#' Add lagged temporal predictor columns
#'
#' Adds lag-1 raw and within-person columns for predictors selected through
#' `lag_predictors`. Values are matched at exactly `time - 1`, so construction
#' does not depend on row order and does not bridge gaps in the measurement
#' index. Stable between-person components are not lagged.
#'
#' @param data An `interdep_data` object returned by [prepare_interdep_data()].
#'
#' @return An `interdep_data` object with lagged temporal predictor columns and
#'   updated predictor metadata.
#'
#' @keywords internal
add_temporal_lag_columns <- function(data) {
  if (!inherits(data, "interdep_data")) {
    stop("`data` must be an `interdep_data` object.", call. = FALSE)
  }

  meta_data <- attr(data, "interdep")
  lag_predictors <- meta_data$lag_predictors

  if (length(lag_predictors) == 0) {
    return(data)
  }

  group <- meta_data$group
  member <- meta_data$member
  time <- meta_data$time
  decompositions <- meta_data$temporal_predictor_decompositions
  lag_sources <- decompositions |>
    dplyr::filter(
      .data$predictor %in% lag_predictors,
      .data$component %in% c("raw", "cwp"),
      .data$lag == 0L
    )

  out <- data |>
    dplyr::mutate(.i_lag_row_order = dplyr::row_number()) |>
    dplyr::group_by(.data[[group]], .data[[member]]) |>
    dplyr::arrange(.data[[time]], .by_group = TRUE) |>
    dplyr::mutate(
      .i_lag_is_consecutive = .data[[time]] == dplyr::lag(.data[[time]]) + 1
    )

  for (i in seq_len(nrow(lag_sources))) {
    predictor <- lag_sources$predictor[[i]]
    component <- lag_sources$component[[i]]
    source_col <- lag_sources$column[[i]]

    lag_col <- paste0(source_col, "_lag1")
    if (component == "raw") {
      predictor_suffix <- make_interdep_suffixes(predictor)[[predictor]]
      lag_col <- paste0(interdep_reserved_prefix, predictor_suffix, "_lag1")
    }

    out <- out |>
      dplyr::mutate(
        "{lag_col}" := dplyr::if_else(
          .data$.i_lag_is_consecutive,
          dplyr::lag(.data[[source_col]]),
          NA
        )
      )

    decompositions <- tibble::add_row(
      decompositions,
      predictor = predictor,
      component = component,
      column = lag_col,
      temporal_predictor_decomposition = lag_sources$temporal_predictor_decomposition[[i]],
      lag = 1L
    )
  }

  out <- out |>
    dplyr::ungroup() |>
    dplyr::arrange(.data$.i_lag_row_order) |>
    dplyr::select(-dplyr::all_of(c(
      ".i_lag_row_order",
      ".i_lag_is_consecutive"
    )))

  meta_data$temporal_predictor_decompositions <- decompositions
  attr(out, "interdep") <- meta_data
  class(out) <- class(data)
  out
}

make_predictor_lag_suffix <- function(lag) {
  if (lag == 0L) {
    return("")
  }

  paste0("_lag", lag)
}
