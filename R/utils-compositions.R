#' Create a canonical dyad composition label
#'
#' Sorts role labels before pasting them so composition labels do not depend on
#' row order.
#'
#' @param roles A vector of role labels.
#' @param sep Separator used between label components.
#'
#' @return A single composition label.
#' @keywords internal
canonical_composition <- function(roles, sep = "__") {
  paste(sort(as.character(roles)), collapse = sep)
}

#' @rdname canonical_composition
#' @param composition A composition label.
#' @param role A row-level role label.
#' @keywords internal
composition_role_label <- function(composition, role, sep = "__") {
  paste(as.character(composition), as.character(role), sep = sep)
}
