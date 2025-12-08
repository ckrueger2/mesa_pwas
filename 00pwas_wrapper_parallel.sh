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

#define populations
POPS=("META" "EUR" "AFR" "AMR")

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

#create environment if needed
if ! conda env list | grep -q imlabtools; then
    conda create -n imlabtools python=3.8 numpy pandas scipy -y
fi

#activate imlabtools
conda activate imlabtools
echo "Successfully activated imlabtools environment"

#patch MetaXcan code
if [ -f /home/jupyter/MetaXcan/software/metax/gwas/GWAS.py ]; then
    sed -i 's/if a.dtype == numpy.object:/if a.dtype == object or str(a.dtype).startswith("object"):/' /home/jupyter/MetaXcan/software/metax/gwas/GWAS.py
fi

if [ -f /home/jupyter/MetaXcan/software/metax/metaxcan/Utilities.py ]; then
    if grep -q "numpy\.str[^_]" /home/jupyter/MetaXcan/software/metax/metaxcan/Utilities.py; then
        sed -i 's/numpy\.str\([^_]\)/numpy.str_\1/g' /home/jupyter/MetaXcan/software/metax/metaxcan/Utilities.py
    elif grep -q "numpy\.str_" /home/jupyter/MetaXcan/software/metax/metaxcan/Utilities.py; then
        sed -i 's/numpy\.str__/numpy.str_/g' /home/jupyter/MetaXcan/software/metax/metaxcan/Utilities.py
    fi
    sed -i 's/type = \[numpy\.str[_]*, numpy\.float64, numpy\.float64, numpy\.float64\]/type = \[str, numpy.float64, numpy.float64, numpy.float64\]/g' /home/jupyter/MetaXcan/software/metax/metaxcan/Utilities.py
    sed -i 's/results = results.drop("n_snps_in_model",1)/results = results.drop(columns=["n_snps_in_model"])/' /home/jupyter/MetaXcan/software/metax/metaxcan/Utilities.py
fi

echo "Environment setup complete."
echo ""

chmod +x ~/mesa_pwas/00pwas_wrapper.sh

#maximum number of parallel jobs
MAX_PARALLEL=2

echo "Starting PWAS analysis for phecode $PHECODE"
echo ""

#counter for active jobs
ACTIVE=0

#loop through all combinations
for POP in "${POPS[@]}"; do
    for JOB in "${JOBS[@]}"; do
        #parse MODEL and DATA from JOB
        MODEL=$(echo $JOB | awk '{print $1}')
        DATA=$(echo $JOB | awk '{print $2}')
        
        #wait if parallel limit hit
        while [ $ACTIVE -ge $MAX_PARALLEL ]; do
            wait -n  #wait for any job to finish
            ACTIVE=$((ACTIVE - 1))
        done
        
        #launch job
        echo "Starting: $POP $MODEL $DATA"
        (
            output_file="/home/jupyter/${POP}_predixcan_output_${PHECODE}_${MODEL}_${DATA}.csv"
            
            #check if output file already exists
            if [ -f "$output_file" ]; then
                echo "WARNING: Output file $output_file already exists. Replacing..."
                rm -f "$output_file"
            fi
            
            #run s-predixcan
            python $REPO/04run_predixcan.py --phecode "$PHECODE" --pop "$POP" --model "$MODEL" --data "$DATA"
            
            #plot pwas
            Rscript "$REPO/05twas_qqman.R" --phecode "$PHECODE" --pop "$POP" --model "$MODEL" --data "$DATA"
            
        ) > ~/${POP}_${PHECODE}_${MODEL}_${DATA}_pwas.log 2>&1 &
        
        ACTIVE=$((ACTIVE + 1))
    done
done

#wait for remaining jobs
wait

#deactivate conda environment
conda deactivate

echo ""
echo "All analyses completed for phecode $PHECODE"