#' Apply two-part coding to partner predictors
#'
#' Where no partner existed, there is no partner value. Numeric partner
#' predictors are set to 0 there (two-part coding), and the partner status
#' columns `.partner_exists` and `.partner_exists_lag1` let the model give these
#' rows their own mean. Contemporaneous partner predictors follow the status at
#' the same occasion, and lagged partner predictors follow the status at the
#' previous occasion. Centering happens before this step, so 0 is the centered
#' reference. Non-numeric partner predictors cannot be set to 0, so they stop
#' with an error.
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
  # the status at the previous occasion, then public 0/1 copies of both, then
  # the columns needed when the status changes over time.
  data <- add_previous_partner_status(data)
  data <- add_partner_status_columns(data)
  data <- add_status_change_columns(data)

  # Rows without a partner, at this occasion and at the previous one.
  # `%in% FALSE` skips unknown statuses (NA), e.g., on temporary rows added for
  # missed occasions.
  no_partner <- data[[dyad_partner_exists_col]] %in% FALSE
  no_partner_lag1 <- data[[dyad_partner_exists_lag1_col]] %in% FALSE

  # One row per partner column. Lagged partner columns follow the status at the
  # previous occasion, the others the current status. The metadata is read
  # again, because add_status_change_columns() may have renamed partner
  # columns.
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
  meta_data$zeroed_partner_columns <- columns_to_zero |>
    dplyr::select("column", "is_lagged")
  attr(data, "dyadMLM") <- meta_data

  report_two_part_coding(data)
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


#' Add the partner status columns `.partner_exists` and `.partner_exists_lag1`
#'
#' Public 0/1 copies of the temporary status columns, for use in the model.
#' `.partner_exists` is only added when the status varies. A constant column
#' would duplicate the intercept. `.partner_exists_lag1` is added next to it
#' when lagged predictors were requested and the status at the previous
#' occasion differs from the current one somewhere. Otherwise it would equal
#' `.partner_exists` wherever it is known.
#'
#' @param data A `dyadMLM_data` object with both temporary status columns.
#'
#' @return `data` with the partner status columns, if any.
#' @keywords internal
add_partner_status_columns <- function(data) {
  meta_data <- attr(data, "dyadMLM")
  status <- data[[dyad_partner_exists_col]]
  previous_status <- data[[dyad_partner_exists_lag1_col]]

  # A constant status would duplicate the intercept.
  if (dplyr::n_distinct(status, na.rm = TRUE) < 2L) {
    return(data)
  }

  # The status at the previous occasion is only added for lagged predictors,
  # and only if it differs from the current status somewhere.
  has_lagged_predictors <- length(meta_data$lag1_predictors) > 0L
  previous_status_differs <- any(status != previous_status, na.rm = TRUE)
  adds_previous_status <- has_lagged_predictors && previous_status_differs

  # One row per status column, and whether it is added.
  column_plan <- tibble::tribble(
    ~target,                ~source_column,               ~lag, ~is_added,
    ".partner_exists",      dyad_partner_exists_col,      0L,   TRUE,
    ".partner_exists_lag1", dyad_partner_exists_lag1_col, 1L,   adds_previous_status
  ) |>
    dplyr::filter(.data$is_added) |>
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
    status_values <- data[[column_plan$source_column[[i]]]]
    data[[column_plan$target[[i]]]] <- as.numeric(status_values)
  }

  return(record_generated_columns(data, column_plan))
}


# Adds the columns needed when the partner status changes over time within a
# dyad: the within- and between-person parts of the status (if predictors are
# split that way), and the columns that separate the occasions before and
# after a relationship.
add_status_change_columns <- function(data) {
  meta_data <- attr(data, "dyadMLM")
  if (!isTRUE(meta_data$longitudinal)) {
    return(data)
  }

  # Nothing to add if no dyad has both statuses. A dyad counts even if each
  # member was only observed with one status.
  statuses_per_dyad <- tibble::tibble(
    dyad = data[[meta_data$dyad]],
    status = data[[dyad_partner_exists_col]]
  ) |>
    dplyr::summarise(
      n_statuses = dplyr::n_distinct(.data$status, na.rm = TRUE),
      .by = "dyad"
    )
  if (!any(statuses_per_dyad$n_statuses > 1L)) {
    return(data)
  }

  split_predictors <- identical(meta_data$temporal_decomposition, "2l")
  if (split_predictors) {
    data <- add_partner_status_parts(data)
  }

  # "Before" and "after" need the order of occasions.
  if (!is.numeric(data[[meta_data$time]])) {
    warning(
      "`partner_exists` changes over time, but `time` is not numeric, so ",
      "dyadMLM cannot tell which occasions come before or after a ",
      "relationship. Columns that depend on this (`.partner_before_exists` ",
      "and the split partner usual levels) are not created. Use a numeric ",
      "`time` to create them.",
      call. = FALSE
    )
    return(data)
  }

  history <- partner_status_history(data)
  data <- add_partner_before_status(data, history)
  if (split_predictors) {
    data <- split_partner_usual_levels(data, history)
  }

  return(data)
}


# Tells users once that values were set to 0 and which status columns belong
# in the model.
report_two_part_coding <- function(data) {
  meta_data <- attr(data, "dyadMLM")
  if (nrow(meta_data$zeroed_partner_columns) == 0L) {
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

  # Why the partner's usual level is split, if it is.
  if (any(terms$is_split)) {
    paragraphs <- c(paragraphs, wrap(
      "The partner's usual level (`cbp`) is split by partner status, ",
      "because it can also relate to a person's outcome before a ",
      "relationship begins or after it ends (for example, through ",
      "selection, shared circumstances, or a lasting influence of the ",
      "partner)."
    ))
  }

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
# data: the status columns and, when split, the partner usual levels. Returns
# a tibble with one row per term and a short description, or `NULL` without
# partner predictors set to 0 or without status columns left.
two_part_terms <- function(meta, data) {
  zeroed_columns <- meta$zeroed_partner_columns
  if (is.null(zeroed_columns)) {
    return(NULL)
  }

  # Only columns that vary in the data can be suggested. A constant column
  # (e.g., `.partner_exists` after filtering to rows with a partner) would be
  # dropped by the model.
  varies <- vapply(
    data,
    function(column) dplyr::n_distinct(column, na.rm = TRUE) > 1L,
    logical(1L)
  )
  column_names <- names(data)[varies]

  generated <- dyad_generated_columns(meta) |>
    dplyr::filter(.data$column %in% column_names)
  status_columns <- generated |>
    dplyr::filter(
      .data$column_role %in% c("partner_status", "partner_before_status")
    ) |>
    dplyr::pull("column")

  # The current status is both status parts when they exist, otherwise the raw
  # status (never one part alone). The indicator for the occasions before a
  # relationship goes with it. The lagged status needs a lagged partner
  # predictor set to 0.
  status_parts <- c(".partner_exists_cwp", ".partner_exists_cbp")
  has_status_parts <- all(status_parts %in% status_columns)
  has_current_status <- has_status_parts ||
    ".partner_exists" %in% status_columns
  has_lagged_zeros <- zeroed_columns |>
    dplyr::filter(.data$column %in% column_names) |>
    dplyr::pull("is_lagged") |>
    any()

  # One row per status term, and whether it is suggested.
  status_terms <- tibble::tribble(
    ~term,                    ~is_suggested,      ~comment,
    ".partner_exists",        !has_status_parts,  "a partner exists (1) or not (0)",
    ".partner_exists_cwp",    has_status_parts,   "losing or gaining a partner (within person)",
    ".partner_exists_cbp",    has_status_parts,   "share of occasions with a partner (between persons)",
    ".partner_exists_lag1",   has_lagged_zeros,   "a partner existed at the previous occasion",
    ".partner_before_exists", has_current_status, "no partner yet, but one later (before the relationship)"
  ) |>
    dplyr::filter(.data$is_suggested, .data$term %in% status_columns) |>
    dplyr::select("term", "comment")

  # One row per kind of partner term, with its comment. Per predictor, the
  # terms are listed in the order of these rows: momentary part, its lag, then
  # the usual level (split by partner status, if it is). Only momentary parts
  # (raw, gmc, cwp) are lagged.
  partner_term_kinds <- tibble::tribble(
    ~column_role,            ~component, ~lag, ~comment,
    "partner",               "raw",      0L,   "partner's value",
    "partner",               "raw",      1L,   "partner's value, previous occasion",
    "partner",               "gmc",      0L,   "partner's value (grand-mean centered)",
    "partner",               "gmc",      1L,   "partner's value (grand-mean centered), previous occasion",
    "partner",               "cwp",      0L,   "partner's deviation from their usual level",
    "partner",               "cwp",      1L,   "partner's deviation from their usual level, previous occasion",
    "partner",               "cbp",      0L,   "partner's usual level",
    "partner_when_exists",   "cbp",      0L,   "partner's usual level, while a partner exists",
    "partner_before_exists", "cbp",      0L,   "future partner's usual level, before the relationship",
    "partner_after_exists",  "cbp",      0L,   "former partner's usual level, after a loss"
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
    dplyr::arrange(.data$variable, .data$order) |>
    dplyr::mutate(is_split = .data$column_role != "partner")

  # Without the current status, only lagged terms (which follow the lagged
  # status) can be suggested.
  if (!has_current_status) {
    partner_terms <- dplyr::filter(partner_terms, .data$lag > 0L)
  }

  # Split usual levels are also 0 for people without a partner at any
  # occasion, so these people need their own intercept.
  before_after_roles <- c("partner_before_exists", "partner_after_exists")
  if (any(partner_terms$column_role %in% before_after_roles)) {
    singleton_compositions <- meta$dyad_compositions |>
      dplyr::filter(.data$dyad_type == "singleton") |>
      dplyr::pull("composition")
    singleton_suffixes <- unname(make_dyad_suffixes(singleton_compositions))
    singleton_terms <- tibble::tibble(
      term = paste0(dyad_retained_prefix, "is_", singleton_suffixes),
      comment = "no partner at any occasion (own intercept)"
    ) |>
      dplyr::filter(.data$term %in% column_names)
    status_terms <- dplyr::bind_rows(status_terms, singleton_terms)
  }

  # Nothing to suggest without a status term or a partner predictor left.
  if (nrow(status_terms) == 0L || nrow(partner_terms) == 0L) {
    return(NULL)
  }

  # The status terms first, then the partner terms.
  terms <- dplyr::bind_rows(
    dplyr::mutate(status_terms, is_split = FALSE),
    dplyr::select(partner_terms, term = "column", "comment", "is_split")
  )
  return(terms)
}


# One line per term, ready to paste into a formula, with aligned comments:
# "+ .partner_exists_cwp   # losing or gaining a partner (within person)".
format_two_part_terms <- function(terms, prefix) {
  padded_terms <- format(terms$term, width = max(nchar(terms$term)))
  return(paste0(prefix, "+ ", padded_terms, "  # ", terms$comment))
}


#' Add the indicator for occasions before a relationship
#'
#' Occasions without a partner before a relationship and after a loss can
#' differ in their mean (e.g., being single versus being widowed). When both
#' occur, `.partner_before_exists` (1 where no partner exists yet, but one does
#' later) gives the occasions before a relationship their own intercept.
#'
#' @param data A `dyadMLM_data` object with the temporary partner status column.
#' @param history The partner status history per row, from
#'   `partner_status_history()`.
#'
#' @return `data` with `.partner_before_exists`, if both states occur.
#' @keywords internal
add_partner_before_status <- function(data, history) {
  # Only needed when occasions before a relationship and after a loss both
  # occur.
  if (!all(c("before", "after") %in% history)) {
    return(data)
  }

  column_plan <- tibble::tibble(
    target = ".partner_before_exists",
    predictor = NA_character_,
    temporal_component = "none",
    lag = 0L,
    model_family = "apim",
    column_role = "partner_before_status",
    variable_role = "partner_status",
    source_column = dyad_partner_exists_col
  )
  validate_generated_column_plan(data, column_plan)

  # 1 before a relationship, 0 otherwise, NA on rows without a status.
  data[[column_plan$target]] <- as.numeric(history == "before")
  return(record_generated_columns(data, column_plan))
}


#' Add the within- and between-person parts of the partner status
#'
#' `.partner_exists_cwp` is the status minus the person's share of observed
#' occasions with a partner. `.partner_exists_cbp` is that share, centered on
#' the mean of all persons' shares, like other `cbp` columns. Together they
#' replace `.partner_exists` and separate losing or gaining a partner from
#' having a partner more often.
#'
#' @param data A `dyadMLM_data` object with the temporary partner status column.
#'
#' @return `data` with `.partner_exists_cwp` and `.partner_exists_cbp`.
#' @keywords internal
add_partner_status_parts <- function(data) {
  meta_data <- attr(data, "dyadMLM")
  rows <- tibble::tibble(
    dyad = data[[meta_data$dyad]],
    member = data[[meta_data$member]],
    status = as.numeric(data[[dyad_partner_exists_col]])
  )

  # Each person's share of observed occasions with a partner. Temporary rows
  # for missed occasions have no status (NA) and are left out.
  person_shares <- rows |>
    dplyr::summarise(
      share = no_NaN_mean(.data$status),
      .by = c("dyad", "member")
    )
  mean_share <- mean(person_shares$share, na.rm = TRUE)

  status_parts <- rows |>
    dplyr::left_join(person_shares, by = c("dyad", "member")) |>
    dplyr::mutate(
      cwp = .data$status - .data$share,
      cbp = .data$share - mean_share
    )

  column_plan <- tibble::tibble(
    target = c(".partner_exists_cwp", ".partner_exists_cbp"),
    predictor = NA_character_,
    temporal_component = c("cwp", "cbp"),
    lag = 0L,
    model_family = "apim",
    column_role = "partner_status",
    variable_role = "partner_status",
    source_column = dyad_partner_exists_col
  )
  validate_generated_column_plan(data, column_plan)

  data[[".partner_exists_cwp"]] <- status_parts$cwp
  data[[".partner_exists_cbp"]] <- status_parts$cbp

  return(record_generated_columns(data, column_plan))
}


#' Split the partner's usual level by partner status
#'
#' After a loss, the partner's usual level (`cbp`) still exists. Setting it to
#' 0 there would assume that it no longer relates to the outcome, and if that
#' is wrong, its slope while a partner exists can be biased too. So each
#' `.{pred}_cbp_partner` column is replaced by one column per state of the
#' dyad's partner status history:
#' * `_when_exists`: a partner exists at this occasion.
#' * `_before_exists`: no partner yet, but one later (only if this occurs).
#' * `_after_exists`: no partner, but one earlier, including gaps in on-off
#'   relationships (only if this occurs).
#'
#' Each column holds the partner's usual level in its state and 0 elsewhere,
#' and `NA` where the state applies but the usual level is unknown. People
#' without a partner at any observed occasion get 0 in all columns.
#'
#' @param data A `dyadMLM_data` object with APIM partner columns and the
#'   temporary partner status column.
#' @param history The partner status history per row, from
#'   `partner_status_history()`.
#'
#' @return `data` with the split columns instead of `.{pred}_cbp_partner`, and
#'   updated metadata.
#' @keywords internal
split_partner_usual_levels <- function(data, history) {
  meta_data <- attr(data, "dyadMLM")
  usual_levels <- meta_data$apim_predictors |>
    dplyr::filter(.data$component == "cbp", .data$lag == 0L)
  if (nrow(usual_levels) == 0L) {
    return(data)
  }

  # One row per state of the history. Only the states that occur get a column.
  states <- tibble::tribble(
    ~state,   ~suffix,
    "exists", "_when_exists",
    "before", "_before_exists",
    "after",  "_after_exists"
  ) |>
    dplyr::filter(.data$state %in% history)

  # One row per new column: each usual level in each state.
  column_plan <- usual_levels |>
    dplyr::select("predictor", "partner_column", "source_column") |>
    dplyr::cross_join(states) |>
    dplyr::mutate(
      target = paste0(.data$partner_column, .data$suffix),
      temporal_component = "cbp",
      lag = 0L,
      model_family = "apim",
      column_role = paste0("partner", .data$suffix),
      variable_role = "predictor"
    )
  validate_generated_column_plan(data, column_plan)

  # The usual level in its state (NA stays NA), 0 elsewhere. Replacing values
  # keeps the column's class (e.g., integer64).
  for (i in seq_len(nrow(column_plan))) {
    usual_level <- data[[column_plan$partner_column[[i]]]]
    is_other_state <- !(history %in% column_plan$state[[i]])
    usual_level[is_other_state] <- 0L
    data[[column_plan$target[[i]]]] <- usual_level
  }

  # Replace the original columns in the data and the metadata. In
  # `apim_predictors`, the column while a partner exists takes their place.
  data[usual_levels$partner_column] <- NULL
  meta_data$generated_columns <- meta_data$generated_columns |>
    dplyr::filter(!(.data$column %in% usual_levels$partner_column))
  meta_data$apim_predictors <- meta_data$apim_predictors |>
    dplyr::mutate(partner_column = dplyr::if_else(
      .data$partner_column %in% usual_levels$partner_column,
      paste0(.data$partner_column, "_when_exists"),
      .data$partner_column
    ))
  attr(data, "dyadMLM") <- meta_data

  return(record_generated_columns(data, column_plan))
}


# The state of the dyad's partner status history at each row: "exists" (a
# partner exists), "before" (no partner yet, one later), "after" (no partner,
# one earlier), "never" (no partner at any observed occasion of the dyad), or NA
# on temporary rows without a status. Both members share one status per
# occasion. Requires numeric `time`.
partner_status_history <- function(data) {
  meta_data <- attr(data, "dyadMLM")
  rows <- tibble::tibble(
    dyad = data[[meta_data$dyad]],
    time = data[[meta_data$time]],
    status = data[[dyad_partner_exists_col]]
  )

  # First occasion at which each dyad had a partner.
  first_partnered <- rows |>
    dplyr::filter(.data$status %in% TRUE) |>
    dplyr::summarise(first_time = min(.data$time), .by = "dyad")

  history <- rows |>
    dplyr::left_join(first_partnered, by = "dyad") |>
    dplyr::mutate(state = dplyr::case_when(
      is.na(.data$status) ~ NA_character_,
      .data$status ~ "exists",
      is.na(.data$first_time) ~ "never",
      .data$time < .data$first_time ~ "before",
      .default = "after"
    )) |>
    dplyr::pull("state")
  return(history)
}
