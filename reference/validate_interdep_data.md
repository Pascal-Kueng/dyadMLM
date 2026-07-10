# Validate dyadic input data

Checks whether `data` has a valid long-format dyadic structure and
returns it as a tibble with an additional `interdep_data` class.
Cross-sectional data may contain at most one row per member within each
dyad. Intensive longitudinal data may contain at most one row per member
and measurement occasion within each dyad.

## Usage

``` r
validate_interdep_data(
  data,
  group,
  member,
  role = NULL,
  time = NULL,
  predictors = NULL,
  outcomes = NULL,
  model_type = "apim",
  temporal_predictor_decomposition = c("auto", "time_2l", "none"),
  incomplete_dyads = c("error", "drop"),
  missing_role = c("error", "drop")
)
```

## Arguments

- data:

  A long-format data frame or tibble.

- group:

  Column identifying the dyad.

- member:

  Column identifying the two people or members within each dyad, such as
  a person ID.

- role:

  Optional column identifying role that can be used to distinguish
  partners within a dyad, such as gender. If no role is supplied, all
  dyads in the data are treated as exchangeable.

- time:

  Optional column identifying time or measurement order.

- predictors:

  Optional variables to select and store as metadata for temporal
  predictor decomposition and model-helper functions.

- outcomes:

  Optional variables to select and store as metadata for outcome-side
  model-helper functions. Currently used by
  `model_type = "undirected_dsm"`.

- model_type:

  Requested model-ready column families. Can contain one or more of
  `"apim"`, `"dim"`, and `"undirected_dsm"`. `"none"` indicates no
  model-specific predictor or outcome construction and must be used
  alone.

- temporal_predictor_decomposition:

  Requested temporal predictor decomposition strategy for predictors.
  `"none"` leaves predictors undecomposed before model-specific columns
  are constructed. `"time_2l"` indicates a two-level temporal predictor
  decomposition into within-person and between-person components.
  `"auto"` resolves to `"time_2l"` when both `time` and `predictors` are
  supplied, and to `"none"` otherwise. Model-specific helpers may apply
  additional conventions, such as grand-mean centering raw
  cross-sectional DIM dyad means.

- incomplete_dyads:

  How to handle dyads that do not contain exactly two unique members
  anywhere in the data. `"error"` stops with an error and `"drop"`
  removes the entire dyad.

- missing_role:

  How to handle missing values in the `role` column. `"error"` stops
  with an error, `"drop"` removes dyads with incomplete role
  information. Ignored when no `role` column is supplied.

## Value

A tibble with class `interdep_data` and metadata about the dyad, member,
optional role, and optional time columns.
