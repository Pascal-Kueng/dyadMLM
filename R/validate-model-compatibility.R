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
    dyad_composition_text <- paste(
      paste0(
        dyad_compositions$composition,
        " (",
        dyad_compositions$dyad_type,
        ", n_dyads = ",
        dyad_compositions$n_dyads,
        ")"
      ),
      collapse = "; "
    )

    stop(
      "DIM and undirected DSM construction currently support only data with exactly one exchangeable dyad composition. ",
      "The prepared data contains unsupported dyad composition metadata: ",
      dyad_composition_text,
      ". ",
      "Use these model types only when partners are exchangeable for your analysis, for example by omitting `role`; ",
      "otherwise use `model_type = \"apim\"`, `model_type = \"none\"`, or use `include_compositions`, ",
      "`set_exchangeable_compositions`, or `pool_compositions` to prepare exactly one exchangeable composition.",
      call. = FALSE
    )
  }

  invisible(data)
}
