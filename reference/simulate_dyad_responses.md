# Simulate response datasets for predictive checks

**\[experimental\]** Generates new response datasets for the same
observations and predictors. Reuse them with
[`check_partner_dependence()`](https://pascal-kueng.github.io/dyadMLM/reference/check_partner_dependence.md)
to check whether a fitted model reproduces features of the observed
data. For a complete example see
[`check_partner_dependence()`](https://pascal-kueng.github.io/dyadMLM/reference/check_partner_dependence.md).

## Usage

``` r
simulate_dyad_responses(model, nsim = 1000, seed = NULL)
```

## Arguments

- model:

  A fitted `glmmTMB` model.

- nsim:

  Number of complete response datasets to simulate. Default: 1000.

- seed:

  Optional seed for reproducible simulations, interpreted as an integer
  (see [`set.seed()`](https://rdrr.io/r/base/Random.html)). When
  supplied, the random-number state is restored after the function
  returns, or when it stops after an error.

## Value

A `dyadMLM_response_simulations` object for use with
[`check_partner_dependence()`](https://pascal-kueng.github.io/dyadMLM/reference/check_partner_dependence.md).

The result keeps all components in fitted-row order (after missing-data
exclusions):

- `simulated_responses`: a matrix with `nsim` rows and one column per
  fitted observation. Each row is a complete simulated dataset.

- `observed_response` and `predicted_response`: numeric vectors with one
  value per fitted observation.

- `model_frame`: the fitted model frame (variables in the model formulas
  only), in the same row order.

The `dyadMLM` attribute records the model and simulation settings,
including the seed.

## Supported models

Supports unweighted `glmmTMB` models with the following families:

- [`gaussian()`](https://rdrr.io/r/stats/family.html)

- [`poisson()`](https://rdrr.io/r/stats/family.html),
  [`glmmTMB::compois()`](https://rdrr.io/pkg/glmmTMB/man/nbinom2.html),
  [`glmmTMB::genpois()`](https://rdrr.io/pkg/glmmTMB/man/nbinom2.html),
  [`glmmTMB::bell()`](https://rdrr.io/pkg/glmmTMB/man/nbinom2.html)

- [`glmmTMB::nbinom1()`](https://rdrr.io/pkg/glmmTMB/man/nbinom2.html),
  [`glmmTMB::nbinom2()`](https://rdrr.io/pkg/glmmTMB/man/nbinom2.html),
  [`glmmTMB::nbinom12()`](https://rdrr.io/pkg/glmmTMB/man/nbinom2.html)

- [`glmmTMB::truncated_poisson()`](https://rdrr.io/pkg/glmmTMB/man/nbinom2.html),
  [`glmmTMB::truncated_nbinom1()`](https://rdrr.io/pkg/glmmTMB/man/nbinom2.html),
  [`glmmTMB::truncated_nbinom2()`](https://rdrr.io/pkg/glmmTMB/man/nbinom2.html),
  [`glmmTMB::truncated_compois()`](https://rdrr.io/pkg/glmmTMB/man/nbinom2.html),
  [`glmmTMB::truncated_genpois()`](https://rdrr.io/pkg/glmmTMB/man/nbinom2.html)

- [`glmmTMB::tweedie()`](https://rdrr.io/pkg/glmmTMB/man/nbinom2.html)

- [`Gamma()`](https://rdrr.io/r/stats/family.html),
  [`glmmTMB::ziGamma()`](https://rdrr.io/pkg/glmmTMB/man/nbinom2.html)

- [`glmmTMB::beta_family()`](https://rdrr.io/pkg/glmmTMB/man/nbinom2.html)

- [`glmmTMB::lognormal()`](https://rdrr.io/pkg/glmmTMB/man/nbinom2.html)

- [`glmmTMB::skewnormal()`](https://rdrr.io/pkg/glmmTMB/man/nbinom2.html)

- [`glmmTMB::t_family()`](https://rdrr.io/pkg/glmmTMB/man/nbinom2.html)
  with more than two degrees of freedom

- `glmmTMB::ordinal()` (currently only available in the development
  version of `glmmTMB`)

Zero-inflated and hurdle versions are supported where available. Checks
describe the combined response, including zeros, rather than each model
component separately. Good agreement does not establish that the zero
and response components each fit well.

Ordinal checks use category scores `1, 2, ..., K` in their fitted order,
matching [glmmTMB's
predictions](https://rdrr.io/pkg/glmmTMB/man/nbinom2.html). The plots
compare variation and partner correlation in these scores. The scores do
not measure distances on an underlying continuous scale.

The model's fitted link is used for prediction and simulation.
Predictions and simulated responses must be finite.

[`check_partner_dependence()`](https://pascal-kueng.github.io/dyadMLM/reference/check_partner_dependence.md)
currently requires cross-sectional dyads.

## Technical details

Each simulation draws new random effects and then new responses from the
fitted model. Random effects within each block are drawn together using
their fitted variances and correlations. This also applies to random
effects in the zero-inflation and dispersion models, if present.

Fitted parameters and predictors, including any lagged responses, stay
fixed. The model is not refitted, and uncertainty in parameter estimates
is not included. This is a *plug-in predictive reference*. If dyads are
the only grouping factor, the simulations represent hypothetical new
dyads under the same study design.

`predicted_response` contains predicted mean responses with random
effects in the conditional and zero-inflation models set to zero. For
zero-inflated and hurdle models, this is the conditional response mean
multiplied by one minus the zero-component probability (Brooks et al.,
2017, Appendix A;
[doi:10.32614/RJ-2017-066](https://doi.org/10.32614/RJ-2017-066) ).

By default, later checks subtract these same predictions from observed
and simulated responses. Both random effects and observation-level noise
still contribute to response variance. With nonlinear links, setting
random effects to zero generally differs from averaging predictions over
them.
