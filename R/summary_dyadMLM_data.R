#' Summarize prepared dyadic data
#'
#' Prints the dyadic structure followed by standard column summaries.
#'
#' @param object A `dyadMLM_data` object returned by [prepare_dyad_data()].
#' @param ... Arguments passed to [summary()].
#' @param include_generated Whether to include package-generated `.dy_` columns
#'   in the column summaries. The default is `FALSE`.
#'
#' @return Invisibly, the standard summary of the selected columns.
#'
#' @export
summary.dyadMLM_data <- function(object, ..., include_generated = FALSE) {
  if (!identical(include_generated, FALSE) &&
      !identical(include_generated, TRUE)) {
    stop("`include_generated` must be `TRUE` or `FALSE`.", call. = FALSE)
  }

  print_dyadMLM_header(object, title = "Summary of dyadMLM data")

  generated <- startsWith(names(object), dyad_reserved_prefix)
  n_generated <- sum(generated)
  object_label <- deparse1(substitute(object))

  if (n_generated > 0L) {
    cat("# Generated columns: ", n_generated, "\n", sep = "")
    print_wrapped_comment_fields(
      paste0(
        "Use `print(", object_label,
        ")` to see their names and descriptions."
      )
    )
    if (!include_generated) {
      print_wrapped_comment_fields(
        paste0(
          "Use `summary(", object_label,
          ", include_generated = TRUE)` to summarize them."
        )
      )
    }
    cat("#\n")
  }

  if (include_generated) {
    cat("# All-column summaries:\n")
  } else {
    cat("# Original-column summaries:\n")
    object <- object[, !generated, drop = FALSE]
  }

  class(object) <- class(object)[class(object) != "dyadMLM_data"]
  result <- summary(object, ...)
  print(result)
  invisible(result)
}
