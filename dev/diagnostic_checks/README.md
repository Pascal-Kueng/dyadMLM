# Simulation-Based Dyadic Diagnostics

Implementation specification for the `residual-diagnostics` branch. This file
is authoritative for the feature; `roadmap.md` records only the release
sequence. If a choice is marked **deferred**, do not infer an answer while
implementing an earlier milestone.

## Goal

Provide visual predictive checks for questions that ordinary residual
diagnostics do not answer reliably when observations remain dependent:

- Does the fitted model reproduce the observed same-occasion partner
  dependence?
- For ILD data, does it reproduce the observed temporal dependence?
- Does it reproduce important features of the observed response distribution?

The checks compare the same statistic or curve in the observed data and in
complete response datasets simulated from the fitted model:

\[
T_{obs} = T(y), \qquad T_{rep,b} = T(y^{rep}_b).
\]

Each replicated dataset must preserve the fitted model's complete dependence
structure. The observations within one dataset are therefore allowed to remain
correlated; the dataset, not an individual row, is the simulation unit.

Plots are the primary output. Checks draw them by default and return their
structured results invisibly; they must not become binary adequacy tests.

The eventual workflow should be:

```r
simulations <- simulate_dyad_responses(model, nsim = 1000, seed = 123)

check_partner_dependence(
  simulations,
  dyad = "couple_id"
)

partner_check <- check_partner_dependence(
  simulations,
  dyad = "couple_id",
  plot = FALSE
)
plot(partner_check, parameterization = "member")
```

## Fixed design decisions

1. Preserve every complete simulated response dataset. Never simulate or
   diagnose one partner, one occasion, or one observation independently of the
   fitted joint model.
2. Use one set of complete replicates for direct predictive checks. There is no
   reference/evaluation split and no PIT-rank transformation. Such a split
   would be needed only if a future diagnostic first estimated a rowwise
   transform from simulations and then tested that transform.
3. A check may use either the raw response or a model-centered response. Apply
   the same center to each observed-versus-replicated comparison: one fixed
   center for `glmmTMB`, or matching posterior-draw centers for `brms`.
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

## Implementation order and file boundaries

Complete one diagnostic question before adding the next:

1. finish and review the Gaussian `glmmTMB` simulation constructor and
   cross-sectional partner-dependence check;
2. validate that same cross-sectional check for negative-binomial and then
   Tweedie `glmmTMB` models;
3. extend the partner check to same-occasion ILD pairs, first for Gaussian and
   then for the generalized families already accepted cross-sectionally;
4. add the `brms` simulation and draw-matched centering path for the completed
   partner check, keeping pairing and statistic code shared;
5. add temporal-dependence curves, validating Gaussian `glmmTMB`, accepted
   generalized `glmmTMB` families, and then `brms` in that order;
6. add broader response-distribution checks; and
7. add mixed-composition support only after the single-composition partner,
   temporal, and response checks are stable.

This order changes one dimension at a time: family, repeated-pair structure,
backend, and finally diagnostic question.

Keep three implementation modules:

```text
R/simulate_dyad_responses.R
R/predictive_checks_dependence.R
R/predictive_checks_response.R
```

`simulate_dyad_responses.R` owns backend-specific simulation, fitted-row
alignment, centering inputs, and predictive-reference metadata for `glmmTMB`
and `brms`. `predictive_checks_dependence.R` owns the shared partner and
temporal statistics and their result, print, and plot methods.
`predictive_checks_response.R` owns response-scale quantile, distribution,
spread, zero-frequency, tail, and fitted-pattern checks. These are analogous in
purpose to familiar residual displays, but they are complete-replicate
predictive checks rather than DHARMa residuals.

Tests mirror these three modules. Do not split files further unless one module
becomes difficult to navigate.

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

After Gaussian cross-sectional review, relax family validation one family
at a time: `nbinom2(link = "log")` first and `tweedie(link = "log")` second.
Initially retain scalar responses, unit case weights, `ziformula = ~0`, and an
intercept-only dispersion model. Validate nonconstant dispersion separately
before accepting it. Reuse the model engine's complete unconditional
simulations; do not reproduce its link, dispersion, zero-mass, or random-effect
calculations. For each family, verify fitted-row alignment, finite simulations,
correct and omitted dependence scenarios, and clear handling of replicates
with insufficient response variation. Inspect the marginal response
distribution separately until the package-native response checks are
implemented. Supporting one family must not imply support for every family
handled by `simulate.glmmTMB()`.

`glmmTMB` simulation codes are mutable. Before simulation:

1. save the current codes;
2. register restoration with `on.exit()` immediately;
3. set every random-effect term to unconditional (`"random"`) simulation;
4. restore the original codes after both success and error.

Never leave persistent simulation settings changed on the fitted model.

## Response-simulation layer

### Constructor

```r
simulate_dyad_responses(model, nsim = 1000, seed = NULL)
```

The constructor is public because the complete `glmmTMB` partner check now
exercises its output contract. Keep the interface experimental while the
diagnostic suite expands. The first object contract below is specific to
`glmmTMB`; add the `brms` path only after the complete `glmmTMB` partner feature
establishes which fields the shared check code actually needs.

`nsim` is the number of complete simulated datasets. Require one positive whole
number and recommend 1000 for ordinary plots. Smaller values remain useful for
quick smoke tests. All simulations contribute directly to every replicated
statistic or curve.

Return class `dyadMLM_response_simulations` with these fields:

```text
observed_response        numeric vector in fitted-model row order
simulated_responses      numeric matrix: simulation x fitted row
fixed_effect_prediction  random-effects-excluded response-scale prediction
model_frame              fitted model frame in the same row order
backend                  "glmmTMB"
family                   fitted family name
link                     fitted link name
reference                "plug-in predictive"
random_effects           "new"
nsim                     number of complete simulations
seed                     supplied seed or NULL
call                     constructor call
```

Extract the response and model frame from the fitted model, not from an object
in the calling environment. Verify finite observed values, simulated values,
and fitted means. A supplied seed must reproduce the complete object.

For `glmmTMB`, calculate `fixed_effect_prediction` with
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

For `glmmTMB`, dependence and conditional-pattern checks use:

```r
observed_centered <- observed_response - fixed_effect_prediction
simulated_centered <- sweep(
  simulated_responses,
  MARGIN = 2,
  STATS = fixed_effect_prediction,
  FUN = "-"
)
```

These centered values are neither independent nor whitened residuals. Their
remaining modeled dependence is intentional and is represented in the
replicated reference distribution.

## Version 0.2.1: cross-sectional partner dependence

### Public check

```r
check_partner_dependence(simulations, dyad, role = NULL, plot = TRUE)
```

Draw all diagnostic plots by default, then return the structured check object
invisibly. `plot = FALSE` suppresses the plots for scripts, tests, or a later
custom call to `plot()`. Keep the explicit print method concise so that typing
an assigned object does not dump its replicated-statistics matrix.

Resolve `dyad` and optional `role` through the shared fitted-row argument
resolver. Each argument may be an unquoted or quoted model-frame column, or an
explicit vector whose length equals the number of fitted rows. Prefer a bare
model-frame column to an inherited object such as `stats::time()`, while a
same-named object defined directly by the caller is an explicit vector. Do not
guess how a source-data vector maps through model omissions.

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
each role in every usable dyad. Orient every pair by factor-level order for a
factor and otherwise by sorted unique values. With role-specific centered
responses \(e_{d1}\) and \(e_{d2}\), report the **member parameterization**:

- the SD of \(e_{d1}\);
- the SD of \(e_{d2}\); and
- their Pearson correlation.

Also report the equivalent **mean-difference parameterization**, using

\[
M_d = \frac{e_{d1}+e_{d2}}{2}, \qquad
D_d = \frac{e_{d1}-e_{d2}}{2}.
\]

- the SD of \(M_d\);
- the SD of \(D_d\); and
- the correlation of \(M_d\) and \(D_d\).

The two views must satisfy

\[
\operatorname{Var}(M)=\frac{v_1+v_2+2c}{4}, \quad
\operatorname{Var}(D)=\frac{v_1+v_2-2c}{4}, \quad
\operatorname{Cov}(M,D)=\frac{v_1-v_2}{4},
\]

where \(v_1\) and \(v_2\) are the role-specific variances and \(c\) is their
covariance. The reported mean-difference correlation retains the covariance as
\(\operatorname{Cor}(M,D)\operatorname{SD}(M)\operatorname{SD}(D)\).
Regression tests must verify this mapping and invariance to fitted row order.

When `role = NULL`, member positions are arbitrary. Report the **member
parameterization**:

- pooled residual SD; and
- partner correlation under the exchangeable common-mean and common-variance
  constraint. With \(\bar e\) denoting the pooled residual mean, calculate

\[
\rho_{partner} =
\frac{2\sum_d(e_{d1}-\bar e)(e_{d2}-\bar e)}
     {\sum_d\{(e_{d1}-\bar e)^2+(e_{d2}-\bar e)^2\}}.
\]

Report the equivalent **mean-difference parameterization**:

- SD of the dyad means \(M_d=(e_{d1}+e_{d2})/2\); and
- SD of the half-differences \(D_d=(e_{d1}-e_{d2})/2\).

Exchangeability fixes the signed half-difference mean at zero. Calculate its SD
as \(\sqrt{\operatorname{mean}(D_d^2)}\), which is invariant to arbitrary
member swaps. Do not report a mean-difference correlation without roles.
Regression tests must verify all four summaries and their invariance when
member positions are exchanged independently within dyads.

Calculate every applicable summary once for the observed centered response and
once for every complete simulated dataset, using one shared internal helper. If
any observed or replicated summary is non-finite, stop clearly rather than
silently dropping simulations.

For `glmmTMB`, return class `dyadMLM_partner_check` with:

```text
statistics_table           one row per statistic, with statistic name,
                           parameterization, label, observed value, replicated
                           median and 95% limits, and observed quantile
replicated_statistics      numeric matrix: simulation x statistic
role_order                 stable role order, or character(0)
n_pairs                    complete fitted dyads used
n_incomplete_dyads         dyads with fewer than two usable rows omitted
n_missing_dyad_rows        rows omitted for missing dyad ID
n_missing_role_rows        rows omitted for missing role, or zero
reference                  copied from simulations
random_effects             copied from simulations
nsim                       copied from simulations
seed                       copied from simulations
call                       check call
```

Each `observed_quantile` describes the observed value's position from 0 to 1
among the replicates. It is not a p-value and has no automatic cutoff.

### Plot and interpretation

Implement `plot.dyadMLM_partner_check()` with base R. Draw each summary as a
separate full-size histogram rather than a multipanel figure. Show both
parameterizations by default and allow `parameterization = "member"` or
`"mean_difference"` to select one view. For each plot:

- use all replicates and between 20 and 100 histogram bins;
- draw the observed value as a clearly visible, thicker red line;
- draw the central replicated 95% limits as grey dashed lines;
- keep the x-axis wide enough for the observed and all replicated values;
- reserve blank space at the top for one horizontal legend and stop the
  observed and interval lines below it; and
- show the parameterization and number of usable pairs.

The red line highlights the observed value; it is not red/green significance
coding. The parameterizations are equivalent views of the same covariance
structure, not independent checks.

The intended reading is: "Does the fitted model generate datasets with
same-occasion partner dependence like the observed data?"

A surprising value means the complete model does not reproduce that selected
response-scale feature. Looking across the spread and dependence summaries can
localize the mismatch within the fitted covariance structure, but it does not
by itself identify whether the mean, marginal distribution, dispersion, random
effects, or partner covariance is responsible.
Until the package-native response checks arrive in 0.2.4, inspect the response
distribution and ordinary model-engine diagnostics separately before assigning
a discrepancy to partner dependence. Do not interpret
ordinary rowwise residual tests as calibrated dyadic tests. For generalized
models, never interpret the partner statistic as the fitted latent correlation.

Use model comparison to decide whether a covariance term is needed or whether
exchangeability constraints are supported. A typical predictive value alone
does not prove the latent covariance structure correct.

## Version 0.2.2: complete the partner-dependence feature

After generalized cross-sectional validation, extend the existing check rather
than create another function:

```r
check_partner_dependence(
  simulations,
  dyad,
  role = NULL,
  occasion = NULL,
  plot = TRUE
)
```

With `occasion = NULL`, retain the cross-sectional contract of one pair per
dyad. When `occasion` is supplied, pair rows by dyad and occasion, allow dyads
to contribute repeated occasions, and calculate the same frozen statistics
across complete dyad-occasion pairs. Each complete pair contributes once.
Resolve `occasion` through the same fitted-row argument resolver as `dyad` and
`role`.

Exclude and report rows with missing occasion identifiers. Count incomplete
dyad-occasion pairs separately, error when a dyad-occasion contains more than
two fitted responses, and apply the existing role checks within every usable
pair. In ILD results, `n_pairs` means complete dyad-occasion pairs; also record
the numbers of missing-occasion rows and incomplete dyad-occasion pairs.

Validate repeated-pair handling for Gaussian `glmmTMB` models first, followed
by only the generalized families accepted in the cross-sectional phase.
Complete simulations already retain fitted temporal and higher-level
dependence, so the replicated reference remains valid. The statistic is
pair-weighted and evaluates the complete model's response-scale
same-occasion dependence; it is not a pure level-1 residual correlation. A
discrepancy may partly reflect temporal misspecification, which the later
temporal check helps localize.

### Mixed-dyad-type expansion after the core diagnostics

Add mixed dyad types only after the 0.2.4 single-composition partner, temporal,
and response-check milestones are stable. They do not require another
simulation backend. Reuse the same complete response datasets, but calculate
the observed and replicated statistics separately for every final analysis
composition. Never pool distinct compositions into one dependence statistic.

For each composition, provide two equivalent diagnostic views:

- The **member parameterization** reports one pooled residual SD and the
  exchangeability-constrained partner correlation for an exchangeable
  composition. For a distinguishable composition, it reports both
  role-specific SDs and their correlation.
- The **mean-difference parameterization** reports the spread of dyad means and
  half-differences. For a distinguishable composition, it also reports their
  correlation using a stable role order. Do not report this
  orientation-dependent correlation for an exchangeable composition.

Show both parameterizations as clearly labelled, separate full-size plots by
default, while allowing either view to be requested alone. The two views are
equivalent reparameterizations, not independent tests.

Freeze the composition-identification arguments only when implementing this
stage. They must respect final analysis-composition and exchangeability
decisions and also accept fitted-row-aligned identifiers when preparation
metadata are no longer attached to the model frame. Within this final expansion,
add cross-sectional partner checks first, repeated same-occasion partner checks
second, and temporal checks last. Limit generalized mixed-composition support
to families already validated in the corresponding single-composition phase.

## `brms` path after the `glmmTMB` partner feature

Implement this path after the `glmmTMB` partner check works for cross-sectional
and repeated same-occasion data across the accepted families, and before
beginning the temporal check. Validate Gaussian models first and then each
accepted generalized family. The public check names, fitted-row pairing, and
statistic helpers remain shared. Replicate generation, centering,
predictive-reference metadata, comparison summaries, and plot details may
differ where posterior uncertainty requires it.

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

Label `brms` results **posterior predictive**, not plug-in predictive.
Posterior-predictive tail areas remain discrepancies, not frequentist p-values.
Do not refit a Bayesian model separately for every posterior-predictive draw.

## Version 0.2.3: temporal dependence

Begin this phase only after the `glmmTMB` and `brms` partner-check paths have
established the shared interface. Validate the temporal implementation first
with Gaussian `glmmTMB`, then with the accepted generalized `glmmTMB` families,
and finally with paired posterior-predictive `brms` curves.
For `brms`, include fitted autocorrelation in predictions
(`incl_autocor = TRUE`) and validate covariance-form AR models first.
Response-dependent regression-form AR/ARMA and any required out-of-sample
handling remain **deferred** until end-to-end tests establish that complete
recursive replication is correct.

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

The first temporal curve addresses own-member persistence only.
Same-occasion partner dependence is handled by
`check_partner_dependence(..., occasion = ...)`. Cross-partner lead/lag
dependence, role-specific curves, and couple-mean/member-difference curves are
separate questions and are **deferred**.

The exact-gap construction and within-series centering in
[`workshop/helpers.R`](../workshop/helpers.R) are useful development references.
Do not copy that helper's DHARMa mutation, p-value output, or dense whitening.

## Version 0.2.4: response-distribution checks

Add broader direct response-scale checks after the partner and temporal
features are complete. Implement them first for Gaussian models and then for
the families already accepted by the dependence checks. Do not infer support
for another family merely because `simulate()` runs.

Start with:

- zero frequency when scientifically meaningful;
- spread and tail behavior;
- response quantile, ECDF, or rootogram envelopes;
- model-centered response patterns over fitted values.

For `brms`, use every complete dataset returned by
`brms::posterior_predict()`. Never replace posterior-predictive draws with their
means or medians before calculating a statistic. Use `bayesplot` for mature
generic posterior-predictive displays when it removes code. `dyadMLM` still
owns fitted-row alignment and every dyadic or temporal statistic.

Each display must compare the identical statistic or curve in the observed and
complete replicated datasets. A predictive quantile envelope is not an iid
normal or uniform QQ plot. Bernoulli zeros represent prevalence, not a separate
zero-inflation process.

Use these displays to help interpret dependence discrepancies. A simplified
generalized random-effects structure may be acceptable if its complete
replicates reproduce the observed dependence and relevant marginal response
features. Failure still does not identify which latent component should be
added.

Individual observation-level PIT outlier flags are **deferred**. They would need
a separately specified predictive reference or analytical CDF and must not be
smuggled back in through the removed simulation split.

The items in this section are roadmap targets, not yet frozen implementation
specifications. Before adding a display, define its exact statistic and its
behavior for ties, zero variance, and non-finite replicated values. Never
silently discard a replicate for which a displayed summary is undefined.

## Validation before release

### Package regression tests

Keep CRAN tests small and deterministic. Test code correctness rather than
whether one random dataset crosses a predictive-quantile threshold:

- class, fields, dimensions, orientation, row order, and seed reproducibility;
- model-class, family, link, weight, and response validation;
- simulation-code restoration after both success and error;
- direct agreement of the fixed response center with population-level fitted
  values;
- direct agreement with manually calculated observed and replicated statistics;
- identical observed/replicated statistic code paths;
- direct agreement with the exchangeability-constrained correlation and
  zero-centered half-difference SD;
- invariance of every exchangeable summary to independent member swapping;
- stable role orientation and the exact distinguishable correlation mapping;
- missing identifiers, incomplete pairs, repeated dyad occasions, excess rows,
  too few pairs, and non-finite values;
- identical cross-sectional and ILD pairing behavior when each dyad has one
  occasion;
- family-specific support and clear handling of zero-variation generalized
  replicates;
- exact temporal gaps, series boundaries, missing occasions, lag support, and
  pair-weighted calculations;
- intervals and observed-quantile calculations;
- both plot views and their selection argument; and
- `print()` and `plot()` return the documented object invisibly.

Before temporal implementation, add optional `brms` tests for posterior draw
pairing, fitted-row alignment, group-effect target metadata, and the paired
observed-versus-replicated discrepancy calculation.

Use `skip_if_not_installed("glmmTMB")` and the corresponding guard for optional
`brms` tests. Never assert that a predictive quantile must cross a
significance cutoff for one seed.

### Development review

Use [`partner-dependence-review.Rmd`](partner-dependence-review.Rmd)
for a short end-to-end review with the package's fixed simulated
`dyads_cross` data. It compares:

- an unstructured distinguishable model with no-correlation and exchangeable
  constraints on the same female-male dyads; and
- the intended shared/difference model with an independent model on genuinely
  exchangeable female-female dyads.

Use fixed preparation and predictive-simulation seeds. Correct models should
place the observed summaries in the replicated bulk, while each constrained
model should reveal the response-scale feature it cannot reproduce. Inspect
the plots and the concise interval-inclusion summary; do not turn either into a
pass/fail hypothesis test.

This review verifies the public workflow on a transparent, shipped dataset. It
does not estimate repeated-sampling operating characteristics. Add narrowly
targeted synthetic studies only when generalized, repeated-pair, or temporal
checks are implemented and the package data cannot represent the required
edge case.

The first `glmmTMB` vertical slice ends with passing regression tests and
inspected development plots. Review the Gaussian cross-sectional
slice before relaxing family validation, and review the complete `glmmTMB`
partner feature before adding `brms`. Keep the exported API experimental until
the supported paths are validated, followed by a clean `R CMD check --as-cran`
run.

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

- [`dyadic-ild-ar1-var-tutorial.md`](../dyadic-ild-ar1-var-tutorial.md) distinguishes
  residual AR covariance from substantive own- and partner-outcome carryover;
- [`dyadic-ild-current-options.md`](../dyadic-ild-current-options.md) records the
  covariance structures available in released `glmmTMB` and `brms` versions;
- [`ild-nonindependence.md`](../ild-nonindependence.md) separates stable dyad,
  same-occasion partner, within-member serial, and cross-partner serial
  dependence;
- [`stan.md`](../stan.md) is the separate long-term residual-VAR model roadmap;
- `workshop/` contains the preserved teaching implementation and must remain
  runnable until deliberately revised.

These sources inform what a diagnostic curve means, but this file controls the
diagnostics API and implementation. Workshop DHARMa rotation and whitening are
historical teaching workflows, not package requirements.

## Keep the implementation small

Planned module layout:

```text
R/simulate_dyad_responses.R
R/predictive_checks_dependence.R
R/predictive_checks_response.R

tests/testthat/test-simulate-dyad-responses.R
tests/testthat/test-predictive-checks-dependence.R
tests/testthat/test-predictive-checks-response.R

dev/diagnostic_checks/partner-dependence-review.Rmd
```

The response-check source and test files belong to the later response-scale
phase; do not create placeholders before that work begins.

Export only the constructor and checks whose behavior has been reviewed.
Register compact print and plot S3 methods; users call the base generics.
Prefer a few explicit helpers and loops over dense functional code when they
make replicated statistics or curves easier to audit.

Do not add `DHARMa` to `Imports` or `Suggests`. Do not add `ggplot2`, `bayesplot`,
`Matrix`, or `brms` to `Imports` for version 0.2.1. Add optional packages to
`Suggests` only when the corresponding backend, display, or tests are
implemented. Do not optimize simulation storage or add chunking until ILD
benchmarks demonstrate a real memory problem.
