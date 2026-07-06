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

  # Printing general metadata
  cat("# interdep data\n")
  cat("# Rows: ", nrow(x), " | ", "Dyads: ", n_dyads, " | ",
      "Longitudinal: ", longitudinal, "\n",
      sep = "")

  # Printing structural information
  cat("# Structure: group = ", group,
      ", member = ", member, sep = "")
  if(!is.null(role)) {
    cat(", role = ", role, sep = "")
  }
  if (!is.null(time)) {
    cat(", time = ", time, sep = "")
  }
  cat("\n#\n")



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

  cat("# Added columns:\n")

  if (interdep_composition_col %in% names(x)) {
    cat("#   .i_composition       inferred dyad composition\n")
  }
  if (interdep_composition_role_col %in% names(x)) {
    cat("#   .i_composition_role  composition-specific member role\n")
  }
  if (any(startsWith(names(x), paste0(interdep_reserved_prefix, "is_")))) {
    cat("#   .i_is_*              composition-role indicator columns\n")
  }
  if (interdep_diff_col %in% names(x)) {
    cat("#   .i_diff              sum-diff contrast for exchangeable dyads\n")
  }
  if (any(startsWith(names(x), paste0(interdep_reserved_prefix, "diff_")))) {
    cat("#   .i_diff_*            composition-specific diff columns\n")
  }

  cat("#\n")

  out <- x
  class(out) <- class(out)[class(out) != "interdep_data"]
  print(out, ...)

  # return original unchanged tibble
  invisible(x)
}
