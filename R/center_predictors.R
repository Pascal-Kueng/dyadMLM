#' Center predictor variables for dyadic models
#'
#' Adds centered predictor columns to an `interdep_data` object. It currently
#' supports two-level temporal centering for intensive longitudinal predictors:
#' a within-person component and a between-person component.
#' For two-level temporal centering, the between-person component is centered
#' around the grand mean of person means, not the grand mean of all observed rows.
#' This gives each person equal weight even when people have different numbers of
#' observed measurement occasions.
#'
#' The function uses the structural metadata stored by
#' [prepare_interdep_data()].
#'
#' @param data An `interdep_data` object returned by [prepare_interdep_data()].
#'
#' @return An `interdep_data` object with centered predictor columns added and
#'   updated predictor metadata.
#'
#' @keywords internal
center_predictors <- function(data) {
  if (!inherits(data, "interdep_data")) {
    stop("`data` must be an `interdep_data` object.", call. = FALSE)
  }

  meta_data <- attr(data, "interdep")
  out <- data

  group <- meta_data$group
  member <- meta_data$member
  predictors <- meta_data$predictors
  temporal_predictor_decomposition <- meta_data$temporal_predictor_decomposition

  # Downstream predictor-construction helpers read this table instead of
  # inferring generated column names from string patterns.
  predictor_decompositions <- tibble::tibble(
    predictor = character(),
    component = character(),
    column = character(),
    temporal_predictor_decomposition = character()
  )

  if (length(predictors) == 0) {
    attr(out, "interdep")$predictor_decompositions <- predictor_decompositions

    return(out)
  }

  if (temporal_predictor_decomposition == "none") {
    attr(out, "interdep")$predictor_decompositions <- tibble::tibble(
      predictor = predictors,
      component = "raw",
      column = predictors,
      temporal_predictor_decomposition = temporal_predictor_decomposition
    )

    return(out)
  }

  if (temporal_predictor_decomposition == "time_2l") {
    predictor_suffixes <- make_interdep_suffixes(predictors)

    for (predictor in predictors) {
      predictor_suffix <- predictor_suffixes[[predictor]]
      person_mean_col <- paste0(interdep_reserved_prefix, predictor_suffix, "_person_mean")
      cwp_col <- paste0(interdep_reserved_prefix, predictor_suffix, "_cwp")
      cbp_col <- paste0(interdep_reserved_prefix, predictor_suffix, "_cbp")

      person_means <- out |>
        dplyr::group_by(.data[[group]], .data[[member]]) |>
        dplyr::summarise(
          "{person_mean_col}" := no_NaN_mean(.data[[predictor]]),
          .groups = "drop"
        )

      grand_mean <- no_NaN_mean(person_means[[person_mean_col]])

      out <- out |>
        dplyr::left_join(person_means, by = c(group, member)) |>
        dplyr::mutate(
          "{cwp_col}" := .data[[predictor]] - .data[[person_mean_col]],
          "{cbp_col}" := .data[[person_mean_col]] - grand_mean
        )

      out[[person_mean_col]] <- NULL

      predictor_decompositions <- tibble::add_row(
        predictor_decompositions,
        predictor = c(predictor, predictor),
        component = c("cwp", "cbp"),
        column = c(cwp_col, cbp_col),
        temporal_predictor_decomposition = temporal_predictor_decomposition
      )
    }

    attr(out, "interdep")$predictor_decompositions <- predictor_decompositions

    return(out)
  }

  stop("Unsupported `temporal_predictor_decomposition` value in `data` metadata.", call. = FALSE)
}


no_NaN_mean <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }

  mean(x, na.rm = TRUE)
}
