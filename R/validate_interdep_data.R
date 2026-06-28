#' Validate package input data (dyadic data)
#'
#' Checks that `data` is a data frame or tibble and returns it as a tibble with
#' an additional `interdep_data` class.
#'
#' @param data A data frame or tibble.
#' @param group Column identifying the dyad.
#' @param member Column identifying the members of the dyad (e.g., a person-id).
#' @param time Column identifying time or measurement order (optional).
#'
#' @return A tibble with class `interdep_data`.
#' @importFrom rlang .data
#' @export
#'
#' @examples
#' validate_interdep_data(
#'   data.frame(dyad_id = c(1, 1, 2, 2), person_id = c(1,2,3,4), x = 1:4),
#'   group = dyad_id,
#'   member = person_id
#' )
validate_interdep_data <- function(data, group, member, time = NULL) {

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

  time <- rlang::enquo(time)
  has_time <- !rlang::quo_is_null(time)
  time_name <- NULL

  if (has_time) {
    time_name <- rlang::as_name(time)
  }

  # Validating that all variables exist.
  if (has_time) {
    if (!time_name %in% names(out)) {
      stop("`time` must refer to an existing column in `data`.", call. = FALSE)
    }

    if (any(is.na(out[[time_name]]))) {
      stop("`time` must not contain missing values.", call. = FALSE)
    }
  }

  if (!member_name %in% names(out)) {
    stop("`member` must refer to an existing column in `data`.", call. = FALSE)
  }

  if (any(is.na(out[[member_name]]))) {
    stop("`member` must not contain missing values.", call. = FALSE)
  }

  if (!group_name %in% names(out)) {
    stop("`group` must refer to an existing column in `data`.", call. = FALSE)
  }

  if (any(is.na(out[[group_name]]))) {
    stop("`group` must not contain missing values.", call. = FALSE)
  }


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

    n_groups <- length(unique(out[[group_name]]))

    if (any(group_time_member_sizes > 1)) {
      stop("Each `member` must appear at most once per `group`-`time` combination.", call. = FALSE)
    }
  } else {
    group_sizes <- dplyr::count(out, .data[[group_name]], name = 'n')[['n']]
    n_groups <- length(group_sizes)
    if (any(group_sizes != 2)) {
      stop("Each `group` must contain exactly two rows. For longitudinal data specify `time`.", call. = FALSE)
    }
  }

  if (n_groups < 2 ) {
    stop("At least 2 groups are needed.", call. = FALSE)
  }

  class(out) <- c("interdep_data", class(out))

  out
}
