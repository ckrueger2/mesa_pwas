library(data.table)
library(dplyr)
library(stringr)
library(argparse)

#set up argparse
parser <- ArgumentParser()
parser$add_argument("--phecode", help="all of us phenotype ID (e.g., CV_401.1)")
args <- parser$parse_args()

#build file read in patterns
phecode_escaped <- gsub("\\.", "\\\\.", args$phecode)
pattern <- paste0('_predixcan_output_', phecode_escaped, '_.*\\.csv$')
dir <- "~/"
files <- list.files(dir, pattern = pattern)

cat("Number of files found:", length(files), "\n\n")

#initialize empty list
all_results <- list()
all_results_p05 <- list()

#create a data frame to store thresholds like significance_thresholds.txt
threshold_summary <- data.frame(
  TYPE = character(),
  THRESHOLD = numeric(),
  stringsAsFactors = FALSE
)

#parse through files
for(file in files) {
  
  #read in file
  f <- fread(paste0(dir, "/", file))
  
  #calculate Bonferroni threshold for THIS file
  n_genes <- nrow(f)
  bonferroni_threshold <- 0.05 / n_genes
  
  #extract ancestry from filename (first part before underscore)
  parts <- strsplit(file, "_")[[1]]
  ancestry <- parts[1] #AFR, AMR, EUR, META
  
  #extract the region type from filename
  # Pattern: {ancestry}_predixcan_output_{phecode}_{method}_{region}.csv
  # Remove the prefix up to and including the phecode
  region_part <- sub(paste0(".*_predixcan_output_", phecode_escaped, "_"), "", file)
  # Remove .csv extension
  region_part <- gsub("\\.csv$", "", region_part)
  
  # Now region_part contains "{method}_{region}", e.g., "EN_cis" or "MASHR_cistrans_fm"
  # Split to get method and region
  region_split <- strsplit(region_part, "_", fixed = TRUE)[[1]]
  method <- region_split[1]  # EN, MASHR, UDR
  region <- paste(region_split[-1], collapse = "_")  # cis, cis_fm, trans, trans_fm, cistrans_fm, etc.
  
  #build the TYPE string
  type_string <- paste0(ancestry, "_", method, "_", region)
  
  cat("Processing:", type_string, "- Genes:", n_genes, "- Threshold:", 
      format(bonferroni_threshold, scientific = TRUE), "\n")
  
  #add to threshold summary
  threshold_summary <- rbind(threshold_summary, 
                             data.frame(TYPE = type_string, 
                                        THRESHOLD = bonferroni_threshold))
  
  #filter by Bonferroni threshold
  filtered <- f %>%
    select(gene, gene_name, zscore, effect_size, pvalue, var_g, pred_perf_r2, 
           pred_perf_pval, pred_perf_qval, n_snps_used, n_snps_in_cov, n_snps_in_model) %>%
    filter(pvalue < bonferroni_threshold) %>%
    mutate(model = type_string)
  
  #filter by p < 0.05
  filtered_p05 <- f %>%
    select(gene, gene_name, zscore, effect_size, pvalue, var_g, pred_perf_r2, 
           pred_perf_pval, pred_perf_qval, n_snps_used, n_snps_in_cov, n_snps_in_model) %>%
    filter(pvalue < 0.05) %>%
    mutate(model = type_string)
  
  #add to results list
  if(nrow(filtered) > 0) {
    all_results[[type_string]] <- filtered
  }
  if(nrow(filtered_p05) > 0) {
    all_results_p05[[type_string]] <- filtered_p05
  }
}

#combine all results into one table
merged_results <- rbindlist(all_results, fill = TRUE)
merged_results_p05 <- rbindlist(all_results_p05, fill = TRUE)

#write merged output
output_file <- paste0("merged_significant_results_bcorr_", args$phecode, ".tsv")
output_file_p05 <- paste0("merged_significant_results_p05_", args$phecode, ".tsv")
threshold_file <- paste0("bonferroni_thresholds_", args$phecode, ".txt")

write.table(merged_results, output_file, row.names=FALSE, quote=FALSE, sep="\t")
write.table(merged_results_p05, output_file_p05, row.names=FALSE, quote=FALSE, sep="\t")
write.table(threshold_summary, threshold_file, row.names=FALSE, quote=FALSE, sep=" ")

#find bucket
my_bucket <- Sys.getenv('WORKSPACE_BUCKET')

#copy the files from current workspace to the bucket
system(paste0("gsutil cp ./", output_file, " ", my_bucket, "/data/"), intern=TRUE)
system(paste0("gsutil cp ./", output_file_p05, " ", my_bucket, "/data/"), intern=TRUE)
system(paste0("gsutil cp ./", threshold_file, " ", my_bucket, "/data/"), intern=TRUE)

cat("\nFiles written:\n")
cat("- ", output_file, "\n")
cat("- ", output_file_p05, "\n")
cat("- ", threshold_file, "\n")
cat("\nDownload files from bucket/data/ and upload to excel\n")