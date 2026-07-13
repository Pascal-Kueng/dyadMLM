#' Add actor and partner predictor columns
#'
#' Adds APIM-style actor and partner columns for the predictors recorded in an
#' `interdep_data` object. For uncentered predictors, this will create actor and
#' partner versions of the raw predictor. For centered intensive longitudinal
#' predictors, this will create actor and partner versions of the raw predictor
#' and each recorded predictor component, such as the within-person and
#' between-person components created by [center_predictors()].
#'
#' The function will use the predictor decomposition metadata stored in
#' `attr(data, "interdep")$temporal_predictor_decompositions`, so downstream code does
#' not need to infer generated predictor columns from their names. It stores the
#' constructed APIM columns in `attr(data, "interdep")$apim_predictors`.
#'
#' @param data An `interdep_data` object returned by [prepare_interdep_data()].
#'
#' @return An `interdep_data` object with actor and partner predictor columns
#'   added and APIM predictor metadata recorded.
#'
#' @keywords internal
add_actor_partner_columns <- function(data) {
  if (!inherits(data, "interdep_data")) {
    stop("`data` must be an `interdep_data` object.", call. = FALSE)
  }

  # Extracting all needed metadata
  meta_data <- attr(data, "interdep")

  group <- meta_data$group
  member <- meta_data$member
  has_time <- meta_data$longitudinal
  time <- meta_data$time

  temporal_predictor_decompositions <- meta_data$temporal_predictor_decompositions

  apim_predictors <- tibble::tibble(
    predictor = character(),
    component = character(),
    source_column = character(),
    actor_column = character(),
    partner_column = character()
  )

  # if no predictor was provided
  if (nrow(temporal_predictor_decompositions) == 0) {
    attr(data, "interdep")$apim_predictors <- apim_predictors
    return(data)
  }

  out <- data

  for (i in seq_len(nrow(temporal_predictor_decompositions))) {
    predictor <- temporal_predictor_decompositions$predictor[[i]]
    component <- temporal_predictor_decompositions$component[[i]]
    source_col <- temporal_predictor_decompositions$column[[i]]

    column_stem <- source_col
    if (component == "raw") {
      predictor_suffix <- make_interdep_suffixes(predictor)[[predictor]]
      column_stem <- paste0(interdep_reserved_prefix, predictor_suffix)
    }

    actor_col <- paste0(column_stem, "_actor")
    partner_col <- paste0(column_stem, "_partner")

    apim_predictors <- tibble::add_row(
      apim_predictors,
      predictor = predictor,
      component = component,
      source_column = source_col,
      actor_column = actor_col,
      partner_column = partner_col
    )

    # Storing the actor column
    out[[actor_col]] <- out[[source_col]]

    # Computing and storing the partner column
    join_keys <- group

    if (has_time) {
      join_keys <- c(group, time)
    }

    partner_lookup <- out |>
      dplyr::select(
        dplyr::all_of(c(join_keys, member, source_col))
      ) |>
      # Rename each row's source value so it can be matched back as the
      # partner value for the other member in the dyad.
      dplyr::rename(
        .i_partner_member = dplyr::all_of(member),
        "{partner_col}" := dplyr::all_of(source_col)
      )

    # We create a table with the original members' ID, then match the partner
    # lookup to it, and filter out self-matches.

    partner_values <- out |>
      dplyr::select(
        dplyr::all_of(c(join_keys, member))
      ) |>
      dplyr::rename(
        .i_actor_member = dplyr::all_of(member)
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
      dplyr::filter(.data$.i_partner_member != .data$.i_actor_member) |>
      # We keep only the cols needed for matching and the _partner column.
      dplyr::select(
        dplyr::all_of(join_keys),
        dplyr::all_of(".i_actor_member"),
        dplyr::all_of(partner_col)
      ) |>
      dplyr::rename(
        "{member}" := dplyr::all_of(".i_actor_member")
      )

    out <- out |>
      dplyr::left_join(
        partner_values,
        by = c(join_keys, member)
      )

  }

  attr(out, "interdep")$apim_predictors <- apim_predictors

  return(out)
}

# setup_add_actor_partner_debug()
