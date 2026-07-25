# dyadMLM: Tools for Dyadic Multilevel Models

`dyadMLM` validates and prepares cross-sectional and intensive
longitudinal dyadic data for multilevel modeling. It creates model-ready
variables for APIMs, DIMs, and DSMs and provides supporting
post-estimation tools.

## Main functions

- [`prepare_dyad_data()`](https://pascal-kueng.github.io/dyadMLM/reference/prepare_dyad_data.md)
  validates long-format dyadic data and creates model-ready variables.

- [`compare_nested_glmmTMB_models()`](https://pascal-kueng.github.io/dyadMLM/reference/compare_nested_glmmTMB_models.md)
  compares compatible nested `glmmTMB` models fitted to equivalent data.

- [`recover_exchangeable_covariance()`](https://pascal-kueng.github.io/dyadMLM/reference/recover_exchangeable_covariance.md)
  converts exchangeable shared/difference covariance structures to
  member-level quantities.

## Example data

See
[dyads_cross](https://pascal-kueng.github.io/dyadMLM/reference/dyads_cross.md)
and
[dyads_ild](https://pascal-kueng.github.io/dyadMLM/reference/dyads_ild.md)
for Gaussian examples, and
[dyads_nbinom_cross](https://pascal-kueng.github.io/dyadMLM/reference/dyads_nbinom_cross.md)
and
[dyads_nbinom_ild](https://pascal-kueng.github.io/dyadMLM/reference/dyads_nbinom_ild.md)
for negative-binomial examples.

## Getting started

See
[`vignette("getting-started", package = "dyadMLM")`](https://pascal-kueng.github.io/dyadMLM/articles/getting-started.md)
for an overview. The APIM, DIM, and DSM vignettes provide model-specific
examples.

## See also

Useful links:

- <https://pascal-kueng.github.io/dyadMLM/>

- <https://github.com/Pascal-Kueng/dyadMLM>

- Report bugs at <https://github.com/Pascal-Kueng/dyadMLM/issues>

## Author

**Maintainer**: Pascal Küng <kueng.pascal@gmail.com>
([ORCID](https://orcid.org/0000-0001-7346-9414)) \[copyright holder\]

Authors:

- Pascal Küng <kueng.pascal@gmail.com>
  ([ORCID](https://orcid.org/0000-0001-7346-9414)) \[copyright holder\]
