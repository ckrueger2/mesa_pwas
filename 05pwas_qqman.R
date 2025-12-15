#!/usr/bin/R

#using biomart to find genomic coordinates of genes from spredixcan output
if (!requireNamespace("BiocManager", quietly = TRUE)) install.packages("BiocManager")
if (!requireNamespace("biomaRt", quietly = TRUE)) BiocManager::install("biomaRt")

#data table and dplyr for data and table manipulation
if (!requireNamespace("data.table", quietly = TRUE)) install.packages("data.table")
if (!requireNamespace("dplyr", quietly = TRUE)) install.packages("dplyr")
if (!requireNamespace("argparse", quietly = TRUE)) install.packages("argparse")
if (!requireNamespace("qqman", quietly = TRUE)) install.packages("qqman")

library(biomaRt)
library(data.table)
library(dplyr)
library(qqman)
library(argparse)

#set up argparse
parser <- ArgumentParser()
parser$add_argument("--phecode", help="all of us phenotype ID")
parser$add_argument("--pop_gwas", help="GWAS population (META, EUR, AFR, AMR)")
parser$add_argument("--pop_db", help="database/model population (META, EUR, AFR, AMR)")
parser$add_argument("--model", help="pwas training model (EN, MASHR, UDR)")
parser$add_argument("--data", help="pwas data type (cis, cis_fm, trans, trans_fm, cistrans_fm)")

args <- parser$parse_args()

#get the bucket name
my_bucket <- Sys.getenv('WORKSPACE_BUCKET')

#pull file from bucket with new naming convention
name_of_file_in_bucket <- paste0("gwas_", args$pop_gwas, "_db_", args$pop_db, 
                                 "_predixcan_output_", args$phecode, "_", 
                                 args$model, "_", args$data, ".csv")
read_in_command <- paste0("gsutil cp ", my_bucket, "/data/", name_of_file_in_bucket, " .")

#copy file from the bucket to the current workspace
system(read_in_command, intern=TRUE)
df <- fread(name_of_file_in_bucket, sep = ",", header=TRUE)

#accessing the Ensembl biomart database for 'genes', specifically the human genes version 113
biomart_access <- useEnsembl(biomart = "genes", dataset = "hsapiens_gene_ensembl")

#removes the decimal after the gene, helps with merging and searching in general 
#this doesnt rename the gene, instead creates a new column so we dont lose data
df$gene_id <- sub("\\..*", "", df$gene)

#preview the data
cat("Preview of S-PrediXcan output:\n")
print(head(df, 5))

#use biomart to pull chromosomal location information 
cat("\nQuerying BioMart for gene coordinates...\n")
gene_coords <- getBM(
  attributes = c("ensembl_gene_id", "chromosome_name", "start_position", "end_position", "external_gene_name"),
  filters = "ensembl_gene_id",
  values = df$gene_id,
  mart = biomart_access
)

#merge pwas table and biomart results 
merged_df <- left_join(df, gene_coords, by=c("gene_id" = "ensembl_gene_id"))

#make p column is numeric and handle NA p-values and 0s
merged_df$P <- as.numeric(merged_df$pvalue)
zeros <- which(merged_df$P == 0)

#filter only for required fields
merged_df <- merged_df %>% filter(!is.na(chromosome_name) & !is.na(start_position) & !is.na(P))
if(length(zeros) > 0) {
  merged_df$P[merged_df$P == 0] <- 1e-300
  cat("Adjusted", length(zeros), "zero p-values to 1e-300\n")
}

#ensure X chromosome coded as 23
merged_df$chromosome_name <- gsub("X", "23", merged_df$chromosome_name)

#make chr rows numeric and remove rows with NA
merged_df$CHR <- as.numeric(merged_df$chromosome_name)
merged_df <- merged_df[!is.na(merged_df$CHR), ]

#finding sample size to calculate threshold
sample_size <- nrow(df)

#calculate the new bonferroni threshold based on sample size 
bonferroni_threshold <- 0.05 / sample_size
new_suggestive_threshold <- -log10(bonferroni_threshold)
cat("\nBonferroni corrected P-value:", bonferroni_threshold, "\n")
cat("Suggestive line (-log10):", new_suggestive_threshold, "\n\n")

#manhattan plot title name - now includes both populations
title <- paste0("GWAS: ", args$pop_gwas, " × DB: ", args$pop_db, 
                "\n", args$phecode, " PWAS Manhattan Plot (", 
                args$model, " - ", args$data, ")")

#name of saved file
destination_filename <- paste0("gwas_", args$pop_gwas, "_db_", args$pop_db, "_", 
                               args$phecode, "_pwas_manhattan_", 
                               args$model, "_", args$data, ".png")

#use qqman to plot the chromosome, location, snp, and pvalue into manhattan plot
cat("Generating Manhattan plot...\n")
png(filename = destination_filename, width = 1400, height = 900, res = 120)
manhattan(merged_df, 
          chr = "CHR", 
          bp = "start_position", 
          snp = "gene_name", 
          p = "pvalue",
          main = title,
          col = c("darkolivegreen3", "darkolivegreen"),
          suggestiveline = new_suggestive_threshold,
          cex.main = 0.9)
dev.off()

cat("PWAS Manhattan plot saved:", destination_filename, "\n")
cat("Analysis complete!\n")