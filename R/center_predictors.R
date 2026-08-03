#' Center predictor variables for dyadic models
#'
#' Adds centered predictor columns to a `dyadMLM_data` object. It currently
#' supports two-level temporal centering for intensive longitudinal predictors:
#' a within-person component and a between-person component. The original
#' predictor remains available as a raw component for model-specific column
#' construction.
#' It can also add GMC source components for numeric APIM predictors.
#' For two-level temporal centering, the between-person component is centered
#' around the grand mean of person means, not the grand mean of all observed rows.
#' This gives each person equal weight even when people have different numbers of
#' observed measurement occasions.
#'
#' The function uses the structural metadata stored by
#' [prepare_dyad_data()].
#'
#' @param data A `dyadMLM_data` object returned by [prepare_dyad_data()].
#' @param add_apim_gmc_predictors Whether to add APIM GMC source components.
#'
#' @return A `dyadMLM_data` object with centered predictor columns added and
#'   updated predictor metadata.
#'
#' @keywords internal
center_predictors <- function(data, add_apim_gmc_predictors = FALSE) {
  if (!inherits(data, "dyadMLM_data")) {
    stop(
      "`data` must be a `dyadMLM_data` object returned by `prepare_dyad_data()`.",
      call. = FALSE
    )
  }

  meta_data <- attr(data, "dyadMLM")
  out <- data

  dyad <- meta_data$dyad
  member <- meta_data$member
  predictors <- meta_data$predictors
  temporal_decomposition <- meta_data$temporal_decomposition

  # Downstream predictor-construction helpers read this table instead of
  # inferring generated column names from string patterns.
  temporal_decompositions <- tibble::tibble(
    predictor = character(),
    component = character(),
    column = character(),
    temporal_decomposition = character(),
    lag = integer()
  )

  if (length(predictors) == 0) {
    attr(out, "dyadMLM")$temporal_decompositions <- temporal_decompositions

    return(out)
  }

  temporal_decompositions <- tibble::tibble(
    predictor = predictors,
    component = "raw",
    column = predictors,
    temporal_decomposition = "none",
    lag = 0L
  )

  if (temporal_decomposition == "none") {
    if (add_apim_gmc_predictors) {
      predictor_is_numeric <- logical(length(predictors))
      for (predictor_index in seq_along(predictors)) {
        predictor <- predictors[[predictor_index]]
        predictor_is_numeric[[predictor_index]] <- is.numeric(out[[predictor]])
      }

      numeric_predictors <- predictors[predictor_is_numeric]
      numeric_predictor_suffixes <- make_dyad_suffixes(numeric_predictors)
      grand_mean_centered_columns <- paste0(
        dyad_retained_prefix,
        unname(numeric_predictor_suffixes),
        "_gmc"
      )

      # Validate all GMC source names before writing any of them.
      grand_mean_centering_plan <- tibble::tibble(
        target = grand_mean_centered_columns,
        predictor = numeric_predictors,
        temporal_component = "gmc",
        lag = 0L,
        model_family = "apim",
        column_role = "source",
        variable_role = "predictor",
        source_column = numeric_predictors
      )
      validate_generated_column_plan(out, grand_mean_centering_plan)

      for (i in seq_along(numeric_predictors)) {
        predictor <- numeric_predictors[[i]]
        grand_mean_centered_column <- grand_mean_centered_columns[[i]]
        predictor_grand_mean <- no_NaN_mean(out[[predictor]])

        out[[grand_mean_centered_column]] <-
          out[[predictor]] - predictor_grand_mean

        temporal_decompositions <- tibble::add_row(
          temporal_decompositions,
          predictor = predictor,
          component = "gmc",
          column = grand_mean_centered_column,
          temporal_decomposition = "none",
          lag = 0L
        )
      }

      out <- record_generated_columns(out, grand_mean_centering_plan)
    }

    attr(out, "dyadMLM")$temporal_decompositions <- temporal_decompositions

    return(out)
  }

  if (temporal_decomposition == "2l") {
    predictor_suffixes <- make_dyad_suffixes(predictors)

    # One row per proposed target makes collisions independent of predictor
    # order and guarantees that this stage fails before writing any columns.
    plan <- tibble::tibble(
      target = c(
        paste0(dyad_retained_prefix, unname(predictor_suffixes), "_cwp"),
        paste0(dyad_retained_prefix, unname(predictor_suffixes), "_cbp")
      ),
      predictor = rep(predictors, 2L),
      temporal_component = c(
        rep("cwp", length(predictors)),
        rep("cbp", length(predictors))
      ),
      lag = 0L,
      model_family = "temporal",
      column_role = "temporal_component",
      variable_role = "predictor",
      source_column = rep(predictors, 2L)
    )
    validate_generated_column_plan(out, plan)

    for (predictor in predictors) {
      predictor_suffix <- predictor_suffixes[[predictor]]
      person_mean_col <- paste0(dyad_reserved_prefix, predictor_suffix, "_person_mean")
      cwp_col <- paste0(dyad_retained_prefix, predictor_suffix, "_cwp")
      cbp_col <- paste0(dyad_retained_prefix, predictor_suffix, "_cbp")

      person_means <- out |>
        dplyr::group_by(.data[[dyad]], .data[[member]]) |>
        dplyr::summarise(
          "{person_mean_col}" := no_NaN_mean(.data[[predictor]]),
          .groups = "drop"
        )

      grand_mean <- no_NaN_mean(person_means[[person_mean_col]])

      out <- out |>
        dplyr::left_join(person_means, by = c(dyad, member)) |>
        dplyr::mutate(
          "{cwp_col}" := .data[[predictor]] - .data[[person_mean_col]],
          "{cbp_col}" := .data[[person_mean_col]] - grand_mean
        )

      out[[person_mean_col]] <- NULL

      temporal_decompositions <- tibble::add_row(
        temporal_decompositions,
        predictor = c(predictor, predictor),
        component = c("cwp", "cbp"),
        column = c(cwp_col, cbp_col),
        temporal_decomposition = temporal_decomposition,
        lag = 0L
      )
    }

    attr(out, "dyadMLM")$temporal_decompositions <- temporal_decompositions
    out <- record_generated_columns(out, plan)

    return(out)
  }

  stop(
    "Internal error: unsupported `attr(data, \"dyadMLM\")$temporal_decomposition` value `",
    temporal_decomposition,
    "`. Expected one of `none` or `2l` after validation. ",
    "Please report this as a dyadMLM bug with a reproducible example and your package version.",
    call. = FALSE
  )
}


no_NaN_mean <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }

  mean(x, na.rm = TRUE)
}
