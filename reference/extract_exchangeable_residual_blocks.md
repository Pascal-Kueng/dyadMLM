# Extract exchangeable random-effect blocks from a fitted model

Normalizes the random-effect coefficients and fitted covariance
parameters needed by
[`exchangeable_rescov()`](https://pascal-kueng.github.io/interdep/reference/exchangeable_rescov.md)
while keeping backend-specific work in two small adapters.

## Usage

``` r
extract_exchangeable_residual_blocks(model)
```

## Arguments

- model:

  A fitted model. Supported classes are `glmmTMB` and `brmsfit`.

## Value

A list containing the model `backend`, one normalized record per
random-effect block, and one grouping-factor ID per fitted row. Every
block record contains `group`, `coefficients`, `correlated`, `term`, and
an estimate/draw-by-coefficients covariance array.
