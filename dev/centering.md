# Temporal Predictor Decomposition and Predictor Construction

This note records the current v0.1.0 design for predictor construction. The
core rule is that APIM and DIM share the same temporal predictor decomposition,
but use separate construction helpers.

## Current Scope

Implemented scope:

- `model_type = c("apim", "dim", "undirected_dsm", "none")`
- `temporal_predictor_decomposition = c("auto", "time_2l", "none")`
- two-level temporal predictor decomposition for ILD predictors
- raw APIM columns for cross-sectional or explicitly undecomposed predictors
- DIM dyad-mean and within-dyad-deviation columns
- DIM currently requires one exchangeable dyad composition
- `outcomes = NULL` in `prepare_interdep_data()` metadata, so DSM preparation
  can distinguish predictor-side and outcome-side transformations
- `model_type = "undirected_dsm"` for undirected dyadic-score model data
  preparation
- undirected DSM currently requires one exchangeable dyad composition
- central generated-column metadata via `interdep_generated_columns()`, with
  one row per temporal predictor, APIM, DIM, or undirected DSM column

Reserved for later:

- `temporal_predictor_decomposition = "time_3l"` for EMA/day/burst workflows
  with an explicit higher temporal unit
- grand-mean-only centering as a separate user option
- automatic inference of 3-level decomposition from the fitted model structure
- directed DSM variants
- centered or change-from-usual DSM outcome scores

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
add_undirected_dyadic_score_columns() # "undirected_dsm" in model_type
```

The resolved temporal predictor decomposition choice is stored in
`attr(data, "interdep")$temporal_predictor_decomposition`.
`temporal_predictor_decomposition = "auto"` resolves to `time_2l` when both `time` and
`predictors` are supplied, and to `none` otherwise.

For APIM and DIM, `predictors` are the only variables transformed. DSM uses a
separate `outcomes` argument rather than broadening `predictors` into a generic
variable list. This keeps APIM/DIM predictor construction clear while allowing
DSM outcome construction to use different rules.

`temporal_predictor_decomposition` controls predictor pre-decomposition over
time. DIM may still apply model-specific conventions after that step;
specifically, raw cross-sectional DIM dyad means are centered around the grand
mean of dyad means.

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

with one row per predictor component.

Generated `.i_*_cwp` and `.i_*_cbp` columns also appear in the normalized
generated-column table returned by `interdep_generated_columns()`. Raw
undecomposed predictor records are intentionally excluded from that table
because they are source columns, not package-generated columns.

## APIM Columns

`add_actor_partner_columns()` reads `temporal_predictor_decompositions` and creates APIM
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

`add_dyad_individual_columns()` also reads `temporal_predictor_decompositions`, but it
does not depend on APIM actor/partner columns. DIM columns are computed directly
from grouped dyad means.

For within-person components, the decomposition level is dyad-time:

```r
.i_x_cwp_dyad_mean
.i_x_cwp_within_dyad_deviation
```

For between-person components, the decomposition level is dyad. The
implementation first reduces to one row per dyad-member so members are not
weighted by the number of observed days:

```r
.i_x_cbp_dyad_mean
.i_x_cbp_within_dyad_deviation
```

For raw cross-sectional predictors:

```r
.i_x_raw_dyad_mean_gmc
.i_x_raw_within_dyad_deviation
```

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

with `decomposition_level` recording whether the component was decomposed within
dyad-time or within dyad.

## Dyadic-Score Model Preparation

For undirected dyadic-score model data preparation, use a separate model type:

```r
model_type = "undirected_dsm"
```

The implemented split is:

```r
center_predictors()
add_dyad_individual_columns()    # predictor-side dyad means/deviations
add_undirected_dyadic_score_columns() # outcome-side dyad scores
```

Predictor-side construction should reuse the current DIM path completely. For
ILD data, that means predictors are first decomposed into `.i_*_cwp` and
`.i_*_cbp`, then converted into dyad means and within-dyad deviations.

Outcome-side construction should be handled separately because the semantics are
different. For ILD dyadic-score outcomes, the default target is the raw
observation-level dyad score at each time point:

```r
.i_y_raw_dyad_mean
.i_y_raw_within_dyad_deviation
```

For cross-sectional data, these are computed within dyad. For ILD data, they
are computed within dyad-time. Outcomes are not within-/between-person centered
by default. Centered or change-from-usual dyadic-score outcomes can be
considered later as an explicit option, not as the default behavior.

Store DSM outcome metadata separately from predictor metadata, for example:

```r
attr(data, "interdep")$undirected_dsm_outcomes
```

DSM outcome columns also appear in `interdep_generated_columns()` with
`model_family = "undirected_dsm"` and `variable_role = "outcome"`.

## Validation Rules

- `temporal_predictor_decomposition = "time_2l"` requires `time` and `predictors`.
- predictors used with `temporal_predictor_decomposition = "time_2l"` must be numeric.
- non-numeric predictors can be kept undecomposed with
  `temporal_predictor_decomposition = "none"` only for model types that do not
  compute dyad means or within-dyad deviations, such as raw APIM.
- DIM and undirected DSM predictor construction require numeric predictors.
- Undirected DSM outcome construction requires numeric outcomes.
- user data may not contain package-owned `.i_` columns.
- longitudinal raw DIM or undirected DSM predictor construction is currently
  rejected because it mixes within-person and between-person information.
- `model_type = "undirected_dsm"` requires `outcomes`.
- DSM outcome columns use raw outcomes; `temporal_predictor_decomposition`
  applies only to predictors.
- `model_type = "dim"` and `model_type = "undirected_dsm"` currently require
  one exchangeable dyad composition.

## Remaining v0.1.0 Work

- Review `add_dyad_individual_columns()` carefully before treating DIM as stable.
- Keep the print header descriptions for DIM column families explicit but
  compact.
- Review `add_undirected_dyadic_score_columns()` before treating undirected DSM
  as stable.
- Treat `dim_predictors` and `undirected_dsm_outcomes` metadata names as stable
  for v0.1 unless the final DIM/DSM review finds a concrete problem.
- Keep `interdep_generated_columns()` internal for v0.1. It is the normalized
  table used by `print.interdep_data()` and documentation-facing summaries, not
  a public inspection API.
- Make `decomposition_level` in normalized generated-column metadata mean the
  computational unit consistently. `dyad` and `dyad_time` already have this
  meaning for DIM/DSM rows; temporal rows should not use `time_2l` there because
  that records the decomposition method rather than the unit.
- Keep `getting-started.Rmd` focused on data preparation and move fitted-model
  examples into model-specific vignettes.
- Keep APIM and temporal predictor decomposition model examples in APIM-focused
  vignettes; avoid duplicating APIM-DIM equivalence material there.
- Keep the DIM vignette focused on DIM construction and APIM-DIM equivalence.
- Add a separate DSM vignette or compact DSM data-preparation section only after
  the current `outcomes` and `model_type = "undirected_dsm"` API is reviewed.
