#!/bin/bash

#command
usage() {
    echo "Usage: $0 --phecode <PHECODE> --pop <POP>"
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
        *)
            echo "unknown flag: $1"
            usage
            ;;
    esac
done

#check for required arguments
if [[ -z "$PHECODE" || -z "$POP" ]]; then
    usage
fi

#github repo path
REPO=$HOME/mesa_pwas

#download hail table
#python "$REPO/01pull_data.py" --phecode "$PHECODE" --pop "$POP"

#format hail tables
#Rscript "$REPO/02table_format.R" --phecode "$PHECODE" --pop "$POP"

#capture the SNP count
BUCKET_PATH=$(gsutil ls gs://*/data/${POP}_full_${PHECODE}.tsv)
SNP_COUNT=$(gsutil cat $BUCKET_PATH | wc -l)
SNP_COUNT=$((SNP_COUNT - 1)) #subtract 1 to exclude the header line

#GWAS qqman
Rscript "$REPO/03gwas_qqman.R" --phecode "$PHECODE" --pop "$POP" --snp_count "$SNP_COUNT"

#how to view generated PNG files
echo "To view PNG file, go to the Jupyter file browser by selecting the jupyter logo to the top left of the terminal."