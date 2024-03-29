library(magrittr)

build_extraction_blank_table <- function(extraction_batch_source,
                                         analyte_concentration_df,
                                         file_name) {
  analyte_peak_area <- analyte_concentration_df %>%
    dplyr::select(
      batch_number,
      cartridge_number,
      individual_native_analyte_name,
      analyte_detection_flag,
      internal_standard_name,
      internal_standard_detection_flag,
      calibration_curve_range_category,
      analyte_concentration_ng,
      limit_of_detection_concentration_ng
    )

  analyte_peak_area %>%
    dplyr::left_join(
      extraction_batch_source,
      by = c("batch_number", "cartridge_number")
    ) %>%
    # filter down to Extraction Blanks
    dplyr::filter(stringr::str_detect(county, "Extraction Blank")) %>%
    dplyr::mutate(
      # run logic for alternate analyte_concentration_ng for extraction blanks
      new_analyte_concentration_ng = dplyr::case_when(
        (!analyte_detection_flag) ~ 0.0,
        calibration_curve_range_category == "<LOD" ~ 0.0,
        calibration_curve_range_category == "<LOQ" ~ (limit_of_detection_concentration_ng / (2^0.5))
      ),
      # merge the new value to the existing
      analyte_concentration_ng = dplyr::if_else(
        is.na(new_analyte_concentration_ng),
        analyte_concentration_ng,
        new_analyte_concentration_ng
      )
    ) %>%
    dplyr::group_by(
      batch_number,
      individual_native_analyte_name
    ) %>%
    dplyr::summarise(
      average_extraction_blank_analyte_concentration_ng = mean(analyte_concentration_ng),
      std_dev_extraction_blank_analyte_concentration_ng = sd(analyte_concentration_ng),
      percent_rsd_extraction_blank_analyte_concentration_ng = (std_dev_extraction_blank_analyte_concentration_ng / average_extraction_blank_analyte_concentration_ng) * 100,
      .groups = "keep"
    ) %>%
    dplyr::select(
      batch_number,
      individual_native_analyte_name,
      average_extraction_blank_analyte_concentration_ng,
      std_dev_extraction_blank_analyte_concentration_ng,
      percent_rsd_extraction_blank_analyte_concentration_ng
    ) %>%
    arrow::write_parquet(
      sink = paste0("data/processed/build-data-products/average_extraction_blank_ng_", file_name, ".parquet")
    ) %>%
    readr::write_excel_csv(
      paste0("data/processed/build-data-products/average_extraction_blank_ng_", file_name, ".csv")
    )
}

extraction_batch_source <- arrow::read_parquet(
  "data/processed/reference/extraction_batch_source.parquet"
)

analyte_concentration_no_recovery <- arrow::read_parquet(
  "data/processed/quantify-sample/analyte_concentration_no_recovery.parquet"
)

build_extraction_blank_table(
  extraction_batch_source,
  analyte_concentration_no_recovery,
  "no_recovery"
)
