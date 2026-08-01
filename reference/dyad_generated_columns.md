# Collect dyadMLM-generated columns

Creates a normalized, one-row-per-column view over temporal predictor,
APIM, DIM, and DSM columns stored in a `dyadMLM` attribute. This is a
derived lookup table; the model-specific metadata tables remain the
source records.

## Usage

``` r
dyad_generated_columns(meta)
```

## Arguments

- meta:

  The `dyadMLM` metadata attribute from a `dyadMLM_data` object.

## Value

A tibble with one row per generated temporal predictor, APIM, DIM, or
DSM column. The `lag` column is `0` for contemporaneous columns and `1`
for lag-1 columns.
