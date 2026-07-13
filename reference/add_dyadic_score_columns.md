# Add dyadic-score model predictor columns and contrast

Adds Dyadic Score Model (DSM) dyad-mean and signed dyad-difference
columns for the predictors recorded in an `interdep_data` object,
together with a DSM role contrast coded `+0.5` and `-0.5`. DSM
differences follow the role order recorded in
`attr(data, "interdep")$dsm_role_order`. The supported DSM structure
contains one distinguishable dyad composition; exchangeable dyads and
multiple compositions are not supported.

## Usage

``` r
add_dyadic_score_columns(data)
```

## Arguments

- data:

  An `interdep_data` object returned by
  [`prepare_interdep_data()`](https://pascal-kueng.github.io/interdep/reference/prepare_interdep_data.md).

## Value

An `interdep_data` object with dyad-mean and signed dyad-difference
predictor columns and a DSM role contrast added.

## Details

For ILD predictors, raw and within-person scores are computed within
dyad-time and between-person scores within dyad. Raw dyad means are
grand-mean centered. Both partners' predictor values are required for
each score pair.

Constructed predictor columns are recorded in
`attr(data, "interdep")$dsm_predictors`, and the contrast column name is
recorded in `attr(data, "interdep")$dsm_role_contrast_column`.
