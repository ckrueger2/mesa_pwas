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
            echo "unknown flag: $1"
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

chmod +x ~/mesa_pwas/00hail_wrapper.sh

#run in parallel
for POP in "${POPS[@]}"; do
    ~/mesa_pwas/00hail_wrapper.sh --phecode "$PHECODE" --pop "$POP" > ~/${POP}_${PHECODE}_gwas.log 2>&1 &
done

#wait for all background jobs to complete
wait

echo "All populations completed for phecode $PHECODE"
