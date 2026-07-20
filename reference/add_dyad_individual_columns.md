# Add dyad-individual predictor columns

Adds Dyad-Individual Model (DIM) style dyad-mean and within-dyad
member-deviation columns for the predictors recorded in a `dyadMLM_data`
object. For currently supported DIMs, the data must contain one
exchangeable dyad composition. This means distinguishable dyads and
multiple exchangeable compositions are not supported by DIM construction
until explicit role-contrast, composition-specific, or pooling support
is added. For intensive longitudinal predictors decomposed by
[`center_predictors()`](https://pascal-kueng.github.io/dyadMLM/reference/center_predictors.md),
raw predictors and within-person components are decomposed within each
dyad-time occasion, while between-person components are decomposed once
within each dyad. For raw predictors, the dyad-mean column is centered
around the grand mean of dyad means, or dyad-occasion means in
longitudinal data, while the within-dyad member-deviation column is the
person's deviation from the uncentered dyad mean. Selected lag
predictors additionally create lag-1 raw and within-person dyad-mean and
within-dyad member-deviation columns.

## Usage

``` r
add_dyad_individual_columns(data)
```

## Arguments

- data:

  A `dyadMLM_data` object returned by
  [`prepare_dyad_data()`](https://pascal-kueng.github.io/dyadMLM/reference/prepare_dyad_data.md).

## Value

A `dyadMLM_data` object with dyad-mean and within-dyad member-deviation
predictor columns added and DIM predictor metadata recorded.

## Details

The function reads
`attr(data, "dyadMLM")$temporal_predictor_decompositions` and stores the
constructed DIM columns in `attr(data, "dyadMLM")$dim_predictors`.
