#' Create a canonical dyad composition label
#'
#' Sorts role labels before pasting them so composition labels do not depend on
#' row order.
#'
#' @param roles A vector of role labels.
#'
#' @return A single composition label.
#' @keywords internal
canonical_composition <- function(roles) {
  paste(sort(as.character(roles)), collapse = "-")
}
