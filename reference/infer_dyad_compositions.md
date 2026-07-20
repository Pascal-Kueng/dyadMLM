# Infer dyad compositions

Builds a dyad-level summary of role compositions from a validated
`dyadMLM_data` object.

## Usage

``` r
infer_dyad_compositions(
  data,
  seed = NULL,
  include_compositions = NULL,
  set_exchangeable_compositions = NULL,
  pool_compositions = NULL
)
```

## Arguments

- data:

  A `dyadMLM_data` object returned by
  [`validate_dyad_data()`](https://pascal-kueng.github.io/dyadMLM/reference/validate_dyad_data.md).

- seed:

  Optional seed for random `.dy_diff_*` sign assignment in exchangeable
  dyads. If `NULL`, the current R session's RNG state is used.

- include_compositions:

  Optional observed dyad compositions to keep before exchangeability
  overrides and pooling.

- set_exchangeable_compositions:

  Optional dyad compositions to treat as exchangeable for analysis.

- pool_compositions:

  Optional named list that pools exchangeable dyad compositions into
  user-named final composition labels. Each pool must resolve to at
  least two distinct observed compositions.

## Value

A `dyadMLM_data` object with added `.dy_composition` and
`.dy_composition_role` factor columns, `.dy_is_*` numeric indicator
columns, composition-specific numeric `.dy_diff_*` contrast columns
coded `-1` and `1` for the two members of matching exchangeable dyads
and `0` otherwise, and dyad composition metadata.
