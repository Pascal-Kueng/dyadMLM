# Print a summary of the partner-dependence predictive check object

Shows each observed statistic with the middle 95% of its simulated
values and marks observed values outside that range. Use
[`plot.dyadMLM_partner_check()`](https://pascal-kueng.github.io/dyadMLM/reference/plot.dyadMLM_partner_check.md)
to view the comparisons.

## Usage

``` r
# S3 method for class 'dyadMLM_partner_check'
print(x, digits = 3L, ...)
```

## Arguments

- x:

  An object returned by
  [`check_partner_dependence()`](https://pascal-kueng.github.io/dyadMLM/reference/check_partner_dependence.md).

- digits:

  Number of decimal places to print.

- ...:

  Not used.

## Value

`x`, invisibly.
