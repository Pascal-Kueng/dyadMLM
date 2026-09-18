# dyadMLM roadmap

`dyadMLM` helps users prepare, assess, and interpret composition-aware dyadic
multilevel models. Model assessment is a core responsibility alongside data
preparation, covariance interpretation, and transparent model specifications.
`glmmTMB` and `brms` remain the fitting engines. The scope covers cross-sectional
and intensive longitudinal (ILD) data.

## Current position

- Version 0.2.0 is released; development is at 0.2.0.9000. Preparation supports
  actor–partner interdependence models (APIM), dyad–individual models (DIM), and
  directional dyadic score models (DSM), with composition controls and temporal
  predictor decomposition.
- Exchangeable covariance recovery supports `glmmTMB` estimates and retained
  `brms` posterior draws, including partial or omitted shared/difference blocks.
- [PR #18](https://github.com/Pascal-Kueng/dyadMLM/pull/18) develops
  cross-sectional partner checks for Gaussian and compatible scalar non-Gaussian
  responses. Longitudinal and broader distributional checks remain follow-up.

## Work packages and release targets

Work packages (WPs) group related capabilities. Releases contain small, validated
increments from one or more WPs. Each increment includes its necessary examples,
documentation, tables, and plots.

| WP | Outcome | Priority and dependencies |
| --- | --- | --- |
| **WP1 — Model assessment** | Assess partner dependence and distributional fit. | Next priority; ILD and broader cross-sectional checks can advance in parallel after WP1A. |
| **WP2 — Covariance interpretation and uncertainty** | Explain fitted dependence and APIM outcome covariance. | Develop in parallel; prioritize the first useful assessment release. |
| **WP3 — Supported workflows and model specifications** | Move from prepared data to validated, inspectable `glmmTMB` models. | Maintain current workflows; expanded tutorials and syntax can follow initial assessment. |
| **WP4 — Bayesian workflows** | Expand existing `brms` support into a coherent analysis path. | Reuse WP3 specification conventions and WP2 algebra where needed. |
| **WP5 — Advanced data preparation** | Support additional designs with explicit preparation rules. | Later, when concrete analyses require them. |
| **WP6 — Multiple-imputation integration** | Prepare externally imputed datasets consistently. | Later; depends on stable preparation, not covariance decomposition. |
| **WP7 — Reporting and visualization** | Turn stable results into useful tables and figures. | Deliver method-specific outputs with their methods; broader integration follows. |
| **WP8 — Documentation and discoverability** | Make current and new workflows easy to learn and find. | Improve current pages now; publish feature guides with each release and update discoverability after page changes. |

These targets replace the earlier version assignments. They are provisional;
only the next release should have a frozen scope. No dates are promised.

| Target | Required scope | Optional additions |
| --- | --- | --- |
| **0.2.1** | WP1A: current cross-sectional partner checks. | Ready correctness fixes and WP8A improvements. |
| **0.3.0** | First useful WP1B and WP1C increments: validated ILD dependence checks and an initial set of broader dyadic assessment plots/checks, with essential WP7 output. | Additional families or formal tests that pass their own validation. |
| **Further assessment releases** | Extend WP1B–WP1D by supported family, design, and check. | Ready reporting and WP8A improvements. |
| **0.4.0** | Initial WP2 APIM covariance decomposition and its essential WP7 output. | Separately validated uncertainty or covariance-recovery extensions. |
| **0.5.0** | WP3 expanded workflows and transparent `glmmTMB` specifications. | Ready cross-method reporting. |
| **Later, unassigned** | Select bounded WP4–WP6 and remaining WP7 increments. | Research candidates only after separate scope and validation decisions. |
| **1.0.0** | Stable preparation–modeling–assessment–interpretation interfaces and documentation. | See the readiness criteria below. |

Freeze the supported families and checks before each release. WP1B and WP1C need
not finish together: split their first releases if either would delay a useful
validated increment. The entire assessment suite is not a gate for WP2.
Generalized diagnostics need validated example models, not completed generalized
APIM tutorials. Assign follow-up version numbers when scheduling each increment;
bundle nearby increments when that makes a worthwhile CRAN update.

For each release, record required deliverables, optional additions, and acceptance
criteria. Use small PRs; each should implement a reviewable part of one WP.
WP8C documentation is required alongside every feature increment. WP8A and WP8B
can also publish improvements to existing pages between package releases.

## Current issues

The following issues were open on 2026-09-18; none had a GitHub milestone.
Timing below is proposed roadmap placement, not an assigned GitHub release.
Keep detailed checklists in the linked issues and update this index as work closes.

| Issue | Home | Timing |
| --- | --- | --- |
| [#23 — Make the dyadMLM website and vignettes easier to find](https://github.com/Pascal-Kueng/dyadMLM/issues/23) | WP8B | After #25 settles the page structure. |
| [#24 — Extend partner-dependence checks to intensive longitudinal data](https://github.com/Pascal-Kueng/dyadMLM/issues/24) | WP1B | After #18; initial scope targets 0.3.0. |
| [#25 — Simplify vignette structure and clarify glmmTMB and brms support](https://github.com/Pascal-Kueng/dyadMLM/issues/25) | WP8A, with scientific content from WP3 | Start now; current-page improvements do not wait for 0.5.0. |
| [#26 — Make help pages and examples clear and practical](https://github.com/Pascal-Kueng/dyadMLM/issues/26) | WP8A | Small PRs now; optional-engine example cleanup follows #18. |
| [#27 — Prevent renamed predictor selections from silently using another column](https://github.com/Pascal-Kueng/dyadMLM/issues/27) | Core maintenance: preparation | Next correctness work; before related refactoring. |
| [#28 — Reject glmmTMB models fitted with priors in likelihood-ratio tests](https://github.com/Pascal-Kueng/dyadMLM/issues/28) | Core maintenance: model comparison | Next correctness work. |
| [#29 — Check that fitted groups contain both partner positions](https://github.com/Pascal-Kueng/dyadMLM/issues/29) | Core maintenance: covariance recovery | Before related recovery refactoring or extensions. |
| [#30 — Keep dyad, member, and time columns when used as APIM predictors](https://github.com/Pascal-Kueng/dyadMLM/issues/30) | Core maintenance: preparation | Next correctness work. |
| [#31 — Avoid overwriting dyad IDs named n_members during incomplete-dyad checks](https://github.com/Pascal-Kueng/dyadMLM/issues/31) | Core maintenance: preparation | Next correctness work; before related refactoring. |
| [#32 — Require dplyr 1.1.1 for the join relationship argument](https://github.com/Pascal-Kueng/dyadMLM/issues/32) | Core maintenance: dependencies | Next compatibility fix. |
| [#33 — Make covariance recovery easier to maintain and test](https://github.com/Pascal-Kueng/dyadMLM/issues/33) | Core maintenance: recovery and internal metadata | After #27–#32; covers existing `glmmTMB`/`brms` support, without waiting for WP2/WP4 extensions. |

Correctness fixes target the earliest suitable release once validated. They are
not deferred to WP5's advanced preparation or the later Bayesian expansion.
WP1C/WP1D and most later features do not yet have dedicated issues; open bounded
implementation issues when selecting their scope. #24 covers ILD partner checks,
not the full assessment suite.

## WP1 — Model assessment

### WP1A: Cross-sectional partner dependence

- Complete `simulate_dyad_responses()` and `check_partner_dependence()` for
  unweighted `glmmTMB` fits without zero inflation: Gaussian, Poisson, NB1, NB2,
  Tweedie, Gamma, and beta responses, using the fitted link.
- Simulate complete datasets with new random effects. Apply the same raw or
  model-centred statistic to observed and simulated responses, subtracting the
  same prediction in the latter case. Preserve fitted-row alignment, complete
  random-effect blocks, simulation settings, and seeded RNG state.
- Keep reference intervals and observed positions descriptive: fitted parameters
  and design are held fixed. They are not confidence intervals or calibrated
  p-values, and nonlinear-link centring is not a residual covariance decomposition.
- Count undefined simulations explicitly. Undefined observed statistics or wholly
  undefined references are errors; report partial undefined draws and summarize
  the defined draws. Binomial and beta-binomial formats need separate adapters.

Scope, examples, and validation: [diagnostic development guide](diagnostic_checks/README.md).

### WP1B: Longitudinal partner dependence

- Extend the same checker with `member` and factor-valued `time`. Recompute
  available-series member means and within-member deviations for the observed
  response and every complete simulation. Reuse paired-moment and reference helpers.
- Compare stable, concurrent, own-member lagged, and cross-member lagged
  dependence. These are finite-series predictive features, not independent
  estimates of latent covariance components.
- Build lag maps from scheduled factor-level positions; preserve gaps and series
  boundaries, role-directed cross-lags, and label-invariant exchangeable pooling.
  Make dyad versus edge weighting explicit. Report contributing dyads, edges,
  defined simulations, and reasons for unavailable summaries.
- Preserve unsupported lags as result rows. For otherwise supported correlations,
  error on undefined observed values or wholly undefined simulations; warn once
  for partial undefined simulations and use the defined values.
- Start with Gaussian identity-link validation against the retained ILD prototype.
  Add Poisson, NB1/NB2, Tweedie, Gamma, and beta only after separate family checks.
  Broader constructor support alone does not establish ILD support. Preserve
  calculable Gaussian results, except for explicitly changed undefined-statistic
  rules, and keep cross-sectional behavior unchanged.
- Validate hand calculations, member swaps, raw/model-centred checks, AR(1) and
  other fitted covariance structures, varying dispersion, sparse outcomes,
  missing or unequal schedules, exact gaps, and the cross-sectional limit. Add
  a simulation study contrasting adequate and omitted dependence structures.
- An external time factor cannot restore an AR state dropped during fitting.
  Lagged outcomes used as fixed predictors are not recursively simulated; scope
  any dynamic simulation extension separately.

After #18 merges, branch from updated `main` and selectively port validated ILD
behavior from [PR #22](https://github.com/Pascal-Kueng/dyadMLM/pull/22). Retain
prototype branches for comparisons. The older separate generalized
cross-sectional step in [#24](https://github.com/Pascal-Kueng/dyadMLM/issues/24)
is superseded by #18's current scope. Open the replacement ILD PR, close #22 once
clearly superseded, then review and merge; delete the old ILD branch only after
merging its replacement. Reconcile #24's checklist when starting this work.

### WP1C: Broader distributional assessment

- Add DHARMa-like QQ/PIT and quantile plots, patterns against fitted values and
  numeric or categorical predictors, and checks of distributional shape,
  tails/outliers, dispersion, and excess zeros. Define each diagnostic's target
  and supported families explicitly.
- Reuse complete model simulations and apply the same transformation to observed
  and replicated data. Construct envelopes that retain fitted partner and
  temporal dependence; distinguish pointwise from simultaneous envelopes.
  Marginally uniform PIT values may remain correlated, so independent-residual
  QQ bands and uniformity tests are not automatically valid.
- Separate detecting excess zeros under a supported count model from supporting
  explicitly zero-inflated or hurdle fits. Those fits require separate simulation
  and component validation. Keep conditional, zero-inflation, and dispersion
  quantities and their response/link scales distinct.
- Cover boundary estimates and document convergence limitations. Covariance
  rotation/whitening is an optional, separately validated residual target, not
  a prerequisite for response-scale checks or dependence-preserving envelopes.
- A possible `check_dyad_fit()` should expose useful diagnostics, with clear
  unsupported cases, rather than reduce adequacy to one score. Diagnostic plots
  ship here; they do not wait for a general reporting interface.

### WP1D: Formal tests and validation

- Keep predictive displays descriptive until a formal testing target is defined
  and validated. Use `DHARMa::testGeneric()` as a reference for applying the same
  statistic to observed and simulated data, not as proof of calibration.
- Validate each check by outcome family, model component, and cross-sectional or
  longitudinal design. Assess false-positive behavior under correctly specified
  dependence and sensitivity to relevant misspecification. Record convergence
  failures, undefined summaries, and effective simulation counts.
- Make any refitting, parameter-uncertainty treatment, or simulation-based test
  procedure explicit. The current fixed-parameter references do not supply these
  automatically. Add differences, SD/RMS ratios, or p-values only with a defined
  target and validation. Full DHARMa coverage is a staged objective, not one
  release gate.

## WP2 — Covariance interpretation and uncertainty

- Develop `decompose_apim_covariance()` for five signed sources of model-implied
  APIM outcome covariance: actor–actor, actor–partner, partner–actor,
  partner–partner, and residual.
- First scope: independent two-member cross-sectional dyads, continuous outcomes,
  a linear Gaussian APIM, one dyadic predictor construct, and fixed slopes.
  Start with distinguishable `glmmTMB` fits. Add the exchangeable special case
  only after testing member-label invariance and combining the two arbitrary
  member-driven terms.
- Separate backend-neutral algebra, fitted-model extraction, term mapping and
  validation, and output. Require explicit term maps for ambiguous formula terms
  or covariance blocks; reuse covariance-array infrastructure where appropriate.
- Return a component table in covariance units and signed outcome-correlation
  points, plus model-implied outcome variances, total covariance/correlation,
  predictor moments, fitted-dyad count, backend, resolved terms, and covariance
  source. Components are not bounded proportions and need not sum to the observed
  sample correlation.
- Calculate predictor moments from complete paired rows in the fitted analysis
  sample with explicit member/role reconstruction, not duplicated long-format
  actor/partner columns.
- Check hand calculations, simulated data, coefficient/row/term reordering,
  asymmetric outcome missingness, boundary estimates, and the workshop's
  distinguishable APIM. Require component sums to match model-implied covariance
  within prespecified tolerances.
- Validate dyad-bootstrap intervals separately: resample whole dyads, recompute
  predictor moments, refit, and state the interval and nonconvergence rules.
  Do not imply frequentist uncertainty from `glmmTMB` point estimates alone.
- Extend exchangeable covariance recovery when applied needs justify bootstrap
  or delta-method uncertainty, explicit custom member contrasts, or paired
  shared/difference blocks in zero-inflation and dispersion components. Validate
  extraction and transformation end to end; keep components and scales separate.
- Keep directional DSM covariance transformation a distinct method using its
  `+0.5/-0.5` role contrast and validated score-to-member mapping. Bayesian
  decomposition and distributional/nonlinear parameters belong to WP4.
- Keep multiple predictors, interactions, ILD level-specific decomposition,
  random slopes, nonlinear outcomes, generic variance-share allocation, mixed
  compositions, automatic formula-wide classification, and `lme4` support outside
  the first contract. Reject unsupported cases; revisit extensions separately.

The [APIM paper note](paper-idea-explaining-interdependence-apim.Rmd) supplies the
technical starting point. Complete the literature review before novelty claims;
study finite-sample bias and interval coverage, and include a reproducible
empirical example with tables and signed waterfall figures. Publish and freeze
the supported function contract, archive paper code/results, then submit the
methods paper. Cite the package concept DOI and add the accepted paper citation
to package metadata.

## WP3 — Supported workflows and model specifications

WP3 owns scientific model specifications and their validation. WP8 owns page
organization, help editing, navigation, and publication. Improving existing
documentation under #25 does not wait for the proposed 0.5.0 feature release.

- Supply one main APIM, DIM, and DSM workflow, with clear cross-sectional and
  ILD paths. Preserve preparation, fitting, interpretation, assumptions,
  covariance recovery, distinguishability checks, and validated transformations.
- APIM: retain within-/between-person actor/partner effects, generated indicators
  and contrasts, and the distinction between manifest raw outcome lags and
  separately estimated within-/between-person lag effects, including small-T
  cautions. DIM: retain exchangeability assumptions, APIM–DIM equivalence,
  random slopes, and ILD limitations. DSM: retain role order, signed differences,
  interaction-model interpretations, role reversal, and APIM/DIM transformations;
  outcomes remain unchanged during preparation.
- Provide validated content for the mixed-composition guide in WP8A: preparation,
  validation, retaining, reclassifying and pooling compositions, a brief APIM
  example, and compatible DIM/DSM workflows. Simplify or label convergence-sensitive ILD fits;
  do not present optimizer changes as a universal remedy.
- Finish `dev/vignettes/generalized-apim.Rmd`, starting with runnable
  negative-binomial examples using shipped count data. Validate Poisson and
  binomial workflows separately; defer ordinal/categorical examples until fully
  supported. Cover distinguishable/exchangeable models and link-scale effects,
  response-scale expectations or mean ratios, and latent covariance distinctions.
  Nonlinear covariance decomposition requires its own estimand and validation.
- Publish development vignettes only when their scope is validated and normal
  package builds are reliable; then link the overview, APIM page, and article
  index. Keep heavy models out of onboarding and use `eval = FALSE` where a
  clearly labeled advanced example should not run during routine builds.
- Generate inspectable `glmmTMB` formulas and arguments for supported
  cross-sectional and ILD models. Test intended estimands and covariance
  structures before considering convenience fitting wrappers. Model specifications
  should reuse preparation metadata rather than create a second composition system.

## WP4 — Bayesian workflows

- Build on existing `brms` covariance recovery. Add transparent formulas and
  priors for supported models, reusing WP3 conventions without promising full
  backend parity.
- Retain posterior draws through covariance transformation and add justified
  summaries. Extend APIM decomposition only with validated term maps and draw-wise
  agreement with WP2's backend-neutral algebra.
- Validate distributional and nonlinear parameters separately from conditional
  model components; do not transfer `glmmTMB` parameter interpretations by name.
- Evaluate Bayesian model comparison separately from `compare_nested_models()`.
  Define the predictive target and observation-versus-dyad holdout unit before
  choosing LOO, WAIC, or another criterion.

## WP5 — Advanced data preparation

- Add explicit `temporal_decomposition = "3l"` only after `"2l"` is stable,
  requiring a day, burst, or period variable. Do not infer it from EMA nesting
  or the fitted random-effects structure. These labels describe predictor
  decomposition, not the number of model levels.
- Consider a separate wide-to-long helper for common two-person inputs while
  retaining canonical long data in `prepare_dyad_data()`.
- Extend composition inspection, raw-to-analysis mapping, or pooling diagnostics
  for concrete uses. `pool_compositions` does not mean statistical partial pooling.
  A public generated-column inspection helper needs a demonstrated use case.
- Extend DSM preparation to multiple distinguishable compositions only with
  explicit directions. Multivariate DSM fitting belongs to later modeling work.
- Add transition-record or dyad-occasion helpers only when WP3 or a custom model
  needs them. Support ragged complete dyad-days and whole dyad-day gaps before
  latent one-partner missingness. Preserve known between-person values and exact
  observed `t - 1` sources across absent current partner rows; latent-state
  imputation is a separate modeling decision.
- Keep `time_4l` and inspection-only incomplete/unknown dyads outside the plan
  unless a concrete use case warrants changing those boundaries.

## WP6 — Multiple-imputation integration

- Start with externally imputed, two-member cross-sectional data and an
  engine-independent preparation contract. Statistical imputation is distinct
  from temporary structural completion, whose temporary rows must never become
  analysis observations.
- Keep structural identifiers and row keys observed and unchanged, with
  consistent roles, composition decisions, and generated-column plans across
  imputations. Impute raw measured and auxiliary variables, then run
  `prepare_dyad_data()` on each completed dataset. Do not independently impute
  generated actor/partner, centered, lagged, DIM, or DSM columns.
- Require imputation models to preserve dyad/person/role structure and relevant
  interactions or random slopes. Include outcomes and suitable auxiliary variables
  where appropriate; a single-level imputation recipe is not a universal default.
- Evaluate a small `prepare_dyad_imputations()` mapper for a list of completed
  datasets, checking row keys, metadata, and composition decisions. Add adapters
  for established imputation-object classes after that contract is stable.
- Validate the cross-sectional APIM workflow through simulation of actor/partner
  effect bias, standard errors, and interval coverage. State missingness
  assumptions and diagnostic expectations without claiming automatic superiority to a defensible complete-case
  analysis. Initially leave imputation, fitting, and pooling to established tools.
- Defer ILD/time-series imputation, missing identifiers or whole members, MNAR
  sensitivity, and pooling nonlinear covariance summaries until separately
  validated. Later longitudinal work must preserve time and serial structure.

## WP7 — Reporting and visualization

- Add `summary.exchangeable_covariance()` and
  `as.data.frame.exchangeable_covariance()`: point summaries for `glmmTMB` and
  posterior summaries for `brms`, with frequentist uncertainty only when validated.
- Make `plot.exchangeable_covariance()` a view of that table, with explicit
  member-level variance, covariance, correlation, and uncertainty labels.
- Develop an ordinary, backend-neutral dyadic-effects table covering actor,
  partner, role-specific, within-/between-person, APIM, DIM, and DSM terms.
  Add coefficient plots after supported formulas can be classified reliably.
- Consider a focused `report_table()` interface returning documented data frames.
  Do not add a generic wrapper around `report`, `parameters`, or `see`.
- Give preparation diagrams, model-structure diagrams, and fitted-result plots
  distinct input contracts. Decomposition tables and signed waterfall plots
  should display WP2 results without recomputing the estimand.

## WP8 — Documentation and discoverability

Use one WP with stages that can overlap. Existing-page cleanup can start now;
new feature guides ship with their features. Scientific scope and validation stay
with the relevant method WP.

### WP8A: Improve current documentation

- Under [#25](https://github.com/Pascal-Kueng/dyadMLM/issues/25), make README the
  entry point, including the raw-data → prepared-columns workflow and links to
  APIM, DIM, and DSM. Give each topic one main page, with clear cross-sectional/ILD
  sections; retain useful diagrams and move lengthy derivations later.
- Move useful Getting Started material before removing its index entry; redirect
  its URL and update navigation. Rework the existing mixed-APIM draft into
  **Preparing and Modeling Multiple Dyad Compositions in R**, using WP3's validated
  content and links to compatible DIM/DSM workflows.
- Add model-engine support tables using the statuses **documented**, **compatible
  but undocumented**, **experimental**, **not implemented**, **unavailable**, and
  **not applicable**. Link documented workflows and record checked `dyadMLM` and
  engine versions.
- Under [#26](https://github.com/Pascal-Kueng/dyadMLM/issues/26), make help practical:
  purpose, workflow, useful output, choices, then technical details. Keep assumptions,
  missingness, roles, covariance scales, and model-comparison limits visible.
  Start with the `compare_nested_models()` help and generated Rd file, retaining
  its example in that first small PR; revise examples separately.
- Use bundled simulated datasets throughout. Smaller examples retain whole dyads
  and required occasions; `coupleID <= 40` in `dyads_cross` contains only female–male
  dyads, so choose IDs for the required composition. After #18, use `@examplesIf`
  for optional engines and verify execution with and without them.
- Explain supported external-vector arguments and fitted-row alignment. Add brief
  contributor guidance on plain language, useful output, and links to one main
  explanation. Keep short pages short; the internal metadata reference stays in #33.

### WP8B: Make documentation easier to find

- After #25 establishes the pages, complete
  [#23](https://github.com/Pascal-Kueng/dyadMLM/issues/23): descriptive titles and
  links, metadata, canonical URLs, sitemap coverage, and indexing. Verify the live
  site after publication, record search results, and review them after 6–8 weeks.
- Maintain accessible workshop materials and synthetic downloads. Track release
  posts, R Weekly, MixedModels Task View outreach, and teaching materials separately
  from feature acceptance. Recheck discoverability when later releases change pages.

### WP8C: Document each feature release

- Include runnable help/examples and an interpretation guide with each new
  capability: model assessment in 0.3.0 and follow-ups, decomposition in 0.4.0,
  expanded workflows/specifications in 0.5.0, and Bayesian/preparation/imputation
  guides with their later increments. WP7 reporting needs examples alongside its
  tables and plots. WP1A's initial documentation still ships in 0.2.1.
- Explain supported designs, outcomes, model engines, statistical targets, and
  limitations. Link existing preparation material rather than repeat it. Update
  support tables and navigation, run examples, inspect rendered pages, and verify
  links and redirects. Feature documentation is required even when other WP8 work
  remains unfinished.

## Continuous maintenance and release checks

- Address #27–#32 before related refactors, prioritizing silent wrong results.
  Keep existing preparation, model-comparison, and covariance-recovery fixes on
  the current maintenance track.
- Under [#33](https://github.com/Pascal-Kueng/dyadMLM/issues/33), separate covariance
  extraction, matching/validation, algebra, and output where this improves clarity.
  Keep file moves separate from behavior changes. Validate actual fitted `glmmTMB`
  and `brms` results against independent calculations; retain fast supplied-result
  tests and document metadata fields, types, shapes, and stage guarantees.
- Each increment requires meaningful numerical checks, runnable examples,
  inspected rendered output, generated help/links, a built-package check, and
  green CI on the proposed commit. Run expensive simulation studies separately
  and retain failure records; smoke checks do not establish calibration or power.
- Before a CRAN release, freeze scope; update NEWS, DESCRIPTION, citation metadata,
  and affected documentation; test with relevant suggested engines; check the
  exact source tarball with `R CMD check --as-cran`, including the manual; review
  Windows/CRAN platform checks; inspect pkgdown and live workshop/download outputs.
  Tag the accepted commit, preserve the official archive, and verify release and
  Zenodo metadata. Cite concept DOI [10.5281/zenodo.22047083](https://doi.org/10.5281/zenodo.22047083).

## Research track — Dynamic models and further methods

These are candidates, not requirements for the next releases or version 1.0.
Further decomposition, covariance, DSM, and imputation candidates remain with
their parent WPs above.

- Consider a lagged-outcome-bias study only if still useful: use a structural
  lagged-outcome generator, compare manifest raw and centered specifications over
  several series lengths, and include an initial-condition-aware reference.
  Keep Monte Carlo work outside routine vignette rendering.
- Evaluate `dynamite` or another MLSEM/DSEM framework after the established-engine
  specification paths are clear. A custom Stan track requires stable preparation,
  composition metadata, actor/partner helpers, validation, and fit/summary conventions.
- Follow the provisional [Stan plan](stan.md): begin with Gaussian two-person
  dyadic residual VAR(1), balanced schedules, and exchangeable/distinguishable
  constraints; then add ragged complete dyad-days and full gaps. Extend mixed
  compositions before evaluating partial pooling across types.
- Preserve one composition system. Distinguish innovation covariance from total
  same-day residual covariance, and use the paired dyad-occasion as the dynamic
  unit while retaining stacked rows for mean-model design.
- Non-Gaussian dynamics, arbitrary DSEM, one-partner latent missingness, and latent
  centering are outside the first Stan implementation. Reconcile the plan with
  the local `dev/references/` literature before implementation, including structural
  versus residual dynamics, initial conditions, unequal intervals, and Kalman-style
  missing-data handling. Method papers follow validated, stable implementations.

## Version 1.0 and JOSS readiness

Version 1.0 marks stable public interfaces: preparation arguments, generated
columns, composition controls and provenance, model specifications, assessment
results, and interpretation helpers. Require a coherent documented workflow from
preparation through model assessment and interpretation, with validated scope and
limits. Complete the introductory, APIM, generalized-APIM, mixed-composition, DIM,
and DSM documentation paths and syntax for at least one primary engine. Published
releases, pkgdown, and the public API must agree. Optional research tracks are not
version-1.0 requirements.

JOSS is a separate package-level milestone, not tied to a particular version.
The package's readiness targets include at least six months of public development,
research-use evidence, archived releases, tests, contribution guidance, and
reproducible vignettes. Explain the package's substantive contributions to dyadic
preparation, assessment, and interpretation. Retain the target of transparent
syntax for `glmmTMB`; a second engine and custom Stan are not submission gates.

## Established implementation contracts

These summarize important constraints from the released preparation and covariance
work. Current code, generated help, and tests define exact behavior; the notes
below provide design context.

- Keep canonical long data and one metadata system. Composition processing is
  `keep_compositions` → `set_exchangeable_compositions` → `pool_compositions`.
  Filtering selects whole dyads and retains their observed time rows. Returned composition
  metadata describes final analysis compositions; `pooled_from` records provenance.
  Do not add a second raw-composition registry or reinterpret pooling as partial pooling.
- Transform predictors only; leave outcomes unchanged. `temporal_decomposition =
  "auto"` selects `"2l"` with time and predictors, otherwise `"none"`. APIM, DIM,
  and DSM share temporal decomposition. For `"2l"`, person means ignore missing
  values and the between-person reference weights person means equally. Preserve raw predictors beside their
  decompositions; redundant raw and decomposed terms should not all enter one model.
- `lag1_predictors` uses exact source times, without bridging gaps. Temporary
  structural completion preserves available partner between-person values and
  source-occasion lags, then returns only original rows in original order. It is
  not imputation and must not leak temporary `.dy_` columns.
- Retained generated names have one leading dot; `.dy_` is reserved internally.
  Keep `short_colnames = TRUE` by default, composition-qualified names for multiple
  final compositions, and explicit `FALSE` for reusable qualified-name pipelines.
  Track generated columns and check collisions before mutation.
- Reject infinite predictors and non-finite numeric structural identifiers;
  preserve supported missing values and character/factor identifiers. Printing
  recomputes available counts and lists only surviving generated columns, without
  mutating or regenerating data. Filtering prepared data retains original centering
  and lags; filtering raw data and preparing again recomputes them. Downstream
  helpers validate required columns directly.
- Keep seeded arbitrary-member assignment reproducible and invariant to input-row
  or occasion order, with RNG restoration. Adding/removing dyads may change draws.
  Arbitrary signs have no substantive member meaning; exchangeable outputs use
  member 1/member 2 labels. Distinguishable contrasts do not reclassify compositions.
- DIM currently requires one final exchangeable composition; DSM requires one
  final distinguishable composition matching `dsm_role_order`. DSM uses full signed
  predictor differences and a `+0.5/-0.5` role contrast. With score variances
  `V_L`, `V_D` and covariance `C_LD`, preserve
  `Var(Y1) = V_L + V_D/4 + C_LD`, `Var(Y2) = V_L + V_D/4 - C_LD`,
  and `Cov(Y1,Y2) = V_L - V_D/4`. Validate coefficient/covariance equivalence,
  fitted outcomes, role reversal, convergence, and positive-definite Hessians
  against independent multivariate/lavaan references at prespecified tolerances.
- Covariance extraction returns named `draws × coefficients × coefficients`
  arrays: one draw for `glmmTMB`, posterior draws for `brms`. Match unambiguous
  shared/difference blocks across compositions and grouping levels; explicit
  `block_pairings` resolve custom terms. Align coefficient order and insert
  structural zeros for partial or wholly omitted blocks. Validate supported
  literal contrast products and fitted-row coding; warn when an omitted formula
  column prevents validation. Keep `varcov`/`sdcor` calculations draw-wise, with
  posterior-mean matrices by default and medians/draws available. Do not infer
  verified partner pairing from a group having only two fitted observations.
- `compare_nested_models(model1, model2, alpha = 0.05)` remains `glmmTMB`-specific.
  Require the same fitted observations for likelihood-ratio comparisons; different
  samples are descriptive sensitivity analyses. Non-significance does not prove
  equal fit. Preserve valid `se = FALSE` fits and address MAP-prior rejection in #28.

## Release history and design notes

Version 0.1.0 established preparation and exchangeable covariance recovery.
Version 0.2.0, accepted on 2026-08-21, stabilized generated names, metadata,
summaries, arbitrary contrasts, optional APIM grand-mean centering, model-comparison
names, and longitudinal structural completion. Its intentional API changes use
direct migration without deprecated wrappers.

The accepted `v0.2.0` archive is recorded at
[10.5281/zenodo.22047084](https://doi.org/10.5281/zenodo.22047084); future GitHub
Releases use the continuing native Zenodo series. The older manual series remains
historical. The [full pre-reorganization roadmap](https://github.com/Pascal-Kueng/dyadMLM/blob/24a495e8cef7c44091c8290ea417680072011f46/dev/roadmap.md)
preserves the detailed 0.1.0/0.2.0 implementation and release-check record.

- [Predictor decomposition and construction](centering.md)
- [Covariance recovery mathematics and design](backtransform.md)
- [Directional DSM derivation and validation](dsm.md)
- [ILD evidence and tutorial policy](ild-nonindependence.md)
- [Diagnostic scope and validation](diagnostic_checks/README.md)
- [APIM decomposition and paper](paper-idea-explaining-interdependence-apim.Rmd)
- [Provisional custom Stan plan](stan.md)
- [Preparation debugging helpers](debug-data-preparation.R)

Some design notes retain historical API wording. Consult current code, generated
help, and tests before using an old note as an implementation specification.
