# Prepare dyadic data for multilevel models

Validates dyadic data, records the structural variables, and adds
metadata and model-ready columns for dyadic multilevel model
parameterizations.

## Usage

``` r
prepare_interdep_data(
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
)
```

## Arguments

- data:

  A data frame or tibble. Data must be in long format. For
  cross-sectional dyadic data, each observed member of each dyad has one
  row. For intensive longitudinal dyadic data, each observed member of
  each dyad has one row per observed time point.

- group:

  Column identifying the dyad.

- member:

  Column identifying a person or the member within dyad.

- role:

  Optional column identifying a stable member role, such as gender.
  Values must be stable within each `group` x `member` and must not
  contain `_x_`. Missing role information is controlled by
  `missing_role`. If no role is supplied, all dyads are treated as the
  same type of exchangeable dyads.

- time:

  Optional column identifying time or measurement order of repeated
  measures.

- predictors:

  Optional variables to use for temporal predictor decomposition and
  model-ready predictor construction.

- lag_predictors:

  Optional subset of `predictors` for which lag-1 model-ready columns
  should be created. Requires `time` to be a finite, integer-valued
  numeric measurement index. Lagging respects the dyad and member
  structure, matches observations at exactly `time - 1`, and does not
  bridge missing occasions. Only raw and within-person predictors are
  lagged. Stable between-person versions are not.

- model_type:

  Model-ready column families to construct. Can contain one or more of
  `"apim"`, `"dim"`, and `"dsm"`. `"apim"` creates actor and partner
  predictors. `"dim"` creates dyad-mean and within-dyad-deviation
  predictors. `"dsm"` creates dyadic-score model predictor columns.
  `"none"` skips model-specific predictor construction after validation,
  composition inference, and optional temporal predictor decomposition,
  and must be used alone. `"dim"` and `"dsm"` must be requested in
  separate calls.

- dsm_role_order:

  For `model_type = "dsm"`, a character vector giving the two
  distinguishable roles in the order used for directional differences.
  For example, `c("female", "male")` defines predictor differences as
  female minus male and assigns the DSM role contrast `+0.5` to female
  partners and `-0.5` to male partners. Required when DSM columns are
  requested and must be `NULL` otherwise.

- temporal_predictor_decomposition:

  Temporal decomposition strategy for `predictors`. `"none"` leaves
  predictors undecomposed before model-specific columns are constructed.
  `"time_2l"` indicates a two-level temporal predictor decomposition
  into within-person and between-person components. `"auto"` resolves to
  `"time_2l"` when both `time` and `predictors` are supplied, and to
  `"none"` otherwise. `"time_2l"` retains raw model-ready predictors in
  addition to their within-person and between-person components. For
  longitudinal DIM and DSM construction, raw and within-person dyadic
  scores are computed within each dyad occasion, while between-person
  scores are computed within dyads. Raw DIM and DSM dyad means are
  grand-mean centered. Do not include the raw, within-person, and
  between-person versions of the same contemporaneous predictor in one
  model because they are linearly dependent.

- set_exchangeable_compositions:

  Optionally specify dyad compositions to treat as exchangeable, when
  their roles would otherwise imply distinguishability. Requires `role`.
  Compositions that are already exchangeable should not be listed. Each
  composition must be supplied as one string, using `_x_`, `-`, `_`, or
  whitespace (` `) between the two role labels, for example
  `"female_x_male"`, `"female-male"`, `"female_male"`, or
  `"female male"`, in arbitrary order. To set multiple compositions, use
  a character vector of such strings.

- include_compositions:

  Optional observed dyad compositions to keep before exchangeability
  overrides and pooling. Requires `role`. Composition references use the
  same format as `set_exchangeable_compositions`.

- pool_compositions:

  Optionally pool exchangeable dyad compositions into a shared final
  composition label. Must be a named list where each name is the final
  composition label and each value is a character vector of composition
  references, for example
  `list(same_sex_couples = c("female-female", "male-male"))`. Only
  exchangeable compositions can be pooled. Each pool must contain at
  least two distinct observed compositions after composition references
  are resolved.

- incomplete_dyads:

  How to handle dyads that do not contain exactly two unique members
  anywhere in the data. `"error"` stops with an error and `"drop"`
  removes the entire dyad.

- missing_role:

  How to handle missing values in the `role` column. `"error"` stops
  with an error, `"drop"` removes dyads with incomplete role
  information. Ignored when no `role` column is supplied.

- seed:

  Optional seed for random `.i_diff_*` sign assignment in exchangeable
  dyads. If `NULL`, the current R session's RNG state is used.

## Value

The original data as a tibble with class `interdep_data`,
`.i_composition` and `.i_composition_role` factor columns, `.i_is_*`
numeric indicator columns, composition-specific numeric `.i_diff_*`
contrast columns coded `-1` and `1` for the two members of matching
exchangeable dyads and `0` otherwise, and an `interdep` attribute
containing structural metadata, `dyad_compositions`, and predictor
metadata such as `temporal_predictor_decompositions`, `lag_predictors`,
`apim_predictors`, and `dim_predictors`, as well as `dsm_predictors` and
`dsm_role_order` when applicable.

## Details

Data must be in long format. Cross-sectional dyadic data may contain at
most one row per member within dyad. Intensive longitudinal dyadic data
may contain at most one row per member and observed measurement occasion
within dyad. Measured variables may contain missing values. Missing or
incomplete structural information is controlled by `incomplete_dyads`
and `missing_role`.

Dyad composition labels are canonical: role labels are sorted
alphabetically before being combined, so labels do not depend on row or
member order.

## Examples

``` r
data <- data.frame(
  dyad_id = c(1, 1, 2, 2, 3, 3),
  person_id = c(1, 2, 3, 4, 5, 6),
  role = c("female", "male", "female", "female", "male", "male"),
  x = c(4, 7, 5, 6, 3, 8)
)

prepared <- prepare_interdep_data(
  data,
  group = dyad_id,
  member = person_id,
  role = role,
  predictors = x,
  model_type = "apim"
)

print(prepared)
#> # interdep data
#> # Rows: 6 | Dyads: 3 | Intensive longitudinal: no
#> # Structure: group = dyad_id, member = person_id, role = role
#> #
#> # Dyad compositions:
#> # female_x_female exchangeable    1 dyad
#> # female_x_male   distinguishable 1 dyad
#> # male_x_male     exchangeable    1 dyad
#> #
#> # Added columns:
#> #   .i_composition       inferred dyad composition
#> #   .i_composition_role  composition-specific member role
#> #   .i_is_{comp-role}    composition-role indicator columns
#> #   .i_diff_{comp}       composition-specific sum-diff contrasts with arbitrary
#> #                        direction; 0 for distinguishable dyads or other
#> #                        exchangeable compositions
#> #   .i_{pred}_actor      APIM actor predictor: actor's original predictor
#> #                        values
#> #   .i_{pred}_partner    APIM partner predictor: partner's original predictor
#> #                        values
#> #
#> # A tibble: 6 × 14
#>   dyad_id person_id role       x .i_composition  .i_composition_role 
#>     <dbl>     <dbl> <chr>  <dbl> <fct>           <fct>               
#> 1       1         1 female     4 female_x_male   female_x_male_female
#> 2       1         2 male       7 female_x_male   female_x_male_male  
#> 3       2         3 female     5 female_x_female female_x_female     
#> 4       2         4 female     6 female_x_female female_x_female     
#> 5       3         5 male       3 male_x_male     male_x_male         
#> 6       3         6 male       8 male_x_male     male_x_male         
#> # ℹ 8 more variables: .i_is_female_x_female <dbl>,
#> #   .i_is_female_x_male_female <dbl>, .i_is_female_x_male_male <dbl>,
#> #   .i_is_male_x_male <dbl>, .i_diff_female_x_female_arbitrary <dbl>,
#> #   .i_diff_male_x_male_arbitrary <dbl>, .i_x_actor <dbl>, .i_x_partner <dbl>

pooled <- prepare_interdep_data(
  data,
  group = dyad_id,
  member = person_id,
  role = role,
  predictors = x,
  model_type = "apim",
  set_exchangeable_compositions = "female-male",
  pool_compositions = list(
    romantic_couples = c("female-female", "male-male", "female-male")
  )
)

print(pooled)
#> # interdep data
#> # Rows: 6 | Dyads: 3 | Intensive longitudinal: no
#> # Structure: group = dyad_id, member = person_id, role = role
#> #
#> # Dyad compositions:
#> # romantic_couples (pooled) exchangeable 3 dyads
#> #   female_x_female
#> #   female_x_male
#> #   male_x_male
#> #
#> # Added columns:
#> #   .i_composition       inferred dyad composition
#> #   .i_composition_role  composition-specific member role
#> #   .i_is_{comp-role}    composition-role indicator columns
#> #   .i_diff_{comp}       composition-specific sum-diff contrasts with arbitrary
#> #                        direction; 0 for distinguishable dyads or other
#> #                        exchangeable compositions
#> #   .i_{pred}_actor      APIM actor predictor: actor's original predictor
#> #                        values
#> #   .i_{pred}_partner    APIM partner predictor: partner's original predictor
#> #                        values
#> #
#> # A tibble: 6 × 10
#>   dyad_id person_id role       x .i_composition   .i_composition_role
#>     <dbl>     <dbl> <chr>  <dbl> <fct>            <fct>              
#> 1       1         1 female     4 romantic_couples romantic_couples   
#> 2       1         2 male       7 romantic_couples romantic_couples   
#> 3       2         3 female     5 romantic_couples romantic_couples   
#> 4       2         4 female     6 romantic_couples romantic_couples   
#> 5       3         5 male       3 romantic_couples romantic_couples   
#> 6       3         6 male       8 romantic_couples romantic_couples   
#> # ℹ 4 more variables: .i_is_romantic_couples <dbl>,
#> #   .i_diff_romantic_couples_arbitrary <dbl>, .i_x_actor <dbl>,
#> #   .i_x_partner <dbl>

ild_data <- data.frame(
  dyad_id = rep(c(1, 2), each = 4),
  person_id = rep(c(1, 2), times = 4),
  time = rep(c(1, 1, 2, 2), times = 2),
  x = c(4, 7, 5, 8, 3, 6, 4, 7)
)

ild_prepared <- prepare_interdep_data(
  ild_data,
  group = dyad_id,
  member = person_id,
  time = time,
  predictors = x,
  lag_predictors = x,
  model_type = "apim",
  seed = 123
)

print(ild_prepared)
#> # interdep data
#> # Rows: 8 | Dyads: 2 | Intensive longitudinal: yes
#> # Structure: group = dyad_id, member = person_id, time = time
#> #
#> # Dyad compositions:
#> # assumed_exchangeable exchangeable 2 dyads
#> #
#> # Added columns:
#> #   .i_composition              inferred dyad composition
#> #   .i_composition_role         composition-specific member role
#> #   .i_is_{comp-role}           composition-role indicator columns
#> #   .i_diff_{comp}              composition-specific sum-diff contrasts with
#> #                               arbitrary direction; 0 for distinguishable
#> #                               dyads or other exchangeable compositions
#> #   .i_{pred}_lag1              lag-1 raw predictor values
#> #   .i_{pred}_cwp               within-person predictor: momentary deviations
#> #                               from each person's usual level
#> #   .i_{pred}_cwp_lag1          lag-1 within-person predictor: momentary
#> #                               deviations from each person's usual level
#> #   .i_{pred}_cbp               between-person predictor: stable differences
#> #                               from the average person's usual level
#> #   .i_{pred}_actor             APIM actor predictor: actor's original
#> #                               predictor values
#> #   .i_{pred}_actor_lag1        lag-1 APIM actor predictor: actor's original
#> #                               predictor values
#> #   .i_{pred}_partner           APIM partner predictor: partner's original
#> #                               predictor values
#> #   .i_{pred}_partner_lag1      lag-1 APIM partner predictor: partner's
#> #                               original predictor values
#> #   .i_{pred}_cwp_actor         APIM within-person actor predictor: actor's
#> #                               momentary deviations from their usual level
#> #   .i_{pred}_cwp_actor_lag1    lag-1 APIM within-person actor predictor:
#> #                               actor's momentary deviations from their usual
#> #                               level
#> #   .i_{pred}_cwp_partner       APIM within-person partner predictor: partner's
#> #                               momentary deviations from their usual level
#> #   .i_{pred}_cwp_partner_lag1  lag-1 APIM within-person partner predictor:
#> #                               partner's momentary deviations from their usual
#> #                               level
#> #   .i_{pred}_cbp_actor         APIM between-person actor predictor: actor's
#> #                               stable difference from the average person's
#> #                               usual level
#> #   .i_{pred}_cbp_partner       APIM between-person partner predictor:
#> #                               partner's stable difference from the average
#> #                               person's usual level
#> #
#> # A tibble: 8 × 22
#>   dyad_id person_id  time     x .i_composition       .i_composition_role 
#>     <dbl>     <dbl> <dbl> <dbl> <fct>                <fct>               
#> 1       1         1     1     4 assumed_exchangeable assumed_exchangeable
#> 2       1         2     1     7 assumed_exchangeable assumed_exchangeable
#> 3       1         1     2     5 assumed_exchangeable assumed_exchangeable
#> 4       1         2     2     8 assumed_exchangeable assumed_exchangeable
#> 5       2         1     1     3 assumed_exchangeable assumed_exchangeable
#> 6       2         2     1     6 assumed_exchangeable assumed_exchangeable
#> 7       2         1     2     4 assumed_exchangeable assumed_exchangeable
#> 8       2         2     2     7 assumed_exchangeable assumed_exchangeable
#> # ℹ 16 more variables: .i_is_assumed_exchangeable <dbl>,
#> #   .i_diff_assumed_exchangeable_arbitrary <dbl>, .i_x_cwp <dbl>,
#> #   .i_x_cbp <dbl>, .i_x_lag1 <dbl>, .i_x_cwp_lag1 <dbl>, .i_x_actor <dbl>,
#> #   .i_x_partner <dbl>, .i_x_cwp_actor <dbl>, .i_x_cwp_partner <dbl>,
#> #   .i_x_cbp_actor <dbl>, .i_x_cbp_partner <dbl>, .i_x_actor_lag1 <dbl>,
#> #   .i_x_partner_lag1 <dbl>, .i_x_cwp_actor_lag1 <dbl>,
#> #   .i_x_cwp_partner_lag1 <dbl>
```
