normalize_model_type <- function(model_type) {
  choices <- c("apim", "dim", "undirected_dsm", "none")
  invalid_model_types <- setdiff(model_type, choices)

  if (length(invalid_model_types) > 0) {
    stop(
      "`model_type` must contain only supported values: ",
      paste(sprintf('"%s"', choices), collapse = ", "),
      ". Invalid value(s): ",
      paste(sprintf('"%s"', invalid_model_types), collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  model_type <- unique(model_type)

  if ("none" %in% model_type && length(model_type) > 1) {
    stop(
      '`model_type = "none"` cannot be combined with other model types.',
      call. = FALSE
    )
  }

  model_type
}
