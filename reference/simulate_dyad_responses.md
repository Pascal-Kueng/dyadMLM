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

- `model_frame`: the data frame used for fitting, in the same row order.

The `dyadMLM` attribute records the model and simulation settings,
including the seed.

## Supported models

Currently supports unweighted `glmmTMB` models without zero inflation
for the following families:

- [`gaussian()`](https://rdrr.io/r/stats/family.html)

- [`poisson()`](https://rdrr.io/r/stats/family.html)

- [`glmmTMB::nbinom1()`](https://rdrr.io/pkg/glmmTMB/man/nbinom2.html)

- [`glmmTMB::nbinom2()`](https://rdrr.io/pkg/glmmTMB/man/nbinom2.html)

- [`glmmTMB::tweedie()`](https://rdrr.io/pkg/glmmTMB/man/nbinom2.html)

- [`Gamma()`](https://rdrr.io/r/stats/family.html)

- [`glmmTMB::beta_family()`](https://rdrr.io/pkg/glmmTMB/man/nbinom2.html)

The model's fitted link is used for prediction and simulation.
Predictions and simulated responses must be finite.

[`check_partner_dependence()`](https://pascal-kueng.github.io/dyadMLM/reference/check_partner_dependence.md)
currently requires cross-sectional dyads.

## Technical details

Each simulation draws new random effects and then new responses from the
fitted model. Random effects within each block are drawn together using
their fitted variances and correlations. This also applies to random
effects in the dispersion model, if present.

Fitted parameters and predictors stay fixed. The model is not refitted,
and uncertainty in parameter estimates is not included. This is a
*plug-in predictive reference*. If dyads are the only grouping factor,
the simulations represent hypothetical new dyads under the same study
design.

`predicted_response` contains predicted mean responses with random
effects in the conditional model set to zero. By default, later checks
subtract these same predictions from observed and simulated responses.
Both random effects and observation-level noise still contribute to
response variance. With nonlinear links, setting random effects to zero
generally differs from averaging predictions over them.

Predictor values remain unchanged, including any lagged responses used
as predictors.
