#' Infer dyad compositions
#'
#' Builds a dyad-level summary of role compositions from a validated
#' `dyadMLM_data` object.
#'
#' @param data A `dyadMLM_data` object returned by [validate_dyad_data()].
#' @param seed Optional seed for random `.dy_diff_*` sign assignment in
#'   exchangeable dyads. If `NULL`, the current R session's RNG state is used.
#' @param include_compositions Optional observed dyad compositions to keep
#'   before exchangeability overrides and pooling.
#' @param set_exchangeable_compositions Optional dyad compositions to treat as
#'   exchangeable for analysis.
#' @param pool_compositions Optional named list that pools exchangeable dyad
#'   compositions into user-named final composition labels. Each pool must
#'   resolve to at least two distinct observed compositions.
#'
#' @return A `dyadMLM_data` object with added `.dy_composition` and
#'   `.dy_composition_role` factor columns, `.dy_is_*` numeric indicator columns,
#'   composition-specific numeric `.dy_diff_*` contrast columns coded `-1` and
#'   `1` for the two members of matching exchangeable dyads and `0` otherwise,
#'   and dyad composition metadata.
#'
#' @keywords internal
infer_dyad_compositions <- function(data, seed = NULL, include_compositions = NULL,
                                    set_exchangeable_compositions = NULL,
                                    pool_compositions = NULL) {
  if (!inherits(data, "dyadMLM_data")) {
    stop(
      "`data` must be a `dyadMLM_data` object returned by `prepare_dyad_data()`.",
      call. = FALSE
    )
  }

  meta_data <- attr(data, "dyadMLM")
  group_name <- meta_data$group
  member_name <- meta_data$member

  # The case if no role column was provided
  if (is.null(meta_data$role)) {
    if (!is.null(include_compositions)) {
      stop(
        "`include_compositions` requires `role` to be supplied. ",
        "Without `role`, there are no observed role compositions to include.",
        call. = FALSE
      )
    }
    if (length(set_exchangeable_compositions) > 0) {
      stop(
        "`set_exchangeable_compositions` requires `role` to be supplied. ",
        "Without `role`, all dyads are already treated as one exchangeable composition.",
        " Either remove `set_exchangeable_compositions` argument or supply `role`.",
        call. = FALSE
      )
    }
    if (length(pool_compositions) > 0) {
      stop(
        "`pool_compositions` requires `role` to be supplied. ",
        "Without `role`, all dyads are already treated as one exchangeable composition.",
        " Either remove `pool_compositions` or supply `role`.",
        call. = FALSE
      )
    }

    data[[dyad_composition_col]] <- dyad_assumed_exchangeable_label
    data[[dyad_composition_role_col]] <- dyad_assumed_exchangeable_label

    data <- add_arbitrary_member_roles(
      data,
      group_name = group_name,
      member_name = member_name,
      seed = seed
    )

    attr(data, "dyadMLM")$dyad_compositions <- tibble::tibble(
      composition = dyad_assumed_exchangeable_label,
      dyad_type = "exchangeable",
      dyad_type_source = "assumed_no_role",
      pooled_from = NA_character_,
      n_dyads = meta_data$n_dyads
    )

    data[[dyad_diff_col]] <- ifelse(data[[dyad_arbitrary_role_col]] == "arbitrary_1", -1, 1)

    # convert to factors, sanitize role names, construct .dy_is_{indicator} variables.
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
      .dy_raw_composition = {
        canonical_composition(.data[[role_name]])
      },
      .dy_dyad_type = {
        has_one_role <- dplyr::n_distinct(.data[[role_name]]) == 1

        if (has_one_role) {
          "exchangeable"
        } else {
          "distinguishable"
        }
      },
      .dy_dyad_type_source = "inferred",
      .groups = "drop"
    ) |>
    dplyr::mutate(
      .dy_composition = .data$.dy_raw_composition,
      .dy_pool_member = NA_character_
    )

  # Apply composition filtering before exchangeability overrides and pooling.
  include_result <- apply_include_compositions(
    data = data,
    dyad_roles = dyad_roles,
    include_compositions = include_compositions,
    set_exchangeable_compositions = set_exchangeable_compositions,
    pool_compositions = pool_compositions,
    group_name = group_name
  )
  data <- include_result$data
  dyad_roles <- include_result$dyad_roles

  # Apply any user-requested exchangeability overrides.
  dyad_roles <- apply_exchangeable_composition_overrides(
    dyad_roles = dyad_roles,
    set_exchangeable_compositions = set_exchangeable_compositions
  )

  # Apply any user-requested composition pooling
  dyad_roles <- apply_pool_compositions(
    dyad_roles = dyad_roles,
    pool_compositions = pool_compositions
  )

  # Summarize dyad compositions and attach to attributes.
  # From dataset to 1 row per composition summary
  attr(data, "dyadMLM")$dyad_compositions <- dyad_roles |>
    dplyr::group_by(
      composition = .data[[dyad_composition_col]]
    ) |>
    dplyr::summarise( # for each composition
      dyad_type = dplyr::first(.data[[dyad_type_col]]), # always identical per composition, so use first.
      dyad_type_source = ifelse(
        # Check whether all are either inferred or set by user, otherwise use mixed
        dplyr::n_distinct(.data[[dyad_type_source_col]]) == 1L,
        dplyr::first(.data[[dyad_type_source_col]]),
        "mixed"
      ),
      pooled_from = {
        pool_members <- stats::na.omit(.data[[dyad_pool_member_col]])
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

  # Only exchangeable dyads need arbitrary labels for their difference
  # contrasts.
  exchangeable_data <- data[data[[dyad_type_col]] == "exchangeable", , drop = FALSE]
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
  data[[dyad_composition_role_col]] <- ifelse(
    data[[dyad_type_col]] == "distinguishable",
    composition_role_label(data[[dyad_composition_col]], data[[role_name]]),
    as.character(data[[dyad_composition_col]])
  )

  # Add a temporary pooled contrast, then expand it into one contrast column
  # per exchangeable composition in finalize_composition_columns().
  data[[dyad_diff_col]] <- ifelse(
    data[[dyad_type_col]] == "exchangeable",
    ifelse(data[[dyad_arbitrary_role_col]] == "arbitrary_1", -1, 1),
    0
  )

  # Remove columns that are no longer needed after constructing contrasts.
  data[[dyad_raw_composition_col]] <- NULL
  data[[dyad_type_col]] <- NULL
  data[[dyad_type_source_col]] <- NULL
  data[[dyad_pool_member_col]] <- NULL

  # convert to factors, sanitize role names, construct .dy_is_{indicator} variables.
  # remove temporary cols, create composition-specific diff cols for exchangeable dyads.
  data <- finalize_composition_columns(data)

  data
}


apply_include_compositions <- function(data, dyad_roles, include_compositions,
                                       set_exchangeable_compositions,
                                       pool_compositions, group_name) {
  if (is.null(include_compositions)) {
    return(list(data = data, dyad_roles = dyad_roles))
  }

  if (length(include_compositions) == 0) {
    stop(
      "`include_compositions` must contain at least one dyad composition. Otherwise, use `NULL` (the default).",
      call. = FALSE
    )
  }

  # Get canonical composition labels for the filter.
  include_compositions_resolved <- resolve_composition_references(
    references = include_compositions,
    observed_compositions = dyad_roles[[dyad_composition_col]],
    arg_name = "include_compositions"
  )

  # Resolve later composition references so we can catch references removed by
  # the filter and provide a clearer error.
  set_exchangeable_compositions_resolved <- resolve_composition_references(
    references = set_exchangeable_compositions,
    observed_compositions = dyad_roles[[dyad_composition_col]],
    arg_name = "set_exchangeable_compositions"
  )

  pool_composition_references <- NULL
  if (is.list(pool_compositions)) {
    pool_composition_references <- unlist(pool_compositions, use.names = FALSE)
  }
  pool_compositions_resolved <- resolve_composition_references(
    references = pool_composition_references,
    observed_compositions = dyad_roles[[dyad_composition_col]],
    arg_name = "pool_compositions"
  )

  # Check if later arguments refer to compositions removed by the filter.
  referenced_later <- c(set_exchangeable_compositions_resolved, pool_compositions_resolved)
  if (!all(referenced_later %in% include_compositions_resolved)) {
    references_removed_by_include <- setdiff(referenced_later, include_compositions_resolved)
    stop(
      "`include_compositions` filters out composition(s) that are later referenced by ",
      "`set_exchangeable_compositions` or `pool_compositions`: ",
      paste(sort(references_removed_by_include), collapse = ", "),
      ". Add them to `include_compositions` or remove them from the later argument.",
      call. = FALSE
    )
  }

  # Get dyad-ids that we keep
  keep_dyads <- dyad_roles |>
    dplyr::filter(.data[[dyad_composition_col]] %in% include_compositions_resolved) |>
    # extract ids with pull (vector)
    dplyr::pull(.data[[group_name]]) |>
    unique() # probably not needed, as it should be unique already, but leave as safeguard

  if (length(keep_dyads) < 2) {
    stop(
      "`include_compositions` must leave at least two complete dyads after filtering.",
      call. = FALSE
    )
  }

  # Filter dyad-roles lookup table
  dyad_roles <- dyad_roles |>
    dplyr::filter(.data[[group_name]] %in% keep_dyads)

  # Also filter actual dataframe so later joins will work properly
  data <- data |>
    dplyr::filter(.data[[group_name]] %in% keep_dyads)
  attr(data, "dyadMLM")$n_dyads <- length(keep_dyads)

  return(list(data = data, dyad_roles = dyad_roles))
}


apply_exchangeable_composition_overrides <- function(dyad_roles, set_exchangeable_compositions) {
  set_exchangeable_compositions_resolved <- resolve_composition_references(
    references = set_exchangeable_compositions,
    observed_compositions = dyad_roles[[dyad_composition_col]],
    arg_name = "set_exchangeable_compositions"
  )

  # Checks if argument is needed and allowed
  if (length(set_exchangeable_compositions_resolved) == 0) {
    return(dyad_roles)
  }

  already_exchangeable_rows <- dyad_roles |>
    dplyr::filter(
      # filter those that are requested to be set exchangeable
      .data[[dyad_composition_col]] %in% set_exchangeable_compositions_resolved,
      # and those that are already inferred to as exchangeable
      .data[[dyad_type_col]] == "exchangeable"
    )

  if (nrow(already_exchangeable_rows) > 0) {
    already_exchangeable_compositions <- already_exchangeable_rows |>
      dplyr::pull(.data[[dyad_composition_col]]) |>
      unique()

    stop(
      "`set_exchangeable_compositions` can only contain compositions that are otherwise not already inferred as exchangeable. ",
      "Already exchangeable composition(s): ",
      paste(sort(already_exchangeable_compositions), collapse = ", "),
      ". Remove these compositions from `set_exchangeable_compositions`.",
      call. = FALSE
    )
  }

  # Actually "constraining" the roles by simply changing .dy_dyad_type from
  # the inferred "distinguishable" to "exchangeable". (Apply the requested exchangeability override)
  dyad_roles_constrained <- dyad_roles |>
    dplyr::mutate(
      "{dyad_type_col}" := dplyr::if_else(
        .data[[dyad_composition_col]] %in% set_exchangeable_compositions_resolved,
        "exchangeable",
        .data[[dyad_type_col]]
      ),
      "{dyad_type_source_col}" := dplyr::if_else(
        .data[[dyad_composition_col]] %in% set_exchangeable_compositions_resolved,
        "set_by_user",
        .data[[dyad_type_source_col]]
      )
    )

  return(dyad_roles_constrained)
}




apply_pool_compositions <- function(dyad_roles, pool_compositions) {
  if (is.null(pool_compositions) || length(pool_compositions) == 0) {
    return(dyad_roles)
  }

  if (!is.list(pool_compositions) || is.null(names(pool_compositions))) {
    stop(
      "`pool_compositions` must be a named list, for example ",
      "`list(romantic_couples = c(\"female-female\", \"male-male\"))`.",
      call. = FALSE
    )
  }

  pool_names <- trimws(names(pool_compositions))
  if (any(is.na(pool_names)) || any(pool_names == "")) {
    stop(
      "All `pool_compositions` elements must have non-empty names. ",
      "Use names for the final pooled compositions, for example ",
      "`list(romantic_couples = c(\"female-female\", \"male-male\"))`.",
      call. = FALSE
    )
  }
  if (any(duplicated(pool_names))) {
    stop(
      "`pool_compositions` names must be unique. Duplicated name(s): ",
      paste(sort(unique(pool_names[duplicated(pool_names)])), collapse = ", "),
      ". Rename the duplicated pools.",
      call. = FALSE
    )
  }

  observed_compositions <- dyad_roles[[dyad_composition_col]]
  already_pooled_compositions <- character()

  for (i in seq_along(pool_compositions)) { # for each requested pool
    pool_name <- pool_names[[i]]
    references_to_pool <- pool_compositions[[i]]

    if (!is.character(references_to_pool) || length(references_to_pool) < 2) {
      stop(
        "Pool `", pool_name,
        "` in `pool_compositions` must be a character vector of at least two dyad compositions, ",
        "for example `c(\"female-female\", \"male-male\")`.",
        call. = FALSE
      )
    }

    resolved_compositions_to_pool <- resolve_composition_references(
      references = references_to_pool,
      observed_compositions = observed_compositions,
      arg_name = "pool_compositions"
    )

    if (length(resolved_compositions_to_pool) < 2) {
      stop(
        "Each `pool_compositions` element must resolve to at least two distinct observed dyad compositions. ",
        "Pool `", pool_name, "` resolved to: ",
        paste(resolved_compositions_to_pool, collapse = ", "),
        ".",
        call. = FALSE
      )
    }

    # While still looping, check whether any composition has already been
    # assigned to a previous pool. To avoid duplications
    duplicated_compositions <- intersect(resolved_compositions_to_pool, already_pooled_compositions)
    if (length(duplicated_compositions) > 0) {
      stop(
        "`pool_compositions` cannot assign the same composition to more than one pool. ",
        "Pool `", pool_name, "` reuses composition(s): ",
        paste(sort(duplicated_compositions), collapse = ", "),
        ". Remove each composition from all but one pool.",
        call. = FALSE
      )
    }

    pool_name_collision <- pool_name %in% setdiff(observed_compositions, resolved_compositions_to_pool)
    if (pool_name_collision) {
      stop(
        "`pool_compositions` names must not match observed compositions that are not part of that pool. ",
        "Conflicting name(s): ",
        pool_name,
        ". Choose a different pool name, or include the matching observed composition in that pool.",
        call. = FALSE
      )
    }

    # check if user tries to pool distinguishable dyads
    non_exchangeable_rows <- dyad_roles |>
      dplyr::filter(
        .data[[dyad_composition_col]] %in% resolved_compositions_to_pool,
        .data[[dyad_type_col]] != "exchangeable"
      )

    if (nrow(non_exchangeable_rows) > 0) {
      non_exchangeable_compositions <- non_exchangeable_rows |>
        dplyr::pull(.data[[dyad_composition_col]]) |>
        unique()

      stop(
        "`pool_compositions` can only pool exchangeable compositions. ",
        "Set distinguishable compositions exchangeable first with `set_exchangeable_compositions`. ",
        "Non-exchangeable composition(s): ",
        paste(sort(non_exchangeable_compositions), collapse = ", "),
        ".",
        call. = FALSE
      )
    }

    # Actual pooling
    ## subsetting all rows **within the current pooling step**.
    is_pooled <- dyad_roles[[dyad_composition_col]] %in% resolved_compositions_to_pool

    # Before overwriting .dy_composition, copy the old composition into .dy_pool_member.
    dyad_roles[[dyad_pool_member_col]][is_pooled] <- dyad_roles[[dyad_composition_col]][is_pooled]

    # Now replace the current composition with the pool name.
    dyad_roles[[dyad_composition_col]][is_pooled] <- pool_name

    already_pooled_compositions <- c(already_pooled_compositions, resolved_compositions_to_pool)
  }

  dyad_roles
}


finalize_composition_columns <- function(data) {

  # convert to factors before returning
  data[[dyad_composition_col]] <- factor(data[[dyad_composition_col]])
  data[[dyad_composition_role_col]] <- factor(data[[dyad_composition_role_col]])

  # This was only needed for contrast construction, we remove it.
  data[[dyad_arbitrary_role_col]] <- NULL

  indicator_suffixes <- make_dyad_suffixes(data[[dyad_composition_role_col]])

  # Create numeric indicator columns .dy_is_{composition_role}
  for (label in sort(names(indicator_suffixes))) {
    data[[paste0(dyad_reserved_prefix, "is_", indicator_suffixes[[label]])]] <- ifelse(
      as.character(data[[dyad_composition_role_col]]) == label,
      1,
      0
    )
  }

  # Composition-specific diff columns let mixed-composition models target each
  # exchangeable composition.
  composition_suffixes <- make_dyad_suffixes(
    data[[dyad_composition_col]][data[[dyad_diff_col]] != 0]
  )

  for (composition in sort(names(composition_suffixes))) {
    is_composition <- as.character(data[[dyad_composition_col]]) == composition
    diff_column <- paste0(
      dyad_reserved_prefix,
      "diff_",
      composition_suffixes[[composition]],
      "_arbitrary"
    )
    data[[diff_column]] <- ifelse(
      is_composition,
      data[[dyad_diff_col]],
      0
    )
  }

  data[[dyad_diff_col]] <- NULL

  data
}
