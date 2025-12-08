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

### Running 00pwas_wrapper.sh script
**MUST BE PERFORMED AT LEAST ONCE PRIOR TO RUNNING S-PREDIXCAN:**
1. Create virtual machine with the following parameters (select jupyter icon on right tool bar):
   - Select `Hail Genomics Analysis` under `Recomended environments` drop down
   - Select `8` under `Cloud compute profile CPUs`
   - Select `60` under `Cloud compute profile RAM (GB)`
2. Run in AoU terminal: `gsutil ls` to find bucket name -> ex. `gs://fc-secure-d80c2561-4630-4343-ab98-9fb7fcc9c21b`
3. Run in AoU terminal: `gcloud config get-value project` to find project Terra ID
4. Run in lab server terminal: `gcloud auth login`, then follow prompts to log into AoU account
5. Run in lab server terminal: `gcloud config set project {PASTE_YOUR_TERRA_ID_HERE}`
6. Run in lab server terminal: `gsutil -m cp -r /home/claudia/models_for_pwas {PASTE_YOUR_BUCKET_HERE}/data/`
7. The 00pwas_wrapper must be ran at least once. After one successful run (at least to where S-PrediXcan begins to run and `Running S-PrediXcan...` is printed in output), then the 04run_predixcan.py script can be run with different flags without re-running the full wrapper with `python ~/mesa_pwas/04run_predixcan.py --phecode <PHECODE> --pop <POP> --model <MODEL> --data <DATA>`

`<PHECODE>` is the phenotype code of interest (ex. CV_404)  
`<POP>` is the population the sample originates from (ex. META)  
`<MODEL>` is the training tool (EN, MASHR, or UDR)   
`<DATA>` is the data included (cis cis_fm, trans (MASHR and UDR only), trans_fm (MASHR and UDR only), cistrans_fm (EN only)

Example S-PrediXcan Command:
```
bash ~/mesa_pwas/00pwas_wrapper.sh --phecode CV_404.1 --pop EUR --model EN --data cis_fm
```

### Long runtime solutions
- I havent implemented nohup - please give it a shot if you'd like and let me know if you get it to work with the kernel quit
- I use the app 'Amphetamine' (from Apple app store for mac) to keep my screen on and leave my computer on a charger
- I set my automatically pause after idle to 8 hours (default is 30 minutes) *this must be done when building environment*
<img width="665" height="434" alt="Screenshot 2025-12-06 at 5 03 12 PM" src="https://github.com/user-attachments/assets/4d2740ea-32cf-4674-9f9b-3aa797257225" />
