# Add actor and partner predictor columns

Adds APIM-style actor and partner columns for the predictors recorded in
an `dyadMLM_data` object. For uncentered predictors, this will create
actor and partner versions of the raw predictor. For centered intensive
longitudinal predictors, this will create actor and partner versions of
the raw predictor and each recorded predictor component, such as the
within-person and between-person components created by
[`center_predictors()`](https://pascal-kueng.github.io/dyadMLM/reference/center_predictors.md).
Selected lag predictors additionally create lag-1 raw and within-person
actor and partner columns.

## Usage

``` r
add_actor_partner_columns(data)
```

## Arguments

- data:

  A `dyadMLM_data` object returned by
  [`prepare_dyad_data()`](https://pascal-kueng.github.io/dyadMLM/reference/prepare_dyad_data.md).

## Value

A `dyadMLM_data` object with actor and partner predictor columns added
and APIM predictor metadata recorded.

## Details

The function will use the predictor decomposition metadata stored in
`attr(data, "dyadMLM")$temporal_decompositions`, so downstream code does
not need to infer generated predictor columns from their names. It
stores the constructed APIM columns in
`attr(data, "dyadMLM")$apim_predictors`.
