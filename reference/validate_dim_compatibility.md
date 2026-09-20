# Validate DIM compatibility

Checks whether a `dyadMLM_data` object can be used for the currently
supported undirected DIM construction. These models currently support
only data with exactly one exchangeable dyad composition. DIM requires
one final exchangeable dyad composition, which may result from pooling
exchangeable compositions. Distinguishable dyad compositions are
rejected until explicit role-contrast support is added.

## Usage

``` r
validate_dim_compatibility(data)
```

## Arguments

- data:

  A `dyadMLM_data` object after composition inference.

## Value

Invisibly returns `data` when compatible.
