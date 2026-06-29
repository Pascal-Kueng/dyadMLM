#' Infer dyad compositions
#'
#' Builds a dyad-level summary of role compositions from a validated
#' `interdep_data` object.
#'
#' @param data An `interdep_data` object returned by [validate_interdep_data()].
#'
#' @return An `interdep_data` object with an added `.interdep_raw_composition`
#'   column and dyad composition metadata.
#'
#' @keywords internal
infer_dyad_compositions <- function(data) {
  meta_data <- attr(data, "interdep")

  # The case if no role column was provided
  if (is.null(meta_data$role)) {
    data[[".interdep_raw_composition"]] <- "unclassified"

    attr(data, "interdep")$dyad_compositions <- tibble::tibble(
      raw_composition = "unclassified",
      composition = "unclassified",
      dyad_type = "exchangeable",
      n_dyads = meta_data$n_dyads
    )

    return(data)
  }

  # If role column was provided
  group_name <- meta_data$group
  member_name <- meta_data$member
  role_name <- meta_data$role

  member_roles <- dplyr::distinct(
    data,
    .data[[group_name]],
    .data[[member_name]],
    .data[[role_name]]
  )

  dyad_roles <- dplyr::summarise(
    dplyr::group_by(member_roles, .data[[group_name]]),
    raw_composition = paste(sort(as.character(.data[[role_name]])), collapse = "-"),
    dyad_type = ifelse(
      dplyr::n_distinct(.data[[role_name]]) == 1,
      "exchangeable",
      "distinguishable"
    ),
    .groups = "drop"
  )

  dyad_roles$composition <- dyad_roles$raw_composition

  data[[".interdep_raw_composition"]] <- dyad_roles$raw_composition[
    match(data[[group_name]], dyad_roles[[group_name]])
  ]

  attr(data, "interdep")$dyad_compositions <- dplyr::count(
    dyad_roles,
    .data$raw_composition,
    .data$composition,
    dyad_type = .data$dyad_type,
    name = "n_dyads"
  )

  data
}
