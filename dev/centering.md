# Centering and Predictor Construction

This note records the current v0.1.0 design for predictor construction. The
core rule is that APIM and DIM share the same temporal decomposition, but use
separate construction helpers.

## Current Scope

Implemented scope:

- `model_type = c("apim", "dim", "apim_dim", "none")`
- `centering = c("auto", "time_2l", "none")`
- two-level temporal decomposition for ILD predictors
- raw APIM columns for cross-sectional or explicitly undecomposed predictors
- DIM dyad-mean and individual-deviation columns

Reserved for later:

- `centering = "time_3l"` for EMA/day/burst workflows with an explicit higher
  temporal unit
- grand-mean-only centering as a separate user option
- automatic inference of 3-level decomposition from the fitted model structure

`time_2l` refers to the predictor decomposition over time, not to the full
random-effects structure of the fitted model.

## Pipeline

`prepare_interdep_data()` currently runs the predictor workflow internally:

```r
validate_interdep_data()
infer_dyad_compositions()
center_predictors()
add_actor_partner_columns()      # model_type = "apim" or "apim_dim"
add_dyad_individual_columns()    # model_type = "dim" or "apim_dim"
```

The resolved centering choice is stored in `attr(data, "interdep")$centering`.
`centering = "auto"` resolves to `time_2l` when both `time` and `predictors`
are supplied, and to `none` otherwise.

## Centering

For each time-varying predictor `x`, `center_predictors()` creates:

```r
.i_x_cwp = x - person_mean(x)
.i_x_cbp = person_mean(x) - grand_mean(person_mean(x))
```

The grand mean is computed over person means, not over all observed rows. This
gives each person equal weight even when people have different numbers of
observed measurement occasions.

Missing values:

- missing raw values remain missing in `.i_x_cwp`
- person means ignore missing raw values
- if a person has no observed predictor values, both components are missing for
  that person

The metadata table is:

```r
attr(data, "interdep")$predictor_decompositions
```

with one row per predictor component.

## APIM Columns

`add_actor_partner_columns()` reads `predictor_decompositions` and creates APIM
columns.

For raw predictors:

```r
.i_x_raw_actor
.i_x_raw_partner
```

For `time_2l` predictors:

```r
.i_x_cwp_actor
.i_x_cwp_partner
.i_x_cbp_actor
.i_x_cbp_partner
```

Partner values are matched within dyad for cross-sectional data and within
dyad-time for longitudinal data. If the partner row or partner predictor value
is missing, the partner column is missing for that row.

The metadata table is:

```r
attr(data, "interdep")$apim_predictors
```

## DIM Columns

`add_dyad_individual_columns()` also reads `predictor_decompositions`, but it
does not depend on APIM actor/partner columns. DIM columns are computed directly
from grouped dyad means.

For within-person components, grouping is dyad-time:

```r
.i_x_cwp_dyad_mean
.i_x_cwp_dyad_deviation
```

For between-person components, grouping is dyad. The implementation first
reduces to one row per dyad-member so members are not weighted by the number of
observed days:

```r
.i_x_cbp_dyad_mean
.i_x_cbp_dyad_deviation
```

For raw cross-sectional predictors:

```r
.i_x_raw_dyad_mean
.i_x_raw_dyad_deviation
```

DIM requires complete dyad information for the relevant component. If only one
partner has an observed value for that component, the dyad mean and deviation
are set to missing for that dyad or dyad-time. This preserves APIM-DIM
equivalence.

The metadata table is:

```r
attr(data, "interdep")$dim_predictors
```

## Validation Rules

- `centering = "time_2l"` requires `time` and `predictors`.
- predictors used with `centering = "time_2l"` must be numeric.
- non-numeric predictors can be kept undecomposed with `centering = "none"`.
- user data may not contain package-owned `.i_` columns.
- longitudinal raw DIM is currently rejected because it mixes within-person and
  between-person information.

## Remaining v0.1.0 Work

- Review `add_dyad_individual_columns()` carefully before treating DIM as stable.
- Decide whether the print header should describe DIM column families.
- Add a focused DIM vignette once the DIM helper and metadata are final.
- Keep APIM and centering examples in the main vignette; avoid duplicating the
  APIM-DIM equivalence material there.
