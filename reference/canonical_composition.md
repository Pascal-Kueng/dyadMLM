# Create a canonical dyad composition label

Sorts role labels before pasting them so composition labels do not
depend on row order.

## Usage

``` r
canonical_composition(roles, sep = interdep_composition_sep)

composition_role_label(composition, role, sep = interdep_composition_role_sep)
```

## Arguments

- roles:

  A vector of role labels.

- sep:

  Separator used between label components.

- composition:

  A composition label.

- role:

  A row-level role label.

## Value

A single composition label.
