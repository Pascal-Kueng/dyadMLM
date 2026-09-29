# Partner-dependence studies

These studies assess descriptive predictive checks, not calibrated significance
tests. Each study has its own script folder and compact tables in `report-data/`.
Public report sources stay in `vignettes/articles/`.

| Folder | Purpose | Report |
| --- | --- | --- |
| [family-comparison](family-comparison/run.R) | Raw versus model-centred correlation checks across response families | [Full report](../../../vignettes/articles/partner-dependence-simulation.Rmd) |
| [covariance-pooling](covariance-pooling/run.R) | Gaussian composition checks and model comparison | [Full report](../../../vignettes/articles/covariance-pooling.Rmd) |
| [generalized-covariance-pooling](generalized-covariance-pooling/run.R) | Screen families, then compare pooled and full latent covariance | [Full report](../../../vignettes/articles/covariance-pooling.Rmd) |
| [distribution-checks](distribution-checks/run.R) | Residual and outcome flags, pooled versus role checks, and paired PIT centring | [Report](../../../vignettes/articles/distribution-checks.Rmd) |
| [validation](validation/validation.R) | Earlier sensitivity studies and focused fitting checks | [Recorded findings](validation/results-summary.md) |

[Shared family generators](shared/family-margins.R) are used by both family studies.
The separate [family checks](../README.md#validation) and package tests check
implementation details such as category scoring and fitted-row alignment.

## Saved results and reproduction

Run commands below from the repository root. Limit numerical libraries to one
thread per worker, and use at most ten workers across jobs. On Windows, use one
worker. Seeds do not depend on worker count.

```sh
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
```

Git keeps the scripts, report sources, and compact aggregate tables under
`report-data/<study>/`. Local outputs under `results/` are ignored, including
checkpoints, logs, archives, and local libraries. Rendered files are ignored too.
Checkpoints save per-dataset statistics, fit diagnostics, and seeds, plus covariance
recovery for screening. They do not save complete fitted model objects.

The family comparison and covariance studies resume saved runs. Reports rebuild
from exported tables without refitting. New diagnostics may require refitting;
changes to the study design require a new run. Failed fits remain recorded and
are excluded from check rates. Reference simulations keep fitted parameters fixed.
Reported rate intervals are 95% Wilson intervals.

## Residual and outcome checks

This focused study extends the earlier [distribution-check pilot](../distribution-diagnostics/calibration-summary.md).
It uses Gaussian and negative-binomial outcomes at 40, 100, and 400 dyads.
Gaussian settings cover correct specification, two omitted role mean differences,
and two role SD ratios. Count settings cover correct NB2 models, two amounts of
NB2 overdispersion fitted as Poisson, and two omitted zero-inflation probabilities.
All fitted models retain actor and partner effects and a shared dyad intercept.
Four additional conditions cover stronger dyad dependence and Gaussian
longitudinal data with six occasions and person-specific AR(1) processes.
There are 34 conditions, with 500 datasets and 1,000 reference simulations per
dataset in a full run.

The fitted centred and uncentred residual checks share their data, fitted model,
simulation bank, and PIT seed. Outcome checks reuse the same bank. Correct-model
conditions also use a separate known-parameter reference, evaluated regardless
of fitting success. Both pooled and role-specific checks are recorded.

Rates describe individual panels and the union of numerical flags across panels
and roles. The union has no promised 5% false-alarm rate. Count-category ranges
are pointwise and use observed categories, so their availability and crossing
rates are reported separately. Blue-only "Other" values have no observed
comparison. The continuous ECDF display has no numerical flag rule.

```sh
Rscript dev/diagnostic_checks/simulation-studies/distribution-checks/check.R
OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
  Rscript dev/diagnostic_checks/simulation-studies/distribution-checks/run.R 500 1000 6 run
```

Arguments are datasets per condition, reference simulations, workers, and `run`
or `summarise`. An optional fifth argument selects comma-separated condition
numbers. Seeds do not depend on workers or selection. Checkpoints save every
five datasets under `results/distribution-checks/<settings>/`; rerun the same
command to resume. Changed generators, package code, or software versions require
archiving the old run before restarting. Use at most ten workers across jobs.

For a short workflow check, use `5 200 4 run`. This is a pilot, not evidence of
precise flag rates. Render its report with the saved output's absolute path as
the `results_directory` parameter. `summarise` updates tables without fitting.
Only a complete 500-by-1,000 run exports public tables and renders the report.

Saved checkpoints contain per-dataset flags, scalar limits, seeds, warnings,
errors, and fitting diagnostics, without fitted models or simulation matrices.
The report tables contain conditions, flag rates with 95% Wilson intervals and
Monte Carlo SEs, paired centring differences and their SEs, fit/check failure
counts, and median fitted dyad SDs and dispersion. Source hashes and session
information accompany the full results.
Rates exclude failed fits and checks without retry; unavailable statistics do
not count as agreement. Longitudinal conditions evaluate these marginal checks
under time dependence, not their ability to detect serial-correlation errors.

### Do the checks detect mismatches that distort inference?

[consequences.R](distribution-checks/consequences.R) refits each main-study
dataset from its seed and records the actor and partner estimates, SEs, and 95%
Wald coverage; the flags of these datasets are in the main study's summary. It
also runs the default checks, with a residual page for each predictor, on three
severe mismatches at 100 and 400 dyads with dyad SD 1.2: an omitted partner
effect, NB2 size 1 fitted as Poisson, and a residual SD that rises with the
actor predictor. The correct Gaussian model with the same pages gives their
false-alarm rate.

```sh
OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
  Rscript dev/diagnostic_checks/simulation-studies/distribution-checks/consequences.R 500 1000 6
```

Arguments and modes match `run.R`. Checkpoints are saved under
`results/distribution-checks-consequences/<settings>/`. Complete 500-by-1,000
runs export `inference.csv` and `severe-summary.csv` to
`report-data/distribution-checks/`. The run takes about 13 CPU hours, nearly
all for the severe conditions, or about three hours with six workers.

### Confirmation run

The main study and its add-on reproduce at commit `0ceacd4c`. They record
panels that the package has since removed: the PIT histogram, the outlier
count, and count category bars. [dropped-panels.R](distribution-checks/dropped-panels.R)
recomputes their default flag unions with and without the histogram and
outlier count and writes `report-data/distribution-checks/dropped-panels.csv`.
The add-on's unions include its predictor pages. Its optional argument is the
`results/` directory of both runs. With all panels, it must reproduce the
reported rates.

[confirmation.R](distribution-checks/confirmation.R) confirms, on fresh seeds,
how often the remaining panels flag correct and mismatched models. Its design
was fixed before the run:

- Cross-sectional data at 100 and 400 dyads, dyad SD 0.6, and the main study's
  predictors. Gaussian: correct model, role SD ratio 1.5, residual SD
  exp(actor predictor - 1), and an omitted partner effect. NB2: correct model
  (size 3), and size 10 fitted as Poisson. Ordinal: correct model, with the
  Gaussian model's predictors and dyad effect, without intercept, scaled by
  pi/sqrt(3), plus standard logistic noise, cut at -3.05, -1.23, 1.23, and 3.05
  into five categories (about 10/20/40/20/10%).
- Every condition runs the same displays: pooled (with `dyad`) and by role,
  both with actor and partner predictor pages, package defaults, and only the
  fitted reference.
- The *core* union contains QQ, mean PIT distance, PIT quartiles and distance
  across predicted outcomes, response SD, largest absolute deviation, and the
  zero count where shown. The *pages* union adds the four predictor-page
  panels. Both are reported for each check and both checks together, pooled
  or in either role. Ordinal category ranges (`category_any`) are reported
  separately and never enter a union.
- Tables give each rate with its 95% Wilson interval and usable datasets, fit
  failures, and how often the ordinal largest-deviation range has equal limits.
- Dataset seeds are 910,000,000 + 100,000 × condition + dataset; simulation
  and PIT seeds add 10,000,000 and 30,000,000. 500 datasets and 1,000 reference
  simulations per dataset. Roxygen lines are left out of the settings check,
  so help text can change during the run.

```sh
Rscript dev/diagnostic_checks/simulation-studies/distribution-checks/dropped-panels.R
OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
  Rscript dev/diagnostic_checks/simulation-studies/distribution-checks/confirmation.R 500 1000 6
```

Arguments and modes match `run.R`. Checkpoints are saved under
`results/distribution-checks/confirmation-<settings>/`. A complete 500-by-1,000
run copies its summary, fits, largest-deviation ties, and session information
to `report-data/distribution-checks/` with the prefix `confirmation-`. The run
needs glmmTMB with `ordinal()` and takes about 18 CPU hours, or about four hours
with six workers.

## Gaussian covariance pooling

Both models use the package's data preparation and covariance terms, with the
same correctly specified, distinguishable fixed effects. Five settings cover
correct pooling, two sizes of role SD differences, and two sizes of correlation
differences between compositions. All retain the same pooled population variance
and covariance. Samples contain 40, 60, 100, 200, or 400 dyads. A further 100-dyad
setting contains 20 female-female, 60 female-male, and 20 male-male dyads.

```sh
Rscript dev/diagnostic_checks/simulation-studies/covariance-pooling/run.R 1000 1000 4 run
```

Arguments are datasets per condition, reference simulations per fit, workers, and
`run` or `summarise`; the command shows the defaults. Progress is saved every ten
datasets under `results/covariance-pooling/`. `summarise` refreshes tables without
refitting. A complete default run exports four tables to
`report-data/covariance-pooling/` and renders the standalone report.

For a short development run, use `5 1000 4 run`. Render the report source with
`rmarkdown::render()` and its absolute output directory as `gaussian_directory`.
Treat those results as preliminary.

## Generalized covariance pooling

This study is complete. The [screen](generalized-covariance-pooling/screen-families.R) used
50 datasets per setting at 40, 100, and 400 dyads. It covers correct pooling,
a latent role SD ratio of 1.5, and latent correlations of -0.1, 0.3, and 0.7 across
compositions. Both fitted models retain dependence and distinguishable fixed effects.

Selection requires at least 90% usable fits for both models in every setting at
400 dyads. Across the full model's compositions and settings, median relative
variance bias must be at most 25%, median absolute relative variance error at most
50%, and absolute median correlation bias at most 0.15. Passing these practical
criteria does not guarantee reliable fitting in other settings.

Ordinal-probit and skew-normal models are excluded before numerical screening.
The full latent structure leaves the ordinal scale unidentified. For skew-normal
responses, Gaussian variation can move between the response distribution and
latent effects. These limits concern this parameterization, not package support.

```sh
Rscript dev/diagnostic_checks/simulation-studies/generalized-covariance-pooling/screen-families.R 50 10
Rscript dev/diagnostic_checks/simulation-studies/generalized-covariance-pooling/check.R
Rscript dev/diagnostic_checks/simulation-studies/generalized-covariance-pooling/run.R 500 1000 10
```

The [known-parameter check](generalized-covariance-pooling/check.R) compares the
generators' response moments with native glmmTMB simulations. The main study uses
fresh seeds, 500 datasets per condition, 1,000 reference simulations per fitted
model, and the same three sample sizes. It checks pooled and full models across
all five covariance settings. Family dispersion, where present, is estimated in
both. Flags concern response summaries, so their direction is not inferred from
latent covariance changes.

Screening saves progress every five datasets. The main study runs one batch of
datasets at a time, up to the worker count, and saves each completed batch.
Screening tables go to
`report-data/generalized-covariance-screening/`; main-study tables go to
`report-data/generalized-covariance-pooling/` only after the complete default run,
which also renders the local report. The [helpers](generalized-covariance-pooling/helpers.R) reuse Gaussian preparation
and the shared family generators. Bell requires `gsl`. Tweedie results
used the isolated sampler repair described below.

## Raw versus model-centred checks

This completed study covers 20 supported families, zero-inflated Poisson, and
hurdle NB2. Both checks use the same fitted model and reference simulations. Only
subtraction of fixed-effect predictions differs. Actor and partner effects are
0.5 and 0.3, with standard normal predictors correlated at 0.3. Models include
these effects but omit the remaining partner dependence.

The [generators](shared/family-margins.R) calibrate residual correlations of
0, 0.10, 0.30, and 0.50 after subtracting the true conditional response means.
Independent calibration checks are saved. Ordinal outcomes use category scores;
zero-inflated and hurdle outcomes include zeros. Sample sizes are 20, 40, 60, 80,
100, 150, 200, 300, 400, 500, and 1,000 dyads.

For positive correlations, detection requires exceeding the reference's 97.5th
percentile. Opposite-direction flags are reported separately. At zero correlation,
either tail counts as a false alarm. The 5% plot line is a benchmark, not a
promised rate. The study also records paired differences and fitting failures.

```sh
Rscript dev/diagnostic_checks/simulation-studies/family-comparison/run.R 500 1000 8 run
Rscript dev/diagnostic_checks/simulation-studies/family-comparison/run.R 500 1000 8 plot
```

Arguments are datasets per condition, reference simulations per fit, workers,
`run` or `plot`, and optional comma-separated families, such as
`gaussian,nbinom2,zi_poisson,hurdle_nbinom2`. The first command shows the defaults.
Progress is saved every 25 datasets under `results/family-comparison/<settings>/`.
`plot` redraws saved results. Full runs require `gsl` and glmmTMB with `ordinal()`.
COM-Poisson settings can be slow.

A complete default run exports four tables to `report-data/family-comparison/`
and renders the report and the [vignette draft](../partner-dependence-vignette-draft.Rmd). The folder also contains
[plotting](family-comparison/plot.R), [summarising](family-comparison/summarise.R),
and [export](family-comparison/export-report-data.R) helpers.

## Rebuild completed reports

After changing text or plots, rebuild from the compact tables without simulations:

```r
pkgdown::build_article("articles/partner-dependence-simulation")
pkgdown::build_article("articles/covariance-pooling")
pkgdown::build_article("articles/distribution-checks")
```

After updating saved family-comparison results, first refresh its exported tables:

```sh
Rscript dev/diagnostic_checks/simulation-studies/family-comparison/export-report-data.R
```

More reference simulations refine each fit's reference range. More generated
datasets improve the precision of the plotted flag rates. They serve different
purposes; the family study uses 1,000 and 500, respectively.

## Tweedie simulation repair

The family comparison used glmmTMB commit
`93c774717c0f10b600c25dd21f393d03155efc3f`. Four Tweedie conditions stalled when
fitted power approached 2 because the sampler added millions of Gamma draws per
response. The two-line [patch](family-comparison/tweedie-sampler.patch) replaces
that sum with one Gamma draw with its shape multiplied by the number of terms,
matching TMB 1.9.25. The distribution and fitting code are unchanged, but random
realizations differ.

The remaining 1,450 datasets in those conditions used the repair; completed
results were retained. Checks confirmed unchanged estimates and expected response
moments and zero probabilities. Resumed repetition ranges and validation results
are saved in `results/family-comparison/tweedie-repair/`.

To build the repair separately, with TMB 1.9.25 and glmmTMB build dependencies:

```sh
study_directory="$PWD/dev/diagnostic_checks/simulation-studies"
tweedie_library="$study_directory/results/tweedie-library"
mkdir -p "$tweedie_library"
git clone https://github.com/glmmTMB/glmmTMB.git "$study_directory/results/tweedie-source"
git -C "$study_directory/results/tweedie-source" checkout 93c774717c0f10b600c25dd21f393d03155efc3f
patch -d "$study_directory/results/tweedie-source" -p1 < "$study_directory/family-comparison/tweedie-sampler.patch"
R CMD INSTALL --library="$tweedie_library" "$study_directory/results/tweedie-source/glmmTMB"
R_LIBS="$tweedie_library" Rscript dev/diagnostic_checks/simulation-studies/family-comparison/run.R 500 1000 10 run tweedie
```

`R_LIBS` selects this repair without replacing the normal installation. The saved
study combines both samplers, so a fresh run will not reproduce every draw exactly.

## Earlier validation and fitting examples

The retained [sensitivity study](validation/sensitivity.R) uses intercept-only
Gaussian, NB2, ordinal, and lognormal models at 50, 200, and 1,000 dyads. Defaults
remain 200 datasets and 499 reference simulations to reproduce earlier results.
Copula correlations are -0.25, 0, 0.10, 0.25, and 0.50. Separate SD settings use
second/first ratios of 1.10, 1.25, and 1.50 with independent partners; one combined
setting uses correlation 0.25 and ratio 1.25.

Before changing the second SD, Gaussian responses have mean 0 and SD 1; NB2 and
lognormal responses have mean 3 and SD 2. Ordinal scores have mean 2.5 and SD 0.8.
Correlated normal draws are transformed to these distributions. Copula correlation
usually differs from response correlation. Checks use raw responses and first/second
roles. These intercept-only settings are not directly comparable with the family
study above. New runs save all six summary statistics.

```sh
Rscript dev/diagnostic_checks/simulation-studies/validation/sensitivity.R 200 499 4
Rscript dev/diagnostic_checks/simulation-studies/validation/sensitivity.R 200 499 4 plot
Rscript dev/diagnostic_checks/simulation-studies/family-comparison/check.R
Rscript dev/diagnostic_checks/simulation-studies/validation/validation.R 20 199 200
Rscript dev/diagnostic_checks/simulation-studies/validation/fitting-examples/ordinal.R
Rscript dev/diagnostic_checks/simulation-studies/validation/fitting-examples/lognormal.R
```

For sensitivity, `plot` refreshes saved summaries without refitting. Fits with
convergence or Hessian problems are excluded without retry. Absent ordinal
categories are recorded as study exclusions. Warnings and undefined draws remain
saved. With 200 datasets, the maximum Monte Carlo SE is about 3.5 percentage points.

`validation.R` takes datasets, reference simulations, and dyads; defaults are shown
above. It checks known-parameter references, Gaussian covariance restrictions,
and omission of response and zero-component dyad effects. These short runs check
behavior, not precise flag rates. Fitting examples use one original dataset and
shared random draws. Ordinal fitting requires the `ordinal` package. These examples
illustrate fitting discrepancies without establishing their frequency.

Validation and fitting examples replace outputs for the same settings. Historical
results and retired scripts remain in ignored archives
`results/before-consolidation-20260921.tar.gz` and
`results/before-apim-retirement-20260923.tar.gz`. Their contents were verified before
cleanup. See [recorded findings](validation/results-summary.md) for context.
