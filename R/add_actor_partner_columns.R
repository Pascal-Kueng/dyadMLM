#' Add actor and partner predictor columns
#'
#' Adds APIM-style actor and partner columns for the predictors recorded in an
#' `dyadMLM_data` object. For uncentered predictors, this will create actor and
#' partner versions of the raw predictor. For centered intensive longitudinal
#' predictors, this will create actor and partner versions of the raw predictor
#' and each recorded predictor component, such as the within-person and
#' between-person components created by [center_predictors()].
#' Selected lag predictors additionally create lag-1 raw and within-person
#' actor and partner columns.
#'
#' The function will use the predictor decomposition metadata stored in
#' `attr(data, "dyadMLM")$temporal_decompositions`, so downstream code does
#' not need to infer generated predictor columns from their names. It stores the
#' constructed APIM columns in `attr(data, "dyadMLM")$apim_predictors`.
#'
#' @param data A `dyadMLM_data` object returned by [prepare_dyad_data()].
#'
#' @return A `dyadMLM_data` object with actor and partner predictor columns
#'   added and APIM predictor metadata recorded.
#'
#' @keywords internal
add_actor_partner_columns <- function(data) {
  if (!inherits(data, "dyadMLM_data")) {
    stop(
      "`data` must be a `dyadMLM_data` object returned by `prepare_dyad_data()`.",
      call. = FALSE
    )
  }

  # Extracting all needed metadata
  meta_data <- attr(data, "dyadMLM")

  dyad <- meta_data$dyad
  member <- meta_data$member
  has_time <- meta_data$longitudinal
  time <- meta_data$time

  temporal_decompositions <- meta_data$temporal_decompositions

  apim_predictors <- tibble::tibble(
    predictor = character(),
    component = character(),
    lag = integer(),
    source_column = character(),
    actor_column = character(),
    partner_column = character()
  )

  # if no predictor was provided
  if (nrow(temporal_decompositions) == 0) {
    attr(data, "dyadMLM")$apim_predictors <- apim_predictors
    return(data)
  }

  out <- data

  # Resolve the entire stage before writing so two semantic origins cannot
  # silently converge on the same compact actor/partner name.
  for (i in seq_len(nrow(temporal_decompositions))) {
    predictor <- temporal_decompositions$predictor[[i]]
    component <- temporal_decompositions$component[[i]]
    lag <- temporal_decompositions$lag[[i]]
    source_col <- temporal_decompositions$column[[i]]

    column_stem <- source_col
    if (lag > 0L) {
      column_stem <- sub(paste0("_lag", lag, "$"), "", column_stem)
    }
    if (component == "raw") {
      predictor_suffix <- make_dyad_suffixes(predictor)[[predictor]]
      column_stem <- paste0(dyad_reserved_prefix, predictor_suffix)
    }

    lag_suffix <- make_predictor_lag_suffix(lag)
    actor_col <- paste0(column_stem, "_actor", lag_suffix)
    partner_col <- paste0(column_stem, "_partner", lag_suffix)

    apim_predictors <- tibble::add_row(
      apim_predictors,
      predictor = predictor,
      component = component,
      lag = lag,
      source_column = source_col,
      actor_column = actor_col,
      partner_column = partner_col
    )
  }

  apim_plan <- dplyr::bind_rows(
    tibble::tibble(
      target = apim_predictors$actor_column,
      predictor = apim_predictors$predictor,
      temporal_component = apim_predictors$component,
      lag = apim_predictors$lag,
      model_family = "apim",
      column_role = "actor",
      variable_role = "predictor",
      source_column = apim_predictors$source_column
    ),
    tibble::tibble(
      target = apim_predictors$partner_column,
      predictor = apim_predictors$predictor,
      temporal_component = apim_predictors$component,
      lag = apim_predictors$lag,
      model_family = "apim",
      column_role = "partner",
      variable_role = "predictor",
      source_column = apim_predictors$source_column
    )
  )
  validate_generated_column_plan(out, apim_plan)

  for (i in seq_len(nrow(apim_predictors))) {
    source_col <- apim_predictors$source_column[[i]]
    actor_col <- apim_predictors$actor_column[[i]]
    partner_col <- apim_predictors$partner_column[[i]]

    # Storing the actor column
    out[[actor_col]] <- out[[source_col]]

    # Computing and storing the partner column
    join_keys <- dyad

    if (has_time) {
      join_keys <- c(dyad, time)
    }

    partner_lookup <- out |>
      dplyr::select(
        dplyr::all_of(c(join_keys, member, source_col))
      ) |>
      # Rename each row's source value so it can be matched back as the
      # partner value for the other member in the dyad.
      dplyr::rename(
        .dy_partner_member = dplyr::all_of(member),
        "{partner_col}" := dplyr::all_of(source_col)
      )

    # We create a table with the original members' ID, then match the partner
    # lookup to it, and filter out self-matches.

    partner_values <- out |>
      dplyr::select(
        dplyr::all_of(c(join_keys, member))
      ) |>
      dplyr::rename(
        .dy_actor_member = dplyr::all_of(member)
      ) |>
      # Now we join the partner_lookup rows to the original member table.
      # This leads to the partner-values of both partners being matched to both
      # the actor IDs of both members of the dyad temporarily.
      dplyr::left_join(
        partner_lookup,
        by = join_keys,
        relationship = "many-to-many"
      ) |>
      # we remove the self-matches
      dplyr::filter(.data$.dy_partner_member != .data$.dy_actor_member) |>
      # We keep only the cols needed for matching and the _partner column.
      dplyr::select(
        dplyr::all_of(join_keys),
        dplyr::all_of(".dy_actor_member"),
        dplyr::all_of(partner_col)
      ) |>
      dplyr::rename(
        "{member}" := dplyr::all_of(".dy_actor_member")
      )

    out <- out |>
      dplyr::left_join(
        partner_values,
        by = c(join_keys, member)
      )

  }

  attr(out, "dyadMLM")$apim_predictors <- apim_predictors
  out <- record_generated_columns(out, apim_plan)

  return(out)
}
