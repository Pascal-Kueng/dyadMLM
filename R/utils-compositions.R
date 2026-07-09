#############################################################################
# CONSTANTS
############################################################################

# Package-wide separator for composition labels.
interdep_composition_sep <- "_x_"

# Separator for appending a member role to a dyad composition label.
interdep_composition_role_sep <- "_"

# Label used when no role column is supplied.
interdep_assumed_exchangeable_label <- "assumed_exchangeable"

# Prefix to be used for package-owned / reserved columns.
interdep_reserved_prefix <- ".i_"

# Package generated columns will use the following names consistently
interdep_composition_col <- paste0(interdep_reserved_prefix, "composition")
interdep_composition_role_col <- paste0(interdep_reserved_prefix, "composition_role")
interdep_dyad_type_col <- paste0(interdep_reserved_prefix, "dyad_type")
interdep_raw_composition_col <- paste0(interdep_reserved_prefix, "raw_composition")
interdep_resolved_role_col <- paste0(interdep_reserved_prefix, "resolved_role")
interdep_diff_col <- paste0(interdep_reserved_prefix, "diff")
interdep_arbitrary_role_col <- paste0(interdep_reserved_prefix, "arbitrary_role")

############################################################################
# HELPER FUNCTIONS
###########################################################################

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
composition_role_label <- function(composition, role, sep = interdep_composition_role_sep) {
  paste(as.character(composition), as.character(role), sep = sep)
}


#' Create safe suffixes for generated interdep columns
#'
#' @param labels Labels that will be used to build generated column names.
#'
#' @return A named character vector. Names are the original labels; values are
#'   sanitized column-name suffixes.
#' @keywords internal
make_interdep_suffixes <- function(labels, label_type = "labels",
                                   rename_hint = "role or composition labels") {
  labels <- unique(as.character(labels))
  suffixes <- gsub("[^[:alnum:]_]+", "_", labels)

  duplicated_suffixes <- unique(suffixes[duplicated(suffixes)])

  if (length(duplicated_suffixes) > 0) {
    conflicts <- character(length(duplicated_suffixes))

    for (i in seq_along(duplicated_suffixes)) {
      conflicts[[i]] <- paste(labels[suffixes == duplicated_suffixes[[i]]], collapse = ", ")
    }

    stop(
      "Some ",
      label_type,
      " produce the same generated column name after sanitizing: ",
      paste(conflicts, collapse = "; "),
      ". Please rename these ",
      rename_hint,
      ".",
      call. = FALSE
    )
  }

  stats::setNames(suffixes, labels)
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


#' Format counted group identifiers for validation messages
#'
#' Converts a vector of dyad or group identifiers into text that includes both
#' the number of groups and a compact list of their identifiers.
#'
#' @param groups A vector of group identifiers.
#' @param singular Singular label for one group.
#' @param plural Plural label for multiple groups.
#' @param max Maximum number of identifiers to show before truncating the list.
#'
#' @return A single character string.
#' @keywords internal
format_group_count <- function(groups, singular = "dyad", plural = "dyads", max = 10) {
  n_groups <- length(groups)
  group_label <- if (n_groups == 1) singular else plural
  id_label <- if (n_groups == 1) "ID" else "IDs"

  paste0(
    n_groups,
    " ",
    group_label,
    ", with ",
    id_label,
    ": ",
    format_group_list(groups, max = max)
  )
}
