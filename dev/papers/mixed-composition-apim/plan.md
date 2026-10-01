# Mixed compositions and singletons in the APIM

Working paper idea, 2 October 2026. No novelty claim is settled.

## Research question and possible contribution

How can researchers fit and interpret one Gaussian APIM for distinguishable and
exchangeable dyad compositions, while retaining people observed alone and
distinguishing an absent partner from missing partner data?

The ingredients have precedents. The possible contribution is an explicit,
reproducible framework connecting composition-specific means, actor/partner
slopes, covariance choices and singleton status, with evidence about when the
choices matter. A different software parameterization alone is insufficient to
establish methodological novelty. See the [literature review](literature-review.md)
and [bibliography](references.bib).

## Proposed manuscript structure

1. **Applied problem.** One running example with female–male, female–female and
   male–male dyads, plus people observed alone. Define composition, role,
   participation and relationship status separately.
2. **Model and choices.** Paired outcome equations; composition/role means and
   slopes; unrestricted distinguishable and exchangeable covariance blocks;
   pooled or separate singleton variances; two-part partner predictors and
   actor-slope differences by status. Explain equivalence to existing Gaussian
   models before introducing implementation details.
3. **Worked analysis.** A short `glmmTMB` implementation and interpretation,
   ideally with an empirical example. Use a diagram and compact parameter table
   only where they clarify a modeling choice.
4. **Validation.** Parameter recovery, interval coverage and fit availability;
   then a focused comparison of plausible pooling choices under the same data
   generation. Put full conditions and parameter tables in the supplement.
5. **Practical guidance.** When pooling is defensible, what singletons inform,
   limits from missing predictors and weak covariance identification, and the
   limits of the evidence.

Start with cross-sectional Gaussian models. Longitudinal random-intercept models
can illustrate an extension; extensive random slopes need stronger fitting and
validation evidence before becoming a main recommendation. Generalized outcomes,
changing partners and latent centering are outside the initial scope.

## Existing material and evidence

- [Draft vignette](../../vignettes/mixed-apim.Rmd): model specifications and
  singleton examples.
- [Recovery study](../../diagnostic_checks/simulation-studies/mixed-apim-recovery/README.md)
  and [report](../../../vignettes/articles/mixed-apim-recovery.Rmd): 12 correctly
  specified Gaussian conditions, 500 datasets each, 120 or 360 dyads.
- The saved full run contains 6,000 attempts. Cross-sectional and
  random-intercept models returned 4,000/4,000 usable fits; fixed-effect 95% Wald
  coverage ranged from 91.6% to 97.8% across their coefficients and conditions.
  Random-slope usable-fit rates ranged from 30.8% to 58.6%. These findings support
  the simpler specifications but do not establish uniformly calibrated inference.
- The study excludes singletons, missingness and extra serial dependence. It
  reports covariance point recovery, not covariance-interval coverage. Pooled
  and separate conditions have different generating parameters, so they do not
  isolate the consequence of choosing the wrong pooling structure.

## Before developing the paper

Clarify the precise advance through further citation searching and model
comparison. Verify matched Gaussian likelihoods against direct residual-covariance
implementations. Add a small singleton study covering true absence versus partner
nonparticipation, pooled versus separate variances, and shared versus different
actor slopes. Evaluate pooling under both matching and mismatching generating
structures. Select an empirical dataset that makes at least one of these choices
substantively useful. These are proposed next steps, not completed studies.
