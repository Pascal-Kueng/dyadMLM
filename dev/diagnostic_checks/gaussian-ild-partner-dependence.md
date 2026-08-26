# Gaussian Partner-Dependence Diagnostics for ILD

Status: implementation specification for a future milestone. The current
cross-sectional Gaussian feature remains the first release slice. This plan
extends that feature after its contract is stable; it does not broaden the
scope of the current pull request.

The current cross-sectional contract that this design must preserve is in
[`gaussian-cross-sectional-partner-dependence.md`](gaussian-cross-sectional-partner-dependence.md).

## Purpose

Repeated dyadic outcomes can remain associated for several different reasons:

1. the two members can have related stable average levels;
2. their departures from those levels can be related at the same occasion;
3. each member's departures can persist over time; and
4. one member's departure can be related to the other member's later departure.

A single pooled partner correlation cannot show which of these implications a
model reproduces. The ILD extension should therefore compare the observed data
with complete datasets simulated from the fitted model for all four targets.
These are graphical, plug-in predictive checks. They describe where the
observed summaries fall in the model's simulated reference distribution; they
are not p-values, pass/fail tests, held-out validation, or direct estimates of
individual covariance parameters.

The construction is literature-informed rather than a published named
procedure. Existing work supports separating stable, concurrent, own-lag, and
cross-lag dependence and comparing meaningful observed summaries with
replicated data. The exact combination of model centering, finite-series
decomposition, weighting, support rules, and simulation envelopes is a
`dyadMLM` design that requires the validation and expert review specified
below.

## One public entry point

Keep one public function for cross-sectional and ILD data:

```r
check_partner_dependence(
  simulations,
  dyad,
  role = NULL,
  plot = TRUE,
  response = c("model-centred", "raw"),
  member = NULL,
  time = NULL,
  lags = NULL,
  weighting = c("dyad", "edge")
)
```

The current first five arguments remain in their existing order. New ILD
arguments are appended so positional cross-sectional calls remain compatible.

- With `time = NULL`, preserve the current cross-sectional behavior exactly.
- If `member` is supplied cross-sectionally, use it to verify two distinct
  members and unique dyad-member keys. Otherwise retain the current two-row
  pairing rule.
- If more than two fitted responses occur in any dyad and `time` is absent,
  explain that repeated responses were detected and ask for `member` and
  `time`. Without `member`, a pathological two-row dyad containing two rows
  from the same person cannot be detected.
- Supplying `time` activates the ILD profile and requires `member`.
- A non-`NULL` `lags` without `time` is an error.
- On the ILD path, resolve `lags = NULL` to `1:5`. Otherwise require finite,
  distinct, positive whole numbers.
- `role` remains optional. Its presence selects distinguishable summaries; its
  absence selects exchangeable, label-invariant summaries.
- `response = "model-centred"` remains the default. A raw-response view may be
  retained as a descriptive sensitivity analysis. After raw member demeaning,
  time-varying fixed effects remain in `W`, and unequal schedules can affect
  `B`; raw profiles therefore describe total observed outcome patterns under
  the fitted design and may be dominated by mean trends or covariate imbalance.

Do not add `check_ild_dependence()` or separate public functions for the four
dependence components. Internally, a small dispatcher can choose the existing
cross-sectional calculation or the ILD calculation.

## Initial supported scope

The first implementation is deliberately narrow:

- simulations created by `simulate_dyad_responses()`;
- Gaussian identity-link `glmmTMB` models;
- exactly two members per dyad;
- one analysis composition at a time as a documented precondition; verify it
  when a composition identifier or retained preparation metadata is available,
  but do not pretend it can be inferred from `dyad`, `member`, and `role` alone;
- a regular, explicitly encoded occasion scale;
- model-centred and raw observable response summaries; and
- distinguishable or exchangeable dyads.

Do not imply support for generalized outcomes, mixed compositions, irregular
time bins, arbitrary numbers of members, innovation residuals, simultaneous
curve tests, or another model backend.

`simulate_dyad_responses()` is currently specified only for cross-sectional
models. Before an ILD check accepts its output, extend and validate that backend
contract for `ar1()` and each other supported structured-covariance term. Test
unconditional complete-response simulation, random-effects-zero centre
alignment, fitted-row order, and restoration of any temporarily altered model
state. A simulation object that happens to run is not sufficient evidence of
ILD support.

## Validate structure without rebuilding the data

Fitted-row identity is essential because each column of the simulation matrix
must continue to refer to the same fitted response row. Never call
`prepare_dyad_data()` on the fitted model frame inside the diagnostic.

Reuse package validation concepts, but do not run the entire
`validate_dyad_data()` preparation pipeline or make a broad validator refactor
an implementation prerequisite. Build a focused diagnostic row-map validator
over resolved vectors and original fitted-row indices. Small common predicates
can be extracted for preparation later where the policies genuinely agree. For
the ILD path, the diagnostic validator should establish:

- exactly two stable member identities within each dyad;
- when `role` is supplied, exactly two eligible role values, exactly one member
  in each role for every included dyad, and one stable role order over the full
  series;
- no duplicate dyad-member-time key;
- valid fitted-row indices and unchanged row order;
- a usable factor-valued time vector aligned to fitted rows and retaining its
  original levels; and
- the intended distinguishable or exchangeable role structure.

Keep diagnostic-specific missing-data and counting rules local. The existing
cross-sectional check reports omissions of missing identifiers, whereas the
data-preparation validator sometimes rejects or removes them. Sharing a helper
must not silently change either public policy.

Use `resolve_fitted_row_argument()` for `member`, `role`, and `time`, including
its support for aligned external vectors, and reuse the original fitted-row
indices throughout.

## Response representation and decomposition

For model-centred Gaussian checks, first subtract the population-level fitted
mean obtained with random effects set to zero:

\[
z_{dmt} = y_{dmt} - \widehat{\mu}^{\mathrm{RE}=0}_{dmt}.
\]

For raw checks, use \(z_{dmt}=y_{dmt}\). Then, separately for the observed
response and every complete simulated response, calculate

\[
B_{dm}=\operatorname{mean}_t(z_{dmt}), \qquad
W_{dmt}=z_{dmt}-B_{dm}.
\]

Here \(d\) indexes dyads, \(m\) members, and \(t\) scheduled occasions.
`B` and `W` are observable finite-series summaries. They are not latent random
effects, true person means, or innovation residuals. Recalculate both values
for every simulated dataset; never decompose the observed data once and reuse
its member means for the simulations.

Use `no_NaN_mean()` for member means: it should ignore explicitly eligible
missing values but return `NA_real_`, not `NaN`, if none remain. In the initial
Gaussian path, fitted observed and simulated responses should already be finite,
so this is defensive reuse rather than a missing-response policy. Resolve,
filter, and count structural missingness before the helper is called, and treat
an empty eligible member as an explicit structural/support failure. Do not let
`na.rm = TRUE` hide an invalid row map or a non-finite simulated response.

The diagnostic is conditional on the fitted-row schedule. It does not test
whether missing occasions or exclusion from the fitted sample are informative.

## Four result sections

### 1. Stable partner dependence

Apply the paired cross-sectional statistic to the two member means \(B_{d1}\)
and \(B_{d2}\). Each eligible dyad contributes one pair.

- Distinguishable dyads: report each role's SD and their partner correlation.
- Exchangeable dyads: report the common member SD and partner correlation using
  the label-invariant dyad-average/half-difference reconstruction. Show the
  familiar SD/correlation view first and retain mean/half-difference summaries
  as supporting detail.

Each `B` is the arithmetic mean over that member's available fitted occasions;
at the second aggregation stage, every eligible dyad contributes one paired
member mean. No additional grand-mean centring is needed for these spread and
correlation summaries. Subtracting any common scalar would change neither the
SDs nor the correlation. The consequential choice is how paired member means
and repeated edges are weighted, not which grand mean is subtracted.

### 2. Concurrent within-member partner dependence

At each exact dyad-occasion with both members observed, pair their within-member
deviations \(W_{d1t}\) and \(W_{d2t}\).

- Distinguishable dyads: report role-specific SDs and the same-occasion partner
  correlation.
- Exchangeable dyads: use the same label-invariant common-member and
  dyad-average/half-difference summaries as in the cross-sectional check.

This is total concurrent association after finite-series demeaning. It is not
necessarily the model's innovation correlation: random slopes, serial
structure, fixed-effect misspecification, and other fitted components can all
contribute to the full-model predictive implication.

### 3. Own-member positive-lag profiles

For each requested positive lag \(h\), correlate

\[
W_{dm,t}\quad\text{with}\quad W_{dm,t+h}.
\]

- Distinguishable dyads: show one curve for each role.
- Exchangeable dyads: pool the corresponding edges from both member series in
  a label-invariant way.

This checks the observable autocorrelation profile reproduced by the complete
model. It is not a direct test of one AR(1) coefficient. In particular,
exchangeability does not generally imply one persistence parameter: a
mean/half-difference dynamic model can have separate persistence for its common
and difference modes.

### 4. Cross-member positive-lag profiles

For each positive lag \(h\), correlate

\[
W_{d1,t}\quad\text{with}\quad W_{d2,t+h}
\]

and, when roles are distinguishable, also

\[
W_{d2,t}\quad\text{with}\quad W_{d1,t+h}.
\]

- Distinguishable dyads: label the two curves by source and later target role,
  for example `role 1 -> role 2` and `role 2 -> role 1`.
- Exchangeable dyads: pool both directions so independently swapping member
  labels within dyads cannot change the result.

This is the model-implied observable cross-correlation profile. It can reveal
whether same-occasion dependence, member-specific serial processes, random
slopes or other time-varying random effects, and cross-member dynamics jointly
recreate lagged partner association.
It is not a direct test of one VAR coefficient. Optional mean-mode and
difference-mode lag profiles may be evaluated later, but they are not part of
the first default display.

## Eligibility and missing occasions

Use the observations that are relevant to each statistic rather than forcing
all panels and lags to share the smallest common sample.

- Construct each `B` from that member's eligible fitted response rows, even if
  the partner is absent at some of those occasions.
- Use only matched member pairs at the same occasion for the concurrent
  section.
- Use only exact eligible start/end rows for each own- or cross-member lag
  edge.
- A short member series may contribute to the stable section but not to every
  concurrent or lag summary.
- Determine eligibility separately at every lag and direction. Never restrict
  all curves to the dyads that support the largest requested lag.

Report these differences in support rather than presenting panels as though
they used identical observations.

## Weighting and moment conventions

Offer

```r
weighting = c("dyad", "edge")
```

with `"dyad"` as the default.

- `"dyad"`: every eligible dyad receives total weight one for a given
  component, lag, and direction; divide that weight equally across its
  available occasion pairs or lag edges.
- `"edge"`: every eligible occasion pair or lag edge receives equal weight, so
  dyads with longer observed series contribute more.

For the proposed `"dyad"` rule, divide a dyad's weight across all of its
eligible edges for that component, lag, and pooled curve. Thus, in an
exchangeable own-lag or cross-lag curve, a member or direction with more
observed edges contributes more of that dyad's fixed total weight. An
alternative hierarchy—dyad, then equal member or direction, then equal
edges—answers a different question. Compare it in the validation study and ask
methods reviewers specifically whether it should replace the proposed default;
do not leave the hierarchy implicit.

The choice affects the concurrent, own-lag, and cross-lag summaries. It does
not affect stable partner dependence because that section already contains one
member-mean pair per dyad. The two choices are identical for a balanced,
complete schedule. Store, print, and caption the selected rule, including a
note that stable summaries are unchanged.

Use one explicit cluster-level finite-sample convention for both weighting
rules. Let \(K\) be the number of eligible dyads, \(E_d\) the eligible edges in
dyad \(d\), and \(N=\sum_d E_d\). Define normalized edge weights

\[
a_{de}=
\begin{cases}
1/(K E_d), & \text{for dyad weighting},\\
1/N, & \text{for edge weighting}.
\end{cases}
\]

Then use

\[
\bar{x}=\sum_{de}a_{de}x_{de},
\]

\[
s_x^2=\frac{K}{K-1}\sum_{de}a_{de}(x_{de}-\bar{x})^2,
\]

with the analogous covariance. For an exchangeable half-difference
\(H_{de}\) constrained about zero, use

\[
s_{H0}^2=\sum_{de}a_{de}H_{de}^2.
\]

This convention reduces exactly to the current cross-sectional calculation
when every dyad contributes one pair, and the two weighting modes are exactly
identical when every dyad has the same number of edges. It is a sensible
cluster-corrected descriptive moment, but it is not automatically an unbiased
variance estimator under serial dependence. Freeze it only after hand checks,
simulation, and expert review; do not let a weighting library silently choose
a different denominator.

Preserve the current intentional cross-sectional conventions:

- ordinary role SDs and dyad-average variances use \(n-1\);
- the common factor in a Pearson correlation cancels;
- the exchangeable half-difference uses its mean square about the
  exchangeability-implied zero and therefore uses \(n\), not \(n-1\).

The same observed statistic must always be applied to every simulated dataset,
regardless of whether it is unbiased as a stand-alone estimator.

## Exact time and lag contract

The first ILD implementation should mirror the strict time representation
needed by `glmmTMB::ar1()`:

- `time` must resolve to a factor aligned to the fitted rows, whether supplied
  from the fitted model frame or as an external vector;
- its ordered level sequence represents equally spaced scheduled occasions;
- every scheduled occasion must remain declared as a factor level, even when
  no fitted row occurs at that occasion;
- missing `time` is not allowed on otherwise eligible fitted rows;
- each dyad-member-time key must be unique; and
- member and role identities must remain stable.

Complete factor levels do not require every member to have an observed row at
every occasion. If a scheduled occasion is absent globally, its unused level
must still be retained in the fitted model, including use of
`glmmTMBControl(drop_unused_levels = FALSE)` when that control is available.

Interpret `lags = 1:5` as differences in factor-level position. For each lag
and direction, create exact row-index maps such as

```text
(dyad, member, t) -> (same dyad, same member, t + h)
(dyad, source member, t) -> (same dyad, other member, t + h)
```

Never infer lags from row order, call an ordinary row-adjacent `lag()`, or join
two rows as lag 1 merely because they are adjacent. Exact factor-level
difference defines the lag: if `t + 1` is missing, `t` to `t + 2` is still a
valid lag-2 edge, never a lag-1 edge. Intermediate observed rows are not
required. Build each map once from the fitted design and reuse it for the
observed response and all simulations. Five literal lagged columns are
acceptable in a readable validation document, but generic edge maps are
clearer and faster inside the package.

## Support and undefined correlations

Return a tidy support table with, as applicable:

- component;
- lag and direction;
- contributing dyads;
- contributing same-occasion pairs or lag edges;
- weighting rule;
- number of defined simulated statistics; and
- an explicit reason when the observed or simulated statistic is undefined.

Show at least the following beneath or beside the plots:

- stable: number of dyads;
- concurrent: number of dyads and matched pairs; and
- each lag/direction: number of dyads and edges.

A correlation is undefined when support is insufficient, either side has zero
variance, or another numerical degeneracy occurs. The first Gaussian
validation should assess a candidate minimum of at least three contributing
dyads and three eligible pairs or edges. It must also prespecify how many of the
simulated statistics must be defined before an interval is drawn.

Do not calculate an interval by silently applying `na.rm = TRUE` to undefined
replicate correlations. If the observed value is undefined, report “not
estimable” with its reason and support, while retaining any informative spread
statistics. Keep an explicitly requested unsupported lag in the returned
support information with a clear reason and omit its curve point; do not
silently drop it or fail the entire otherwise useful profile. Default lags with
no support may be omitted from the plotted curve, but must remain in the support
table with the reason.

## Result and plot design

Leave the current cross-sectional object shape exactly unchanged. Return ILD
results with a dedicated subclass such as
`c("dyadMLM_ild_partner_check", "dyadMLM_partner_check", "list")`, four named
sections, and dedicated print/plot methods. One public entry function does not
require identical storage for two substantially different displays. Store the
observed statistics, full replicated statistics, reference summaries, row/edge
maps or their auditable identifiers, role order, time levels, lag requests,
weighting, support, response representation, and simulation metadata.

Use the current summaries for fully defined scalar results: simulated median,
middle 95% interval, and the observed value's position among simulations.
Describe the position as a descriptive tail location, not a p-value. ILD
profiles need a componentwise summarizer because some replicated correlations
may be undefined. Only after the prespecified defined-replicate threshold is
met, calculate the median and interval from that accepted subset and calculate
the observed position with finite correction denominator `n_defined + 1`.

For lagged results, use two compact profile plots rather than a separate plot
for every lag:

1. one own-member lag profile; and
2. one cross-member lag profile.

Show observed points/lines, the simulated median, and pointwise middle 50% and
95% envelopes. Clearly label the envelopes as pointwise, not simultaneous.
Lag zero belongs to the concurrent section and should not be duplicated in the
own-lag plot. A selected-lag histogram can be considered later as an optional
detail view.

## Code reuse and internal organization

Prefer small, readable helpers over a second diagnostics framework.

1. After its ILD backend contract passes the gate above, reuse the existing
   simulation object, response centre, fitted-row alignment, and basic observed
   versus replicated iteration.
2. Reuse `resolve_fitted_row_argument()` and implement the focused diagnostic
   row-map validator described above; extract only genuinely common predicates.
3. Reuse `no_NaN_mean()` for the finite member means.
4. Put the new calculations in a small paired-value moment kernel accepting
   `x`, `y`, `cluster = dyad`, distinguishable/exchangeable mode, and the
   explicit weighting rule. Keep
   `calculate_partner_response_statistics(response, indices, ...)` as a thin
   wrapper so the current cross-sectional contract and its direct tests remain
   intact.
5. Use that full paired kernel for stable means and concurrent pairs where its
   weighting semantics match.
6. Use lower-level weighted mean, variance, covariance, and correlation helpers
   for own- and cross-lag profiles; do not force lag edges through the complete
   mean/half-difference output kernel.
7. Reuse the exact-gap rule from the package's lag-predictor code, but implement
   a new factor-level-position key map for diagnostics rather than calling the
   row-sorting predictor-generation pipeline.
8. Apply one decomposition and statistic path to the observed response and to
   every simulation. Add a componentwise ILD reference summarizer rather than
   reusing the current all-or-nothing finite-statistic check.

Keep the validation R Markdown code deliberately direct. Repetition that makes
the four targets visible is preferable there to abstractions that obscure what
is being checked.

## Deterministic tests

Before the outer simulation study, add focused tests for:

- dispatch and unchanged current cross-sectional results when `time = NULL`;
- unchanged positional cross-sectional calls and exact cross-sectional object
  shape;
- `member` validation on the cross-sectional path and `lags = NULL` dispatch;
- informative rejection of repeated fitted responses without `time`;
- unconditional ILD simulation, centre alignment, and model-state restoration
  for every accepted structured covariance term;
- structural validation and exact fitted-row alignment;
- hand-calculated `B` and `W` values;
- recomputation of `B` and `W` for every simulation;
- member means built from their own available rows;
- concurrent pairs and exact own/cross lag maps;
- gaps that are never collapsed, including a valid lag-2 edge across a missing
  `t + 1`, and unused scheduled factor levels that remain meaningful;
- statistic-specific support with unequal series lengths;
- role ordering and both distinguishable cross-lag directions;
- exchangeable label-swap invariance for every component and lag;
- dyad- and edge-weighted hand calculations;
- the one-pair-per-dyad cross-sectional limit;
- the intentional \(n-1\) and zero-centred \(n\) conventions;
- zero variance, insufficient support, and partially undefined simulated
  profiles;
- componentwise defined-replicate thresholds and `n_defined + 1` position
  calculations;
- support-table, print, and plot structure; and
- stable results under irrelevant fitted-row reordering when identifiers remain
  correct.

## Outer simulation study

Implement one plainly named, development-only document, for example
`dev/diagnostic_checks/gaussian-ild-partner-dependence-validation.Rmd`. Keep
generation, fitting, checking, plotting, and plain-language conclusions visible
in one file. It should cover at least:

- a correctly specified Gaussian reference model;
- omitted or misspecified stable partner covariance;
- omitted or misspecified concurrent covariance;
- asymmetric own-member persistence, such as 0.80 versus 0.20;
- omitted cross-member dynamics;
- covariance compensation, where one pooled summary appears adequate although
  level-specific summaries fail;
- exchangeable data with separate common- and difference-mode persistence;
- gaps, unequal series lengths, and asymmetric missing occasions;
- fixed trends, random slopes, and mean misspecification;
- short series and smaller dyad samples;
- dyad versus edge weighting under informative series-length imbalance;
- dyad-to-all-edges versus dyad-to-equal-member/direction weighting for
  exchangeable pooled profiles; and
- low support, zero variance, and undefined simulated correlations.

The study should ask whether each section stays compatible under a correct
model and moves in an understandable direction under targeted
misspecification. It should also determine practical support and
defined-replicate thresholds. Do not claim formal calibration, power, or error
rates unless the simulation design actually establishes them.

## Interpretation and review boundary

Documentation should state in plain language:

- Checking the same dependence structure that was directly fitted may be
  reassuring but not very informative when the model has enough flexibility to
  reproduce it.
- The checks are more useful when a simpler fitted structure must recreate a
  richer observable pattern—for example, an exchangeable model applied to data
  with distinguishable roles, a generalized model with simplified covariance,
  or a model where several components jointly generate serial and concurrent
  dependence.
- A good profile does not prove that covariance was assigned to the correct
  latent component, validate standard errors, or establish an adequate fixed
  mean model.
- Mean-model checks and response-distribution checks remain separate and
  necessary.

Expert methods review is especially useful for the equal-dyad moment estimand,
finite-series decomposition under unequal or missing occasions, exchangeable
pooling and transformation, and interpretation of cross-lag profiles. Code and
usability review are valuable but answer different questions.

## Later three-level extension

After explicit three-level data preparation is supported, extend the same idea
to an explicit period or burst identifier:

\[
z_{dmpt}=B_{dm}+P_{dmp}+W_{dmpt},
\]

where `B` is the stable member mean, `P` is the member's period deviation, and
`W` is the within-period occasion deviation. Apply partner SD/correlation
summaries at all three levels, both own- and cross-member between-period lag
profiles to `P`, and both own- and cross-member within-period lag profiles to
`W`. Never create an edge across a period boundary. Require the period
variable; do not infer it from row order or random effects. Validate whether
equal observations within period, equal periods within member, and equal dyads
at the population level are the appropriate recursive weights.

Keep the public progression explicit—two-level first, then three-level. Do not
promise a generic arbitrary-level or four-level implementation without a
concrete use case. Outcome diagnostic decomposition is distinct from temporal
predictor decomposition even when their terminology and identifiers align.

## Generalized and other deferred paths

Generalized diagnostics begin only after the corresponding generalized APIM
workflow exists. Start cross-sectionally with `nbinom2(link = "log")`, unit
weights, no zero inflation, and a simple dispersion model. Use raw responses
first unless a nonlinear marginal response centre is separately defined and
validated. Do not treat an inverse-linked linear predictor or link-scale
residual as an automatic substitute.

Validate undefined correlations and sensitivity family by family. Treat
Tweedie separately. Defer binary, ordinal, zero-inflated, hurdle, and
generalized ILD checks until the simpler paths are stable. Keep distribution,
dispersion, and zero-inflation checks separate from partner dependence.

DHARMa-style distribution diagnostics, covariance rotation or whitening, and
innovation-specific residual checks may later complement this profile. They do
not answer the same four observable partner-dependence questions and should not
be dependencies of the first implementation. Do not add a public omnibus score,
global p-value, or pass/fail verdict.

## Capability matrix after validation

Once the initial diagnostic slices are stable, publish one support matrix with
rows for validated combinations and columns for:

- design: cross-sectional, two-level ILD, or later three-level ILD;
- backend;
- family and link;
- distinguishable or exchangeable dyads;
- raw or model-centred response;
- supported dependence targets;
- weighting options; and
- validation status.

Populate a cell only after its deterministic tests, outer simulation evidence,
and documentation are complete.

## Methodological anchors

- Woody and Sadler (2005),
  [*Structural Equation Models for Interchangeable Dyads*](https://doi.org/10.1037/1082-989X.10.2.139),
  grounds the cross-sectional exchangeable mean/half-difference reconstruction.
- Gelman, Meng, and Stern (1996),
  [*Posterior Predictive Assessment of Model Fitness via Realized Discrepancies*](https://www3.stat.sinica.edu.tw/statistica/oldpdf/A6n41.pdf),
  and Gabry et al. (2019),
  [*Visualization in Bayesian Workflow*](https://doi.org/10.1111/rssa.12378),
  motivate comparing several meaningful observed summaries with replicated
  data. The package's current plug-in simulation is not a posterior predictive
  distribution.
- Bolger and Shrout (2007),
  [*Accounting for Statistical Dependency in Longitudinal Data on Dyads*](https://www.columbia.edu/~nb2229/docs/Bolger%20and%20Shrout-Accounting%20for%20Statistical%20Dependency%20May%202005.pdf),
  separates stable and time-varying dyadic dependence and examines
  model-predicted correlations across lags.
- Savord et al. (2023),
  [*Fitting the Longitudinal Actor-Partner Interdependence Model as a Dynamic
  Structural Equation Model in Mplus*](https://doi.org/10.1080/10705511.2022.2065279),
  and Chen and Ferrer (2023),
  [*Assessing Dynamical Associations in Dyadic Interactions Across Multiple
  Time Scales via a Bayesian Hierarchical Vector Autoregressive Model*](https://doi.org/10.1177/02654075221137865),
  provide direct dyadic dynamic and multiple-time-scale context.
- [`../ild-nonindependence.md`](../ild-nonindependence.md) contains the broader
  package literature map and distinctions among stable, concurrent,
  autoregressive, and cross-partner dependence.
