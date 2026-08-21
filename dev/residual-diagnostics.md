# Simulation-Based Dyadic Diagnostics

Implementation specification for the `residual-diagnostics` branch. This file
is authoritative for the feature; `roadmap.md` records only the release
sequence. If a choice is marked **deferred**, do not infer an answer while
implementing an earlier milestone.

## Goal

Provide visual predictive checks for questions that ordinary residual
diagnostics do not answer reliably when observations remain dependent:

- Does the fitted model reproduce important features of the observed response
  distribution?
- For ILD data, does it reproduce the observed temporal dependence?
- Does it reproduce the observed same-occasion partner dependence?

The checks compare the same statistic or curve in the observed data and in
complete response datasets simulated from the fitted model:

\[
T_{obs} = T(y), \qquad T_{rep,b} = T(y^{rep}_b).
\]

Each replicated dataset must preserve the fitted model's complete dependence
structure. The observations within one dataset are therefore allowed to remain
correlated; the dataset, not an individual row, is the simulation unit.

Plots are the primary output. Printed numbers describe a plot and must not turn
it into a binary adequacy test.

The eventual workflow should be:

```r
simulations <- simulate_dyad_responses(model, nsim = 1000, seed = 123)

partner_check <- check_partner_dependence(
  simulations,
  dyad = "couple_id"
)

plot(partner_check)
partner_check
```

## Fixed design decisions

1. Preserve every complete simulated response dataset. Never simulate or
   diagnose one partner, one occasion, or one observation independently of the
   fitted joint model.
2. Use one set of complete replicates for direct predictive checks. There is no
   reference/evaluation split and no PIT-rank transformation. Such a split
   would be needed only if a future diagnostic first estimated a rowwise
   transform from simulations and then tested that transform.
3. A check may use either the raw response or a fixed model-centered response,
   but it must apply exactly the same operation to the observed data and every
   complete replicate.
4. Do not reconstruct or whiten with a dense fitted covariance matrix. The
   model engine already generates the joint response datasets needed here.
5. Keep the computational core independent of DHARMa. Do not add a DHARMa
   dependency, return a DHARMa object, or expose its standard residual tests as
   if their residuals were independent. This design corresponds to DHARMa's
   recommended alternative of explicitly comparing observed and simulated
   dependence statistics.
6. Use unconditional `glmmTMB` simulations. Fitted parameters remain fixed and
   new random effects and responses are generated from the complete fitted
   model. Label this a **plug-in predictive reference**.
7. Use `check_*`, not `test_*`, names. Do not return `p.value`, significance
   stars, a pass/fail label, or a combined model-adequacy score.
8. A central replicated interval is descriptive. A pointwise 95% curve envelope
   is not a simultaneous 95% test. Exact frequentist-style calibration is a
   separate, deferred feature.
9. Keep convergence, optimizer, Hessian, sampling, influence, missingness, and
   model-comparison diagnostics outside this feature. They are not specifically
   dyadic and are handled by model engines or separate workflows.
10. Document the feature as experimental. Do not emit a warning merely because
    it is experimental; warnings are reserved for a concrete unsafe condition.

## What these checks answer

A dependence check does **not** test whether correlation is zero. It asks
whether the fitted model generates datasets with dependence like that observed.
For example, an adequate fitted AR(1) model should reproduce a nonzero observed
lag-1 association.

Predictive checks and model comparison are complementary:

- a predictive check asks whether the retained model reproduces an observed
  feature;
- model comparison asks whether adding, removing, or constraining a covariance
  component improves relative fit.

A flexible covariance parameter estimated from the same data can make a
partner check forgiving. A multi-lag temporal curve can still reveal an
incorrect decay pattern even when an AR-versus-no-AR comparison favors AR.

## Reuse model-engine simulation

Keep backend-specific code thin. `dyadMLM` must not reproduce family, link,
dispersion, zero-inflation, random-effect, or autocorrelation simulation code.

### Initial `glmmTMB` backend

- Use `stats::simulate()` to obtain complete response replicates from the
  fitted model, including all supported random effects and structured
  covariance terms.
- Normalize its result immediately to `simulation x fitted row` and validate
  the orientation and row alignment.
- Do not construct a fitted covariance matrix or use
  `TMB::oneStepPredict()` in the public workflow.
- Do not make DHARMa or `performance::check_model()` part of the runtime core.
  They remain useful development comparators for ordinary diagnostics.

The initial implementation supports scalar-response, Gaussian identity-link
`glmmTMB` models. Additional grouping levels, random slopes, supported
structured covariance terms, offsets, and nonconstant Gaussian dispersion are
allowed because `simulate.glmmTMB()` owns their simulation.

Reject other model classes, families, links, matrix responses, non-unit case
weights, and any nonzero zero-inflation formula clearly in this first
milestone. Treat absent weights as unit weights. Generalized families are added
only through the family-by-family validation milestones below.

`glmmTMB` simulation codes are mutable. Before simulation:

1. save the current codes;
2. register restoration with `on.exit()` immediately;
3. set every random-effect term to unconditional (`"random"`) simulation;
4. restore the original codes after both success and error.

Never leave persistent simulation settings changed on the fitted model.

## Shared simulation object

### Shared constructor

```r
simulate_dyad_responses(model, nsim = 1000, seed = NULL)
```

Keep this constructor internal while the first checks are being reviewed. It
can become public once its output contract is exercised by a complete check.

`nsim` is the number of complete simulated datasets. Require one positive whole
number and recommend 1000 for ordinary plots. Smaller values remain useful for
quick smoke tests. All simulations contribute directly to every replicated
statistic or curve.

Return class `dyadMLM_response_simulations` with these fields:

```text
observed_response        numeric vector in fitted-model row order
simulated_responses      numeric matrix: simulation x fitted row
fitted_response          deterministic random-effects-excluded response center
model_frame              fitted model frame in the same row order
backend                  "glmmTMB"
family                   "gaussian"
link                     "identity"
reference                "plug-in predictive"
random_effects           "new"
nsim                     number of complete simulations
seed                     supplied seed or NULL
call                     constructor call
```

Extract the response and model frame from the fitted model, not from an object
in the calling environment. Verify finite observed values, simulated values,
and fitted means. A supplied seed must reproduce the complete object.

For `glmmTMB`, calculate `fitted_response` with
`predict(model, newdata = NULL, type = "response", re.form = NA)`. Explicit
`newdata = NULL` keeps the result in fitted-row order when `na.exclude` was used.
It is the same deterministic response-scale center for the observed data and
every unconditional replicate.
For the initial Gaussian identity-link scope, this is the population-level
mean. Do not subtract empirical-Bayes or BLUP effects estimated for the observed
groups while the replicates contain newly generated effects.

Do not store a dense covariance matrix or the full fitted model unless a later
concrete operation requires it.

## Raw and model-centered checks

Raw-response checks apply the same function directly:

```r
observed_statistic <- statistic(observed_response)
replicated_statistic[b] <- statistic(simulated_responses[b, ])
```

These are appropriate for observable features such as zero frequency,
rootograms, response quantiles, spread, and tail counts.

Dependence and conditional-pattern checks use:

```r
observed_centered <- observed_response - fitted_response
simulated_centered <- sweep(
  simulated_responses,
  MARGIN = 2,
  STATS = fitted_response,
  FUN = "-"
)
```

These centered values are neither independent nor whitened residuals. Their
remaining modeled dependence is intentional and is represented in the
replicated reference distribution.

## Version 0.2.1: cross-sectional partner dependence

### Public check

```r
check_partner_dependence(simulations, dyad, role = NULL)
```

Resolve `dyad` and optional `role` as either:

- one character column name in `simulations$model_frame`; or
- an explicit vector whose length equals the number of fitted rows.

Do not use tidy evaluation and do not guess how a source-data vector maps
through model omissions. The explicit-vector route lets users supply an
identifier that was not in the model formula.

For the initial cross-sectional check:

- exclude missing dyad identifiers and report the number of omitted rows;
- omit and report dyads represented by only one fitted response;
- error if any remaining dyad has more than two fitted responses;
- require at least three complete pairs;
- never assign roles from row order.

When `role` is supplied, omit rows with missing roles and report
`n_missing_role_rows`. Count a dyad made incomplete by that omission among
`n_incomplete_dyads`. After omissions, error if a usable dyad does not contain
exactly one row of each of the two role values.

### Frozen statistics

Let `e` be the fixed-model-centered response.

When `role` is supplied, require exactly two role values and exactly one row of
each role in every usable dyad. Orient every pair by those values and calculate
the Pearson correlation between the two role-specific centered responses
across dyads.

When `role = NULL`, use the label-invariant symmetric coefficient

\[
T_{partner} =
\frac{2\sum_d e_{d1}e_{d2}}
     {\sum_d(e_{d1}^2 + e_{d2}^2)}.
\]

This value is unchanged if the two members are swapped within any dyad. Call it
a **symmetric partner-dependence coefficient**, not a latent Gaussian
correlation. Require a finite positive denominator.

Calculate the selected statistic once for the observed centered response and
once for every complete simulated dataset, using one shared internal statistic
helper. If any replicated statistic is non-finite, stop clearly in the initial
Gaussian milestone rather than silently dropping simulations.

Return class `dyadMLM_partner_check` with:

```text
statistic                  descriptive statistic name
observed_statistic         scalar
replicated_statistics      numeric vector of length nsim
replicated_median          scalar
replicated_interval        named 2.5% and 97.5% limits
observed_percentile        (1 + sum(replicated <= observed)) / (nsim + 1)
n_pairs                    complete fitted dyads used
n_incomplete_dyads         one-row dyads omitted
n_missing_id_rows          rows omitted for missing dyad ID
n_missing_role_rows        rows omitted for missing role, or zero
reference                  copied from simulations
random_effects             copied from simulations
nsim                       copied from simulations
seed                       copied from simulations
call                       check call
```

`observed_percentile` describes the observed value's position among the
replicates. It is not a p-value and has no automatic cutoff.

### Plot and interpretation

Implement `plot.dyadMLM_partner_check()` with base R:

- a histogram of replicated statistics;
- a solid neutral line for the observed statistic;
- dashed lines for the central replicated 95% interval;
- an x-axis containing the observed and all replicated values;
- the number of usable pairs and predictive-reference type;
- no red/green significance coding.

The intended reading is: "Does the fitted model generate datasets with
same-occasion partner dependence like the observed data?"

A surprising value means the complete model does not reproduce this selected
response-scale feature. It does not identify whether the mean, marginal
distribution, dispersion, random effects, or partner covariance is responsible.
For version 0.2.1, inspect the response distribution and ordinary model-engine
diagnostics separately before assigning the discrepancy to partner dependence;
package-native marginal predictive checks arrive in 0.2.3. Do not interpret
ordinary rowwise residual tests as calibrated dyadic tests. For generalized
models, never interpret the partner statistic as the fitted latent correlation.

Use model comparison to decide whether a covariance term is needed or whether
exchangeability constraints are supported. A typical predictive value alone
does not prove the latent covariance structure correct.

Same-occasion partner checks for ILD data require an explicit occasion
identifier and are **deferred**. The first function accepts one pair per dyad.

## Version 0.2.2: Gaussian ILD temporal dependence

### Public check

```r
check_temporal_dependence(
  simulations,
  dyad,
  member,
  time,
  lags = NULL
)
```

Resolve identifiers using the same character-name or fitted-row-aligned vector
contract as the partner check. Require numeric time values and at most one
response for each dyad-member-time combination. Construct every series
explicitly from `dyad` and `member`; never concatenate series.

Omit rows with missing dyad, member, or time identifiers and report the count
for each identifier. Reject infinite time values. Require at least one usable
member series after these omissions; individual lags have the stronger edge
requirements below.

For the first implementation, support regularly scheduled integer time. Define
the largest observed scheduled gap as the largest positive exact pairwise time
difference available within any usable fitted member series. With `lags = NULL`,
use unit lags from 1 through the smaller of 5 and that largest gap. An explicit
`lags` vector must contain distinct positive whole numbers. Irregular
continuous-time bins for `ou()` models are **deferred** until their boundaries
and tolerances are specified and calibrated.

Missing scheduled occasions remain missing. Construct edges from actual time
differences, so observations at times 1 and 3 contribute to lag 2 and never to
lag 1 merely because they are adjacent rows.

### Frozen temporal curve

For both observed and replicated centered responses:

1. subtract each fitted member series' mean from its centered values;
2. for each requested lag, collect all within-series pairs separated by that
   exact scheduled lag;
3. calculate `cor(earlier_values, later_values)` across all eligible edges.

Call this a **pooled lag correlation**, not a conventional per-series ACF
estimator. It is pair-weighted: longer series contribute more temporal edges.
Require at least three eligible pairs and nonzero variation for a displayed
lag; omit and report unsupported lags based on the observed design. If the
statistic is undefined in any Gaussian replicate for an otherwise supported
lag, stop clearly rather than discarding that replicate. Apply the identical
centering, edge construction, and correlation calculation to every complete
replicate. The simulations therefore include the finite-series effect of
demeaning.

Return class `dyadMLM_temporal_check` with the observed curve, an
`nsim x n_lags` replicated-curve matrix, pointwise replicated medians, 50% and
95% intervals, eligible-pair counts, omission counts, reference metadata, seed,
and call.

Implement `plot.dyadMLM_temporal_check()` as an observed multi-lag curve over
pointwise 50% and 95% simulation envelopes. Label the envelopes explicitly as
pointwise. Do not run separate significance tests at every lag.

Do not report a single global tail probability in the first implementation. A
global numerical check requires a separately frozen whole-curve discrepancy
and calibrated reference and belongs with the deferred formal-testing work.

The first temporal curve addresses own-member persistence only. Same-occasion
partner dependence, cross-partner lead/lag dependence, role-specific curves,
and couple-mean/member-difference curves are separate questions and are
**deferred**.

The exact-gap construction and within-series centering in
[`workshop/helpers.R`](workshop/helpers.R) are useful development references.
Do not copy that helper's DHARMa mutation, p-value output, or dense whitening.

## Versions 0.2.3-0.2.4: generalized validation

The complete-replicate architecture is family-neutral, but support is not
claimed merely because `simulate()` runs. Validate scalar-response families one
at a time, beginning with negative binomial and then the applied Tweedie case.

Start generalized validation with direct response-scale checks:

- zero frequency when scientifically meaningful;
- spread and tail behavior;
- response quantile, ECDF, or rootogram envelopes;
- model-centered response patterns over fitted values.

Each display must compare the identical statistic or curve in the observed and
complete replicated datasets. A predictive quantile envelope is not an iid
normal or uniform QQ plot. Bernoulli zeros represent prevalence, not a separate
zero-inflation process.

Then validate the same partner and temporal statistics. Their interpretation is
response-scale adequacy: a simplified generalized random-effects structure may
be acceptable if its complete replicates reproduce the observed dependence.
Failure does not identify which latent component should be added.

Individual observation-level PIT outlier flags are **deferred**. They would need
a separately specified predictive reference or analytical CDF and must not be
smuggled back in through the removed simulation split.

The items in this generalized section are roadmap targets, not yet frozen
implementation specifications. Before supporting a family, define each exact
statistic and its behavior for ties, zero variance, and non-finite replicated
values. Never silently discard a discrete replicate for which a correlation is
undefined.

Version 0.2.3 covers generalized cross-sectional marginal and partner checks.
Version 0.2.4 combines only those validated families with the temporal edge
construction accepted in 0.2.2.

## Later `brms` backend

Keep the downstream statistics, result objects, and plots backend-neutral.
Only replicate generation, centering, and predictive-reference metadata differ.

### Raw-response checks

Use every complete dataset returned by `brms::posterior_predict()`. Never replace
posterior-predictive draws with their means or medians before calculating a
statistic. Raw response-distribution checks can then use the shared comparison
code. The frozen partner and temporal checks use the model-centered path below.

### Model-centered checks

When centering is needed, pair each posterior-predictive draw with the expected
response from the same posterior draw:

\[
e_{obs,s} = y - \mu_s, \qquad
e_{rep,s} = y^{rep}_s - \mu_s.
\]

Obtain `y_rep` and `mu` from matching `posterior_predict()` and
`posterior_epred()` draw IDs. The observed centered statistic is then
draw-specific; do not present one fixed observed red line as if it were the
`glmmTMB` plug-in target.

For a scalar statistic, store the paired vectors `observed_statistics` and
`replicated_statistics` and calculate

\[
D_s = T(y^{rep}_s - \mu_s) - T(y - \mu_s).
\]

Summarize and plot the distribution of `D` against zero. For curve-valued
checks, store and display the corresponding paired difference curves. Do not
compare the two marginal statistic distributions independently. The statistic
and curve helpers remain backend-neutral even though the compact comparison
object differs from the single-observed-value `glmmTMB` object.

### Group-effect target

Expose the predictive target explicitly:

- `group_effects = "existing"`: retain posterior effects for the fitted group
  levels and use the matching conditional expected response as `mu`. This
  checks remaining dependence conditional on the learned group effects, not
  whether those effects reproduce total population dependence;
- `group_effects = "new"`: relabel all grouping factors while preserving their
  nesting and crossing, then use `allow_new_levels = TRUE` and
  `sample_new_levels = "gaussian"` to generate fresh effects. Center both the
  observed and replicated response on the matching posterior draw's
  random-effects-excluded expectation (`re_formula = NA`), so newly generated
  group effects remain part of the dependence being checked.

The new-group target most closely matches unconditional `glmmTMB` simulation.
Do not subtract a newly sampled group effect from the observed response because
that effect does not belong to the observed group. Nested, crossed,
multi-membership, and special grouping structures require dedicated validation;
unsupported structures must fail clearly.

An existing-group raw predictive check can assess total response reproduction,
but it may be forgiving because those group effects were learned from the same
groups. State the chosen target in every result and plot.

Include fitted autocorrelation in predictions (`incl_autocor = TRUE`). Validate
covariance-form AR models first. Response-dependent regression-form AR/ARMA and
any required out-of-sample handling remain **deferred** until end-to-end tests
establish that complete recursive replication is correct.

Label `brms` results **posterior predictive**, not plug-in predictive.
Posterior-predictive tail areas remain discrepancies, not frequentist p-values.
Do not refit a Bayesian model separately for every posterior-predictive draw.

Use `bayesplot` for mature generic posterior-predictive displays when it removes
code. `dyadMLM` still owns fitted-row alignment, dyad pairs, temporal edges,
dyadic statistics, and their interpretation.

## Validation before export

### Package regression tests

Keep CRAN tests small and deterministic. Test code correctness rather than
whether one random dataset crosses a percentile threshold:

- class, fields, dimensions, orientation, row order, and seed reproducibility;
- model-class, family, link, weight, and response validation;
- simulation-code restoration after both success and error;
- direct agreement of the fixed response center with population-level fitted
  values;
- direct agreement with manually calculated observed and replicated statistics;
- identical observed/replicated statistic code paths;
- invariance of the exchangeable statistic to member swapping;
- role validation for distinguishable dyads;
- missing identifiers, incomplete pairs, excess rows, too few pairs, and
  non-finite values;
- exact temporal gaps, series boundaries, missing occasions, lag support, and
  pair-weighted calculations;
- intervals and observed-percentile calculations;
- `print()` and `plot()` return the documented object invisibly.

Use `skip_if_not_installed("glmmTMB")`. Never assert that a predictive
percentile must cross a significance cutoff for one seed.

### Development calibration

Use fixed multi-seed simulations and keep them outside CRAN tests. For partner
dependence include:

1. a correct distinguishable Gaussian covariance;
2. a correct exchangeable Gaussian covariance;
3. positive dependence omitted from the fitted model;
4. negative dependence fitted with a structure that can generate only
   nonnegative dependence;
5. missing members and randomly reordered rows;
6. an additional higher-level random intercept.

For temporal dependence include correct AR(1), omitted AR(1), and a deliberately
misspecified decay shape, with fixed missing scheduled occasions. Inspect the
complete multi-lag curve rather than only lag 1.

Record convergence, observed and replicated summaries, interval inclusion, and
runtime over all predetermined seeds. Do not select a convenient seed or change
the statistic after viewing one result. Correct scenarios should not show a
systematic directional discrepancy; deliberately inadequate scenarios should
show the intended discrepancy often enough to make the plot useful. If they do
not, report that limitation before export rather than inventing a favorable
threshold.

The first implementation task ends with internal functions, passing regression
tests, calibration output, and inspected plots. Export is a separate review
decision followed by a clean `R CMD check --as-cran` run.

## Formal calibration is deferred

The initial `glmmTMB` checks hold parameters fixed at estimates obtained from
the observed data. Observed and replicated statistics are therefore not exactly
exchangeable, and features closely related to fitted covariance or dispersion
parameters can look central by construction.

A future frequentist-style calibrated test would need to:

1. simulate a complete dataset;
2. refit the model to that dataset;
3. recompute the diagnostic;
4. compare the observed result with the refitted reference distribution.

Curve-valued tests additionally require a simultaneous or global envelope,
such as a rank or maximum-deviation envelope. Neither refitting nor global
testing belongs in the first implementation.

## Relationship to existing development material

The following files remain useful and are not competing diagnostics plans:

- [`dyadic-ild-ar1-var-tutorial.md`](dyadic-ild-ar1-var-tutorial.md) distinguishes
  residual AR covariance from substantive own- and partner-outcome carryover;
- [`dyadic-ild-current-options.md`](dyadic-ild-current-options.md) records the
  covariance structures available in released `glmmTMB` and `brms` versions;
- [`ild-nonindependence.md`](ild-nonindependence.md) separates stable dyad,
  same-occasion partner, within-member serial, and cross-partner serial
  dependence;
- [`stan.md`](stan.md) is the separate long-term residual-VAR model roadmap;
- `workshop/` contains the preserved teaching implementation and must remain
  runnable until deliberately revised.

These sources inform what a diagnostic curve means, but this file controls the
diagnostics API and implementation. Workshop DHARMa rotation and whitening are
historical teaching workflows, not package requirements.

## Keep the implementation small

Planned first files:

```text
R/predictive_checks.R
R/check_partner_dependence.R
tests/testthat/test-predictive-checks.R
tests/testthat/test-check-partner-dependence.R
dev/diagnostics/calibrate-partner-dependence.R
```

Keep the public functions internal until their calibration is reviewed. Then
export only the constructor and accepted checks. Register compact print and plot
S3 methods; users call the base generics. Prefer a few explicit helpers and
loops over dense functional code when they make replicated statistics or curves
easier to audit.

Do not add DHARMa, ggplot2, bayesplot, Matrix, or brms as a runtime dependency
for version 0.2.1. Do not optimize simulation storage or add chunking until ILD
benchmarks demonstrate a real memory problem.
