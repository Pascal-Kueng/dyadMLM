# Add lagged temporal predictor columns

Adds eligible lag-1 raw, within-person, and APIM GMC source columns.
Values are matched at exactly `time - 1`; gaps are not bridged. Stable
between-person components are not lagged.

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
