#' Prepare dyadic data for interdep
#'
#' Validates dyadic data, records the structural variables, and adds metadata
#' used by downstream interdep functions.
#'
#' Data must be in long format. Cross-sectional dyadic data may contain at most
#' one row per member within dyad. Intensive longitudinal dyadic data may
#' contain at most one row per member and observed measurement occasion within
#' dyad. Measured variables may contain missing values. Missing or incomplete
#' structural information is controlled by `incomplete_dyads` and
#' `missing_role`.
#'
#' @param data A data frame or tibble. Data must be in long format. For
#' cross-sectional dyadic data, each observed member of each dyad has one row.
#' For intensive longitudinal dyadic data, each observed member of each dyad has
#' one row per observed time point.
#' @param group Column identifying the dyad.
#' @param member Column identifying a person or the member within dyad.
#' @param role Optional column identifying a stable member role, such as gender.
#'   Values must be stable within each `group` x `member` and must not contain
#'   `_x_`. Missing role information is controlled by `missing_role`. If no role
#'   is supplied, all dyads are treated as the same type of exchangeable dyads.
#' @param time Optional column identifying time or measurement order of repeated
#' measures.
#' @param predictors Optional character vector of predictor columns to transform
#'   into `_actor` and `_partner` columns for APIM analyses.
#' @param incomplete_dyads How to handle dyads that do not contain exactly two
#'   unique members anywhere in the data. `"error"` stops with an error and
#'   `"drop"` removes the entire dyad.
#' @param missing_role How to handle missing values in the `role` column.
#'   `"error"` stops with an error, `"drop"` removes dyads with incomplete role
#'   information. Ignored when no `role` column is supplied.
#' @param seed Optional seed for random arbitrary partner-role assignment. If
#'   `NULL`, the current R session's RNG state is used.
#'
#' @return The original data as a tibble with class `interdep_data`,
#'   `.i_composition` and `.i_composition_role` factor columns,
#'   `.i_arbitrary_role`, `.i_is_*` numeric indicator columns, `.i_diff`, and
#'   an `interdep` attribute containing structural metadata and
#'   `dyad_compositions`. Arbitrary-role indicators and `.i_diff` are active
#'   for exchangeable dyads and zero for distinguishable dyads.
#'
#' @examples
#' data <- data.frame(
#'   dyad_id = c(1, 1, 2, 2),
#'   person_id = c(1, 2, 3, 4),
#'   role = c("female", "male", "female", "male")
#' )
#'
#' prepared <- prepare_interdep_data(
#'   data,
#'   group = dyad_id,
#'   member = person_id,
#'   role = role
#' )
#'
#' attr(prepared, "interdep")$dyad_compositions
#'
#' print(prepared)
#' @export
prepare_interdep_data <- function(
    data,
    group,
    member,
    role = NULL,
    time = NULL,
    predictors = NULL,
    incomplete_dyads = c("error", "drop"),
    missing_role = c("error", "drop"),
    seed = NULL
  ) {

  incomplete_dyads <- rlang::arg_match(incomplete_dyads)
  missing_role <- rlang::arg_match(missing_role)

  out <- validate_interdep_data(
    data = data,
    group = {{ group }},
    member = {{ member }},
    role = {{ role }},
    time = {{ time }},
    incomplete_dyads = incomplete_dyads,
    missing_role = missing_role
  )

  out <- infer_dyad_compositions(out)

  out <- add_arbitrary_roles(out, seed = seed)

  # out <- add_actor_partner_columns(out, variables = predictors)

  # out <- add_wb_centering(out)

  out
}
