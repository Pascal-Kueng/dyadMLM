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
  cat("# Rows: ", nrow(x), " | ",
      "Dyads: ", n_dyads, " | ",
      "Longitudinal: ", longitudinal,
      "\n", sep = "")

  # Printing structural information
  cat("# Structure: group = ", group,
      ", member = ", member, sep = "")
  if(!is.null(role)) {
    cat(", role = ", role, sep = "")
  }
  if (!is.null(time)) {
    cat(", time = ", time, sep = "")
  }
  cat("\n\n")

  cat("# Dyad Composition: \n")

  cat("\n\n")

  cat("# Added Columns: \n")

  cat("\n\n")

  out <- x
  class(out) <- class(out)[class(out) != "interdep_data"]
  print(out, ...)

  # return original unchanged tibble
  invisible(x)
}
