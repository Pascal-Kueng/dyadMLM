# APIM covariance decomposition: current paper plan

Updated **1 September 2026**. This is the working plan, not a finalized protocol.
It replaces the duplicated planning sections previously embedded in the
[technical notes](paper-idea.Rmd). The [literature review](literature-review.md)
records source evidence and access gaps; the [short outline](paper-outline.Rmd)
provides the figures and a meeting-ready summary.

## Programme and positioning

- **Paper 1, current priority:** cross-sectional linear APIM, including covariates,
  multiple predictors, and distinguishable/exchangeable dyads; clarify the
  estimand and reporting, evaluate uncertainty, and provide reproducible software.
- **Paper 2, planned next:** Gaussian ILD, within/between dependence, and
  heterogeneous actor/partner effects. Establish its contribution and feasibility
  separately; do not enlarge Paper 1 to cover it.
- **Paper 3, conditional:** observed-outcome dependence in selected generalized
  joint models. Proceed only if a distinct attribution problem can be resolved
  and validated; three publications are not a foregone conclusion.
- The substantive question is how different modeled routes contribute to dyadic
  outcome covariance. Similar total correlations can conceal different profiles.
  Statistical attribution, including inference about it, is not automatically causal.
- The decomposition, named routes, signed correlation-unit reporting, diagrams,
  and APIM software already have direct precedents: [Dwyer et al. (2017)](https://doi.org/10.1016/j.amepre.2017.01.011),
  the [Bolger-Laurenceau webinar (2016)](https://cancercontrol.cancer.gov/sites/default/files/2020-06/flashe-webinar-2.5.2016.pdf),
  [Kenny's handout](https://davidakenny.net/kkc/c7/Explained_Nonindependence.docx), and
  [APIM_MM](https://davidakenny.net/doc/APIM_MM.pdf). Do not claim priority for these.
- Paper 1's intended contribution is a clear, auditable synthesis with validated
  inferential/reporting recommendations. If it only reproduces existing
  calculations, position it as a tutorial/consolidation rather than a new
  statistical method. Contribution-specific inference remains a literature gap
  to investigate, not an established absence of prior work.

## Paper 1: scope and estimand

- Independent, cross-sectional two-member dyads and a linear fixed-slope APIM.
  Gaussian estimation is the starting point for validation; the covariance
  identity itself needs finite second moments and predictor-residual
  orthogonality, not normality.
- Use one distinguishable predictor pair as the running example. Include
  covariates/multiple predictors and exchangeable dyads in the paper's general
  treatment, rather than listing them only as future work.
- Primary target: model-implied marginal outcome covariance across the specified
  population/distribution of dyads. Report signed covariance contributions and
  their common-denominator contributions to model-implied outcome correlation.
- Keep observed correlation, residual correlation, and changes in residual
  covariance across separately fitted models distinct from that primary target.
  Do not force the contributions to reproduce the observed correlation.
- For several predictors, retain cross-predictor and predictor-covariate terms.
  Report cross-block contributions separately initially; allocating them to
  individual constructs requires an explicit convention and depends on coding.
- Covariate-adjusted slopes combined with marginal predictor moments still
  describe a marginal target. Conditional-on-covariate and linear-adjustment
  targets need their own moment definitions; they are not interchangeable.
- For exchangeable dyads, impose the model's label-symmetric coefficient and
  moment constraints and group the arbitrary member-driven contributions.
  Equality constraints alone do not make substantively distinguishable roles
  exchangeable.
- Exclude random slopes, ILD, nonlinear links, formal causal identification,
  and automatic allocation of interaction/variance shares from Paper 1.

## Paper 1: argument and displays, in order

1. **Introduction:** motivate interpretation of total interdependence, acknowledge
   the direct precedents, and state the clarification/validation question. No
   equations; use the equal-total/different-profile idea as the motivating example.
2. **Model and routes:** introduce the complete left-to-right APIM and highlighted
   paths. Place the paired outcome equations, indexing, and assumptions here.
3. **Decomposition and reporting:** show the five-term identity, component table,
   model-implied variances, and common denominator. Explain signed contributions,
   cancellation, and the distinction from residual correlation; show the waterfall.
4. **Covariates, multiple predictors, and exchangeability:** give the compact matrix
   identity, cross-block terms, and symmetric special case. Use one short worked
   extension; put long expansions in the supplement. These are within Paper 1.
5. **Estimation, uncertainty, and software:** define the target and fitted-sample
   moments, compare candidate interval procedures, and give a concise R/Mplus
   workflow. A compact delta-method expression and bootstrap algorithm box suffice.
6. **Simulation study:** test estimator and interval behavior, not the truth of the
   algebra. Present the most consequential bias/coverage results and the resulting
   recommendations; put the full design and Monte Carlo uncertainty in the supplement.
7. **Empirical example:** report observed and model-implied totals, signed
   contributions, intervals, and convergence information. Interpret the route
   profile; include the adjusted/multiple-predictor case if substantively useful.
8. **Discussion:** state what the validated workflow adds, give a minimum reporting
   checklist, and identify limits. Briefly motivate Papers 2 and 3 without promising
   support or claiming their novelty before a focused review.
9. **Supplement:** derivations, gradients/joint parameter covariance, complete
   inference algorithms, simulation specifications, and reproducible R/Mplus code.

Keep the main text question-led, with plain-language interpretation after each
equation. Aim for roughly 6-8 compact equation groups rather than repeated
component-by-component formulas. Preserve the four existing illustrations;
add simulation and empirical displays only when results exist. Choose the
journal before fixing page/word limits. Writing models: Laurenceau and Bolger
(2005) for exposition, Ledermann et al. (2011) for compound dyadic quantities,
and Gistelinck et al. (2018) for simulation-to-recommendation structure; see the
[annotated references](literature-review.md#5-writing-examples-path-algebra-and-neighboring-methods).

## Paper 1: inference and validation

- Compare a **joint delta method** with a **whole-dyad bootstrap** before selecting
  a recommended procedure. SEM already computes uncertainty for defined parameters;
  adding an interval call is not itself the methodological contribution
  ([lavaan documentation](https://lavaan.ugent.be/tutorial/mediation.html)).
- For population/random-predictor inference, propagate joint uncertainty in
  slopes, predictor/covariate moments, and residual parameters, including their
  effect on the common denominator. A slopes-only covariance matrix is insufficient.
  Distinguish this from inference conditional on a fixed observed design.
- In each bootstrap sample, resample independent dyads intact, refit, and
  recompute all required moments and denominators. Prespecify interval types,
  resample counts, and failed-fit handling; report failures transparently.
- Evaluate zero/near-zero path products, squared terms under exchangeability,
  and boundary estimates. First-order delta inference can degenerate when
  product gradients vanish; ordinary bootstrap is not automatically valid there.
- Prioritize intervals for magnitudes and prespecified substantive contrasts.
  Do not automatically add five component p-values. If formal tests are retained,
  define their nulls and evaluate calibration separately from interval coverage.
- Plan a focused simulation: vary dyad count, predictor correlation/collinearity,
  unequal variances, coefficient symmetry, path signs/cancellation, residual
  dependence, and one covariate/multiple-predictor setting. Include near-zero
  total covariance as a reporting stress test, not a denominator to divide by.
- Report bias, empirical standard error, interval coverage/width, convergence,
  and Monte Carlo uncertainty. Verify algebraic reconstruction separately to
  numerical tolerance; do not describe that check as evidence of estimator accuracy.

## Software and reproducibility

- Add decomposition functionality to **dyadMLM**, not a new fitting engine or
  separate package. `decompose_apim_covariance()` remains a proposed function;
  no public implementation or validated contribution intervals are claimed yet.
- Separate backend-neutral covariance algebra, APIM term mapping, fitted-model
  extraction, inference, and presentation. Keep R and Mplus examples transparent
  enough to reproduce the quantities without relying on the package wrapper.
- Start with one-predictor distinguishable `glmmTMB` and an independent joint-SEM
  calculation in R/lavaan. Match samples, parameter constraints, ML/REML choices,
  and predictor-moment conventions before comparing numerical results.
- Then validate exchangeability and covariate/multiple-predictor cases. A narrower
  initial software release is acceptable if documented explicitly; paper scope
  does not imply every backend already supports every case. Existing `brms`
  roadmap work remains separate from Paper 1's minimum requirements.
- Return signed components, totals, outcome variances/denominators, predictor
  moments, fitted-dyad count, coefficient mapping, covariance source, backend,
  and target assumptions. Reject unsupported or ambiguous structures.
- Begin reproducibility checks on complete paired data; specify missing-data
  support before combining incomplete-data fits with separately estimated moments.
  Test row/term ordering, role relabeling, exchangeable invariance, cross-terms,
  and agreement between scalar and matrix calculations.
- Keep third-party full texts in the ignored reference folder. Publish our code,
  summaries, metadata, and permitted data; archive the supported implementation
  and reproducible results before submission.

## Paper 2: Gaussian ILD, levels, and heterogeneous effects

- Separate between-level and contemporaneous within-dyad covariance. A candidate
  primary target is population-average within-dyad covariance; confirm that choice
  before deriving or implementing the extension.
- Define the conditioning/marginalization level, predictor reference distribution,
  and dyad/occasion weighting. Show conditional dependence at chosen predictor
  values as a complementary quantity, not an interchangeable estimate.
- Include relevant random-intercept, random-slope, intercept-slope, and
  cross-member coefficient covariances. Mean products of random coefficients
  need not equal products of their means.
- Keep level-specific covariance, level-specific correlation, and correlation
  after pooling distinct. Averaging covariances and averaging correlations are
  different operations.
- A contemporaneous focus still requires attention to serial dependence in
  estimation and inference. Retain whole trajectories when resampling independent
  dyads. Extensive lagged feedback/dynamic models are outside the core scope.
- Review the longitudinal APIM literature and related random-slope moment work
  ([Johnson, 2014](https://doi.org/10.1111/2041-210X.12225)) before claiming novelty.
  Develop a feasible random-effects specification, parameter-recovery/interval
  study, empirical example, and extension of the same software interface.

## Paper 3: generalized outcomes, only if justified

- Ask how to attribute dependence between **observed outcomes** under nonlinear
  joint models. Non-normal continuous data alone do not invalidate the linear
  covariance identity established in Paper 1.
- Start with selected binary/count constructions and relatively simple models;
  do not simultaneously promise all families or every ILD/random-slope feature.
- Specify the dependence measure, full joint outcome model, and predictor
  reference distribution. Marginal logistic/Poisson regressions alone do not
  determine residual dependence between partners.
- Distinguish a latent response, a linear predictor, and the observed outcome;
  these scales do not all have the same interpretation or variance structure.
- Exact total-covariance identities remain available. What generally lacks the
  linear model's natural form is allocation into four separate path-product
  contributions on the response scale. State and justify the allocation rule.
- Identify tractable exact cases and validate numerical integration elsewhere;
  do not assume that every generalized model requires approximation. Existing
  count-model variance/ICC results are essential prior art
  ([Leckie et al., 2020](https://doi.org/10.1037/met0000265)), not the same as a
  validated APIM route-attribution framework.
- Proceed as a standalone paper only if it resolves a distinct interpretation
  or inference problem. Evaluate prevalence/event-rate effects, weak dependence,
  uncertainty, and an empirical case before promising package support.

## Decisions and next actions

- [x] Assemble the broad APIM scoping review and distinguish six confirmed applied
  uses from total-only explanations, adjacent models, and unverified sources.
- [ ] Obtain Dwyer's calculation supplement and the full 2024 Kenny-Ackerman-Kashy
  chapter; complete the targeted contribution-inference and extension searches.
- [ ] Agree with collaborators on Paper 1's target journal, substantive example,
  scope, division of work, feedback cadence, and authorship responsibilities.
- [ ] Use outline + figures -> feedback -> revised outline -> rough draft as the
  proposed workflow; confirm that this suits the collaborators.
- [ ] Finalize target moments, covariate/cross-term reporting, missing-data limits,
  candidate intervals, and any prespecified contrasts before the simulation grid.
- [ ] Prototype the common calculation and independent SEM check, run a small
  inference pilot, then lock the focused simulation design and empirical workflow.
- [ ] Draft Paper 1 while keeping later-paper ideas here; do not create duplicate
  promises or separate software implementations for unvalidated extensions.
