#' Prepare dyadic data for multilevel models
#'
#' Validates dyadic data, records the structural variables, and adds metadata
#' and model-ready columns for dyadic multilevel model parameterizations.
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
#' @param lag_predictors Optional subset of `predictors` for which lag-1
#'   model-ready columns should be created. Requires `time` to be a finite,
#'   integer-valued numeric measurement index. Lagging respects the dyad and
#'   member structure, matches observations at exactly `time - 1`, and does not
#'   bridge missing occasions. Only raw and within-person predictors are
#'   lagged. Stable between-person versions are not.
#' @param model_type Model-ready column families to construct. Can contain one
#'   or more of `"apim"`, `"dim"`, and `"dsm"`. `"apim"` creates
#'   actor and partner predictors. `"dim"` creates dyad-mean and
#'   within-dyad-deviation predictors. `"dsm"` creates dyadic-score model
#'   predictor columns. `"none"` skips model-specific predictor
#'   construction after validation, composition inference, and optional
#'   temporal predictor decomposition, and must be used alone. `"dim"` and
#'   `"dsm"` must be requested in separate calls.
#' @param dsm_role_order For `model_type = "dsm"`, a character vector giving
#'   the two distinguishable roles in the order used for directional
#'   differences. For example, `c("female", "male")` defines predictor
#'   differences as female minus male and assigns the DSM role contrast `+0.5`
#'   to female partners and `-0.5` to male partners. Required when DSM columns
#'   are requested and must be `NULL` otherwise.
#' @param temporal_predictor_decomposition Temporal decomposition strategy for
#'   `predictors`.
#'   `"none"` leaves predictors undecomposed before model-specific columns are
#'   constructed. `"time_2l"` indicates a two-level temporal predictor
#'   decomposition into within-person and between-person components. `"auto"`
#'   resolves to `"time_2l"` when both `time` and `predictors` are supplied, and
#'   to `"none"` otherwise. `"time_2l"` retains raw model-ready predictors in
#'   addition to their within-person and between-person components. For
#'   longitudinal DIM and DSM construction, raw and within-person dyadic scores
#'   are computed within each dyad occasion, while between-person scores are
#'   computed within dyads. Raw DIM and DSM dyad means are grand-mean centered.
#'   Do not include the raw, within-person, and between-person versions of the
#'   same contemporaneous predictor in one model because they are linearly
#'   dependent.
#' @param set_exchangeable_compositions Optionally specify dyad compositions
#'   to treat as exchangeable, when their roles would otherwise imply distinguishability.
#'   Requires `role`. Compositions that are already
#'   exchangeable should not be listed. Each composition must be supplied as one
#'   string, using `_x_`, `-`, `_`, or whitespace (` `) between the two role labels,
#'   for example `"female_x_male"`, `"female-male"`, `"female_male"`, or
#'   `"female male"`, in arbitrary order.
#'   To set multiple compositions, use a character vector of such strings.
#' @param include_compositions Optional observed dyad compositions to keep
#'   before exchangeability overrides and pooling. Requires `role`. Composition
#'   references use the same format as `set_exchangeable_compositions`.
#' @param pool_compositions Optionally pool exchangeable dyad compositions
#'   into a shared final composition label. Must be a named list where each name
#'   is the final composition label and each value is a character vector of
#'   composition references, for example
#'   `list(same_sex_couples = c("female-female", "male-male"))`. Only
#'   exchangeable compositions can be pooled. Each pool must contain at least
#'   two distinct observed compositions after composition references are
#'   resolved.
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
#'   numeric `.i_diff_*` contrast columns coded `-1` and `1` for the two members
#'   of matching exchangeable dyads and `0` otherwise, and an `interdep` attribute
#'   containing structural metadata, `dyad_compositions`, and predictor metadata
#'   such as `temporal_predictor_decompositions`, `lag_predictors`,
#'   `apim_predictors`, and
#'   `dim_predictors`, as well as `dsm_predictors` and `dsm_role_order` when
#'   applicable.
#'
#' @examples
#' data <- data.frame(
#'   dyad_id = c(1, 1, 2, 2, 3, 3),
#'   person_id = c(1, 2, 3, 4, 5, 6),
#'   role = c("female", "male", "female", "female", "male", "male"),
#'   x = c(4, 7, 5, 6, 3, 8)
#' )
#'
#' prepared <- prepare_interdep_data(
#'   data,
#'   group = dyad_id,
#'   member = person_id,
#'   role = role,
#'   predictors = x,
#'   model_type = "apim"
#' )
#'
#' print(prepared)
#'
#' pooled <- prepare_interdep_data(
#'   data,
#'   group = dyad_id,
#'   member = person_id,
#'   role = role,
#'   predictors = x,
#'   model_type = "apim",
#'   set_exchangeable_compositions = "female-male",
#'   pool_compositions = list(
#'     romantic_couples = c("female-female", "male-male", "female-male")
#'   )
#' )
#'
#' print(pooled)
#'
#' ild_data <- data.frame(
#'   dyad_id = rep(c(1, 2), each = 4),
#'   person_id = rep(c(1, 2), times = 4),
#'   time = rep(c(1, 1, 2, 2), times = 2),
#'   x = c(4, 7, 5, 8, 3, 6, 4, 7)
#' )
#'
#' ild_prepared <- prepare_interdep_data(
#'   ild_data,
#'   group = dyad_id,
#'   member = person_id,
#'   time = time,
#'   predictors = x,
#'   lag_predictors = x,
#'   model_type = "apim",
#'   seed = 123
#' )
#'
#' print(ild_prepared)
#'
#' @export
prepare_interdep_data <- function(
    data,
    group,
    member,
    role = NULL,
    time = NULL,
    predictors = NULL,
    lag_predictors = NULL,
    model_type = "apim",
    dsm_role_order = NULL,
    temporal_predictor_decomposition = c("auto", "time_2l", "none"),
    set_exchangeable_compositions = NULL,
    include_compositions = NULL,
    pool_compositions = NULL,
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
    lag_predictors = {{ lag_predictors }},
    model_type = model_type,
    dsm_role_order = dsm_role_order,
    temporal_predictor_decomposition = temporal_predictor_decomposition,
    incomplete_dyads = incomplete_dyads,
    missing_role = missing_role
  )

  out <- infer_dyad_compositions(
    out,
    seed = seed,
    include_compositions = include_compositions,
    set_exchangeable_compositions = set_exchangeable_compositions,
    pool_compositions = pool_compositions
  )

  # Validate model compatibilities
  if ("dsm" %in% model_type) {
    validate_dsm_compatibility(out)
  }

  out <- center_predictors(out)
  out <- add_temporal_lag_columns(out)

  if ("dim" %in% model_type) {
    # Current DIM construction supports one exchangeable composition.
    validate_dim_compatibility(out)
  }

  # Add model cols
  if ("apim" %in% model_type) {
    out <- add_actor_partner_columns(out)
  }

  if ("dim" %in% model_type) {
    out <- add_dyad_individual_columns(out)
  }

  if ("dsm" %in% model_type) {
    out <- add_dyadic_score_columns(out)
  }

  return(out)
}
