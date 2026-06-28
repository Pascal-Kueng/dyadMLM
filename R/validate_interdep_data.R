#' Validate package input data (dyadi data)
#'
#' Checks that `data` is a data frame or tibble and returns it as a tibble with
#' an additional `interdep_data` class.
#'
#' @param data A data frame or tibble.
#' @param group Column identifying the dyad.
#' @param time Column identifying time or measurement order (optional).
#'
#' @return A tibble with class `interdep_data`.
#' @export
#'
#' @examples
#' validate_interdep_data(
#'   data.frame(dyad_id = c(1, 1, 2, 2), x = 1:4),
#'   group = dyad_id
#' )
validate_interdep_data <- function(data, group, time = NULL) {

  # Validating Dataframe
  if (!inherits(data, "data.frame")) {
    stop("`data` must be a data frame or tibble.", call. = FALSE)
  }

  # Extracing variables
  group <- rlang::enquo(group)
  group_name <- rlang::as_name(group)

  time <- rlang::enquo(time)
  time_name <- NULL

  if (!rlang::quo_is_null(time)) {
    time_name <- rlang::as_name(time)
  }

  # Validating time variable
  if (!is.null(time)) {
    if (!time_name %in% names(data)) {
      stop("`time` must refer to an existing column in `data`.", call. = FALSE)
    }

    if (any(is.na(data[[time_name]]))) {
      stop("`time` must not contain missing values", call. = FALSE)
    }
  }

  # Validating grouping variable
  if (!group_name %in% names(data)) {
    stop("`group` must refer to an existing column in `data`.", call. = FALSE)
  }

  if (any(is.na(data[[group_name]]))) {
    stop("`group` must not contain missing values.", call. = FALSE)
  }

  if (!is.null(time)) {
    group_time_sizes <- dplyr::count(data, .data[[group_name]], .data[[time_name]], name = 'n')[['n']]
    n_groups <- length(group_sizes)
    if (any(group_time_sizes != 2)) {
      stop("Each `group` must contain exactly two rows per timepoint.", call. = FALSE)
    }
  } else {
    group_sizes <- as.integer(table(data[[group_name]]))
    n_groups <- length(group_sizes)
    if (any(group_sizes != 2)) {
      stop("Each `group` must contain exactly two rows. For longitudinal data specify `time`.", call. = FALSE)
    }
  }



  if (n_groups < 2 ) {
    stop"At least 2 groups are needed."
  }

  out <- tibble::as_tibble(data)

  class(out) <- c("interdep_data", class(out))

  out
}
