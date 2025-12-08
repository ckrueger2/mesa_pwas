#!/bin/bash

#command
usage() {
    echo "Usage: $0 --phecode <PHECODE> --pop <POP> --model <MODEL> --data <DATA>"
    exit 1
}

#command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --phecode)
            PHECODE=$2
            shift 2
            ;;
        --pop)
            POP=$2
            shift 2
            ;;
        --model)
            MODEL=$2
            shift 2
            ;;
        --data)
            DATA=$2
            shift 2
            ;;
        *)
            echo "unknown flag: $1"
            usage
            ;;
    esac
done

#check for required arguments
if [[ -z "$PHECODE" || -z "$POP" || -z "$MODEL" || -z "$DATA" ]]; then
    usage
fi

#github repo path
REPO=$HOME/mesa_pwas

#set up S-PrediXcan environment
bash "$REPO/00install_predixcan.sh"

#activate conda
source ~/miniconda3/bin/activate

#create environment with compatible versions (version numbers may need to be changed with future updates)
if ! conda env list | grep -q imlabtools; then
    # If it doesn't exist, create it
    conda create -n imlabtools python=3.8 numpy pandas scipy -y
fi

#activate imlabtools
if conda activate imlabtools; then
    echo "Successfully activated imlabtools environment"
fi

output_file="/home/jupyter/${POP}_predixcan_output_${PHECODE}_${MODEL}_${DATA}.csv"

# #check if the output file already exists
# if [ -f "$output_file" ]; then
#     echo "WARNING: Output file $output_file already exists."
#     read -p "Press ENTER to replace it, or type 'n' to cancel: " response
#     
#     if [[ $response =~ ^[Nn]$ ]]; then
#         echo "Operation cancelled by user."
#         exit 1
#     else
#         # Delete the file
#         rm -f "$output_file"
#         echo "Existing file has been deleted."
#     fi
# fi

#check if the output file already exists
if [ -f "$output_file" ]; then
    echo "WARNING: Output file $output_file already exists. Replacing..."
    rm -f "$output_file"
fi

# #run s-predixcan
# PREDIXCAN_CMD="python $REPO/04run_predixcan.py --phecode \"$PHECODE\" --pop \"$POP\" --model \"$MODEL\" --data \"$DATA\""
# 
# eval $PREDIXCAN_CMD
# 
# #run qqman on twas sum stats
# Rscript "$REPO/05pwas_qqman.R" --phecode "$PHECODE" --pop "$POP" --model "$MODEL" --data "$DATA"

#run s-predixcan - continue even if it fails
if python $REPO/04run_predixcan.py --phecode "$PHECODE" --pop "$POP" --model "$MODEL" --data "$DATA"; then
    echo "S-PrediXcan completed successfully"
    
    #only run qqman if s-prediXcan succeeded
    if [ -f "$output_file" ]; then
        Rscript "$REPO/05pwas_qqman.R" --phecode "$PHECODE" --pop "$POP" --model "$MODEL" --data "$DATA"
    else
        echo "WARNING: Output file not found, skipping qqman plot"
    fi
else
    echo "ERROR: S-PrediXcan failed for $POP $MODEL $DATA (exit code $?)"
    echo "Check log file for details: ~/${POP}_${PHECODE}_${MODEL}_${DATA}_pwas.log"
fi

#deactivate imlabtools
conda deactivate

#how to view generated PNG files
echo "To view the S-PrediXcan and PNG files, go to the Jupyter file browser by selecting the jupyter logo to the top left of the terminal."