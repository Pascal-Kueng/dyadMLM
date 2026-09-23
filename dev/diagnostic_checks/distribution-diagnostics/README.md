# Distribution-check examples

The package function `check_residuals()` compares observed data with
complete datasets from the fitted model. It uses DHARMa for PIT residuals and
keeps simulated partner and time dependence in the plotted references.

```r
simulations <- simulate_dyad_responses(model, seed = 123)
check_residuals(simulations)

# Separate compositions and roles, even if the model pools them.
check_residuals(
  simulations, dyad = coupleID, role = gender, data = model_data
)
```

Use your own column names and the unchanged data used to fit the model.
Without `role`, all observations are pooled. With `role`, each composition
gets two pages: one column for same-role dyads, two role-specific columns
for distinct-role dyads. For repeated observations, also supply `member`.
Observed responses from incomplete pairs are retained when their composition
can be established from the fitting data.

Each overview shows a PIT QQ plot, PIT histogram, outcome distribution, and
PIT quartiles across fitted predictions. Outcome plots use category frequencies
for ordinal outcomes and small count ranges; otherwise, cumulative proportions.
A second page compares response variability, out-of-range outcomes, largest
deviations, and relevant zero counts with their simulated distributions.
Each plot has a short reading guide. Numeric predictor plots use bins chosen
within each role, then smooth nearby quartiles with the same weights for observed
and simulated datasets. Bands are calculated after smoothing. The median is bold;
matching line styles identify the other quartiles and their bands. Sparse numeric
values and categories retain separate reference intervals.
Red shows observed data; blue shows simulated references. Ranges contain the middle 95% at each
position, not across the whole figure. These are descriptive checks, with fitted
parameters fixed and no significance tests.

Use `predictors = simulations$model_frame[c("x", "z")]` for extra predictor
panels, or `details = TRUE` to add a uniformity summary and PIT distance across
fitted predictions.
See `?check_residuals` for plot meanings and limits.

## Reproduce the examples

From the package folder, run:

```sh
OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 Rscript dev/diagnostic_checks/distribution-diagnostics/tail-shape-comparison.R
```

Run [composition-layout.R](composition-layout.R) the same way for the three
compositions:

| Composition | Overview | Summary checks |
|---|---|---|
| Female-female | [Plots](results/composition-01.svg) | [Plots](results/composition-02.svg) |
| Female-male | [Plots](results/composition-03.svg) | [Plots](results/composition-04.svg) |
| Male-male | [Plots](results/composition-05.svg) | [Plots](results/composition-06.svg) |

The tail-shape script fits Gaussian models to four datasets:

| Data | Overview | Summary checks | Predictor patterns |
|---|---|---|---|
| Heavy-tailed t(3) | [Plots](results/t3-panel-01.svg) | [Plots](results/t3-panel-02.svg) | [Plots](results/t3-panel-03.svg) |
| Heavier-tailed t(2.2) | [Plots](results/t22-panel-01.svg) | [Plots](results/t22-panel-02.svg) | [Plots](results/t22-panel-03.svg) |
| Gaussian | [Plots](results/gaussian-panel-01.svg) | [Plots](results/gaussian-panel-02.svg) | [Plots](results/gaussian-panel-03.svg) |
| Gaussian with strong partner and AR(1) dependence | [Plots](results/gaussian_strong-panel-01.svg) | [Plots](results/gaussian_strong-panel-02.svg) | [Plots](results/gaussian_strong-panel-03.svg) |

The first two illustrate a distribution mismatch; the others are comparison
cases with the same sample size. The composition examples demonstrate the layout
using a simplified model; they are not correctly specified controls. These examples
do not establish how reliably the checks detect model problems.
The SVGs are kept for review and are reproduced by these scripts; they are
excluded from the built R package. `results/` also records package versions and
fit summaries. Its tail ratio is the 1st-to-99th percentile range divided by the
interquartile range, after subtracting fixed-effect predictions.

The implementation is in `R/predictive_checks_residuals.R`; package regression
tests are in `tests/testthat/test-predictive-checks-residuals.R`.
