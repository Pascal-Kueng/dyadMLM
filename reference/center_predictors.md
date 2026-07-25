# Center predictor variables for dyadic models

Adds centered predictor columns to a `dyadMLM_data` object. It currently
supports two-level temporal centering for intensive longitudinal
predictors: a within-person component and a between-person component.
The original predictor remains available as a raw component for
model-specific column construction. It can also add GMC source
components for numeric APIM predictors. For two-level temporal
centering, the between-person component is centered around the grand
mean of person means, not the grand mean of all observed rows. This
gives each person equal weight even when people have different numbers
of observed measurement occasions.

## Usage

``` r
center_predictors(data, add_apim_gmc_predictors = FALSE)
```

## Arguments

- data:

  A `dyadMLM_data` object returned by
  [`prepare_dyad_data()`](https://pascal-kueng.github.io/dyadMLM/reference/prepare_dyad_data.md).

- add_apim_gmc_predictors:

  Whether to add APIM GMC source components.

## Value

A `dyadMLM_data` object with centered predictor columns added and
updated predictor metadata.

## Details

The function uses the structural metadata stored by
[`prepare_dyad_data()`](https://pascal-kueng.github.io/dyadMLM/reference/prepare_dyad_data.md).
