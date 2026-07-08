#' Validate non-directed DIM/DSM compatibility
#'
#' Checks whether an `interdep_data` object can be used for the currently
#' supported non-directed DIM or undirected DSM construction. These models
#' require `.i_diff` to be nonzero for every retained row, so distinguishable
#' dyads are rejected until explicit role-contrast or pooling support is added.
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

  temporal_predictor_decompositions <- attr(data, "interdep")$temporal_predictor_decompositions

  if (is.null(temporal_predictor_decompositions) || nrow(temporal_predictor_decompositions) == 0) {
    return(invisible(data))
  }

  if (any(data[[interdep_diff_col]] %in% 0)) {
    stop(
      "`model_type = \"dim\"` and `model_type = \"undirected_dsm\"` currently support only non-directed models. ",
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
