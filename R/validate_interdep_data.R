#' Validate package input data (dyadi data)
#'
#' Checks that `data` is a data frame or tibble and returns it as a tibble with
#' an additional `interdep_data` class.
#'
#' @param data A data frame or tibble.
#'
#' @return A tibble with class `interdep_data`.
#' @export
#'
#' @examples
#' validate_interdep_data(data.frame(x = 1:3))
validate_interdep_data <- function(data) {
  if (!inherits(data, "data.frame")) {
    stop("`data` must be a data frame or tibble.", call. = FALSE)
  }

  out <- tibble::as_tibble(data)

  class(out) <- c("interdep_data", class(out))

  out
}
