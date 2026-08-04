# Collect dyadMLM-generated columns

Returns a normalized, one-row-per-column view of the generated columns
recorded in a `dyadMLM` attribute. Shared semantics and display text are
supplied by `generated_column_spec_lookup()`.

## Usage

``` r
dyad_generated_columns(meta)
```

## Arguments

- meta:

  The `dyadMLM` metadata attribute from a `dyadMLM_data` object.

## Value

A tibble with one row per generated column. The `lag` column is `0` for
contemporaneous columns and `1` for lag-1 columns.
