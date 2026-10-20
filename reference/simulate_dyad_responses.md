# Simulate response datasets for predictive checks

**\[experimental\]** If a model fits, data simulated from it should
resemble the observed data. This function generates new response
datasets for the same observations and predictors. Reuse them with
[`check_partner_dependence()`](https://pascal-kueng.github.io/dyadMLM/reference/check_partner_dependence.md),
[`check_dyad_residuals()`](https://pascal-kueng.github.io/dyadMLM/reference/check_dyad_residuals.md),
or
[`check_dyad_outcomes()`](https://pascal-kueng.github.io/dyadMLM/reference/check_dyad_outcomes.md)
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
[`check_partner_dependence()`](https://pascal-kueng.github.io/dyadMLM/reference/check_partner_dependence.md),
[`check_dyad_residuals()`](https://pascal-kueng.github.io/dyadMLM/reference/check_dyad_residuals.md),
and
[`check_dyad_outcomes()`](https://pascal-kueng.github.io/dyadMLM/reference/check_dyad_outcomes.md).

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

- [`glmmTMB::ordinal()`](https://rdrr.io/pkg/glmmTMB/man/nbinom2.html)
  (glmmTMB 1.1.15.2 or later)

Smooth terms (`s()`) are not supported: simulations would draw new
curves. Fixed-effect splines such as
[`splines::ns()`](https://rdrr.io/r/splines/ns.html) are supported.

Zero-inflated and hurdle versions are supported where available. Checks
describe the combined response, including zeros, rather than each model
component separately. Good agreement does not establish that the zero
and response components each fit well.

Ordinal checks use category scores `1, 2, ..., K` in their fitted order,
matching [glmmTMB's
predictions](https://rdrr.io/pkg/glmmTMB/man/nbinom2.html). The checks
compare observed and simulated scores. The scores do not measure
distances on an underlying continuous scale. Because each dyad contains
only two people, glmmTMB tends to underestimate the dyad variance in
ordinal models. Simulations then show less partner dependence than the
data, so the partner check can flag a correct ordinal model, especially
with many dyads.

The model's fitted link is used for prediction and simulation.
Predictions and simulated responses must be finite.

## Technical details

Each simulation draws new random effects, if the model has any, and then
new responses from the fitted model. Random effects within each block
are drawn together using their fitted variances and correlations. This
also applies to random effects in the zero-inflation and dispersion
models, if present.

Fitted parameters and predictors, including any lagged responses, stay
fixed. The model is not refitted, and uncertainty in parameter estimates
is not included. This is a *plug-in predictive reference* (Gelman et
al., 1996). If all grouping factors are dyads or nested within dyads
(such as dyad-days), the simulations represent hypothetical new dyads
under the same study design.

`predicted_response` contains predicted mean responses with random
effects in the conditional and zero-inflation models set to zero. For
zero-inflated and hurdle models, this is the conditional response mean
multiplied by one minus the zero-component probability (Brooks et al.,
2017, Appendix A;
[doi:10.32614/RJ-2017-066](https://doi.org/10.32614/RJ-2017-066) ).

Partner-dependence checks (by default) and the response SD and largest
absolute deviation of
[`check_dyad_outcomes()`](https://pascal-kueng.github.io/dyadMLM/reference/check_dyad_outcomes.md)
subtract these same predictions from observed and simulated responses.
Both random effects and observation-level noise still contribute to
response variance. With nonlinear links, setting random effects to zero
generally differs from averaging predictions over them.

## References

Gelman, A., Meng, X.-L., & Stern, H. S. (1996). Posterior predictive
assessment of model fitness via realized discrepancies. *Statistica
Sinica, 6*(4), 733–807.
