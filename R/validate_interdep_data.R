#' Validate dyadic input data
#'
#' Checks whether `data` has a valid long-format dyadic structure and returns it
#' as a tibble with an additional `interdep_data` class. Cross-sectional data
#' should contain one row per member within each dyad. Intensive longitudinal
#' data should contain one row per member and measurement occasion within each
#' dyad.
#'
#' @param data A long-format data frame or tibble.
#' @param group Column identifying the dyad.
#' @param member Column identifying the two people or members within each dyad,
#'   such as a person ID.
#' @param role Optional column identifying role that can be used to distinguish
#'   partners within a dyad, such as gender. If no role is supplied, all dyads
#'   in the data are treated as exchangeable.
#' @param time Optional column identifying time or measurement order.
#'
#' @return A tibble with class `interdep_data` and metadata about the dyad,
#'   member, optional role, and optional time columns.
#' @importFrom rlang .data
#'
#' @keywords internal
validate_interdep_data <- function(data, group, member, role = NULL, time = NULL) {

  # Validating Dataframe
  if (!inherits(data, "data.frame")) {
    stop("`data` must be a data frame or tibble.", call. = FALSE)
  }

  out <- tibble::as_tibble(data)

  # Extracting variables
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

  if (has_role && any(is.na(out[[role_name]]))) {
    stop("`role` must not contain missing values.", call. = FALSE)
  }

  if (has_time && any(is.na(out[[time_name]]))) {
    stop("`time` must not contain missing values.", call. = FALSE)
  }

  n_groups <- dplyr::n_distinct(out[[group_name]])

  # Validating that each group has exactly two members
  members_per_group <- dplyr::summarise(
    dplyr::group_by(out, .data[[group_name]]),
    n_members = dplyr::n_distinct(.data[[member_name]]),
    .groups = "drop"
  )[["n_members"]]

  if (any(members_per_group != 2)) {
    stop("Each `group` must contain exactly two unique members.", call. = FALSE)
  }

  # Validating that each member appears at most once per group x time instance.
  if (has_time) {
    group_time_member_sizes <- dplyr::count(
      out,
      .data[[group_name]],
      .data[[time_name]],
      .data[[member_name]],
      name = "n"
    )[["n"]]

    if (any(group_time_member_sizes > 1)) {
      stop("Each `member` must appear at most once per `group`-`time` combination.", call. = FALSE)
    }
  } else {
    group_sizes <- dplyr::count(out, .data[[group_name]], name = "n")[["n"]]
    if (any(group_sizes != 2)) {
      stop("Each `group` must contain exactly two rows. For longitudinal data specify `time`.", call. = FALSE)
    }
  }

  if (n_groups < 2) {
    stop("At least 2 groups are needed.", call. = FALSE)
  }

  # Validating that each member only has a single consistent role across time
  if (has_role) {
    roles_per_member <- dplyr::summarise(
      dplyr::group_by(out, .data[[group_name]], .data[[member_name]]),
      n_roles = dplyr::n_distinct(.data[[role_name]]),
      .groups = "drop"
    )[["n_roles"]]

    if (any(roles_per_member != 1)) {
      stop("Each `member` must have exactly one `role` within each `group`.", call. = FALSE)
    }
  }

  attr(out, "interdep") <- list(
    group = group_name,
    member = member_name,
    role = role_name,
    time = time_name,
    n_dyads = n_groups,
    longitudinal = has_time
  )

  class(out) <- c("interdep_data", class(out))

  out
}
