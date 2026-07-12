#' Add dyadic-score model predictor columns and contrast
#'
#' Adds Dyadic Score Model (DSM) dyad-mean and signed dyad-difference columns
#' for the predictors recorded in an `interdep_data` object, together with a
#' DSM role contrast coded `+0.5` and `-0.5`. DSM differences follow the role
#' order recorded in `attr(data, "interdep")$dsm_role_order`. The supported DSM
#' structure contains one distinguishable dyad composition; exchangeable dyads
#' and multiple compositions are not supported.
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

  # validate_undirected_dyad_compatibility(data) # probably not needed, and we need to validate
  # with a new function in the same file that it is a single type of distinguishable, right?

  add_dyad_individual_columns(data)
}

# setup_add_dyadic_score_debug()
