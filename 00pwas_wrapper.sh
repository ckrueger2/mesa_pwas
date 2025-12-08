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
    conda create -n imlabtools python=3.8 "numpy<1.24" "pandas<2.0" "scipy<1.11" -y
else
    #if environment exists, ensure compatible numpy version
    conda install -n imlabtools "numpy<1.24" "pandas<2.0" "scipy<1.11" -y
fi

#activate imlabtools
if conda activate imlabtools; then
    echo "Successfully activated imlabtools environment"
fi

#patch MetaXcan code
if [ -f /home/jupyter/MetaXcan/software/metax/gwas/GWAS.py ]; then
    sed -i 's/if a.dtype == numpy.object:/if a.dtype == object or str(a.dtype).startswith("object"):/' /home/jupyter/MetaXcan/software/metax/gwas/GWAS.py
fi

#patch numpy.str deprecation in Utilities.py
if [ -f /home/jupyter/MetaXcan/software/metax/metaxcan/Utilities.py ]; then
    #first check if the file contains the original numpy.str (not already patched)
    if grep -q "numpy\.str[^_]" /home/jupyter/MetaXcan/software/metax/metaxcan/Utilities.py; then
        #only replace numpy.str with numpy.str_ if it hasn't been replaced yet
        sed -i 's/numpy\.str\([^_]\)/numpy.str_\1/g' /home/jupyter/MetaXcan/software/metax/metaxcan/Utilities.py
    elif grep -q "numpy\.str_" /home/jupyter/MetaXcan/software/metax/metaxcan/Utilities.py; then
        #if we find numpy.str__ (double underscore), replace it with numpy.str_
        sed -i 's/numpy\.str__/numpy.str_/g' /home/jupyter/MetaXcan/software/metax/metaxcan/Utilities.py
    fi
    
    #fix the specific line that causes errors with numpy.str__
    sed -i 's/type = \[numpy\.str[_]*, numpy\.float64, numpy\.float64, numpy\.float64\]/type = \[str, numpy.float64, numpy.float64, numpy.float64\]/g' /home/jupyter/MetaXcan/software/metax/metaxcan/Utilities.py
    
    #fix pandas drop() method call
    sed -i 's/results = results.drop("n_snps_in_model",1)/results = results.drop(columns=["n_snps_in_model"])/' /home/jupyter/MetaXcan/software/metax/metaxcan/Utilities.py
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

#run s-predixcan
PREDIXCAN_CMD="python $REPO/04run_predixcan.py --phecode \"$PHECODE\" --pop \"$POP\" --model \"$MODEL\" --data \"$DATA\""

eval $PREDIXCAN_CMD

#run qqman on twas sum stats
Rscript "$REPO/05pwas_qqman.R" --phecode "$PHECODE" --pop "$POP" --model "$MODEL" --data "$DATA"

#deactivate imlabtools
conda deactivate

#how to view generated PNG files
echo "To view the S-PrediXcan and PNG files, go to the Jupyter file browser by selecting the jupyter logo to the top left of the terminal."