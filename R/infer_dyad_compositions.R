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
#'   and dyad composition metadata.
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

    data <- add_arbitrary_member_roles(
      data,
      group_name = group_name,
      member_name = member_name,
      seed = seed
    )

    data[[interdep_composition_role_col]] <- composition_role_label(
      data[[interdep_composition_col]],
      data$.i_arbitrary_role
    )

    attr(data, "interdep")$dyad_compositions <- tibble::tibble(
      raw_composition = interdep_assumed_exchangeable_label,
      composition = interdep_assumed_exchangeable_label,
      dyad_type = "exchangeable",
      n_dyads = meta_data$n_dyads
    )

    data$.i_diff <- ifelse(data$.i_arbitrary_role == "arbitrary_1", -1, 1)

    return(finalize_composition_columns(data))
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

  # Only exchangeable dyads need arbitrary labels. This keeps the random
  # assignment independent of unrelated distinguishable dyads.
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
  # arbitrary labels so each partner can still receive a unique model column.
  data[[interdep_composition_role_col]] <- ifelse(
    data[[interdep_dyad_type_col]] == "distinguishable",
    composition_role_label(data[[interdep_composition_col]], data[[role_name]]),
    composition_role_label(data[[interdep_composition_col]], data$.i_arbitrary_role)
  )

  data$.i_diff <- ifelse(
    data[[interdep_dyad_type_col]] == "exchangeable",
    ifelse(data$.i_arbitrary_role == "arbitrary_1", -1, 1),
    0
  )

  data[[interdep_dyad_type_col]] <- NULL

  attr(data, "interdep")$dyad_compositions <- dplyr::count(
    dyad_roles,
    .data$raw_composition,
    .data$composition,
    dyad_type = .data$dyad_type,
    name = "n_dyads"
  )

  finalize_composition_columns(data)
}


finalize_composition_columns <- function(data) {
  data[[interdep_composition_col]] <- factor(data[[interdep_composition_col]])
  data[[interdep_composition_role_col]] <- factor(data[[interdep_composition_role_col]])
  data$.i_arbitrary_role <- NULL

  add_composition_role_indicators(data)
}


add_composition_role_indicators <- function(data) {
  # Create numeric indicator columns for model formulas while first sanitizing
  # the user supplied values.
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
