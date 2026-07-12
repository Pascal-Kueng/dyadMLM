#' Validate DIM compatibility
#'
#' Checks whether an `interdep_data` object can be used for the currently
#' supported undirected DIM construction. These models
#' currently support only data with exactly one exchangeable dyad composition. Distinguishable or
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
      "DIM currently supports only data with exactly one exchangeable dyad composition. ",
      "The prepared data contains unsupported dyad composition metadata: ",
      dyad_composition_text,
      ". ",
      "Use this model type only when partners are exchangeable for your analysis, for example by omitting `role`; ",
      "otherwise use `model_type = \"apim\"`, `model_type = \"dsm\"`, `model_type = \"none\"`, or use `include_compositions`, ",
      "`set_exchangeable_compositions`, or `pool_compositions` to prepare exactly one exchangeable composition.",
      call. = FALSE
    )
  }

  invisible(data)
}

#' Validate DSM compatibility
#'
#' Checks whether prepared data contain the single distinguishable dyad
#' composition required by the DSM and whether its observed roles match the
#' declared directional role order.
#'
#' @param data An `interdep_data` object after composition inference.
#'
#' @return Invisibly returns `data` when compatible.
#'
#' @keywords internal
validate_dsm_compatibility <- function(data) {
  if (!inherits(data, "interdep_data")) {
    stop("`data` must be an `interdep_data` object.", call. = FALSE)
  }

  meta <- attr(data, "interdep")
  dyad_compositions <- meta$dyad_compositions

  if (nrow(dyad_compositions) != 1L ||
      dyad_compositions$dyad_type[[1]] != "distinguishable") {
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
      "DSM currently supports only data with exactly one distinguishable dyad composition. ",
      "The prepared data contains unsupported dyad composition metadata: ",
      dyad_composition_text,
      ".",
      call. = FALSE
    )
  }

  # The two supplied roles must exactly be the two sole unique roles in the data!
  observed_roles <- unique(as.character(data[[meta$role]]))
  if (!setequal(meta$dsm_role_order, observed_roles)) {
    stop(
      "`dsm_role_order` must contain exactly the two role values in the prepared DSM data. ",
      "Observed role(s): ",
      paste(sort(observed_roles), collapse = ", "),
      ". Supplied role order: ",
      paste(meta$dsm_role_order, collapse = " - "),
      ".",
      call. = FALSE
    )
  }

  invisible(data)
}
