# dyadMLM: Tools for Dyadic Multilevel Models

`dyadMLM` provides tools for dyadic multilevel modeling with linear and
generalized linear mixed-effects models.

It provides functions for data preparation for various types of dyadic
models and post-estimation tools for interpretation and checking of
model assumptions.

## Installation

Install the stable release from CRAN:

``` r

install.packages("dyadMLM")
```

To try the latest changes and help test upcoming features, install the
development version:

``` r

install.packages(
  "dyadMLM",
  repos = c(
    "https://pascal-kueng.r-universe.dev",
    "https://cloud.r-project.org"
  )
)
```

## Citation

If you use `dyadMLM`, please cite the installed package version. Run:

``` r

citation("dyadMLM")
```

## Data preparation and validation

[`prepare_dyad_data()`](https://pascal-kueng.github.io/dyadMLM/reference/prepare_dyad_data.html)
validates dyadic data and creates model-ready columns for:

- ✅ **Actor-Partner Interdependence Model (APIM):** distinguishable and
  exchangeable dyads.
- ✅ **Dyad-Individual Model (DIM):** exchangeable dyads.
- ✅ **Dyadic Score Model (DSM):** distinguishable dyads.

It supports cross-sectional and intensive longitudinal dyadic data
(e.g., daily diary data). The package also supports datasets containing
multiple dyad compositions.

Preparation options include selecting and pooling compositions, treating
selected compositions as exchangeable, centering predictors, and
creating within-/between-person components and lagged predictors.

Prepared data can be used with **glmmTMB** or **brms**. See the [Getting
Started
vignette](https://pascal-kueng.github.io/dyadMLM/articles/getting-started.html)
for data requirements and examples.

## Post-estimation tools

| Tool | glmmTMB | brms |
|----|----|----|
| [Compare nested models](https://pascal-kueng.github.io/dyadMLM/reference/compare_nested_models.html) | ✅ Supported | Not implemented · [Contribute](https://github.com/Pascal-Kueng/dyadMLM/blob/main/.github/CONTRIBUTING.md) |
| [Recover exchangeable member variances and partner covariances](https://pascal-kueng.github.io/dyadMLM/reference/recover_exchangeable_covariance.html) | ✅ Point estimates | ✅ Posterior summaries and draws |
| [Check partner dependence — cross-sectional](https://pascal-kueng.github.io/dyadMLM/reference/check_partner_dependence.html) | ✅ Experimental | Not implemented · [Contribute](https://github.com/Pascal-Kueng/dyadMLM/blob/main/.github/CONTRIBUTING.md) |

Predictive checks assess whether a model reproduces response variances
and partner correlations. See the [function
help](https://pascal-kueng.github.io/dyadMLM/reference/check_partner_dependence.html)
for supported models and interpretation.

## Quick example

In this example, we prepare the simulated data included in `dyadMLM`,
fit a cross-sectional APIM, and visually check how well the model
reproduces observed partner dependence. The predictive check requires
the development version.

The example also requires **glmmTMB**. Install it with
`install.packages("glmmTMB")`.

``` r

library(dyadMLM)

data("dyads_cross")

prepared_data <- prepare_dyad_data(
  data = dyads_cross,
  dyad = coupleID,
  member = personID,
  role = gender,
  predictors = provided_support,
  model_types = "apim",
  add_apim_gmc_predictors = TRUE,
  keep_compositions = "female-male"
)

# Fit the distinguishable Gaussian APIM from the vignette.
model <- glmmTMB::glmmTMB(
  closeness ~

    # Gender-specific intercepts
    0 + .is_female + .is_male +

    # Gender-specific actor effects
    .is_female:.provided_support_gmc_actor +
    .is_male:.provided_support_gmc_actor +

    # Gender-specific partner effects
    .is_female:.provided_support_gmc_partner +
    .is_male:.provided_support_gmc_partner +

    # Each role's residual variance and the covariance between partners
    us(0 + .is_female + .is_male | coupleID),
  dispformula = ~ 0, # Fix the additional Gaussian residual variance near zero
  family = gaussian(),
  data = prepared_data
)

# Simulate responses and visually check partner dependence.
simulations <- simulate_dyad_responses(model, seed = 123)

check_partner_dependence(
  simulations,
  dyad = coupleID,
  role = prepared_data$gender,
  ask = FALSE
)
```

![Histogram of simulated partner correlations with the observed
correlation marked in red and the middle 95 percent of simulations
marked by dashed
lines.](reference/figures/README-cross-sectional-prep-1.png)

The function draws six plots. Only the partner-correlation plot is shown
here.

Continue with the [APIM
vignette](https://pascal-kueng.github.io/dyadMLM/articles/apim.html) for
details on the model specification and interpretation.

## Vignettes and examples

| Vignette | Focus |
|----|----|
| [Getting Started](https://pascal-kueng.github.io/dyadMLM/articles/getting-started.html) | Data structure, validation, dyad compositions, generated columns, and basic preparation |
| [Actor-Partner Interdependence Model](https://pascal-kueng.github.io/dyadMLM/articles/apim.html) | Cross-sectional and longitudinal APIMs, distinguishability checks, covariance recovery, random slopes, and AR(1) |
| [Dyad-Individual Model](https://pascal-kueng.github.io/dyadMLM/articles/dim.html) | DIM predictor construction, longitudinal models, and an interactive demonstration of equivalence to the exchangeable APIM |
| [Dyadic Score Model](https://pascal-kueng.github.io/dyadMLM/articles/dsm.html) | DSM predictor-score and contrast construction, longitudinal models, and the relationship to the distinguishable APIM |

The model-fitting examples use **glmmTMB**. Joint analysis of multiple
dyad compositions is also supported with glmmTMB. A dedicated vignette
is in preparation.

For theoretical foundations and a practical walkthrough of dyadic data
analysis, from data preparation and model fitting to interpretation and
diagnostics using `dyadMLM` with `glmmTMB`, see the [Dyadic Data
Analysis Workshop](https://pascal-kueng.github.io/dyadMLM/workshop/).
For Bayesian APIM and DIM workflows using `dyadMLM` and `brms`, refer to
[Distinguishable and Exchangeable Dyads: Bayesian Multilevel
Modelling](https://pascal-kueng.github.io/05DyadicDataAnalysis/)
([source](https://github.com/Pascal-Kueng/05DyadicDataAnalysis),
[DOI](https://doi.org/10.5281/zenodo.17400655)).

## Questions and contributing

Questions about using `dyadMLM`, specifying models, or interpreting
output are welcome in [Q&A
Discussions](https://github.com/Pascal-Kueng/dyadMLM/discussions/categories/q-a).

Feature or method ideas can be proposed in
[Ideas](https://github.com/Pascal-Kueng/dyadMLM/discussions/categories/ideas).

Please report any bugs you find or any concrete improvement suggestions
through
[Issues](https://github.com/Pascal-Kueng/dyadMLM/issues/new/choose).

Documentation, examples, tests, reviews, and code contributions are all
welcome. See the [contribution
guide](https://github.com/Pascal-Kueng/dyadMLM/blob/main/.github/CONTRIBUTING.md).

## Full citation

Küng P (2026). *dyadMLM: Tools for Dyadic Multilevel Models*. University
of Zurich.
[doi:10.5281/zenodo.22047083](https://doi.org/10.5281/zenodo.22047083).
R package version 0.2.0.9000, <https://pascal-kueng.github.io/dyadMLM/>.
