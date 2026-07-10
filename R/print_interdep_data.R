#' @export
print.interdep_data <- function(x, ...) {
  meta <- attr(x, "interdep")

  group <- meta$group
  member <- meta$member
  role <- meta$role
  time <- meta$time
  n_dyads <- meta$n_dyads
  longitudinal <- meta$longitudinal
  dyad_compositions <- meta$dyad_compositions
  dropped_incomplete_dyads <- meta$dropped_incomplete_dyads
  dropped_missing_role_dyads <- meta$dropped_missing_role_dyads

  # Printing general metadata
  cat("# interdep data\n")
  cat("# Rows: ", nrow(x), " | ", "Dyads: ", n_dyads, " | ",
      "Intensive longitudinal: ", ifelse(longitudinal, "yes", "no"), "\n",
      sep = "")

  # Printing structural information
  cat("# Structure: group = ", group,
      ", member = ", member, sep = "")
  if (!is.null(role)) {
    cat(", role = ", role, sep = "")
  }

  if (!is.null(time)) {
    cat(", time = ", time, sep = "")
  }
  cat("\n#\n")

  # Printing dropped dyads if any
  if (length(dropped_incomplete_dyads) > 0) {
    cat(
      "# Dropped incomplete dyads: ",
      format_group_count(dropped_incomplete_dyads, singular = "dyad", plural = "dyads"),
      "\n#\n",
      sep = ""
    )
  }

  if (length(dropped_missing_role_dyads) > 0) {
    cat(
      "# Dropped dyads with incomplete role information: ",
      format_group_count(dropped_missing_role_dyads, singular = "dyad", plural = "dyads"),
      "\n#\n",
      sep = ""
    )
  }

  # Printing dyad compositions
  if (!is.null(dyad_compositions) && nrow(dyad_compositions) > 0) {
    cat("# Dyad compositions:\n")

    composition <- format(dyad_compositions$composition, justify = "left")

    dyad_type_label <- dyad_compositions$dyad_type
    dyad_type_label <- ifelse(
      dyad_compositions$dyad_type_source == "set_by_user",
      paste0(dyad_type_label, " (set by user)"),
      dyad_type_label
    )

    dyad_type <- format(dyad_type_label, justify = "left")
    composition_n_dyads <- format(dyad_compositions$n_dyads, justify = "right")

    for (i in seq_len(nrow(dyad_compositions))) {
      cat("#",
          composition[[i]],
          dyad_type[[i]],
          composition_n_dyads[[i]],
          "dyads\n",
          sep = " ")
    }

    cat("#\n")
  }

  cat("# Added columns:\n")

  fixed_added_columns <- tibble::tribble(
    ~column_pattern,        ~description,
    ".i_composition",       "inferred dyad composition",
    ".i_composition_role",  "composition-specific member role",
    ".i_is_*",              "composition-role indicator columns",
    ".i_diff_*",            "composition-specific sum-diff contrasts; 0 for distinguishable dyads or other exchangeable compositions"
  )
  show_fixed_added_columns <- c(
    interdep_composition_col %in% names(x),
    interdep_composition_role_col %in% names(x),
    any(startsWith(names(x), paste0(interdep_reserved_prefix, "is_"))),
    any(startsWith(names(x), paste0(interdep_reserved_prefix, "diff_")))
  )
  added_columns <- fixed_added_columns[show_fixed_added_columns, ]

  # Users may remove generated columns while keeping the interdep metadata.
  # Only advertise generated model columns that are still present in the data.
  generated_column_specs <- interdep_generated_columns(meta) |>
    dplyr::filter(.data$column %in% names(x)) |>
    # To avoid repeated printing of columns likse .i_*_actor and .i_*_actor
    # if we have multiple variables of that type, we only use distinct.
    dplyr::distinct(
      .data$print_order,
      .data$column_pattern,
      .data$description
    ) |>
    dplyr::arrange(.data$print_order)

  if (nrow(generated_column_specs) > 0) {
    added_columns <- dplyr::bind_rows(
      added_columns,
      generated_column_specs[, c("column_pattern", "description")]
    )
  }

  print_added_columns(added_columns)

  cat("#\n")

  out <- x
  class(out) <- class(out)[class(out) != "interdep_data"]
  print(out, ...)

  # return original unchanged tibble
  invisible(x)
}

print_added_columns <- function(added_columns) {
  if (nrow(added_columns) == 0) {
    return(invisible(NULL))
  }

  column_width <- max(nchar(added_columns$column_pattern, type = "width")) + 2L

  for (i in seq_len(nrow(added_columns))) {
    prefix <- sprintf("#   %-*s", column_width, added_columns$column_pattern[[i]])
    continuation_prefix <- paste0("\n#   ", strrep(" ", column_width))
    wrap_width <- max(20L, getOption("width", 80L) - nchar(prefix, type = "width"))
    description_lines <- strwrap(added_columns$description[[i]], width = wrap_width)
    if (length(description_lines) == 0) {
      description_lines <- ""
    }

    cat(prefix, paste(description_lines, collapse = continuation_prefix), "\n", sep = "")
  }

  invisible(NULL)
}
