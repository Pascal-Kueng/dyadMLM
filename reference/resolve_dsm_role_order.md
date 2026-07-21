# Resolve the DSM role order

Checks the relationship between `model_types`, `role`, and
`dsm_role_order`, validates the requested role order, and returns its
stored representation.

## Usage

``` r
resolve_dsm_role_order(dsm_role_order, model_types, has_role)
```

## Arguments

- dsm_role_order:

  The requested DSM role order.

- model_types:

  The normalized model types.

- has_role:

  Whether a role column was supplied.

## Value

The validated, unnamed role order, or `NULL`.
