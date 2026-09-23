normalize_model_types <- function(model_types) {
  choices <- c("apim", "dim", "dsm", "none")

  if (!is.character(model_types) || length(model_types) == 0 || anyNA(model_types)) {
    stop(
      "`model_types` must be a non-empty character vector without missing values.",
      call. = FALSE
    )
  }

  invalid_model_types <- setdiff(model_types, choices)

  if (length(invalid_model_types) > 0) {
    stop(
      "`model_types` must contain only supported values: ",
      paste(sprintf('"%s"', choices), collapse = ", "),
      ". Invalid value(s): ",
      paste(sprintf('"%s"', invalid_model_types), collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  model_types <- unique(model_types)

  if ("none" %in% model_types && length(model_types) > 1) {
    stop(
      '`model_types = "none"` cannot be combined with other model types.',
      call. = FALSE
    )
  }

  if (all(c("dim", "dsm") %in% model_types)) {
    stop(
      '`model_types = "dim"` and `model_types = "dsm"` cannot be combined. ',
      "DIM currently requires one exchangeable dyad composition, whereas DSM requires one distinguishable dyad composition. ",
      "Prepare the two model parameterizations in separate calls.",
      call. = FALSE
    )
  }

  model_types
}


select_dyad_columns <- function(data, cols_quo, arg) {
  if (rlang::quo_is_null(cols_quo)) {
    return(NULL)
  }

  selected_columns <- tryCatch(
    tidyselect::eval_select(cols_quo, data = data),
    error = function(e) {
      stop(
        sprintf(
          paste0(
            "`%s` must select columns from `data`. Check that the selected columns exist and that the tidyselect expression is valid. ",
            "Underlying selection error: %s"
          ),
          arg,
          conditionMessage(e)
        ),
        call. = FALSE
      )
    }
  )

  names(selected_columns)
}


# Match original rows after subsetting and NA removal, checking for changed data.
match_fitted_rows <- function(model_frame, data) {
  if (!is.data.frame(data)) {
    stop("`data` must be the data frame used to fit the model.", call. = FALSE)
  }
  fitted_rows <- match(row.names(model_frame), row.names(data))
  if (anyNA(fitted_rows)) {
    stop("Could not match the fitted rows to `data`. ",
         "Supply the same unchanged data frame used to fit the model.", call. = FALSE)
  }
  fitted_data <- data[fitted_rows, , drop = FALSE]
  for (column in intersect(names(model_frame), names(fitted_data))) {
    if (!isTRUE(all.equal(model_frame[[column]], fitted_data[[column]],
                          check.attributes = FALSE, tolerance = 0))) {
      stop("Column `", column, "` in `data` does not match the fitted rows. ",
           "Supply the same unchanged data frame used to fit the model.", call. = FALSE)
    }
  }
  fitted_rows
}


# Use fitted columns first; otherwise match rows in the original fitting data.
resolve_fitted_row_argument <- function(argument_quo, argument_name, model_frame,
                                       data = NULL, allow_null = FALSE) {
  if (allow_null && rlang::quo_is_null(argument_quo)) return(NULL)
  column_expression <- rlang::quo_get_expr(argument_quo)
  if (!rlang::is_symbol(column_expression) && !rlang::is_string(column_expression)) {
    stop("`", argument_name, "` must be a column name, with or without quotes. ",
         "Supply the fitting data with `data = your_data`, rather than passing a vector.",
         call. = FALSE)
  }
  column_name <- rlang::as_name(column_expression)

  if (column_name %in% names(model_frame)) {
    value <- model_frame[[column_name]]
  } else {
    if (is.null(data)) {
      stop("Column `", column_name, "` was not found in the fitted model frame. ",
           "Variables not used in the model formula are not retained there. ",
           "Supply the data frame used to fit the model with `data = your_data`. ",
           "Rows excluded during fitting will be handled automatically.", call. = FALSE)
    }
    fitted_data <- data[match_fitted_rows(model_frame, data), , drop = FALSE]
    if (!column_name %in% names(data)) {
      stop("Column `", column_name, "` was not found in the fitted model frame or `data`.",
           call. = FALSE)
    }
    value <- fitted_data[[column_name]]
  }
  if (!is.atomic(value) || !is.null(dim(value)) || length(value) != nrow(model_frame)) {
    stop("Column `", column_name, "` for `", argument_name,
         "` must contain one value per fitted row.", call. = FALSE)
  }
  value
}
