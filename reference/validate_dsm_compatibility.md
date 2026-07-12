# Validate DSM compatibility

Checks whether prepared data contain the single distinguishable dyad
composition required by the DSM and whether its observed roles match the
declared directional role order.

## Usage

``` r
validate_dsm_compatibility(data)
```

## Arguments

- data:

  An `interdep_data` object after composition inference.

## Value

Invisibly returns `data` when compatible.
