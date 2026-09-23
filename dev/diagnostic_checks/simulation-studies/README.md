# Partner-dependence studies

Start with `compare-centering.R` for the current family comparison. `sensitivity.R`
retains the earlier study of omitted correlation and unequal SDs; the other scripts
answer narrower validation questions.
These are descriptive predictive checks, not calibrated significance tests.

| Script | Purpose |
| --- | --- |
| [sensitivity.R](sensitivity.R) | Sensitivity to omitted positive or negative correlation and unequal SDs |
| [compare-centering.R](compare-centering.R) | Compare raw and model-centred checks across all supported families |
| [check-family-comparison.R](check-family-comparison.R) | Verify family generators and the study's correlation calculation |
| [family-margins.R](family-margins.R) | Generate each response distribution and calibrate residual correlation |
| [family-comparison.Rmd](family-comparison.Rmd) | Render all family plots and settings from saved results |
| [plot-family-comparison.R](plot-family-comparison.R) | Draw detection and false-alarm plots from saved summary tables |
| [summarise-family-comparison.R](summarise-family-comparison.R) | Count expected-direction detections and opposite-direction flags |
| [validation.R](validation.R) | Known-parameter references and correct versus restricted covariance models |
| [fitting-examples/ordinal.R](fitting-examples/ordinal.R) | Compare Laplace fitting with more accurate quadrature |
| [fitting-examples/lognormal.R](fitting-examples/lognormal.R) | Compare Laplace fitting with direct likelihood integration |

The [full family report](family-comparison.Rmd) describes the current study;
[recorded earlier results](results-summary.md) cover the historical investigations.
The separate
[family checks](../README.md#validation) and package tests protect implementation
correctness, including category scoring, fitted-row alignment, and zero components.

## Sensitivity

This retained study uses intercept-only Gaussian, NB2, ordinal, and lognormal
models at 50, 200, and 1,000 dyads, with the original generation and seeds.
Its defaults remain **200 datasets per condition and 499 simulations per fit**
to reproduce the historical results. The current family comparison below uses
500 datasets and 1,000 simulations.

The correlation sweep uses copula correlations -0.25, 0, 0.10, 0.25, and 0.50.
The SD sweep uses second/first SD ratios 1.10, 1.25, and 1.50 with independent
partners. One combined condition uses correlation 0.25 and SD ratio 1.25.

The family examples have these marginal distributions before changing the second SD:

| Family | Mean | SD | Generation |
| --- | ---: | ---: | --- |
| Gaussian | 0 | 1 | Normal responses |
| NB2 | 3 | 2 | `size = mean^2 / (SD^2 - mean)` |
| Ordinal | 2.5 | 0.8 | Four scores; probabilities `p, 0.5-p, 0.5-p, p`, with `p = (SD^2-0.25)/4` |
| Lognormal | 3 | 2 | Log variance `log(1 + SD^2 / mean^2)` |

Correlated normal draws are transformed to these distributions. Copula correlation
is generally different from response correlation. These intercept-only examples
are not directly comparable with the current family comparison, which includes
actor and partner effects.

The checks use raw responses and first/second role labels. Each fit assumes
independent partners and equal role variances. New runs save all six panel
statistics and summarise whether either role SD is flagged, so a separate SD
follow-up is unnecessary.

A flag means the observed statistic falls outside its middle 95% simulated range.
The zero-correlation baseline is measured rather than assumed to be 5%. Simulations
keep fitted parameters fixed and are not refitted. Fits with convergence or Hessian
problems are recorded and excluded without retry; missing ordinal categories are
recorded as study exclusions. Undefined reference draws and warnings are retained.

Run from the repository root:

```sh
Rscript dev/diagnostic_checks/simulation-studies/sensitivity.R
Rscript dev/diagnostic_checks/simulation-studies/sensitivity.R 200 499 4 plot
```

Optional arguments are datasets per condition, reference draws, workers, and `plot`.
The second command refreshes saved summaries without refitting. Use one worker on
Windows. Seeds do not depend on worker count. A glmmTMB version with `ordinal()`
is required. Summary tables include 95% Wilson intervals; with 200 datasets, the
maximum Monte Carlo SE is about 3.5 percentage points.

## Raw versus model-centred checks

`compare-centering.R` covers the 20 supported families, plus zero-inflated Poisson
and hurdle NB2 models. Both checks use the same fitted model and reference
simulations for each dataset; only subtraction of the fixed-effect predictions
changes. The Gaussian example retains the original APIM data and seeds.

Actor and partner effects are 0.5 and 0.3. Predictors are standard normal with
partner correlation 0.3. Fitted models include these effects but omit the remaining
partner dependence. [family-margins.R](family-margins.R) specifies each distribution
and calibrates residual correlations of 0, 0.10, 0.30, and 0.50 **after subtracting
the true conditional response means**. Independent checks of these correlations
are saved alongside the results. Ordinal checks use category scores; zero-inflated
and hurdle checks use the combined outcome, including zeros.

The study saves paired plots, detection rates, paired differences, and fitting failures.
For positive residual correlations, detection requires the observed correlation to
exceed the upper 97.5th percentile of its simulated reference. Opposite-direction
flags are reported separately. Zero-correlation conditions count either tail,
showing how often the check flags a mismatch when no dependence was omitted.
Each family also has a false-alarm plot with black solid and dotted lines
for the two methods. Its 5% reference line is a benchmark, not a guaranteed rate.

```sh
Rscript dev/diagnostic_checks/simulation-studies/compare-centering.R
```

Optional arguments are generated datasets per condition, reference simulations
per fit, workers, `run` or `plot`, and comma-separated family names. Defaults are
`500 1000 8 run`, using all families. For example:

```sh
Rscript dev/diagnostic_checks/simulation-studies/compare-centering.R 500 1000 8 run gaussian,nbinom2,zi_poisson,hurdle_nbinom2
Rscript dev/diagnostic_checks/simulation-studies/compare-centering.R 500 1000 8 plot
```

Use one worker on Windows. Seeds do not depend on worker count. Progress is saved
every 25 datasets and at the end of each condition; rerunning resumes from the last
saved dataset. Outputs are in `results/family-comparison/<settings>/`. The `plot`
option redraws saved results without fitting models.

The complete default run renders the [full report](family-comparison.Rmd) and
updates the selected figures in the [vignette draft](../partner-dependence-vignette-draft.Rmd).
The report rebuilds its plots from saved summary tables. To change text, layout, colours,
or axes, edit the report or [plotting helper](plot-family-comparison.R) and render again:

```sh
Rscript -e 'rmarkdown::render("dev/diagnostic_checks/simulation-studies/family-comparison.Rmd")'
```

This does not generate data, fit models, or simulate responses. Changing the study
design or recomputing a different check requires a new run.
During a run, the report and vignette can show completed families and mark the rest
as pending.

Increasing reference simulations improves each fitted model's reference range;
increasing generated datasets improves the precision of the plotted detection rates.
The defaults are 1,000 reference simulations and 500 generated datasets per point.
The full run needs a glmmTMB version with `ordinal()` and the `gsl` package for Bell
simulations. Some families, especially COM-Poisson, take much longer to simulate.

## Tweedie simulation repair

The full run used glmmTMB commit `93c774717c0f10b600c25dd21f393d03155efc3f`.
Four Tweedie conditions stalled when fitted power approached 2: its sampler tried
to add millions of Gamma draws for each response. The two-line
[sampler patch](tweedie-sampler.patch) replaces that sum with one Gamma draw whose
shape is multiplied by the number of terms, matching TMB 1.9.25. This preserves
the distribution and fitting code, but changes random-number realizations.

The remaining 1,450 datasets in those conditions used the repaired sampler;
completed results were retained. Checks confirmed unchanged fitted parameters
and the expected simulation moments and zero probabilities. The patch, resumed
repetition ranges, and validation results are saved under
`results/family-comparison/tweedie-repair/`.

To build the same repair separately from the normal user library, run from the
repository root with TMB 1.9.25 and glmmTMB's build dependencies installed:

```sh
study_directory="$PWD/dev/diagnostic_checks/simulation-studies"
tweedie_library="$study_directory/results/tweedie-library"
mkdir -p "$tweedie_library"
git clone https://github.com/glmmTMB/glmmTMB.git "$study_directory/results/tweedie-source"
git -C "$study_directory/results/tweedie-source" checkout 93c774717c0f10b600c25dd21f393d03155efc3f
patch -d "$study_directory/results/tweedie-source" -p1 < "$study_directory/tweedie-sampler.patch"
R CMD INSTALL --library="$tweedie_library" "$study_directory/results/tweedie-source/glmmTMB"
R_LIBS="$tweedie_library" Rscript dev/diagnostic_checks/simulation-studies/compare-centering.R 500 1000 10 run tweedie
```

`R_LIBS` selects the local repair for this command while keeping the normal user
library available. It does not replace the normal glmmTMB installation. The saved
study combines both samplers, so a fresh run will not reproduce every draw exactly.

## Validation and fitting examples

```sh
Rscript dev/diagnostic_checks/simulation-studies/check-family-comparison.R
Rscript dev/diagnostic_checks/simulation-studies/validation.R
Rscript dev/diagnostic_checks/simulation-studies/fitting-examples/ordinal.R
Rscript dev/diagnostic_checks/simulation-studies/fitting-examples/lognormal.R
```

Validation defaults to 20 datasets, 199 reference simulations, and 200 dyads;
these are its three optional arguments. It checks positive and negative Gaussian
correlation, unequal SDs, exchangeable and role-specific summaries, and a reference
using the true parameters. Focused zero-inflated and hurdle examples compare both
dyad effects present with both omitted. It records all statistics on raw and
model-centred scales. These short runs check behavior, not precise flag rates.

Each fitting example uses one original dataset and the same random draws across
fitting methods. The ordinal example requires `ordinal` and a glmmTMB version with
`ordinal()`. The lognormal example retains integration-accuracy and optimizer checks.
They illustrate fitting discrepancies; they do not reproduce the old repeated-study
frequencies or establish how often a problem occurs.

## Saved results and previous investigations

Generated outputs are ignored under `results/`, with settings-specific folders for
sensitivity, family comparison, and validation. Fitting examples have their own
result folders. Family comparisons resume saved runs; the other scripts replace
their outputs when rerun with the same settings. The completed sensitivity results
were moved without refitting: they saved three statistics, with the other three
available for the SD follow-up. New sensitivity runs save all six throughout.
Historical population-correlation estimates are also preserved alongside these results.

The family comparison explicitly saves per-condition RDS checkpoints, per-dataset
statistics and fit diagnostics, summary tables, calibration, seeds, and session
information. The report reads these saved tables rather than relying on a knitr
cache. Interrupted runs can resume, and report edits do not invalidate the results.

The complete previous collection, including source, reports, seeds, and results,
is preserved locally in `results/before-consolidation-20260921.tar.gz`. Every archived
file was verified against its source before cleanup. This ignored archive retains
the larger studies, component-specific omissions, sparse-category controls, and
exploratory numerical probes without adding them to routine code review.

The superseded Gaussian APIM script mode and figure are archived with their saved
results in `results/before-apim-retirement-20260923.tar.gz`. Archived files were
verified against their originals before removal; `compare-centering.R` now covers
that design.
