#!/usr/bin/R

cat("Beginning table formatting...")

#if needed, install packages
if (!requireNamespace("data.table", quietly = TRUE)) install.packages("data.table")
if (!requireNamespace("dplyr", quietly = TRUE)) install.packages("dplyr")
if (!requireNamespace("tidyr", quietly = TRUE)) install.packages("tidyr")
if (!requireNamespace("argparse", quietly = TRUE)) install.packages("argparse")

#load packages
library(data.table)
library(dplyr)
library(tidyr)
library(argparse)

#set up argparse
parser <- ArgumentParser()
parser$add_argument("--phecode", help="all of us phenotype ID")
parser$add_argument("--pop", help="all of us population ID")

args <- parser$parse_args()

#find bucket
my_bucket <- Sys.getenv('WORKSPACE_BUCKET')

#PERFORM COMMAND LINE FORMATTING FOR S-PREDIXCAN FILE
#upload SNP file to workspace bucket
command7 <- paste0("gsutil -m cp -v ~/mesa_pwas/predixcan_models_varids-effallele_mesa.txt.gz ", my_bucket, "/data/")
system(command7, intern=TRUE)

#unzip files
command8 <- paste0("gsutil cat ", my_bucket, "/data/predixcan_models_varids-effallele_mesa.txt.gz | gunzip > /tmp/predixcan_models_varids-effallele_mesa.txt")
system(command8)

#format reference file
system("awk -F'[,:]' 'NR>1 {print $1\":\"$2}' /tmp/predixcan_models_varids-effallele_mesa.txt > /tmp/chrpos_allele_table.tsv", intern=TRUE)

#make temp files
command9 <- paste0("gsutil cp ", my_bucket, "/data/", args$pop, "_full_", args$phecode,".tsv /tmp/")
system(command9)

#filter SNPs
command10 <- paste0("awk 'NR==FNR{a[$1];next} $1 in a' /tmp/chrpos_allele_table.tsv /tmp/", args$pop, "_full_", args$phecode, ".tsv > /tmp/mesa_", args$phecode, ".tsv")
system(command10)

#save to bucket
command11 <- paste0("gsutil cp /tmp/mesa_", args$phecode, ".tsv ", my_bucket, "/data/", args$pop, "_mesa_", args$phecode,".tsv")
system(command11)

#check bucket
check_result2 <- system(paste0("gsutil ls ", my_bucket, "/data/ | grep ", args$pop, "_mesa_", args$phecode, ".tsv"), ignore.stderr = TRUE)

if (check_result2 != 0) {
 stop(paste0("ERROR: File '", args$pop, "_mesa_", args$phecode, ".tsv' was not found in bucket ", my_bucket, "/data/"))
} else {
 cat("Reference mesa file successfully transferred to bucket.\n")
}

#FORMAT TABLES
#read in mesa filtered table
name_of_mesa_file <- paste0(args$pop, "_mesa_", args$phecode, ".tsv")
mesa_command <- paste0("gsutil cp ", my_bucket, "/data/", name_of_mesa_file, " .")

system(mesa_command, intern=TRUE)

mesa_table <- fread(name_of_mesa_file, header=FALSE, sep="\t")
colnames(mesa_table) <- c("locus","alleles","BETA","SE","Het_Q","Pvalue","Pvalue_log10","CHR","POS","rank","Pvalue_expected","Pvalue_expected_log10")

#check table
cat("MESA filtered table preview:\n")
head(mesa_table)

#MESA TABLE
#reformat locus column to chr_pos_ref_alt_b38
mesa_table$locus_formatted <- gsub(":", "_", mesa_table$locus) #colon to underscore
mesa_table$alleles_formatted <- gsub('\\["', "", mesa_table$alleles)  #remove opening [
mesa_table$alleles_formatted <- gsub('"\\]', "", mesa_table$alleles_formatted)  #remove closing ]
mesa_table$alleles_formatted <- gsub('","', "_", mesa_table$alleles_formatted)  #comma to underscore

#split allele column
mesa_table <- mesa_table %>%
  separate(alleles_formatted, into = c("REF", "ALT"), sep = "_", remove=F)

#combine strings
mesa_table$SNP <- paste0(mesa_table$locus_formatted, "_", mesa_table$alleles_formatted, "_b38")
mesa_table$ID <- paste0(mesa_table$locus, ":", mesa_table$REF, ":", mesa_table$ALT)

#remove intermediate columns
mesa_table$locus_formatted <- NULL
mesa_table$alleles_formatted <- NULL

#edit sex chromosomes
mesa_table$CHR <- gsub("X", "23", mesa_table$CHR)
mesa_table$CHR <- gsub("Y", "24", mesa_table$CHR)

#FINAL FORMATTING
#format chromosomes
mesa_table$CHR <- gsub("chr", "", mesa_table$CHR)
mesa_table$CHR <- gsub("X", "23", mesa_table$CHR)
mesa_table$CHR <- gsub("Y", "24", mesa_table$CHR)

#make numeric
mesa_table$CHR <- as.numeric(mesa_table$CHR)

#sort by chr, pos
merged_mesa_table <- merged_mesa_table %>%
  arrange(CHR, POS)

#rename header
merged_mesa_table$"#CHROM" <- merged_mesa_table$CHR
merged_mesa_table$CHR <- NULL

#select columns
merged_mesa_table <- merged_mesa_table %>%
  select(locus, alleles, ID, REF, ALT, "#CHROM", BETA, SE, Pvalue, SNP, ID)

#edit X chromosome SNP file for mesa table
mesa_table$SNP <- gsub("^chrX_", "X_", mesa_table$SNP)

#edit locus column for pvalue filtered table
filtered_merged_table$locus <- gsub("^chrX:", "X:", filtered_merged_table$locus)

#check tables
cat("Final MESA filtered table:\n")
head(merged_mesa_table)

#write mesa table
mesa_destination_filename <- paste0(args$pop, "_formatted_mesa_", args$phecode,".tsv")

#store the dataframe in current workspace
write.table(merged_mesa_table, mesa_destination_filename, col.names=TRUE, row.names=FALSE, quote=FALSE, sep="\t")

#copy the file from current workspace to the bucket
system(paste0("gsutil cp ./", mesa_destination_filename, " ", my_bucket, "/data/"), intern=TRUE)

#CHECK IF FILES ARE IN THE BUCKET
#mesa file
check_mesa <- system(paste0("gsutil ls ", my_bucket, "/data/ | grep ", mesa_destination_filename), ignore.stderr = TRUE)

if (check_mesa != 0) {
  stop(paste0("ERROR: File '", mesa_destination_filename, "' was not found in bucket ", my_bucket, "/data/"))
} else {
  cat("MESA formatted file successfully saved to bucket.\n")
}

#clean up tmp files
system(paste0("rm -f /tmp/subset_", args$phecode, ".tsv /tmp/nochr", args$phecode, ".tsv /tmp/", args$phecode, "ref.vcf /tmp/predixcan_models_varids-effallele_mesa.txt /tmp/chrpos_allele_table.tsv /tmp/", args$pop, "_full_", args$phecode, ".tsv /tmp/mesa_", args$phecode, ".tsv"), intern=TRUE)