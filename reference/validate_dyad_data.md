# Validate dyadic input data

Checks whether `data` has a valid long-format dyadic structure and
returns it as a tibble with an additional `dyadMLM_data` class.
Cross-sectional data may contain at most one row per member within each
dyad. Intensive longitudinal data may contain at most one row per member
and measurement occasion within each dyad.

## Usage

``` r
validate_dyad_data(
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
  incomplete_dyads = c("error", "drop"),
  missing_role = c("error", "drop")
)
```

## Arguments

- data:

  A long-format data frame or tibble.

- dyad:

  Column identifying the dyad.

- member:

  Column identifying the two people or members within each dyad, such as
  a person ID.

- role:

  Optional column identifying a stable member role, such as gender.
  Non-missing values must be consistent within each `dyad` x `member`.
  In repeated-measures data, an observed role is propagated to missing
  rows for the same member within a dyad. If no role is supplied, all
  dyads are treated as exchangeable.

- time:

  Optional column identifying time or measurement order.

- predictors:

  Optional variables to select and store as metadata for temporal
  predictor decomposition and model-helper functions.

- lag1_predictors:

  Optional subset of `predictors` for which lag-1 model-ready columns
  should be created. Requires a finite, integer-valued numeric `time`
  variable.

- model_types:

  Requested model-ready column families. Can contain one or more of
  `"apim"`, `"dim"`, and `"dsm"`. `"none"` indicates no model-specific
  predictor construction and must be used alone.

- dsm_role_order:

  For `model_types = "dsm"`, a character vector giving the two
  distinguishable roles in the order used for directional differences.
  Required when DSM columns are requested and must be `NULL` otherwise.

- temporal_decomposition:

  Requested temporal predictor decomposition strategy for predictors.
  `"none"` leaves predictors undecomposed before model-specific columns
  are constructed. `"2l"` indicates a two-level temporal predictor
  decomposition into within-person and between-person components.
  `"auto"` resolves to `"2l"` when both `time` and `predictors` are
  supplied, and to `"none"` otherwise. Model-specific helpers may apply
  additional conventions, such as grand-mean centering raw DIM and DSM
  dyad means.

- incomplete_dyads:

  How to handle dyads with fewer than two unique members across all rows
  in `data`. `"error"` stops with an error and `"drop"` removes the
  entire dyad. A dyad with more than two unique members is invalid and
  always causes an error, regardless of this setting.

- missing_role:

  How to handle dyads in which at least one member has no non-missing
  `role` value on any row. A consistent non-missing role observed for a
  member is propagated to that member's other rows before this policy is
  applied. `"error"` stops with an error and `"drop"` removes the entire
  dyad. Conflicting non-missing roles always cause an error. Ignored
  when no `role` column is supplied.

## Value

A tibble with class `dyadMLM_data` and metadata about the dyad, member,
optional role, and optional time columns.
