#' Build the Calibration Curve Input Table
#'
#' Combines the Average Peak Area Ratio output to the
#' Concentration Ratio Output
#'
#' Input:
#'   Data:
#'     - data/processed/calibration-curve/average_peak_area_ratio.parquet
#'     - data/processed/calibration-curve/concentration_ratio.parquet
#'
#' Output:
#'   - data/processed/calibration-curve/calibration_curve_input.parquet

library(magrittr)

average_peak_area_ratio_df <- arrow::read_parquet(
  "data/processed/calibration-curve/average_peak_area_ratio.parquet"
)



concentration_ratio_df <- arrow::read_parquet("data/processed/calibration-curve/concentration_ratio.parquet") %>%
  dplyr::select(
    individual_native_analyte_name,
    calibration_level,
    analyte_concentration_ratio
  )

analyte_to_internal_standard_mapping <- arrow::read_parquet(
  "data/processed/mapping/native_analyte_internal_standard_mapping.parquet"
) %>%
  dplyr::select(
    individual_native_analyte_name,
    minimum_limit_of_quantitation = cal_level_loq
  )

average_peak_area_ratio_df %>%
  dplyr::left_join(
    concentration_ratio_df,
    by = c(
      "individual_native_analyte_name",
      "calibration_level"
    )
  ) %>%
  dplyr::left_join(
    analyte_to_internal_standard_mapping,
    by = c("individual_native_analyte_name")
  ) %>%
  # remove calibration levels less than the limit of quantation
  dplyr::filter(
    calibration_level >= minimum_limit_of_quantitation
  ) %>%
  arrow::write_parquet(
    sink = "data/processed/calibration-curve/calibration_curve_input.parquet"
  ) %>%
  readr::write_csv(
    "data/processed/calibration-curve/calibration_curve_input.csv"
  )
