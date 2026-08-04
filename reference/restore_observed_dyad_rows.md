# Restore rows observed in the supplied data

Removes rows added by
[`temporarily_complete_dyad_occasions()`](https://pascal-kueng.github.io/dyadMLM/reference/temporarily_complete_dyad_occasions.md)
and restores the original row order. Rows removed by an explicit
preparation option, such as composition filtering, remain removed.

## Usage

``` r
restore_observed_dyad_rows(data, original_observed_row_keys)
```

## Arguments

- data:

  A temporarily completed `dyadMLM_data` object after model-ready
  columns have been constructed.

- original_observed_row_keys:

  Original row keys returned by
  [`temporarily_complete_dyad_occasions()`](https://pascal-kueng.github.io/dyadMLM/reference/temporarily_complete_dyad_occasions.md).

## Value

A `dyadMLM_data` object containing only originally observed rows.
