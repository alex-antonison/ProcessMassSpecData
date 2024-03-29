#' Calculate the calibration Curve
#'
#' This is done with the following calculation
#'
#' y = average_peak_area_ratio
#' x = analyte_concentration_rate
#'
#' lm(y ~ x)

library(magrittr)

calibration_curve_input_df <- arrow::read_parquet(
  "data/processed/calibration-curve/calibration_curve_input.parquet"
)

# clear out calibration curve troubleshoot from previous run
debug_file_list <- c(
  "data/processed/calibration-curve/temp_successful_calibration_curve.csv",
  "data/processed/calibration-curve/temp_recovery_calc.csv",
  "data/processed/calibration-curve/calibration_recovery_troubleshoot.csv",
  "data/processed/calibration-curve/calibration_curve_troublehsoot.csv"
)
for (file in debug_file_list) {
  if (fs::file_exists(file)) fs::file_delete(file)
}

#' This function takes care of initializing a debugging table
#' with a header column
#' and once created, it will then continue to append rows to the file.
#' @param df The troubleshoot df to be stored to a csv
#' @param filename The path and name of the file to be saved out
build_trouble_shoot_file <- function(df, filename) {
  if (!fs::file_exists(filename)) {
    readr::write_csv(
      df,
      filename
    )
  } else {
    readr::write_csv(
      df,
      filename,
      append = TRUE
    )
  }
}

#' This function removes either the lowest or highest
#' calibration level based on what
#' was was previously removed. It will start off with removing the lowest range.
#' @param df The dataframe included the calibration levels for a single analyte
#' @param min_flag This is used to indicate whether or not the lowest
#' or highest calibration
#' level should be removed.
remove_cal_level <- function(df, min_flag) {
  if (min_flag) {
    remove_val <- min(df$calibration_level)
    min_flag <- FALSE
  } else {
    remove_val <- max(df$calibration_level)
    min_flag <- TRUE
  }

  df <- df %>%
    dplyr::filter(calibration_level != remove_val) # nolint

  return(list(df, min_flag, remove_val))
}

#' This function will iterate through the different calibration levels
#' when calculating the calibration curve. If a calibration range
#' does not have an R^2 > 0.99, it will remove the upper or lower calibration
#' range and then re-fit the remaining calibration ranges.
#' @param df The calibration curve input dataframe
#' @param run_count A variable used for debugging purposes
calculate_calibration_curve <- function(df,
                                        run_count,
                                        remove_cal_level) {
  # initialize min flag to true so it starts off with removing the lowest
  # calibration first
  min_flag <- TRUE
  # initialize the removed calibration levels so it can be appended to
  removed_calibration <- ""
  # set iteration count to 1 and it will increment as there are multiple
  # iterations
  iteration <- 1
  # capture the current batch number so it can be added to the
  # troubleshoot output file
  batch_number <- unique(df$batch_number)
  analyte_name <- unique(df$individual_native_analyte_name)

  for (calibration_level in df$calibration_level) {
    # use R's built in linear model function
    cur_model <- lm(average_peak_area_ratio ~ analyte_concentration_ratio,
      data = df
    )

    # pull r.squared from R summary of model
    r_squared <- summary(cur_model)$r.squared

    # when calculating the calibration curve after the recovery values,
    # we do not want to remove any calibration levels. If there is an instance
    # where an r-squared changes to below 0.99 after recovery values are removed
    # this is considered an error case that needs to be investigated.
    if (r_squared < 0.99 & remove_cal_level) {
      # set remove calibration flag to true to indicate an analyte
      # has had a calibration removed from it
      removed_calibration_flag <- TRUE
      return_val <- remove_cal_level(df, min_flag)
      df <- return_val[[1]]
      min_flag <- return_val[[2]]
      remove_val <- return_val[[3]]
      removed_calibration <- paste(removed_calibration, remove_val, sep = ",")

      cur_eval_df <- dplyr::tibble(
        batch_number = batch_number,
        individual_native_analyte_name = analyte_name,
        iteration_count = iteration,
        removed_calibration_level = remove_val,
        min_calibration_range = min(df$calibration_level),
        max_calibration_range = max(df$calibration_level),
        calibration_range = paste0(min(df$calibration_level), ":", max(df$calibration_level)),
        r_squared = r_squared,
        current_removed_calibration = stringr::str_sub(removed_calibration, start = 2),
        run_count = run_count
      )

      # this will check to see if the file exists and if it doesn't,
      # create the file with headers. if it does exist, it will append
      build_trouble_shoot_file(
        cur_eval_df,
        "data/processed/calibration-curve/calibration_curve_troublehsoot.csv"
      )

      iteration <- iteration + 1
    } else {
      cf <- coef(cur_model)

      analyte_calibration_curve <- df %>%
        dplyr::mutate(
          batch_number,
          individual_native_analyte_name = analyte_name,
          slope = cf[["analyte_concentration_ratio"]],
          y_intercept = cf[["(Intercept)"]],
          r_squared = r_squared,
          calibration_point = nrow(df),
          min_calibration_range = min(df$calibration_level),
          max_calibration_range = max(df$calibration_level),
          calibration_range = paste0(min(df$calibration_level), ":", max(df$calibration_level)),
          removed_calibrations = stringr::str_sub(removed_calibration, start = 2),
          minimum_average_peak_area_ratio = min(df$average_peak_area_ratio),
          maximum_average_peak_area_ratio = max(df$average_peak_area_ratio),
          run_count = run_count
        )

      return(analyte_calibration_curve)
    }
  }
}

#' Function for iterating over all analytes and calculating calibration curves
#' @param df A dataframe that should include 1 batch of analytes
#' @param run_count A variable used for debugging purposes
run_calibration_curve <- function(df, run_count, remove_cal_level) {
  # build a list of analyte names
  analyte_name_df <- df %>%
    dplyr::distinct(
      individual_native_analyte_name
    )

  calc_cal_curve_df <- dplyr::tibble()

  for (analyte in analyte_name_df$individual_native_analyte_name) {
    # filter dataframe down to only a single analyte for calculation
    input_df <- df %>%
      dplyr::filter(
        individual_native_analyte_name == analyte
      )

    calc_cal_curve_temp <- calculate_calibration_curve(
      input_df,
      run_count,
      remove_cal_level
    )

    calc_cal_curve_df <- dplyr::bind_rows(
      calc_cal_curve_temp,
      calc_cal_curve_df
    )
  }

  return(calc_cal_curve_df)
}

#' This function takes care of running the calibration curve function and takes the output
#' and calculates the recovery values for each calibration level. If a calibration level
#' has a 0.8 <= recovery value <= 1.2 it is successful, if not it fails and is removed
#' from the dataframe. This will require re-calculating the calibration curve if values
#' are removed
#' @param df The calibration curve input dataframe
calculate_recovery_value <- function(df) {
  # calculate the recovery values and store in a temp dataframe to then
  # filter passing and failing values into different dataframes
  recovery_cal_curve_temp <- df %>%
    dplyr::mutate(
      experimental_concentration_ratio = (average_peak_area_ratio - y_intercept) / slope,
      recovery = experimental_concentration_ratio / analyte_concentration_ratio
    )

  # filter down to only passing recovery values
  recovery_cal_curve_eval <- recovery_cal_curve_temp %>%
    dplyr::filter(
      recovery >= 0.8 & recovery <= 1.2
    )

  # filter down recovery failed recovery values for troubleshooting purposes
  recovery_cal_curve_troubleshoot <- recovery_cal_curve_temp %>%
    dplyr::filter(
      recovery < 0.8 | recovery > 1.2
    ) %>%
    dplyr::mutate(
      run_count = run_count
    )

  # if any values get removed because of out of bounds recovery values
  # need to set removed calibration_flag to true
  if (nrow(recovery_cal_curve_troubleshoot) > 0) {
    build_trouble_shoot_file(
      recovery_cal_curve_troubleshoot,
      "data/processed/calibration-curve/calibration_recovery_troubleshoot.csv"
    )
  }

  return(recovery_cal_curve_eval)
}

################################################################
# Control Loop for running functions across different batches
################################################################

# build a list of batches
batch_df <- calibration_curve_input_df %>%
  dplyr::distinct(
    batch_number
  )

# initialize final output dataframe
complete_cal_curve_output <- dplyr::tibble()
cal_curve_non_recovery_output <- dplyr::tibble()

for (batch in batch_df$batch_number) {
  # initialize run values values
  single_batch_analyte_df <- calibration_curve_input_df %>%
    # process one batch at a time
    dplyr::filter(
      batch_number == batch
    )

  calc_cal_curve_df <- run_calibration_curve(
    single_batch_analyte_df,
    run_count = 1,
    remove_cal_level = TRUE
  )

  cal_curve_non_recovery_output <- dplyr::bind_rows(
    cal_curve_non_recovery_output,
    calc_cal_curve_df
  )

  calc_recovery_value_df <- calculate_recovery_value(calc_cal_curve_df)


  # do not want to remove calibration levels, just want to re-calculate
  # the R Squared, Y Intercept, and Slope
  # If it has an R Squared less than 0.99, this is an error that requires
  # investigation
  final_slope_intercept_calc_df <- run_calibration_curve(
    calc_recovery_value_df,
    run_count = 2,
    remove_cal_level = FALSE
  )


  complete_cal_curve_output <- dplyr::bind_rows(
    complete_cal_curve_output,
    final_slope_intercept_calc_df
  )
}

cal_curve_non_recovery_output %>%
  arrow::write_parquet(
    sink = "data/processed/calibration-curve/calibration_curve_output_no_recov_filter.parquet"
  ) %>%
  readr::write_csv(
    "data/processed/calibration-curve/calibration_curve_output_no_recov_filter.csv"
  )

complete_cal_curve_output %>%
  arrow::write_parquet(
    sink = "data/processed/calibration-curve/calibration_curve_output_with_recov.parquet"
  ) %>%
  readr::write_csv(
    "data/processed/calibration-curve/calibration_curve_output_with_recov.csv"
  )
