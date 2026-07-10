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
#' @param predictors Optional variables to use for temporal predictor
#'   decomposition and model-ready predictor construction.
#' @param outcomes Optional variables to use for model-ready outcome construction.
#'   Currently only needed for `model_type = "undirected_dsm"`.
#' @param model_type Model-ready column families to construct. Can contain one
#'   or more of `"apim"`, `"dim"`, and `"undirected_dsm"`. `"apim"` creates
#'   actor and partner predictors. `"dim"` creates dyad-mean and
#'   within-dyad-deviation predictors. `"undirected_dsm"` creates undirected
#'   dyadic-score model columns. `"none"` skips model-specific predictor and
#'   outcome construction after validation, composition inference, and optional
#'   temporal predictor decomposition, and must be used alone.
#' @param temporal_predictor_decomposition Temporal decomposition strategy for
#'   `predictors`.
#'   `"none"` leaves predictors undecomposed before model-specific columns are
#'   constructed. `"time_2l"` indicates a two-level temporal predictor
#'   decomposition into within-person and between-person components. `"auto"`
#'   resolves to `"time_2l"` when both `time` and `predictors` are supplied, and
#'   to `"none"` otherwise. Raw cross-sectional DIM predictor dyad-mean columns
#'   are still centered around the grand mean of dyad means as part of DIM-style
#'   predictor construction. For longitudinal DIM or undirected DSM predictor
#'   construction, raw undecomposed predictors are currently rejected; use
#'   `"auto"` or `"time_2l"`.
#' @param set_compositions_exchangeable Optionally specify dyad compositions
#'   to treat as exchangeable, when their roles would otherwise imply distinguishability.
#'   Requires `role`. Compositions that are already
#'   exchangeable should not be listed. Each composition must be supplied as one
#'   string, using `_x_`, `-`, `_`, or whitespace (` `) between the two role labels,
#'   for example `"female_x_male"`, `"female-male"`, `"female_male"`, or
#'   `"female male"`, in arbitrary order.
#'   To set multiple compositions, use a character vector of such strings.
#' @param composition_pooling Optionally pool exchangeable dyad compositions
#'   into a shared final composition label. Must be a named list where each name
#'   is the final composition label and each value is a character vector of
#'   composition references, for example
#'   `list(same_sex_couples = c("female-female", "male-male"))`. Only
#'   exchangeable compositions can be pooled.
#' @param incomplete_dyads How to handle dyads that do not contain exactly two
#'   unique members anywhere in the data. `"error"` stops with an error and
#'   `"drop"` removes the entire dyad.
#' @param missing_role How to handle missing values in the `role` column.
#'   `"error"` stops with an error, `"drop"` removes dyads with incomplete role
#'   information. Ignored when no `role` column is supplied.
#' @param seed Optional seed for random `.i_diff_*` sign assignment in
#'   exchangeable dyads. If `NULL`, the current R session's RNG state is used.
#'
#' @return The original data as a tibble with class `interdep_data`,
#'   `.i_composition` and `.i_composition_role` factor columns,
#'   `.i_is_*` numeric indicator columns, composition-specific
#'   `.i_diff_*` columns for exchangeable dyads, and an `interdep` attribute
#'   containing structural metadata, `dyad_compositions`, and predictor metadata
#'   such as `temporal_predictor_decompositions`, `apim_predictors`, and
#'   `dim_predictors` when applicable.
#'
#' @examples
#' data <- data.frame(
#'   dyad_id = c(1, 1, 2, 2, 3, 3),
#'   person_id = c(1, 2, 3, 4, 5, 6),
#'   role = c("female", "male", "female", "female", "male", "male")
#' )
#'
#' prepared <- prepare_interdep_data(
#'   data,
#'   group = dyad_id,
#'   member = person_id,
#'   role = role
#' )
#'
#' print(prepared)
#'
#'
#' pooled <- prepare_interdep_data(
#'   data,
#'   group = dyad_id,
#'   member = person_id,
#'   role = role,
#'   set_compositions_exchangeable = "female-male",
#'   composition_pooling = list(
#'     same_sex_couples = c("female-female", "male-male")
#'   )
#' )
#'
#' print(pooled)
#'
#' @export
prepare_interdep_data <- function(
    data,
    group,
    member,
    role = NULL,
    time = NULL,
    predictors = NULL,
    outcomes = NULL,
    model_type = "apim",
    temporal_predictor_decomposition = c("auto", "time_2l", "none"),
    set_compositions_exchangeable = NULL,
    composition_pooling = NULL,
    incomplete_dyads = c("error", "drop"),
    missing_role = c("error", "drop"),
    seed = NULL
  ) {

  model_type <- normalize_model_type(model_type)
  temporal_predictor_decomposition <- rlang::arg_match(temporal_predictor_decomposition)
  incomplete_dyads <- rlang::arg_match(incomplete_dyads)
  missing_role <- rlang::arg_match(missing_role)

  out <- validate_interdep_data(
    data = data,
    group = {{ group }},
    member = {{ member }},
    role = {{ role }},
    time = {{ time }},
    predictors = {{ predictors }},
    outcomes = {{ outcomes }},
    model_type = model_type,
    temporal_predictor_decomposition = temporal_predictor_decomposition,
    incomplete_dyads = incomplete_dyads,
    missing_role = missing_role
  )

  out <- infer_dyad_compositions(
    out,
    seed = seed,
    set_compositions_exchangeable = set_compositions_exchangeable,
    composition_pooling = composition_pooling
  )

  out <- center_predictors(out)

  if (any(model_type %in% c("dim", "undirected_dsm"))) {
    # Current DIM/DSM construction supports one exchangeable composition.
    validate_undirected_dyad_compatibility(out)
  }

  if ("apim" %in% model_type) {
    out <- add_actor_partner_columns(out)
  }

  if ("dim" %in% model_type && !"undirected_dsm" %in% model_type) {
    out <- add_dyad_individual_columns(out)
  }

  if ("undirected_dsm" %in% model_type) {
    out <- add_undirected_dyadic_score_columns(out)
  }

  return(out)
}
