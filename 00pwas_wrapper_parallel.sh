#!/bin/bash

usage() {
    echo "Usage: $0 --phecode <PHECODE>"
    exit 1
}

#parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --phecode)
            PHECODE=$2
            shift 2
            ;;
        *)
            echo "Unknown flag: $1"
            usage
            ;;
    esac
done

#check for required argument
if [[ -z "$PHECODE" ]]; then
    usage
fi

#define populations for both GWAS data and DB models
GWAS_POPS=("META" "EUR" "AFR" "AMR")
DB_POPS=("META" "EUR" "AFR" "AMR")

#define model-data combinations
declare -a JOBS=(
    "EN cis"
    "EN cis_fm"
    "EN cistrans_fm"
    "MASHR cis"
    "MASHR cis_fm"
    "MASHR trans"
    "MASHR trans_fm"
    "UDR cis"
    "UDR cis_fm"
    "UDR trans"
    "UDR trans_fm"
)

#repo path
REPO=$HOME/mesa_pwas

#set up environment once before running any jobs
echo "Setting up S-PrediXcan environment..."
bash "$REPO/00install_predixcan.sh"

#activate conda
source ~/miniconda3/bin/activate

#create environment with compatible versions (version numbers may need to be changed with future updates)
if ! conda env list | grep -q imlabtools; then
    # If it doesn't exist, create it
    conda create -n imlabtools python=3.8 numpy pandas scipy -y
fi

#activate imlabtools
conda activate imlabtools
echo "Successfully activated imlabtools environment"

#maximum number of parallel jobs
MAX_PARALLEL=1

#copy MESA model files to workspace if they don't exist
if [ ! -f "/home/jupyter/models_for_pwas/EN/cis/META_EN_covariances.txt.gz" ]; then
    echo "Copying model files from bucket..."
    
    #get bucket from environment variable or use default
    if [ -z "$WORKSPACE_BUCKET" ]; then
        echo "WARNING: WORKSPACE_BUCKET not set in environment"
        #try to get it from google cloud
        BUCKET=$(gcloud config get-value project 2>/dev/null)
        if [ -z "$BUCKET" ]; then
            echo "ERROR: Could not determine bucket. Please set WORKSPACE_BUCKET environment variable"
            exit 1
        fi
    else
        BUCKET="$WORKSPACE_BUCKET"
    fi
    
    gsutil -m cp -r ${BUCKET}/data/models_for_pwas/ /home/jupyter/
    echo "Model files copied successfully"
else
    echo "Model files already exist, skipping download"
fi

echo "Starting PWAS analysis for phecode $PHECODE"
echo "Running all GWAS population x DB population combinations"
echo ""

#counter for active jobs
ACTIVE=0

#loop through all combinations: GWAS pop x DB pop x MODEL x DATA
for GWAS_POP in "${GWAS_POPS[@]}"; do
    for DB_POP in "${DB_POPS[@]}"; do
        for JOB in "${JOBS[@]}"; do
            #parse MODEL and DATA from JOB
            MODEL=$(echo $JOB | awk '{print $1}')
            DATA=$(echo $JOB | awk '{print $2}')
            
            #skip META population for MASHR and UDR models (DB side)
            if [ "$MODEL" = "MASHR" ] || [ "$MODEL" = "UDR" ]; then
                if [ "$DB_POP" = "META" ]; then
                    continue
                fi
            fi
            
            #wait if parallel limit hit
            while [ $ACTIVE -ge $MAX_PARALLEL ]; do
                wait -n  #wait for any job to finish
                ACTIVE=$((ACTIVE - 1))
            done
            
            #launch job
            echo "Starting: GWAS=$GWAS_POP x DB=$DB_POP | $MODEL $DATA"
            (
                output_file="/home/jupyter/gwas_${GWAS_POP}_db_${DB_POP}_predixcan_output_${PHECODE}_${MODEL}_${DATA}.csv"
                
                #check if output file already exists
                if [ -f "$output_file" ]; then
                    echo "WARNING: Output file $output_file already exists. Replacing..."
                    rm -f "$output_file"
                fi
                
                #run s-predixcan - continue other runs if it fails
                if python $REPO/04run_predixcan.py --phecode "$PHECODE" --pop_gwas "$GWAS_POP" --pop_db "$DB_POP" --model "$MODEL" --data "$DATA"; then
                    echo ""
                    
                    #only run qqman if s-predixcan succeeded
                    if [ -f "$output_file" ]; then
                        if [ -f "$REPO/05pwas_qqman.R" ]; then
                            Rscript "$REPO/05pwas_qqman.R" --phecode "$PHECODE" --pop_gwas "$GWAS_POP" --pop_db "$DB_POP" --model "$MODEL" --data "$DATA"
                            echo "Finished: GWAS=$GWAS_POP x DB=$DB_POP | $MODEL $DATA"
                        fi
                    else
                        echo "WARNING: Output file not found, skipping qqman plot"
                    fi
                else
                    echo "ERROR: S-PrediXcan failed for GWAS=$GWAS_POP x DB=$DB_POP | $MODEL $DATA (exit code $?)"
                    echo "Check log file for details: ~/00gwas_${GWAS_POP}_db_${DB_POP}_${PHECODE}_${MODEL}_${DATA}_pwas.log"
                fi
                
            ) > ~/01gwas_${GWAS_POP}_db_${DB_POP}_${PHECODE}_${MODEL}_${DATA}_pwas.log 2>&1 &
            
            ACTIVE=$((ACTIVE + 1))
        done
    done
done

#wait for remaining jobs
wait

#deactivate conda environment
conda deactivate

echo "All analyses completed for phecode $PHECODE"
echo "Total combinations run: GWAS pops (4) x DB pops (4 for EN, 3 for MASHR/UDR) x Models/Data"