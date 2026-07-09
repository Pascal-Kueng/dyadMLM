#' Validate undirected dyad compatibility
#'
#' Checks whether an `interdep_data` object can be used for the currently
#' supported undirected DIM or undirected DSM construction. These models
#' currently support only data with exactly one exchangeable dyad composition. Distinguishable or
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
      "DIM and undirected DSM construction currently support only data with exactly one exchangeable dyad composition. ",
      "The prepared data contains unsupported dyad composition metadata. ",
      "Use these model types only when partners are exchangeable for your analysis, for example by omitting `role`; ",
      "otherwise use `model_type = \"apim\"`, `model_type = \"none\"`, or subset to one exchangeable composition.",
      call. = FALSE
    )
  }

  invisible(data)
}
