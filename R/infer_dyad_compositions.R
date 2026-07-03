#' Infer dyad compositions
#'
#' Builds a dyad-level summary of role compositions from a validated
#' `interdep_data` object.
#'
#' @param data An `interdep_data` object returned by [validate_interdep_data()].
#'
#' @return An `interdep_data` object with added `.i_composition` and
#'   `.i_composition_role` factor columns, `.i_is_*` numeric indicator columns,
#'   and dyad composition metadata.
#'
#' @keywords internal
infer_dyad_compositions <- function(data) {
  meta_data <- attr(data, "interdep")

  # The case if no role column was provided
  if (is.null(meta_data$role)) {
    data[[interdep_composition_col]] <- interdep_assumed_exchangeable_label
    data[[interdep_composition_role_col]] <- interdep_assumed_exchangeable_label

    attr(data, "interdep")$dyad_compositions <- tibble::tibble(
      raw_composition = interdep_assumed_exchangeable_label,
      composition = interdep_assumed_exchangeable_label,
      dyad_type = "exchangeable",
      n_dyads = meta_data$n_dyads
    )

    # return as factors!
    data[[interdep_composition_col]] <- factor(data[[interdep_composition_col]])
    data[[interdep_composition_role_col]] <- factor(data[[interdep_composition_role_col]])

    # Create indicator column. In this case it is constant and equivalent to an intercept.
    data[[paste0(interdep_reserved_prefix, "is_", interdep_assumed_exchangeable_label)]] <- 1

    return(data)
  }

  # If role column **was** provided
  group_name <- meta_data$group
  member_name <- meta_data$member
  role_name <- meta_data$role

  incomplete_groups <- meta_data$incomplete_dyads

  dyad_roles <- data |>
    # Collapse repeated ILD rows to one role per member.
    dplyr::distinct(
      .data[[group_name]],
      .data[[member_name]],
      .data[[role_name]]
    ) |>
    dplyr::group_by(.data[[group_name]]) |>
    dplyr::summarise(
      raw_composition = {
        roles <- .data[[role_name]]

        # For incomplete dyads, add one synthetic unknown role for the missing partner.
        if (.data[[group_name]][1] %in% incomplete_groups) {
          roles <- c(roles, interdep_unknown_label)
        }

        canonical_composition(roles)
      },
      dyad_type = {
        has_unknown_role <- any(.data[[role_name]] == interdep_unknown_label)
        is_incomplete_group <- .data[[group_name]][1] %in% incomplete_groups
        has_one_role <- dplyr::n_distinct(.data[[role_name]]) == 1

        if (has_unknown_role || is_incomplete_group) {
          interdep_unknown_label
        } else if (has_one_role) {
          "exchangeable"
        } else {
          "distinguishable"
        }
      },
      .groups = "drop"
    )

  dyad_roles$composition <- dyad_roles$raw_composition

  # Create the dyad-level lookup that will be joined back to every row.
  # The lookup uses the final `.i_*` column names returned to users.
  composition_lookup <- dyad_roles[c(group_name, "composition", "dyad_type")]
  names(composition_lookup)[names(composition_lookup) == "composition"] <- interdep_composition_col
  names(composition_lookup)[names(composition_lookup) == "dyad_type"] <- interdep_dyad_type_col

  data <- dplyr::left_join(
    data,
    composition_lookup,
    by = group_name
  )

  # Adding individual role column!
  data[[interdep_composition_role_col]] <- ifelse(
    data[[interdep_dyad_type_col]] %in% c("distinguishable", interdep_unknown_label),
    # For distinguishable and unknown dyads, include the member role in the label.
    composition_role_label(data[[interdep_composition_col]], data[[role_name]]),
    # For exchangeable dyads, the dyad composition label is sufficient.
    data[[interdep_composition_col]]
  )

  data[[interdep_dyad_type_col]] <- NULL

  attr(data, "interdep")$dyad_compositions <- dplyr::count(
    dyad_roles,
    .data$raw_composition,
    .data$composition,
    dyad_type = .data$dyad_type,
    name = "n_dyads"
  )

  # return as factors!
  data[[interdep_composition_col]] <- factor(data[[interdep_composition_col]])
  data[[interdep_composition_role_col]] <- factor(data[[interdep_composition_role_col]])

  # Create numeric indicator columns for model formulas
  # while first sanitizing the user supplied values.
  is_ <- gsub(
    "[^[:alnum:]_]+",
    "_",
    data[[interdep_composition_role_col]]
  )

  dummy_matrix <- stats::model.matrix(~ 0 + is_)

  colnames(dummy_matrix) <- paste0(interdep_reserved_prefix, colnames(dummy_matrix))

  data[colnames(dummy_matrix)] <- as.data.frame(dummy_matrix)

  data
}
