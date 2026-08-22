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


# Resolve a quosure to a fitted-row column or an aligned external vector.
resolve_fitted_row_argument <- function(
  argument_quo,
  argument_name,
  model_frame,
  allow_null = FALSE
) {
  argument_expression <- rlang::quo_get_expr(argument_quo)
  calling_environment <- rlang::quo_get_env(argument_quo)
  unquoted_name <- if (rlang::is_symbol(argument_expression)) {
    rlang::as_name(argument_expression)
  } else {
    NULL
  }

  # Prefer a fitted column to an inherited object such as stats::time(). A
  # name defined directly by the caller is instead treated as an external
  # vector, which also preserves argument forwarding through wrappers.
  if (!is.null(unquoted_name) &&
      !exists(unquoted_name, envir = calling_environment, inherits = FALSE) &&
      unquoted_name %in% names(model_frame)) {
    return(model_frame[[unquoted_name]])
  }

  resolved_value <- tryCatch(
    rlang::eval_tidy(argument_quo),
    error = function(error) {
      stop(
        sprintf(
          "`%s` could not be evaluated: %s",
          argument_name,
          conditionMessage(error)
        ),
        call. = FALSE
      )
    }
  )

  if (allow_null && is.null(resolved_value)) {
    return(NULL)
  }

  if (rlang::is_string(resolved_value)) {
    if (!resolved_value %in% names(model_frame)) {
      stop(
        sprintf(
          "`%s` does not name a column in the fitted model frame.",
          resolved_value
        ),
        call. = FALSE
      )
    }
    return(model_frame[[resolved_value]])
  }

  if (!is.atomic(resolved_value) || !is.null(dim(resolved_value)) ||
      length(resolved_value) != nrow(model_frame)) {
    stop(
      sprintf(
        paste0(
          "`%s` must name a column in the fitted model frame or evaluate ",
          "to a vector of length %d."
        ),
        argument_name,
        nrow(model_frame)
      ),
      call. = FALSE
    )
  }

  return(resolved_value)
}
