# Center predictor variables for dyadic models

Adds centered predictor columns to an `interdep_data` object. It
currently supports two-level temporal centering for intensive
longitudinal predictors: a within-person component and a between-person
component. For two-level temporal centering, the between-person
component is centered around the grand mean of person means, not the
grand mean of all observed rows. This gives each person equal weight
even when people have different numbers of observed measurement
occasions.

## Usage

``` r
center_predictors(data)
```

## Arguments

- data:

  An `interdep_data` object returned by
  [`prepare_interdep_data()`](https://pascal-kueng.github.io/interdep/reference/prepare_interdep_data.md).

## Value

An `interdep_data` object with centered predictor columns added and
updated predictor metadata.

## Details

The function uses the structural metadata stored by
[`prepare_interdep_data()`](https://pascal-kueng.github.io/interdep/reference/prepare_interdep_data.md).
