#' Add dyadic-score model predictor columns and contrast
#'
#' Adds Dyadic Score Model (DSM) dyad-mean and signed dyad-difference columns
#' for the predictors recorded in an `interdep_data` object, together with a
#' DSM role contrast coded `+0.5` and `-0.5`. DSM differences follow the role
#' order recorded in `attr(data, "interdep")$dsm_role_order`. The supported DSM
#' structure contains one distinguishable dyad composition; exchangeable dyads
#' and multiple compositions are not supported.
#'
#' For ILD predictors, raw and within-person scores are computed within
#' dyad-time and between-person scores within dyad. Raw dyad means are
#' grand-mean centered. Both partners' predictor values are required for each
#' score pair.
#' Selected lag predictors additionally create lag-1 raw and within-person
#' dyad-mean and signed-difference columns.
#'
#' Constructed predictor columns are recorded in
#' `attr(data, "interdep")$dsm_predictors`, and the contrast column name is
#' recorded in `attr(data, "interdep")$dsm_role_contrast_column`.
#'
#' @param data An `interdep_data` object returned by [prepare_interdep_data()].
#'
#' @return An `interdep_data` object with dyad-mean and signed dyad-difference
#'   predictor columns and a DSM role contrast added.
#'
#' @keywords internal
add_dyadic_score_columns <- function(data) {
  if (!inherits(data, "interdep_data")) {
    stop("`data` must be an `interdep_data` object.", call. = FALSE)
  }

  validate_dsm_compatibility(data)

  meta_data <- attr(data, "interdep")
  dsm_role_order <- meta_data$dsm_role_order
  role <- meta_data$role

  data[[interdep_dsm_role_contrast_col]] <- ifelse(
    as.character(data[[role]]) == dsm_role_order[[1]],
    0.5,
    -0.5
  )

  decomposition <- construct_dyad_predictor_decompositions(data)

  out <- decomposition$data
  n_predictors <- nrow(decomposition$predictors)
  difference_cols <- character(n_predictors)

  for (i in seq_len(n_predictors)) {
    predictor <- decomposition$predictors$predictor[[i]]
    component <- decomposition$predictors$component[[i]]
    lag <- decomposition$predictors$lag[[i]]
    source_col <- decomposition$predictors$source_column[[i]]
    deviation_col <- decomposition$predictors$deviation_column[[i]]

    column_stem <- make_dyad_predictor_column_stem(
      predictor = predictor,
      component = component,
      source_col = source_col,
      lag = lag
    )
    difference_col <- paste0(
      column_stem,
      "_within_dyad_diff",
      make_predictor_lag_suffix(lag)
    )

    difference_cols[[i]] <- difference_col

    # Deviation = role contrast * full directional difference, so division
    # recovers the same role-1-minus-role-2 score on both member rows.
    out[[difference_col]] <-
      out[[deviation_col]] / out[[interdep_dsm_role_contrast_col]]
  }

  # Replace intermediate deviation metadata with DSM difference metadata.
  dsm_predictors <- decomposition$predictors |>
    dplyr::mutate(
      difference_column = difference_cols,
      .after = "mean_column"
    ) |>
    dplyr::select(-"deviation_column")

  # Remove the intermediate deviation columns from DSM output.
  deviation_cols <- decomposition$predictors$deviation_column
  if (length(deviation_cols) > 0) {
    out[deviation_cols] <- NULL
  }

  attr(out, "interdep")$dsm_predictors <- dsm_predictors
  attr(out, "interdep")$dsm_role_contrast_column <- interdep_dsm_role_contrast_col

  out
}

# setup_add_dyadic_score_debug()
