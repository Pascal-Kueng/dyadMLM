#' Infer dyad compositions
#'
#' Builds a dyad-level summary of role compositions from a validated
#' `interdep_data` object.
#'
#' @param data An `interdep_data` object returned by [validate_interdep_data()].
#' @param seed Optional seed for random `.i_diff_*` sign assignment in
#'   exchangeable dyads. If `NULL`, the current R session's RNG state is used.
#' @param set_compositions_exchangeable Optional dyad compositions to treat as
#'   exchangeable for analysis.
#' @param composition_pooling Optional named list that pools exchangeable dyad
#'   compositions into user-named final composition labels.
#'
#' @return An `interdep_data` object with added `.i_composition` and
#'   `.i_composition_role` factor columns, `.i_is_*` numeric indicator columns,
#'   composition-specific `.i_diff_*` columns for exchangeable dyads, and dyad
#'   composition metadata.
#'
#' @keywords internal
infer_dyad_compositions <- function(data, seed = NULL, set_compositions_exchangeable = NULL,
                                    composition_pooling = NULL) {
  if (!inherits(data, "interdep_data")) {
    stop("`data` must be an `interdep_data` object.", call. = FALSE)
  }

  meta_data <- attr(data, "interdep")
  group_name <- meta_data$group
  member_name <- meta_data$member

  # The case if no role column was provided
  if (is.null(meta_data$role)) {
    if (length(set_compositions_exchangeable) > 0) {
      stop(
        "`set_compositions_exchangeable` requires `role` to be supplied. ",
        "Without `role`, all dyads are already treated as one exchangeable composition.",
        " Either remove `set_compositions_exchangeable` argument or supply `role`.",
        call. = FALSE
      )
    }
    if (length(composition_pooling) > 0) {
      stop(
        "`composition_pooling` requires `role` to be supplied. ",
        "Without `role`, all dyads are already treated as one exchangeable composition.",
        " Either remove `composition_pooling` or supply `role`.",
        call. = FALSE
      )
    }

    data[[interdep_composition_col]] <- interdep_assumed_exchangeable_label
    data[[interdep_composition_role_col]] <- interdep_assumed_exchangeable_label

    data <- add_arbitrary_member_roles(
      data,
      group_name = group_name,
      member_name = member_name,
      seed = seed
    )

    attr(data, "interdep")$dyad_compositions <- tibble::tibble(
      composition = interdep_assumed_exchangeable_label,
      dyad_type = "exchangeable",
      dyad_type_source = "assumed_no_role",
      pooled_from = NA_character_,
      n_dyads = meta_data$n_dyads
    )

    data[[interdep_diff_col]] <- ifelse(data[[interdep_arbitrary_role_col]] == "arbitrary_1", -1, 1)

    # convert to factors, sanitize role names, construct .i_is_{indicator} variables.
    # remove temporary cols, create composition-specific diff cols for exchangeable dyads.
    data <- finalize_composition_columns(data)

    return(data)
  }

  ########################################################################
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
      .i_dyad_type_source = "inferred",
      .groups = "drop"
    ) |>
    dplyr::mutate(
      .i_composition = .data$.i_raw_composition,
      .i_pool_member = NA_character_
    )

  # Apply any user-requested exchangeability overrides.
  dyad_roles <- apply_exchangeable_composition_overrides(
    dyad_roles = dyad_roles,
    set_compositions_exchangeable = set_compositions_exchangeable
  )

  # Apply any user-requested role-pooling
  dyad_roles <- apply_composition_pooling(
    dyad_roles = dyad_roles,
    composition_pooling = composition_pooling
  )

  # Summarize dyad compositions and attach to attributes.
  # From dataset to 1 row per composition summary
  attr(data, "interdep")$dyad_compositions <- dyad_roles |>
    dplyr::group_by(
      composition = .data[[interdep_composition_col]]
    ) |>
    dplyr::summarise( # for each composition
      dyad_type = dplyr::first(.data[[interdep_dyad_type_col]]), # always identical per composition, so use first.
      dyad_type_source = ifelse(
        # Check whether all are either inferred or set by user, otherwise use mixed
        dplyr::first(.data[[interdep_dyad_type_source_col]]),
        dplyr::n_distinct(.data[[interdep_dyad_type_source_col]]) == 1L,
        "mixed"
      ),
      pooled_from = {
        pool_members <- stats::na.omit(.data[[interdep_pool_member_col]])
        if (length(pool_members) == 0) {
          NA_character_ # if not pooled.
        } else {
          paste(sort(unique(pool_members)), collapse = ", ")
        }
      },
      n_dyads = dplyr::n(),
      .groups = "drop"
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
  data[[interdep_dyad_type_source_col]] <- NULL
  data[[interdep_pool_member_col]] <- NULL

  # convert to factors, sanitize role names, construct .i_is_{indicator} variables.
  # remove temporary cols, create composition-specific diff cols for exchangeable dyads.
  data <- finalize_composition_columns(data)

  data
}


apply_exchangeable_composition_overrides <- function(dyad_roles, set_compositions_exchangeable) {
  set_compositions_exchangeable_resolved <- resolve_composition_references(
    references = set_compositions_exchangeable,
    observed_compositions = dyad_roles[[interdep_composition_col]],
    arg_name = "set_compositions_exchangeable"
  )

  # Checks if argument is needed and allowed
  if (length(set_compositions_exchangeable_resolved) == 0) {
    return(dyad_roles)
  }

  already_exchangeable_rows <- dyad_roles |>
    dplyr::filter(
      # filter those that are mentioned to be restricted to be exchangeable
      .data[[interdep_composition_col]] %in% set_compositions_exchangeable_resolved,
      # and those that are already inferred to as exchangeable
      .data[[interdep_dyad_type_col]] == "exchangeable"
    )

  if (nrow(already_exchangeable_rows) > 0) {
    already_exchangeable_compositions <- already_exchangeable_rows |>
      dplyr::pull(.data[[interdep_composition_col]]) |>
      unique()

    stop(
      "`set_compositions_exchangeable` can only contain compositions that are otherwise not already inferred as exchangeable. ",
      "Already exchangeable composition(s): ",
      paste(sort(already_exchangeable_compositions), collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  # Actually "constraining" the roles by simply changing .i_dyad_type from
  # the inferred "distinguishable" to "exchangeable". (Apply the requested exchangeability override)
  dyad_roles_constrained <- dyad_roles |>
    dplyr::mutate(
      "{interdep_dyad_type_col}" := dplyr::if_else(
        .data[[interdep_composition_col]] %in% set_compositions_exchangeable_resolved,
        "exchangeable",
        .data[[interdep_dyad_type_col]]
      ),
      "{interdep_dyad_type_source_col}" := dplyr::if_else(
        .data[[interdep_composition_col]] %in% set_compositions_exchangeable_resolved,
        "set_by_user",
        .data[[interdep_dyad_type_source_col]]
      )
    )

  return(dyad_roles_constrained)
}


apply_composition_pooling <- function(dyad_roles, composition_pooling) {
  if (is.null(composition_pooling) || length(composition_pooling) == 0) {
    return(dyad_roles)
  }

  if (!is.list(composition_pooling) || is.null(names(composition_pooling))) {
    stop("`composition_pooling` must be a named list.", call. = FALSE)
  }

  pool_names <- trimws(names(composition_pooling))
  if (any(is.na(pool_names)) || any(pool_names == "")) {
    stop("All `composition_pooling` elements must have non-empty names.", call. = FALSE)
  }
  if (any(duplicated(pool_names))) {
    stop("`composition_pooling` names must be unique.", call. = FALSE)
  }

  pooled_compositions <- character()
  composition_pool_map <- character()

  for (i in seq_along(composition_pooling)) {
    pool_name <- pool_names[[i]]
    references <- composition_pooling[[i]]

    if (!is.character(references) || length(references) == 0) {
      stop("Each `composition_pooling` element must be a non-empty character vector.", call. = FALSE)
    }

    resolved <- resolve_composition_references(
      references = references,
      observed_compositions = dyad_roles[[interdep_composition_col]],
      arg_name = "composition_pooling"
    )

    pooled_compositions <- c(pooled_compositions, resolved)
    composition_pool_map[resolved] <- pool_name
  }

  duplicated_compositions <- unique(pooled_compositions[duplicated(pooled_compositions)])
  if (length(duplicated_compositions) > 0) {
    stop(
      "`composition_pooling` cannot assign the same composition to more than one pool. ",
      "Repeated composition(s): ",
      paste(sort(duplicated_compositions), collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  unpooled_compositions <- setdiff(dyad_roles[[interdep_composition_col]], pooled_compositions)
  pool_name_collisions <- intersect(pool_names, unpooled_compositions)
  if (length(pool_name_collisions) > 0) {
    stop(
      "`composition_pooling` names must not match observed compositions that are not part of that pool. ",
      "Conflicting name(s): ",
      paste(sort(pool_name_collisions), collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  non_exchangeable_rows <- dyad_roles |>
    dplyr::filter(
      .data[[interdep_composition_col]] %in% pooled_compositions,
      .data[[interdep_dyad_type_col]] != "exchangeable"
    )

  if (nrow(non_exchangeable_rows) > 0) {
    non_exchangeable_compositions <- non_exchangeable_rows |>
      dplyr::pull(.data[[interdep_composition_col]]) |>
      unique()

    stop(
      "`composition_pooling` can only pool exchangeable compositions. ",
      "Set distinguishable compositions exchangeable first with `set_compositions_exchangeable`. ",
      "Non-exchangeable composition(s): ",
      paste(sort(non_exchangeable_compositions), collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  pooled_compositions <- names(composition_pool_map)

  dyad_roles |>
    dplyr::mutate(
      "{interdep_pool_member_col}" := dplyr::if_else(
        .data[[interdep_composition_col]] %in% pooled_compositions,
        .data[[interdep_composition_col]],
        .data[[interdep_pool_member_col]]
      ),
      "{interdep_composition_col}" := dplyr::if_else(
        .data[[interdep_pool_member_col]] %in% pooled_compositions,
        unname(composition_pool_map[.data[[interdep_pool_member_col]]]),
        .data[[interdep_composition_col]]
      )
    )
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
