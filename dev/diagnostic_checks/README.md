# Partner-dependence checks: development guide

The workflow is: predict with random effects set to zero, simulate new random
effects and responses, subtract the same prediction from every dataset, apply
the same statistic, and plot. The comparisons are descriptive and keep fitted
parameters fixed; close agreement alone does not establish good fit.

## Documents

| Document | Purpose |
| --- | --- |
| [Vignette candidate](partner-dependence-vignette-draft.Rmd) | One complete workflow and interpretation |
| [Review checklist](partner-dependence-review.Rmd) | Questions for reviewing changes |
| [Reference validation](partner-dependence-reference-validation.Rmd) | Independent Woody–Sadler calculations and Dingy cross-check |
| [Outer simulation study](partner-dependence-outer-simulation-study.Rmd) | Known Gaussian populations, fitted models, and repeated-sample behavior |

The function help is the reference for arguments, output fields, supported
models, and omission rules. Keep these details there rather than duplicating
them in each development document.

## Scope and extension

Current checks cover unweighted cross-sectional `glmmTMB` models without zero
inflation: Gaussian, Poisson, NB1, NB2, Tweedie, Gamma, and beta. The model's
fitted link is used for prediction and simulation. Binomial and beta-binomial response
formats need adapters. Nonlinear-link centring is not a residual covariance
decomposition.

The simulator preserves fitted-row order and restores model simulation settings.
With a supplied seed, it also restores the caller’s random-number state.
The checker builds pairs once and applies one statistic
to observed and simulated responses. Undefined observed statistics or entirely
undefined references cause errors; partial undefined draws are reported and
counted, with references conditional on defined values.

Future ILD work can reuse simulation and reference summaries, with its own
statistic and exact scheduled-time pair maps. Recompute member demeaning for
every dataset. Lagged outcomes used as fixed predictors are not recursively
simulated. Preserve the prototype branches as references; weighting and
minimum-reference rules need separate decisions.

## Validation

From the repository root:

```r
devtools::test()
rmarkdown::render("dev/diagnostic_checks/partner-dependence-vignette-draft.Rmd")
rmarkdown::render("dev/diagnostic_checks/partner-dependence-reference-validation.Rmd")
```

Tests cover Gaussian and generalized calculations, fitted-row alignment,
simulation-state restoration, pairing, omissions, undefined statistics, and
printing/plotting. These are correctness checks, not calibration or power
studies. Run the outer simulation report separately when that evidence needs
updating; its full configuration is intentionally more expensive. For a merge,
also check the built package and CI on the proposed commit.
