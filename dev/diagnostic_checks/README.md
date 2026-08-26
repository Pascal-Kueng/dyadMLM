# Cross-Sectional Gaussian Partner-Dependence Checks

This document is the implementation and review specification for the current
partner-dependence feature. The supported workflow is deliberately narrow:
cross-sectional Gaussian identity-link models fitted with `glmmTMB`.

The public interface is experimental. The source code, generated documentation,
and tests are authoritative when they differ from this development note.

## Purpose and supported scope

The feature asks whether a fitted model reproduces the observed variation and
same-dyad association of two partner responses. It consists of:

- `simulate_dyad_responses()`, which creates complete model-generated response
  datasets; and
- `check_partner_dependence()`, which compares the same partner summaries in
  the observed and simulated datasets.

The constructor enforces the response, model, weight, and zero-inflation
requirements below. Once a dyad identifier is supplied,
`check_partner_dependence()` enforces the cross-sectional pairing restriction.
The validated workflow is:

- one numeric response per fitted row;
- cross-sectional data with at most two fitted rows per supplied dyad;
- a Gaussian identity-link `glmmTMB` model;
- unit case weights; and
- no zero-inflation component.

The check requires at least three complete dyads. A supplied role variable must
contain exactly two role values among complete dyads, with one row for each role
within every complete pair.

## Predictive-reference target

For fitted parameters `theta_hat` and the fitted-row design, the constructor
generates complete response datasets from the fitted model:

```text
observed statistic:   T(y)
simulated statistic:  T(y_rep)
```

The fitted parameters and design remain fixed. Random effects at every modeled
grouping level and Gaussian observation errors are newly generated for every
replicate. When dyads are the only grouping factor, the simulations can be
interpreted as hypothetical model-generated new dyads observed under the same
design.

This is a full-data plug-in predictive reference. The model is not refitted,
parameter uncertainty is not propagated, and no observations are held out. It
is therefore not cross-validation.

The model's stored simulation settings are mutable. The constructor saves their
exact values, requests unconditional simulation, and restores the original
values after both successful simulation and errors.

## Public workflow

```r
simulations <- simulate_dyad_responses(
  model,
  nsim = 1000,
  seed = 123
)

partner_check <- check_partner_dependence(
  simulations,
  dyad = couple_id,
  role = gender,
  plot = FALSE
)

print(partner_check)
plot(partner_check)
```

`dyad` and `role` may be unquoted or quoted fitted-model-frame column names,
or vectors aligned with the fitted rows. Pairing always uses fitted-row indices,
not source-data row order.

## Response representations

`check_partner_dependence()` offers two response representations:

- `response = "model-centred"` is the default. It subtracts the same
  row-specific response centre from the observed response and every simulated
  response.
- `response = "raw"` leaves the observed and simulated responses unchanged.

For the supported Gaussian identity-link model, the centre is the prediction
with random effects set to zero. It is also the expected response after
averaging over newly generated zero-mean random effects under the fitted
parameter estimates. Subtracting it removes the fitted marginal mean pattern
while retaining newly generated random-effect and observation-level variation.

Raw summaries retain both the fitted mean pattern and dependence. Both
representations reuse the same complete simulations.

## Pairing and omitted rows

The check builds one pair map and applies it unchanged to the observed response
and every simulated dataset.

- Rows with missing dyad identifiers are omitted and counted.
- When roles are supplied, rows with missing roles are omitted and counted
  separately.
- Dyads with fewer than two usable rows are counted as incomplete.
- A dyad with more than two fitted rows is rejected.
- Complete role-aware pairs are oriented by the role values rather than row
  order.

The printed number of pairs always means complete cross-sectional dyads in this
feature.

## Partner summaries

### Distinguishable dyads

When `role` is supplied, the member view reports:

- the SD for role 1;
- the SD for role 2; and
- the partner correlation.

The equivalent mean/difference view reports:

- Dyad-average SD;
- Half-difference SD, with the role direction shown; and
- Dyad-average/role-difference correlation.

These are two parameterizations of the same paired covariance information, not
independent tests.

### Interchangeable dyads

When `role = NULL`, members are assumed to be substantively interchangeable.
The member view reports:

- Common member SD (exchangeable); and
- Partner correlation (exchangeable).

The equivalent mean/difference view reports:

- Dyad-average SD; and
- Half-difference RMS (about zero).

The half-difference is summarized about zero so that arbitrary member swaps do
not change the result.

## Output and interpretation

The returned `dyadMLM_partner_check` object contains the observed statistics,
the complete replicated-statistic matrix, and for every summary:

- the observed value;
- the simulated median;
- the middle 95% of simulated values; and
- the observed position among the simulated values.

The observed position is descriptive and is not a p-value. The middle 95%
interval is a predictive-reference summary, not a calibrated acceptance region.

This check is most useful when the model makes a clear simplifying assumption
that could be wrong. If the model was allowed to learn the same pattern freely
from the data, a close match is expected and mostly repeats what the model
already learned. For example, when a model assumes no remaining relationship
between partners' responses, the correlation result can reveal a problem,
while the amount-of-variation results may mainly repeat values the model was
allowed to estimate.

Plots show a histogram of each simulated summary, the observed value, and the
middle 95% interval. The subtitle states whether raw or model-centred responses
were used and reports the number of complete pairs.

A check asks whether the fitted model reproduces a selected observed feature. It
does not test whether partner correlation is zero, prove that every covariance
component is correctly assigned, or validate model-based standard errors.

## Validation and review

Deterministic package tests cover:

- supported and unsupported model classes, families, links, weights, and
  zero-inflation structures;
- response dimensions, fitted-row alignment, and seeded reproducibility;
- unconditional simulation and restoration of model simulation settings after
  success and error;
- bare, quoted, and externally supplied dyad and role identifiers;
- row reordering, member swapping, missing identifiers, incomplete pairs, and
  invalid role structures;
- direct agreement with manually calculated raw and model-centred summaries;
- distinguishable and interchangeable covariance identities;
- simulated medians, intervals, and observed positions; and
- concise printing, plotting, and invisible returns.

The focused end-to-end review is
[`partner-dependence-review.Rmd`](partner-dependence-review.Rmd). It uses the
shipped `dyads_cross` data to compare intended and constrained models for both
role-distinguishable and interchangeable dyads. The extended
[`partner-dependence-vignette-draft.Rmd`](partner-dependence-vignette-draft.Rmd)
exercises the same public workflow across a fuller cross-sectional model
sequence.

The independent
[`partner-dependence-reference-validation.Rmd`](partner-dependence-reference-validation.Rmd)
reconstructs the Woody--Sadler exchangeable-dyad calculation and records the
supplementary Dingy software cross-check.

The self-contained
[`partner-dependence-outer-simulation-study.Rmd`](partner-dependence-outer-simulation-study.Rmd)
repeatedly generates data from known Gaussian populations, refits correct and
restricted models, and records how the complete check behaves. It is a
development validation report and is not run in CI.

Before review or merge, regenerate the Rd files, run the focused and full test
suites, render the development documents, run the package check, and verify CI
on the exact PR head.

## Explicit exclusions

This PR does not implement or define a contract for:

- `brms`;
- intensive longitudinal or repeated dyad-occasion data;
- non-Gaussian families or non-identity links;
- response-distribution or temporal-dependence checks;
- leave-one-dyad-out cross-validation;
- refit-based calibration or formal hypothesis tests;
- parameter-uncertainty propagation;
- dense covariance whitening; or
- a DHARMa wrapper, generic adequacy score, or pass/fail verdict.

Those are separate features and should be developed and reviewed independently.

## File map

```text
R/simulate_dyad_responses.R
R/predictive_checks_dependence.R
man/simulate_dyad_responses.Rd
man/print.dyadMLM_response_simulations.Rd
man/check_partner_dependence.Rd
man/print.dyadMLM_partner_check.Rd
man/plot.dyadMLM_partner_check.Rd
tests/testthat/test-simulate-dyad-responses.R
tests/testthat/test-predictive-checks-dependence.R
dev/diagnostic_checks/partner-dependence-review.Rmd
dev/diagnostic_checks/partner-dependence-reference-validation.Rmd
dev/diagnostic_checks/partner-dependence-outer-simulation-study.Rmd
dev/diagnostic_checks/partner-dependence-vignette-draft.Rmd
```
