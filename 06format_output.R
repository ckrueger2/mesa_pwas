library(data.table)
library(dplyr)
library(stringr)
library(argparse)

#set up argparse
parser <- ArgumentParser()
parser$add_argument("--phecode", help="all of us phenotype ID")
args <- parser$parse_args()

#build file read in patterns - updated for new naming convention
phecode_escaped <- paste0("\\Q", args$phecode, "\\E")
pattern <- paste0("gwas_.*_db_.*_predixcan_output_.*_", phecode_escaped, "_.*\\.csv$")
files <- list.files("/home/jupyter", pattern = pattern)
cat("Number of files found:", length(files), "\n\n")

#initialize empty list
all_results <- list()
all_results_p05 <- list()

#create a data frame to store thresholds
threshold_summary <- data.frame(
  GWAS_POP = character(),
  DB_POP = character(),
  METHOD = character(),
  DATA = character(),
  MODEL_NAME = character(),
  N_GENES = integer(),
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
  
  #parse filename: gwas_{GWAS_POP}_db_{DB_POP}_predixcan_output_{phecode}_{METHOD}_{DATA}.csv
  # Example: gwas_META_db_EUR_predixcan_output_250.2_EN_cis.csv
  
  #extract GWAS population
  gwas_pop <- str_extract(file, "gwas_([A-Z]+)_db")
  gwas_pop <- gsub("gwas_", "", gwas_pop)
  gwas_pop <- gsub("_db", "", gwas_pop)
  
  #extract DB population
  db_pop <- str_extract(file, "db_([A-Z]+)_predixcan")
  db_pop <- gsub("db_", "", db_pop)
  db_pop <- gsub("_predixcan", "", db_pop)
  
  #extract the method and data type from filename
  #remove prefix up to and including the phecode
  remainder <- sub(paste0(".*_predixcan_output_", phecode_escaped, "_"), "", file)
  #remove .csv extension
  remainder <- gsub("\\.csv$", "", remainder)
  
  #remainder contains "{method}_{data}", e.g., "EN_cis" or "MASHR_cistrans_fm"
  #split to get method and data
  parts_split <- strsplit(remainder, "_", fixed = TRUE)[[1]]
  method <- parts_split[1]  # EN, MASHR, UDR
  data_type <- paste(parts_split[-1], collapse = "_")  # cis, cis_fm, trans, trans_fm, cistrans_fm
  
  #build the model name string (for backward compatibility and easy identification)
  model_name <- paste0(gwas_pop, "x", db_pop, "_", method, "_", data_type)
  
  cat("Processing:", model_name, "\n")
  cat("  GWAS Pop:", gwas_pop, "| DB Pop:", db_pop, "| Method:", method, 
      "| Data:", data_type, "\n")
  cat("  Genes:", n_genes, "| Threshold:", format(bonferroni_threshold, scientific = TRUE), "\n\n")
  
  #add to threshold summary
  threshold_summary <- rbind(threshold_summary, 
                             data.frame(
                               GWAS_POP = gwas_pop,
                               DB_POP = db_pop,
                               METHOD = method,
                               DATA = data_type,
                               MODEL_NAME = model_name,
                               N_GENES = n_genes,
                               THRESHOLD = bonferroni_threshold
                             ))
  
  #filter by Bonferroni threshold
  filtered <- f %>%
    select(gene, gene_name, zscore, effect_size, pvalue, var_g, pred_perf_r2, 
           pred_perf_pval, pred_perf_qval, n_snps_used, n_snps_in_cov, n_snps_in_model) %>%
    filter(pvalue < bonferroni_threshold) %>%
    mutate(
      gwas_pop = gwas_pop,
      db_pop = db_pop,
      method = method,
      data_type = data_type,
      model_name = model_name
    )
  
  #filter by p < 0.05
  filtered_p05 <- f %>%
    select(gene, gene_name, zscore, effect_size, pvalue, var_g, pred_perf_r2, 
           pred_perf_pval, pred_perf_qval, n_snps_used, n_snps_in_cov, n_snps_in_model) %>%
    filter(pvalue < 0.05) %>%
    mutate(
      gwas_pop = gwas_pop,
      db_pop = db_pop,
      method = method,
      data_type = data_type,
      model_name = model_name
    )
  
  #add to results list
  if(nrow(filtered) > 0) {
    all_results[[model_name]] <- filtered
  }
  if(nrow(filtered_p05) > 0) {
    all_results_p05[[model_name]] <- filtered_p05
  }
}

#combine all results into one table
merged_results <- rbindlist(all_results, fill = TRUE)
merged_results_p05 <- rbindlist(all_results_p05, fill = TRUE)

#reorder columns for better readability
if(nrow(merged_results) > 0) {
  merged_results <- merged_results %>%
    select(gene, gene_name, gwas_pop, db_pop, method, data_type, model_name,
           zscore, effect_size, pvalue, var_g, pred_perf_r2, 
           pred_perf_pval, pred_perf_qval, n_snps_used, n_snps_in_cov, n_snps_in_model)
}

if(nrow(merged_results_p05) > 0) {
  merged_results_p05 <- merged_results_p05 %>%
    select(gene, gene_name, gwas_pop, db_pop, method, data_type, model_name,
           zscore, effect_size, pvalue, var_g, pred_perf_r2, 
           pred_perf_pval, pred_perf_qval, n_snps_used, n_snps_in_cov, n_snps_in_model)
}

#write merged output
output_file <- paste0("merged_significant_results_bcorr_", args$phecode, ".tsv")
output_file_p05 <- paste0("merged_significant_results_p05_", args$phecode, ".tsv")
threshold_file <- paste0("bonferroni_thresholds_", args$phecode, ".txt")

write.table(merged_results, output_file, row.names=FALSE, quote=FALSE, sep="\t")
write.table(merged_results_p05, output_file_p05, row.names=FALSE, quote=FALSE, sep="\t")
write.table(threshold_summary, threshold_file, row.names=FALSE, quote=FALSE, sep="\t")

#print summary statistics
cat("\n========== SUMMARY ==========\n")
cat("Total files processed:", length(files), "\n")
cat("Bonferroni significant genes:", nrow(merged_results), "\n")
cat("P < 0.05 genes:", nrow(merged_results_p05), "\n")

#find bucket
my_bucket <- Sys.getenv('WORKSPACE_BUCKET')

#copy the files from current workspace to the bucket
system(paste0("gsutil cp ./", output_file, " ", my_bucket, "/data/"), intern=TRUE)
system(paste0("gsutil cp ./", output_file_p05, " ", my_bucket, "/data/"), intern=TRUE)
system(paste0("gsutil cp ./", threshold_file, " ", my_bucket, "/data/"), intern=TRUE)

cat("\nDownload files and upload to shared excel file\n")