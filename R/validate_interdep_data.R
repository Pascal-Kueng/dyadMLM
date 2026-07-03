#' Validate dyadic input data
#'
#' Checks whether `data` has a valid long-format dyadic structure and returns it
#' as a tibble with an additional `interdep_data` class. Cross-sectional data
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
#' @param incomplete_dyads How to handle dyads that do not contain exactly two
#'   unique members anywhere in the data. `"error"` stops with an error,
#'   `"drop"` removes the entire dyad, and `"keep"` retains the observed rows.
#'   Keeping incomplete dyads can produce unknown role compositions, such as
#'   `"female_x_unknown"`, when a `role` column is supplied.
#' @param missing_role How to handle missing values in the `role` column.
#'   `"error"` stops with an error, `"drop"` removes dyads with incomplete role
#'   information, and `"keep"` retains them. Keeping missing roles can produce
#'   unknown role compositions, such as `"female_x_unknown"`. Ignored when no
#'   `role` column is supplied.
#'
#' @return A tibble with class `interdep_data` and metadata about the dyad,
#'   member, optional role, and optional time columns.
#' @importFrom rlang .data
#'
#' @export
validate_interdep_data <- function(
    data,
    group,
    member,
    role = NULL,
    time = NULL,
    incomplete_dyads = c("error", "drop", "keep"),
    missing_role = c("error", "drop", "keep")
  ) {

  # Validate data frame input.
  if (!inherits(data, "data.frame")) {
    stop("`data` must be a data frame or tibble.", call. = FALSE)
  }

  out <- tibble::as_tibble(data)

  # Validate that package-owned columns are not already present.
  reserved_columns <- names(out)[startsWith(names(out), interdep_reserved_prefix)]
  if (length(reserved_columns) > 0) {
    stop(
      sprintf(
        "`data` must not contain columns starting with `%s`; these names are reserved by interdep.",
        interdep_reserved_prefix
      ),
      call. = FALSE
    )
  }

  # Extract structural column names.
  incomplete_dyads <- rlang::arg_match(incomplete_dyads)
  missing_role <- rlang::arg_match(missing_role)

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

  time <- rlang::enquo(time)
  has_time <- !rlang::quo_is_null(time)
  time_name <- NULL

  if (has_time) {
    time_name <- rlang::as_name(time)
  }

  # Validate that structural columns exist.
  if (!group_name %in% names(out)) {
    stop("`group` must refer to an existing column in `data`.", call. = FALSE)
  }

  if (!member_name %in% names(out)) {
    stop("`member` must refer to an existing column in `data`.", call. = FALSE)
  }

  if (has_role && !role_name %in% names(out)) {
    stop("`role` must refer to an existing column in `data`.", call. = FALSE)
  }

  if (has_time && !time_name %in% names(out)) {
    stop("`time` must refer to an existing column in `data`.", call. = FALSE)
  }

  # Validate that required structural columns are complete.
  if (any(is.na(out[[group_name]]))) {
    stop("`group` must not contain missing values.", call. = FALSE)
  }

  if (any(is.na(out[[member_name]]))) {
    stop("`member` must not contain missing values.", call. = FALSE)
  }

  if (has_time && any(is.na(out[[time_name]]))) {
    stop("`time` must not contain missing values.", call. = FALSE)
  }

  # Resolve dyads with fewer than two observed members.
  dyad_resolution <- resolve_incomplete_dyads(
    out = out,
    group_name = group_name,
    member_name = member_name,
    incomplete_dyads = incomplete_dyads
  )
  out <- dyad_resolution$data
  incomplete_groups <- dyad_resolution$incomplete_groups

  # Resolve sparse or missing role information.
  if (has_role) {
    out <- resolve_interdep_roles(
      out = out,
      group_name = group_name,
      member_name = member_name,
      role_name = role_name,
      missing_role = missing_role
    )
    incomplete_groups <- incomplete_groups[incomplete_groups %in% unique(out[[group_name]])]
  }

  # Validate that each member has at most one row per dyad or dyad-time.
  if (has_time) {
    if (anyDuplicated(out[c(group_name, time_name, member_name)]) > 0) {
      stop("Each `member` must appear at most once per `group`-`time` combination.", call. = FALSE)
    }
  } else {
    if (anyDuplicated(out[c(group_name, member_name)]) > 0) {
      stop("Each `member` must appear at most once per `group`. For longitudinal data specify `time`.", call. = FALSE)
    }
  }

  n_groups <- length(unique(out[[group_name]]))

  if (n_groups < 2) {
    stop("At least 2 groups are needed.", call. = FALSE)
  }

  # Store no incomplete dyads as an empty slice of the group column. This keeps
  # the metadata type aligned with the user's group IDs, e.g. character,
  # integer, or factor.
  if (length(incomplete_groups) == 0) {
    incomplete_groups <- out[[group_name]][0]
  }

  attr(out, "interdep") <- list(
    group = group_name,
    member = member_name,
    role = role_name,
    time = time_name,
    n_dyads = n_groups,
    longitudinal = has_time,
    incomplete_dyads = incomplete_groups,
    incomplete_dyads_action = incomplete_dyads
  )

  class(out) <- unique(c("interdep_data", class(out)))

  out
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
    return(list(data = out, incomplete_groups = incomplete_groups))
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
        "."
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
    return(list(data = out, incomplete_groups = incomplete_groups[0]))
  }

  if (incomplete_dyads == "keep") {
    warning(
      paste0(
        "Keeping ",
        format_group_count(
          incomplete_groups,
          singular = "incomplete dyad",
          plural = "incomplete dyads"
        ),
        ". Composition labels may be unknown."
      ),
      call. = FALSE
    )

    return(list(data = out, incomplete_groups = incomplete_groups))
  }
}

resolve_interdep_roles <- function(out, group_name, member_name, role_name, missing_role) {
  known_roles <- out[[role_name]][!is.na(out[[role_name]])]

  # Reject role labels that contain the reserved composition separator.
  if (any(grepl(interdep_composition_sep, as.character(known_roles), fixed = TRUE))) {
    stop(
      sprintf(
        "`role` values must not contain `%s`; this separator is reserved by interdep.",
        interdep_composition_sep
      ),
      call. = FALSE
    )
  }

  # Ignore missing role rows when checking whether known roles are consistent.
  known_member_roles <- unique(
    out[!is.na(out[[role_name]]), c(group_name, member_name, role_name), drop = FALSE]
  )

  if (anyDuplicated(known_member_roles[c(group_name, member_name)]) > 0) {
    stop("Each `member` must have exactly one `role` within each `group`.", call. = FALSE)
  }

  # Rename the known role column before joining it back to the full data.
  known_member_roles[[interdep_resolved_role_col]] <- known_member_roles[[role_name]]
  known_member_roles[[role_name]] <- NULL

  # Create a lookup table with one resolved role per observed member.
  member_roles <- dplyr::left_join(
    unique(out[c(group_name, member_name)]),
    known_member_roles,
    by = c(group_name, member_name)
  )

  # Find dyads where at least one member has no known role.
  missing_role_groups <- unique(
    member_roles[[group_name]][is.na(member_roles[[interdep_resolved_role_col]])]
  )

  if (length(missing_role_groups) > 0) {
    if (missing_role == "error") {
      stop(
        paste0(
          "Each `member` must have at least one non-missing `role` within each `group`. ",
          "Found incomplete role information in ",
          format_group_count(missing_role_groups),
          "."
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
    } else if (missing_role == "keep") {
      warning(
        paste0(
          "Keeping ",
          format_group_count(
            missing_role_groups,
            singular = "dyad with incomplete role information",
            plural = "dyads with incomplete role information"
          ),
          ". Unknown role compositions may be produced."
        ),
        call. = FALSE
      )
    }
  }

  # Join the resolved member roles back to every original row.
  out <- dplyr::left_join(out, member_roles, by = c(group_name, member_name))

  # Convert unresolved roles from NA to "unknown" when requested.
  if (missing_role == "keep") {
    out[[interdep_resolved_role_col]][is.na(out[[interdep_resolved_role_col]])] <- interdep_unknown_label
  }

  out[[role_name]] <- as.character(out[[interdep_resolved_role_col]])
  out[[interdep_resolved_role_col]] <- NULL

  out
}
