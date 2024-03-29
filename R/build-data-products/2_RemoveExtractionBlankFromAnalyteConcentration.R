library(magrittr)

build_blank_filtered_analyte_concentration_table <- function(extraction_blank,
                                                             analyte_concentration,
                                                             file_name) {
  analyte_concentration %>%
    dplyr::left_join(
      extraction_blank,
      by = c(
        "batch_number",
        "individual_native_analyte_name"
      )
    ) %>%
    dplyr::mutate(
      extraction_blank_filtered_analyte_concentration_ng = analyte_concentration_ng - average_extraction_blank_analyte_concentration_ng
    ) %>%
    readr::write_excel_csv(
      paste0(
        "data/processed/build-data-products/extraction_blank_filtered_analyte_concentration_",
        file_name,
        ".csv"
      )
    ) %>%
    arrow::write_parquet(
      paste0(
        "data/processed/build-data-products/extraction_blank_filtered_analyte_concentration_",
        file_name,
        ".parquet"
      )
    )
}

extraction_blank_no_recovery <- arrow::read_parquet(
  "data/processed/build-data-products/average_extraction_blank_ng_no_recovery.parquet"
) %>%
  dplyr::select(
    batch_number,
    individual_native_analyte_name,
    average_extraction_blank_analyte_concentration_ng
  )

analyte_concentration_no_recovery <- arrow::read_parquet(
  "data/processed/quantify-sample/analyte_concentration_no_recovery.parquet"
) %>%
  dplyr::select(
    batch_number,
    cartridge_number,
    analyte_detection_flag,
    calibration_curve_range_category,
    individual_native_analyte_name,
    analyte_concentration_ng
  )

build_blank_filtered_analyte_concentration_table(
  extraction_blank_no_recovery,
  analyte_concentration_no_recovery,
  "no_recovery"
)
