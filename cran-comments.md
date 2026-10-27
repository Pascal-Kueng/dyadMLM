## License change

The package license has changed from MIT + file LICENSE to GPL-3.

## Test environments

* Fedora Linux 44, R 4.6.1 (2026-06-24), `R CMD check --as-cran`
* GitHub Actions: macOS R-release; Windows R-release; Ubuntu R-oldrel,
  R-release, and R-devel
* win-builder: R-release (R 4.6.1)

## R CMD check results

0 errors | 0 warnings | 0 notes

## Reverse dependencies

There are currently no reverse dependencies.

## Release summary

This release adds experimental model checks: predictive checks of response
variances and partner correlations, also for repeated occasions, and checks of
residuals and response distributions based on simulated responses. It also
fixes cases in which data preparation or covariance recovery gave wrong results
without an error. dyadMLM now requires dplyr 1.1.1 or later.
