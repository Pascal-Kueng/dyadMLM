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
#'   `"female__unknown"`, when a `role` column is supplied.
#' @param missing_role How to handle missing values in the `role` column.
#'   `"error"` stops with an error, `"drop"` removes dyads with incomplete role
#'   information, and `"keep"` retains them. Keeping missing roles can produce
#'   unknown role compositions, such as `"female__unknown"`. Ignored when no
#'   `role` column is supplied.
#'
#' @return A tibble with class `interdep_data` and metadata about the dyad,
#'   member, optional role, and optional time columns.
#' @importFrom rlang .data
#'
#' @keywords internal
validate_interdep_data <- function(
    data,
    group,
    member,
    role = NULL,
    time = NULL,
    incomplete_dyads = c("error", "drop", "keep"),
    missing_role = c("error", "drop", "keep")
  ) {

  # Validating Dataframe
  if (!inherits(data, "data.frame")) {
    stop("`data` must be a data frame or tibble.", call. = FALSE)
  }

  out <- tibble::as_tibble(data)

  # Validating that package-owned columns are not already present.
  reserved_columns <- names(out)[startsWith(names(out), ".interdep_")]
  if (length(reserved_columns) > 0) {
    stop(
      "`data` must not contain columns starting with `.interdep_`; these names are reserved by interdep.",
      call. = FALSE
    )
  }

  # Extracting variables
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

  # Validating that all variables exist.
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

  # Validating that structural variables are complete.
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

  # Validating that each member has at most one row per dyad or dyad-time.
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

##############################################################################

resolve_interdep_roles <- function(out, group_name, member_name, role_name, missing_role) {
  known_roles <- out[[role_name]][!is.na(out[[role_name]])]

  if (any(grepl(interdep_composition_sep, as.character(known_roles), fixed = TRUE))) {
    stop(
      sprintf(
        "`role` values must not contain `%s`; this separator is reserved by interdep.",
        interdep_composition_sep
      ),
      call. = FALSE
    )
  }

  known_member_roles <- unique(
    out[!is.na(out[[role_name]]), c(group_name, member_name, role_name), drop = FALSE]
  )

  if (anyDuplicated(known_member_roles[c(group_name, member_name)]) > 0) {
    stop("Each `member` must have exactly one `role` within each `group`.", call. = FALSE)
  }

  names(known_member_roles)[names(known_member_roles) == role_name] <- ".interdep_resolved_role"
  member_roles <- dplyr::left_join(
    unique(out[c(group_name, member_name)]),
    known_member_roles,
    by = c(group_name, member_name)
  )

  missing_role_groups <- unique(
    member_roles[[group_name]][is.na(member_roles[[".interdep_resolved_role"]])]
  )

  if (length(missing_role_groups) > 0) {
    missing_role_group_labels <- paste(as.character(missing_role_groups), collapse = ", ")

    if (missing_role == "error") {
      stop(
        paste0(
          "Each `member` must have at least one non-missing `role` within each `group`. ",
          "Missing role information was found in dyads: ",
          missing_role_group_labels,
          "."
        ),
        call. = FALSE
      )
    }

    if (missing_role == "drop") {
      out <- out[!out[[group_name]] %in% missing_role_groups, , drop = FALSE]
      warning(
        paste0(
          "Dropped dyads with incomplete role information: ",
          missing_role_group_labels,
          "."
        ),
        call. = FALSE
      )
    } else if (missing_role == "keep") {
      warning(
        paste0(
          "Keeping dyads with incomplete role information. Unknown role ",
          "compositions may be produced for dyads: ",
          missing_role_group_labels,
          "."
        ),
        call. = FALSE
      )
    }
  }

  out <- dplyr::left_join(out, member_roles, by = c(group_name, member_name))
  resolved_role <- as.character(out[[".interdep_resolved_role"]])
  if (missing_role == "keep") {
    resolved_role[is.na(resolved_role)] <- interdep_unknown_role
  }
  out[[role_name]] <- resolved_role
  out[[".interdep_resolved_role"]] <- NULL

  out
}

#############################################################################

resolve_incomplete_dyads <- function(out, group_name, member_name, incomplete_dyads) {
  group_member_counts <- dplyr::summarise(
    dplyr::group_by(out, .data[[group_name]]),
    n_members = length(unique(.data[[member_name]])),
    .groups = "drop"
  )

  too_large_groups <- group_member_counts[[group_name]][group_member_counts$n_members > 2]
  if (length(too_large_groups) > 0) {
    stop(
      paste0(
        "Each `group` must contain exactly two unique members. ",
        "Groups with more than two members were found: ",
        paste(as.character(too_large_groups), collapse = ", "),
        "."
      ),
      call. = FALSE
    )
  }

  incomplete_groups <- group_member_counts[[group_name]][group_member_counts$n_members < 2]

  if (length(incomplete_groups) == 0) {
    return(list(data = out, incomplete_groups = incomplete_groups))
  }

  incomplete_group_labels <- paste(as.character(incomplete_groups), collapse = ", ")

  if (incomplete_dyads == "error") {
    stop(
      paste0(
        "Each `group` must contain exactly two unique members. ",
        "Incomplete dyads were found: ",
        incomplete_group_labels,
        "."
      ),
      call. = FALSE
    )
  }

  if (incomplete_dyads == "drop") {
    warning(
      paste0("Dropped incomplete dyads: ", incomplete_group_labels, "."),
      call. = FALSE
    )
    out <- out[!out[[group_name]] %in% incomplete_groups, , drop = FALSE]
    return(list(data = out, incomplete_groups = incomplete_groups[0]))
  }

  if (incomplete_dyads == "keep") {
    warning(
      paste0(
        "Keeping incomplete dyads; composition labels may be unknown for dyads: ",
        incomplete_group_labels,
        "."
      ),
      call. = FALSE
    )

    return(list(data = out, incomplete_groups = incomplete_groups))
  }
}
