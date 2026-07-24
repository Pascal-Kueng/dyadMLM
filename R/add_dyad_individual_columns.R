#' Add dyad-individual predictor columns
#'
#' Adds Dyad-Individual Model (DIM) style dyad-mean and within-dyad
#' member-deviation columns for the predictors recorded in a `dyadMLM_data`
#' object. For
#' currently supported DIMs, the data must
#' contain one exchangeable dyad composition. This means distinguishable dyads
#' and multiple exchangeable compositions are not supported by DIM
#' construction until explicit role-contrast, composition-specific, or pooling
#' support is added. For
#' intensive longitudinal predictors decomposed by [center_predictors()], raw
#' predictors and within-person components are decomposed within each dyad-time
#' occasion, while between-person components are decomposed once within each
#' dyad.
#' For raw predictors, the dyad-mean column is centered around the grand mean
#' of dyad means, or dyad-occasion means in longitudinal data, while the
#' within-dyad member-deviation column is the person's deviation from the
#' uncentered dyad mean.
#' Selected lag predictors additionally create lag-1 raw and within-person
#' dyad-mean and within-dyad member-deviation columns.
#'
#' The function reads `attr(data, "dyadMLM")$temporal_decompositions` and
#' stores the constructed DIM columns in
#' `attr(data, "dyadMLM")$dim_predictors`.
#'
#' @param data A `dyadMLM_data` object returned by [prepare_dyad_data()].
#'
#' @return A `dyadMLM_data` object with dyad-mean and within-dyad
#'   member-deviation predictor columns added and DIM predictor metadata
#'   recorded.
#'
#' @keywords internal
add_dyad_individual_columns <- function(data) {
  if (!inherits(data, "dyadMLM_data")) {
    stop(
      "`data` must be a `dyadMLM_data` object returned by `prepare_dyad_data()`.",
      call. = FALSE
    )
  }

  validate_dim_compatibility(data)

  decomposition <- construct_dyad_predictor_decompositions(data, "dim")
  out <- decomposition$data
  attr(out, "dyadMLM")$dim_predictors <- decomposition$predictors
  out <- record_generated_columns(out, decomposition$column_plan)

  out
}

construct_dyad_predictor_decompositions <- function(data, model_family = "dim") {
  meta_data <- attr(data, "dyadMLM")
  group <- meta_data$dyad
  member <- meta_data$member
  has_time <- meta_data$longitudinal
  time <- meta_data$time
  temporal_decompositions <- meta_data$temporal_decompositions

  predictors <- tibble::tibble(
    predictor = character(),
    component = character(),
    lag = integer(),
    source_column = character(),
    mean_column = character(),
    deviation_column = character(),
    dyad_decomposition_level = character()
  )

  out <- data

  # First resolve one complete manifest and metadata table. The second loop
  # performs the writes only after the shared collision validator succeeds.
  for (i in seq_len(nrow(temporal_decompositions))) {
    predictor <- temporal_decompositions$predictor[[i]]
    component <- temporal_decompositions$component[[i]]
    lag <- temporal_decompositions$lag[[i]]
    source_col <- temporal_decompositions$column[[i]]

    column_stem <- make_dyad_predictor_column_stem(
      predictor = predictor,
      component = component,
      source_col = source_col,
      lag = lag
    )

    lag_suffix <- make_predictor_lag_suffix(lag)
    mean_col <- paste0(column_stem, "_dyad_mean", lag_suffix)
    if (component == "raw") {
      mean_col <- paste0(column_stem, "_dyad_mean_gmc", lag_suffix)
    }
    deviation_col <- paste0(column_stem, "_within_dyad_dev", lag_suffix)

    dyad_decomposition_level <- "dyad"
    if (has_time && component %in% c("raw", "cwp")) {
      dyad_decomposition_level <- "dyad_time"
    }

    predictors <- tibble::add_row(
      predictors,
      predictor = predictor,
      component = component,
      lag = lag,
      source_column = source_col,
      mean_column = mean_col,
      deviation_column = deviation_col,
      dyad_decomposition_level = dyad_decomposition_level
    )
  }

  decomposition_plan <- dplyr::bind_rows(
    tibble::tibble(
      target = predictors$mean_column,
      predictor = predictors$predictor,
      temporal_component = predictors$component,
      lag = predictors$lag,
      model_family = rep(model_family, nrow(predictors)),
      column_role = rep("dyad_mean", nrow(predictors)),
      variable_role = rep("predictor", nrow(predictors)),
      source_column = predictors$source_column
    ),
    tibble::tibble(
      target = predictors$deviation_column,
      predictor = predictors$predictor,
      temporal_component = predictors$component,
      lag = predictors$lag,
      model_family = rep(model_family, nrow(predictors)),
      column_role = rep("within_dyad_deviation", nrow(predictors)),
      variable_role = rep("predictor", nrow(predictors)),
      source_column = predictors$source_column
    )
  )
  validate_generated_column_plan(out, decomposition_plan)

  for (i in seq_len(nrow(predictors))) {
    component <- predictors$component[[i]]
    source_col <- predictors$source_column[[i]]
    mean_col <- predictors$mean_column[[i]]
    deviation_col <- predictors$deviation_column[[i]]

    if (has_time && component %in% c("raw", "cwp")) {
      out <- add_dyad_time_decomposition(
        out = out,
        group = group,
        member = member,
        time = time,
        source_col = source_col,
        mean_col = mean_col,
        deviation_col = deviation_col,
        center_mean = component == "raw"
      )
    } else {
      out <- add_dyad_level_decomposition(
        out = out,
        group = group,
        member = member,
        source_col = source_col,
        mean_col = mean_col,
        deviation_col = deviation_col,
        center_mean = component == "raw"
      )
    }
  }

  list(
    data = out,
    predictors = predictors,
    column_plan = decomposition_plan
  )
}

make_dyad_predictor_column_stem <- function(predictor, component, source_col,
                                            lag = 0L) {
  if (lag > 0L) {
    source_col <- sub(paste0("_lag", lag, "$"), "", source_col)
  }

  if (component != "raw") {
    return(source_col)
  }

  predictor_suffix <- make_dyad_suffixes(predictor)[[predictor]]
  paste0(dyad_reserved_prefix, predictor_suffix)
}

add_dyad_time_decomposition <- function(out, group, member, time, source_col,
                                        mean_col, deviation_col,
                                        center_mean = FALSE) {
  join_keys <- c(group, time, member)

  dyad_time_values <- out |>
    dplyr::select(dplyr::all_of(c(join_keys, source_col))) |>
    dplyr::group_by(.data[[group]], .data[[time]]) |>
    dplyr::mutate(
      # Both member values are required for dyad-level predictor scores.
      .dy_dyad_n_observed = sum(!is.na(.data[[source_col]])),
      .dy_dyad_mean = dplyr::if_else(
        .data$.dy_dyad_n_observed == 2L,
        no_NaN_mean(.data[[source_col]]),
        NA_real_
      ),
      "{mean_col}" := .data$.dy_dyad_mean,
      "{deviation_col}" := .data[[source_col]] - .data$.dy_dyad_mean
    ) |>
    dplyr::ungroup()

  if (center_mean) {
    dyad_time_mean_values <- dyad_time_values |>
      dplyr::distinct(.data[[group]], .data[[time]], .data[[mean_col]])

    grand_mean <- no_NaN_mean(dyad_time_mean_values[[mean_col]])

    dyad_time_values <- dyad_time_values |>
      dplyr::mutate("{mean_col}" := .data[[mean_col]] - grand_mean)
  }

  dyad_time_values <- dyad_time_values |>
    dplyr::select(
      dplyr::all_of(join_keys),
      dplyr::all_of(c(mean_col, deviation_col))
    )

  dplyr::left_join(out, dyad_time_values, by = join_keys)
}

add_dyad_level_decomposition <- function(out, group, member, source_col, mean_col,
                                         deviation_col, center_mean = FALSE) {
  # Between-person components are repeated over time, so reduce to one row per
  # dyad-member before computing dyad means to avoid weighting by observed days.
  person_values <- out |>
    dplyr::select(dplyr::all_of(c(group, member, source_col))) |>
    dplyr::distinct()

  dyad_values <- person_values |>
    dplyr::group_by(.data[[group]]) |>
    dplyr::mutate(
      .dy_dyad_n_observed = sum(!is.na(.data[[source_col]])),
      .dy_dyad_mean = dplyr::if_else(
        .data$.dy_dyad_n_observed == 2L,
        no_NaN_mean(.data[[source_col]]),
        NA_real_
      ),
      "{deviation_col}" := .data[[source_col]] - .data$.dy_dyad_mean
    ) |>
    dplyr::ungroup()

  # Raw cross-sectional dyad means are grand-mean centered by convention.
  if (center_mean) {
    dyad_mean_values <- dyad_values |>
      dplyr::distinct(.data[[group]], .data$.dy_dyad_mean)

    grand_mean <- no_NaN_mean(dyad_mean_values$.dy_dyad_mean)

    dyad_values <- dyad_values |>
      dplyr::mutate("{mean_col}" := .data$.dy_dyad_mean - grand_mean)
  } else {
    # Other components already have the intended scale, for example cbp.
    dyad_values <- dyad_values |>
      dplyr::mutate("{mean_col}" := .data$.dy_dyad_mean)
  }

  dyad_values <- dyad_values |>
    dplyr::select(
      dplyr::all_of(c(group, member)),
      dplyr::all_of(c(mean_col, deviation_col))
    )

  dplyr::left_join(out, dyad_values, by = c(group, member))
}
