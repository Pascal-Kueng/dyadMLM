# Add dyadic-score model (undirected) predictor columns

Adds Dyad-Score Model (DSM) style dyad-mean and within-dyad-deviation
columns for the predictors recorded in an `interdep_data` object. For
currently supported undirected DSMs, the data must contain one
exchangeable dyad composition. This means distinguishable dyads and
multiple exchangeable compositions are not supported by DSM construction
until explicit role-contrast, composition-specific, or pooling support
is added. Predictors are constructed and treated identically to the DIM
method. The function reads
`attr(data, "interdep")$temporal_predictor_decompositions`.

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
predictor columns added.
