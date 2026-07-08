
# Roadmap for 'interdep' R-Package

This package provides functions for preparing composition-aware dyadic
multilevel models, focusing on cross-sectional and intensive longitudinal (ILD)
data. The package should not try to replace model engines such as `glmmTMB` or
`brms`. Its core responsibility is to make the dyadic composition logic,
temporal decomposition, indicators, constraints, interpretation helpers, and
eventually model syntax explicit and reproducible.

## Development Notes

- Temporal decomposition and predictor-shape planning: [`centering.md`](centering.md)
- Possible future reintroduction of inspection-only incomplete/unknown dyads:
  [`keep-behavior-notes.md`](keep-behavior-notes.md)
- Long-term custom Stan / dyadic residual VAR planning: [`stan.md`](stan.md)
- Composition-inference debugging scratch code:
  [`debug-infer-compositions.R`](debug-infer-compositions.R)

## Version 0.1.0 - First CRAN Release Candidate

Goal: ship a small, reliable data-preparation workflow with enough ILD support
to be useful for composition-aware dyadic MLMs before adding larger
model-building features.

- Validate dyadic data and return a model-ready tibble with metadata
- Support cross-sectional and ILD data for distinguishable and exchangeable
  dyads
- Auto-detect roles, dyad compositions, and distinguishability where possible
- Handle incomplete dyads and missing roles with explicit `error` and `drop`
  behavior
- Return factor columns for `.i_composition` and
  `.i_composition_role`
- Add temporal decomposition and predictor-shape helpers for ILD data
  - Keep the implemented `time_2l` workflow described in [`centering.md`](centering.md)
  - Keep APIM and DIM on the same temporal-decomposition foundation
  - Use `temporal_decomposition = "auto"` by default: resolve to `time_2l`
    when both `time` and predictors are supplied, and to `none` otherwise
  - Allow explicit `temporal_decomposition = "none"` for undecomposed or
    externally centered cases
  - Support raw APIM columns, within-/between-person APIM columns, and DIM
    dyad-mean / individual-deviation columns
  - Keep missing-data behavior explicit
  - Keep `predictors` as the predictor-side API; add future `outcomes`
    metadata separately rather than turning `predictors` into a generic
    variable list
- Add a print method for `interdep_data`
  - Keep normal tibble/data-frame printing; add a compact interdep header above
    the data output
  - Show number of dyads, whether data are longitudinal, and inferred
    composition counts
  - Show structural columns: group, member, optional role, optional time
  - Show dyad compositions with composition name, dyad type, and dyad count
  - Show generated column families and one-line meanings:
    `.i_composition`, `.i_composition_role`, `.i_diff`, `.i_is_*`, `.i_diff_*`,
    and generated predictor-column families
  - Make dropped incomplete dyads and missing roles visible
  - Target display:
    ```r
    # interdep data
    # Rows: 5,600 | Dyads: 200 | Intensive longitudinal: yes
    # Structure: group = coupleID, member = personID, role = gender, time = diaryday
    #
    # Dyad compositions:
    # female_x_male   distinguishable 80 dyads
    # female_x_female exchangeable    60 dyads
    # male_x_male     exchangeable    60 dyads
    #
    # Added columns:
    #   .i_composition       inferred dyad composition
    #   .i_composition_role  composition-specific member role
    #   .i_is_*              composition-role indicator columns
    #   .i_diff              sum-diff contrast; 0 for distinguishable dyads
    #   .i_diff_*            composition-specific sum-diff contrasts
    #   .i_*_cwp             within-person centred predictors
    #   .i_*_cbp             between-person centred predictors
    #   .i_*_cwp_actor       within-person actor predictor columns
    #   .i_*_cwp_partner     within-person partner predictor columns
    #   .i_*_cbp_actor       between-person actor predictor columns
    #   .i_*_cbp_partner     between-person partner predictor columns
    #
    # Dropped incomplete dyads: 14 dyads, with IDs: 12, 18, 44, 51, 60, 72, 80, 91, 104, 110, and 4 more.
    # A tibble: 5,600 x 17
       personID coupleID diaryday gender closeness provided_support .i_composition ...
          <int>    <int>    <int> <fct>      <dbl>            <dbl> <fct>          ...
     1        1        1        0 female      5.91             4.72 female_x_male  ...
     2        1        1        1 female      6.10             5.01 female_x_male  ...
     3        1        1        2 female      5.44             4.63 female_x_male  ...
    # i 5,597 more rows
    ```
  - Do not add sparse-composition warnings to `print()` yet; thresholds are too
    arbitrary for a compact display
- Add composition role indicator columns for cross-sectional model workflows
- Add small inspection helpers
  - Show generated `.i_*` columns by purpose
  - Show composition counts and sparse-composition warnings
- Keep README and vignette focused on the data-preparation workflow
- Add a focused DIM vignette after reviewing the DIM helper API
- Add citation metadata
  - `inst/CITATION` for R users
  - `CITATION.cff` for GitHub and future Zenodo metadata

### Pre-CRAN v0.1.0 Checklist

Complete these before calling the feature set CRAN-ready:

- Review `add_dyad_individual_columns.R` carefully
  - confirm direct grouped DIM construction is final
  - confirm missingness behavior for incomplete dyad components is documented
  - confirm raw cross-sectional DIM names are final
- Finalize DIM metadata
  - decide whether `dim_predictors` table columns are stable:
    `predictor`, `component`, `source_column`, `mean_column`,
    `deviation_column`, `decomposition_level`
  - make sure downstream print/vignette code reads metadata rather than
    guessing column names where possible
- Decide whether `print.interdep_data()` should show DIM column families
  - if yes, add compact descriptions for `.i_*_dyad_mean` and
    `.i_*_dyad_deviation`
  - avoid listing every generated column individually
- Add a short DIM vignette after the DIM API is stable
  - show cross-sectional APIM-DIM equivalence
  - show ILD DIM construction from `time_2l` components
  - keep mixed-composition/maximal models in the APIM vignette for now
- Resolve unified ILD model convergence documentation
  - current increased simulation size improves information but does not fully
    remove Gaussian optimizer warnings for the maximal unified ILD APIM
  - do not present BFGS as a universal fix; document optimizer behavior only
    where it is empirically supported by the current simulated data
  - either simplify the vignette model deliberately or explain that the maximal
    model is aspirational/diagnostic and may require more data or Bayesian
    regularization
- Run final release checks
  - `devtools::test(reporter = "summary")`
  - `devtools::check(args = "--no-manual", error_on = "never")`
  - inspect README, vignette, examples, `inst/CITATION`, and package metadata
    for CRAN-facing clarity

- Release to CRAN once checks, tests, docs, README, and vignette are clean
  - Submit source package to CRAN without requiring a Git tag first
  - After CRAN acceptance, tag the accepted commit as `v0.1.0`
  - Create a GitHub release from that tag
  - Archive the GitHub release on Zenodo
  - Add the Zenodo concept DOI to README and citation metadata on `main`
  - Include the DOI in the next CRAN release

## Version 0.2.0

- Add helper functions to rotate `.i_diff` / Idiff structures back to
  partner-level interpretations
- Add outcome-aware preparation for dyadic-score models
  - Add `outcomes = NULL` to store outcome variables separately from
    `predictors`
  - Add `model_type = "dyadic_score"` for undirected dyadic-score models
  - Reuse DIM construction for predictor-side dyad means/deviations
  - Add a separate outcome helper for raw dyad-time outcome means and
    deviations
  - Do not within-/between-person center ILD outcomes by default; reserve
    centered outcome scores for an explicit later option
- Constrain and pool compositions
  - Example: treat male-female dyads as exchangeable
  - Example: pool male-male and female-female dyads as same-sex
  - Preserve clear metadata about original and modeled compositions
- Write static model syntax for cross-sectional and ILD models
  - `glmmTMB` first
  - `brms`, including priors, once the `glmmTMB` syntax path is stable
  - Consider `dynamite` or another MLSEM/DSEM framework later
- Add tests that generated syntax matches intended estimands and model
  structures

## Version 0.3.0

- Estimation helpers for supported model engines
  - Prefer thin wrappers around established engines
  - Do not add a custom Stan backend unless the package contribution becomes a
    new estimator rather than preparation/syntax infrastructure
- Model summaries focused on dyadic interpretation
- Diagnostics and sparse-composition guidance
- Optional wide-to-long preprocessing helper
  - Keep `prepare_interdep_data()` strict: it should continue to validate one
    canonical long-format dyadic structure
  - Add reshaping only as a separate helper that converts common two-person
    wide formats into the long structure expected by `prepare_interdep_data()`
  - Treat this as convenience infrastructure, not part of the core validation
    contract
- Optional preprint or methods note
  - Cite the Zenodo software DOI for the implementation
  - Use the preprint for the composition-aware dyadic MLM framework

## Version 0.4.0

- Advanced ILD/EMA data infrastructure
  - Add `time_3l` temporal decomposition only after the `time_2l` workflow is
    stable
  - Require an explicit day, burst, or period variable for `time_3l`
  - Do not infer `time_3l` automatically from EMA nesting or three-level random
    effects; users should request it when the substantive predictor
    decomposition requires it
  - Keep `time_4l` out of scope unless a concrete applied use case justifies the
    extra API and interpretation burden
  - Keep the terminology focused on temporal predictor decomposition, not on
    claiming that fitted models have exactly two or three levels
- Dynamic-data preparation groundwork for later model engines
  - Add transition-record or dyad-occasion data helpers only if needed by the
    model-syntax or custom-model tracks
  - Support ragged complete dyad-days and full dyad-day gaps before attempting
    one-partner missingness in dynamic models
  - Keep one-partner missingness and latent-state handling out of the core
    preparation API until a modeling layer needs them

## Version 0.5.0 and Later

- Evaluate a custom Stan track only after the package has stable validation,
  temporal decomposition, actor/partner helpers, syntax generation, and fit/summary
  conventions for established engines
- If custom Stan becomes part of the package scope, follow the staged dyadic
  residual VAR plan in [`stan.md`](stan.md)
  - Start with Gaussian, two-person dyadic residual VAR(1) models
  - Start balanced, then add ragged complete dyad-days and full dyad-day gaps
  - Keep non-Gaussian likelihoods, arbitrary DSEM features, one-partner
    missingness, and latent centering out of the first Stan implementation
  - Preserve the package-wide composition metadata and exchangeability
    constraints rather than introducing a parallel dyad registry

## JOSS Readiness

JOSS should be a later milestone, not a first-release target. A JOSS submission
does not require `interdep` to estimate models itself, but it should be more
than a thin data-preparation wrapper.

Target state before JOSS submission:

- Public development history of at least six months
- Tagged releases, changelog, tests, documentation, and clear contribution
  guidance
- Evidence of research use, ideally a preprint or applied analysis using the
  package
- Robust temporal decomposition for ILD data
- Composition pooling/constraining helpers
- `.i_diff` / Idiff interpretation helpers
- Formula or syntax generation for at least `glmmTMB`
- Preferably `brms` syntax generation as a second modeling backend
- Reproducible vignettes showing composition-aware dyadic MLM workflows
- Clear statement that `interdep` supplies dyadic composition logic, temporal
  decomposition, indicators, constraints, interpretation helpers, and syntax
  for established model engines
