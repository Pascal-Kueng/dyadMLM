# Partner-dependence checks: development guide

The workflow is: predict with random effects set to zero, simulate new random
effects and responses, subtract the same prediction from every dataset, apply
the same statistic, and plot. The comparisons are descriptive and keep fitted
parameters fixed; close agreement alone does not establish good fit.

## Documents

| Document | Purpose |
| --- | --- |
| [Vignette candidate](partner-dependence-vignette-draft.Rmd) | One complete workflow and interpretation |
| [Reference validation](partner-dependence-reference-validation.Rmd) | Independent Woody–Sadler calculations and Dingy cross-check |
| [Partner-dependence report](https://pascal-kueng.github.io/dyadMLM/articles/partner-dependence-simulation.html) | Detection and false alarms across families and sample sizes |
| [Covariance-pooling report](https://pascal-kueng.github.io/dyadMLM/articles/covariance-pooling.html) | Composition checks and model comparison across families |
| [Simulation studies](simulation-studies/README.md) | Sensitivity across families, raw versus centred checks, and validation |

The function help is the reference for arguments, output fields, supported
models, and omission rules. Keep these details there rather than duplicating
them in each development document.

## Scope and extension

Current checks cover unweighted cross-sectional `glmmTMB` models, including
zero-inflated and hurdle models. See `?simulate_dyad_responses` for supported
families. The model's fitted link is used for prediction and simulation.
Nonlinear-link centring is not a residual covariance decomposition.

The simulator preserves fitted-row order and restores model simulation settings.
With a supplied seed, it also restores the caller’s random-number state.
The checker builds pairs once and applies one statistic
to observed and simulated responses. Undefined observed statistics or entirely
undefined references cause errors; partial undefined draws are reported and
counted, with references conditional on defined values.

Future ILD work can reuse simulation and paired statistics, with exact
scheduled-time pair maps. Recompute member demeaning for
every dataset. Lagged outcomes used as fixed predictors are not recursively
simulated. Preserve the prototype branches as references; weighting and
minimum-reference rules need separate decisions.

## Validation

From the repository root:

```r
devtools::test()
source("dev/diagnostic_checks/check-additional-families.R")
source("dev/diagnostic_checks/check-ordinal-family.R")
rmarkdown::render("dev/diagnostic_checks/partner-dependence-vignette-draft.Rmd")
rmarkdown::render("dev/diagnostic_checks/partner-dependence-reference-validation.Rmd")
pkgdown::build_article("articles/partner-dependence-simulation")
pkgdown::build_article("articles/covariance-pooling")
```

The website report uses saved summary tables and does not rerun the simulations.

Tests cover Gaussian and generalized calculations, fitted-row alignment,
simulation-state restoration, pairing, omissions, undefined statistics, and
printing/plotting. The additional-family script checks native response formats
and prediction/simulation agreement; Bell models also require `gsl`.
The ordinal script checks category scores and predictions with logit and probit
links. It requires a `glmmTMB` version with `ordinal()`.
These are correctness checks, not calibration or power
studies. Run the simulation scripts separately when that evidence needs
updating; their full configurations are intentionally more expensive. For a merge,
also check the built package and CI on the proposed commit.
