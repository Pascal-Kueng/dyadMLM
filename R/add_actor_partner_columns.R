#' Add actor and partner predictor columns
#'
#' Adds APIM-style actor and partner columns for the predictors recorded in an
#' `interdep_data` object. For uncentered predictors, this will create actor and
#' partner versions of the raw predictor. For centered intensive longitudinal
#' predictors, this will create actor and partner versions of each recorded
#' predictor component, such as the within-person and between-person components
#' created by [center_predictors()].
#'
#' The function will use the predictor decomposition metadata stored in
#' `attr(data, "interdep")$predictor_decompositions`, so downstream code does
#' not need to infer generated predictor columns from their names.
#'
#' @param data An `interdep_data` object returned by [prepare_interdep_data()].
#'
#' @return An `interdep_data` object with actor and partner predictor columns
#'   added.
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

  predictors <- meta_data$predictors
  predictor_decompositions <- meta_data$predictor_decompositions

  # if no predictor was provided
  if (nrow(predictor_decompositions) == 0) {
    return(data)
  }

  out <- data

  for (i in seq_len(nrow(predictor_decompositions))) {
    predictor <- predictor_decompositions$predictor[[i]]
    component <- predictor_decompositions$component[[i]]
    source_col <- predictor_decompositions$column[[i]]

    actor_col <- paste0(source_col, "_actor")
    partner_col <- paste0(source_col, "_partner")

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
      # we simply rename the member colname to .i_partner_member and now whatever was
      # an actor column is a partner column. So we rename those too.
      dplyr::rename(
        .i_partner_member = dplyr::all_of(member),
        "{partner_col}" := dplyr::all_of(source_col)
      )

    # We join this table back with the regular data, where partner col does
    # not match actor col!
  }

  return(out)
}

# setup_add_actor_partner_debug()
