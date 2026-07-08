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
    print_added_column(".i_diff", "sum-diff contrast; 0 for distinguishable dyads")
  }

  if (any(startsWith(names(x), paste0(interdep_reserved_prefix, "diff_")))) {
    print_added_column(".i_diff_*", "composition-specific sum-diff contrasts")
  }

  if (any(startsWith(names(x), interdep_reserved_prefix) & endsWith(names(x), "_cwp"))) {
    print_added_column(".i_*_cwp", "within-person centred predictors")
  }
  if (any(startsWith(names(x), interdep_reserved_prefix) & endsWith(names(x), "_cbp"))) {
    print_added_column(".i_*_cbp", "between-person centred predictors")
  }

  if (any(startsWith(names(x), interdep_reserved_prefix) & endsWith(names(x), "_raw_actor"))) {
    print_added_column(".i_*_raw_actor/partner", "APIM raw actor/partner predictors")
  }

  if (any(startsWith(names(x), interdep_reserved_prefix) & endsWith(names(x), "_cwp_actor"))) {
    print_added_column(".i_*_cwp_actor/partner", "APIM within-person actor/partner predictors")
  }
  if (any(startsWith(names(x), interdep_reserved_prefix) & endsWith(names(x), "_cbp_actor"))) {
    print_added_column(".i_*_cbp_actor/partner", "APIM between-person actor/partner predictors")
  }

  if (any(startsWith(names(x), interdep_reserved_prefix) & endsWith(names(x), "_raw_dyad_mean_gmc"))) {
    print_added_column(".i_*_raw_dyad_mean_gmc", "DIM raw dyad means, grand-mean centred")
  }
  if (any(startsWith(names(x), interdep_reserved_prefix) & endsWith(names(x), "_raw_within_dyad_deviation"))) {
    print_added_column(".i_*_raw_within_dyad_deviation", "DIM raw within-dyad deviations")
  }

  if (any(startsWith(names(x), interdep_reserved_prefix) & endsWith(names(x), "_cwp_dyad_mean"))) {
    print_added_column(".i_*_cwp_dyad_mean", "DIM shared momentary deviations")
  }
  if (any(startsWith(names(x), interdep_reserved_prefix) & endsWith(names(x), "_cwp_within_dyad_deviation"))) {
    print_added_column(".i_*_cwp_within_dyad_deviation", "DIM deviations from shared momentary levels")
  }
  if (any(startsWith(names(x), interdep_reserved_prefix) & endsWith(names(x), "_cbp_dyad_mean"))) {
    print_added_column(".i_*_cbp_dyad_mean", "DIM shared usual levels, centred across persons")
  }
  if (any(startsWith(names(x), interdep_reserved_prefix) & endsWith(names(x), "_cbp_within_dyad_deviation"))) {
    print_added_column(".i_*_cbp_within_dyad_deviation", "DIM deviations from dyad usual levels")
  }

  cat("#\n")

  out <- x
  class(out) <- class(out)[class(out) != "interdep_data"]
  print(out, ...)

  # return original unchanged tibble
  invisible(x)
}

print_added_column <- function(column_family, description) {
  cat(sprintf("#   %-34s %s\n", column_family, description))
}
