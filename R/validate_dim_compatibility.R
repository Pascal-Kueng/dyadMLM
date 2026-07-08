#' Validate undirected DIM/DSM compatibility
#'
#' Checks whether an `interdep_data` object can be used for the currently
#' supported undirected DIM or undirected DSM construction. These models
#' currently require one exchangeable dyad composition. Distinguishable or
#' multiple exchangeable compositions are rejected until explicit role-contrast,
#' composition-specific, or pooling support is added.
#'
#' @param data An `interdep_data` object after composition inference.
#'
#' @return Invisibly returns `data` when compatible.
#'
#' @keywords internal
validate_dim_compatibility <- function(data) {
  if (!inherits(data, "interdep_data")) {
    stop("`data` must be an `interdep_data` object.", call. = FALSE)
  }

  meta_data <- attr(data, "interdep")
  temporal_predictor_decompositions <- meta_data$temporal_predictor_decompositions
  model_type <- meta_data$model_type

  has_dim_predictors <- !is.null(temporal_predictor_decompositions) &&
    nrow(temporal_predictor_decompositions) > 0
  has_dsm_outcomes <- "undirected_dsm" %in% model_type

  if (!has_dim_predictors && !has_dsm_outcomes) {
    return(invisible(data))
  }

  dyad_compositions <- meta_data$dyad_compositions

  if (nrow(dyad_compositions) != 1L || dyad_compositions$dyad_type[[1]] != "exchangeable") {
    stop(
      "`model_type = \"dim\"` and `model_type = \"undirected_dsm\"` currently require one exchangeable dyad composition. ",
      "Use exchangeable dyads, for example by omitting the `role` argument when ",
      "that matches your research question, or wait for explicit role-contrast, ",
      "composition-specific, or pooling support.",
      call. = FALSE
    )
  }

  if (any(data[[interdep_diff_col]] %in% 0)) {
    stop(
      "`model_type = \"dim\"` and `model_type = \"undirected_dsm\"` currently support only undirected models. ",
      "For these models, `.i_diff` must be nonzero for every retained row. ",
      "Your data include distinguishable dyads, where `.i_diff` is 0 by construction. ",
      "Use exchangeable dyads, for example by omitting the `role` argument when ",
      "that matches your research question, or wait for explicit role-contrast ",
      "or pooling support.",
      call. = FALSE
    )
  }

  invisible(data)
}
