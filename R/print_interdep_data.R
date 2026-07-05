#' @export
print.interdep_data <- function(data, ...) {
  meta <- attr(data, "interdep")

  group <- meta$group
  member <- meta$member
  role <- meta$role
  time <- meta$time
  predictors <- meta$predictors
  n_dyads <- meta$n_dyads
  longitudinal <- meta$longitudinal
  incomplete_dyads <- meta$incomplete_dyads
  incomplete_dyads_action <- meta$incomplete_dyads_action
  dyad_compositions <- meta$dyad_compositions

  # print
  cat("# interdep data\n")
  cat("# Rows: ", nrow(data), " | ",
      "Dyads: ", n_dyads, " | ",
      "Longitudinal: ", longitudinal, " | ",
      "Model Type: placeholder | ",
      "Centering: placeholder",
      "\n\n", sep = "")

  out <- data
  class(out) <- class(out)[class(out) != "interdep_data"]
  print(out, ...)

  # return original unchanged tibble
  invisible(data)
}
