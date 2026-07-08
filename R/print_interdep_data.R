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


  if (any(startsWith(names(x), interdep_reserved_prefix) & endsWith(names(x), "_cwp"))) {
    cat("#   .i_*_cwp             within-person centred predictors\n")
  }
  if (any(startsWith(names(x), interdep_reserved_prefix) & endsWith(names(x), "_cbp"))) {
    cat("#   .i_*_cbp             between-person centred predictors\n")
  }


  if (any(startsWith(names(x), interdep_reserved_prefix) & endsWith(names(x), "_raw_actor"))) {
    cat("#   .i_*_raw_actor       raw actor predictor columns\n")
  }
  if (any(startsWith(names(x), interdep_reserved_prefix) & endsWith(names(x), "_raw_partner"))) {
    cat("#   .i_*_raw_partner     raw partner predictor columns\n")
  }

  if (any(startsWith(names(x), interdep_reserved_prefix) & endsWith(names(x), "_cwp_actor"))) {
    cat("#   .i_*_cwp_actor       within-person actor predictor columns\n")
  }
  if (any(startsWith(names(x), interdep_reserved_prefix) & endsWith(names(x), "_cwp_partner"))) {
    cat("#   .i_*_cwp_partner     within-person partner predictor columns\n")
  }
  if (any(startsWith(names(x), interdep_reserved_prefix) & endsWith(names(x), "_cbp_actor"))) {
    cat("#   .i_*_cbp_actor       between-person actor predictor columns\n")
  }
  if (any(startsWith(names(x), interdep_reserved_prefix) & endsWith(names(x), "_cbp_partner"))) {
    cat("#   .i_*_cbp_partner     between-person partner predictor columns\n")
  }

  cat("#\n")

  out <- x
  class(out) <- class(out)[class(out) != "interdep_data"]
  print(out, ...)

  # return original unchanged tibble
  invisible(x)
}
