## Test environments

* Fedora Linux 44, R 4.6.1 (2026-06-24), `R CMD check --as-cran`
* GitHub Actions: macOS R-release; Windows R-release; Ubuntu R-oldrel,
  R-release, and R-devel

## R CMD check results

0 errors | 0 warnings | 0 notes

## Release summary

This is an early API-stabilization update following version 0.1.0. It fixes
longitudinal partner and lagged-column construction when dyad-occasion rows are
missing, strengthens input validation, and completes the documented Gaussian
APIM, DIM, and DSM preparation workflows.

The release also contains intentionally breaking names while the package is
new. The changes and direct migration paths are listed in `NEWS.md`; deprecated
wrappers are not included.
