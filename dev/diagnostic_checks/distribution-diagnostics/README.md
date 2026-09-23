# Distribution-check examples

`check_residuals()` checks DHARMa PIT residuals. `check_outcomes()` checks
response distributions, spread, extremes, and zero counts. Both reuse complete
simulated datasets and retain their partner and time dependence in the references.

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
Without `role`, all observations are pooled. With `role`, each composition
gets one page per check: one column for same-role dyads, two role-specific columns
for distinct-role dyads. For repeated observations, also supply `member`.
Observed responses from incomplete pairs are retained when their composition
can be established from the fitting data.

Residual pages show a PIT QQ plot, PIT histogram, PIT quartiles across fitted
predictions, and the number of PIT endpoints (outcomes outside their simulation
reference range). Outcome pages show the raw response distribution, variability,
largest deviations, and relevant zero counts. Variability and deviations are
calculated after subtracting the same model predictions from each dataset.
Outcome distributions use category frequencies for ordinal outcomes and small
count ranges; otherwise, cumulative proportions.

Each plot has a short reading guide. Numeric residual plots use bins chosen
within each role, then smooth nearby quartiles with the same weights for observed
and simulated datasets. Bands are calculated after smoothing. The median is bold;
matching line styles identify the other quartiles and their bands. Sparse numeric
values and categories retain separate reference intervals.
Red shows observed data; blue shows simulated references. Ranges contain the middle 95% at each
position, not across the whole figure. These are descriptive checks, with fitted
parameters fixed and no significance tests.

In `check_residuals()`, use `predictors = simulations$model_frame[c("x", "z")]`
for extra predictor panels, or `details = TRUE` for a uniformity summary and
PIT distance across fitted predictions. In `check_outcomes()`,
`centred_overlay = TRUE` adds an outcome overlay after subtracting model predictions.
See `?check_residuals` and `?check_outcomes` for plot meanings and limits.

## Reproduce the examples

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
