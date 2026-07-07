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
#' Dyad composition labels are canonical: role labels are sorted alphabetically
#' before being combined, so labels do not depend on row or member order.
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
#' @param predictors Optional variables to use for centering and model-ready
#'   predictor construction.
#' @param model_type Predictor shape to construct. `"apim"` creates actor and
#'   partner predictors. `"dim"` creates dyad mean and half-difference predictors.
#' @param centering Predictor-centering strategy. `"none"` leaves predictors
#'   undecomposed. `"time_2l"` indicates a two-level temporal decomposition into
#'   within-person and between-person predictor components. `"auto"` resolves to
#'   `"time_2l"` when both `time` and `predictors` are supplied, and to `"none"`
#'   otherwise.
#' @param incomplete_dyads How to handle dyads that do not contain exactly two
#'   unique members anywhere in the data. `"error"` stops with an error and
#'   `"drop"` removes the entire dyad.
#' @param missing_role How to handle missing values in the `role` column.
#'   `"error"` stops with an error, `"drop"` removes dyads with incomplete role
#'   information. Ignored when no `role` column is supplied.
#' @param seed Optional seed for random `.i_diff` sign assignment in
#'   exchangeable dyads. If `NULL`, the current R session's RNG state is used.
#'
#' @return The original data as a tibble with class `interdep_data`,
#'   `.i_composition` and `.i_composition_role` factor columns,
#'   `.i_is_*` numeric indicator columns, `.i_diff`, composition-specific
#'   `.i_diff_*` columns for exchangeable dyads, and an `interdep` attribute
#'   containing structural metadata and `dyad_compositions`. `.i_diff` is
#'   active for exchangeable dyads and zero for distinguishable dyads.
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
    model_type = c("apim", "dim"),
    centering = c("auto", "time_2l", "none"),
    incomplete_dyads = c("error", "drop"),
    missing_role = c("error", "drop"),
    seed = NULL
  ) {

  out <- validate_interdep_data(
    data = data,
    group = {{ group }},
    member = {{ member }},
    role = {{ role }},
    time = {{ time }},
    predictors = {{ predictors }},
    model_type = model_type,
    centering = centering,
    incomplete_dyads = incomplete_dyads,
    missing_role = missing_role
  )

  out <- infer_dyad_compositions(out, seed = seed)

  out <- center_predictors(out)

  # out <- add_actor_partner_columns(out, variables = predictors)

  # out <- add_wb_centering(out)

  out
}
