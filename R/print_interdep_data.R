#' @export
print.interdep_data <- function(data, ...) {
  cat("# interdep data\n")
  cat("# Rows: ", nrow(data), "\n", sep = "")

  out <- data
  class(out) <- class(out)[class(out) != "interdep_data"]
  print(out, ...)

  # return original unchanged tibble
  invisible(data)
}
