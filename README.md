# mesa_pwas
***

Installing pipeline in All of Us:   
`git clone https://github.com/ckrueger2/mesa_pwas`

### Running 00hail_wrapper.sh script
Running the 00hail_wrapper.sh will execute scripts 1 through 3, which include pulling GWAS summary statistics, formatting them, and ploting the manhattan plot

To run the wrapper use the following command within the All of Us terminal under the Hail Table Environment:
```
bash ~/mesa_pwas/00hail_wrapper.sh --phecode <PHECODE> --pop <POP>
```

### Running 00hail_wrapper_parallel.sh script
Running the 00hail_wrapper_parallel.sh will execute scripts 1 through 3, which include pulling GWAS summary statistics, formatting them, and ploting the manhattan plot *for all 4 populations simultaneously*

To run the wrapper use the following command within the All of Us terminal under the Hail Table Environment:
```
bash ~/mesa_pwas/00hail_wrapper_parallel.sh --phecode <PHECODE>
```

**MUST BE PERFORMED AT LEAST ONCE PRIOR TO RUNNING S-PREDIXCAN:**
1. Run in AoU terminal: `gsutil ls` to find bucket name -> ex. `gs://fc-secure-d80c2561-4630-4343-ab98-9fb7fcc9c21b`
2. Run in AoU terminal: `gcloud config get-value project` to find project Terra ID
3. Run in lab server terminal: `gcloud auth login`, then follow prompts to log into AoU account
4. Run in lab server terminal: `gcloud config set project {PASTE_YOUR_TERRA_ID_HERE}`
5. Run in lab server terminal: `gsutil -m cp -r /home/claudia/models_for_pwas {PASTE_YOUR_BUCKET_HERE}/data/`
6. The wrapper must be ran at least once. After one successful run (at least to where S-PrediXcan begins to run and `Running S-PrediXcan...` is printed in output), then the 04run_predixcan.py script can be run with different flags without re-running the full wrapper with `python ~/mesa_pwar/04run_predixcan.py --phecode <PHECODE> --pop <POP> --model <MODEL> --data <DATA>`

`<PHECODE>` is the phenotype code of interest (ex. CV_404)  
`<POP>` is the population the sample originates from (ex. META)  
`<MODEL>` is the training tool (EN, MASHR, or UDR) 
`<DATA>` is the data included (cis cis_fm, trans (MASHR and UDR only), trans_fm (MASHR and UDR only), cistrans_fm (EN only)

Example S-PrediXcan Command:
```
bash ~/mesa_pwas/00pwas_wrapper.sh --phecode CV_404.1 --pop EUR --model EN --data cis_fm
```
