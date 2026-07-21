# Print recovered exchangeable residual covariance

Print recovered exchangeable residual covariance

## Usage

``` r
# S3 method for class 'exchangeable_rescov'
print(x, representation = c("both", "varcov", "sdcor"), ...)
```

## Arguments

- x:

  An object returned by
  [`recover_exchangeable_covariance()`](https://pascal-kueng.github.io/dyadMLM/reference/recover_exchangeable_covariance.md).

- representation:

  Which representation to print: `"both"` (default), `"varcov"`, or
  `"sdcor"`.

- ...:

  Additional arguments passed to
  [`print()`](https://rdrr.io/r/base/print.html) when printing matrices.

## Value

`x`, invisibly.
