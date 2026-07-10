# Create safe suffixes for generated interdep columns

Create safe suffixes for generated interdep columns

## Usage

``` r
make_interdep_suffixes(
  labels,
  label_type = "labels",
  rename_hint = "role or composition labels"
)
```

## Arguments

- labels:

  Labels that will be used to build generated column names.

## Value

A named character vector. Names are the original labels; values are
sanitized column-name suffixes.
