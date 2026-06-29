#' Infer dyad compositions
#'
#' Builds a dyad-level summary of role compositions from a validated
#' `interdep_data` object.
#'
#' @param data An `interdep_data` object returned by [validate_interdep_data()].
#'
#' @return An `interdep_data` object with added `.interdep_raw_composition`,
#'   `.interdep_composition`, and `.interdep_composition_role` columns and dyad
#'   composition metadata.
#'
#' @keywords internal
infer_dyad_compositions <- function(data) {
  meta_data <- attr(data, "interdep")

  # The case if no role column was provided
  if (is.null(meta_data$role)) {
    data[[".interdep_raw_composition"]] <- "assumed-exchangeable"
    data[[".interdep_composition"]] <- "assumed-exchangeable"
    data[[".interdep_composition_role"]] <- "assumed-exchangeable"

    attr(data, "interdep")$dyad_compositions <- tibble::tibble(
      raw_composition = "assumed-exchangeable",
      composition = "assumed-exchangeable",
      dyad_type = "exchangeable",
      n_dyads = meta_data$n_dyads
    )

    return(data)
  }


  # If role column was provided
  group_name <- meta_data$group
  member_name <- meta_data$member
  role_name <- meta_data$role

  dyad_roles <- dplyr::summarise(
    dplyr::group_by(
      dplyr::distinct(
        data,
        .data[[group_name]],
        .data[[member_name]],
        .data[[role_name]]
      ),
      .data[[group_name]]
    ),
    raw_composition = canonical_composition(.data[[role_name]]),
    dyad_type = ifelse(
      dplyr::n_distinct(.data[[role_name]]) == 1,
      "exchangeable",
      "distinguishable"
    ),
    .groups = "drop"
  )

  dyad_roles$composition <- dyad_roles$raw_composition

  data <- dplyr::left_join(
    data,
    dplyr::select(
      dyad_roles,
      dplyr::all_of(group_name),
      .interdep_raw_composition = "raw_composition",
      .interdep_composition = "composition",
      .interdep_dyad_type = "dyad_type"
    ),
    by = group_name
  )

  data[[".interdep_composition_role"]] <- ifelse(
    data[[".interdep_dyad_type"]] == "distinguishable",
    composition_role_label(data[[".interdep_composition"]], data[[role_name]]),
    data[[".interdep_composition"]]
  )

  data[[".interdep_dyad_type"]] <- NULL

  attr(data, "interdep")$dyad_compositions <- dplyr::count(
    dyad_roles,
    .data$raw_composition,
    .data$composition,
    dyad_type = .data$dyad_type,
    name = "n_dyads"
  )

  data
}
