#' Validate undirected dyad compatibility
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
validate_undirected_dyad_compatibility <- function(data) {
  if (!inherits(data, "interdep_data")) {
    stop("`data` must be an `interdep_data` object.", call. = FALSE)
  }

  dyad_compositions <- attr(data, "interdep")$dyad_compositions

  if (nrow(dyad_compositions) != 1L || dyad_compositions$dyad_type[[1]] != "exchangeable") {
    stop(
      "`model_type = \"dim\"` and `model_type = \"undirected_dsm\"` currently require one exchangeable dyad composition. ",
      "Use exchangeable dyads, for example by omitting the `role` argument when ",
      "that matches your research question, or wait for explicit role-contrast, ",
      "composition-specific, or pooling support.",
      call. = FALSE
    )
  }

  invisible(data)
}
