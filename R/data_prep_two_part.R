#' Apply two-part coding to partner predictors
#'
#' Where no partner existed, there is no partner value. Numeric partner
#' predictors are set to 0 there (two-part coding), and the partner status
#' column `.partner_exists` lets the model give these rows their own mean.
#' Lagged partner predictors are only set to 0 where the dyad has a row at the
#' previous occasion, so they stay missing at first occasions and after gaps,
#' as in complete dyads. Centering happens before this step, so 0 is the
#' centered reference. Non-numeric partner predictors cannot be set to 0, so
#' they stop with an error.
#'
#' @param data A `dyadMLM_data` object with APIM partner columns and the
#'   temporary partner status column.
#'
#' @return `data` with two-part coded partner columns, the partner status
#'   column, and the temporary status column for the previous occasion.
#' @keywords internal
apply_two_part_coding <- function(data) {
  if (is.null(attr(data, "dyadMLM")$partner_exists)) {
    return(data)
  }

  # The current status (`.dy_partner_exists`) was added during validation. Add
  # the status at the previous occasion, then a public 0/1 copy of the current
  # status.
  data <- add_previous_partner_status(data)
  data <- add_partner_status_column(data)

  # Rows without a partner, at this occasion and at the previous one.
  # `%in% FALSE` skips unknown statuses (NA), e.g., on temporary rows added for
  # missed occasions.
  no_partner <- data[[dyad_partner_exists_col]] %in% FALSE
  no_partner_lag1 <- data[[dyad_partner_exists_lag1_col]] %in% FALSE

  # One row per partner column. Lagged partner columns follow the status at the
  # previous occasion, the others the current status. The metadata is read
  # after the status column was recorded in it.
  meta_data <- attr(data, "dyadMLM")
  partner_columns <- meta_data$apim_predictors |>
    dplyr::select("predictor", column = "partner_column", "lag") |>
    dplyr::mutate(
      is_lagged = .data$lag > 0L,
      is_numeric = vapply(data[.data$column], is.numeric, logical(1L)),
      has_no_partner_rows = dplyr::if_else(
        .data$is_lagged,
        any(no_partner_lag1),
        any(no_partner)
      )
    )

  # Only columns with rows without a partner are set to 0, which needs numeric
  # columns.
  columns_to_zero <- partner_columns |>
    dplyr::filter(.data$has_no_partner_rows)
  non_numeric_predictors <- columns_to_zero |>
    dplyr::filter(!.data$is_numeric) |>
    dplyr::pull("predictor") |>
    unique()
  if (length(non_numeric_predictors) > 0L) {
    stop(
      "Non-numeric partner predictor(s) cannot be set to 0 where no partner ",
      "existed: ", paste0("`", non_numeric_predictors, "`", collapse = ", "),
      ". Recode them as numeric (e.g., dummy variables) to use two-part coding.",
      call. = FALSE
    )
  }

  # Two-part coding, part 2: partner predictors are 0 where no partner existed.
  # Replacing only these values keeps the column's class (e.g., integer64), and
  # an integer 0 keeps integer columns integer.
  for (i in seq_len(nrow(columns_to_zero))) {
    column <- columns_to_zero$column[[i]]
    is_lagged <- columns_to_zero$is_lagged[[i]]
    rows_to_zero <- if (is_lagged) no_partner_lag1 else no_partner
    data[[column]][rows_to_zero] <- 0L
  }

  # Record which partner columns were set to 0, for the message and print().
  # prepare_dyad_data() shows the message once temporary rows are removed, so
  # it describes the returned rows.
  meta_data$zeroed_partner_columns <- columns_to_zero |>
    dplyr::select("column", "is_lagged")
  attr(data, "dyadMLM") <- meta_data

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

  rows <- tibble::tibble(
    dyad = data[[meta_data$dyad]],
    time = data[[meta_data$time]],
    status = data[[dyad_partner_exists_col]]
  )

  # One row per dyad and occasion with a known status, moved one occasion
  # later so it joins to the following occasion.
  previous_statuses <- rows |>
    dplyr::filter(!is.na(.data$status)) |>
    dplyr::select("dyad", "time", previous_status = "status") |>
    dplyr::distinct() |>
    dplyr::mutate(time = .data$time + 1)

  data[[dyad_partner_exists_lag1_col]] <- rows |>
    dplyr::left_join(previous_statuses, by = c("dyad", "time")) |>
    dplyr::pull("previous_status")

  return(data)
}


#' Add the partner status column `.partner_exists`
#'
#' A public 0/1 copy of the temporary status column, for use in the model. It
#' is only added when the status varies. A constant column would duplicate the
#' intercept.
#'
#' @param data A `dyadMLM_data` object with the temporary status column.
#'
#' @return `data` with `.partner_exists`, if the status varies.
#' @keywords internal
add_partner_status_column <- function(data) {
  status <- data[[dyad_partner_exists_col]]

  # A constant status would duplicate the intercept.
  if (dplyr::n_distinct(status, na.rm = TRUE) < 2L) {
    return(data)
  }

  column_plan <- tibble::tibble(
    target = ".partner_exists",
    predictor = NA_character_,
    temporal_component = "none",
    lag = 0L,
    model_family = "apim",
    column_role = "partner_status",
    variable_role = "partner_status",
    source_column = dyad_partner_exists_col
  )
  validate_generated_column_plan(data, column_plan)

  # Two-part coding, part 1: the status dummy. TRUE/FALSE becomes 1/0.
  data[[".partner_exists"]] <- as.numeric(status)
  return(record_generated_columns(data, column_plan))
}


# Tells users once that values were set to 0 and which status columns belong
# in the model.
report_two_part_coding <- function(data) {
  meta_data <- attr(data, "dyadMLM")
  zeroed_columns <- meta_data$zeroed_partner_columns
  if (is.null(zeroed_columns) || nrow(zeroed_columns) == 0L) {
    return(invisible(NULL))
  }

  # Like message(), wrap() pastes its arguments into one paragraph. It then
  # wraps the paragraph to the console width. Term lines are not wrapped, so
  # they can be pasted into a formula.
  wrap <- function(...) {
    lines <- strwrap(paste0(...), width = getOption("width", 80L))
    return(paste(lines, collapse = "\n"))
  }

  # Without status columns (no row has a partner), there is no indicator to
  # include, so one sentence is enough.
  terms <- two_part_terms(meta_data, data)
  if (is.null(terms)) {
    message(wrap("Partner predictors were set to 0 where no partner existed."))
    return(invisible(NULL))
  }

  # Why the zeros need a status indicator in the model.
  paragraphs <- wrap(
    "Partner predictors were set to 0 where no partner existed. The zeros ",
    "\"turn off\" the predictors where they do not apply, when an indicator ",
    "of whether a partner existed is included in the model to give these ",
    "rows their own mean (two-part coding)."
  )

  # The suggested terms, then why the status terms matter.
  paragraphs <- c(
    paragraphs,
    wrap(
      "Suggested fixed-effect terms for the partner part of the model ",
      "(starting point, please revise and check that this is what you ",
      "need):"
    ),
    paste(format_two_part_terms(terms, prefix = "  "), collapse = "\n"),
    wrap(
      "Without the status terms, the zeros are treated as real partner ",
      "values, which can bias the partner effects. They can only be left ",
      "out if fixed intercepts already separate rows with and without a ",
      "partner. Random effects cannot replace them. Leave out terms that ",
      "are constant or duplicate other fixed effects in your model. See ",
      "`vignette(\"partner-exists\")`."
    )
  )

  # One message, with a blank line between paragraphs.
  message(paste(paragraphs, collapse = "\n\n"))
  return(invisible(NULL))
}


# The terms two-part coding needs in the model, among the columns still in the
# data: the status column and the partner predictors. Returns a tibble with one
# row per term and a short description, or `NULL` without partner predictors
# set to 0, without a status column that varies, or without partner predictors
# left.
two_part_terms <- function(meta, data) {
  if (is.null(meta$zeroed_partner_columns)) {
    return(NULL)
  }

  # A term is only suggested if it varies in the data. A constant column
  # (e.g., `.partner_exists` after filtering to rows with a partner) would be
  # dropped by the model.
  varies <- function(column) {
    dplyr::n_distinct(data[[column]], na.rm = TRUE) > 1L
  }

  # Generated columns still in the data.
  generated <- dyad_generated_columns(meta) |>
    dplyr::filter(.data$column %in% names(data))
  has_status <- ".partner_exists" %in% generated$column && varies(".partner_exists")

  # One row per kind of partner term, with its comment. Per predictor, the
  # terms are listed in the order of these rows: momentary part, its lag, then
  # the usual level. Only momentary parts (raw, gmc, cwp) are lagged.
  partner_term_kinds <- tibble::tribble(
    ~column_role, ~component, ~lag, ~comment,
    "partner",    "raw",      0L,   "partner's value",
    "partner",    "raw",      1L,   "partner's value, previous occasion",
    "partner",    "gmc",      0L,   "partner's value (grand-mean centered)",
    "partner",    "gmc",      1L,   "partner's value (grand-mean centered), previous occasion",
    "partner",    "cwp",      0L,   "partner's deviation from their usual level",
    "partner",    "cwp",      1L,   "partner's deviation from their usual level, previous occasion",
    "partner",    "cbp",      0L,   "partner's usual level"
  ) |>
    dplyr::mutate(order = dplyr::row_number())

  # The partner columns still in the data, with their comment and order. Only
  # the kinds listed above can be suggested: the inner join also drops all
  # other columns, such as actor columns.
  partner_columns <- generated |>
    dplyr::filter(.data$model_family == "apim") |>
    dplyr::inner_join(
      partner_term_kinds,
      by = c("column_role", "component", "lag")
    )

  # Partner predictors of one decomposition, so the terms are not collinear:
  # `cwp` and `cbp` when predictors were split into within- and between-person
  # parts, otherwise `gmc` if requested, otherwise raw values, each with its
  # lag where requested.
  if (any(partner_columns$component %in% c("cwp", "cbp"))) {
    components <- c("cwp", "cbp")
  } else if (any(partner_columns$component == "gmc")) {
    components <- "gmc"
  } else {
    components <- "raw"
  }

  partner_terms <- partner_columns |>
    dplyr::filter(.data$component %in% components) |>
    dplyr::filter(vapply(.data$column, varies, logical(1L))) |>
    dplyr::arrange(.data$variable, .data$order)

  # Nothing to suggest without the status or a partner predictor left.
  if (!has_status || nrow(partner_terms) == 0L) {
    return(NULL)
  }

  # The status term first, then the partner terms.
  terms <- dplyr::bind_rows(
    tibble::tibble(term = ".partner_exists", comment = "a partner exists (1) or not (0)"),
    dplyr::select(partner_terms, term = "column", "comment")
  )
  return(terms)
}


# One line per term, ready to paste into a formula, with aligned comments:
# "+ .partner_exists  # a partner exists (1) or not (0)".
format_two_part_terms <- function(terms, prefix) {
  padded_terms <- format(terms$term, width = max(nchar(terms$term)))
  return(paste0(prefix, "+ ", padded_terms, "  # ", terms$comment))
}
