#' This script creates a more streamlined version of
#' the data/source/Native_analyte_ISmatch_source.xlsx for use in
#' calculations.

library(magrittr)

############################
# Get Source Reference Files
###########################

full_file_list <- c(
  "data/source/Native_analyte_ISmatch_source.xlsx",
  "data/source/calibration_concentration_name_mapping.csv"
)

# setting this to false
missing_file <- FALSE

for (file_path in full_file_list) {
  if (!fs::file_exists(file_path)) {
    # if a source file is missing, this will trigger
    # downloading source data from S3
    missing_file <- TRUE
  }
}

# if a file is missing pull source data from S3
if (missing_file) {
  source("R/utility/GetSourceData.R")
} else {
  # if all files are downloaded, skip downloading data
  print("Source Data Downloaded")
}

############################
# Create Native Analyte to Internal Standard Reference File
###########################

readxl::read_excel(
  "data/source/Native_analyte_ISmatch_source.xlsx",
  sheet = "Sheet1"
) %>%
  janitor::clean_names() %>%
  dplyr::select(
    individual_native_analyte_name = processing_method_name,
    internal_standard_name = internal_standard
  ) %>%
  arrow::write_parquet(
    sink = "data/processed/reference/native_analyte_internal_standard_mapping.parquet"
  )

############################
# Create Calibration Analyte Name to Source Analyte Name Reference File
###########################

readr::read_csv("data/source/calibration_concentration_name_mapping.csv") %>%
  janitor::clean_names() %>%
  dplyr::rename(
    source_analyte_name = individual_native_analyte_name,
    individual_native_analyte_name = corresponding_name_in_native_analyte_ismatch_source
  ) %>%
  arrow::write_parquet(
    sink = "data/processed/reference/calibration_concentration_name_mapping.parquet"
  )