# Package index

## Main functions

- [`prepare_dyad_data()`](https://pascal-kueng.github.io/dyadMLM/reference/prepare_dyad_data.md)
  : Prepare dyadic data for multilevel models
- [`summary(`*`<dyadMLM_data>`*`)`](https://pascal-kueng.github.io/dyadMLM/reference/summary.dyadMLM_data.md)
  : Summarize prepared dyadic data
- [`compare_nested_models()`](https://pascal-kueng.github.io/dyadMLM/reference/compare_nested_models.md)
  : Compare nested glmmTMB models fitted to equivalent data
- [`recover_exchangeable_covariance()`](https://pascal-kueng.github.io/dyadMLM/reference/recover_exchangeable_covariance.md)
  : Recover member-level residual covariance from exchangeable
  random-effect blocks

## Predictive diagnostics

Experimental descriptive checks of how well a fitted model reproduces
partner dependence.

- [`simulate_dyad_responses()`](https://pascal-kueng.github.io/dyadMLM/reference/simulate_dyad_responses.md)
  **\[experimental\]** : Simulate response datasets for predictive
  checks
- [`check_partner_dependence()`](https://pascal-kueng.github.io/dyadMLM/reference/check_partner_dependence.md)
  **\[experimental\]** : Check whether a fitted model reproduces partner
  dependence
- [`plot(`*`<dyadMLM_partner_check>`*`)`](https://pascal-kueng.github.io/dyadMLM/reference/plot.dyadMLM_partner_check.md)
  **\[experimental\]** : Plot a saved partner-dependence check

## Example data

- [`dyads_cross`](https://pascal-kueng.github.io/dyadMLM/reference/dyads_cross.md)
  : Example Gaussian cross-sectional dyadic data
- [`dyads_ild`](https://pascal-kueng.github.io/dyadMLM/reference/dyads_ild.md)
  : Example Gaussian intensive longitudinal dyadic data
- [`dyads_nbinom_cross`](https://pascal-kueng.github.io/dyadMLM/reference/dyads_nbinom_cross.md)
  : Example negative-binomial cross-sectional dyadic data
- [`dyads_nbinom_ild`](https://pascal-kueng.github.io/dyadMLM/reference/dyads_nbinom_ild.md)
  : Example negative-binomial intensive longitudinal dyadic data
