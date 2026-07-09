#' Add dyadic-score model (undirected) predictor and outcome columns
#'
#' Adds Dyad-Score Model (DSM) style dyad-mean and within-dyad-deviation
#' columns for the predictors and outcomes recorded in an `interdep_data` object. For
#' currently supported undirected DSMs, the data must contain one exchangeable
#' dyad composition. This means distinguishable dyads and multiple exchangeable
#' compositions are not supported by DSM construction until explicit
#' role-contrast, composition-specific, or pooling support is added.
#' Predictors are constructed and treated identically to the DIM method.
#' Outcomes are not temporally decomposed or grand-mean centered. Instead, a raw
#' dyad mean and difference is created at each time-point.
#'
#' The function reads `attr(data, "interdep")$temporal_predictor_decompositions` and
#' stores the constructed outcome columns in
#' `attr(data, "interdep")$undirected_dsm_outcomes`.
#'
#' @param data An `interdep_data` object returned by [prepare_interdep_data()].
#'
#' @return An `interdep_data` object with dyad-mean and within-dyad-deviation
#'   predictor and outcome columns added and DSM outcome metadata recorded.
#'
#' @keywords internal
add_undirected_dyadic_score_columns <- function(data) {
  if (!inherits(data, "interdep_data")) {
    stop("`data` must be an `interdep_data` object.", call. = FALSE)
  }

  validate_undirected_dyad_compatibility(data)

  # Handle predictors
  out <- add_dyad_individual_columns(data)

  # Handle outcomes
  meta_data <- attr(out, "interdep")

  group <- meta_data$group
  member <- meta_data$member
  has_time <- meta_data$longitudinal
  time <- meta_data$time
  outcomes <- meta_data$outcomes

  # Prepare empty tibble
  dsm_outcomes <- tibble::tibble(
    outcome = character(),
    source_column = character(),
    mean_column = character(),
    deviation_column = character(),
    decomposition_level = character()
  )

  for (outcome in outcomes) {
    source_col <- outcome
    outcome_suffix <- make_interdep_suffixes(outcome)[[outcome]]
    column_stem <- paste0(interdep_reserved_prefix, outcome_suffix, "_raw")
    mean_col <- paste0(column_stem, "_dyad_mean")
    deviation_col <- paste0(column_stem, "_within_dyad_deviation")
    decomposition_level <- "dyad"
    if (has_time) {
      decomposition_level <- "dyad_time"
    }

    # update tibble
    dsm_outcomes <- tibble::add_row(
      dsm_outcomes,
      outcome = outcome,
      source_column = source_col,
      mean_column = mean_col,
      deviation_column = deviation_col,
      decomposition_level = decomposition_level
    )

    if (has_time) {
      # from DIM constructor.
      # does not center, in DIM we pass already centered values, so works perfectly here.
      out <- add_dyad_time_decomposition(
        out = out,
        group = group,
        member = member,
        time = time,
        source_col = source_col,
        mean_col = mean_col,
        deviation_col = deviation_col
      )
    } else {
      # from DIM constructor
      # need to center_mean = FALSE to avoid grand-mean centering.
      out <- add_dyad_level_decomposition(
        out = out,
        group = group,
        member = member,
        source_col = source_col,
        mean_col = mean_col,
        deviation_col = deviation_col,
        center_mean = FALSE
      )
    }
  }

  attr(out, "interdep")$undirected_dsm_outcomes <- dsm_outcomes

  return(out)

}

# setup_add_undirected_dyadic_score_debug()
