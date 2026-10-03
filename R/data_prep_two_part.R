#' Apply two-part coding to partner predictors
#'
#' Where no partner existed, there is no partner value. Numeric partner
#' predictors are set to 0 there (two-part coding), and the partner status
#' columns `.partner_exists` and `.partner_exists_lag1` let the model give these
#' rows their own mean. Contemporaneous partner predictors follow the status at
#' the same occasion, and lagged partner predictors follow the status at the
#' previous occasion. Centering happens before this step, so 0 is the centered
#' reference. Non-numeric partner predictors cannot be set to 0. Instead, they
#' are set to `NA` there, with a warning.
#'
#' @param data A `dyadMLM_data` object with APIM partner columns and the
#'   temporary partner status column.
#'
#' @return `data` with two-part coded partner columns, the partner status
#'   columns, and the temporary status column for the previous occasion.
#' @keywords internal
apply_two_part_coding <- function(data) {
  meta_data <- attr(data, "dyadMLM")
  if (is.null(meta_data$partner_exists)) {
    return(data)
  }

  # The current status (`.dy_partner_exists`) was added during validation. Add
  # the status at the previous occasion, then public 0/1 copies of both.
  data <- add_previous_partner_status(data)
  data <- add_partner_status_columns(data)

  # One row per partner column. Lagged columns follow the status at the
  # previous occasion, the others the current status.
  partner_columns <- meta_data$apim_predictors |>
    dplyr::mutate(
      column = .data$partner_column,
      predictor = .data$predictor,
      is_lagged = .data$lag > 0L,
      status_column = dplyr::if_else(
        .data$is_lagged,
        dyad_partner_exists_lag1_col,
        dyad_partner_exists_col
      ),
      .keep = "none"
    ) |>
    # One TRUE or FALSE per partner column.
    dplyr::mutate(
      is_numeric = vapply(
        .data$column,
        FUN = function(column) is.numeric(data[[column]]),
        FUN.VALUE = logical(1L)
      ),
      has_no_partner_rows = vapply(
        .data$status_column,
        FUN = function(status_column) any(data[[status_column]] %in% FALSE),
        FUN.VALUE = logical(1L)
      )
    )

  # Two-part coding, part 2: partner predictors are 0 where no partner existed.
  for (i in seq_len(nrow(partner_columns))) {
    column <- partner_columns$column[[i]]
    # `%in% FALSE` skips unknown statuses (NA), e.g., on temporary rows added
    # for missed occasions.
    no_partner <- data[[partner_columns$status_column[[i]]]] %in% FALSE
    no_partner_value <- if (partner_columns$is_numeric[[i]]) 0 else NA

    data[[column]] <- dplyr::if_else(no_partner, no_partner_value, data[[column]])
  }

  report_two_part_coding(data, partner_columns)
  return(data)
}


#' Add each dyad's partner status at the previous occasion
#'
#' Both members agree on the status when both have a row (checked during
#' validation), so the dyad has one status per occasion. The status at the
#' previous occasion is `NA` when neither member has a row then. Without
#' `lag1_predictors`, it is not needed, so the column is all `NA`.
#'
#' @param data A `dyadMLM_data` object with the temporary partner status column.
#'
#' @return `data` with the temporary column `.dy_partner_exists_lag1`.
#' @keywords internal
add_previous_partner_status <- function(data) {
  meta_data <- attr(data, "dyadMLM")
  if (length(meta_data$lag1_predictors) == 0L) {
    data[[dyad_partner_exists_lag1_col]] <- NA
    return(data)
  }

  dyad <- meta_data$dyad
  time <- meta_data$time

  # One row per dyad and occasion, shifted by one occasion so it joins to the
  # following occasion. The `.dy_` name cannot clash with input columns.
  status_at_previous_occasion <- data |>
    dplyr::filter(!is.na(.data[[dyad_partner_exists_col]])) |>
    dplyr::distinct(
      .data[[dyad]],
      .data[[time]],
      .dy_previous_status = .data[[dyad_partner_exists_col]]
    ) |>
    dplyr::mutate("{time}" := .data[[time]] + 1)

  data[[dyad_partner_exists_lag1_col]] <- tibble::tibble(
    "{dyad}" := data[[dyad]],
    "{time}" := data[[time]]
  ) |>
    dplyr::left_join(status_at_previous_occasion, by = c(dyad, time)) |>
    dplyr::pull(".dy_previous_status")

  return(data)
}


#' Add the partner status columns `.partner_exists` and `.partner_exists_lag1`
#'
#' Public 0/1 copies of the temporary status columns, for use in the model.
#' `.partner_exists` is only added when the status varies. A constant column
#' would duplicate the intercept. `.partner_exists_lag1` is added next to it
#' when lagged predictors were requested.
#'
#' @param data A `dyadMLM_data` object with both temporary status columns.
#'
#' @return `data` with the partner status columns, if any.
#' @keywords internal
add_partner_status_columns <- function(data) {
  meta_data <- attr(data, "dyadMLM")
  status <- data[[dyad_partner_exists_col]]
  if (dplyr::n_distinct(status, na.rm = TRUE) < 2L) {
    return(data)
  }

  status_columns <- tibble::tibble(
    target = paste0(dyad_retained_prefix, "partner_exists"),
    source_column = dyad_partner_exists_col,
    lag = 0L
  )
  if (length(meta_data$lag1_predictors) > 0L) {
    status_columns <- tibble::add_row(
      status_columns,
      target = paste0(dyad_retained_prefix, "partner_exists_lag1"),
      source_column = dyad_partner_exists_lag1_col,
      lag = 1L
    )
  }

  column_plan <- status_columns |>
    dplyr::mutate(
      predictor = NA_character_,
      temporal_component = "none",
      model_family = "apim",
      column_role = "partner_status",
      variable_role = "partner_status"
    )
  validate_generated_column_plan(data, column_plan)

  # Two-part coding, part 1: the status dummy. TRUE/FALSE becomes 1/0.
  for (i in seq_len(nrow(column_plan))) {
    data[[column_plan$target[[i]]]] <- as.numeric(data[[column_plan$source_column[[i]]]])
  }

  return(record_generated_columns(data, column_plan))
}


# Tells users once that values were set to 0, which status columns belong in
# the model, and which non-numeric partner predictors became NA instead.
report_two_part_coding <- function(data, partner_columns) {
  affected <- dplyr::filter(partner_columns, .data$has_no_partner_rows)

  set_to_zero <- dplyr::filter(affected, .data$is_numeric)
  if (nrow(set_to_zero) > 0L) {
    # Name only the status columns that were added.
    status_terms <- ""
    if (".partner_exists" %in% names(data)) {
      status_terms <- " You must include `.partner_exists` as a fixed effect in the model"
      # The lagged status is only named if a lagged partner predictor was set to 0.
      if (".partner_exists_lag1" %in% names(data) && any(set_to_zero$is_lagged)) {
        status_terms <- paste0(
          status_terms,
          " (and `.partner_exists_lag1` for lagged partner predictors)"
        )
      }
      status_terms <- paste0(
        status_terms, ". Together with the zeros, this is two-part coding ",
        "(see `vignette(\"mixed-apim\")`). Without it, the zeros are treated as ",
        "real partner values and bias the partner effects. Random effects ",
        "cannot replace `.partner_exists`."
      )
    }

    message(
      "Partner predictors were set to 0 where no partner existed.", status_terms
    )
  }

  set_to_missing <- dplyr::filter(affected, !.data$is_numeric)
  if (nrow(set_to_missing) > 0L) {
    warning(
      "Non-numeric partner predictor(s) cannot be set to 0 where no partner ",
      "existed, so they are missing (NA) there: ",
      paste0("`", unique(set_to_missing$predictor), "`", collapse = ", "),
      ". Recode them as numeric (e.g., dummy variables) to use two-part coding.",
      call. = FALSE
    )
  }

  return(invisible(NULL))
}
