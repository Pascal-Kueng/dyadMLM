
# Roadmap for 'interdep' R-Package

This package provides functions for preparing composition-aware dyadic
multilevel models, focusing on cross-sectional and intensive longitudinal (ILD)
data. The package should not try to replace model engines such as `glmmTMB` or
`brms`. Its core responsibility is to make the dyadic composition logic,
temporal predictor decomposition, indicators, constraints, interpretation
helpers, and eventually model syntax explicit and reproducible.

## Development Notes

- Temporal predictor decomposition and predictor-shape planning:
  [`centering.md`](centering.md)
- Possible future reintroduction of inspection-only incomplete/unknown dyads:
  [`keep-behavior-notes.md`](keep-behavior-notes.md)
- Long-term custom Stan / dyadic residual VAR planning: [`stan.md`](stan.md)
- Composition-inference debugging scratch code:
  [`debug-infer-compositions.R`](debug-infer-compositions.R)

## Vignette Architecture

Keep the first-contact documentation short and stable. Heavy or
convergence-sensitive model demonstrations should not live in the getting
started vignette, because that makes onboarding harder and can make CRAN/pkgdown
builds slow or fragile when optional modeling packages are installed.

Target vignette structure:

- `getting-started.Rmd`
  - package purpose and expected long data structure
  - `group`, `member`, `role`, and `time`
  - distinguishable, exchangeable, and mixed dyad compositions
  - missing structural data rules
  - compact examples of `predictors`, `model_type`, `temporal_predictor_decomposition`,
    print output, and metadata
  - links to model-specific vignettes
  - minimal or no fitted models
- `apim.Rmd`
  - cross-sectional APIM model construction
  - distinguishable and exchangeable APIMs
  - multiple dyad types in one APIM
  - `.i_is_*`, `.i_diff`, and raw actor/partner predictor columns
- `intensive-longitudinal-apim.Rmd`
  - ILD APIMs with temporal predictor decomposition
  - within-person and between-person actor/partner effects
  - generalized outcomes, including Tweedie examples
  - optimizer and convergence notes
  - heavier unified ILD models shown carefully, with `eval = FALSE` where
    needed
- `Dyad-Individual-Model.Rmd`
  - undirected DIM assumptions
  - cross-sectional and ILD APIM-DIM equivalence
  - role-moderated and random-slope material only as advanced/conceptual
    guidance until the implementation is more complete
- future `Dyadic-Score-Model.Rmd`
  - add only after the current `outcomes` and
    `model_type = "undirected_dsm"` API is reviewed
  - keep DSM outcome-side semantics separate from DIM predictor construction

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
- Add temporal predictor decomposition and predictor-shape helpers for ILD data
  - Keep the implemented `time_2l` workflow described in [`centering.md`](centering.md)
  - Keep APIM and DIM on the same temporal predictor decomposition foundation
  - Use `temporal_predictor_decomposition = "auto"` by default: resolve to
    `time_2l` when both `time` and predictors are supplied, and to `none`
    otherwise
  - Allow explicit `temporal_predictor_decomposition = "none"` for
    undecomposed or externally centered cases
  - Support raw APIM columns, within-/between-person APIM columns, and DIM
    dyad-mean / within-dyad-deviation columns
  - Keep missing-data behavior explicit
  - Keep `predictors` as the predictor-side API; add `outcomes` separately
    for outcome-aware preparation rather than turning `predictors` into a
    generic variable list
- Add minimal undirected dyadic-score model (DSM) data preparation
  - Add `outcomes = NULL` to store outcome variables separately from
    `predictors`
  - Add `model_type = "undirected_dsm"` for undirected DSM preparation only
  - Require one exchangeable dyad composition for the first undirected DSM path
  - Reuse DIM construction for predictor-side dyad means/deviations
  - Add a separate outcome helper for raw dyad outcome means and within-dyad
    deviations
  - For ILD outcomes, compute raw dyad scores within dyad-time
  - Do not within-/between-person center ILD outcomes by default; reserve
    centered or directed DSM outcomes for an explicit later option
- Add a print method for `interdep_data`
  - Keep normal tibble/data-frame printing; add a compact interdep header above
    the data output
  - Show number of dyads, whether data are longitudinal, and inferred
    composition counts
  - Show structural columns: group, member, optional role, optional time
  - Show dyad compositions with composition name, dyad type, and dyad count
  - Show generated column families and one-line meanings:
    `.i_composition`, `.i_composition_role`, `.i_diff`, `.i_is_*`, `.i_diff_*`,
    temporal predictor components, APIM predictor columns, DIM predictor
    columns, and undirected DSM outcome columns
  - Drive generated-column printing from `interdep_generated_columns()`, which
    normalizes temporal predictor, APIM, DIM, and undirected DSM metadata into
    one row per concrete generated column
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
    #   .i_diff              sum-diff contrast for exchangeable dyads; 0 for distinguishable dyads
    #   .i_diff_*            composition-specific sum-diff contrasts
    #   .i_*_cwp             within-person temporal predictor components
    #   .i_*_cbp             between-person temporal predictor components, centred around grand mean of person means
    #   .i_*_cwp_actor       APIM within-person actor predictors
    #   .i_*_cwp_partner     APIM within-person partner predictors
    #   .i_*_cbp_actor       APIM between-person actor predictors
    #   .i_*_cbp_partner     APIM between-person partner predictors
    #   .i_*_cwp_dyad_mean   DIM shared momentary predictor deviations
    #   .i_*_cwp_within_dyad_deviation  DIM person deviations from shared momentary predictor levels
    #   .i_*_cbp_dyad_mean   DIM shared usual predictor levels, centred across persons
    #   .i_*_cbp_within_dyad_deviation  DIM person differences from dyad usual predictor levels
    #   .i_*_raw_dyad_mean   DSM raw outcome dyad means
    #   .i_*_raw_within_dyad_deviation  DSM raw outcome within-dyad deviations
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
- Keep README and `getting-started.Rmd` focused on the data-preparation
  workflow
- Split model-fitting examples out of `getting-started.Rmd`
  - use a cross-sectional APIM vignette for distinguishable, exchangeable, and
    multiple-dyad-type APIM examples
  - use a separate ILD APIM vignette for temporal predictor decomposition,
    generalized outcomes, optimizer notes, and heavier unified ILD examples
- Keep the focused DIM vignette separate from APIM/ILD APIM examples
- Add a short DSM data-preparation example after the DSM API is stable
- Add citation metadata
  - `inst/CITATION` for R users
  - `CITATION.cff` for GitHub and future Zenodo metadata

### Pre-CRAN v0.1.0 Checklist

Complete these before calling the feature set CRAN-ready:

- Review `add_dyad_individual_columns.R` carefully
  - confirm direct grouped DIM construction is final
  - confirm missingness behavior for incomplete dyad components is documented
  - confirm raw cross-sectional DIM names are final
  - keep the v0.1 scope restricted to one exchangeable dyad composition
- Finalize DIM metadata
  - decide whether `dim_predictors` table columns are stable:
    `predictor`, `component`, `source_column`, `mean_column`,
    `deviation_column`, `decomposition_level`
  - keep downstream print/vignette code reading metadata rather than guessing
    column names where possible
- Finalize generated-column metadata
  - keep `interdep_generated_columns()` as the single normalized table for
    generated temporal predictor, APIM, DIM, and undirected DSM columns
  - preserve explicit fields for `temporal_decomposition`,
    `dyadic_decomposition`, and `column_centering`
  - revisit whether temporal rows should keep `decomposition_level = "time_2l"`
    or later split method and level into separate fields
- Keep `print.interdep_data()` descriptions for DIM column families explicit
  - describe raw, cwp, and cbp DIM columns separately when present
  - avoid listing every generated predictor individually
- Review minimal undirected DSM preparation
  - confirm `outcomes` selection and validation are final for v0.1
  - confirm raw outcome dyad means/deviations are the only v0.1 outcome scores
  - confirm dyad-level scores for cross-sectional outcomes and dyad-time scores
    for ILD outcomes are documented clearly
  - keep DSM outcome metadata in `undirected_dsm_outcomes`, separate from
    `dim_predictors`
  - add a short DSM data-preparation vignette/example only after the API feels
    stable
- Finalize vignette split for v0.1.0
  - shorten `getting-started.Rmd` so it is an orientation and data-prep
    vignette, not the main modeling manual
  - move current cross-sectional APIM model-fitting material into an APIM
    vignette
  - move ILD APIM, generalized outcome, optimizer, and unified ILD material into
    an ILD APIM vignette
  - keep heavy or convergence-sensitive examples out of `getting-started.Rmd`
    and mark advanced examples `eval = FALSE` where needed
- Keep the DIM vignette focused
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
- Extend dyadic-score model support beyond the minimal v0.1.0 data-prep API
  - Consider directed DSM variants only after the undirected data-prep path is
    stable
  - Consider centered or change-from-usual DSM outcome scores only as explicit
    options
  - Keep multivariate DSM modeling and formula/syntax generation for a later
    modeling layer
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
  - Add `time_3l` temporal predictor decomposition only after the `time_2l`
    workflow is stable
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
  temporal predictor decomposition, actor/partner helpers, syntax generation,
  and fit/summary conventions for established engines
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
- Robust temporal predictor decomposition for ILD data
- Composition pooling/constraining helpers
- `.i_diff` / Idiff interpretation helpers
- Formula or syntax generation for at least `glmmTMB`
- Preferably `brms` syntax generation as a second modeling backend
- Reproducible vignettes showing composition-aware dyadic MLM workflows
- Clear statement that `interdep` supplies dyadic composition logic, temporal
  predictor decomposition, indicators, constraints, interpretation helpers, and
  syntax for established model engines
