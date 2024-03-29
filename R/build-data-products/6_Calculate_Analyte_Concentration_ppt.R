library(magrittr)

extraction_batch_source <- arrow::read_parquet(
  "data/processed/reference/extraction_batch_source.parquet"
)

final_filtered_analyte_concentration <- arrow::read_parquet(
  "data/processed/build-data-products/final_filtered_analyte_concentration_no_recovery.parquet"
)

analyte_concentration_ppt <- final_filtered_analyte_concentration %>%
  dplyr::left_join(
    extraction_batch_source,
    by = c(
      "batch_number",
      "cartridge_number"
    )
  ) %>%
  # filter to just QC Samples
  dplyr::filter(
    county != "Fresh Water QC" & county != "Salt Water QC" & county != "Field Blank" & county != "Extraction Blank"
  ) %>%
  dplyr::mutate(
    analyte_concentration_ppt = (final_filtered_analyte_concentration_ng / sample_mass_g) * 1000
  ) %>%
  dplyr::select(
    batch_number,
    cartridge_number,
    county,
    sample_id,
    coordinates,
    individual_native_analyte_name,
    final_filtered_analyte_concentration_ng,
    sample_mass_g,
    analyte_concentration_ppt
  ) %>%
  readr::write_excel_csv(
    "data/processed/build-data-products/analyte_concentration_ppt.csv"
  ) %>%
  arrow::write_parquet(
    sink = "data/processed/build-data-products/analyte_concentration_ppt.parquet"
  )
