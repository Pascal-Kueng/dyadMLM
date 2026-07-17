
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
  - the note is provisional and must be revised against the methodological
    papers in [`References/`](References/) before implementation
- Directional DSM derivation and implementation record: [`dsm.md`](dsm.md)
- ILD non-independence evidence and tutorial policy:
  [`ild-nonindependence.md`](ild-nonindependence.md)
- Composition-inference debugging scratch code:
  [`debug-infer-compositions.R`](debug-infer-compositions.R)

## Current State

The package is currently in a public development state, not a CRAN-ready release
state. The core data-preparation API is implemented and covered by tests, the
README links to the pkgdown site, and GitHub Actions are configured for
R CMD check and pkgdown publishing.

Recently completed cleanup:

- replaced the old combined-model wording with "mixed dyad types" or
  "mixed-composition" wording
- renamed the mixed example datasets to:
  - `example_dyadic_crosssectional_mixed`
  - `example_dyadic_ILD_mixed`
  - `example_dyadic_ILD_mixed_tweedie`
- kept `LICENSE` for R/CRAN's `MIT + file LICENSE` convention and
  `LICENSE.md` as the full human-readable MIT license
- added GitHub Pages/pkgdown infrastructure and linked available vignettes from
  the README
- kept generated `docs/` and `doc/` output ignored; pkgdown should rebuild the
  site through the GitHub Pages workflow
- added `set_exchangeable_compositions`, so observed distinguishable
  compositions can be treated as exchangeable for generated columns and
  downstream DIM/DSM compatibility
- added `pool_compositions`, so exchangeable analysis compositions can be
  pooled under a user-provided final composition label without external
  preprocessing
- added `include_compositions`, so analyses can keep selected observed dyad
  compositions before exchangeability overrides, pooling, and DIM/DSM
  compatibility checks
- implemented and reviewed separate DIM and directional DSM preparation paths
  for the current v0.0.1 scope
- accepted the current composition metadata shape for v0.0.1: returned data use
  final analysis compositions, while pooling metadata records the pooled source
  compositions in a compact `pooled_from` summary

Immediate next step: finish vignette and release-facing polish. The
getting-started and DIM vignettes have completed detailed review. The APIM,
mixed-APIM, and DSM vignettes still need final review, and the DSM vignette
still needs its planned ILD section.

## Vignette Architecture

Keep the first-contact documentation short and stable. Heavy or
convergence-sensitive model demonstrations should not live in the getting
started vignette, because that makes onboarding harder and can make CRAN/pkgdown
builds slow or fragile when optional modeling packages are installed.

Target vignette structure:

- `getting-started.Rmd`
  - package purpose and expected long data structure
  - `group`, `member`, `role`, and `time`
  - distinguishable, exchangeable, and mixed dyad types
  - missing structural data rules
  - compact examples of `predictors`, `model_type`, `temporal_predictor_decomposition`,
    print output, and metadata
  - links to available model-specific vignettes
  - minimal or no fitted models
- `apim.Rmd`
  - cross-sectional and ILD APIM model construction
  - distinguishable and exchangeable APIMs
  - within-person and between-person actor/partner effects
  - generalized outcomes, including Tweedie examples
  - `.i_is_*`, `.i_diff_*`, and raw actor/partner predictor columns
  - a brief comparison of manifest raw outcome lags and separately estimated
    within-/between-person outcome-lag components, with their different
    interpretations and small-T cautions
- `mixed-apim.Rmd`
  - cross-sectional and ILD APIMs with mixed dyad compositions
  - optimizer and convergence notes
  - heavier mixed-composition ILD models shown carefully, with `eval = FALSE`
    where needed
- `dim.Rmd`
  - exchangeable-dyad DIM assumptions
  - cross-sectional and ILD APIM-DIM equivalence
  - fixed and random-effect transformations
  - random-slope examples
  - a concise section on current limitations of dyadic ILD designs in R
- `dsm.Rmd`
  - directional DSM preparation with an explicit role order
  - dyad-level and signed-difference predictor columns
  - exact long-format interaction model and coefficient interpretations
  - role-order reversal and APIM-DSM transformations
  - a brief ILD extension, still to be added
  - outcomes remain unchanged in the MLM-focused preparation API

## Version 0.0.1 - First CRAN Release Candidate

Goal: ship a small, reliable data-preparation workflow with enough ILD support
to be useful for composition-aware dyadic MLMs before adding larger
model-building features.

- Validate dyadic data and return a model-ready tibble with metadata
- Support cross-sectional and ILD data for distinguishable and exchangeable
  dyads
- Auto-detect roles, dyad compositions, and distinguishability where possible
- Add explicit analysis-composition controls so common mixed dyad-type analyses
  do not require external preprocessing
  - `include_compositions = NULL` is implemented as an observed-composition
    pre-filter before exchangeability overrides and pooling. It is a narrow
    dyad-level filter, not a general row filter:
    - require `role`; without observed roles, there are no observed
      compositions to include or exclude
    - accept the same composition reference aliases as the other composition
      controls, for example `"female_x_female"`, `"female-female"`,
      `"female female"`, or `"female_female"`
    - reject `character(0)`, non-character values, unknown references, and
      filters that leave fewer than two complete dyads
    - infer canonical raw compositions first, resolve `include_compositions`
      against those raw observed compositions, then keep all rows for retained
      dyads and drop all rows for excluded dyads
    - update `attr(data, "interdep")$n_dyads` and all downstream
      `dyad_compositions` metadata to describe only the retained dyads
    - excluded-composition metadata and print summaries are intentionally not
      part of the current minimal implementation
    - after filtering, resolve `set_exchangeable_compositions` and
      `pool_compositions` only against retained compositions, so excluded
      compositions cannot be constrained or pooled accidentally
    - cross-sectional and ILD behavior are covered by tests; ILD filtering must
      retain all observed time rows for included dyads
  - `set_exchangeable_compositions` marks selected observed compositions as
    exchangeable for downstream generated columns
  - `pool_compositions` pools exchangeable analysis compositions under a
    user-provided final composition name
  - Resolve composition references through separated composition labels such as
    `"female_x_male"`, `"female_male"`, `"female-male"`, `"male-female"`, or
    `"female male"`; do not treat `c("female", "male")` as one composition
    reference
  - Apply the steps in this order:
    1. infer canonical raw compositions and create aliases
    2. apply `include_compositions`, if supplied, as a whole-dyad raw
       composition filter
    3. apply `set_exchangeable_compositions`
    4. apply `pool_compositions` only to compositions that are exchangeable
       after step 3
    5. build `.i_composition`, `.i_composition_role`, `.i_is_*`, `.i_diff_*`,
       print summaries, and metadata from the final analysis compositions
  - Keep raw observed compositions out of the returned data columns, but
    preserve pooling provenance in `attr(data, "interdep")$dyad_compositions`
  - Error clearly for unknown aliases, ambiguous aliases, overlapping pooling
    definitions, or pooling requests that include non-exchangeable compositions
- Handle incomplete dyads and missing roles with explicit `error` and `drop`
  behavior
- Return factor columns for `.i_composition` and
  `.i_composition_role`
- Add temporal predictor decomposition and predictor-shape helpers for ILD data
  - Keep the implemented `time_2l` workflow described in [`centering.md`](centering.md)
  - Keep APIM, DIM, and DSM on the same temporal predictor decomposition
    foundation
  - Use `temporal_predictor_decomposition = "auto"` by default: resolve to
    `time_2l` when both `time` and predictors are supplied, and to `none`
    otherwise
  - Allow explicit `temporal_predictor_decomposition = "none"` for
    undecomposed or externally centered cases
  - Support raw and within-/between-person model-ready columns for APIM, DIM,
    and DSM, including DIM within-dyad deviations using the
    `_within_dyad_dev` suffix
  - For ILD models using `time_2l`, retain each selected raw predictor alongside
    its CWP and CBP components in the shared predictor metadata
    - construct raw APIM actor/partner columns and raw DIM/DSM dyadic scores
      from the shared metadata
    - decompose raw longitudinal DIM/DSM predictors within dyad-occasion, while
      retaining dyad-level construction for CBP components
    - keep the established `.i_{pred}_actor` and `.i_{pred}_partner` names; do
      not reintroduce `_raw_` into generated column names
    - document that raw and decomposed versions of the same contemporaneous
      predictor should not all be included in one formula because they are
      linearly dependent
    - allow users to include an outcome in `predictors`, lag the raw
      model-specific columns, and choose a manifest raw-lag or within-between
      lag parameterization
    - test raw-column values, model metadata and print output, dyad-occasion
      matching and decomposition, and coexistence across model requests
  - Keep missing-data behavior explicit
  - Keep `predictors` as the only transformed-variable API; select outcomes in
    fitted-model formulas
- Add directional dyadic-score model (DSM) data preparation
  - Use `model_type = "dsm"` with an explicit `dsm_role_order`
  - Require one distinguishable dyad composition
  - Reuse neutral dyad-mean/member-deviation calculations internally
  - Create full signed predictor differences and a `+0.5/-0.5` role contrast
  - Leave outcomes unchanged
- Add a print method for `interdep_data`
  - Keep normal tibble/data-frame printing; add a compact interdep header above
    the data output
  - Show number of dyads, whether data are longitudinal, and inferred
    composition counts
  - Show structural columns: group, member, optional role, optional time
  - Show dyad compositions with composition name, dyad type, and dyad count
  - Show generated column families and one-line meanings:
    `.i_composition`, `.i_composition_role`, `.i_is_*`, `.i_diff_*`,
    temporal predictor components, APIM predictor columns, DIM deviations, and
    DSM directional predictor columns
  - Drive generated-column printing from `interdep_generated_columns()`, which
    normalizes temporal predictor, APIM, DIM, and DSM metadata into
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
    #   .i_composition                  inferred dyad composition
    #   .i_composition_role             composition-specific member role
    #   .i_is_{comp-role}               composition-role indicator columns
    #   .i_diff_{comp}                  composition-specific sum-diff contrasts; 0
    #                                   for distinguishable dyads or other
    #                                   exchangeable compositions
    #   .i_{pred}_cwp                   within-person predictor: momentary
    #                                   deviations from each person's usual level
    #   .i_{pred}_cbp                   between-person predictor: stable
    #                                   differences from the average person's usual
    #                                   level
    #   .i_{pred}_actor                 APIM actor predictor: actor's original values
    #   .i_{pred}_partner               APIM partner predictor: partner's original values
    #   .i_{pred}_cwp_actor             APIM within-person actor predictor: actor's
    #                                   momentary deviations from their usual level
    #   .i_{pred}_cwp_partner           APIM within-person partner predictor:
    #                                   partner's momentary deviations from their
    #                                   usual level
    #   .i_{pred}_cbp_actor             APIM between-person actor predictor:
    #                                   actor's stable difference from the average
    #                                   person's usual level
    #   .i_{pred}_cbp_partner           APIM between-person partner predictor:
    #                                   partner's stable difference from the
    #                                   average person's usual level
    #   .i_{pred}_dyad_mean_gmc         raw dyad-mean predictor, grand-mean centered
    #   .i_{pred}_within_dyad_dev       DIM raw within-dyad predictor deviation
    #   .i_{pred}_within_dyad_diff      DSM raw signed predictor difference
    #   .i_{pred}_cwp_dyad_mean         within-person dyad-mean predictor:
    #                                   shared momentary deviations in the dyad
    #   .i_{pred}_cwp_within_dyad_dev
    #                                   DIM within-person within-dyad predictor
    #                                   deviation: person's momentary deviation
    #                                   from the dyad average
    #   .i_{pred}_cbp_dyad_mean         between-person dyad-mean predictor:
    #                                   dyad's stable usual level, grand-mean
    #                                   centered
    #   .i_{pred}_cbp_within_dyad_dev
    #                                   DIM between-person within-dyad predictor
    #                                   deviation: person's stable difference from
    #                                   the dyad's usual level
    #   .i_dsm_role_contrast            DSM +0.5/-0.5 directional role contrast
    #   .i_{pred}_cwp_within_dyad_diff   DSM within-person signed predictor difference
    #   .i_{pred}_cbp_within_dyad_diff   DSM between-person signed predictor difference
    #
    # Dropped incomplete dyads: 14 dyads, with IDs: 12, 18, 44, 51, 60, 72, 80, 91, 104, 110, ... and 4 more
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
- Keep generated-column inspection internal for v0.0.1
  - `interdep_generated_columns()` remains the internal normalized table used by
    printing
  - generated-column meanings are exposed through `print.interdep_data()`
  - public inspection helpers and sparse-composition diagnostics are deferred
    until there is a concrete user need
- Keep README and `getting-started.Rmd` focused on the data-preparation
  workflow
- Split model-fitting examples out of `getting-started.Rmd`
  - use `apim.Rmd` for cross-sectional and ILD distinguishable or exchangeable
    APIM examples
  - use `mixed-apim.Rmd` for cross-sectional and ILD mixed-composition APIM
    examples and optimizer notes
- Keep the focused DIM vignette separate from APIM/ILD APIM examples
- Keep the DSM data-preparation examples aligned with the implemented API
- Add citation metadata
  - `inst/CITATION` for R users
  - `CITATION.cff` for GitHub and future Zenodo metadata

### Pre-CRAN v0.0.1 Checklist

Complete these before calling the feature set CRAN-ready:

- Rebuild and inspect generated documentation
  - run `devtools::document()`
  - render `README.Rmd`
  - build pkgdown locally when changing vignette structure or `_pkgdown.yml`
- DIM and directional DSM preparation review: done for the current v0.0.1 scope
  - direct grouped DIM construction is accepted
  - raw cross-sectional and longitudinal DIM names are accepted
  - DIM remains restricted to one final exchangeable composition
  - DSM remains restricted to one final distinguishable composition matching
    `dsm_role_order`
- Analysis-composition controls: done for v0.0.1
  - `include_compositions` is implemented as a raw observed-composition dyad
    filter before `set_exchangeable_compositions` and `pool_compositions`
  - `include_compositions` updates retained dyads and downstream metadata; a
    separate excluded-composition metadata table or print summary is deferred
    unless users need it
  - `set_exchangeable_compositions` runs before `pool_compositions`
  - the name `set_exchangeable_compositions` is intentionally specific; avoid
    generic "constraints" wording
  - `pool_compositions` is a named list where names are final analysis
    composition labels and values are observed or analysis composition labels
    to pool
  - `include_compositions`, `set_exchangeable_compositions`, and
    `pool_compositions` use the same composition-reference resolver
  - returned data are limited to final analysis columns, not extra raw
    composition columns
  - pooling provenance is recorded in `dyad_compositions$pooled_from`
- DIM metadata: done for v0.0.1
  - the current `dim_predictors` table columns are stable for v0.0.1:
    `predictor`, `component`, `source_column`, `mean_column`,
    `deviation_column`, `dyad_decomposition_level`
  - keep downstream print/vignette code reading metadata rather than guessing
    column names where possible
- Generated-column metadata: done for v0.0.1
  - `interdep_generated_columns()` stays internal as the single normalized table
    used by printing and documentation-facing summaries of generated temporal
    predictor, APIM, DIM, and DSM columns
  - expose generated-column meanings through `print.interdep_data()` for
    v0.0.1;
    consider a public wrapper later only if users need programmatic inspection
  - preserve explicit fields for `temporal_decomposition`,
    `dyadic_decomposition`, and `column_centering`
  - keep source-metadata fields such as `dim_predictors$dyad_decomposition_level`
    out of the normalized generated-column interpretation table unless they
    answer a user-facing interpretation question
- `print.interdep_data()` descriptions for DIM column families: done for
  v0.0.1
  - describe raw, cwp, and cbp DIM columns separately when present
  - avoid listing every generated predictor individually
- Directional DSM preparation: done for the current v0.0.1 scope
  - outcomes remain unchanged and are selected in model formulas
  - DSM reuses neutral dyad-mean/member-deviation calculations internally
  - full signed differences and the role contrast are recorded in DSM metadata
  - the DSM vignette documents the exact long-format interaction model
- Finalize vignette polish for v0.0.1
  - `getting-started.Rmd` is finalized as an orientation and data-prep vignette,
    not the main modeling manual
  - `dim.Rmd` is finalized for the current scope, including cross-sectional and
    ILD equivalence, interpretations, random slopes, citations, and current ILD
    limitations
  - review and polish `apim.Rmd` and `mixed-apim.Rmd`
  - in `apim.Rmd`, show concise versions of both the manifest raw-lag and
    manifest within-between lag specifications; describe them as different
    parameterizations rather than interchangeable corrections
  - complete the planned ILD DSM section and final review of `dsm.Rmd`
  - keep heavy or convergence-sensitive examples out of `getting-started.Rmd`
    and mark advanced examples `eval = FALSE` where needed
- Keep the completed DIM vignette stable
  - retain cross-sectional and ILD APIM-DIM equivalence
  - retain raw and `time_2l` ILD construction and the current concise
    methodological limitations
  - retain selective `lag_predictors` construction for lag-1 raw and CWP
    model-ready columns without bridging missing time indexes
  - keep mixed-composition models in the APIM vignettes
- Resolve mixed-composition ILD model convergence documentation
  - current increased simulation size improves information but does not fully
    remove Gaussian optimizer warnings for the maximal mixed-composition ILD APIM
  - do not present BFGS as a universal fix; document optimizer behavior only
    where it is empirically supported by the current simulated data
  - either simplify the vignette model deliberately or explain that the maximal
    model is aspirational/diagnostic and may require more data or Bayesian
    regularization
- Add public covariance back-transformation helpers for v0.0.1
  - Make the engine-independent matrix transformation the core implementation,
    rather than hard-coding only the scalar residual-SD formulas currently used
    by the vignette diagrams. For a fitted shared/difference covariance matrix
    `Sigma_score` and the appropriate member contrast matrix `T`, compute
    `Sigma_member = T %*% Sigma_score %*% t(T)`.
  - Provide a clear convenience path for the exchangeable `.i_diff_*`
    parameterization used by DIMs and exchangeable APIMs. With shared and
    difference coefficient vectors `u_shared` and `u_diff`, use
    `member_1 = u_shared + u_diff` and
    `member_2 = u_shared - u_diff`.
  - Accept covariance matrices, not only standard deviations, so the same
    implementation covers:
    - scalar residual variance/covariance blocks
    - stable dyad-level and same-occasion ILD blocks separately
    - random intercepts and multiple random slopes, including covariances among
      their coefficients
    - each exchangeable composition in a mixed-composition model
  - Keep arbitrary exchangeable members labelled as member 1 and member 2;
    never relabel them as female and male. Reversing the arbitrary `+1/-1`
    assignment must leave the implied member covariance unchanged.
  - Return the complete named member-level covariance matrix and convenient
    derived summaries such as member standard deviations and correlations.
    Preserve coefficient names and make the ordering of members and random
    coefficients explicit in the output.
  - Separate the mathematical transformation from model-engine extraction:
    - first implement and test a small function that transforms supplied
      covariance matrices
    - add a thin `glmmTMB` adapter only if it can identify or receive the shared
      and `.i_diff_*` terms explicitly; do not guess silently when several
      random-effect blocks are present
    - design the matrix-level function so bootstrap draws or other uncertainty
      estimates can be transformed later, without claiming that the v0.0.1
      point-estimate helper itself supplies confidence intervals
  - Reuse the general transformation core for the directional DSM only after
    validating its different `+0.5/-0.5` role contrast and its potentially
    correlated outcome-mean/outcome-difference block. Do not treat the DSM
    transformation as identical to the independent shared/`.i_diff_*` blocks
    required by exchangeability.
  - Validate the back-transformation before release:
    - reproduce the scalar identities already documented in `apim.Rmd`,
      including member variance equal to shared variance plus difference
      variance and member covariance equal to shared variance minus difference
      variance
    - test the documented example where shared variance `1.2` and difference
      variance `0.3` imply member variances `1.5` and covariance `0.9`
    - test dimensions, names, symmetry, and positive-semidefiniteness, with
      actionable errors for incompatible inputs
    - test round trips between exchangeable member and shared/difference
      covariance representations within numerical tolerance
    - compare transformed multi-coefficient blocks with direct transformations
      of simulated random effects
    - verify the same member-level results after reversing arbitrary member
      assignments
  - Replace duplicated diagram-only arithmetic with the tested helper where
    practical, so vignettes, diagrams, and future summaries use one definition
    of the transformation.
- Add a bounded `glmmTMB` diagnostics workflow for v0.0.1
  - Treat this as validated documentation and release guidance, not as a full
    exported diagnostics or plotting API. Prefer one focused diagnostics
    vignette or section that the APIM, mixed-APIM, DIM, and DSM vignettes can
    link to rather than repeating slightly different recipes.
  - Begin with model-integrity checks before inspecting residuals:
    - check optimizer convergence and a positive-definite Hessian
    - check that standard errors are finite
    - flag covariance estimates near zero and correlations near `-1` or `1`
      as possible boundary or identifiability problems
    - use `glmmTMB::diagnose()` as supporting information, while explaining
      that a large coefficient Z-statistic alone does not establish model
      failure
  - Document the special DHARMa requirement for the Gaussian dyadic models:
    - with `dispformula = ~ 0`, the ordinary Gaussian residual variance is
      fixed near zero and the member residual variance/covariance is represented
      by random-effect blocks
    - DHARMa 0.5.0 defaults to simulations conditional on all fitted random
      effects; that default conditions on the blocks serving as dyadic
      residuals and therefore simulates only the tiny remaining Gaussian
      nugget
    - use `DHARMa::simulateResiduals(..., simulateREs = "unconditional")` for
      the primary whole-model check; use a sufficiently stable simulation count
      such as `n = 1000` in documentation
    - if executable examples are added, list DHARMa in `Suggests`, require a
      version supporting `simulateREs`, guard examples with
      `requireNamespace()`, and keep expensive simulation out of routine CRAN
      vignette builds where necessary
  - Make residual and predictive checks composition- and role-aware:
    - map the rows actually used by the fitted model before subsetting, because
      missing outcomes can make the fitted rows differ from the original data
    - use `DHARMa::recalculateResiduals(..., sel = ...)` to inspect one
      composition-role at a time; for a cross-sectional distinguishable model,
      each such subset contains one independent member observation per dyad
    - do not treat a combined role comparison as an ordinary independent-groups
      test, because the two partner residuals are paired
    - compare observed and simulated role-specific means, standard deviations,
      and selected quantiles, as well as dyad-level summaries that directly
      represent the model: partner covariance/correlation and the distribution
      of partner differences
    - investigate `rotation = "estimated"` only for joint residual checks and
      validate its behavior by simulation before recommending it generally;
      the role-specific displays should remain the simpler first-line workflow
  - Address temporal autocorrelation explicitly for ILD models:
    - state that the current concurrent ILD examples model stable dyad
      dependence and same-occasion partner dependence, but do not by themselves
      model residual serial dependence
    - do not apply `DHARMa::testTemporalAutocorrelation()` once to all rows:
      diary-day values repeat across people, whereas the test requires unique
      time values within the tested series
    - do not aggregate all people at the same diary day and call that a
      within-person AR(1) check; it instead tests a calendar-day aggregate
    - for a valid dyadic check, compute an adjacent-occasion lag-1 statistic
      within each member series, summarize it across members or dyads, and
      compare the observed statistic with the same statistic calculated from
      unconditional full-model simulations
    - respect actual time indexes and gaps when defining adjacency; never bridge
      missing occasions merely because two rows are adjacent after sorting
    - if an `ar1()` structure is later fitted, explain that unconditional
      DHARMa residuals can retain the modeled serial correlation. Selective
      conditioning on only the relevant `glmmTMB` random-effect block is not
      generally available, so use a validated covariance rotation or compare
      observed autocorrelation directly with autocorrelation in simulated data
    - keep own-series AR(1) distinct from a dyadic residual VAR: AR(1) does not
      estimate partner cross-lag paths
    - keep an automated AR(1)/VAR diagnostic helper out of v0.0.1 unless its
      false-positive behavior and power have been validated across the
      supported ILD structures
  - Handle multicollinearity as a design question rather than a generic VIF
    threshold:
    - do not use `performance::check_collinearity()` on the complete
      no-intercept, role-indicator interaction formula as a package-level
      pass/fail check; structural zeroes and indicator interactions can make
      the resulting VIFs misleadingly large
    - check exact fixed-design rank and numerical conditioning
    - inspect correlations among the substantive actor, partner, dyad-mean, and
      member-deviation predictors within the relevant composition-role, before
      multiplying them by role indicators
    - retain the existing warning that raw, CWP, and CBP versions of the same
      predictor must not all enter one formula because they are algebraically
      dependent
    - if a future `check_interdep_fit()` helper is added, report these results
      descriptively and identify the implicated columns; do not reduce them to
      a universal VIF cutoff
  - Validate the documented workflow before release:
    - cover distinguishable, exchangeable, and at least one mixed-composition
      cross-sectional model
    - verify that conditional DHARMa simulations are rejected as inappropriate
      for the `dispformula = ~ 0` parameterization and that unconditional
      simulations exercise the full fitted covariance structure
    - verify role/composition row mapping when fitted rows were removed for
      missing outcomes
    - use seeded simulation studies for the autocorrelation procedure rather
      than unit tests that expect one particular random p-value
    - keep generalized-family diagnostics, automated influence analysis,
      high-dimensional DHARMa rotation, and a general diagnostics plotting
      interface outside the v0.0.1 release scope
- Rerun final release checks after vignette/doc cleanup
  - release checks have already been run during development, but must be run
    again after building and polishing the vignettes
  - `devtools::test(reporter = "summary")`
  - `devtools::check(args = "--no-manual", error_on = "never")`
  - inspect the pkgdown site after the GitHub Pages workflow completes
  - inspect README, vignette, examples, `inst/CITATION`, and package metadata
    for CRAN-facing clarity

- Release to CRAN once checks, tests, docs, README, and vignette are clean
  - Submit source package to CRAN without requiring a Git tag first
  - After CRAN acceptance, tag the accepted commit as `v0.0.1`
  - Create a GitHub release from that tag
  - Archive the GitHub release on Zenodo
  - Add the Zenodo concept DOI to README and citation metadata on `main`
  - Include the DOI in the next CRAN release

## Version 0.2.0

- Add a dedicated, validated simulation of lagged-outcome bias if this remains
  useful after the v0.0.1 tutorial review
  - generate data from a structural lagged-outcome model rather than reuse the
    current examples, whose serial dependence is generated at the residual
    level
  - compare manifest raw-lag and manifest-centered lag specifications across
    several values of T, and include an initial-condition-aware reference model
    if the results are presented as a methodological comparison
  - keep computationally expensive Monte Carlo work out of normal vignette
    rendering; use a development script or validated precomputed summary
- Extend dyadic-score model support beyond the v0.0.1 data-prep API
  - consider multiple distinguishable compositions with explicit directions
  - Keep multivariate DSM modeling and formula/syntax generation for a later
    modeling layer
- Extend composition controls only after the v0.0.1 API has real examples
  - consider richer pooling diagnostics and warnings for sparse pooled groups
  - consider helpers for inspecting raw-to-analysis composition mappings
  - avoid adding partial-pooling semantics here; `pool_compositions` is a
    data-preparation label operation, not a fitted-model prior structure
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
  - Before implementation, reconcile the plan with the papers under
    [`References/`](References/), including the distinctions between structural
    DSEM and residual DSEM, manifest and latent centering, initial conditions,
    unequal intervals, and Kalman-style missing-data handling

## Version 1.0.0 - Stable User-Facing API

Treat `1.0.0` as an API-stability milestone, not as the first useful release.
By this point, the core preparation functions should be stable enough that
scripts written against the public arguments and generated-column semantics do
not need routine breaking changes.

Minimum expected state:

- stable `prepare_interdep_data()` argument names and semantics
- stable generated-column families for compositions, temporal predictor
  components, APIM predictors, and DIM/DSM predictors
- stable analysis-composition controls:
  `include_compositions`, `set_exchangeable_compositions`, and
  `pool_compositions`
- clear metadata for raw observed compositions versus final analysis
  compositions
- complete getting-started, APIM, mixed-APIM, DIM, and DSM documentation paths
- interpretation helpers for `.i_diff_*` structures
- syntax generation for at least one primary model engine, preferably
  `glmmTMB`, with tests that protect intended estimands
- CRAN release history and pkgdown documentation that match the current API

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
- Composition filtering, exchangeability, and pooling helpers
- `.i_diff_*` / Idiff interpretation helpers
- Formula or syntax generation for at least `glmmTMB`
- Preferably `brms` syntax generation as a second modeling backend
- Reproducible vignettes showing composition-aware dyadic MLM workflows
- Clear statement that `interdep` supplies dyadic composition logic, temporal
  predictor decomposition, indicators, constraints, interpretation helpers, and
  syntax for established model engines
