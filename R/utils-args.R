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


# Turn a dyad or role argument into one vector with a value per fitted row
# (or NULL when allowed). `argument_quo` is a quosure: the user's expression
# together with the environment where it was written. Keeping both allows
# wrappers to forward arguments with `{{ }}` without losing their meaning.
resolve_fitted_row_argument <- function(
  argument_quo,
  argument_name,
  model_frame,
  allow_null = FALSE
) {
  # Bare names look in the fitted data first, then in the caller's environment.
  # `.data$dyad` explicitly selects a fitted column; `.env$dyad` explicitly
  # selects the caller's vector, even if a fitted column has the same name.
  value <- tryCatch(
    rlang::eval_tidy(argument_quo, data = model_frame),
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

  # A single string is also accepted as a column name, e.g. dyad = "coupleID".
  if (rlang::is_string(value)) {
    if (!value %in% names(model_frame)) {
      stop(
        sprintf(
          "`%s` does not name a column in the fitted model frame.", value
        ),
        call. = FALSE
      )
    }
    value <- model_frame[[value]]
  }

  # Require a vector of length n, where n is the number of fitted rows.
  # External vectors must already follow fitted-row order: length alone cannot
  # tell us which observation each value belongs to or restore omitted rows.
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
