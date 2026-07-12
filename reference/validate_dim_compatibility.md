# Validate DIM compatibility

Checks whether an `interdep_data` object can be used for the currently
supported undirected DIM construction. These models currently support
only data with exactly one exchangeable dyad composition.
Distinguishable or multiple exchangeable compositions are rejected until
explicit role-contrast, composition-specific, or pooling support is
added.

## Usage

``` r
validate_dim_compatibility(data)
```

## Arguments

- data:

  An `interdep_data` object after composition inference.

## Value

Invisibly returns `data` when compatible.
