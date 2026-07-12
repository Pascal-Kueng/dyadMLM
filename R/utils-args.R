normalize_model_type <- function(model_type) {
  choices <- c("apim", "dim", "dsm", "none")

  if (!is.character(model_type) || length(model_type) == 0 || anyNA(model_type)) {
    stop(
      "`model_type` must be a non-empty character vector without missing values.",
      call. = FALSE
    )
  }

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

  if (all(c("dim", "dsm") %in% model_type)) {
    stop(
      '`model_type = "dim"` and `model_type = "dsm"` cannot be combined. ',
      "DIM currently requires one exchangeable dyad composition, whereas DSM requires one distinguishable dyad composition. ",
      "Prepare the two model parameterizations in separate calls.",
      call. = FALSE
    )
  }

  model_type
}


select_interdep_columns <- function(data, cols_quo, arg) {
  if (rlang::quo_is_null(cols_quo)) {
    return(NULL)
  }

  selected_columns <- tryCatch(
    tidyselect::eval_select(cols_quo, data = data),
    error = function(e) {
      stop(
        sprintf(
          "`%s` must select columns from `data`. Check that the selected columns exist and that the tidyselect expression is valid.",
          arg
        ),
        call. = FALSE
      )
    }
  )

  names(selected_columns)
}
