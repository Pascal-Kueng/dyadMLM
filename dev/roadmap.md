
# Roadmap for 'dyadMLM' R-Package

This package provides functions for preparing composition-aware dyadic
multilevel models, focusing on cross-sectional and intensive longitudinal (ILD)
data. The package should not try to replace model engines such as `glmmTMB` or
`brms`. Its core responsibility is to make the dyadic composition logic,
temporal predictor decomposition, indicators, constraints, interpretation
helpers, and eventually model syntax explicit and reproducible.

## Development Notes

- Temporal predictor decomposition and predictor-shape planning:
  [`centering.md`](centering.md)
- Inspection-only incomplete/unknown dyads remain intentionally unsupported;
  revisit that boundary only for a concrete user-facing need.
- Long-term custom Stan / dyadic residual VAR planning: [`stan.md`](stan.md)
  - the note is provisional and must be revised against the methodological
    papers in [`References/`](References/) before implementation
- Directional DSM derivation and implementation record: [`dsm.md`](dsm.md)
- Covariance back-transformation mathematics and design history:
  [`backtransform.md`](backtransform.md)
  - use the current code, generated documentation, and tests as authoritative
    for exact API behavior
- ILD non-independence evidence and tutorial policy:
  [`ild-nonindependence.md`](ild-nonindependence.md)
- Data-preparation debugging scratch helpers:
  [`debug-data-preparation.R`](debug-data-preparation.R)

## Current State

Version 0.1.0 has been accepted by CRAN, tagged as `v0.1.0`, archived on
Zenodo, and published as a GitHub Release. Development now continues as version
0.1.0.9000 and contains intentionally breaking changes. The next CRAN release
is planned as version 0.2.0: a focused correctness and API-stabilization release
before broader adoption, not a large model-fitting feature release.

The core data-preparation API is implemented and covered by tests, the README
links to the pkgdown site, and GitHub Actions are configured for R CMD check,
coverage, pkgdown publishing, and workshop-material deployment. A four-pass
API, edge-case, and general review identified longitudinal missingness,
validation, and prepared-object integrity issues. Temporary structural
completion now addresses the identified unpaired-occasion CBP and lagging
problems; remaining correctness and API work is tracked in the
[active 0.2.0 milestone](#version-020---cran-api-stabilization-release).

Recently completed cleanup:

- replaced the old combined-model wording with "mixed dyad types" or
  "mixed-composition" wording
- consolidated the examples into the structurally parallel `dyads_cross`,
  `dyads_ild`, `dyads_nbinom_cross`, and `dyads_nbinom_ild` datasets
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
- added `keep_compositions`, so analyses can keep selected observed dyad
  compositions before exchangeability overrides, pooling, and DIM/DSM
  compatibility checks
- implemented and reviewed separate DIM and directional DSM preparation paths
  for the current v0.1.0 scope
- accepted the current composition metadata shape for v0.1.0: returned data use
  final analysis compositions, while pooling metadata records the pooled source
  compositions in a compact `pooled_from` summary
- implemented common extraction of `glmmTMB` and `brms` random-effect blocks,
  including covariance arrays, normalized labels, and focused rejection of
  unsupported backend structures
- implemented automatic matching of package-generated shared/difference blocks
  and exact formula-block pairs for custom or constrained models, including
  random slopes, multiple compositions/grouping levels, partial or wholly
  omitted components, coefficient reordering, literal difference-indicator by
  time products, and fitted-row coding validation when the indicator columns
  remain available

Post-release sequence:

1. [x] Create the GitHub Release from the accepted `v0.1.0` tag.
2. [x] Upload the exact accepted source archive to the prepared Zenodo record,
   verify its metadata and checksum, and publish it.
3. [x] Complete and deploy the post-release documentation currently on `main`,
   then verify the pkgdown and stable workshop URLs.
4. [ ] Rebase and integrate, or explicitly abandon, the remaining
   `post-workshop-slide-updates` branch. Preserve the current deployment and ZIP
   contracts, render and inspect both decks, and close
   [GitHub issue #6](https://github.com/Pascal-Kueng/dyadMLM/issues/6).
5. [ ] Complete the 0.2.0 stabilization milestone below, run the exact release
   checks, and submit one bundled update to CRAN.

The engine-independent covariance-array back-transformation and final named
`varcov`/`sdcor` results are implemented for `glmmTMB` point estimates and
draw-wise `brms` results, including partial and wholly omitted components.

The getting-started and DIM vignettes have completed detailed review.

## Vignette Architecture

Keep the first-contact documentation short and stable. Heavy or
convergence-sensitive model demonstrations should not live in the getting
started vignette, because that makes onboarding harder and can make CRAN/pkgdown
builds slow or fragile when optional modeling packages are installed.

Target vignette structure:

- `getting-started.Rmd`
  - package purpose and expected long data structure
  - `dyad`, `member`, `role`, and `time`
  - distinguishable, exchangeable, and mixed dyad types
  - missing structural data rules
  - compact examples of `predictors`, `model_types`, `temporal_decomposition`,
    print output, and metadata
  - links to available model-specific vignettes
  - minimal or no fitted models
- `apim.Rmd`
  - cross-sectional and ILD APIM model construction
  - distinguishable and exchangeable APIMs
  - within-person and between-person actor/partner effects
  - `.is_*`, `.member_contrast_*`, and raw actor/partner predictor columns
  - a brief comparison of manifest raw outcome lags and separately estimated
    within-/between-person outcome-lag components, with their different
    interpretations and small-T cautions
- `generalized-apim.Rmd`
  - one focused, runnable negative-binomial APIM workflow using the shipped
    count-outcome data
  - distinguishable and exchangeable examples with interpretation on the
    log-mean and response scales
  - links back to the main APIM workflow rather than repeating general data
    preparation or reporting
  - binary, ordinal, and categorical outcomes deferred until complete examples
    are validated
- `dev/vignettes/mixed-apim.Rmd`
  - development-only workflow, omitted from the public vignette index
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
  - a brief ILD extension
  - outcomes remain unchanged in the MLM-focused preparation API

<details>
<summary><strong>Historical v0.1.0 implementation record</strong></summary>

## Version 0.1.0 - Accepted CRAN Release

Goal: ship a small, reliable data-preparation and interpretation workflow with
enough ILD support to be useful for composition-aware dyadic MLMs before adding
larger model-building features.

### v0.1.0 Release Record and Follow-up

Version 0.1.0 was accepted by CRAN and tagged. The completed items below record
the accepted scope. Any remaining follow-up has been reassigned to the versioned
milestones below rather than retained as unchecked work in this historical
section.

- [x] Core composition-aware validation and APIM, DIM, and DSM column
  construction are implemented and tested.
- [x] Cross-sectional and ILD temporal predictor decomposition, composition
  filtering, exchangeability overrides, pooling, metadata, and printing are
  implemented and tested for the documented scope.
- [x] `recover_exchangeable_covariance()` converts fitted
  shared/`.member_contrast_*` random-effect
  structures to interpretable member-level covariance matrices. Backend
  extraction and matching are implemented for `glmmTMB` and single-response
  `brms`, including draw-wise transformation, constrained components, final
  named output, and numerical end-to-end tests.
- [x] Version `0.1.0` is released on CRAN and tagged as `v0.1.0`.
- [x] Create the GitHub Release and publish the exact accepted source archive
  through the prepared Zenodo record.

Not required for v0.1.0: model fitting or syntax-generation wrappers, public
fitted-diagram functions, automated AR(1)/VAR diagnostics, a universal
multicollinearity rule, generalized-family diagnostic automation, or a full
diagnostics plotting interface.

Detailed historical implementation notes follow. Imperative wording in this
collapsed record documents the decisions and checks used for 0.1.0; it does not
define the current task list.

- Validate dyadic data and return a model-ready tibble with metadata
- Support cross-sectional and ILD data for distinguishable and exchangeable
  dyads
- Auto-detect roles, dyad compositions, and distinguishability where possible
- Add explicit analysis-composition controls so common mixed dyad-type analyses
  do not require external preprocessing
  - `keep_compositions = NULL` is implemented as an observed-composition
    pre-filter before exchangeability overrides and pooling. It is a narrow
    dyad-level filter, not a general row filter:
    - require `role`; without observed roles, there are no observed
      compositions to include or exclude
    - accept the same composition reference aliases as the other composition
      controls, for example `"female_x_female"`, `"female-female"`,
      `"female female"`, or `"female_female"`
    - reject `character(0)`, non-character values, unknown references, and
      filters that leave fewer than two complete dyads
    - infer canonical raw compositions first, resolve `keep_compositions`
      against those raw observed compositions, then keep all rows for retained
      dyads and drop all rows for excluded dyads
    - update `attr(data, "dyadMLM")$n_dyads` and all downstream
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
    2. apply `keep_compositions`, if supplied, as a whole-dyad raw
       composition filter
    3. apply `set_exchangeable_compositions`
    4. apply `pool_compositions` only to compositions that are exchangeable
       after step 3
    5. build `.composition`, `.composition_role`, `.is_*`,
       `.member_contrast_*`,
       print summaries, and metadata from the final analysis compositions
  - Do not generate an additional raw-composition column. Preserve any
    user-supplied columns, and record pooling provenance in
    `attr(data, "dyadMLM")$dyad_compositions`
  - Error clearly for unknown aliases, ambiguous aliases, overlapping pooling
    definitions, or pooling requests that include non-exchangeable compositions
- Handle incomplete dyads and missing roles with explicit `error` and `drop`
  behavior
- Return factor columns for `.composition` and
  `.composition_role`
- Add temporal predictor decomposition and predictor-shape helpers for ILD data
  - Keep the implemented `"2l"` workflow described in [`centering.md`](centering.md)
  - Keep APIM, DIM, and DSM on the same temporal predictor decomposition
    foundation
  - Use `temporal_decomposition = "auto"` by default: resolve to
    `"2l"` when both `time` and predictors are supplied, and to `"none"`
    otherwise
  - Allow explicit `temporal_decomposition = "none"` for
    undecomposed or externally centered cases
  - Support raw and within-/between-person model-ready columns for APIM, DIM,
    and DSM, including DIM within-dyad deviations using the
    `_within_dyad_dev` suffix
  - For ILD models using `temporal_decomposition = "2l"`, retain each selected
    raw predictor alongside
    its CWP and CBP components in the shared predictor metadata
    - construct raw APIM actor/partner columns and raw DIM/DSM dyadic scores
      from the shared metadata
    - decompose raw longitudinal DIM/DSM predictors within dyad-occasion, while
      retaining dyad-level construction for CBP components
    - keep the established `.{pred}_actor` and `.{pred}_partner` names; do
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
  - Use `model_types = "dsm"` with an explicit `dsm_role_order`
  - Require one distinguishable dyad composition
  - Reuse neutral dyad-mean/member-deviation calculations internally
  - Create full signed predictor differences and a `+0.5/-0.5` role contrast
  - Leave outcomes unchanged
- Add a print method for `dyadMLM_data`
  - Keep normal tibble/data-frame printing; add a compact dyadMLM header above
    the data output
  - Show number of dyads, whether data are longitudinal, and inferred
    composition counts
  - Show structural columns: dyad, member, optional role, optional time
  - Show dyad compositions with composition name, dyad type, and dyad count
  - Show generated column families and one-line meanings:
    `.composition`, `.composition_role`, `.is_*`,
    `.member_contrast_*`,
    temporal predictor components, APIM predictor columns, DIM deviations, and
    DSM directional predictor columns
  - Drive generated-column printing from `dyad_generated_columns()`, which
    normalizes temporal predictor, APIM, DIM, and DSM metadata into
    one row per concrete generated column
  - Make dropped incomplete dyads and missing roles visible
  - Target display for `dyads_ild`:
    ```r
    # dyadMLM data
    # Rows: 10,080 | Dyads: 360 | Intensive longitudinal: yes
    # Structure: dyad = coupleID, member = personID, role = gender, time = diaryday
    #
    # Dyad compositions:
    # female_x_female exchangeable    120 dyads
    # female_x_male   distinguishable 120 dyads
    # male_x_male     exchangeable    120 dyads
    #
    # Added columns:
    #   .composition                  inferred dyad composition
    #   .composition_role             composition-specific member role
    #   .is_{comp-role}               composition-role indicator columns
    #   .member_contrast_{comp}_arbitrary
    #                                   composition-specific member contrasts
    #                                   with arbitrary direction; 0 for
    #                                   distinguishable dyads or other
    #                                   exchangeable compositions
    #   .{pred}_cwp                   within-person predictor: momentary
    #                                   deviations from each person's usual level
    #   .{pred}_cbp                   between-person predictor: stable
    #                                   differences from the average person's usual
    #                                   level
    #   .{pred}_actor                 APIM actor predictor: actor's original values
    #   .{pred}_partner               APIM partner predictor: partner's original values
    #   .{pred}_cwp_actor             APIM within-person actor predictor: actor's
    #                                   momentary deviations from their usual level
    #   .{pred}_cwp_partner           APIM within-person partner predictor:
    #                                   partner's momentary deviations from their
    #                                   usual level
    #   .{pred}_cbp_actor             APIM between-person actor predictor:
    #                                   actor's stable difference from the average
    #                                   person's usual level
    #   .{pred}_cbp_partner           APIM between-person partner predictor:
    #                                   partner's stable difference from the
    #                                   average person's usual level
    #   .{pred}_dyad_mean_gmc         raw dyad-mean predictor, grand-mean centered
    #   .{pred}_within_dyad_dev       DIM raw within-dyad predictor deviation
    #   .{pred}_within_dyad_diff      DSM raw signed predictor difference
    #   .{pred}_cwp_dyad_mean         within-person dyad-mean predictor:
    #                                   shared momentary deviations in the dyad
    #   .{pred}_cwp_within_dyad_dev
    #                                   DIM within-person within-dyad predictor
    #                                   deviation: person's momentary deviation
    #                                   from the dyad average
    #   .{pred}_cbp_dyad_mean         between-person dyad-mean predictor:
    #                                   dyad's stable usual level, grand-mean
    #                                   centered
    #   .{pred}_cbp_within_dyad_dev
    #                                   DIM between-person within-dyad predictor
    #                                   deviation: person's stable difference from
    #                                   the dyad's usual level
    #   .dsm_role_contrast            DSM +0.5/-0.5 directional role contrast
    #   .{pred}_cwp_within_dyad_diff   DSM within-person signed predictor difference
    #   .{pred}_cbp_within_dyad_diff   DSM between-person signed predictor difference
    #
    # A tibble: 10,080 x 23
       personID coupleID diaryday gender closeness provided_support ... .composition ...
          <int>    <int>    <int> <fct>      <dbl>            <dbl> ... <fct>        ...
     1        1        1        0 female      4.40             4.93 ... female_x_male ...
     2        2        1        0 male        5.14             5.59 ... female_x_male ...
     3        1        1        1 female      5.16             4.89 ... female_x_male ...
    # i 10,077 more rows
    ```
  - Do not add sparse-composition warnings to `print()` yet; thresholds are too
    arbitrary for a compact display
- Add composition role indicator columns for cross-sectional model workflows
- Keep generated-column inspection internal for v0.1.0
  - `dyad_generated_columns()` remains the internal normalized table used by
    printing
  - generated-column meanings are exposed through `print.dyadMLM_data()`
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
  - metadata-driven `inst/CITATION` for R users
  - `CITATION.cff` for GitHub and future Zenodo metadata

### v0.1.0 Historical Implementation Record

This section preserves the implementation and release-check record used for the
first release. Active follow-up has been reassigned to the versioned milestones
outside this collapsed section.

- Rebuild and inspect generated documentation
  - run `devtools::document()`
  - render `README.Rmd`
  - build pkgdown locally when changing vignette structure or `_pkgdown.yml`
- DIM and directional DSM preparation review: done for the current v0.1.0 scope
  - direct grouped DIM construction is accepted
  - raw cross-sectional and longitudinal DIM names are accepted
  - DIM remains restricted to one final exchangeable composition
  - DSM remains restricted to one final distinguishable composition matching
    `dsm_role_order`
- Analysis-composition controls: done for v0.1.0
  - `keep_compositions` is implemented as a raw observed-composition dyad
    filter before `set_exchangeable_compositions` and `pool_compositions`
  - `keep_compositions` updates retained dyads and downstream metadata; a
    separate excluded-composition metadata table or print summary is deferred
    unless users need it
  - `set_exchangeable_compositions` runs before `pool_compositions`
  - the name `set_exchangeable_compositions` is intentionally specific; avoid
    generic "constraints" wording
  - `pool_compositions` is a named list where names are final analysis
    composition labels and values are observed or analysis composition labels
    to pool
  - `keep_compositions`, `set_exchangeable_compositions`, and
    `pool_compositions` use the same composition-reference resolver
  - no extra raw-composition column is generated; user-supplied columns remain
    unchanged
  - pooling provenance is recorded in `dyad_compositions$pooled_from`
- DIM metadata: done for v0.1.0
  - the current `dim_predictors` table columns are stable for v0.1.0:
    `predictor`, `component`, `source_column`, `mean_column`,
    `deviation_column`, `dyad_decomposition_level`
  - keep downstream print/vignette code reading metadata rather than guessing
    column names where possible
- Generated-column metadata: done for v0.1.0
  - `dyad_generated_columns()` stays internal as the single normalized table
    used by printing and documentation-facing summaries of generated temporal
    predictor, APIM, DIM, and DSM columns
  - expose generated-column meanings through `print.dyadMLM_data()` for
    v0.1.0;
    consider a public wrapper later only if users need programmatic inspection
  - preserve explicit fields for `temporal_decomposition`,
    `dyadic_decomposition`, and `column_centering`
  - keep source-metadata fields such as `dim_predictors$dyad_decomposition_level`
    out of the normalized generated-column interpretation table unless they
    answer a user-facing interpretation question
- `print.dyadMLM_data()` descriptions for DIM column families: done for
  v0.1.0
  - describe raw, cwp, and cbp DIM columns separately when present
  - avoid listing every generated predictor individually
- Directional DSM preparation: done for the current v0.1.0 scope
  - outcomes remain unchanged and are selected in model formulas
  - DSM reuses neutral dyad-mean/member-deviation calculations internally
  - full signed differences and the role contrast are recorded in DSM metadata
  - the DSM vignette documents the exact long-format interaction model
- Finalize vignette polish for v0.1.0
  - `getting-started.Rmd` is finalized as an orientation and data-prep vignette,
    not the main modeling manual
  - `dim.Rmd` is finalized for the current scope, including cross-sectional and
    ILD equivalence, interpretations, random slopes, citations, and current ILD
    limitations
  - review and polish `apim.Rmd` and `mixed-apim.Rmd`
  - in `apim.Rmd`, show concise versions of both the manifest raw-lag and
    manifest within-between lag specifications; describe them as different
    parameterizations rather than interchangeable corrections
  - keep the completed ILD DSM section aligned with the implemented API and
    complete any remaining review of `dsm.Rmd`
  - keep heavy or convergence-sensitive examples out of `getting-started.Rmd`
    and mark advanced examples `eval = FALSE` where needed
- Keep the completed DIM vignette stable
  - retain cross-sectional and ILD APIM-DIM equivalence
  - retain raw and `"2l"` ILD construction and the current concise
    methodological limitations
  - retain selective `lag1_predictors` construction for lag-1 raw and CWP
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
- Add public covariance back-transformation helpers for v0.1.0
  - Current implementation status:
    - `extract_exchangeable_residual_blocks()` dispatches to thin `glmmTMB` and
      `brms` adapters and returns one common block representation.
    - Each block retains its grouping factor, coefficient names, correlation
      structure, recognizable normalized term, and a
      `draws x coefficients x coefficients` covariance array. `glmmTMB` uses
      one draw; `brms` retains posterior draws.
    - Automatic matching supports complete, unambiguous pairs across multiple
      compositions and grouping levels. It aligns coefficient and interaction
      order and leaves unrelated blocks alone.
    - `block_pairings` selects exact shared and difference random-effect terms
      copied from the fitted formula, plus `difference_indicator` and optional
      `shared_indicator`.
      Backend-normalized equivalents such as `(1 | group)`/`us(1 | group)` and
      `(0 + x || group)`/`diag(0 + x | group)` are recognized.
    - Supplied block pairings may contain different coefficient sets or set one
      whole block to `NULL`. The common term union and `NA` term-index entries
      record where the numerical transformation must insert structural zeros.
    - Difference slopes support either interaction order and narrow literal
      products such as `I(difference_indicator * time)`. More complex
      arithmetic inside `I()` is rejected.
    - Fitted rows are validated when their indicator columns remain available:
      the difference column must use `-1/+1` where the shared indicator equals
      one, zero elsewhere, and contain both signs. A wholly omitted formula
      column cannot be recovered from either backend, so that check is skipped
      with a warning.
    - Tests cover both backend adapters, correlated and uncorrelated blocks,
      multiple blocks, order changes, automatic ambiguity/failure cases,
      exact custom pairs, partial and omitted structures, fitted-row contrast
      coding, literal products in both backends, mathematical matrix identities,
      zero-variance boundaries, public `glmmTMB` output, and draw-wise `brms`
      output.
    - The common aligner inserts structural zeros, and the numerical helper
      constructs member-level `varcov` and `sdcor` results for every estimate or
      posterior draw. `glmmTMB` returns matrices; `brms` retains draw arrays. A
      compact print method can show both representations or either one alone.
    - A simple fitted-row detector flags grouping levels whose units always
      contain at most two observations. Its cautious warning does not inspect
      the difference indicator or claim that the rows are verified member
      pairs; it highlights
      `brms` residual structures, omitted components, and non-intercept terms.
  - A posterior summary beside the retained draw-wise `brms` results was left
    for post-0.2 evaluation.
  - Keep model discovery, matching, matrix algebra, and output formatting
    separate. Do not introduce `reformulas`: both fitted backends already store
    the normalized structures used by the adapters.
  - Use arbitrary member 1/member 2 labels, never female/male labels, for the
    transformed covariance of exchangeable dyads.
  - `dev/backtransform.md` records the matching contract, mathematical
    transformation, backend boundaries, and remaining implementation sequence.
- The bounded `glmmTMB`/DHARMa diagnostics work considered after the first
  release is now the priority additive 0.2.0 target below.
- Historical release-check sequence after vignette/doc cleanup
  - release checks have already been run during development, but must be run
    again after building and polishing the vignettes
  - `devtools::test(reporter = "summary")`
  - `devtools::check(args = "--no-manual", error_on = "never")`
  - inspect the pkgdown site after the GitHub Pages workflow completes
  - inspect README, vignette, examples, `inst/CITATION`, and package metadata
    for CRAN-facing clarity

- Complete release archiving after CRAN acceptance
  - [x] Submit the source package to CRAN and obtain acceptance
  - [x] Tag the accepted commit as `v0.1.0`
  - [x] Create a GitHub Release from that tag
  - [x] Upload the exact accepted source archive to Zenodo record `21481721`,
    whose reserved version DOI is `10.5281/zenodo.21481721`
  - [x] Verify the Zenodo metadata and checksum, then publish it
  - Continue to use the concept DOI in package-level citation metadata

</details>

## Version 0.2.0 - CRAN API-Stabilization Release

Status: in progress. Checked items are implemented on the development branch;
unchecked items remain proposed until they have been reviewed, implemented, and
verified. Because development already contains intentionally breaking names and
defaults, this release should be version 0.2.0 rather than 0.1.1. Keep the
direct-migration policy: do not add deprecated wrappers for the 0.1.0 API.

Goal: correct the model-ready longitudinal columns, settle the small public API
while changes are still inexpensive, and submit one bundled early-stabilization
release before many users adopt the 0.1.0 interface. Do not follow 0.2.0 with
another routine breaking CRAN update shortly afterward.

### Implemented on the development branch and requiring final revalidation

- [x] Use a single leading dot for retained generated columns while reserving
  `.dy_` for temporary implementation columns.
- [x] Support compact composition-dependent names through `short_colnames`.
  The default remains an open 0.2.0 API decision below.
- [x] Add optional arbitrary member contrasts for distinguishable compositions
  without reclassifying their composition metadata.
- [x] Add `summary.dyadMLM_data()` and complete generated-column tracking,
  collision preflights, and print integration.
- [x] Add optional APIM GMC source, actor, partner, and lagged columns while
  retaining raw predictors.
- [x] Rename `compare_nested_glmmTMB_models()` to
  `compare_nested_models()` without a compatibility wrapper.
- [x] Remove redundant composition columns from the example datasets and use
  member-specific AR(1) residual processes in `dyads_ild`.
- [x] Use the Zenodo concept DOI consistently in citation-facing metadata and
  documentation.
- [x] Temporarily complete observed longitudinal dyad-occasions while generated
  columns are constructed, then return only the rows supplied by the user.
  - This preserves stable partner CBP values and exact source-occasion APIM,
    DIM, and DSM lags when a partner's current row is absent.
  - Tests compare sparse input with explicitly supplied all-missing partner
    rows, preserve original rows and order, and verify that no temporary `.dy_`
    columns escape.
  - This is deterministic structural completion for data preparation, not
    statistical imputation and not the creation of additional analysis rows.
  - Add the user-facing missingness contract and this behavioral change to
    `NEWS.md` and the affected vignettes before release.

### Release-blocking correctness fixes

- [ ] Reject infinite values before generating model-ready columns.
  - Reject `Inf` and `-Inf` in selected numeric predictors with an error naming
    the affected variables and rows; continue to treat `NA` and `NaN` as
    missing values.
  - Reject non-finite values in numeric `dyad`, `member`, and `time` columns while
    continuing to support character and factor identifiers.
  - Cover GMC, CWP/CBP, APIM, DIM, DSM, and structural-column validation in
    regression tests so one infinite value cannot contaminate many generated
    rows through a mean.
- [ ] Define and enforce the post-preparation modification contract.
  - Current problem: base and dplyr subsetting can preserve the
    `dyadMLM_data` class and its frozen metadata after rows or structural columns
    change; source-variable mutation can also leave generated columns stale.
  - Treat `dyadMLM_data` as an immutable prepared analysis artifact. Filter or
    transform the raw data first, then call `prepare_dyad_data()` as the final
    preparation step.
  - Preserve the class and metadata only for pure row or column permutations
    that retain every row, column, and value, such as `arrange()`, `relocate()`,
    or a complete permutation with `[`. Row order is not part of the estimand.
  - Drop both the class and `dyadMLM` attribute when rows are removed, added, or
    duplicated; a value changes; a column is added, removed, or renamed; or the
    object is explicitly converted with `as.data.frame()` or `as_tibble()`.
    Return the ordinary data result and never silently re-center or regenerate.
  - Vector extraction with `$`, `[[`, or `pull()` returns an ordinary vector.
    Row extraction such as `x[1, ]` follows the row-removal rule and drops the
    class and metadata. Package print/summary methods leave the input unchanged,
    and package internals may restore the class only after a complete, validated
    generation stage.
  - Test the full operation matrix across base and dplyr paths, including no-op
    calls, pure permutations, joins, row binding, and source, generated,
    structural, and unrelated-column mutations.
- [ ] Complete the remaining model-level DSM verification in [`dsm.md`](dsm.md).
  - Define one direct score-space reference implementation, such as a
    multivariate Gaussian `brms` model for `YLevel` and `YDiff` on one row per
    dyad, and compare it with the long `glmmTMB` interaction model using
    `dispformula = ~ 0`.
  - With `V_L = Var(YLevel)`, `V_D = Var(YDiff)`, and
    `C_LD = Cov(YLevel, YDiff)`, verify the implied member covariance:
    `Var(Y1) = V_L + V_D / 4 + C_LD`,
    `Var(Y2) = V_L + V_D / 4 - C_LD`, and
    `Cov(Y1, Y2) = V_L - V_D / 4`.
  - Verify all six fixed coefficients, score-space covariance parameters,
    fitted member outcomes, `YLevel`, and `YDiff` within prespecified numerical
    tolerances. Require successful convergence and a positive-definite Hessian.
  - Reverse `dsm_role_order` and verify invariant likelihood and fitted values,
    the expected sign changes for terms containing one directional quantity, and
    unchanged signs for terms containing two directional quantities.
  - Treat a discrepancy as a correctness or documentation blocker rather than
    narrowing the numerical tolerance until the test passes.

### API decisions to settle before the 0.2.0 freeze

- [ ] Replace random arbitrary-member assignment with deterministic assignment
  and remove the public `seed` argument.
  - Within each dyad, assign `-1` to the canonically first member identifier and
    `+1` to the second. Order numeric identifiers numerically; order character
    and factor identifiers by normalized labels using a documented
    locale-independent rule rather than row order or factor-level codes.
  - Existing signs must be invariant to input row order, repeated-occasion
    order, composition filtering or pooling, and adding or removing unrelated
    dyads. Changing an identifier or its storage type may change the arbitrary
    orientation.
  - The operation must neither read nor modify the session RNG state.
  - Keep the documentation explicit that the sign is arbitrary and has no
    substantive member interpretation.
  - Update every function signature, vignette, workshop source, example, test,
    and NEWS migration entry in the same change.
- [ ] Use stable composition-qualified generated names by default.
  - Recommended default: `short_colnames = FALSE` so adding a composition does
    not change the columns referenced by an existing formula.
  - Vignettes and workshop examples that deliberately retain one composition
    may request `short_colnames = TRUE` for teaching-friendly formulas.
  - If compact context-dependent names remain the default, add a supported
    generated-column accessor rather than making direct attribute access the
    programmatic API.
- [ ] Make prepared-data summaries concise by default.
  - Recommended interface:
    `summary(x, include_generated = FALSE)` and
    `summary(x, include_generated = TRUE)` for the full table.
  - The default should show structural/composition information and original
    columns, then point users to the opt-in full generated-column summary.
- [ ] Keep model-comparison conclusions neutral and configurable.
  - Recommended interface:
    `compare_nested_models(model1, model2, alpha = 0.05)`.
  - Report evidence or no clear evidence of improvement at `alpha`; do not tell
    users to prefer the restricted model solely because the test is not
    significant, and retain the warning that this does not establish equal fit.
  - Keep the shorter function name, but state consistently that the current
    backend is `glmmTMB` only.
- [ ] Use covariance terminology that covers residual and higher-level random
  effects.
  - Recommended direct rename before the API freeze: class
    `exchangeable_covariance` and print heading "Recovered exchangeable
    member-level covariance". The public function name
    `recover_exchangeable_covariance()` already has the right scope.
  - Preserve the backend, grouping factor, underlying coefficient names,
    selected shared/difference terms, and indicator names in each returned block
    pairing so results are self-describing.

### Required 0.2.0 documentation alignment

- [ ] Publish one focused cross-sectional negative-binomial APIM workflow.
  - Promote and finish the usable count-outcome material in
    `dev/vignettes/generalized-apim.Rmd`, covering distinguishable and
    exchangeable examples with `dyads_nbinom_cross`.
  - Remove the empty dichotomous, ordinal, and categorical sections and defer
    those outcome families explicitly rather than implying that they are
    documented.
  - Execute both fits during local validation, check convergence and coefficient
    interpretation on the log-mean scale and as conditional expected counts or
    multiplicative mean ratios. Keep normal CRAN rendering bounded through
    guarded or precomputed output if necessary.
  - Link the published workflow from `apim.Rmd`, the package overview, and the
    pkgdown vignette index; remove statements that a generalized vignette is
    merely planned.
- [ ] Complete the APIM, mixed-APIM, DIM, and DSM consistency review.
  - Ensure examples use the final 0.2.0 names, defaults, and prepared-object
    contract and distinguish implemented workflows from methodological limits.
  - Simplify or explicitly label mixed-composition ILD fits that remain
    convergence-sensitive rather than presenting optimizer changes as a
    universal solution.

### Priority additive feature after stabilization: bounded DHARMa guidance

Begin this work only after the release-blocking correctness fixes are complete,
the 0.2.0 API decisions are settled, and the full test suite is green. This is
the highest-priority additive feature for 0.2.0. Keep the first deliverable
documentation-first: one focused package-vignette section backed by a
reproducible calibration script and results under `dev/`, without an exported
diagnostic helper or plotting API. If the bounded workflow does not meet the
acceptance criteria below, record the findings and defer it rather than widening
the release scope or shipping unvalidated guidance.

- [ ] Calibrate and document a cross-sectional `glmmTMB`/DHARMa workflow.
  - Scope the first workflow to two-member Gaussian identity-link `glmmTMB`
    models with dyad random effects and `dispformula = ~ 0`. Exclude generalized
    families, ILD/EMA models, temporal-dependence tests, and the experimental
    block-whitening helper.
  - Start with convergence, a positive-definite Hessian, finite estimates and
    standard errors, and boundary covariance estimates. Use
    `glmmTMB::diagnose()` as supporting evidence rather than a pass/fail verdict.
  - Request unconditional simulation explicitly because conditioning on the
    fitted dyad random effects can make simulations nearly degenerate when
    `dispformula = ~ 0`. Use `refit = FALSE` for DHARMa's inner simulations and
    calibrate their count rather than treating the workshop's `n = 10000` or an
    initial smaller value as a universal default.
  - Evaluate the two existing candidate summaries separately:
    1. The workshop workflow uses `rotation = "estimated"` for the joint residual
       vector, then fitted-row-aligned role selections with `rotation = NULL`.
    2. The earlier audit workflow uses complete fitted dyads to recalculate a
       dyad mean and a consistently ordered signed member difference.
  - Do not present rotation, role-specific checks, and dyad mean/difference
    checks as interchangeable. Select the primary presentation from calibration
    results and state the distinct question answered by every retained check.
  - Derive dyad, member, and role indexes from fitted model rows. Report the
    number of complete fitted dyads used by paired summaries and never infer a
    signed difference from source row numbers or accidental row order.
  - Preserve ordinary DHARMa objects and functions. Do not rewrite DHARMa object
    internals or produce a package-specific one-number adequacy verdict.
  - State clearly that these checks do not by themselves establish the
    correctness of dyadic covariance, exchangeability, or temporal dependence.

#### DHARMa calibration and acceptance criteria

- [ ] In every outer calibration replicate, generate a new dataset and refit the
  model before running the DHARMa checks. Cover correctly specified
  distinguishable and exchangeable models, weak, moderate, and strong admissible
  partner covariance, unequal member variances for distinguishable dyads, and
  workshop-relevant sample sizes.
- [ ] Predefine the diagnostic tests and assess empirical false-positive rates
  against Monte Carlo uncertainty; one reassuring dataset or p-value is not
  sufficient.
- [ ] Include consequential mean-structure misspecification, including one
  role-specific case, and record each candidate workflow's sensitivity and
  localization. Treat covariance-misspecification results as a documented limit
  unless separate calibration supports a stronger claim.
- [ ] Verify correct fitted-row alignment with reordered input and nonsequential
  row names and require conclusions to remain stable within calibrated Monte
  Carlo variability rather than requiring identical p-values. Check asymmetric
  outcome missingness and exclude incomplete fitted dyads deterministically from
  paired summaries.
- [ ] Check stability across seeds and candidate simulation counts, then choose
  the smallest count with stable conclusions and acceptable vignette runtime.
- [ ] Verify supported DHARMa and `glmmTMB` versions and that simulation does not
  leave altered `glmmTMB` state behind. Add a versioned DHARMa `Suggests` entry
  if the vignette executes the workflow; otherwise guard or precompute it.
- [ ] Require clean package-vignette, CI/pkgdown, and exact-tarball renders before
  including the guidance in 0.2.0.

### Additional tests and optional polish

- [ ] Test fitted exchangeable-covariance recovery when outcome missingness
  leaves only one member in some fitted grouping units while both member signs
  remain represented overall.
- [ ] Add a direct `compare_nested_models()` regression test for a valid
  `glmmTMB` fit created with `se = FALSE` if that variant remains supported.

### CRAN release checklist

- [ ] Resolve every release-blocking correctness item, every API decision, and
  every required 0.2.0 documentation-alignment item above; update this roadmap
  with the chosen contracts rather than leaving alternatives documented as if
  implemented.
- [ ] Update `NEWS.md` before freezing the release candidate.
  - Record temporary structural dyad-occasion completion and the resulting
    partner CBP/lag behavior change; do not call it imputation.
  - Record deterministic arbitrary-member assignment and removal of `seed`, the
    prepared-object mutation contract, and every changed default,
    generated-column name, S3-class name, summary interface, and
    model-comparison conclusion.
  - Include concise 0.1.0-to-0.2.0 migration examples and no deprecated wrappers.
- [ ] Update `DESCRIPTION` to version 0.2.0 and the release date; update
  `CITATION.cff` to the same version and date. Verify that
  `citation("dyadMLM")` reports version 0.2.0 while retaining the Zenodo concept
  DOI.
- [ ] Run `devtools::document()`, render `README.Rmd`, and rebuild every package
  vignette affected by the API or numerical changes. Render and inspect the
  generalized APIM workflow and every source affected by removal of `seed` or
  changed generated-column defaults; check examples and package help for stale
  names and defaults.
- [ ] If the DHARMa guidance passes calibration and is included, verify its
  declared dependency, build-time behavior, runtime, fitted-row alignment, and
  simulation state in the exact release tarball.
- [ ] Run the complete test suite with all suggested modeling packages installed,
  including asymmetric-missingness, mutation-matrix, deterministic-assignment,
  fitted DSM-equivalence, covariance recovery, and generalized-APIM validation
  tests, with no failures, warnings, or unexpected skips.
- [ ] Build the exact source tarball and run `R CMD check --as-cran` on that
  tarball, including the manual. Treat ordinary GitHub Actions checks as ongoing
  CI rather than a substitute for this release artifact.
- [ ] Run Win-builder or an equivalent current Windows submission check and
  review all CRAN-check platforms for the current release candidate.
- [ ] Build and inspect pkgdown, deploy from `main`, and verify the stable
  package, vignette, workshop-slide, exercise-source, PDF, and ZIP URLs. Confirm
  that the workshop ZIP still contains only the intended synthetic datasets.
- [ ] Submit one frozen 0.2.0 candidate to CRAN. After acceptance, tag the exact
  accepted commit as `v0.2.0`, create the GitHub Release, archive the release on
  Zenodo, and verify the version-specific DOI while continuing to cite the
  concept DOI in package-facing materials.

### Explicitly deferred beyond 0.2.0

Candidate work beyond 0.2.0 is organized below:

- Proposed version 0.3.0 candidates: multiple-imputation integration, dyadic
  post-processing and reporting, advanced diagnostics, Bayesian comparison
  design, and advanced ILD/EMA preparation.
- Version 0.4.0 and later: fitting/syntax helpers, wider reshaping and
  composition infrastructure, broader DSM and covariance methods, a custom Stan
  track, and any preprint or methods note.

## Proposed Version 0.3.0 Scope

Status: proposed. Select a small subset after 0.2.0 is accepted rather than
treating every item below as one release commitment.

### Multiple-imputation integration

- Start with an engine-independent contract for externally imputed, two-member
  cross-sectional data rather than implementing a new imputation algorithm.
- Keep statistical imputation distinct from the temporary structural completion
  used while model-ready columns are constructed. Temporary all-missing partner
  rows must never become returned analysis observations.
- Require structural identifiers and row keys to remain observed and unchanged,
  and require roles and analysis-composition decisions to resolve consistently
  across imputations.
- Impute raw measured and auxiliary variables first, then run
  `prepare_dyad_data()` separately within each completed dataset. Do not
  independently impute package-generated actor/partner, centered, lagged, DIM,
  or DSM columns.
- Require the imputation model to preserve the dyad, person, and role structure
  and the analysis model's important interactions and random-slope structure
  where present. Add time and serial structure only when the workflow is later
  extended to ILD. Do not offer a single-level convenience specification as a
  generally valid dyadic default.
- Evaluate a small `prepare_dyad_imputations()` mapper for a list of completed
  long-format datasets, with checks for consistent row keys, metadata,
  composition decisions, and generated-column plans. Add adapters for
  established imputation-object classes only after this contract is stable.
- Validate the first cross-sectional APIM workflow through simulation. Include
  outcomes and suitable auxiliary variables in the imputation model where
  appropriate, and assess actor/partner effect bias, standard errors, and
  interval coverage.
- State supported missingness assumptions and diagnostic expectations without
  presenting multiple imputation as automatically superior to a defensible
  complete-case analysis.
- Initially leave imputation-model specification, model fitting, and pooling to
  established packages. Defer ILD/time-series imputation, missing structural
  identifiers or completely unobserved members, MNAR sensitivity models, and
  pooling nonlinear covariance summaries until separately validated.

### Dyadic post-processing and reporting

- Add `summary.exchangeable_covariance()` and
  `as.data.frame.exchangeable_covariance()` only after the 0.2.0 class contract
  is final. Provide point summaries for `glmmTMB`; add posterior summaries and
  intervals for retained `brms` draws while preserving access to the full draw
  arrays. Do not imply frequentist uncertainty for `glmmTMB` until a bootstrap
  or delta-method workflow is validated.
- Consider `plot.exchangeable_covariance()` only as a thin view of that stable
  summary table, with explicit member-level variance, covariance, correlation,
  and uncertainty labels.
- Evaluate a backend-neutral dyadic-effects table for actor, partner,
  role-specific, CWP/CBP, APIM, DIM, and DSM terms. Build a coefficient plot only
  after the table can classify supported formulas reliably; do not package
  generic wrappers around `report`, `parameters`, or `see`.
- Evaluate Bayesian model comparison as a separate workflow rather than an LRT
  branch inside `compare_nested_models()`. Define the predictive target and the
  observation-versus-dyad holdout unit before choosing LOO, WAIC, or another
  criterion.
- Consider splitting covariance extraction, block matching, validation,
  transformation, summaries, and printing into separate implementation files
  when doing so reduces review and maintenance risk.

### Advanced diagnostics

- Build on the calibrated 0.2.0 cross-sectional guidance before considering any
  exported helper.
- Evaluate a within-member lag-1 statistic against unconditional full-model
  simulations while respecting gaps and repeated series.
- Validate joint covariance rotation and mixed/ILD behavior before adding
  generalized-family diagnostics or a narrow `check_dyad_fit()` for convergence,
  design rank, boundary covariance estimates, and row alignment.
- Do not export diagnostic automation until false-positive behavior and the
  interpretation of every reported check are understood for supported models.

### Advanced ILD/EMA data infrastructure

- Add `"3l"` temporal predictor decomposition only after the `"2l"` workflow is
  stable, and require an explicit day, burst, or period variable.
- Do not infer `"3l"` automatically from EMA nesting or three-level random
  effects; users should request it when the substantive predictor decomposition
  requires it.
- Keep `time_4l` out of scope unless a concrete applied use case justifies the
  extra API and interpretation burden. Describe temporal decomposition rather
  than claiming that fitted models have exactly two or three levels.

### Dynamic-data preparation groundwork

- Add transition-record or dyad-occasion data helpers only if needed by the
  model-syntax or custom-model tracks.
- Support ragged complete dyad-days and full dyad-day gaps before attempting
  latent one-partner missingness in dynamic models.
- Distinguish latent-state handling from the observed-data preparation fixed for
  0.2.0: known CBP and exact observed `t - 1` values should survive an absent
  current partner row, but latent-state imputation remains outside the core
  preparation API until a modeling layer needs it.

## Longer-Term Roadmap: Version 0.4.0 and Later

### Model syntax and wider preparation

- Write static model syntax for cross-sectional and ILD models, starting with
  `glmmTMB`; add `brms` syntax and priors only after the first path is stable.
- Add tests that generated syntax matches intended estimands and model
  structures. Consider `dynamite` or another MLSEM/DSEM framework only after the
  established-engine paths are clear.
- Consider a separate wide-to-long helper for common two-person inputs while
  keeping `prepare_dyad_data()` strict about the canonical long format.
- Extend composition controls only for concrete applied needs, such as richer
  pooling diagnostics or raw-to-analysis mapping helpers. Do not give
  `pool_compositions` partial-pooling semantics.

### Broader method development

- Extend exchangeable covariance recovery only where applied use justifies it:
  evaluate bootstrap or delta-method uncertainty for `glmmTMB` and support
  explicitly mapped custom member contrasts only when their coding and scale can
  be validated.
- Develop any DSM covariance transformation as a separate directional,
  distinguishable-dyad method using its `+0.5/-0.5` role contrast and the
  score-to-member mapping validated in the 0.2.0 DSM tests. Do not present it as
  an extension of exchangeable covariance recovery.
- Extend DSM preparation to multiple distinguishable compositions only with
  explicit directions; keep multivariate DSM fitting in the later modeling
  layer.
- Add a dedicated simulation of lagged-outcome bias only if still useful. Use a
  structural lagged-outcome generator, compare manifest raw and centered lag
  specifications across several values of T, and include an
  initial-condition-aware reference model. Keep Monte Carlo work out of normal
  vignette rendering.
- Develop any preprint or methods note only after the corresponding package
  methods are stable. Cite the Zenodo concept DOI for the implementation.

### Custom Stan track

- Evaluate a custom Stan track only after the package has stable validation,
  temporal predictor decomposition, actor/partner helpers, syntax generation,
  and fit/summary conventions for established engines.
- If custom Stan becomes part of the package scope, follow the staged dyadic
  residual VAR plan in [`stan.md`](stan.md):
  - Start with Gaussian, two-person dyadic residual VAR(1) models.
  - Start balanced, then add ragged complete dyad-days and full dyad-day gaps.
  - Keep non-Gaussian likelihoods, arbitrary DSEM features, one-partner
    missingness, and latent centering out of the first Stan implementation.
  - Preserve package-wide composition metadata and exchangeability constraints
    rather than introducing a parallel dyad registry.
  - Reconcile the plan with papers under [`References/`](References/), including
    structural versus residual DSEM, manifest versus latent centering, initial
    conditions, unequal intervals, and Kalman-style missing-data handling.

## Version 1.0.0 - Stable User-Facing API

Treat `1.0.0` as an API-stability milestone, not as the first useful release.
By this point, the core preparation functions should be stable enough that
scripts written against the public arguments and generated-column semantics do
not need routine breaking changes.

Minimum expected state:

- stable `prepare_dyad_data()` argument names and semantics
- stable generated-column families for compositions, temporal predictor
  components, APIM predictors, and DIM/DSM predictors
- stable analysis-composition controls:
  `keep_compositions`, `set_exchangeable_compositions`, and
  `pool_compositions`
- clear metadata for raw observed compositions versus final analysis
  compositions
- complete getting-started, APIM, generalized-APIM, mixed-APIM, DIM, and DSM
  documentation paths
- interpretation helpers for `.member_contrast_*` structures
- syntax generation for at least one primary model engine, preferably
  `glmmTMB`, with tests that protect intended estimands
- CRAN release history and pkgdown documentation that match the current API

## JOSS Readiness

JOSS should be a later milestone, not a first-release target. A JOSS submission
does not require `dyadMLM` to estimate models itself, but it should be more
than a thin data-preparation wrapper.

Target state before JOSS submission:

- Public development history of at least six months
- Tagged releases, changelog, tests, documentation, and clear contribution
  guidance
- Evidence of research use, ideally a preprint or applied analysis using the
  package
- Robust temporal predictor decomposition for ILD data
- Composition filtering, exchangeability, and pooling helpers
- `.member_contrast_*` interpretation helpers
- Formula or syntax generation for at least `glmmTMB`; a second modeling
  backend is optional and is not a JOSS submission gate
- Reproducible vignettes showing composition-aware dyadic MLM workflows
- Clear statement that `dyadMLM` supplies dyadic composition logic, temporal
  predictor decomposition, indicators, constraints, interpretation helpers, and
  syntax for established model engines
