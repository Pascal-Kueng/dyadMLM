# Infer dyad compositions

Builds a dyad-level summary of role compositions from a validated
`interdep_data` object.

## Usage

``` r
infer_dyad_compositions(
  data,
  seed = NULL,
  set_compositions_exchangeable = NULL,
  composition_pooling = NULL
)
```

## Arguments

- data:

  An `interdep_data` object returned by
  [`validate_interdep_data()`](https://pascal-kueng.github.io/interdep/reference/validate_interdep_data.md).

- seed:

  Optional seed for random `.i_diff_*` sign assignment in exchangeable
  dyads. If `NULL`, the current R session's RNG state is used.

- set_compositions_exchangeable:

  Optional dyad compositions to treat as exchangeable for analysis.

- composition_pooling:

  Optional named list that pools exchangeable dyad compositions into
  user-named final composition labels.

## Value

An `interdep_data` object with added `.i_composition` and
`.i_composition_role` factor columns, `.i_is_*` numeric indicator
columns, composition-specific `.i_diff_*` columns for exchangeable
dyads, and dyad composition metadata.
