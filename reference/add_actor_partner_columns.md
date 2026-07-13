# Add actor and partner predictor columns

Adds APIM-style actor and partner columns for the predictors recorded in
an `interdep_data` object. For uncentered predictors, this will create
actor and partner versions of the raw predictor. For centered intensive
longitudinal predictors, this will create actor and partner versions of
the raw predictor and each recorded predictor component, such as the
within-person and between-person components created by
[`center_predictors()`](https://pascal-kueng.github.io/interdep/reference/center_predictors.md).

## Usage

``` r
add_actor_partner_columns(data)
```

## Arguments

- data:

  An `interdep_data` object returned by
  [`prepare_interdep_data()`](https://pascal-kueng.github.io/interdep/reference/prepare_interdep_data.md).

## Value

An `interdep_data` object with actor and partner predictor columns added
and APIM predictor metadata recorded.

## Details

The function will use the predictor decomposition metadata stored in
`attr(data, "interdep")$temporal_predictor_decompositions`, so
downstream code does not need to infer generated predictor columns from
their names. It stores the constructed APIM columns in
`attr(data, "interdep")$apim_predictors`.
