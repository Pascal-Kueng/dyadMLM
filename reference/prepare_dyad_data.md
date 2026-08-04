# Prepare dyadic data for multilevel models

Validates dyadic data, records the structural variables, and adds
metadata and model-ready columns for dyadic multilevel model
parameterizations.

## Usage

``` r
prepare_dyad_data(
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
  seed = NULL,
  short_colnames = TRUE,
  include_arbitrary_member_contrast = FALSE,
  add_apim_gmc_predictors = FALSE
)
```

## Arguments

- data:

  A data frame or tibble. Data must be in long format. For
  cross-sectional dyadic data, each observed member of each dyad has one
  row. For intensive longitudinal dyadic data, each observed member of
  each dyad has one row per observed time point.

- dyad:

  Column identifying the dyad.

- member:

  Column identifying a person or the member within dyad.

- role:

  Optional column identifying a stable member role, such as gender.
  Non-missing values must be consistent within each `dyad` x `member`
  and must not contain `_x_`. In repeated-measures data, an observed
  role is propagated to missing rows for the same member within a dyad.
  `missing_role` controls dyads in which a member has no non-missing
  role on any row. If no role is supplied, all dyads are treated as the
  same type of exchangeable dyads.

- time:

  Optional column identifying time or measurement order of repeated
  measures.

- predictors:

  Optional variables to use for temporal predictor decomposition and
  model-ready predictor construction.

- lag1_predictors:

  Optional subset of `predictors` for which lag-1 model-ready columns
  should be created. Requires `time` to be a finite, integer-valued
  numeric measurement index. Lagging respects the dyad and member
  structure, matches observations at exactly `time - 1`, and does not
  bridge missing occasions. Eligible raw, within-person, and APIM GMC
  variants are lagged; stable between-person variants are not.

- model_types:

  Model-ready column families to construct. Can contain one or more of
  `"apim"`, `"dim"`, and `"dsm"`. `"apim"` creates actor and partner
  predictors. `"dim"` creates dyad-mean and within-dyad member-deviation
  predictors. `"dsm"` creates dyadic-score model predictor columns.
  `"none"` skips model-specific predictor construction after validation,
  composition inference, and optional temporal predictor decomposition,
  and must be used alone. `"dim"` and `"dsm"` must be requested in
  separate calls.

- dsm_role_order:

  For `model_types = "dsm"`, a character vector giving the two
  distinguishable roles in the order used for directional differences.
  For example, `c("female", "male")` defines predictor differences as
  female minus male and assigns the DSM role contrast `+0.5` to female
  partners and `-0.5` to male partners. Required when DSM columns are
  requested and must be `NULL` otherwise.

- temporal_decomposition:

  Temporal decomposition strategy for `predictors`. `"none"` leaves
  predictors undecomposed before model-specific columns are constructed.
  `"2l"` indicates a two-level temporal predictor decomposition into
  within-person and between-person components. `"auto"` resolves to
  `"2l"` when both `time` and `predictors` are supplied, and to `"none"`
  otherwise. `"2l"` retains raw model-ready predictors in addition to
  their within-person and between-person components. For longitudinal
  DIM and DSM construction, raw and within-person dyadic scores are
  computed within each dyad occasion, while between-person scores are
  computed within dyads. Raw DIM and DSM dyad means are grand-mean
  centered. Do not include the raw, within-person, and between-person
  versions of the same contemporaneous predictor in one model because
  they are linearly dependent.

- set_exchangeable_compositions:

  Optionally specify dyad compositions to treat as exchangeable, when
  their roles would otherwise imply distinguishability. Requires `role`.
  Compositions that are already exchangeable should not be listed. Each
  composition must be supplied as one string, using `_x_`, `-`, `_`, or
  whitespace (` `) between the two role labels, for example
  `"female_x_male"`, `"female-male"`, `"female_male"`, or
  `"female male"`, in arbitrary order. To set multiple compositions, use
  a character vector of such strings. Unlike
  `include_arbitrary_member_contrast`, this reclassifies the selected
  compositions as exchangeable and changes their composition-role coding
  and indicators, which is required for composition pooling and DIM
  compatibility.

- keep_compositions:

  Optional observed dyad compositions to keep before exchangeability
  overrides and pooling. Requires `role`. Composition references use the
  same format as `set_exchangeable_compositions`. `NULL` keeps all
  observed compositions.

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

- seed:

  Optional seed for random `.member_contrast_*` sign assignment. If
  `NULL`, the current R session's RNG state is used.

- short_colnames:

  Whether to use shorter composition-dependent generated column names
  when the final data contain one composition. The default `TRUE` omits
  the redundant composition label from `.is_*` and `.member_contrast_*`
  names. `FALSE` always retains composition-qualified names. Other
  generated column names are unaffected.

- include_arbitrary_member_contrast:

  Whether to also generate arbitrary `.member_contrast_*` columns for
  distinguishable compositions. The default `FALSE` generates these
  columns only for exchangeable compositions. `TRUE` retains
  distinguishable composition metadata, composition roles, and role
  indicators. It only adds the contrast needed to fit an
  exchangeability-constrained random-effects model to the same prepared
  data. Use `set_exchangeable_compositions` instead to reclassify
  compositions for pooling or DIM compatibility.

- add_apim_gmc_predictors:

  Whether to add APIM GMC variants for numeric predictors. `TRUE`
  retains the raw columns and adds `.{pred}_gmc` plus its actor and
  partner versions, centered over all retained non-missing values after
  filtering. Lagged variants use the same mean. Mixed non-numeric
  predictors remain raw and are listed in one warning. In longitudinal
  data, the mean is observation-weighted. Requires `"apim"` in
  `model_types`, at least one numeric predictor, and resolved
  `temporal_decomposition = "none"`. Do not use raw and GMC variants
  together in a model with an intercept.

## Value

The original data as a tibble with class `dyadMLM_data`, `.composition`
and `.composition_role` factor columns, `.is_*` numeric indicator
columns, and numeric `.member_contrast_*` columns coded `-1` and `1` for
the two members of each matching composition and `0` otherwise. With one
final composition, their default names omit the composition label. The
`dyadMLM` attribute contains structural metadata, `dyad_compositions`,
and predictor metadata such as `temporal_decompositions`,
`lag1_predictors`, `apim_predictors`, and `dim_predictors`, as well as
`dsm_predictors` and `dsm_role_order` when applicable. The
`generated_columns` table records each package-generated column retained
in the returned data.

## Details

Data must be in long format. Cross-sectional dyadic data may contain at
most one row per member within dyad. Intensive longitudinal dyadic data
may contain at most one row per member and observed measurement occasion
within dyad. Measured variables may contain missing values. Structural
completeness is assessed across all rows. `incomplete_dyads` controls
dyads with fewer than two members; dyads with more than two members
always cause an error. When `role` is supplied, stable member roles are
resolved across repeated rows before `missing_role` is applied.

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

prepared <- prepare_dyad_data(
  data,
  dyad = dyad_id,
  member = person_id,
  role = role,
  predictors = x,
  model_types = "apim"
)

print(prepared)
#> # dyadMLM data
#> # Rows: 6 | Dyads: 3 | Intensive longitudinal: no
#> # Structure: dyad = dyad_id, member = person_id, role = role
#> #
#> # Dyad compositions:
#> # female_x_female exchangeable    1 dyad
#> # female_x_male   distinguishable 1 dyad
#> # male_x_male     exchangeable    1 dyad
#> #
#> # Added columns:
#> #   .composition                       inferred dyad composition
#> #   .composition_role                  composition-specific member role
#> #   .is_{comp-role}                    composition-role indicator columns
#> #   .member_contrast_{comp}_arbitrary  composition-specific member contrasts
#> #                                      coded -1/+1 in arbitrary direction for
#> #                                      exchangeability-constrained random
#> #                                      effects. Values are 0 for other
#> #                                      compositions
#> #   .{pred}_actor                      APIM actor predictor: actor's original
#> #                                      predictor values
#> #   .{pred}_partner                    APIM partner predictor: partner's
#> #                                      original predictor values
#> #
#> # A tibble: 6 × 14
#>   dyad_id person_id role       x .composition    .composition_role   
#>     <dbl>     <dbl> <chr>  <dbl> <fct>           <fct>               
#> 1       1         1 female     4 female_x_male   female_x_male_female
#> 2       1         2 male       7 female_x_male   female_x_male_male  
#> 3       2         3 female     5 female_x_female female_x_female     
#> 4       2         4 female     6 female_x_female female_x_female     
#> 5       3         5 male       3 male_x_male     male_x_male         
#> 6       3         6 male       8 male_x_male     male_x_male         
#> # ℹ 8 more variables: .is_female_x_female <dbl>,
#> #   .is_female_x_male_female <dbl>, .is_female_x_male_male <dbl>,
#> #   .is_male_x_male <dbl>, .member_contrast_female_x_female_arbitrary <dbl>,
#> #   .member_contrast_male_x_male_arbitrary <dbl>, .x_actor <dbl>,
#> #   .x_partner <dbl>

pooled <- prepare_dyad_data(
  data,
  dyad = dyad_id,
  member = person_id,
  role = role,
  predictors = x,
  model_types = "apim",
  set_exchangeable_compositions = "female-male",
  pool_compositions = list(
    romantic_couples = c("female-female", "male-male", "female-male")
  )
)

print(pooled)
#> # dyadMLM data
#> # Rows: 6 | Dyads: 3 | Intensive longitudinal: no
#> # Structure: dyad = dyad_id, member = person_id, role = role
#> #
#> # Dyad compositions:
#> # romantic_couples (pooled) exchangeable 3 dyads
#> #   female_x_female
#> #   female_x_male
#> #   male_x_male
#> #
#> # Added columns:
#> #   .composition                inferred dyad composition
#> #   .composition_role           composition-specific member role
#> #   .is_exchangeable            composition-role indicator columns
#> #   .member_contrast_arbitrary  composition-specific member contrasts coded
#> #                               -1/+1 in arbitrary direction for
#> #                               exchangeability-constrained random effects.
#> #                               Values are 0 for other compositions
#> #   .{pred}_actor               APIM actor predictor: actor's original
#> #                               predictor values
#> #   .{pred}_partner             APIM partner predictor: partner's original
#> #                               predictor values
#> #
#> # A tibble: 6 × 10
#>   dyad_id person_id role       x .composition .composition_role .is_exchangeable
#>     <dbl>     <dbl> <chr>  <dbl> <fct>        <fct>                        <dbl>
#> 1       1         1 female     4 romantic_co… romantic_couples                 1
#> 2       1         2 male       7 romantic_co… romantic_couples                 1
#> 3       2         3 female     5 romantic_co… romantic_couples                 1
#> 4       2         4 female     6 romantic_co… romantic_couples                 1
#> 5       3         5 male       3 romantic_co… romantic_couples                 1
#> 6       3         6 male       8 romantic_co… romantic_couples                 1
#> # ℹ 3 more variables: .member_contrast_arbitrary <dbl>, .x_actor <dbl>,
#> #   .x_partner <dbl>

ild_data <- data.frame(
  dyad_id = rep(c(1, 2), each = 4),
  person_id = rep(c(1, 2), times = 4),
  time = rep(c(1, 1, 2, 2), times = 2),
  x = c(4, 7, 5, 8, 3, 6, 4, 7)
)

ild_prepared <- prepare_dyad_data(
  ild_data,
  dyad = dyad_id,
  member = person_id,
  time = time,
  predictors = x,
  lag1_predictors = x,
  model_types = "apim",
  seed = 123
)

print(ild_prepared)
#> # dyadMLM data
#> # Rows: 8 | Dyads: 2 | Intensive longitudinal: yes
#> # Structure: dyad = dyad_id, member = person_id, time = time
#> #
#> # Dyad compositions:
#> # assumed_exchangeable exchangeable 2 dyads
#> #
#> # Added columns:
#> #   .composition                inferred dyad composition
#> #   .composition_role           composition-specific member role
#> #   .is_exchangeable            composition-role indicator columns
#> #   .member_contrast_arbitrary  composition-specific member contrasts coded
#> #                               -1/+1 in arbitrary direction for
#> #                               exchangeability-constrained random effects.
#> #                               Values are 0 for other compositions
#> #   .{pred}_lag1                lag-1 raw predictor values
#> #   .{pred}_cwp                 within-person predictor: momentary deviations
#> #                               from each person's usual level
#> #   .{pred}_cwp_lag1            lag-1 within-person predictor: momentary
#> #                               deviations from each person's usual level
#> #   .{pred}_cbp                 between-person predictor: stable differences
#> #                               from the average person's usual level
#> #   .{pred}_actor               APIM actor predictor: actor's original
#> #                               predictor values
#> #   .{pred}_actor_lag1          lag-1 APIM actor predictor: actor's original
#> #                               predictor values
#> #   .{pred}_partner             APIM partner predictor: partner's original
#> #                               predictor values
#> #   .{pred}_partner_lag1        lag-1 APIM partner predictor: partner's
#> #                               original predictor values
#> #   .{pred}_cwp_actor           APIM within-person actor predictor: actor's
#> #                               momentary deviations from their usual level
#> #   .{pred}_cwp_actor_lag1      lag-1 APIM within-person actor predictor:
#> #                               actor's momentary deviations from their usual
#> #                               level
#> #   .{pred}_cwp_partner         APIM within-person partner predictor: partner's
#> #                               momentary deviations from their usual level
#> #   .{pred}_cwp_partner_lag1    lag-1 APIM within-person partner predictor:
#> #                               partner's momentary deviations from their usual
#> #                               level
#> #   .{pred}_cbp_actor           APIM between-person actor predictor: actor's
#> #                               stable difference from the average person's
#> #                               usual level
#> #   .{pred}_cbp_partner         APIM between-person partner predictor:
#> #                               partner's stable difference from the average
#> #                               person's usual level
#> #
#> # A tibble: 8 × 22
#>   dyad_id person_id  time     x .composition  .composition_role .is_exchangeable
#>     <dbl>     <dbl> <dbl> <dbl> <fct>         <fct>                        <dbl>
#> 1       1         1     1     4 assumed_exch… assumed_exchange…                1
#> 2       1         2     1     7 assumed_exch… assumed_exchange…                1
#> 3       1         1     2     5 assumed_exch… assumed_exchange…                1
#> 4       1         2     2     8 assumed_exch… assumed_exchange…                1
#> 5       2         1     1     3 assumed_exch… assumed_exchange…                1
#> 6       2         2     1     6 assumed_exch… assumed_exchange…                1
#> 7       2         1     2     4 assumed_exch… assumed_exchange…                1
#> 8       2         2     2     7 assumed_exch… assumed_exchange…                1
#> # ℹ 15 more variables: .member_contrast_arbitrary <dbl>, .x_cwp <dbl>,
#> #   .x_cbp <dbl>, .x_lag1 <dbl>, .x_cwp_lag1 <dbl>, .x_actor <dbl>,
#> #   .x_partner <dbl>, .x_cwp_actor <dbl>, .x_cwp_partner <dbl>,
#> #   .x_cbp_actor <dbl>, .x_cbp_partner <dbl>, .x_actor_lag1 <dbl>,
#> #   .x_partner_lag1 <dbl>, .x_cwp_actor_lag1 <dbl>, .x_cwp_partner_lag1 <dbl>
```
