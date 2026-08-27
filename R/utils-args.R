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

  # Prefer a fitted column to an inherited object such as stats::time(). A
  # name defined directly by the caller is instead treated as an external
  # vector, which also preserves argument forwarding through wrappers.
  if (rlang::is_symbol(argument_expression)) {
    column_name <- rlang::as_name(argument_expression)
    if (column_name %in% names(model_frame) &&
        !exists(column_name, envir = calling_environment, inherits = FALSE)) {
      return(model_frame[[column_name]])
    }
  }

  value <- tryCatch(
    rlang::eval_tidy(argument_quo),
    error = function(error) {
      stop(
        sprintf(
          "`%s` could not be evaluated: %s",
          argument_name, conditionMessage(error)
        ),
        call. = FALSE
      )
    }
  )

  if (is.null(value) && allow_null) {
    return(NULL)
  }

  if (rlang::is_string(value)) {
    if (!value %in% names(model_frame)) {
      stop(
        sprintf(
          "`%s` does not name a column in the fitted model frame.", value
        ),
        call. = FALSE
      )
    }
    return(model_frame[[value]])
  }

  valid_vector <- is.atomic(value) &&
    is.null(dim(value)) &&
    length(value) == nrow(model_frame)

  if (!valid_vector) {
    stop(
      sprintf(
        paste0(
          "`%s` must name a column in the fitted model frame or evaluate ",
          "to a vector of length %d."
        ),
        argument_name, nrow(model_frame)
      ),
      call. = FALSE
    )
  }

  value
}


# Factors can encode an explicit missing-value level for which anyNA() on the
# factor codes is false. Identifier validation therefore also inspects the
# represented labels. Scheduled-time validation may additionally reject an
# unused missing level because every declared level is treated as substantive.
has_missing_identifier_values <- function(
  values,
  include_unused_factor_levels = FALSE
) {
  missing_values <- anyNA(values)
  if (is.factor(values)) {
    missing_values <- missing_values || anyNA(as.character(values))
    if (include_unused_factor_levels) {
      missing_values <- missing_values || anyNA(levels(values))
    }
  }
  missing_values
}
