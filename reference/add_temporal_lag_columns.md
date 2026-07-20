# Add lagged temporal predictor columns

Adds lag-1 raw and within-person columns for predictors selected through
`lag_predictors`. Values are matched at exactly `time - 1`, so
construction does not depend on row order and does not bridge gaps in
the measurement index. Stable between-person components are not lagged.

## Usage

``` r
add_temporal_lag_columns(data)
```

## Arguments

- data:

  A `dyadMLM_data` object returned by
  [`prepare_dyad_data()`](https://pascal-kueng.github.io/dyadMLM/reference/prepare_dyad_data.md).

## Value

A `dyadMLM_data` object with lagged temporal predictor columns and
updated predictor metadata.
