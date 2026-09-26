# Distribution-check examples

`check_residuals()` checks where each observed outcome falls among its simulated
values (PIT residuals). `check_outcomes()` checks
response distributions, spread, extremes, and zero counts. Both reuse complete
simulated datasets and retain their partner and time dependence in the references.

The residual method follows [Florian Hartig's DHARMa](https://cran.r-project.org/package=DHARMa)
and the randomized-quantile principle of [Dunn and Smyth (1996)](https://gksmyth.github.io/pubs/residual.html).
dyadMLM computes the PIT ranks internally. Its envelopes and plots compare whole
simulated datasets; they are descriptive checks, with no significance tests.

```r
simulations <- simulate_dyad_responses(model, seed = 123)
check_residuals(simulations)
check_outcomes(simulations)

# Separate compositions and roles, even if the model pools them.
check_residuals(
  simulations, dyad = coupleID, role = gender, data = model_data
)
check_outcomes(
  simulations, dyad = coupleID, role = gender, data = model_data
)
```

Use your own column names and the unchanged data used to fit the model.
Without `role`, all observations are pooled. With `role`, each combination of
partners' roles gets one page per check: one column for same-role dyads, two
role-specific columns for distinct-role dyads. For repeated observations, also
supply `member`.
Observed responses from incomplete pairs are retained when their composition
can be established from the fitting data.
Roles determine the display; simulations retain the fitted model's assumptions,
including its partner dependence and any role-specific variability.

Residual pages show a PIT QQ plot, PIT histogram, PIT quartiles and distance
across predicted outcomes, the number of outcomes outside their simulation
reference range, and mean PIT distance. The QQ plot and histogram are two views
of the same distribution; agreement is not independent evidence.
Outcome pages show the raw response distribution, variability,
largest deviations, and relevant zero counts. Variability and deviations are
calculated after subtracting the same model predictions from each dataset.
They include random effects, so variability does not isolate the model's residual
variance or dispersion parameter.
Outcome distributions use category frequencies for ordinal outcomes and small
count ranges (at most 20 observed values), with an "Other values" range for
unobserved simulated values, shown only in blue without an observed comparison;
otherwise, the proportion at or below each outcome value.

Each plot has a short reading guide. Numeric residual plots use bins chosen
within each role, then smooth nearby quartiles with the same weights for observed
and simulated datasets. Bands are calculated after smoothing. The median is bold;
matching line styles identify the other quartiles and their bands. Sparse numeric
values and categories retain separate reference intervals.
Red shows observed data; blue shows simulated references. Residual curve envelopes
cover positions jointly within each panel, including all three quartiles, but not
across roles or pages. Outcome category ranges remain pointwise. Scalar limits
use simulation order statistics with ties retained at the limits.

PIT uses observed data and all simulations symmetrically. When the conditional
mean has a free overall location, whether fitted as an intercept or separate
role means, each complete dataset is median-centred on the normal-score scale
before any grouping. Ordinal models remain uncentred. The one resulting PIT matrix
is used throughout; outlier counts use strict extrema of the original responses.
At least 200 simulations are required for residual checks; 1,000 are recommended.
Fitted parameters stay fixed. Centring is an empirical adjustment, not a guarantee
of exact calibration. Fitting can make references conservative or biased. With
few observations per random effect, ordinal Laplace fits can bias partner
dependence; refitting with the same approximation need not remove that bias.

In `check_residuals()`, use `predictors = c("x", "z")` for extra predictor panels.
Columns come from the model frame; if absent, supply the original fitting data
with `data` and excluded rows are handled automatically. `predictors = NULL`
(default) omits these extra pages. Each supplied predictor gets quartile and
PIT-distance plots. "Predicted outcome" means the model's
prediction with random effects set to zero, not the observed outcome. Additional
predictor pages use the supplied predictor values.
See `?check_residuals` and `?check_outcomes` for plot meanings and limits.

All three checks can be saved without plotting, then displayed later:

```r
residual_check <- check_residuals(simulations, plot = FALSE)
plot(residual_check, ask = FALSE)
```

`panels = FALSE` shows one plot per figure, retaining composition and role labels.
It changes the layout, not which checks are shown. By default, plots pause only
when there are multiple figures on an interactive device; file output never pauses.

## Validation

[validate-envelopes.R](validate-envelopes.R) compares the global envelopes with
GET, used only as a development reference. [calibration-check.R](calibration-check.R)
checks the package implementation on known-parameter and fitted Gaussian and
negative-binomial models. It also checks Gaussian role panels when the fitted
model omits a role mean difference (A: -0.4, B: +0.4) or a residual SD difference
(A: 0.6, B: 1.4), alongside matching correct-model role panels. It records rates,
Monte Carlo standard errors, and fit warnings and convergence; these are examples,
not fixed detection targets. Set `DYADMLM_CALIBRATION_OUTPUT` to save a pilot run
separately. See [calibration-summary.md](calibration-summary.md)
for the settings, results, limits, and large-data benchmark.

## Reproduce the examples

The [full Tweedie-to-Gaussian example](results/tweedie-gaussian/index.html) starts
with pooled residual checks, then checks roles and a predictor. It shows the
calls to all three checks and every page they produce. The
[executable example](../tweedie-gaussian-example.Rmd) is also included directly
in the development vignette. It uses
the earlier study's first Tweedie dataset (120 dyads, seed 100104) and 2,000
simulations from an exchangeable Gaussian model without the difference random
effect. Run [tweedie-gaussian.R](tweedie-gaussian.R) to reproduce it.

From the package folder, run:

```sh
OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 Rscript dev/diagnostic_checks/distribution-diagnostics/tail-shape-comparison.R
```

Run [composition-layout.R](composition-layout.R) the same way for the three
compositions:

| Composition | Residuals | Outcomes | Partner dependence |
|---|---|---|---|
| Female-female | [Plots](results/residual-composition-01.svg) | [Plots](results/outcome-composition-01.svg) | [Plots](results/partner-composition-01.svg) |
| Female-male | [Plots](results/residual-composition-02.svg) | [Plots](results/outcome-composition-02.svg) | [Plots](results/partner-composition-02.svg) |
| Male-male | [Plots](results/residual-composition-03.svg) | [Plots](results/outcome-composition-03.svg) | [Plots](results/partner-composition-03.svg) |

The tail-shape script fits Gaussian models to four datasets:

| Data | Residuals | Outcomes | Predictor patterns |
|---|---|---|---|
| Heavy-tailed t(3) | [Plots](results/t3-residual-01.svg) | [Plots](results/t3-outcome-01.svg) | [Plots](results/t3-residual-02.svg) |
| Heavier-tailed t(2.2) | [Plots](results/t22-residual-01.svg) | [Plots](results/t22-outcome-01.svg) | [Plots](results/t22-residual-02.svg) |
| Gaussian | [Plots](results/gaussian-residual-01.svg) | [Plots](results/gaussian-outcome-01.svg) | [Plots](results/gaussian-residual-02.svg) |
| Gaussian with strong partner and AR(1) dependence | [Plots](results/gaussian_strong-residual-01.svg) | [Plots](results/gaussian_strong-outcome-01.svg) | [Plots](results/gaussian_strong-residual-02.svg) |

The first two illustrate a distribution mismatch; the others are comparison
cases with the same sample size. The composition examples demonstrate the layout
using a simplified model; they are not correctly specified controls. These examples
do not establish how reliably the checks detect model problems.
The SVGs are kept for review and are reproduced by these scripts; they are
excluded from the built R package. `results/` also records package versions and
fit summaries. Its tail ratio is the 1st-to-99th percentile range divided by the
interquartile range, after subtracting fixed-effect predictions. Its references
use all simulated datasets, as `check_outcomes()` does.
