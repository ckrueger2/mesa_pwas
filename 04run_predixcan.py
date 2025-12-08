#!/usr/bin/env python3

import os
import sys
import argparse
import subprocess

def set_args():
    parser = argparse.ArgumentParser(description="run s-predixcan")
    parser.add_argument("--phecode", help="phecode", required=True)
    parser.add_argument("--pop", help="population", required=True)
    parser.add_argument("--model", help="EN, MASHR, or UDR", required=True)
    parser.add_argument("--data", help="cis, cis_fm, trans, trans_fm, cistrans_fm", required=True)
    return parser
    
def main():
    parser = set_args()
    args = parser.parse_args(sys.argv[1:])
    
    #define paths
    bucket = os.getenv('WORKSPACE_BUCKET')
    output = f"/home/jupyter/{args.pop}_predixcan_output_{args.phecode}_{args.model}_{args.data}.csv"
    
    #python and metaxcan paths
    python_path = sys.executable
    metaxcan_dir = "/home/jupyter/MetaXcan"

    #retrieve MESA filtered file from bucket
    filename = args.pop + "_formatted_mesa_" + args.phecode + ".tsv"
    get_command = "gsutil cp " + bucket + "/data/" + filename + " /tmp/"
    os.system(get_command)

    # #copy MESA dbfiles to workspace
    # if not os.path.exists("/home/jupyter/models_for_pwas/EN/cis/META_EN_covariances.txt.gz"):
    #     ret = subprocess.run(f"gsutil cp -r {bucket}/data/models_for_pwas/ /home/jupyter/", shell=True)
    
    #assign database paths
    model_db_path = f"models_for_pwas/{args.model}/{args.data}/{args.pop}_{args.model}.db"
    covariance_path = f"models_for_pwas/{args.model}/{args.data}/{args.pop}_{args.model}_covariances.txt.gz"
    #command without optional parameters
    cmd = f"{python_path} {metaxcan_dir}/software/SPrediXcan.py \
    --gwas_file /tmp/{filename} \
    --snp_column SNP \
    --effect_allele_column ALT \
    --non_effect_allele_column REF \
    --beta_column BETA \
    --se_column SE \
    --model_db_path {model_db_path} \
    --covariance {covariance_path} \
    --keep_non_rsid \
    --model_db_snp_key rsid \
    --throw \
    --output_file {output}"
        
    #execute the S-PrediXcan command
    print("Running S-PrediXcan...")
    exit_code = os.system(cmd)
    
    if exit_code != 0:
        print(f"ERROR: SPrediXcan.py failed with exit code {exit_code}")
        return
    
    #upload the results back to the bucket
    set_file = f"gsutil cp {output} {bucket}/data/"
    print(f"Uploading results: {set_file}")
    os.system(set_file)

    #clean up tmp files if they exist
    os.system(f"rm -rf /tmp/{filename} 2>/dev/null")
        
    print("S-PrediXcan analysis completed successfully")

if __name__ == "__main__":
    main()
