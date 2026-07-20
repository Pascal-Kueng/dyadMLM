#' Validate dyadic input data
#'
#' Checks whether `data` has a valid long-format dyadic structure and returns it
#' as a tibble with an additional `dyadMLM_data` class. Cross-sectional data
#' may contain at most one row per member within each dyad. Intensive
#' longitudinal data may contain at most one row per member and measurement
#' occasion within each dyad.
#'
#' @param data A long-format data frame or tibble.
#' @param group Column identifying the dyad.
#' @param member Column identifying the two people or members within each dyad,
#'   such as a person ID.
#' @param role Optional column identifying role that can be used to distinguish
#'   partners within a dyad, such as gender. If no role is supplied, all dyads
#'   in the data are treated as exchangeable.
#' @param time Optional column identifying time or measurement order.
#' @param predictors Optional variables to select and store as metadata for
#'   temporal predictor decomposition and model-helper functions.
#' @param lag_predictors Optional subset of `predictors` for which lag-1
#'   model-ready columns should be created. Requires a finite, integer-valued
#'   numeric `time` variable.
#' @param model_type Requested model-ready column families. Can contain one or
#'   more of `"apim"`, `"dim"`, and `"dsm"`. `"none"` indicates no
#'   model-specific predictor construction and must be used alone.
#' @param dsm_role_order For `model_type = "dsm"`, a character vector giving
#'   the two distinguishable roles in the order used for directional
#'   differences. Required when DSM columns are requested and must be `NULL`
#'   otherwise.
#' @param temporal_predictor_decomposition Requested temporal predictor decomposition
#'   strategy for predictors. `"none"` leaves predictors undecomposed before
#'   model-specific columns are constructed. `"time_2l"` indicates a two-level
#'   temporal predictor decomposition into within-person and between-person
#'   components. `"auto"` resolves to `"time_2l"` when both `time` and
#'   `predictors` are supplied, and to `"none"` otherwise.
#'   Model-specific helpers may apply additional conventions, such as grand-mean
#'   centering raw DIM and DSM dyad means.
#' @param incomplete_dyads How to handle dyads that do not contain exactly two
#'   unique members anywhere in the data. `"error"` stops with an error and
#'   `"drop"` removes the entire dyad.
#' @param missing_role How to handle missing values in the `role` column.
#'   `"error"` stops with an error, `"drop"` removes dyads with incomplete role
#'   information. Ignored when no `role` column is supplied.
#'
#' @return A tibble with class `dyadMLM_data` and metadata about the dyad,
#'   member, optional role, and optional time columns.
#' @importFrom rlang .data :=
#'
#' @keywords internal
validate_dyad_data <- function(
    data,
    group,
    member,
    role = NULL,
    time = NULL,
    predictors = NULL,
    lag_predictors = NULL,
    model_type = "apim",
    dsm_role_order = NULL,
    temporal_predictor_decomposition = c("auto", "time_2l", "none"),
    incomplete_dyads = c("error", "drop"),
    missing_role = c("error", "drop")
  ) {

  # Validate data frame input.
  if (!inherits(data, "data.frame")) {
    stop("`data` must be a data frame or tibble.", call. = FALSE)
  }

  if (inherits(data, "dyadMLM_data")) {
    stop(
      "`data` has already been prepared by dyadMLM. ",
      "`prepare_dyad_data()` expects raw data; start from the original data frame instead.",
      call. = FALSE
    )
  }

  out <- tibble::as_tibble(data)

  # Validate that package-owned columns are not already present.
  reserved_columns <- names(out)[startsWith(names(out), dyad_reserved_prefix)]
  if (length(reserved_columns) > 0) {
    stop(
      "`data` must not contain columns starting with `",
      dyad_reserved_prefix,
      "`; these names are reserved by dyadMLM. Reserved column(s): ",
      paste(reserved_columns, collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  # Extract and match (non column-based) arguments
  incomplete_dyads <- rlang::arg_match(incomplete_dyads)
  missing_role <- rlang::arg_match(missing_role)

  model_type <- normalize_model_type(model_type)
  temporal_predictor_decomposition <- rlang::arg_match(temporal_predictor_decomposition)

  # Extract structural column names.
  group <- rlang::enquo(group)
  if (rlang::quo_is_missing(group)) {
    stop("`group` must be supplied.", call. = FALSE)
  }
  group_name <- rlang::as_name(group)

  member <- rlang::enquo(member)
  if (rlang::quo_is_missing(member)) {
    stop("`member` must be supplied.", call. = FALSE)
  }
  member_name <- rlang::as_name(member)

  role <- rlang::enquo(role)
  has_role <- !rlang::quo_is_null(role)
  role_name <- NULL

  if (has_role) {
    role_name <- rlang::as_name(role)
  }

  dsm_role_order <- resolve_dsm_role_order(
    dsm_role_order = dsm_role_order,
    model_type = model_type,
    has_role = has_role
  )

  time <- rlang::enquo(time)
  has_time <- !rlang::quo_is_null(time)
  time_name <- NULL

  if (has_time) {
    time_name <- rlang::as_name(time)
  }

  # Validate that structural columns exist.
  if (!group_name %in% names(out)) {
    stop(
      "`group` must refer to an existing column in `data`. Column `",
      group_name, "` was not found.",
      call. = FALSE
    )
  }

  if (!member_name %in% names(out)) {
    stop(
      "`member` must refer to an existing column in `data`. Column `",
      member_name, "` was not found.",
      call. = FALSE
    )
  }

  if (has_role && !role_name %in% names(out)) {
    stop(
      "`role` must refer to an existing column in `data`. Column `",
      role_name, "` was not found.",
      call. = FALSE
    )
  }

  if (has_time && !time_name %in% names(out)) {
    stop(
      "`time` must refer to an existing column in `data`. Column `",
      time_name, "` was not found.",
      call. = FALSE
    )
  }

  # Validate that required structural columns are complete.
  if (any(is.na(out[[group_name]]))) {
    stop(
      "`group` must not contain missing values. Found ",
      sum(is.na(out[[group_name]])),
      " affected row(s); fill or remove them before preparing the data.",
      call. = FALSE
    )
  }

  if (any(is.na(out[[member_name]]))) {
    stop(
      "`member` must not contain missing values. Found ",
      sum(is.na(out[[member_name]])),
      " affected row(s); fill or remove them before preparing the data.",
      call. = FALSE
    )
  }

  if (has_time && any(is.na(out[[time_name]]))) {
    stop(
      "`time` must not contain missing values. Found ",
      sum(is.na(out[[time_name]])),
      " affected row(s); fill or remove them before preparing the data.",
      call. = FALSE
    )
  }


  # Extract and validate user-owned model columns!!!
  predictors_quo <- rlang::enquo(predictors)
  predictor_names <- select_dyad_columns(out, predictors_quo, "predictors")
  # Avoid different predictors resolving to the same sanitized name later.
  make_dyad_suffixes(
    predictor_names,
    label_type = "`predictors`",
    rename_hint = "variables"
  )

  lag_predictors_quo <- rlang::enquo(lag_predictors)
  lag_predictor_names <- select_dyad_columns(
    out,
    lag_predictors_quo,
    "lag_predictors"
  )

  predictors_not_selected <- setdiff(lag_predictor_names, predictor_names)
  if (length(predictors_not_selected) > 0) {
    stop(
      "`lag_predictors` must select only variables already selected by `predictors`. ",
      "Not selected by `predictors`: ",
      paste(predictors_not_selected, collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  if (length(lag_predictor_names) > 0) {
    if (!has_time) {
      stop("`lag_predictors` requires `time` to be supplied.", call. = FALSE)
    }

    time_values <- out[[time_name]]
    is_integer_time <- is.numeric(time_values) &&
      all(is.finite(time_values)) &&
      all(time_values == floor(time_values))

    if (!is_integer_time) {
      stop(
        "`lag_predictors` requires `time` to be a finite, integer-valued numeric measurement index. ",
        "Create an occasion index such as 1, 2, 3, ... and supply it as `time`.",
        call. = FALSE
      )
    }
  }

  # Resolve dyads with fewer than two observed members.
  out_list <- resolve_incomplete_dyads(
    out = out,
    group_name = group_name,
    member_name = member_name,
    incomplete_dyads = incomplete_dyads
  )
  out <- out_list$out
  dropped_incomplete_dyads <- out_list$dropped_incomplete_dyads

  # Resolve sparse or missing role information.
  dropped_missing_role_dyads <- out[[group_name]][0]
  if (has_role) {
    out_list <- resolve_dyad_roles(
      out = out,
      group_name = group_name,
      member_name = member_name,
      role_name = role_name,
      missing_role = missing_role
    )
    out <- out_list$out
    dropped_missing_role_dyads <- out_list$dropped_missing_role_dyads
  }

  # Validate that each member has at most one row per dyad or dyad-time.
  if (has_time) {
    if (anyDuplicated(out[c(group_name, time_name, member_name)]) > 0) {
      stop(
        "Each `member` must appear at most once per `group`-`time` combination. ",
        "Affected combination(s): ",
        format_duplicate_combinations(
          out,
          c(group_name, time_name, member_name)
        ),
        ". Remove or combine these duplicate rows.",
        call. = FALSE
      )
    }
  } else {
    if (anyDuplicated(out[c(group_name, member_name)]) > 0) {
      stop(
        "Each `member` must appear at most once per `group`. ",
        "Affected combination(s): ",
        format_duplicate_combinations(out, c(group_name, member_name)),
        ". If these are repeated measurements, supply `time` so rows are validated within each `group`-`time` combination.",
        call. = FALSE
      )
    }
  }

  n_groups <- length(unique(out[[group_name]]))

  if (n_groups < 2) {
    stop("At least 2 complete dyads are required after validation and any requested dropping.", call. = FALSE)
  }


  # Resolve temporal predictor decomposition.
  if (temporal_predictor_decomposition == "time_2l") {
    if (!has_time) {
      stop("`temporal_predictor_decomposition = \"time_2l\"` requires `time` to be supplied.", call. = FALSE)
    }

    if (length(predictor_names) == 0) {
      stop("`temporal_predictor_decomposition = \"time_2l\"` requires `predictors` to be supplied.", call. = FALSE)
    }
  }

  if (temporal_predictor_decomposition == "auto") {
    temporal_predictor_decomposition <- if (has_time && length(predictor_names) > 0) "time_2l" else "none"
  }

  # Check if predictors are numeric in certain cases where needed.
  if (temporal_predictor_decomposition == "time_2l") {
    predictor_is_numeric <- vapply(out[predictor_names], is.numeric, logical(1))
    non_numeric_predictors <- predictor_names[!predictor_is_numeric]

    if (length(non_numeric_predictors) > 0) {
      stop(
        "`predictors` used with `temporal_predictor_decomposition = \"time_2l\"` must be numeric. ",
        "Non-numeric predictor(s): ",
        paste(non_numeric_predictors, collapse = ", "),
        ". Use numeric predictors, or use `temporal_predictor_decomposition = \"none\"` only when the selected `model_type` allows undecomposed non-numeric predictors.",
        call. = FALSE
      )
    }
  }

  if (any(model_type %in% c("dim", "dsm")) && length(predictor_names) > 0) {
    predictor_is_numeric <- vapply(out[predictor_names], is.numeric, logical(1))
    non_numeric_predictors <- predictor_names[!predictor_is_numeric]

    if (length(non_numeric_predictors) > 0) {
      stop(
        "`predictors` used with `model_type = \"dim\"` or `model_type = \"dsm\"` must be numeric. ",
        "DIM and DSM predictor construction computes numeric dyadic predictor scores. ",
        "Non-numeric predictor(s): ",
        paste(non_numeric_predictors, collapse = ", "),
        ".",
        call. = FALSE
      )
    }
  }

  attr(out, "dyadMLM") <- list(
    group = group_name,
    member = member_name,
    role = role_name,
    time = time_name,
    predictors = predictor_names,
    lag_predictors = lag_predictor_names,
    n_dyads = n_groups,
    longitudinal = has_time,
    temporal_predictor_decomposition = temporal_predictor_decomposition,
    model_type = model_type,
    dsm_role_order = dsm_role_order,
    dropped_missing_role_dyads = dropped_missing_role_dyads,
    dropped_incomplete_dyads = dropped_incomplete_dyads
  )

  class(out) <- unique(c("dyadMLM_data", class(out)))

  out
}

##########################################################################
# End Main
##########################################################################

#' Resolve the DSM role order
#'
#' Checks the relationship between `model_type`, `role`, and `dsm_role_order`,
#' validates the requested role order, and returns its stored representation.
#'
#' @param dsm_role_order The requested DSM role order.
#' @param model_type The normalized model types.
#' @param has_role Whether a role column was supplied.
#'
#' @return The validated, unnamed role order, or `NULL`.
#'
#' @keywords internal
resolve_dsm_role_order <- function(dsm_role_order, model_type, has_role) {
  has_dsm <- "dsm" %in% model_type

  if (!has_dsm && !is.null(dsm_role_order)) {
    stop(
      "`dsm_role_order` can only be supplied when `model_type` includes \"dsm\".",
      call. = FALSE
    )
  }

  if (!has_dsm) {
    return(NULL)
  }

  if (!has_role) {
    stop(
      "`model_type = \"dsm\"` requires `role` to be supplied.",
      call. = FALSE
    )
  }

  if (is.null(dsm_role_order)) {
    stop(
      paste0(
        "`model_type = \"dsm\"` requires `dsm_role_order` to be supplied. ",
        "For exchangeable dyads, use `model_type = \"dim\"` instead."
      ),
      call. = FALSE
    )
  }

  if (!is.character(dsm_role_order) ||
      length(dsm_role_order) != 2L ||
      anyNA(dsm_role_order) ||
      any(!nzchar(trimws(dsm_role_order))) ||
      anyDuplicated(trimws(dsm_role_order))) {
    stop(
      paste0(
        "`dsm_role_order` must be a character vector containing exactly two ",
        "distinct, non-missing, non-empty role values, for example ",
        "`c(\"male\", \"female\")`."
      ),
      call. = FALSE
    )
  }

  unname(trimws(dsm_role_order))
}

format_duplicate_combinations <- function(data, columns, max_combinations = 5L) {
  duplicated_rows <- duplicated(data[columns]) |
    duplicated(data[columns], fromLast = TRUE)
  combinations <- unique(data[duplicated_rows, columns, drop = FALSE])
  shown <- utils::head(combinations, max_combinations)
  labels <- character(nrow(shown))

  for (i in seq_len(nrow(shown))) {
    values <- vapply(
      shown[i, , drop = FALSE],
      function(value) as.character(value[1L]),
      character(1L)
    )
    labels[[i]] <- paste0(
      "`", columns, "` = ", values,
      collapse = ", "
    )
  }

  if (nrow(combinations) > nrow(shown)) {
    labels <- c(labels, paste0("... and ", nrow(combinations) - nrow(shown), " more"))
  }
  return(paste(labels, collapse = "; "))
}

resolve_incomplete_dyads <- function(out, group_name, member_name, incomplete_dyads) {

  group_member_counts <- out |>
    dplyr::group_by(.data[[group_name]]) |>
    dplyr::summarise(
      n_members = length(unique(.data[[member_name]])),
      .groups = "drop"
    )

  # Groups with more than two members are never valid dyads.
  too_large_groups <- group_member_counts[[group_name]][group_member_counts$n_members > 2]
  if (length(too_large_groups) > 0) {
    stop(
      paste0(
        "Each `group` must contain at most two unique members. ",
        "Found ",
        format_group_count(
          too_large_groups,
          singular = "group with more than two members",
          plural = "groups with more than two members"
        ),
        "."
      ),
      call. = FALSE
    )
  }

  # Groups with fewer than two members are handled by policy.
  incomplete_groups <- group_member_counts[[group_name]][group_member_counts$n_members < 2]

  # Return early if all groups are complete.
  if (length(incomplete_groups) == 0) {
    return(list(out = out, dropped_incomplete_dyads = incomplete_groups))
  }

  if (incomplete_dyads == "error") {
    stop(
      paste0(
        "Each `group` must contain exactly two unique members. ",
        "Found ",
        format_group_count(
          incomplete_groups,
          singular = "incomplete dyad",
          plural = "incomplete dyads"
        ),
        ". Add the missing member rows or use `incomplete_dyads = \"drop\"` ",
        "to drop these dyads."
      ),
      call. = FALSE
    )
  }

  if (incomplete_dyads == "drop") {
    message(
      paste0(
        "Dropped ",
        format_group_count(
          incomplete_groups,
          singular = "incomplete dyad",
          plural = "incomplete dyads"
        ),
        "."
      )
    )
    out <- out[!out[[group_name]] %in% incomplete_groups, , drop = FALSE]
    return(list(out = out, dropped_incomplete_dyads = incomplete_groups))
  }

  out
}

resolve_dyad_roles <- function(out, group_name, member_name, role_name, missing_role) {
  known_roles <- out[[role_name]][!is.na(out[[role_name]])]
  role_labels <- as.character(known_roles)

  if (any(!nzchar(trimws(role_labels)))) {
    stop(
      "`role` values must not be empty or whitespace-only. Use `NA` for ",
      "unknown roles so `missing_role` can handle them.",
      call. = FALSE
    )
  }

  # Reject role labels that contain the reserved composition separator.
  if (any(grepl(dyad_composition_sep, role_labels, fixed = TRUE))) {
    offending_roles <- unique(known_roles[
      grepl(dyad_composition_sep, as.character(known_roles), fixed = TRUE)
    ])
    stop(
      "`role` values must not contain `", dyad_composition_sep,
      "`; this separator is reserved by dyadMLM. Offending value(s): ",
      paste(sort(as.character(offending_roles)), collapse = ", "),
      ". Rename these role values before preparing the data.",
      call. = FALSE
    )
  }

  # Ignore missing role rows when checking whether known roles are consistent.
  known_member_roles <- unique(
    out[!is.na(out[[role_name]]), c(group_name, member_name, role_name), drop = FALSE]
  )

  if (anyDuplicated(known_member_roles[c(group_name, member_name)]) > 0) {
    stop(
      "Within each `group`, each `member` must have only one non-missing `role` value. ",
      "Group-member pair(s) with conflicting roles: ",
      format_duplicate_combinations(
        known_member_roles,
        c(group_name, member_name)
      ),
      ". Correct the `role` values for these pairs.",
      call. = FALSE
    )
  }

  # Rename the known role column before joining it back to the full data.
  known_member_roles[[dyad_resolved_role_col]] <- known_member_roles[[role_name]]
  known_member_roles[[role_name]] <- NULL

  # Create a lookup table with one resolved role per observed member.
  member_roles <- dplyr::left_join(
    unique(out[c(group_name, member_name)]),
    known_member_roles,
    by = c(group_name, member_name)
  )

  # Find dyads where at least one member has no known role.
  missing_role_groups <- unique(
    member_roles[[group_name]][is.na(member_roles[[dyad_resolved_role_col]])]
  )

  if (length(missing_role_groups) > 0) {
    if (missing_role == "error") {
      stop(
        paste0(
          "Each `member` must have at least one non-missing `role` within each `group` so roles can be resolved across rows. ",
          "Found incomplete role information in ",
          format_group_count(missing_role_groups),
          ". Fill in `role` values or use `missing_role = \"drop\"` to drop these dyads."
        ),
        call. = FALSE
      )
    }

    if (missing_role == "drop") {
      out <- out[!out[[group_name]] %in% missing_role_groups, , drop = FALSE]
      message(
        paste0(
          "Dropped ",
          format_group_count(
            missing_role_groups,
            singular = "dyad with incomplete role information",
            plural = "dyads with incomplete role information"
          ),
          "."
        )
      )
    }
  }

  # Join the resolved member roles back to every original row.
  out <- dplyr::left_join(out, member_roles, by = c(group_name, member_name))

  out[[role_name]] <- out[[dyad_resolved_role_col]]
  out[[dyad_resolved_role_col]] <- NULL

  return(list(out = out, dropped_missing_role_dyads = missing_role_groups))
}
