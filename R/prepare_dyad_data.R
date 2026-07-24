#' Prepare dyadic data for multilevel models
#'
#' Validates dyadic data, records the structural variables, and adds metadata
#' and model-ready columns for dyadic multilevel model parameterizations.
#'
#' Data must be in long format. Cross-sectional dyadic data may contain at most
#' one row per member within dyad. Intensive longitudinal dyadic data may
#' contain at most one row per member and observed measurement occasion within
#' dyad. Measured variables may contain missing values. Structural completeness
#' is assessed across all rows. `incomplete_dyads` controls dyads with fewer
#' than two members; dyads with more than two members always cause an error.
#' When `role` is supplied, stable member roles are resolved across repeated
#' rows before `missing_role` is applied.
#'
#' Dyad composition labels are canonical: role labels are sorted alphabetically
#' before being combined, so labels do not depend on row or member order.
#'
#' @param data A data frame or tibble. Data must be in long format. For
#' cross-sectional dyadic data, each observed member of each dyad has one row.
#' For intensive longitudinal dyadic data, each observed member of each dyad has
#' one row per observed time point.
#' @param dyad Column identifying the dyad.
#' @param member Column identifying a person or the member within dyad.
#' @param role Optional column identifying a stable member role, such as gender.
#'   Non-missing values must be consistent within each `dyad` x `member` and
#'   must not contain `_x_`. In repeated-measures data, an observed role is
#'   propagated to missing rows for the same member within a dyad.
#'   `missing_role` controls dyads in which a member has no non-missing role on
#'   any row. If no role is supplied, all dyads are treated as the same type of
#'   exchangeable dyads.
#' @param time Optional column identifying time or measurement order of repeated
#' measures.
#' @param predictors Optional variables to use for temporal predictor
#'   decomposition and model-ready predictor construction.
#' @param lag1_predictors Optional subset of `predictors` for which lag-1
#'   model-ready columns should be created. Requires `time` to be a finite,
#'   integer-valued numeric measurement index. Lagging respects the dyad and
#'   member structure, matches observations at exactly `time - 1`, and does not
#'   bridge missing occasions. Only raw and within-person predictors are
#'   lagged. Stable between-person versions are not.
#' @param model_types Model-ready column families to construct. Can contain one
#'   or more of `"apim"`, `"dim"`, and `"dsm"`. `"apim"` creates
#'   actor and partner predictors. `"dim"` creates dyad-mean and
#'   within-dyad member-deviation predictors. `"dsm"` creates dyadic-score model
#'   predictor columns. `"none"` skips model-specific predictor
#'   construction after validation, composition inference, and optional
#'   temporal predictor decomposition, and must be used alone. `"dim"` and
#'   `"dsm"` must be requested in separate calls.
#' @param dsm_role_order For `model_types = "dsm"`, a character vector giving
#'   the two distinguishable roles in the order used for directional
#'   differences. For example, `c("female", "male")` defines predictor
#'   differences as female minus male and assigns the DSM role contrast `+0.5`
#'   to female partners and `-0.5` to male partners. Required when DSM columns
#'   are requested and must be `NULL` otherwise.
#' @param temporal_decomposition Temporal decomposition strategy for
#'   `predictors`.
#'   `"none"` leaves predictors undecomposed before model-specific columns are
#'   constructed. `"2l"` indicates a two-level temporal predictor
#'   decomposition into within-person and between-person components. `"auto"`
#'   resolves to `"2l"` when both `time` and `predictors` are supplied, and
#'   to `"none"` otherwise. `"2l"` retains raw model-ready predictors in
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
#' @param keep_compositions Optional observed dyad compositions to keep
#'   before exchangeability overrides and pooling. Requires `role`. Composition
#'   references use the same format as `set_exchangeable_compositions`. `NULL`
#'   keeps all observed compositions.
#' @param pool_compositions Optionally pool exchangeable dyad compositions
#'   into a shared final composition label. Must be a named list where each name
#'   is the final composition label and each value is a character vector of
#'   composition references, for example
#'   `list(same_sex_couples = c("female-female", "male-male"))`. Only
#'   exchangeable compositions can be pooled. Each pool must contain at least
#'   two distinct observed compositions after composition references are
#'   resolved.
#' @param incomplete_dyads How to handle dyads with fewer than two unique
#'   members across all rows in `data`. `"error"` stops with an error and
#'   `"drop"` removes the entire dyad. A dyad with more than two unique members
#'   is invalid and always causes an error, regardless of this setting.
#' @param missing_role How to handle dyads in which at least one member has no
#'   non-missing `role` value on any row. A consistent non-missing role observed
#'   for a member is propagated to that member's other rows before this policy
#'   is applied. `"error"` stops with an error and `"drop"` removes the entire
#'   dyad. Conflicting non-missing roles always cause an error. Ignored when no
#'   `role` column is supplied.
#' @param seed Optional seed for random `.dy_member_contrast_*` sign assignment
#'   in exchangeable dyads. If `NULL`, the current R session's RNG state is used.
#'
#' @return The original data as a tibble with class `dyadMLM_data`,
#'   `.dy_composition` and `.dy_composition_role` factor columns,
#'   `.dy_is_*` numeric indicator columns, composition-specific
#'   numeric `.dy_member_contrast_*` columns coded `-1` and `1` for the two
#'   members of matching exchangeable dyads and `0` otherwise, and a `dyadMLM`
#'   attribute containing structural metadata, `dyad_compositions`, and
#'   predictor metadata such as `temporal_decompositions`, `lag1_predictors`,
#'   `apim_predictors`, and `dim_predictors`, as well as `dsm_predictors` and
#'   `dsm_role_order` when applicable. The `generated_columns` table records each
#'   package-generated column retained in the returned data.
#'
#' @examples
#' data <- data.frame(
#'   dyad_id = c(1, 1, 2, 2, 3, 3),
#'   person_id = c(1, 2, 3, 4, 5, 6),
#'   role = c("female", "male", "female", "female", "male", "male"),
#'   x = c(4, 7, 5, 6, 3, 8)
#' )
#'
#' prepared <- prepare_dyad_data(
#'   data,
#'   dyad = dyad_id,
#'   member = person_id,
#'   role = role,
#'   predictors = x,
#'   model_types = "apim"
#' )
#'
#' print(prepared)
#'
#' pooled <- prepare_dyad_data(
#'   data,
#'   dyad = dyad_id,
#'   member = person_id,
#'   role = role,
#'   predictors = x,
#'   model_types = "apim",
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
#' ild_prepared <- prepare_dyad_data(
#'   ild_data,
#'   dyad = dyad_id,
#'   member = person_id,
#'   time = time,
#'   predictors = x,
#'   lag1_predictors = x,
#'   model_types = "apim",
#'   seed = 123
#' )
#'
#' print(ild_prepared)
#'
#' @export
prepare_dyad_data <- function(
    data,
    dyad,
    member,
    role = NULL,
    time = NULL,
    predictors = NULL,
    lag1_predictors = NULL,
    model_types = "apim",
    dsm_role_order = NULL,
    temporal_decomposition = c("auto", "2l", "none"),
    set_exchangeable_compositions = NULL,
    keep_compositions = NULL,
    pool_compositions = NULL,
    incomplete_dyads = c("error", "drop"),
    missing_role = c("error", "drop"),
    seed = NULL
  ) {

  model_types <- normalize_model_types(model_types)
  temporal_decomposition <- rlang::arg_match(temporal_decomposition)
  incomplete_dyads <- rlang::arg_match(incomplete_dyads)
  missing_role <- rlang::arg_match(missing_role)

  out <- validate_dyad_data(
    data = data,
    dyad = {{ dyad }},
    member = {{ member }},
    role = {{ role }},
    time = {{ time }},
    predictors = {{ predictors }},
    lag1_predictors = {{ lag1_predictors }},
    model_types = model_types,
    dsm_role_order = dsm_role_order,
    temporal_decomposition = temporal_decomposition,
    incomplete_dyads = incomplete_dyads,
    missing_role = missing_role
  )

  out <- infer_dyad_compositions(
    out,
    seed = seed,
    keep_compositions = keep_compositions,
    set_exchangeable_compositions = set_exchangeable_compositions,
    pool_compositions = pool_compositions
  )

  # Validate model compatibilities
  if ("dsm" %in% model_types) {
    validate_dsm_compatibility(out)
  }

  out <- center_predictors(out)
  out <- add_temporal_lag_columns(out)

  if ("dim" %in% model_types) {
    # Current DIM construction supports one exchangeable composition.
    validate_dim_compatibility(out)
  }

  # Add model cols
  if ("apim" %in% model_types) {
    out <- add_actor_partner_columns(out)
  }

  if ("dim" %in% model_types) {
    out <- add_dyad_individual_columns(out)
  }

  if ("dsm" %in% model_types) {
    out <- add_dyadic_score_columns(out)
  }

  return(out)
}
