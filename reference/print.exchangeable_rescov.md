# Print recovered exchangeable residual covariance

Print recovered exchangeable residual covariance

## Usage

``` r
# S3 method for class 'exchangeable_rescov'
print(x, what = c("both", "varcov", "sdcor"), ...)
```

## Arguments

- x:

  An object returned by
  [`exchangeable_rescov()`](https://pascal-kueng.github.io/interdep/reference/exchangeable_rescov.md).

- what:

  Which representation to print: `"both"` (default), `"varcov"`, or
  `"sdcor"`.

- ...:

  Additional arguments passed to
  [`print()`](https://rdrr.io/r/base/print.html) when printing matrices.

## Value

`x`, invisibly.
