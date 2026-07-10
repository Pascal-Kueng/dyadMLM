#' Infer dyad compositions
#'
#' Builds a dyad-level summary of role compositions from a validated
#' `interdep_data` object.
#'
#' @param data An `interdep_data` object returned by [validate_interdep_data()].
#' @param seed Optional seed for random `.i_diff_*` sign assignment in
#'   exchangeable dyads. If `NULL`, the current R session's RNG state is used.
#'
#' @return An `interdep_data` object with added `.i_composition` and
#'   `.i_composition_role` factor columns, `.i_is_*` numeric indicator columns,
#'   composition-specific `.i_diff_*` columns for exchangeable dyads, and dyad
#'   composition metadata.
#'
#' @keywords internal
infer_dyad_compositions <- function(data, seed = NULL) {
  if (!inherits(data, "interdep_data")) {
    stop("`data` must be an `interdep_data` object.", call. = FALSE)
  }

  meta_data <- attr(data, "interdep")
  group_name <- meta_data$group
  member_name <- meta_data$member

  # The case if no role column was provided
  if (is.null(meta_data$role)) {
    data[[interdep_composition_col]] <- interdep_assumed_exchangeable_label
    data[[interdep_composition_role_col]] <- interdep_assumed_exchangeable_label

    data <- add_arbitrary_member_roles(
      data,
      group_name = group_name,
      member_name = member_name,
      seed = seed
    )

    attr(data, "interdep")$dyad_compositions <- tibble::tibble(
      raw_composition = interdep_assumed_exchangeable_label,
      composition = interdep_assumed_exchangeable_label,
      dyad_type = "exchangeable",
      n_dyads = meta_data$n_dyads
    )

    data[[interdep_diff_col]] <- ifelse(data[[interdep_arbitrary_role_col]] == "arbitrary_1", -1, 1)

    # convert to factors, sanitize role names, construct .i_is_{indicator} variables.
    # remove temporary cols, create composition-specific diff cols for exchangeable dyads.
    data <- finalize_composition_columns(data)

    return(data)
  }

  # If role column **was** provided
  role_name <- meta_data$role

  dyad_roles <- data |>
    # Collapse repeated ILD rows to one role per member.
    dplyr::distinct(
      .data[[group_name]],
      .data[[member_name]],
      .data[[role_name]]
    ) |>
    dplyr::group_by(.data[[group_name]]) |>
    dplyr::summarise(
      .i_raw_composition = {
        canonical_composition(.data[[role_name]])
      },
      .i_dyad_type = {
        has_one_role <- dplyr::n_distinct(.data[[role_name]]) == 1

        if (has_one_role) {
          "exchangeable"
        } else {
          "distinguishable"
        }
      },
      .groups = "drop"
    ) |>
    dplyr::mutate(.i_composition = .data$.i_raw_composition)

  # attach how many dyads for each comp type we have
  attr(data, "interdep")$dyad_compositions <- dyad_roles |>
    dplyr::count(
      raw_composition = .data[[interdep_raw_composition_col]],
      composition = .data[[interdep_composition_col]],
      dyad_type = .data[[interdep_dyad_type_col]],
      name = "n_dyads"
    )

  # attach dyad roles to data frame
  data <- dplyr::left_join(
    data,
    dyad_roles,
    by = group_name
  )

  # Only exchangeable dyads need arbitrary labels to construct .i_diff_*.
  exchangeable_data <- data[data[[interdep_dyad_type_col]] == "exchangeable", , drop = FALSE]
  arbitrary_roles <- assign_arbitrary_member_roles(
    exchangeable_data,
    group_name = group_name,
    member_name = member_name,
    seed = seed
  )

  data <- dplyr::left_join(
    data,
    arbitrary_roles,
    by = c(group_name, member_name)
  )

  # Distinguishable dyads use observed member roles. Exchangeable dyads use
  # just the composition.
  data[[interdep_composition_role_col]] <- ifelse(
    data[[interdep_dyad_type_col]] == "distinguishable",
    composition_role_label(data[[interdep_composition_col]], data[[role_name]]),
    as.character(data[[interdep_composition_col]])
  )

  # Add a temporary pooled contrast, then use it to create composition-specific
  # .i_diff_* columns in finalize_composition_columns().
  data[[interdep_diff_col]] <- ifelse(
    data[[interdep_dyad_type_col]] == "exchangeable",
    ifelse(data[[interdep_arbitrary_role_col]] == "arbitrary_1", -1, 1),
    0
  )

  # Remove columns that are no longer needed after constructing contrasts.
  data[[interdep_raw_composition_col]] <- NULL
  data[[interdep_dyad_type_col]] <- NULL

  # convert to factors, sanitize role names, construct .i_is_{indicator} variables.
  # remove temporary cols, create composition-specific diff cols for exchangeable dyads.
  data <- finalize_composition_columns(data)

  data
}


finalize_composition_columns <- function(data) {

  # convert to factors before returning
  data[[interdep_composition_col]] <- factor(data[[interdep_composition_col]])
  data[[interdep_composition_role_col]] <- factor(data[[interdep_composition_role_col]])

  # This was only needed for contrast construction, we remove it.
  data[[interdep_arbitrary_role_col]] <- NULL

  indicator_suffixes <- make_interdep_suffixes(data[[interdep_composition_role_col]])

  # Create numeric indicator columns .i_is_{composition_role}
  for (label in sort(names(indicator_suffixes))) {
    data[[paste0(interdep_reserved_prefix, "is_", indicator_suffixes[[label]])]] <- ifelse(
      as.character(data[[interdep_composition_role_col]]) == label,
      1,
      0
    )
  }

  # Composition-specific diff columns let mixed-composition models target each
  # exchangeable composition.
  composition_suffixes <- make_interdep_suffixes(
    data[[interdep_composition_col]][data[[interdep_diff_col]] != 0]
  )

  for (composition in sort(names(composition_suffixes))) {
    is_composition <- as.character(data[[interdep_composition_col]]) == composition
    data[[paste0(interdep_reserved_prefix, "diff_", composition_suffixes[[composition]])]] <- ifelse(
      is_composition,
      data[[interdep_diff_col]],
      0
    )
  }

  data[[interdep_diff_col]] <- NULL

  data
}
