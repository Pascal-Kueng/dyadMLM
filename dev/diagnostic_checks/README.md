# Simulation-Based Dyadic Diagnostics

Implementation specification for the current Gaussian cross-sectional
`glmmTMB` slice on the `residual-diagnostics` branch. Its current API and
statistics are authoritative. Later backend, family, ILD, and response-check
sections are provisional milestone notes; `roadmap.md` owns their release
sequence. If a choice is marked **deferred** or **unresolved**, do not infer an
answer while implementing an earlier milestone.

## Goal

Provide visual predictive checks for questions that ordinary residual
diagnostics do not answer reliably when observations remain dependent:

- Does the fitted model reproduce the observed same-occasion partner
  dependence?
- For ILD data, does it reproduce stable, same-occasion, own-member, and
  cross-partner lagged dependence?
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
3. A check may use raw or model-centred responses. For the centred version,
   subtract the same row-specific centre from the observed response and every
   replicate. In the current Gaussian identity implementation, this is the
   prediction with random effects set to zero and also the marginal mean over
   newly generated random effects. Under a nonlinear link, those quantities
   generally differ. Generalized checks must remain raw-only until a concrete
   marginal-centering algorithm has been validated.
4. Do not reconstruct or whiten with a dense fitted covariance matrix. The
   model engine already generates the joint response datasets needed here.
5. Keep the computational core independent of DHARMa. Do not add a DHARMa
   dependency, return a DHARMa object, or expose its standard residual tests as
   if their residuals were independent. This design corresponds to DHARMa's
   recommended alternative of explicitly comparing observed and simulated
   dependence statistics.
6. Use unconditional `glmmTMB` simulations. Fitted parameters remain fixed;
   random effects at every modeled grouping level and the responses are newly
   generated. With dyad effects this represents hypothetical new dyads, plus
   new effects at any additional modeled grouping levels. Label this a
   **plug-in predictive reference**.
7. Use `check_*`, not `test_*`, names. Do not return `p.value`, significance
   stars, a pass/fail label, or a combined model-adequacy score.
8. A central replicated interval is descriptive. A pointwise 95% curve envelope
   is not a simultaneous 95% test. Exact frequentist-style calibration is a
   separate, deferred feature.
9. Keep convergence, optimizer, Hessian, sampling, influence, missingness, and
   generic model-comparison diagnostics outside the predictive-check
   implementation. They are not specifically dyadic and are handled by model
   engines or separate workflows.
10. Document the feature as experimental. Do not emit a warning merely because
    it is experimental; warnings are reserved for a concrete unsafe condition.
11. Treat leave-one-dyad-out cross-validation as a separate predictive-
    validation workflow. Hold out both members and every occasion from a dyad
    together. Ordinary rowwise leave-one-out is not a substitute when the
    target is prediction for a genuinely new dyad.

## Implementation order and file boundaries

Complete one diagnostic question before adding the next:

1. finish and review the Gaussian `glmmTMB` simulation constructor and
   cross-sectional partner-dependence check;
2. extend that check to Gaussian same-occasion ILD pairs;
3. either add generalized raw checks one family at a time or first validate and
   freeze a nonlinear marginal-centering algorithm; do not promise centred
   generalized checks before that decision;
4. add Gaussian `brms` parity only after validating the role-specific,
   exchangeable shared/difference, and repeated-pair structures taught by the
   package;
5. add the corrected ILD dependence profile, Gaussian first, and extend it only
   to paths with a validated centre and informative statistic;
6. add broader response-distribution checks; and
7. add mixed-composition support only after the single-composition partner,
   ILD-profile, and response checks are stable.

Leave-one-dyad-out cross-validation remains a separate later roadmap feature;
it is not another step in the diagnostics implementation sequence.

Keep the predictive checks in three implementation modules:

```text
R/simulate_dyad_responses.R
R/predictive_checks_dependence.R
R/predictive_checks_response.R
```

`simulate_dyad_responses.R` owns backend-specific simulation, fitted-row
alignment, centering inputs, and predictive-reference metadata for `glmmTMB`
and `brms`. `predictive_checks_dependence.R` owns the shared partner and ILD
dependence-profile statistics and their result, print, and plot methods.
`predictive_checks_response.R` owns response-scale quantile, distribution,
spread, zero-frequency, tail, and fitted-pattern checks. These are analogous in
purpose to familiar residual displays, but they are complete-replicate
predictive checks rather than DHARMa residuals.

Tests mirror these three modules. When the cross-validation phase begins, add a
separate `R/cross_validate_dyad_models.R` module and matching test file rather
than mixing fold-wise refitting and scoring into the predictive-check modules.
Do not create placeholders before that work begins, and do not split files
further unless one module becomes difficult to navigate.

## What these checks answer

A dependence check does **not** test whether correlation is zero. It asks
whether the fitted model generates datasets with dependence like that observed.
For example, an adequate fitted AR(1) model should reproduce a nonzero observed
lag-1 association.

Predictive checks and model comparison are complementary:

- a predictive check asks whether the retained model reproduces an observed
  feature;
- leave-one-dyad-out cross-validation asks how well it predicts a completely
  unseen dyad; and
- model comparison asks whether adding, removing, or constraining a covariance
  component improves relative fit.

A flexible covariance parameter estimated from the same data can make a
partner check forgiving. A multi-lag within-dyad profile can still reveal an
incorrect decay pattern even when an AR-versus-no-AR comparison favors AR.

"Complete-model" describes how the replicated datasets are generated: they
contain every dependence component fitted by the model. It does not mean that
one summary identifies or validates every component. In ILD, stable dyad,
same-occasion partner, and serial dependence can partly compensate for one
another. A typical same-occasion partner statistic therefore does not establish
that covariance has been assigned to the correct level, and it does not by
itself validate model-based standard errors.

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
diagnostic suite expands. The package constructor currently accepts `glmmTMB`;
the development-only `brms` adapter already emits the same normalized object so
the shared check code can be tested before public backend dispatch is added.

`nsim` is the number of complete simulated datasets. Require one positive whole
number and use 1000 as the bounded public default for every backend. Smaller
values remain useful for quick smoke tests. An explicit all-draw option may be
considered later for `brms`, but must not make the default backend-dependent.
All simulations contribute directly to every replicated statistic or curve.

Return class `dyadMLM_response_simulations` with these fields:

```text
observed_response       numeric vector in fitted-model row order
simulated_responses     numeric matrix: simulation x fitted row
response_center         fixed row-specific marginal expected response
model_frame             fitted model frame in the same row order
backend                 "glmmTMB" or "brms"
family                  fitted family name
link                    fitted link name
reference               "plug-in predictive" or "posterior predictive"
random_effects          "new"
parameter_uncertainty   "excluded" or "included"
center                  how response_center was calculated
center_target           estimand represented by response_center
center_draws            draws used for the centre, or NA when exact
target                  complete predictive target
nsim                    number of complete simulations
seed                    supplied seed or NULL
call                    constructor call
```

Extract the response and model frame from the fitted model, not from an object
in the calling environment. Verify finite observed values, simulated values,
and fitted means. A supplied seed must reproduce the complete object.

For the current Gaussian `glmmTMB` path, calculate `response_center` with
`predict(model, newdata = NULL, type = "response", re.form = NA)`. Explicit
`newdata = NULL` keeps the result in fitted-row order when `na.exclude` was used.
It is the same deterministic response-scale center for the observed data and
every unconditional replicate.
For the initial Gaussian identity-link scope, this is the population-level
mean. Do not subtract empirical-Bayes or BLUP effects estimated for the observed
groups while the replicates contain newly generated effects.

Do not store a dense covariance matrix or the full fitted model unless a later
concrete operation requires it.

## Raw and model-centred checks

The choice changes only the values passed to the summary; it does not rerun the
simulations:

```r
raw_observed <- observed_response
centred_observed <- observed_response - response_center
```

`"raw"` asks whether the fitted model reproduces observed spread and partner
association while retaining the fitted mean pattern. It does not check response
location. For partner association, this adapts Hoff's observed-versus-simulated
comparison to paired unconditional simulations.

`"model-centred"` removes the fixed marginal expected response. Random effects
remain, so the centred values are not independent, whitened, conditional, or
PIT residuals. In Gaussian identity models this centre is the
random-effects-zero prediction. In generalized models it must instead be the
response-scale mean marginalized over new random effects. A diagnostic that
removed learned group effects would answer a different question and remains
deferred.

## Unresolved generalized-outcome centering

The current constructor intentionally rejects non-Gaussian and non-identity
models. Complete response simulation remains the intended architecture, but a
generalized model-centred check is not yet specified well enough to implement.
The first generalized slice should therefore support `response = "raw"` only,
family by family. Enable `"model-centred"` only after the nonlinear marginal
centre below has a concrete backend algorithm and validation evidence. Do not
move the diagnostic to the link scale merely to obtain Gaussian-looking
residuals.

[Ritz and Spiegelman (2004)](https://doi.org/10.1191/0962280204sm368ra)
review when conditional and marginal means agree and when a nonlinear link
makes them differ. This supports the distinction needed here, but does not
specify the diagnostic itself.

If a centred generalized path is pursued, its candidate target is

\[
m_i=E(Y_i^{new}\mid X_i,\text{fitted model}),
\]

where the expectation averages over newly generated group effects but not over
observation noise. For `glmmTMB`, fitted parameters remain fixed and the centre
integrates over new effects under those plug-in estimates. For `brms`, it also
averages over posterior parameter draws. Complete replicated responses still
include new effects and observation noise. Consequently, the simulation object
and every downstream statistic remain shared; only response generation and
centre calculation are backend-specific.

Treat Pearson correlations as observable response-scale discrepancies, not as
latent Gaussian covariance parameters. Their attainable range and sensitivity
can depend on the response mean and family. Sparse counts and binary series may
also have zero variance, making a correlation undefined. Never discard such a
replicate silently.

Support is therefore family-specific rather than automatic. Validate negative-
binomial and Tweedie models first. For each proposed family and dependence path,
verify centre stability, the rate of undefined statistics, sensitivity to
omitted stable/concurrent/serial/cross-lag dependence, and agreement of the two
backends in diagnostic direction. Bernoulli, ordinal, categorical, hurdle, and
zero-inflated models remain unsupported until these checks establish that the
same statistics are informative; an alternative observable association summary
may be needed without changing the complete-simulation architecture.

## Version 0.2.1: cross-sectional partner dependence

### Public check

```r
check_partner_dependence(
  simulations,
  dyad,
  role = NULL,
  plot = TRUE,
  response = c("model-centred", "raw")
)
```

Draw all diagnostic plots by default, then return the structured check object
invisibly. `plot = FALSE` suppresses the plots for scripts, tests, or a later
custom call to `plot()`. Keep the explicit print method concise so that typing
an assigned object does not dump its replicated-statistics matrix.

`"model-centred"` is the default and focuses on variation beyond the fitted
mean pattern. `"raw"` retains that pattern while checking spread and partner
association. Neither mode checks response location. Both use the same complete
simulated datasets.

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

Let `z` denote the selected response representation:

\[
z = y - \hat m
\quad\text{for model-centred},\qquad
z = y
\quad\text{for raw},
\]

where \(\hat m\) is the fixed row-specific marginal expected response stored in
`response_center`. For the current Gaussian identity model,
\(\hat m=\hat\mu_0\), the random-effects-excluded prediction. Apply the same
transformation to every simulated response.

When `role` is supplied, require exactly two role values and exactly one row of
each role in every usable dyad. Orient every pair by factor-level order for a
factor and otherwise by sorted unique values. With role-specific values
\(z_{d1}\) and \(z_{d2}\), report the **member parameterization**:

- the SD of \(z_{d1}\);
- the SD of \(z_{d2}\); and
- their Pearson correlation.

Also report the equivalent **mean-difference parameterization**, using

\[
M_d = \frac{z_{d1}+z_{d2}}{2}, \qquad
D_d = \frac{z_{d1}-z_{d2}}{2}.
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

Use `role = NULL` only when members are substantively interchangeable for the
analysis; the absence of a recorded role variable is not sufficient. In that
case member positions are arbitrary. Report the **member parameterization**:

- common member SD for the selected response representation; and
- partner correlation under the exchangeable common-mean and common-variance
  constraint.

First calculate the **mean-difference parameterization**:

- the sample SD of the dyad means \(M_d=(z_{d1}+z_{d2})/2\); and
- the root mean square of the half-differences
  \(D_d=(z_{d1}-z_{d2})/2\).

Exchangeability implies the population expectation \(E(D)=0\); it does not
force the realized sample mean difference to equal zero. Thus define

\[
s_M^2 = \frac{\sum_d(M_d-\bar M)^2}{n-1}, \qquad
s_{D0}^2 = \frac{\sum_d D_d^2}{n}.
\]

The different denominators follow Woody and Sadler's (2005, p. 142) sample
recipe: the centered dyad-mean matrix uses an effective sample size of
\(n-1\), whereas the uncentered difference cross-products use \(n\). On the
present half-sum/half-difference scale, their matrices are

\[
B=2s_M^2, \qquad W=2s_{D0}^2.
\]

Reconstruct the exchangeable member parameters as

\[
\widehat v = s_M^2+s_{D0}^2, \qquad
\widehat c = s_M^2-s_{D0}^2, \qquad
\widehat\rho_{partner}=\frac{\widehat c}{\widehat v}.
\]

Their Appendix (p. 158) gives the corresponding population identities
\(B=v+c\) and \(W=v-c\); the \(n-1\) versus \(n\) distinction comes from the
sample recipe rather than those population equations.

Report \(\sqrt{\widehat v}\), \(\widehat\rho_{partner}\), \(s_M\), and
\(s_{D0}\). Do not report a mean-difference correlation without roles.
All four summaries are invariant to arbitrary member swaps. Regression tests
must verify that invariance and both reconstruction identities above.

Calculate every applicable summary once for the selected observed response and
once for every complete simulated dataset, using one shared internal helper. If
any observed or replicated summary is non-finite, stop clearly rather than
silently dropping simulations.

Return the same class `dyadMLM_partner_check` for every backend with:

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
response                   "model-centred" or "raw"
backend                    copied from simulations
family                     copied from simulations
link                       copied from simulations
reference                  copied from simulations
random_effects             copied from simulations
parameter_uncertainty      copied from simulations
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
- show the response representation, parameterization, number of usable pairs,
  predictive reference, and number of complete datasets.

Use the concise plot subtitles `"Marginal expected response removed;
dependence retained"` and `"Raw responses; fitted mean pattern retained"`.

The red line highlights the observed value; it is not red/green significance
coding. The parameterizations are equivalent views of the same covariance
structure, not independent checks.

For `"model-centred"`, ask: "After removing the fitted marginal mean pattern,
does the model reproduce the remaining spread and partner association?" For
`"raw"`, ask: "With the fitted mean pattern retained, does the model reproduce
the observed spread and partner association?"

A surprising value suggests that the model may not reproduce that feature. It
does not by itself identify whether the mean, distribution, random effects, or
partner covariance caused the mismatch.
Until the package-native response checks arrive in 0.2.4, inspect the response
distribution and ordinary model-engine diagnostics separately before assigning
a discrepancy to partner dependence. Do not interpret
ordinary rowwise residual tests as calibrated dyadic tests. For generalized
models, never interpret the partner statistic as the fitted latent correlation.

Use model comparison to decide whether a covariance term is needed or whether
exchangeability constraints are supported. A typical predictive value alone
does not prove the latent covariance structure correct.

## Version 0.2.2: complete the partner-dependence feature

After the Gaussian cross-sectional review, extend the existing check rather
than create another function:

```r
check_partner_dependence(
  simulations,
  dyad,
  role = NULL,
  occasion = NULL,
  plot = TRUE,
  response = c("model-centred", "raw")
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

Validate repeated-pair handling for Gaussian `glmmTMB` models first. Generalized
repeated-pair support follows only for families with a validated raw statistic
or a separately validated marginal centre.
Complete simulations already retain fitted temporal and higher-level
dependence, so the replicated reference remains valid. The statistic is
pair-weighted and evaluates the complete model's response-scale
same-occasion dependence; it is not a pure level-1 residual correlation. A
discrepancy may partly reflect temporal misspecification, which the later ILD
dependence profile helps localize. Retain this marginal check as the broad
same-occasion view; the profile does not replace it.

### Mixed-dyad-type expansion after the core diagnostics

Add mixed dyad types only after the 0.2.4 single-composition partner, ILD
dependence-profile, and response-check milestones are stable. They do not
require another
simulation backend. Reuse the same complete response datasets, but calculate
the observed and replicated statistics separately for every final analysis
composition. Never pool distinct compositions into one dependence statistic.

For each composition, provide two equivalent diagnostic views:

- The **member parameterization** reports one reconstructed common member SD
  and the exchangeability-constrained partner correlation for an exchangeable
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
second, and ILD dependence profiles last. Limit generalized mixed-composition
support to families already validated in the corresponding single-composition
phase.

## Later milestone: `brms`

The current `brms` work is exploratory, not package support. Its supported
scope, predictive-reference semantics, validation evidence, bounded future
default, and package-integration gates are recorded in
[`brms-partner-prototype.md`](brms-partner-prototype.md). The public adapter
must reuse `check_partner_dependence()` rather than add another check wrapper.

## Later milestone: ILD dependence profile

The corrected between/within decomposition, role-specific and exchangeable
estimands, exact-lag support rules, plots, and validation gates are recorded in
[`ild-dependence-plan.md`](ild-dependence-plan.md). Gaussian same-occasion
pairing comes first. The profile is extended only to paths with a validated
centre and informative statistic.

## Later milestone: response-distribution checks

After the dependence checks are stable, add complete-replicate displays for
spread, tails, zeros where meaningful, response quantiles or distributions,
and patterns over fitted values. Their exact statistics and handling of ties,
zero variance, and non-finite replicates remain provisional in
[`roadmap.md`](../roadmap.md). They are not iid residual QQ plots.

## Later roadmap: leave-one-dyad-out cross-validation

Cross-validation is a separate predictive-validation feature, not another
diagnostic milestone. It must hold out complete dyads, compare models on the
same folds, and treat held-out dyad-specific effects as new. Its detailed
`glmmTMB` and `brms` design belongs in [`roadmap.md`](../roadmap.md) when that
feature becomes active; ordinary rowwise LOO does not answer this question.

## Validation before release

### Package regression tests

Keep CRAN tests small and deterministic. Test code correctness rather than
whether one random dataset crosses a predictive-quantile threshold:

- class, fields, dimensions, orientation, row order, and seed reproducibility;
- model-class, family, link, weight, and response validation;
- simulation-code restoration after both success and error;
- direct agreement of the fixed response center with population-level fitted
  values;
- direct agreement of raw and model-centred summaries with manual
  calculations, with the centred representation remaining the default;
- direct agreement with manually calculated observed and replicated statistics;
- identical observed/replicated statistic code paths;
- direct agreement with the exchangeability-constrained correlation and
  half-difference RMS about zero;
- invariance of every exchangeable summary to independent member swapping;
- stable role orientation and the exact distinguishable correlation mapping;
- missing identifiers, incomplete pairs, repeated dyad occasions, excess rows,
  too few pairs, and non-finite values;
- intervals and observed-quantile calculations;
- both parameterization views and their selection argument; and
- `print()` and `plot()` return the documented object invisibly.

Use `skip_if_not_installed("glmmTMB")`. Never assert that a predictive quantile
must cross a significance cutoff for one seed.

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
targeted synthetic studies only when generalized, repeated-pair, or ILD-profile
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
- [`brms-partner-prototype.md`](brms-partner-prototype.md) records the
  exploratory Bayesian adapter and its promotion gates;
- [`ild-dependence-plan.md`](ild-dependence-plan.md) records the corrected
  future ILD estimands and validation gates;
- [`stan.md`](../stan.md) is the separate long-term residual-VAR model roadmap;
- `workshop/` contains the preserved teaching implementation and must remain
  runnable until deliberately revised.

These sources inform later milestones, but this file controls the current
Gaussian diagnostics API and implementation. Workshop DHARMa rotation and
whitening are historical teaching workflows, not package requirements.

## Keep the implementation small

Use the three-module layout defined under "Implementation order and file
boundaries" above. Response-check files belong to a later roadmap phase;
cross-validation remains a separate feature. Do not create placeholders before
either workstream begins.

Export only the constructor and checks whose behavior has been reviewed.
Register compact print and plot S3 methods; users call the base generics.
Prefer a few explicit helpers and loops over dense functional code when they
make replicated statistics or curves easier to audit.

Do not add `DHARMa` to `Imports` or `Suggests`. Do not add `ggplot2`, `bayesplot`,
`Matrix`, or `brms` to `Imports` for version 0.2.1. Add optional packages to
`Suggests` only when the corresponding backend, display, or tests are
implemented. Do not optimize simulation storage or add chunking until ILD
benchmarks demonstrate a real memory problem.

## Current decision record

Last consolidated: 2026-08-24.

These are working implementation decisions, not immutable conclusions. They may
be challenged when a concrete use case, methodological argument, or validation
result justifies reconsideration. When a decision changes, update both its
detailed section above and this record so that an older prototype or discussion
does not silently become the plan again.

| Question | Current decision | Why |
|---|---|---|
| What is the simulation unit? | Preserve and evaluate complete response datasets. | Dyadic and temporal dependence exists within a dataset; rowwise simulation or checking destroys the target structure. |
| Who simulates the responses? | Use each fitted model engine rather than reimplementing family, link, random-effect, or autocorrelation simulation. | This keeps the package code small and uses the backend behavior that was fitted. |
| Are these formal tests? | No. Use `check_*` names, descriptive reference intervals, and pointwise curve envelopes. | Plug-in and posterior-predictive references reuse fitted data and are not automatically calibrated p-values. |
| What prediction target is primary? | Unconditional fitted-row replication, including hypothetical new dyads and new effects at every modeled grouping level. | This checks the population model rather than only fitted groups whose effects were learned from the same outcomes. |
| How are centred responses defined? | In the current Gaussian identity path, subtract one fixed row-specific marginal response mean from observed data and every replicate. | This equals the random-effects-zero prediction and preserves newly generated random-effect dependence. Nonlinear marginal centering is unresolved. |
| How do the backends differ? | `glmmTMB` uses a plug-in predictive reference; `brms` uses complete posterior-predictive draws. Pairing and statistic code remain shared. | Posterior uncertainty belongs in the Bayesian reference but does not require a different substantive diagnostic question. |
| Which partner representations are shown? | Retain member and mean/difference parameterizations as equivalent views, with model-centred as the default and raw as an option. | The views aid interpretation and audit the Woody-Sadler algebra; they are not independent tests. |
| What does the marginal partner check establish? | It checks response-scale same-occasion association and spread in the selected raw or model-centred representation. | It is broadly applicable, but one pooled summary cannot identify which covariance level generated a match. |
| How is ILD localized? | Use one `check_ild_dependence()` function, one between/within-series decomposition, and two default panels. | No-role stable and lag-zero summaries use the swap-invariant exchangeable reconstruction; role-aware own-lag curves remain separate. |
| Can cross-sectional data separate stable and occasion-specific dependence? | No. Report only the marginal partner check unless repeated observations or additional assumptions are available. | With one response per member, those levels are not empirically separable. |
| Is a Levy-style conditional check in scope? | No. Keep it only as a possible advanced extension. | Conditioning on learned effects answers a narrower local-dependence question, adds backend-specific machinery, and cannot replace the new-dyad marginal check. |
| How are generalized outcomes handled? | Start with raw complete-response checks, one family at a time. Enable model-centred checks only after validating a concrete nonlinear marginal-centering algorithm. | Response-scale correlations can be mean-dependent, coarse, or undefined even when simulation itself succeeds. |
| What is plotted by default? | Partner checks use replicated-statistic histograms with one observed line; the ILD profile uses one stable-association histogram and one pointwise lag-envelope panel. | These displays expose the reference distribution directly without adding alternative plot types or pass/fail color coding. |
| How is correctness validated? | Use deterministic regression tests for calculations and targeted simulation studies for sensitivity, covariance compensation, model-based SEs, interval coverage, and false-positive rates. | One fitted dataset cannot establish repeated-sampling calibration or inferential robustness. |
| What remains separate? | Model comparison, leave-one-dyad-out cross-validation, formal calibration, generic convergence checks, and marginal response-distribution checks. | They answer different questions or change the fitting and prediction target. |
| What is the release order? | Finish Gaussian cross-sectional checks; add Gaussian repeated pairing; resolve generalized raw versus centred support; validate Gaussian `brms`; then add the corrected ILD profile and response checks. | Each milestone changes one main dimension at a time; cross-validation remains separate. |
