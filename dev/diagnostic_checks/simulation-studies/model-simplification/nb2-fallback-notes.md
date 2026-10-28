# NB2 inference when the full covariance is hard to fit

Six conditions use 100/400 dyads and correct pooling, a latent role SD ratio of
1.5, or composition correlations of -0.1/0.3/0.7. Outcomes follow NB2 with size
3. Both candidates retain the correct role- and composition-specific means and
slopes. The female actor effect in female-male dyads is generated as zero.
The four primary targets are conditional log-link coefficients, including the
female-minus-male intercept; that contrast is not a marginal mean difference
when latent variances differ.

Compare fixed pooled/full models, full-then-pooled fallback and LRT selection at
0.05. A full fit with log-likelihood more than 0.000001 below its nested pooled
fit is ineligible even when its optimizer reports convergence. Preserve nominal
fit status and all estimates. Selection uses the sole eligible candidate; if
neither is eligible, it returns no inference. An undefined LRT with both fits
eligible also returns no inference.

Report all attempts, availability, bias, SE accuracy, coverage and rejection.
Dependence, residual and outcome checks share one pooled-fit reference bank.
Individual panels and per-check unions remain separate. Show all eligible pooled
fits primarily, with full-fit availability strata as descriptive subsets.
Do not condition inference on having no flags.

Run from this checkout, with at most ten fitting workers across jobs:

```sh
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
Rscript dev/diagnostic_checks/simulation-studies/model-simplification/check-nb2-fallback.R
Rscript -e 'source("dev/diagnostic_checks/simulation-studies/model-simplification/nb2-fallback.R"); run_nb2_fallback(2L, 1000L, 5L, "run")'
Rscript dev/diagnostic_checks/simulation-studies/model-simplification/validate-nb2-fallback-pilot.R
Rscript -e 'source("dev/diagnostic_checks/simulation-studies/model-simplification/nb2-fallback.R"); run_nb2_fallback(500L, 1000L, 10L, "run")'
```

The full run has 3,000 datasets, 6,000 fit attempts and 300 checkpoints. Sources
and software are fingerprinted; only matching checkpoints may be resumed. Pilot
rates are not calibration evidence. After the full audit, copy the five CSV
tables to `report-data/model-simplification-nb2/` and render the covariance-pooling
report. Its `nb2_directory` parameter can instead point to an absolute pilot path.

Then run `Rscript dev/diagnostic_checks/simulation-studies/model-simplification/nb2-paired-inference.R`
to add `paired-inference.csv`. This reads saved results without refitting and
compares the models on datasets where both were eligible. Keep this selected
subset as a sensitivity analysis alongside the primary available-fit results.

This does not validate ordinal fallback models. For cross-sectional ordinal
probit with a fully free latent covariance V, replacing coefficients and
thresholds by c times their values, and V by c²(V+I)−I, leaves the joint category
probabilities unchanged when the new covariance is valid. An explicit scale
constraint is needed; checks cannot identify that missing scale.
