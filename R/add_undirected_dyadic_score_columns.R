#' Add dyadic-score model (undirected) predictor columns
#'
#' Adds Dyad-Score Model (DSM) style dyad-mean and within-dyad-deviation
#' columns for the predictors recorded in an `interdep_data` object. For
#' currently supported undirected DSMs, the data must contain one exchangeable
#' dyad composition. This means distinguishable dyads and multiple exchangeable
#' compositions are not supported by DSM construction until explicit
#' role-contrast, composition-specific, or pooling support is added.
#' Predictors are constructed and treated identically to the DIM method.
#' The function reads
#' `attr(data, "interdep")$temporal_predictor_decompositions`.
#'
#' @param data An `interdep_data` object returned by [prepare_interdep_data()].
#'
#' @return An `interdep_data` object with dyad-mean and within-dyad-deviation
#'   predictor columns added.
#'
#' @keywords internal
add_undirected_dyadic_score_columns <- function(data) {
  if (!inherits(data, "interdep_data")) {
    stop("`data` must be an `interdep_data` object.", call. = FALSE)
  }

  validate_undirected_dyad_compatibility(data)

  add_dyad_individual_columns(data)
}

# setup_add_undirected_dyadic_score_debug()
