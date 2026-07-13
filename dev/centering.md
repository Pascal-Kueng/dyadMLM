# Temporal Predictor Decomposition and Predictor Construction

This note records the current v0.1.0 design for predictor construction. The
core rule is that APIM, DIM, and DSM share the same temporal predictor
decomposition, but expose model-specific predictor columns.

## Current Scope

Implemented scope:

- `model_type = c("apim", "dim", "dsm", "none")`
- `temporal_predictor_decomposition = c("auto", "time_2l", "none")`
- two-level temporal predictor decomposition for ILD predictors
- raw and temporally decomposed model-ready columns for APIM, DIM, and DSM
- DIM dyad-mean and within-dyad-deviation columns
- DIM currently requires one exchangeable dyad composition
- `model_type = "dsm"` for directional dyadic-score model data preparation
- DSM currently requires one distinguishable dyad composition
- central generated-column metadata via `interdep_generated_columns()`, with
  one row per generated temporal, APIM, DIM, or DSM column

Reserved for later:

- `temporal_predictor_decomposition = "time_3l"` for EMA/day/burst workflows
  with an explicit higher temporal unit
- grand-mean-only centering as a separate user option
- automatic inference of 3-level decomposition from the fitted model structure
- multiple-composition DSM support
- explicit multivariate or SEM-oriented dyad-score preparation

`time_2l` refers to the predictor decomposition over time, not to the full
random-effects structure of the fitted model.

## Pipeline

`prepare_interdep_data()` currently runs the predictor workflow internally:

```r
validate_interdep_data()
infer_dyad_compositions()
center_predictors()
add_actor_partner_columns()      # "apim" in model_type
add_dyad_individual_columns()    # "dim" in model_type
add_dyadic_score_columns()       # "dsm" in model_type
```

The resolved temporal predictor decomposition choice is stored in
`attr(data, "interdep")$temporal_predictor_decomposition`.
`temporal_predictor_decomposition = "auto"` resolves to `time_2l` when both `time` and
`predictors` are supplied, and to `none` otherwise.

Only `predictors` are transformed. Outcomes remain unchanged and are selected
later in the model formula.

`temporal_predictor_decomposition` controls predictor pre-decomposition over
time. DIM and DSM apply dyadic predictor-score construction afterward;
raw dyad means are centered around the grand mean of dyad means or observed
dyad-occasion means.

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
attr(data, "interdep")$temporal_predictor_decompositions
```

with one row for the raw predictor and one row per constructed temporal
component.

Generated `.i_*_cwp` and `.i_*_cbp` columns also appear in the normalized
generated-column table returned by `interdep_generated_columns()`. Raw source
records are excluded from the temporal part of that table because they are not
package-generated columns. Their model-specific APIM, DIM, or DSM columns are
included.

## APIM Columns

`add_actor_partner_columns()` reads `temporal_predictor_decompositions` and creates APIM
columns.

For raw predictors:

```r
.i_x_actor
.i_x_partner
```

For `time_2l` predictors, the raw columns above are retained alongside:

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

`add_dyad_individual_columns()` also reads `temporal_predictor_decompositions`, but it
does not depend on APIM actor/partner columns. DIM columns are computed directly
from grouped dyad means.

For within-person components, the decomposition level is dyad-time:

```r
.i_x_cwp_dyad_mean
.i_x_cwp_within_dyad_dev
```

For between-person components, the decomposition level is dyad. The
implementation first reduces to one row per dyad-member so members are not
weighted by the number of observed days:

```r
.i_x_cbp_dyad_mean
.i_x_cbp_within_dyad_dev
```

For raw predictors:

```r
.i_x_dyad_mean_gmc
.i_x_within_dyad_dev
```

Raw longitudinal predictors are decomposed within dyad-time. Raw
cross-sectional predictors are decomposed within dyad. Their dyad means are
grand-mean centered in both cases.

DIM requires complete dyad information for the relevant component. If only one
partner has an observed value for that component, the dyad mean and deviation
are set to missing for that dyad or dyad-time. This preserves APIM-DIM
equivalence.

The current DIM implementation requires one exchangeable dyad composition.
Distinguishable dyads and multiple exchangeable compositions should be rejected
until role-contrast, composition-specific, or pooling support is explicit.

The metadata table is:

```r
attr(data, "interdep")$dim_predictors
```

with `dyad_decomposition_level` recording whether the component was decomposed
within dyad-time or within dyad.

## Dyadic-Score Model Preparation

Directional DSM preparation uses:

```r
model_type = "dsm"
dsm_role_order = c("female", "male")
```

DSM requires exactly one distinguishable composition. The declared role order
defines every difference as the first role minus the second and creates
`.i_dsm_role_contrast` with `+0.5/-0.5` coding.

DIM and DSM share internal dyad-mean and member-deviation calculations. Their
public columns then diverge:

```r
# Shared mean
.i_x_dyad_mean_gmc

# DIM
.i_x_within_dyad_dev

# DSM
.i_x_within_dyad_diff
.i_dsm_role_contrast
```

For ILD data, DSM creates dyad means and full directional differences for the
raw predictor and separately for `.i_*_cwp` and `.i_*_cbp`. Raw and CWP scores
are constructed within dyad-time, while CBP scores are constructed within dyad.

Outcome scores are not materialized for the MLM-focused API. Outcomes remain
member-level variables selected in the fitted-model formula.

## Validation Rules

- `temporal_predictor_decomposition = "time_2l"` requires `time` and `predictors`.
- predictors used with `temporal_predictor_decomposition = "time_2l"` must be numeric.
- non-numeric predictors can be kept undecomposed with
  `temporal_predictor_decomposition = "none"` only for model types that do not
  compute dyad means or within-dyad deviations, such as raw APIM.
- DIM and DSM predictor construction require numeric predictors.
- user data may not contain package-owned `.i_` columns.
- longitudinal raw DIM and DSM predictor construction is available with
  `temporal_predictor_decomposition = "none"`; `time_2l` returns raw scores
  alongside CWP and CBP scores.
- `temporal_predictor_decomposition` applies only to predictors.
- `model_type = "dim"` requires one exchangeable dyad composition.
- `model_type = "dsm"` requires one distinguishable dyad composition and an
  explicit `dsm_role_order`.
- DIM and DSM cannot be requested in the same preparation call.

## Remaining v0.1.0 Work

- Keep the print header descriptions for DIM and DSM column families explicit but
  compact.
- Treat `dim_predictors` and `dsm_predictors` metadata as stable for v0.1 unless
  review finds a concrete problem.
- Keep `interdep_generated_columns()` internal for v0.1. It is the normalized
  table used by `print.interdep_data()` and documentation-facing summaries, not
  a public inspection API.
- Keep normalized generated-column interpretation focused on
  `temporal_decomposition`, `dyadic_decomposition`, and `column_centering`.
  Source metadata can still record implementation details such as whether a DIM
  or DSM component was computed within dyad or dyad-time.
- Keep `getting-started.Rmd` focused on data preparation and move fitted-model
  examples into model-specific vignettes.
- Keep APIM and temporal predictor decomposition model examples in APIM-focused
  vignettes; avoid duplicating APIM-DIM equivalence material there.
- Keep the DIM vignette focused on DIM construction and APIM-DIM equivalence.
- Keep the DSM vignette aligned with the implemented directional score columns
  and exact long-format interaction model.
- Analysis-composition controls run before DIM/DSM compatibility checks.
  The implemented order is `include_compositions`, then
  `set_exchangeable_compositions`, then `pool_compositions`. DIM continues to
  require one final exchangeable composition, whereas DSM requires one final
  distinguishable composition matching `dsm_role_order`.
