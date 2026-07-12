#' Add dyadic-score model predictor columns and contrast
#'
#' Adds Dyad-Score Model (DSM) style dyad-mean and within-dyad-deviation
#' columns for the predictors recorded in an `interdep_data` object, which
#' is equivalent to the DIM method. For currently supported DSMs,
#' the data must contain one single distinguishable dyad composition. This means
#' exchangeable dyads and multiple compositions are not supported by DSM yet.
#' The function reads
#' `attr(data, "interdep")$temporal_predictor_decompositions`.
#'
#' @param data An `interdep_data` object returned by [prepare_interdep_data()].
#'
#' @return An `interdep_data` object with dyad-mean and signed within-dyad
#'   deviations predictor columns added.
#'
#' @keywords internal
add_dyadic_score_columns <- function(data) {
  if (!inherits(data, "interdep_data")) {
    stop("`data` must be an `interdep_data` object.", call. = FALSE)
  }

  # validate_undirected_dyad_compatibility(data) # probably not needed, and we need to validate
  # with a new function in the same file that it is a single type of distinguishable, right?

  add_dyad_individual_columns(data)
}

# setup_add_dyadic_score_debug()
