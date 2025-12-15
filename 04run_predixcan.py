#!/usr/bin/env python3
import os
import sys
import argparse
import subprocess

def set_args():
    parser = argparse.ArgumentParser(description="run s-predixcan with cross-population analysis")
    parser.add_argument("--phecode", help="phecode", required=True)
    parser.add_argument("--pop_gwas", help="population for GWAS data (META, EUR, AFR, AMR)", required=True)
    parser.add_argument("--pop_db", help="population for database/model (META, EUR, AFR, AMR)", required=True)
    parser.add_argument("--model", help="EN, MASHR, or UDR", required=True)
    parser.add_argument("--data", help="cis, cis_fm, trans, trans_fm, cistrans_fm", required=True)
    return parser
    
def main():
    parser = set_args()
    args = parser.parse_args(sys.argv[1:])
    
    #define paths
    bucket = os.getenv('WORKSPACE_BUCKET')
    output = f"/home/jupyter/gwas_{args.pop_gwas}_db_{args.pop_db}_predixcan_output_{args.phecode}_{args.model}_{args.data}.csv"
    
    #python and metaxcan paths
    python_path = sys.executable
    metaxcan_dir = "/home/jupyter/MetaXcan"
    
    #retrieve MESA formatted file from bucket (using GWAS population)
    filename = args.pop_gwas + "_formatted_mesa_" + args.phecode + ".tsv"
    get_command = "gsutil cp " + bucket + "/data/" + filename + " /tmp/"
    print(f"Downloading GWAS data: {filename}")
    ret = os.system(get_command)
    
    if ret != 0:
        print(f"ERROR: Failed to download GWAS file {filename}")
        sys.exit(1)
    
    #assign database paths (using DB population)
    model_db_path = f"models_for_pwas/{args.model}/{args.data}/{args.pop_db}_{args.model}.db"
    covariance_path = f"models_for_pwas/{args.model}/{args.data}/{args.pop_db}_{args.model}_covariances.txt.gz"
    
    #verify database files exist
    if not os.path.exists(model_db_path):
        print(f"ERROR: Model database not found: {model_db_path}")
        sys.exit(1)
    if not os.path.exists(covariance_path):
        print(f"ERROR: Covariance file not found: {covariance_path}")
        sys.exit(1)
    
    print(f"\nRunning S-PrediXcan:")
    print(f"  GWAS Population: {args.pop_gwas}")
    print(f"  DB Population:   {args.pop_db}")
    print(f"  Model:           {args.model}")
    print(f"  Data:            {args.data}")
    print(f"  Phecode:         {args.phecode}\n")
    
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
    print("Executing S-PrediXcan...")
    exit_code = os.system(cmd)
    
    if exit_code != 0:
        print(f"ERROR: SPrediXcan.py failed with exit code {exit_code}")
        #clean up tmp files
        os.system(f"rm -rf /tmp/{filename} 2>/dev/null")
        sys.exit(exit_code)
    
    #upload the results back to the bucket
    set_file = f"gsutil cp {output} {bucket}/data/"
    print(f"\nUploading results: {output}")
    upload_ret = os.system(set_file)
    
    if upload_ret != 0:
        print(f"WARNING: Failed to upload results to bucket")
    
    #clean up tmp files if they exist
    os.system(f"rm -rf /tmp/{filename} 2>/dev/null")
        
    print(f"\nS-PrediXcan analysis completed successfully")
    print(f"Output file: {output}")

if __name__ == "__main__":
    main()
