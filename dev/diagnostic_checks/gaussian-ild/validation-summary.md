# Gaussian ILD Prototype Validation Record

Date: 2026-08-27

Branch baseline: pull-request head `b3857749c2741f3458c668d97223a71ad6d5b979`.

The prototype was developed and validated as a working-tree diff on that
baseline, then committed on the dedicated `gaussian-ild-prototype` branch.

Environment: R 4.6.1, `glmmTMB` 1.1.14,
`dyadMLM` 0.2.0.9000, x86_64 Fedora Linux.

This record reports engineering validation, not formal calibration or evidence
that the diagnostic has a universal pass/fail interpretation.

## Deterministic and fitted-backend checks

The focused package tests cover:

- equality between stable ILD summaries and the public cross-sectional check;
- independent member demeaning for every observed and simulated dataset;
- exact factor-level gaps, including distinct lag-1 and lag-2 correlations
  when a scheduled level is globally unobserved;
- distinguishable directions and exchangeable label-swap invariance;
- public dyad and edge weighting on an unbalanced panel, balanced equality,
  and hand-calculated weighted moments;
- unsupported lags, zero variance, partial simulated degeneracy, and the
  `n_defined + 1` observed-position convention, including a warning-free
  maximum-integer lag;
- fitted-row reordering and explicit-`NA` factor levels;
- unconditional `glmmTMB` simulation equivalence, omitted fitted rows,
  response-centre alignment, and model/RNG-state restoration; and
- fitted AR(1), dyad-occasion, and shared/difference process smoke tests,
  including a fitted-model-to-diagnostic end-to-end call.

The focused ILD test files and complete package test suite completed without
failures or warnings. An independent review found no discrepancy in the
exact-lag maps or in the prespecified `a_de` and `K / (K - 1)` moment formulas.

As a one-time historical refactor check, the compact implementation was run
beside the preceding validated implementation on the same shipped-data model
and all 199 simulated datasets. The maximum absolute difference was `2.22e-16`
for observed statistics and `4.44e-16` for simulated statistics (floating-
point noise). The ILD file fell from 1,425 to 902 lines; its calculation and
mapping core fell from about 1,093 to about 584 lines. The cross-sectional and
ILD paths now share one pair-moment kernel, statistic schema, reference
summarizer, and histogram helper. The old implementation is not retained as a
reproducible validation script; the exact tests and covariance oracles below
are the continuing checks.

## Shipped-data benchmark

Command:

```sh
Rscript dev/diagnostic_checks/gaussian-ild/benchmark-shipped-data.R
```

The shipped `dyads_ild` data contain 120 female-male, 120 female-female,
and 120 male-male dyads. The prototype correctly rejects pooling those
compositions under one role-aware check. The benchmark therefore selects the
female-male composition.

| Fitted rows | Dyads | Simulations | Statistics | Defined observed | Defined references |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 3,360 | 120 | 199 | 32 | 32 | 32 |

On the 2026-08-27 revalidation run, fitting, simulation, and the ILD check took
1.869, 0.168, and 0.806 seconds. The fitted model converged with a positive-
definite Hessian.

## Package integration

The final complete `devtools::test()` rerun passed 1,623 expectations with no
failures, warnings, or skips. Documentation was regenerated from roxygen, and
`git diff --check` reported no whitespace errors.

An exact source tarball was built, including package-vignette generation. Its
SHA-256 was:

```text
2dad18732041e931bf81a0230a82ed97e697874bb18ad9383a5a5c86c017f025
```

`R CMD check --as-cran` on that tarball passed installation, namespace and code
checks, documentation, examples, spelling, the complete test suite, rebuilt
vignettes, and the PDF and HTML manuals. Its single NOTE is the expected CRAN
incoming note for development version `0.2.0.9000` (and the recent-update
timing); the package check itself is otherwise clean.

## Outer simulation smoke and pilot profiles

The parameterized study source is
[`outer-simulation-study.Rmd`](outer-simulation-study.Rmd). Its standard
smoke profile rendered successfully with:

- 3 outer repetitions;
- 49 fitted-model simulations per check;
- 40 dyads and 12 scheduled occasions; and
- 6 fitted scenarios per repetition.

All 18 fitted scenario runs converged with positive-definite Hessians. All 18
checks completed, with no recorded warnings, fit errors, Hessian problems, or
check errors. After limiting the fitted core to its prespecified lag-1 target,
median fit times ranged from 0.017 to 0.495 seconds and median diagnostic times
from 0.068 to 0.098 seconds across the six cells.

The predefined pilot profile then rendered successfully with 20 outer
repetitions, 199 simulations per check, 60 dyads, and 16 occasions. All 120
fitted scenarios converged with positive-definite Hessians and all 120 checks
completed, again with no warnings, fit errors, Hessian problems, or check
errors. Median fit times by scenario ranged from 0.025 to 1.142 seconds; median
diagnostic times ranged from 0.281 to 0.442 seconds.

Every targeted restriction moved in its prespecified qualitative direction in
all 20 pilot repetitions:

| Restricted scenario | Target | Median observed | Median reference | Median position |
| --- | --- | ---: | ---: | ---: |
| Stable covariance omitted | Stable partner correlation | 0.578 | 0.005 | 1.000 |
| Concurrent covariance omitted | Concurrent partner correlation | 0.602 | 0.000 | 1.000 |
| One pooled AR process | Role 1 lag-1 correlation | 0.649 | 0.392 | 1.000 |
| One pooled AR process | Role 2 lag-1 correlation | 0.114 | 0.391 | 0.005 |

These rates remain pilot integration evidence. Twenty repetitions are useful
for checking completion and strong qualitative sensitivity but do not estimate
power, specificity, coverage, or error rates. Under the correctly specified
fitted cells, the selected median observed positions ranged from 0.290 to 0.640
and the corresponding descriptive outside-interval rates ranged from 0 to
0.15.

Known-mean finite-series covariance calculations closely reproduced the pilot
medians. These are analytic DGP benchmarks, not exact expectations after
estimating the fixed-effect centre and calculating a finite-dyad sample
statistic:

| Diagnostic-scale summary | Analytic DGP benchmark | Pilot median |
| --- | ---: | ---: |
| Member-mean correlation in the stable population | 0.588 | 0.578 |
| Same-occasion correlation in the concurrent population | 0.600 | 0.602 |
| Member 1 demeaned AR lag-1 correlation | 0.652 | 0.649 |
| Member 2 demeaned AR lag-1 correlation | 0.118 | 0.114 |
| Restricted pooled AR lag-1 reference | 0.392 | 0.391 |

The revalidation exposed and corrected one interpretation error in the study.
The shared/difference process control does not isolate cross-lag behavior after
finite-series member demeaning. At 16 occasions, its exact concurrent, own-
lag-1, and cross-lag-1 targets are -0.213, 0.325, and 0.181; the correct-
reference medians were -0.199, 0.326, and 0.182. Under the restricted .50/.50
reference, the exact targets are 0, 0.392, and 0; the corresponding medians
were 0.011, 0.393, and 0.003. The diagnostic was correct; the former claim that
the control preserved concurrent and own-lag summaries was not.

The exact-gap fixture also completed. In the rerun of the previous unequal-
series simulation, the lag-1 reference median was 0.168 under dyad weighting
and 0.343 under edge weighting. An independent covariance oracle gives exact
finite-series targets of 0.1683 and 0.3446. The study now uses those exact
values directly instead of spending another 99--199 simulations to estimate
them.

## Remaining promotion boundaries

- `glmmTMB` 1.1.14 drops globally unused AR(1) factor levels. An aligned
  external factor preserves the diagnostic edge map but cannot repair a
  covariance state already omitted from the fitted model. Every scheduled AR
  level must be represented, or the analysis needs a genuinely gap-aware
  structure such as a suitable positive-decay OU model.
- With `role = NULL`, substantive dyad composition cannot be inferred;
  mixed compositions must be subset by the caller.
- The current evidence is Gaussian identity-link and plug-in predictive. It
  does not establish non-Gaussian residual targets, parameter-uncertainty
  propagation, recursive VAR simulation, cross-validation, or formal
  goodness-of-fit calibration.
- The former 200-by-499 full profile was removed because no formal calibration
  estimand had been defined and the strong pilot targets were already
  saturated. If promotion later requires population error-rate claims, design
  a separate calibration study after the estimands and model cells are fixed.
