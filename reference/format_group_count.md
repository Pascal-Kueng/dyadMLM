# Format counted group identifiers for validation messages

Converts a vector of dyad or group identifiers into text that includes
both the number of groups and a compact list of their identifiers.

## Usage

``` r
format_group_count(groups, singular = "dyad", plural = "dyads", max = 10)
```

## Arguments

- groups:

  A vector of group identifiers.

- singular:

  Singular label for one group.

- plural:

  Plural label for multiple groups.

- max:

  Maximum number of identifiers to show before truncating the list.

## Value

A single character string.
