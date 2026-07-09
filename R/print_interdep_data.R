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
    dyad_type <- format(dyad_compositions$dyad_type, justify = "left")
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

  if (interdep_composition_col %in% names(x)) {
    print_added_column(".i_composition", "inferred dyad composition")
  }

  if (interdep_composition_role_col %in% names(x)) {
    print_added_column(".i_composition_role", "composition-specific member role")
  }

  if (any(startsWith(names(x), paste0(interdep_reserved_prefix, "is_")))) {
    print_added_column(".i_is_*", "composition-role indicator columns")
  }

  if (interdep_diff_col %in% names(x)) {
    print_added_column(".i_diff", "sum-diff contrast for exchangeable dyads; 0 for distinguishable dyads")
  }

  if (any(startsWith(names(x), paste0(interdep_reserved_prefix, "diff_")))) {
    print_added_column(".i_diff_*", "composition-specific sum-diff contrasts")
  }

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

  for (i in seq_len(nrow(generated_column_specs))) {
    print_added_column(
      generated_column_specs$column_pattern[[i]],
      generated_column_specs$description[[i]]
    )
  }

  cat("#\n")

  out <- x
  class(out) <- class(out)[class(out) != "interdep_data"]
  print(out, ...)

  # return original unchanged tibble
  invisible(x)
}

print_added_column <- function(column_pattern, description) {
  cat(sprintf("#   %-34s %s\n", column_pattern, description))
}
