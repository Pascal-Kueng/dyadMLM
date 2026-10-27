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


# Tells users once that values were set to 0 and which terms belong in the
# model.
report_two_part_coding <- function(data) {
  meta_data <- attr(data, "dyadMLM")
  zeroed_columns <- meta_data$zeroed_partner_columns
  if (is.null(zeroed_columns) || nrow(zeroed_columns) == 0L) {
    return(invisible(NULL))
  }

  # Wraps a paragraph to the console width. Term lines are not wrapped, so
  # they can be pasted into a formula.
  wrap <- function(paragraph) {
    lines <- strwrap(paragraph, width = getOption("width", 80L))
    return(paste(lines, collapse = "\n"))
  }

  # The advice explains the zeros only when it suggests partner terms.
  advice <- model_term_advice(meta_data, data)
  paragraphs <- character()
  if (is.null(advice) || !advice$has_partner_terms) {
    paragraphs <- wrap("Partner predictors were set to 0 where no partner existed.")
  }
  if (!is.null(advice)) {
    for (paragraph in advice$before) {
      paragraphs <- c(paragraphs, wrap(paragraph))
    }
    if (length(advice$terms) > 0L) {
      paragraphs <- c(paragraphs, paste0("  ", advice$terms, collapse = "\n"))
    }
    paragraphs <- c(paragraphs, wrap(advice$after))
  }

  # One message, with a blank line between paragraphs.
  message(paste(paragraphs, collapse = "\n\n"))
  return(invisible(NULL))
}


# Advice on the terms a model of these data needs, for the message and
# print(): the partner terms of two-part coding and the indicators of people
# observed alone (fixed intercepts and variance terms). Returns `NULL` if there
# is nothing to advise. Otherwise, returns the paragraphs `before` the
# suggested `terms` (lines to paste into a formula), a paragraph `after` them,
# and whether partner terms are suggested.
model_term_advice <- function(meta, data) {
  # 1. Partner terms of two-part coding, if partner predictors were set to 0.
  partner_terms <- two_part_terms(meta, data)

  # 2. Indicators of people observed alone. Their rows are 0 in the
  #    indicators of dyad members, so they only need their own next to dyads.
  indicators <- composition_indicators(meta, data) |>
    dplyr::mutate(is_alone = .data$dyad_type %in% dyad_alone_types)
  dyad_indicators <- indicators$column[!indicators$is_alone]
  alone <- dplyr::filter(indicators, .data$is_alone, length(dyad_indicators) > 0L)
  if (nrow(alone) == 0L && is.null(partner_terms)) {
    return(NULL)
  }

  # 3. Rows whose partner is not in the data drop out of models with partner
  #    predictors (their partner values are missing). Their terms are listed
  #    only if no partner terms are suggested.
  has_partner_predictors <- dyad_generated_columns(meta) |>
    dplyr::filter(.data$column_role == "partner", .data$column %in% names(data)) |>
    nrow() > 0L
  missing_partner <- dplyr::filter(alone, .data$dyad_type == "missing_partner")
  listed <- alone
  if (!is.null(partner_terms)) {
    listed <- dplyr::filter(alone, .data$dyad_type != "missing_partner")
  }

  # 4. Variance terms of people observed alone: per dyad and, in longitudinal
  #    data, per occasion, as the residual terms of dyad members.
  groups <- meta$dyad
  if (isTRUE(meta$longitudinal)) {
    groups <- c(groups, paste0(meta$dyad, ":", meta$time))
  }
  variance_terms <- function(columns) {
    paste0("(0 + ", rep(columns, each = length(groups)), " | ", groups, ")")
  }

  # 5. The suggested terms: fixed intercepts of all listed groups (needed for
  #    people observed alone, or in place of `.partner_exists`), partner terms,
  #    then variance terms of the listed people observed alone.
  terms <- character()
  replaces_status <- !is.null(partner_terms) && !".partner_exists" %in% partner_terms$term
  if (nrow(listed) > 0L || replaces_status) {
    terms <- paste("0 +", paste(c(dyad_indicators, listed$column), collapse = " + "))
  }
  if (!is.null(partner_terms)) {
    terms <- c(terms, format_two_part_terms(partner_terms, prefix = ""))
  }
  if (nrow(listed) > 0L) {
    terms <- c(terms, paste("+", variance_terms(listed$column)))
  }

  # 6. Why these terms are needed, before the terms.
  before <- character()
  if (!is.null(partner_terms)) {
    before <- c(before, paste(
      "Partner predictors are 0 where no partner existed. The zeros \"turn",
      "off\" the predictors where they do not apply, when the fixed part gives",
      "these rows their own mean, through composition indicators or",
      "`.partner_exists` (two-part coding). Otherwise, the zeros are treated as",
      "real partner values, which can bias the partner effects."
    ))
  }
  if (nrow(alone) > 0L) {
    before <- c(before, paste(
      "Rows of people observed alone are 0 in the indicators of dyad members.",
      "Without their own indicators in the fixed part and in the variance",
      "terms, they get no intercept and, with `dispformula = ~ 0`, almost no",
      "residual variance."
    ))
  }
  if (length(terms) > 0L) {
    lead <- "Suggested fixed-effect terms"
    if (nrow(listed) > 0L) {
      lead <- "Suggested terms, next to the variance terms of dyad members"
    }
    before <- c(before, paste(
      lead, "(starting point, please revise and check that this is what you need):"
    ))
  }

  # 7. How to handle people whose partner is not in the data and how to pool,
  #    after the terms.
  after <- character()
  if (nrow(missing_partner) > 0L && has_partner_predictors) {
    after <- c(after, paste0(
      "Rows of ", paste(missing_partner$composition, collapse = " and "),
      " drop out of models with partner predictors, because their partner values are missing. ",
      if (!is.null(partner_terms)) {
        paste0(
          "In models without partner predictors, add `",
          paste(missing_partner$column, collapse = "`, `"), "` in the same way."
        )
      } else {
        "Leave out their terms there."
      }
    ))
  }
  if (nrow(alone) > 0L) {
    # Pool the first group with dyad members of the same role, if any, and
    # preferably of a distinguishable composition, whose variance term needs
    # no member contrast.
    example <- dplyr::bind_rows(listed, missing_partner)[1L, ]
    dyad <- indicators |>
      dplyr::filter(!.data$is_alone) |>
      dplyr::arrange(!.data$role %in% example$role, .data$dyad_type != "distinguishable") |>
      dplyr::slice(1L)
    after <- c(after, paste0(
      "To pool a group with dyad members, sum their indicators inside I(), ",
      "for example `I(", dyad$column, " + ", example$column, ")`."
    ))

    # To pool the variance of an exchangeable composition, the group also goes
    # into the composition's member contrast, the contrast column that is not
    # 0 on its rows.
    if (dyad$dyad_type == "exchangeable") {
      contrasts <- dyad_generated_columns(meta) |>
        dplyr::filter(.data$column_role == "member_contrast", .data$column %in% names(data)) |>
        dplyr::pull("column")
      in_dyad <- data[[dyad$column]] == 1
      for (contrast in contrasts) {
        if (any(data[[contrast]][in_dyad] != 0)) {
          after <- c(after, paste0(
            "To pool the variance, also use `I(", contrast, " + ", example$column,
            ")` in the member-contrast term."
          ))
        }
      }
    }

    # A pooled intercept of people without a partner undoes two-part coding.
    # With `.partner_exists` added, pooling one group gives back the separate
    # model.
    if (!is.null(partner_terms) && example$dyad_type == "singleton") {
      after <- c(after, "With two-part coding, keep the intercepts of people without a partner separate.")
    }
  }
  after <- c(after, "See `vignette(\"partner-exists\")`.")

  return(list(
    before = before,
    terms = terms,
    after = paste(after, collapse = " "),
    has_partner_terms = !is.null(partner_terms)
  ))
}


# The composition indicators still in the data, with the composition, dyad
# type, and role of the first row each one marks. Indicators that mark no row
# (e.g., after filtering) are left out.
composition_indicators <- function(meta, data) {
  indicators <- dyad_generated_columns(meta) |>
    dplyr::filter(
      .data$column_role == "composition_indicator",
      .data$column %in% names(data)
    ) |>
    dplyr::select("column")
  if (!dyad_composition_col %in% names(data)) {
    return(tibble::tibble(
      column = character(), composition = character(), role = character(), dyad_type = character()
    ))
  }

  # 1. The first row each indicator marks.
  indicators$row <- NA_integer_
  for (i in seq_len(nrow(indicators))) {
    indicators$row[[i]] <- match(1, data[[indicators$column[[i]]]])
  }

  # 2. That row's composition and role, and the composition's dyad type.
  roles <- rep(NA_character_, nrow(data))
  if (isTRUE(meta$role %in% names(data))) {
    roles <- as.character(data[[meta$role]])
  }
  indicators <- indicators |>
    dplyr::filter(!is.na(.data$row)) |>
    dplyr::mutate(
      composition = as.character(data[[dyad_composition_col]][.data$row]),
      role = roles[.data$row]
    ) |>
    dplyr::left_join(
      dplyr::select(meta$dyad_compositions, "composition", "dyad_type"),
      by = "composition"
    )
  return(dplyr::select(indicators, -"row"))
}


# The terms two-part coding needs in the model, among the columns still in the
# data: the status column (if composition indicators do not separate the
# statuses) and the partner predictors. Returns a tibble with one row per term
# and a short description, or `NULL` without partner predictors set to 0,
# without a status column that varies, or without partner predictors left.
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

  # Composition indicators already separate rows with and without a partner,
  # unless a composition has both (e.g., former partners who both take part).
  # Only then is `.partner_exists` needed next to them.
  needs_status <- TRUE
  if (dyad_composition_col %in% names(data)) {
    statuses <- tibble::tibble(
      composition = data[[dyad_composition_col]],
      status = data[[".partner_exists"]]
    ) |>
      dplyr::summarise(
        n_statuses = dplyr::n_distinct(.data$status, na.rm = TRUE),
        .by = "composition"
      )
    needs_status <- any(statuses$n_statuses > 1L)
  }

  # The status term first, if needed, then the partner terms.
  terms <- dplyr::select(partner_terms, term = "column", "comment")
  if (needs_status) {
    terms <- dplyr::bind_rows(
      tibble::tibble(term = ".partner_exists", comment = "a partner exists (1) or not (0)"),
      terms
    )
  }
  return(terms)
}


# One line per term, ready to paste into a formula, with aligned comments:
# "+ .partner_exists  # a partner exists (1) or not (0)".
format_two_part_terms <- function(terms, prefix) {
  padded_terms <- format(terms$term, width = max(nchar(terms$term)))
  return(paste0(prefix, "+ ", padded_terms, "  # ", terms$comment))
}
