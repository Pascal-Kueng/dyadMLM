# Package-wide separator for composition labels.
interdep_composition_sep <- "__"

# Role label used when a member's role is unknown but retained.
interdep_unknown_role <- "unknown"

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
canonical_composition <- function(roles, sep = interdep_composition_sep) {
  paste(sort(as.character(roles)), collapse = sep)
}


#' @rdname canonical_composition
#' @param composition A composition label.
#' @param role A row-level role label.
#' @keywords internal
composition_role_label <- function(composition, role, sep = interdep_composition_sep) {
  paste(as.character(composition), as.character(role), sep = sep)
}


#' Format group identifiers for validation messages
#'
#' Converts a vector of dyad or group identifiers into a compact comma-separated
#' string for use in validation errors and warnings.
#'
#' @param groups A vector of group identifiers.
#' @param max Maximum number of identifiers to show before truncating the list.
#'
#' @return A single character string.
#' @keywords internal
format_group_list <- function(groups, max = 10) {
  groups <- as.character(groups)

  if (length(groups) <= max) {
    return(paste(groups, collapse = ", "))
  }

  paste0(
    paste(groups[seq_len(max)], collapse = ", "),
    ", ... and ",
    length(groups) - max,
    " more"
  )
}
