#' Add dyad-individual predictor columns
#'
#' Adds Dyad-Individual Model (DIM) style dyad-mean and within-dyad-deviation
#' columns for the predictors recorded in an `interdep_data` object. For
#' currently supported undirected DIMs and undirected DSMs, the data must
#' contain one exchangeable dyad composition. This means distinguishable dyads
#' and multiple exchangeable compositions are not supported by DIM/DSM
#' construction until explicit role-contrast, composition-specific, or pooling
#' support is added. For
#' intensive longitudinal predictors decomposed by [center_predictors()], the
#' within-person component is decomposed within each dyad-time occasion and the
#' between-person component is decomposed once within each dyad.
#' For raw cross-sectional predictors, the dyad-mean column is centered around
#' the grand mean of dyad means by DIM convention, while the
#' within-dyad-deviation column is the person's deviation from the uncentered
#' dyad mean.
#'
#' The function reads `attr(data, "interdep")$temporal_predictor_decompositions` and
#' stores the constructed DIM columns in
#' `attr(data, "interdep")$dim_predictors`.
#'
#' @param data An `interdep_data` object returned by [prepare_interdep_data()].
#'
#' @return An `interdep_data` object with dyad-mean and within-dyad-deviation
#'   predictor columns added and DIM predictor metadata recorded.
#'
#' @keywords internal
add_dyad_individual_columns <- function(data) {
  if (!inherits(data, "interdep_data")) {
    stop("`data` must be an `interdep_data` object.", call. = FALSE)
  }

  validate_undirected_dyad_compatibility(data)

  meta_data <- attr(data, "interdep")

  group <- meta_data$group
  member <- meta_data$member
  has_time <- meta_data$longitudinal
  time <- meta_data$time

  temporal_predictor_decompositions <- meta_data$temporal_predictor_decompositions

  # empty table for metadata
  dim_predictors <- tibble::tibble(
    predictor = character(),
    component = character(),
    source_column = character(),
    mean_column = character(),
    deviation_column = character(),
    decomposition_level = character()
  )

  if (nrow(temporal_predictor_decompositions) == 0) {
    attr(data, "interdep")$dim_predictors <- dim_predictors
    return(data)
  }

  out <- data

  for (i in seq_len(nrow(temporal_predictor_decompositions))) {
    predictor <- temporal_predictor_decompositions$predictor[[i]]
    component <- temporal_predictor_decompositions$component[[i]]
    source_col <- temporal_predictor_decompositions$column[[i]]

    if (has_time && !component %in% c("cwp", "cbp")) {
      stop(
        "`model_type = \"dim\"` or `model_type = \"undirected_dsm\"` for longitudinal predictors requires supported centered predictor components. ",
        "Use `temporal_predictor_decomposition = \"auto\"` or `temporal_predictor_decomposition = \"time_2l\"`, or choose ",
        "`model_type = \"none\"` or a different supported model type.",
        call. = FALSE
      )
    }

    # constructing all column names that we will create dynamically.
    predictor_suffix <- make_interdep_suffixes(predictor)[[predictor]]
    column_stem <- source_col

    if (component == "raw") {
      column_stem <- paste0(interdep_reserved_prefix, predictor_suffix, "_raw")
    }

    mean_col <- paste0(column_stem, "_dyad_mean")
    if (component == "raw") {
      mean_col <- paste0(column_stem, "_dyad_mean_gmc")
    }
    deviation_col <- paste0(column_stem, "_within_dyad_deviation")

    # Record the level at which this component is decomposed.
    decomposition_level <- "dyad"
    if (component == "cwp") {
      decomposition_level <- "dyad_time"
    }

    # update table with metadata of the current looping component.
    dim_predictors <- tibble::add_row(
      dim_predictors,
      predictor = predictor,
      component = component,
      source_column = source_col,
      mean_column = mean_col,
      deviation_column = deviation_col,
      decomposition_level = decomposition_level
    )

    # only within-person components need special handling
    if (component == "cwp") {
      out <- add_dyad_time_decomposition(
        out = out,
        group = group,
        member = member,
        time = time,
        source_col = source_col,
        mean_col = mean_col,
        deviation_col = deviation_col
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

  attr(out, "interdep")$dim_predictors <- dim_predictors

  return(out)
}

add_dyad_time_decomposition <- function(out, group, member, time, source_col,
                                        mean_col, deviation_col) {
  join_keys <- c(group, time, member)

  dyad_time_values <- out |>
    dplyr::select(dplyr::all_of(c(join_keys, source_col))) |>
    dplyr::group_by(.data[[group]], .data[[time]]) |>
    dplyr::mutate(
      # We can only construct DIM parameters sensibly if we have both
      # partners' observations. Therefore we return NA if that is not the case,
      # otherwise construct the mean and individual deviation.
      .i_dim_n_observed = sum(!is.na(.data[[source_col]])),
      .i_dim_mean = dplyr::if_else(
        .data$.i_dim_n_observed == 2L,
        no_NaN_mean(.data[[source_col]]),
        NA_real_
      ),
      "{mean_col}" := .data$.i_dim_mean,
      "{deviation_col}" := .data[[source_col]] - .data$.i_dim_mean
    ) |>
    dplyr::ungroup() |>
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
      .i_dim_n_observed = sum(!is.na(.data[[source_col]])),
      .i_dim_mean = dplyr::if_else(
        .data$.i_dim_n_observed == 2L,
        no_NaN_mean(.data[[source_col]]),
        NA_real_
      ),
      "{deviation_col}" := .data[[source_col]] - .data$.i_dim_mean
    ) |>
    dplyr::ungroup()

  # Raw cross-sectional DIM dyad means are grand-mean centered by convention.
  if (center_mean) {
    dyad_mean_values <- dyad_values |>
      dplyr::distinct(.data[[group]], .data$.i_dim_mean)

    grand_mean <- no_NaN_mean(dyad_mean_values$.i_dim_mean)

    dyad_values <- dyad_values |>
      dplyr::mutate("{mean_col}" := .data$.i_dim_mean - grand_mean)
  } else {
    # Other components already have the intended scale, for example cbp.
    dyad_values <- dyad_values |>
      dplyr::mutate("{mean_col}" := .data$.i_dim_mean)
  }

  dyad_values <- dyad_values |>
    dplyr::select(
      dplyr::all_of(c(group, member)),
      dplyr::all_of(c(mean_col, deviation_col))
    )

  dplyr::left_join(out, dyad_values, by = c(group, member))
}

# setup_add_dyad_individual_debug()
