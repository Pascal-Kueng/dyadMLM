#' Infer dyad compositions
#'
#' Builds a dyad-level summary of role compositions from a validated
#' `interdep_data` object.
#'
#' @param data An `interdep_data` object returned by [validate_interdep_data()].
#' @param seed Optional seed for random arbitrary partner-role assignment in
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

    data$.i_diff <- ifelse(data$.i_arbitrary_role == "arbitrary_1", -1, 1)

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
      raw_composition = {
        canonical_composition(.data[[role_name]])
      },
      dyad_type = {
        has_one_role <- dplyr::n_distinct(.data[[role_name]]) == 1

        if (has_one_role) {
          "exchangeable"
        } else {
          "distinguishable"
        }
      },
      .groups = "drop"
    ) |>
    dplyr::mutate(composition = .data$raw_composition)

  # attach dyad roles to data frame
  data <- dplyr::left_join(
    data,
    dyad_roles,
    by = group_name
  )

  data[[interdep_composition_col]] <- data$composition
  data[[interdep_dyad_type_col]] <- data$dyad_type

  # Only exchangeable dyads need arbitrary labels to construct idiff.
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


  data$.i_diff <- ifelse(
    data[[interdep_dyad_type_col]] == "exchangeable",
    ifelse(data$.i_arbitrary_role == "arbitrary_1", -1, 1),
    0
  )

  # remove columns that are no longer needed after constructing idiff
  data[[interdep_dyad_type_col]] <- NULL
  data$raw_composition <- NULL
  data$composition <- NULL
  data$dyad_type <- NULL

  attr(data, "interdep")$dyad_compositions <- dplyr::count(
    dyad_roles,
    .data$raw_composition,
    .data$composition,
    dyad_type = .data$dyad_type,
    name = "n_dyads"
  )

  # convert to factors, sanitize role names, construct .i_is_{indicator} variables.
  data <- finalize_composition_columns(data)

  data
}


finalize_composition_columns <- function(data) {

  # convert to factors before returning
  data[[interdep_composition_col]] <- factor(data[[interdep_composition_col]])
  data[[interdep_composition_role_col]] <- factor(data[[interdep_composition_role_col]])

  # This was only needed for idiff construction
  data$.i_arbitrary_role <- NULL

  # Sanitizing user-speicified roles
  indicator_values <- gsub(
    "[^[:alnum:]_]+",
    "_",
    data[[interdep_composition_role_col]]
  )

  # Create numeric indicator columns .i_is_{indicator}
  for (indicator in sort(unique(indicator_values))) {
    data[[paste0(interdep_reserved_prefix, "is_", indicator)]] <- ifelse(
      indicator_values == indicator,
      1,
      0
    )
  }

  # Composition-specific diff columns let unified models target each
  # exchangeable composition without exposing arbitrary role labels.
  composition_values <- gsub(
    "[^[:alnum:]_]+",
    "_",
    as.character(data[[interdep_composition_col]])
  )
  exchangeable_compositions <- sort(unique(composition_values[data$.i_diff != 0]))

  for (composition in exchangeable_compositions) {
    is_composition <- composition_values == composition
    data[[paste0(interdep_reserved_prefix, "diff_", composition)]] <- ifelse(
      is_composition,
      data$.i_diff,
      0
    )
  }

  data
}
