#' Summarize prepared dyadic data
#'
#' Prints the dyadic structure followed by standard summaries for all columns.
#'
#' @param object A `dyadMLM_data` object returned by [prepare_dyad_data()].
#' @param ... Arguments passed to [summary()].
#'
#' @return Invisibly, the standard summary of all columns.
#'
#' @export
summary.dyadMLM_data <- function(object, ...) {
  print_dyadMLM_header(object, title = "Summary of dyadMLM data")
  cat("# Column summaries:\n")

  class(object) <- class(object)[class(object) != "dyadMLM_data"]
  result <- summary(object, ...)
  print(result)
  invisible(result)
}
