# Validate DIM compatibility

Checks whether a `dyadMLM_data` object can be used for the currently
supported undirected DIM construction. DIM requires one final
exchangeable dyad composition, which may result from pooling
exchangeable compositions. Distinguishable dyads are not currently
supported.

## Usage

``` r
validate_dim_compatibility(data)
```

## Arguments

- data:

  A `dyadMLM_data` object after composition inference.

## Value

Invisibly returns `data` when compatible.
