#' Infer dyad compositions
#'
#' Builds a dyad-level summary of role compositions from a validated
#' `interdep_data` object.
#'
#' @param data An `interdep_data` object returned by [validate_interdep_data()].
#'
#' @return A tibble with one row per dyad composition and columns:
#' `composition`, `dyad_type`, and `n_dyads`.
#'
#' @keywords internal
infer_dyad_compositions <- function(data) {
  meta <- attr(data, "interdep")

  if (is.null(meta$role)) {
    return(tibble::tibble(
      composition = "unclassified",
      dyad_type = "exchangeable",
      n_dyads = meta$n_dyads
    ))
  }

  group_name <- meta$group
  member_name <- meta$member
  role_name <- meta$role

  member_roles <- dplyr::distinct(
    data,
    .data[[group_name]],
    .data[[member_name]],
    .data[[role_name]]
  )

  dyad_roles <- dplyr::summarise(
    dplyr::group_by(member_roles, .data[[group_name]]),
    roles = paste(sort(as.character(.data[[role_name]])), collapse = "-"),
    dyad_type = ifelse(
      dplyr::n_distinct(.data[[role_name]]) == 1,
      "exchangeable",
      "distinguishable"
    ),
    .groups = "drop"
  )

  dplyr::count(
    dyad_roles,
    composition = .data$roles,
    dyad_type = .data$dyad_type,
    name = "n_dyads"
  )
}
