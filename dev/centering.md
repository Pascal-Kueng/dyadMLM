# Centering and Predictor-Shape Plan

This note records the intended v0.1.0 design for centering and predictor
construction. The central idea is that APIM and DIM should use the same
temporal decomposition. DIM is then an extra reparameterization step on top of
actor/partner variables, not a separate centering procedure.

## Scope

Version 0.1.0 should support:

- `model_type = c("apim", "dim")`
- `centering = c("auto", "time_2l", "none")`

Reserve `centering = "time_3l"` for a later EMA/day-level workflow with an
explicit day or burst variable. Do not add grand-mean-only centering yet. Do not
let `"auto"` infer `time_3l` later just because a model has three-level random
effects or an EMA/day variable; 3-level predictor decomposition should be an
explicit user choice.

`time_2l` means a two-level temporal decomposition of repeated measures. The
name refers to the predictor decomposition over time, not to the full nesting
structure of the fitted model.

## Pipeline

The workflow should be modular:

1. Center raw time-varying predictors.
2. Create actor/partner variables.
3. If requested, create DIM variables from the actor/partner variables.

Candidate user-facing workflow:

```r
prepared |>
  center_predictors(predictors = provided_support, centering = "time_2l") |>
  add_apim_predictors(predictors = provided_support) |>
  add_dim_predictors(predictors = provided_support)
```

`prepare_interdep_data()` can later call these steps when `predictors`,
`model_type`, and `centering` are supplied.

The default request should be `centering = "auto"`. Resolve `"auto"` to
`"time_2l"` when `time` and `predictors` are supplied, and to `"none"` otherwise.
Store the resolved value in metadata. Do not require centering globally just
because a `time` column exists: users may provide time only for time slopes, may
have centered externally, may use stable predictors repeated across rows, or may
intentionally fit undecomposed predictor effects.

If `time`, `predictors`, and `centering = "none"` are supplied, allow the
workflow but make the behavior explicit in metadata and documentation:
actor/partner or DIM predictors are then undecomposed over time and mix stable
between-person differences with occasion-level fluctuations.

## Implementation Order

Build this in small pieces so each layer can be tested before the next one
depends on it:

1. Add centering and generated-predictor metadata to the `interdep` attribute.
2. Implement `center_predictors()` for raw predictor decomposition.
3. Implement `add_apim_predictors()` for actor/partner predictor columns.
4. Implement `add_dim_predictors()` for mean and half-difference columns.
5. Wire the optional workflow into `prepare_interdep_data()` once the standalone
   helpers are stable.

## Step 1: `time_2l` Centering

For each raw predictor `x`, create:

```r
x_cwp = x - person_mean(x)
x_cbp = person_mean(x) - grand_mean(person_mean(x))
```

where `person_mean(x)` is computed within the structural member column, and the
grand mean is computed over person means, not over all rows.

Column names:

```r
x_cwp
x_cbp
```

Mean calculations should ignore missing predictor values. Centered values should
remain missing where the raw predictor is missing. If a person has no observed
values for a predictor, both centered components should be missing for that
person.

## Step 2: APIM Variables

For each centered component, create actor and partner columns:

```r
x_actor_cwp
x_partner_cwp
x_actor_cbp
x_partner_cbp
```

Partner values are matched within dyad and measurement occasion for longitudinal
data. If the partner row or partner predictor is missing for an occasion, the
partner value should be missing for that row. Structural columns remain
unchanged.

For `model_type = "apim"`, these columns are the main predictor output.

## Step 3: DIM Variables

For `model_type = "dim"`, create mean and half-difference variables from the
APIM columns. The same operation is used for the within-person and
between-person components:

```r
x_cwp_mean     = (x_actor_cwp + x_partner_cwp) / 2
x_cwp_halfdiff = (x_actor_cwp - x_partner_cwp) / 2

x_cbp_mean     = (x_actor_cbp + x_partner_cbp) / 2
x_cbp_halfdiff = (x_actor_cbp - x_partner_cbp) / 2
```

Interpretation:

- `x_cwp_mean`: on this occasion, are both partners jointly higher or lower than
  their own usual levels?
- `x_cwp_halfdiff`: on this occasion, is this member higher or lower than the
  partner relative to each person's usual level?
- `x_cbp_mean`: is this dyad generally high or low compared with other dyads?
- `x_cbp_halfdiff`: is this member generally higher or lower than the partner?

For exchangeable dyads, the half-difference sign follows the existing row-level
actor/partner and `.i_diff` convention. Tests should verify that APIM and DIM
fixed-effect columns are algebraically equivalent under the expected
back-transformation:

```r
b_actor   = (b_mean + b_halfdiff) / 2
b_partner = (b_mean - b_halfdiff) / 2
```

If `centering = "none"`, DIM is still algebraically sensible, but it is a
cross-sectional-style or undecomposed longitudinal DIM:

```r
x_mean     = (x_actor + x_partner) / 2
x_halfdiff = (x_actor - x_partner) / 2
```

This is not the preferred ILD decomposition because it does not separate
within-person and between-person information. It should therefore be allowed for
explicit opt-out/debugging/stable-predictor cases, but the default longitudinal
workflow should remain `time_2l`.

## Validation Rules

- `centering = "time_2l"` requires a `time` column in the `interdep` metadata.
- `time_2l` should error if no predictors are supplied.
- `centering = "auto"` resolves to `time_2l` when `time` and predictors are
  supplied, and to `none` otherwise.
- Store the resolved centering value in metadata.
- If `centering` is omitted, use `auto`.
- If `time`, predictors, and `centering = "none"` are supplied, allow the
  workflow but record that generated predictor columns are undecomposed.
- `add_apim_predictors()` requires centered columns when `centering = "time_2l"`
  and raw columns when `centering = "none"`.
- `add_dim_predictors()` should work from existing actor/partner columns and
  should not recompute centering.
- Existing `.i_*` composition columns must remain unchanged.
- Generated predictor columns should be tracked in `attr(data, "interdep")` so
  the print method can describe them.

## Tests

Minimum tests for v0.1.0:

- `time_2l` creates `x_cwp` and `x_cbp`.
- Person-level `x_cwp` means are zero, within numerical tolerance.
- `x_cbp` is constant within person and grand-mean centered over persons.
- Missing raw values produce missing `x_cwp` but do not break person means.
- APIM creates actor and partner versions for both `cwp` and `cbp`.
- Partner values are matched within dyad-time.
- DIM creates `cwp_mean`, `cwp_halfdiff`, `cbp_mean`, and `cbp_halfdiff`.
- DIM columns equal the corresponding actor/partner sums and differences.
- `add_dim_predictors()` does not alter existing `.i_diff` or composition
  metadata.
