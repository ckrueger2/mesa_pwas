library(data.table)
library(dplyr)
library(stringr)
library(argparse)

#set up argparse
parser <- ArgumentParser()
parser$add_argument("--phecode", help="all of us phenotype ID")

args <- parser$parse_args()

#build file read in patterns
phecode_escaped <- gsub("\\.", "\\\\.", args$phecode)
pattern <- paste0('_predixcan_output.*', phecode_escaped, '.*\\.csv$')
dir <- "~/"
files <- list.files(dir, pattern = pattern)

#read in pvalue thresholds
thresholds <- fread("~/mesa_pwas/significance_thresholds.txt")

#initialize empty list
all_results <- list()

#parse through files
for(file in files) {
  
  #read in file
  f <- fread(paste0(dir, "/", file))
  
  #extract ancestry, method, and type from filename
  parts <- strsplit(file, "_")[[1]]
  ancestry <- parts[1] #AFR, AMR, EUR, META
  method <- parts[6] #EN, MASHR, UDR
  
  #determine if cis or trans
  if(grepl("trans", file)) {
    region <- "trans"
  } else {
    region <- "cis"
  }
  
  #determine if fm or not
  if(grepl("_fm\\.csv$", file)) {
    type_suffix <- "fm"
  } else {
    type_suffix <- ""
  }
  
  #build the TYPE string to match thresholds table
  if(region == "cis" && type_suffix == "fm") {
    type_string <- paste0(ancestry, "_", method, "_cisfm")
  } else if(region == "cis" && type_suffix == "") {
    type_string <- paste0(ancestry, "_", method, "_cis")
  } else if(region == "trans" && type_suffix == "fm") {
    type_string <- paste0(ancestry, "_", method, "_transfm")
  } else if(region == "trans" && type_suffix == "") {
    type_string <- paste0(ancestry, "_", method, "_trans")
  }
  
  #match to threshold
  threshold_row <- thresholds[TYPE == type_string]
  threshold_val <- threshold_row$THRESHOLD
  
  #filter by threshold
  filtered <- f %>%
    select(gene, gene_name, zscore, effect_size, pvalue, var_g, pred_perf_r2, pred_perf_pval, pred_perf_qval, n_snps_used, n_snps_in_cov, n_snps_in_model) %>%
    filter(pvalue < threshold_val) %>%
    mutate(model = type_string)
  
  #add to results list
  if(nrow(filtered) > 0) {
    all_results[[type_string]] <- filtered
  }
}

#combine all results into one table
merged_results <- rbindlist(all_results, fill = TRUE)

#write merged output
output_file <- paste0("merged_significant_results_", args$phecode, ".tsv")
write.table (merged_results, output_file, row.names=FALSE, quote=FALSE, sep="\t")

#find bucket
my_bucket <- Sys.getenv('WORKSPACE_BUCKET')

#copy the file from current workspace to the bucket
system(paste0("gsutil cp ./", output_file, " ", my_bucket, "/data/"), intern=TRUE)

cat("Download /home/jupyter/merged_siginificant_results_{phecode}.tsv and upload to excel file\n")