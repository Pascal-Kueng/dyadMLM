#' Infer dyad compositions
#'
#' Builds a dyad-level summary of role compositions from a validated
#' `dyadMLM_data` object.
#'
#' @param data A `dyadMLM_data` object returned by [validate_dyad_data()].
#' @param seed Optional seed for random `.dy_member_contrast_*` sign assignment in
#'   exchangeable dyads. If `NULL`, the current R session's RNG state is used.
#' @param keep_compositions Optional observed dyad compositions to keep
#'   before exchangeability overrides and pooling.
#' @param set_exchangeable_compositions Optional dyad compositions to treat as
#'   exchangeable for analysis.
#' @param pool_compositions Optional named list that pools exchangeable dyad
#'   compositions into user-named final composition labels. Each pool must
#'   resolve to at least two distinct observed compositions.
#' @param short_colnames Whether to use shorter composition-dependent generated
#'   column names when the final data contain one composition.
#'
#' @return A `dyadMLM_data` object with added `.dy_composition` and
#'   `.dy_composition_role` factor columns, `.dy_is_*` numeric indicator columns,
#'   composition-specific numeric `.dy_member_contrast_*` columns coded `-1` and
#'   `1` for the two members of matching exchangeable dyads and `0` otherwise,
#'   and dyad composition metadata.
#'
#' @keywords internal
infer_dyad_compositions <- function(data, seed = NULL, keep_compositions = NULL,
                                    set_exchangeable_compositions = NULL,
                                    pool_compositions = NULL,
                                    short_colnames = TRUE) {
  if (!inherits(data, "dyadMLM_data")) {
    stop(
      "`data` must be a `dyadMLM_data` object returned by `prepare_dyad_data()`.",
      call. = FALSE
    )
  }
  if (!is.logical(short_colnames) ||
      length(short_colnames) != 1L ||
      is.na(short_colnames)) {
    stop("`short_colnames` must be `TRUE` or `FALSE`.", call. = FALSE)
  }

  meta_data <- attr(data, "dyadMLM")
  group_name <- meta_data$dyad
  member_name <- meta_data$member

  # The case if no role column was provided
  if (is.null(meta_data$role)) {
    if (!is.null(keep_compositions)) {
      stop(
        "`keep_compositions` requires `role` to be supplied. ",
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

    # Finalize factors and construct the generated composition columns.
    data <- finalize_composition_columns(data, short_colnames)

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
  include_result <- apply_keep_compositions(
    data = data,
    dyad_roles = dyad_roles,
    keep_compositions = keep_compositions,
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

  # Finalize factors and construct the generated composition columns.
  data <- finalize_composition_columns(data, short_colnames)

  data
}


apply_keep_compositions <- function(data, dyad_roles, keep_compositions,
                                       set_exchangeable_compositions,
                                       pool_compositions, group_name) {
  if (is.null(keep_compositions)) {
    return(list(data = data, dyad_roles = dyad_roles))
  }

  if (length(keep_compositions) == 0) {
    stop(
      "`keep_compositions` must contain at least one dyad composition. Otherwise, use `NULL` (the default).",
      call. = FALSE
    )
  }

  # Get canonical composition labels for the filter.
  keep_compositions_resolved <- resolve_composition_references(
    references = keep_compositions,
    observed_compositions = dyad_roles[[dyad_composition_col]],
    arg_name = "keep_compositions"
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
  if (!all(referenced_later %in% keep_compositions_resolved)) {
    references_removed_by_include <- setdiff(referenced_later, keep_compositions_resolved)
    stop(
      "`keep_compositions` filters out composition(s) that are later referenced by ",
      "`set_exchangeable_compositions` or `pool_compositions`: ",
      paste(sort(references_removed_by_include), collapse = ", "),
      ". Add them to `keep_compositions` or remove them from the later argument.",
      call. = FALSE
    )
  }

  # Get dyad-ids that we keep
  keep_dyads <- dyad_roles |>
    dplyr::filter(.data[[dyad_composition_col]] %in% keep_compositions_resolved) |>
    # extract ids with pull (vector)
    dplyr::pull(.data[[group_name]]) |>
    unique() # probably not needed, as it should be unique already, but leave as safeguard

  if (length(keep_dyads) < 2) {
    stop(
      "`keep_compositions` must leave at least two complete dyads after filtering.",
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


finalize_composition_columns <- function(data, short_colnames) {

  # Convert to factors before returning.
  data[[dyad_composition_col]] <- factor(data[[dyad_composition_col]])
  data[[dyad_composition_role_col]] <- factor(data[[dyad_composition_role_col]])

  meta_data <- attr(data, "dyadMLM")
  # Short names omit the composition label. After filtering and pooling, they
  # are unambiguous only when exactly one final composition remains; otherwise
  # they are not allowed.
  has_single_composition <- nrow(meta_data$dyad_compositions) == 1L
  use_short_composition_colnames <-
    short_colnames && has_single_composition

  # Store the resolved choice so later lookup and printing use the names that
  # were actually created, rather than the user's original request.
  meta_data$short_colnames <- use_short_composition_colnames
  attr(data, "dyadMLM") <- meta_data

  # The arbitrary role is only needed while constructing member contrasts.
  data[[dyad_arbitrary_role_col]] <- NULL

  # Build the exact output names once and reuse them for validation and writing.
  composition_role_labels <- sort(unique(
    as.character(data[[dyad_composition_role_col]])
  ))
  if (use_short_composition_colnames &&
      meta_data$dyad_compositions$dyad_type[[1L]] == "exchangeable") {
    composition_indicator_columns <- paste0(
      dyad_short_prefix,
      "is_exchangeable"
    )
  } else if (use_short_composition_colnames) {
    # With one distinguishable composition, the observed role alone identifies
    # each indicator; the composition portion of the label is redundant.
    observed_role_labels <- as.character(data[[meta_data$role]])[
      match(
        composition_role_labels,
        as.character(data[[dyad_composition_role_col]])
      )
    ]
    observed_role_suffixes <- make_dyad_suffixes(
      observed_role_labels,
      label_type = "role labels",
      rename_hint = "role labels"
    )
    composition_indicator_columns <- paste0(
      dyad_short_prefix,
      "is_",
      unname(observed_role_suffixes[observed_role_labels])
    )
  } else {
    composition_role_suffixes <- make_dyad_suffixes(
      composition_role_labels
    )
    composition_indicator_columns <- paste0(
      dyad_reserved_prefix,
      "is_",
      unname(composition_role_suffixes[composition_role_labels])
    )
  }
  names(composition_indicator_columns) <- composition_role_labels

  # Only exchangeable compositions have non-zero member contrasts and
  # therefore need a member-contrast column.
  exchangeable_composition_labels <- sort(unique(as.character(
    data[[dyad_composition_col]][data[[dyad_diff_col]] != 0]
  )))
  member_contrast_columns <- character(length(exchangeable_composition_labels))
  if (length(exchangeable_composition_labels) > 0L) {
    if (use_short_composition_colnames) {
      member_contrast_columns <- paste0(
        dyad_short_prefix,
        "member_contrast_arbitrary"
      )
    } else {
      exchangeable_composition_suffixes <- make_dyad_suffixes(
        exchangeable_composition_labels
      )
      member_contrast_columns <- paste0(
        dyad_reserved_prefix,
        "member_contrast_",
        unname(
          exchangeable_composition_suffixes[exchangeable_composition_labels]
        ),
        "_arbitrary"
      )
    }
  }
  names(member_contrast_columns) <- exchangeable_composition_labels

  # Shape: one row per column that this function is about to create. The
  # descriptive fields are used only to make collision errors informative.
  composition_column_plan <- tibble::tibble(
    target = c(
      unname(composition_indicator_columns),
      unname(member_contrast_columns)
    ),
    predictor = NA_character_,
    temporal_component = "none",
    lag = 0L,
    model_family = "composition",
    column_role = c(
      rep("composition_indicator", length(composition_indicator_columns)),
      rep("member_contrast", length(member_contrast_columns))
    ),
    variable_role = c(
      rep("composition_role", length(composition_indicator_columns)),
      rep("composition", length(member_contrast_columns))
    ),
    source_column = c(
      rep(dyad_composition_role_col, length(composition_indicator_columns)),
      rep(dyad_composition_col, length(member_contrast_columns))
    )
  )
  validate_generated_column_plan(data, composition_column_plan)

  # Create numeric indicator columns using the exact planned names.
  for (composition_role in composition_role_labels) {
    composition_indicator_column <-
      composition_indicator_columns[[composition_role]]
    data[[composition_indicator_column]] <- ifelse(
      as.character(data[[dyad_composition_role_col]]) == composition_role,
      1,
      0
    )
  }

  # Composition-specific member contrasts let mixed-composition models target
  # each exchangeable composition.
  for (composition_label in exchangeable_composition_labels) {
    row_matches_composition <-
      as.character(data[[dyad_composition_col]]) == composition_label
    member_contrast_column <- member_contrast_columns[[composition_label]]
    data[[member_contrast_column]] <- ifelse(
      row_matches_composition,
      data[[dyad_diff_col]],
      0
    )
  }

  data[[dyad_diff_col]] <- NULL
  # These two fixed columns are created before this shared finalizer. Append
  # their rows to the already validated indicator/contrast plan and record the
  # complete composition stage only after every column exists.
  fixed_composition_columns <- tibble::tibble(
    target = c(dyad_composition_col, dyad_composition_role_col),
    predictor = NA_character_,
    temporal_component = "none",
    lag = 0L,
    model_family = "composition",
    column_role = c("composition", "composition_role"),
    variable_role = c("composition", "composition_role"),
    source_column = NA_character_
  )
  data <- record_generated_columns(
    data,
    dplyr::bind_rows(fixed_composition_columns, composition_column_plan)
  )

  data
}
