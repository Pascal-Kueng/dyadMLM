# Create safe suffixes for generated dyadMLM columns

Create safe suffixes for generated dyadMLM columns

## Usage

``` r
make_dyad_suffixes(
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
