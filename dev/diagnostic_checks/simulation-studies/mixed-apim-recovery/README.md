# Mixed-composition APIM parameter recovery

This study checks whether the Gaussian specifications in
[`mixed-apim.Rmd`](../../../vignettes/mixed-apim.Rmd) recover their generating fixed
effects and member-level covariance parameters. It uses fresh data generated for
each specification, rather than the package's illustrative datasets.

## Design

The 12 conditions combine 120 or 360 dyads with:

- cross-sectional intercept-only and actor–partner models;
- 14-occasion models with random intercepts, or random intercepts plus
  within-person actor and partner slopes;
- separate composition parameters, or correctly pooled female–female and
  male–male parameters in the longitudinal models.

Each sample starts with equal numbers of female–female, female–male and male–male
dyads: 40 or 120 of each. Pooled conditions therefore have twice as many same-sex
dyads as female–male dyads. The full run generates 500 datasets per condition
(6,000 joint-model fitting procedures, plus fits used for starting values).
There is no missingness or serial dependence beyond stable random
effects. ILD predictors use observed person means and within-person deviations,
computed before package preparation. These checks do not assess latent centring.

[`helpers.R`](helpers.R) records the fixed effects and covariance matrices,
generates outcomes independently of the prepared indicator columns, and builds
the vignette's distinguishable and shared/difference blocks. Random slopes apply
to within-person predictors. Exchangeable covariance estimates are transformed
back to the member scale; every matrix element and correlation is retained.
The random-slope models estimate 38 covariance parameters when pooled and 52
when compositions are separate.

Fits use maximum likelihood, zero observation-level dispersion and BFGS
(`maxit = 1000`, `reltol = 1e-10`), without retries. Cross-sectional and
random-intercept models use profiling. Random-slope models first fit each
composition sequentially with profiling, preserving the joint sample's prepared
predictors and centring. Named coefficients and covariance parameters from these
fits supply starting values for the literal joint model, fitted without profiling.
No generating parameter is used as a starting value.

Finite starting values are retained even when a composition fit has a convergence,
Hessian or boundary problem. `initialization_failures` counts datasets with at
least one initializer convergence or Hessian problem; warnings include all stages.
A thrown initialization error records a failed procedure. Final usability depends
on the joint fit: convergence, a positive-definite Hessian, finite log-likelihood,
estimates and fixed-effect SEs. Near-singular final covariance blocks are recorded
using a smallest-eigenvalue/largest-diagonal ratio below `1e-6`; this flag alone
does not exclude a fit.

## Run and inspect

Run from the repository root. Keep numerical libraries to one thread and use no
more than ten workers across concurrent jobs.

```sh
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 \
  Rscript dev/diagnostic_checks/simulation-studies/mixed-apim-recovery/check.R
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 \
  Rscript dev/diagnostic_checks/simulation-studies/mixed-apim-recovery/run.R 2 10 run
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 \
  Rscript dev/diagnostic_checks/simulation-studies/mixed-apim-recovery/run.R 500 10 run
```

The two-dataset pilot checks the workflow; its seeds differ from the full run.
Rerun the same command to resume. Atomic checkpoints save ten datasets at a time
under `results/mixed-apim-recovery/<datasets>-datasets/`. Source snapshots,
settings and software versions prevent incompatible checkpoints from being mixed.
An optional fourth argument selects a fresh output directory.
After a branch change, render the exported CSVs directly. Existing checkpoints
retain their original source signature; rerunning with different sources requires
a fresh output directory.

Use `500 10 summarise` to rebuild tables without fitting. Local
`dataset-tables.rds` retains individual estimates and fit diagnostics. A complete
500-dataset run exports `conditions.csv`, `fits.csv` and `recovery.csv` to
`report-data/mixed-apim-recovery/`. Failed fits remain in the denominator for fit
availability; parameter summaries use usable fits and retain their own counts.

Recovery includes bias, Monte Carlo SE of bias, empirical SD, RMSE and mean
absolute error. Fixed effects also have mean model SEs, SE ratios and 95% Wald
coverage with Monte Carlo SEs and Wilson intervals. No interval coverage is
claimed for covariance parameters. At 500 usable estimates, 95% coverage has a
Monte Carlo SE of about one percentage point.

```r
rmarkdown::render("dev/vignettes/articles/mixed-apim-recovery.Rmd")
# For a pilot, set params = list(output_directory = "/absolute/path/to/results").
```

The report reads saved tables, shows each fixed coefficient, compares random
parameter means with truth, and reports correlation RMSE. Its scope is limited
to these Gaussian designs, sample sizes and fitting settings.
