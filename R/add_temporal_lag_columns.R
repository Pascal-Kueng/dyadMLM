#' Add lagged temporal predictor columns
#'
#' Adds lag-1 raw and within-person columns for predictors selected through
#' `lag1_predictors`. Values are matched at exactly `time - 1`, so construction
#' does not depend on row order and does not bridge gaps in the measurement
#' index. Stable between-person components are not lagged.
#'
#' @param data A `dyadMLM_data` object returned by [prepare_dyad_data()].
#'
#' @return A `dyadMLM_data` object with lagged temporal predictor columns and
#'   updated predictor metadata.
#'
#' @keywords internal
add_temporal_lag_columns <- function(data) {
  if (!inherits(data, "dyadMLM_data")) {
    stop(
      "`data` must be a `dyadMLM_data` object returned by `prepare_dyad_data()`.",
      call. = FALSE
    )
  }

  meta_data <- attr(data, "dyadMLM")
  lag1_predictors <- meta_data$lag1_predictors

  if (length(lag1_predictors) == 0) {
    return(data)
  }

  dyad <- meta_data$dyad
  member <- meta_data$member
  time <- meta_data$time
  decompositions <- meta_data$temporal_decompositions
  lag_sources <- decompositions |>
    dplyr::filter(
      .data$predictor %in% lag1_predictors,
      .data$component %in% c("raw", "cwp"),
      .data$lag == 0L
    )

  lag_columns <- character(nrow(lag_sources))
  for (i in seq_len(nrow(lag_sources))) {
    predictor <- lag_sources$predictor[[i]]
    component <- lag_sources$component[[i]]
    source_col <- lag_sources$column[[i]]
    lag_col <- paste0(source_col, "_lag1")
    if (component == "raw") {
      predictor_suffix <- make_dyad_suffixes(predictor)[[predictor]]
      lag_col <- paste0(dyad_reserved_prefix, predictor_suffix, "_lag1")
    }
    lag_columns[[i]] <- lag_col
  }
  lag_plan <- tibble::tibble(
    target = lag_columns,
    predictor = lag_sources$predictor,
    temporal_component = lag_sources$component,
    lag = 1L,
    model_family = "temporal",
    column_role = "temporal_component"
  )
  validate_generated_column_plan(data, lag_plan)

  out <- data |>
    dplyr::mutate(.dy_lag_row_order = dplyr::row_number()) |>
    dplyr::group_by(.data[[dyad]], .data[[member]]) |>
    dplyr::arrange(.data[[time]], .by_group = TRUE) |>
    dplyr::mutate(
      .dy_lag_is_consecutive = .data[[time]] == dplyr::lag(.data[[time]]) + 1
    )

  for (i in seq_len(nrow(lag_sources))) {
    predictor <- lag_sources$predictor[[i]]
    component <- lag_sources$component[[i]]
    source_col <- lag_sources$column[[i]]

    lag_col <- lag_columns[[i]]

    out <- out |>
      dplyr::mutate(
        "{lag_col}" := dplyr::if_else(
          .data$.dy_lag_is_consecutive,
          dplyr::lag(.data[[source_col]]),
          NA
        )
      )

    decompositions <- tibble::add_row(
      decompositions,
      predictor = predictor,
      component = component,
      column = lag_col,
      temporal_decomposition = lag_sources$temporal_decomposition[[i]],
      lag = 1L
    )
  }

  out <- out |>
    dplyr::ungroup() |>
    dplyr::arrange(.data$.dy_lag_row_order) |>
    dplyr::select(-dplyr::all_of(c(
      ".dy_lag_row_order",
      ".dy_lag_is_consecutive"
    )))

  meta_data$temporal_decompositions <- decompositions
  attr(out, "dyadMLM") <- meta_data
  class(out) <- class(data)
  out
}

make_predictor_lag_suffix <- function(lag) {
  if (lag == 0L) {
    return("")
  }

  paste0("_lag", lag)
}
