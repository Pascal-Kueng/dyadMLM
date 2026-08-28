# Gaussian ILD Partner-Dependence Prototype

This sub-folder contains the implementation review material for the Gaussian
intensive-longitudinal extension of the cross-sectional partner-dependence
check. It is intentionally isolated from any future non-Gaussian extension:
the two features have different statistical targets and should not share a
prototype branch.

## Scope

The prototype reuses `simulate_dyad_responses()` and activates the ILD path
of `check_partner_dependence()` when both `member` and factor-valued
`time` are supplied. It currently requires:

- a Gaussian identity-link `glmmTMB` fit;
- exactly two stable member identities per dyad and at least three dyads;
- one dyad-member-time row at most;
- one composition per check, with two stable roles when `role` is used;
- a factor whose complete level sequence represents equally spaced scheduled
  occasions; and
- finite responses on the fitted rows.

The complete factor-level sequence is substantive. An externally supplied
aligned factor can retain a globally unobserved occasion for the diagnostic
edge map, but it cannot repair the fitted covariance after `glmmTMB` has
dropped that AR(1) state. An AR(1) predictive reference therefore requires
every scheduled level to be represented in the fitted structure. A genuinely
gap-aware alternative such as `ou(0 + numFactor(time) | series)` may be
appropriate when its positive-decay assumptions match the analysis.

The function cannot infer substantive composition when `role = NULL`.
Subsetting mixed exchangeable compositions before the check is therefore a
caller responsibility and remains an explicit promotion boundary.

## Diagnostic contract

For the observed response and every complete simulated response dataset, the
prototype independently recomputes:

1. stable partner dependence from each member's available-series mean;
2. concurrent dependence from paired within-member deviations at the same
   scheduled occasion;
3. own-member correlations at exact positive lags; and
4. cross-member correlations at exact positive lags, role-directed when roles
   are supplied and pooled over both directions otherwise.

The implementation builds the row and edge maps once, decomposes each response
dataset once, and applies the shared pair-statistics kernel to each reported
curve. Each curve is one pooled weighted pair correlation; it is not an
average of separate per-occasion, per-dyad, or per-series correlations. Such
averages would define different estimands and would often be unstable for
sparse occasions.

Lag edges are differences in factor-level position, not adjacency between
observed rows. A missing intermediate observation therefore never turns a
lag-2 edge into lag 1.

`weighting = "dyad"` gives each eligible dyad total weight one within each
reported statistic. For a pooled exchangeable cross-lag statistic, both
directions share that total dyad weight. `weighting = "edge"` instead gives
each eligible pair or lag edge equal weight. Both use the prespecified cluster
correction `K / (K - 1)`; stable summaries contain one member-mean pair per
dyad and therefore do not depend on the weighting choice.

The default is equal-dyad weighting because the dyad is the independent
sampling unit; equal-edge weighting remains an explicit sensitivity estimand
when series lengths differ.

These are predictive sample summaries, not estimates of mutually exclusive
latent components. Stable dependence describes available-series member means;
concurrent and lagged dependence describe responses centred by each dataset's
own member means. Finite-series averaging and demeaning therefore couple the
four views. Their comparison remains valid because the identical transformation
is applied to the observed response and every simulated dataset under the same
fitted-row design.

Requested but unsupported lags stay in the statistics table with their
contributing dyad and edge counts.
Reference summaries are drawn only when at least 20 and at least 95 percent of
the simulated values for that statistic are defined. Observed positions and
pointwise simulation intervals are descriptive model checks, not p-values or
formal calibration statements.

The returned statistics table records weighting, structural support, the
defined-simulation threshold, and observed/reference reasons in one place.
Printed output reports the defined count for each statistic, and profile plot
subtitles show contributing dyads/edges as `K/E` for every lag. Exact row and
edge maps remain available in `maps` for auditing.

## Validation layers

The prototype is reviewed at four levels:

- deterministic hand calculations and exact map tests in
  `tests/testthat/test-predictive-checks-dependence-ild.R`;
- fitted-backend, row-alignment, state-restoration, and structured-covariance
  tests in `tests/testthat/test-simulate-dyad-responses-ild.R`;
- an end-to-end benchmark on the female-male composition of the shipped
  `dyads_ild` data, reproduced by
  [`benchmark-shipped-data.R`](benchmark-shipped-data.R); and
- the parameterized outer study in
  [`outer-simulation-study.Rmd`](outer-simulation-study.Rmd).

The exact environment, shipped-data timings, smoke/pilot results, and
remaining boundaries are recorded in
[`validation-summary.md`](validation-summary.md).

The outer study has smoke and pilot profiles. It records failed or singular
fits instead of retrying them and separates fitted-model checks from known-
parameter controls where `glmmTMB` cannot express the relevant recursive
cross-lag data-generating process. Analytic finite-series DGP benchmarks and
exact known-parameter controls give the statistical reference; the repeated
fits are integration and sensitivity checks, not a calibration study.

## Boundaries

This prototype does not claim support for non-Gaussian families, generalized
residuals, recursive VAR simulation, parameter uncertainty, cross-validation,
formal goodness-of-fit tests, or automatic adequacy decisions. In particular,
lagged outcomes used as fixed predictors are not regenerated recursively by
`simulate.glmmTMB()` and are not a valid unconditional simulation
workaround.

Promotion beyond a prototype should require successful package checks, exact
hand agreement, stable fitted-backend completion, defined-reference audits,
and simulation review. A larger calibration study is warranted only after a
formal calibration target is specified; more repetitions do not resolve
estimand or API choices.

Run the shipped-data benchmark from the package root with:

```sh
Rscript dev/diagnostic_checks/gaussian-ild/benchmark-shipped-data.R
```
