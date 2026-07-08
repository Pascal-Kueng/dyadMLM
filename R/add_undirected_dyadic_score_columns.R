#' Add dyadic-score model (undirected) predictor and outcome columns
#'
#' Adds Dyad-Score Model (DSM) style dyad-mean and within-dyad-deviation
#' columns for the predictors and outcomes recorded in an `interdep_data` object. For
#' currently supported undirected DSMs, the data must contain one exchangeable
#' dyad composition. This means distinguishable dyads and multiple exchangeable
#' compositions are not supported by DSM construction until explicit
#' role-contrast, composition-specific, or pooling support is added.
#' Predictors are constructed and treated identically do the DIM method. The outcome
#' is treated the same as cross-sectional raw DIM predictors and is not temporally
#' decomposed. Instead, a raw dyad mean and difference is created at each time-point.
#'
#' The function reads `attr(data, "interdep")$temporal_predictor_decompositions` and
#' stores the constructed DSM columns in
#' `attr(data, "interdep")$undirected_dsm_predictors`.
#'
#' @param data An `interdep_data` object returned by [prepare_interdep_data()].
#'
#' @return An `interdep_data` object with dyad-mean and within-dyad-deviation
#'   predictor columns added and DSM predictor metadata recorded.
#'
#' @keywords internal
add_undirected_dyadic_score_columns <- function(data) {
  if (!inherits(data, "interdep_data")) {
    stop("`data` must be an `interdep_data` object.", call. = FALSE)
  }

  # Handle predictors
  out <- add_dyad_individual_columns(data)

  # Handle outcomes
  meta_data <- attr(out, "interdep")

  group <- meta_data$group
  member <- meta_data$member
  outcomes <- meta_data$outcomes

  # necessary or advisable to add this as atable just like the predictor decomp and temporal decomp tables??
  # Even if the DIM is likely the only model that needs decomp (but also the directed later.)?
  dsm_outcomes <- tibble::tibble(
      outcome = character(),
      source_column = character(),
      mean_column = character(),
      deviation_column = character()
    )

  for (outcome in outcomes) {
    print(outcome)
  }

  return(out)

}

# setup_add_undirected_dyadic_score_debug()
