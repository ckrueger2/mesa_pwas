# mesa_pwas
For more detailed set up info, take a look at the wiki from this github: https://github.com/bmoginot/GWAS-TWAS-in-All-of-Us-Cloud
***

Installing pipeline in All of Us:   
`git clone https://github.com/ckrueger2/mesa_pwas`

### Running 00hail_wrapper.sh script
Running 00hail_wrapper.sh will execute scripts 1 through 3, which include pulling GWAS summary statistics, formatting them, and ploting the manhattan plot

To run the wrapper use the following command within the All of Us terminal under the Hail Table Environment:
```
bash ~/mesa_pwas/00hail_wrapper.sh --phecode <PHECODE> --pop <POP>
```

### Running 00hail_wrapper_parallel.sh script
Running 00hail_wrapper_parallel.sh will execute scripts 1 through 3, which include pulling GWAS summary statistics, formatting them, and ploting the manhattan plot *for all 4 populations simultaneously*

To run the wrapper use the following command within the All of Us terminal under the Hail Table Environment:
```
bash ~/mesa_pwas/00hail_wrapper_parallel.sh --phecode <PHECODE>
```
- A log file will be produced for each population
     - Check for errors or other messages that may impact data
     - To delete all at once : `rm ~/00*.log`
     - To delete all from one phecode: `rm ~/00*{phecode_here}*.log`
       
### Running 00pwas_wrapper.sh script
**MUST BE PERFORMED AT LEAST ONCE PRIOR TO RUNNING S-PREDIXCAN:**
1. Create virtual machine with the following parameters (select jupyter icon on right tool bar):
   - Select `Hail Genomics Analysis` under `Recomended environments` drop down *- remember you must have a controlled workspace to use hail*
   - Select `16` under `Cloud compute profile CPUs`
   - Select `60` under `Cloud compute profile RAM (GB)`
2. Run in AoU terminal: `gsutil ls` to find bucket name -> ex. `gs://fc-secure-d80c2561-4630-4343-ab98-9fb7fcc9c21b`
3. Run in AoU terminal: `gcloud config get-value project` to find project Terra ID
4. Run in lab server terminal: `gcloud auth login`, then follow prompts to log into AoU account
5. Run in lab server terminal: `gcloud config set project {PASTE_YOUR_TERRA_ID_HERE}`
6. Run in lab server terminal: `gsutil -m cp -r /home/matt/models_for_pwas {PASTE_YOUR_BUCKET_HERE}/data/`
7. The 00pwas_wrapper must be ran at least once. After one successful run (at least to where S-PrediXcan begins to run and `Running S-PrediXcan...` is printed in output), then the 04run_predixcan.py script can be run with different flags without re-running the full wrapper with `python ~/mesa_pwas/04run_predixcan.py --phecode <PHECODE> --pop_gwas <GWAS_POP> --pop_db <POP_DB> --model <MODEL> --data <DATA>`

`<PHECODE>` is the phenotype code of interest (ex. CV_404)  
`<POP_GWAS>` is the population of the AoU GWAS (ex. EUR)     
`<POP_DB>` is the population of the MESA db file (ex. META) 
`<MODEL>` is the training tool (EN, MASHR, or UDR)   
`<DATA>` is the data included (cis cis_fm, trans (MASHR and UDR only), trans_fm (MASHR and UDR only), cistrans_fm (EN only)

To run the wrapper use the following command within the All of Us:
```
bash ~/mesa_pwas/00pwas_wrapper.sh --phecode <PHECODE> --pop_gwas <POP_GWAS> --pop_db <POP_DB> --model <MODEL> --data <DATA>

#example:
bash ~/mesa_pwas/00pwas_wrapper.sh --phecode CV_404.1 --pop_gwas EUR --pop_db META --model EN --data cis_fm
```

### Running 00pwas_wrapper_parallel.sh script
Running 00pwas_wrapper_parallel.sh will execute scripts 4 and 5, which included running S-PrediXcan with the TOPMed MESA models and plotting the manhattan plot *for all 4 populations and models simultaneously*

- A log file will be produced for each pop_model_data combination
     - Check for unusual % SNPs used, errors, or other messages that may impact data
     - To delete all at once: `rm ~/01*.log`
     - To delete all from one phecode: `rm ~/01*{phecode_here}*.log`

To run the wrapper use the following command within the All of Us:
```
bash ~/mesa_pwas/00pwas_wrapper_parallel.sh --phecode <PHECODE>
```

### Running 06format_output.R script
Runnning 06format_output.R will compile all predixcan-output files and filter by the respective bonferroni and <0.05 thresholds, producing one filtered file for each. It will create a third file that lists the bonferonni thresholds for each pop/model/data combination. *(merged_significant_results_bcorr_{phecode}.tsv, merged_significant_results_p05_{phecode}.tsv, bonferroni_thresholds_{phecode}.txt)*

- Please download the final bcorr and p05 files and upload it to its own page in the shared excel file

To run the script use the following command within the All of Us:
```
Rscript ~/mesa_pwas/06format_output.R --phecode <PHECODE>
```

### Long runtime solutions
- I havent implemented nohup - please give it a shot if you'd like and let me know if you get it to work with the kernel quit
- I use the app 'Amphetamine' (from Apple app store for mac) to keep my screen on and leave my computer on a charger
- I set my automatically pause after idle to 5 days (default is 30 minutes) *this must be done when building environment*
  - Be sure to pause environment when not running or change this after running so we dont spend all of Dr. Wheeler's money
<img width="657" height="426" alt="Screenshot 2025-12-15 at 12 41 25 PM" src="https://github.com/user-attachments/assets/06d1a9d2-c531-4026-8042-9228b99b082a" />

