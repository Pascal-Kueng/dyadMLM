# Calibration and performance check

Checked on 2026-09-26 using the `calibrate-residuals` working tree based on
`7bdc6c9a`, with R 4.6.1, glmmTMB 1.1.15 and TMB 1.9.25.

From the package root, reproduce with:

```sh
OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 Rscript dev/diagnostic_checks/distribution-diagnostics/calibration-check.R
```

Each Gaussian/NB2 design used 100 repetitions, 100 dyads with two observations,
200 simulations, and seeds starting at 93001. The script specifies the generating
parameters. Known-parameter references were uncentred; fitted references used
the implemented intercept guard and median centring. All 200 fits converged with
positive-definite Hessians and no fitting warnings. Per-repetition results,
settings, source hashes and session information are saved in ignored
`results/calibration/`.

Percent of observed summaries crossing their reference limits:

| Family/reference | QQ | Histogram | Predictor quartiles | Predictor distance | Outliers | Mean distance |
|---|---:|---:|---:|---:|---:|---:|
| Gaussian, known | 5 | 1 | 4 | 5 | 0 | 3 |
| Gaussian, fitted | 3 | 3 | 1 | 6 | 0 | 0 |
| NB2, known | 7 | 5 | 7 | 3 | 2 | 4 |
| NB2, fitted | 5 | 2 | 1 | 1 | 1 | 0 |

At a 5% rate, Monte Carlo SE is about 2.2 percentage points. Zero crossings
in 100 repetitions still allow an exact two-sided 95% upper bound of about 3.6%.
These limited designs do not establish general calibration or power. The fitted
mean-distance comparison remained conservative. Coverage is per panel, not across panels.

For actual `dyads_ild` data (10,080 rows, 1,000 simulations), simulation took
2.016 s and `check_residuals()` took 11.732 s. Stored PIT used 77.04 MiB; the full
result used 78.23 MiB. The complete cross-sectional/ILD benchmark process peaked
at 1.09 GiB RAM, including packages, fits, simulations, checks and plotting.
Its ILD model used couple/person random intercepts: this was a runtime/layout
check, not an AR(1) calibration study. Both full result objects were exactly
unchanged by the column-wise centring memory improvement.

Six-row plots on both package datasets rendered at 12 x 8 and 12 x 20 inches.
Tall plots were readable; ordinary-height plots retained all rows with small text.
The timings and object sizes are saved in [benchmark.csv](benchmark.csv).
Both models used `closeness ~ gender + provided_support + (1 | coupleID)`;
the ILD model also included `(1 | personID)`. Simulation and PIT seeds were
260926 and 260927. These timings describe one local run. Rendered examples are
linked in the [development guide](README.md#reproduce-the-examples).
Separate validation: 2,483 test assertions passed; ERL matched GET in 24 cases,
and 201/1,001-curve cutoff checks passed. `R CMD check` was OK, with tests run
separately and manuals/vignettes skipped.

The review fixes passed 1,143 diagnostic assertions, including ordinal intercept
mapping and the display of unobserved count values. The corrected count plot was
visually checked, and the updated Tweedie example was rendered again.
