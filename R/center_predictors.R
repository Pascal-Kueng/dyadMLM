#' Center predictor variables for dyadic models
#'
#' Adds centered predictor columns to an `interdep_data` object. It currently
#' supports two-level temporal centering for intensive longitudinal predictors:
#' a within-person component and a between-person component.
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
  centering <- meta_data$centering

  if (centering == "none") {
    return(out)
  }

  if (centering == "time_2l") {
    predictor_suffixes <- make_interdep_suffixes(predictors)
    centered_predictors <- tibble::tibble(
      predictor = character(),
      cwp = character(),
      cbp = character(),
      centering = character()
    )

    for (predictor in predictors) {
      person_mean_col <- paste0(predictor, "_person_mean")
      predictor_suffix <- predictor_suffixes[[predictor]]
      cwp_col <- paste0(interdep_reserved_prefix, predictor_suffix, "_cwp")
      cbp_col <- paste0(interdep_reserved_prefix, predictor_suffix, "_cbp")

      person_means <- out |>
        dplyr::group_by(.data[[group]], .data[[member]]) |>
        dplyr::summarise(
          "{person_mean_col}" := no_NaN_mean(.data[[predictor]]),
          .groups = "drop"
        )

      grand_mean <- mean(person_means[[person_mean_col]], na.rm = TRUE)

      out <- out |>
        dplyr::left_join(person_means, by = c(group, member)) |>
        dplyr::mutate(
          "{cwp_col}" := .data[[predictor]] - .data[[person_mean_col]],
          "{cbp_col}" := .data[[person_mean_col]] - grand_mean
        )

      out[[person_mean_col]] <- NULL

      centered_predictors <- tibble::add_row(
        centered_predictors,
        predictor = predictor,
        cwp = cwp_col,
        cbp = cbp_col,
        centering = centering
      )
    }

    attr(out, "interdep")$centered_predictors <- centered_predictors

    return(out)
  }
}


no_NaN_mean <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }

  mean(x, na.rm = TRUE)
}
