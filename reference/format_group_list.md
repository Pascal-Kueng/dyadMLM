# Format group identifiers for validation messages

Converts a vector of dyad or group identifiers into a compact
comma-separated string for use in validation errors and warnings.

## Usage

``` r
format_group_list(groups, max = 10)
```

## Arguments

- groups:

  A vector of group identifiers.

- max:

  Maximum number of identifiers to show before truncating the list.

## Value

A single character string.
