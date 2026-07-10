# Add dyadic-score model (undirected) predictor and outcome columns

Adds Dyad-Score Model (DSM) style dyad-mean and within-dyad-deviation
columns for the predictors and outcomes recorded in an `interdep_data`
object. For currently supported undirected DSMs, the data must contain
one exchangeable dyad composition. This means distinguishable dyads and
multiple exchangeable compositions are not supported by DSM construction
until explicit role-contrast, composition-specific, or pooling support
is added. Predictors are constructed and treated identically to the DIM
method. Outcomes are not temporally decomposed or grand-mean centered.
Instead, a raw dyad mean and row-level within-dyad deviation is created
at each time-point.

## Usage

``` r
add_undirected_dyadic_score_columns(data)
```

## Arguments

- data:

  An `interdep_data` object returned by
  [`prepare_interdep_data()`](https://pascal-kueng.github.io/interdep/reference/prepare_interdep_data.md).

## Value

An `interdep_data` object with dyad-mean and within-dyad-deviation
predictor and outcome columns added and DSM outcome metadata recorded.

## Details

The function reads
`attr(data, "interdep")$temporal_predictor_decompositions` and stores
the constructed outcome columns in
`attr(data, "interdep")$undirected_dsm_outcomes`.
