
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
API, edge-case, and general review identified release-blocking longitudinal
missingness, validation, and prepared-object integrity issues. These findings
and the associated API recommendations are recorded under the 0.2.0 milestone
below.

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
3. [x] Complete the post-release documentation and workshop cleanup and verify
   the pkgdown and stable workshop URLs after deployment from `main`.
4. [ ] Complete the 0.2.0 stabilization milestone below, run the exact release
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
  - generalized outcomes, including negative-binomial examples
  - `.is_*`, `.member_contrast_*`, and raw actor/partner predictor columns
  - a brief comparison of manifest raw outcome lags and separately estimated
    within-/between-person outcome-lag components, with their different
    interpretations and small-T cautions
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

## Version 0.1.0 - Accepted CRAN Release

Goal: ship a small, reliable data-preparation and interpretation workflow with
enough ILD support to be useful for composition-aware dyadic MLMs before adding
larger model-building features.

### v0.1.0 Release Record and Follow-up

Version 0.1.0 was accepted by CRAN and tagged. Completed items below record the
accepted scope; unchecked items are post-release documentation or maintenance
follow-up rather than claims about the CRAN release state.

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
- [ ] A bounded `glmmTMB`/DHARMa workflow is deferred to the conditional 0.2.0
  documentation stretch goal below; it was not part of the accepted 0.1.0
  release.
- [ ] APIM, mixed-APIM, DIM, and DSM vignettes are internally consistent and
  clearly distinguish implemented workflows from methodological limitations.
- [ ] Mixed-composition ILD convergence examples are either supported by the
  example data or explicitly presented as advanced/diagnostic specifications.
- [ ] Documentation, README, citation metadata, pkgdown, tests, and multi-platform
  R CMD checks are clean.
- [x] Version `0.1.0` is released on CRAN and tagged as `v0.1.0`.
- [x] Create the GitHub Release and publish the exact accepted source archive
  through the prepared Zenodo record.

Not required for v0.1.0: model fitting or syntax-generation wrappers, public
fitted-diagram functions, automated AR(1)/VAR diagnostics, a universal
multicollinearity rule, generalized-family diagnostic automation, or a full
diagnostics plotting interface.

Detailed implemented scope and final checks follow.

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

### v0.1.0 Implementation Record and Follow-up Checklist

This section preserves the implementation record used for the first release.
Remaining unchecked or imperative items are follow-up maintenance work.

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
  - Remaining release polish:
    - decide later whether a posterior summary is useful beside the retained
      draw-wise `brms` results.
  - Keep model discovery, matching, matrix algebra, and output formatting
    separate. Do not introduce `reformulas`: both fitted backends already store
    the normalized structures used by the adapters.
  - Use arbitrary member 1/member 2 labels, never female/male labels, for the
    transformed covariance of exchangeable dyads.
  - `dev/backtransform.md` records the matching contract, mathematical
    transformation, backend boundaries, and remaining implementation sequence.
- The bounded `glmmTMB`/DHARMa diagnostics documentation considered after the
  first release is now scoped as a conditional 0.2.0 stretch goal below.
- Rerun final release checks after vignette/doc cleanup
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
  - For future releases:
    1. update the version and release date in `DESCRIPTION` and `CITATION.cff`
       before tagging
    2. create the GitHub Release from the tag
    3. create a new version from the latest Zenodo record
    4. upload the exact release archive, verify its metadata and checksum, and
       publish it
  - This preserves the concept DOI across releases.

## Deferred maintenance after 0.2.0

- Extend `compare_nested_models()` to support fitted `brms` models, using a
  Bayesian-appropriate comparison method and similarly clear output.

## Longer-term method development (not required for 0.2.0)

- Extend the v0.1.0 covariance back-transformation only where applied use
  justifies it:
  - add the distinct DSM `+0.5/-0.5` transformation
  - consider bootstrap or delta-method uncertainty for `glmmTMB`
  - consider explicitly mapped custom member contrasts only if their coding and
    scale can be validated safely
  - extend posterior summaries for `brms` only where the v0.1.0 return proves
    insufficient in applied use
- Develop advanced diagnostics only after validating the bounded 0.2.0
  documentation:
  - evaluate a within-member lag-1 statistic against unconditional full-model
    simulations, respecting gaps and repeated series
  - validate joint DHARMa covariance rotation and mixed/ILD diagnostic behavior
  - consider a narrow `check_dyad_fit()` for convergence, design rank,
    boundary covariance estimates, and row alignment
  - do not export these helpers until false-positive behavior and interpretation
    are understood for the supported structures

- Add a dedicated, validated simulation of lagged-outcome bias if this remains
  useful after the v0.1.0 tutorial review
  - generate data from a structural lagged-outcome model rather than reuse the
    current examples, whose serial dependence is generated at the residual
    level
  - compare manifest raw-lag and manifest-centered lag specifications across
    several values of T, and include an initial-condition-aware reference model
    if the results are presented as a methodological comparison
  - keep computationally expensive Monte Carlo work out of normal vignette
    rendering; use a development script or validated precomputed summary
- Extend dyadic-score model support beyond the v0.1.0 data-prep API
  - consider multiple distinguishable compositions with explicit directions
  - Keep multivariate DSM modeling and formula/syntax generation for a later
    modeling layer
- Extend composition controls only after the v0.1.0 API has real examples
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

## Version 0.2.0 - CRAN API-Stabilization Release

Status: planned. Items below are proposals until they have been reviewed,
implemented, and checked. Because development already contains intentionally
breaking names and defaults, this release should be version 0.2.0 rather than
0.1.1. Keep the direct-migration policy: do not add deprecated wrappers for the
0.1.0 API.

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

### Release-blocking correctness fixes

- [ ] Preserve stable partner CBP values on unpaired occasions.
  - Current problem: longitudinal partner construction joins every component on
    `dyad + time`, so an actor receives a missing partner CBP whenever the
    partner has no row at that occasion, even though CBP is a known person-level
    quantity.
  - Recommended implementation: match CBP partner values by dyad and partner
    member, independently of current-time row availability. Keep raw and CWP
    contemporaneous partner values matched within dyad-occasion.
  - Test absent partner rows against equivalent explicit rows with missing
    outcomes; stable partner CBP values should agree in both representations.
- [ ] Construct partner and dyadic lagged predictors from the source occasion.
  - Current problem: a partner's `t - 1` value is first stored on that partner's
    row at `t`, so it is lost when the partner has no current row even if the
    required source row exists.
  - Recommended APIM implementation: retrieve the partner's source value at
    exactly `current_time - 1` and attach it to the actor's current row.
  - Recommended DIM/DSM implementation: form the dyad mean, deviation, or
    directional difference from both members at source time `t - 1`, then attach
    that completed score to available outcome rows at `t`.
  - Continue to require exact lag spacing and never bridge missing time indexes.
    The existing own-actor lag behavior can remain.
  - Add asymmetric-missingness tests for APIM, DIM, and DSM and for raw and CWP
    lag sources.
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
  - Recommended contract: treat `dyadMLM_data` as an immutable prepared analysis
    artifact. Filter and transform the raw data first, then call
    `prepare_dyad_data()` as the final preparation step.
  - Add base/dplyr reconstruction behavior that invalidates the custom class and
    metadata after unsupported row or column mutations. Adjust package internals
    so the class is restored only after a validated generation stage.
  - Do not silently re-center or rebuild after filtering because the package
    cannot know whether the original or filtered reference population is the
    intended estimand.
  - Test base `[`, `filter()`, `slice()`, `select()`, and `mutate()`.

### API decisions to settle before the 0.2.0 freeze

- [ ] Make arbitrary member assignment reproducible without using the session's
  RNG state by default.
  - Preferred lean API: assign `-1/+1` deterministically from a documented stable
    member ordering and remove the public `seed` argument.
  - Smaller alternative: retain `seed` but use a fixed non-`NULL` default and
    preserve the caller's RNG state. This is reproducible for identical data but
    less stable when dyads are added or removed.
  - Keep the documentation explicit that the sign is arbitrary and has no
    substantive member interpretation.
  - If `seed` is removed, update every package vignette, workshop source, example,
    test, and NEWS migration entry in the same change.
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

### Conditional documentation stretch goal after stabilization

Only begin this work after all release-blocking correctness fixes are complete,
the 0.2.0 API decisions are settled, and the full test suite is green. This would
be a useful addition, but it is not a release gate; defer it rather than delay
the CRAN release.

- [ ] Adapt the validated workshop DHARMa diagnostics into one focused package-
  vignette section. Keep the first addition documentation-only, without an
  exported diagnostic helper or plotting API.
  - Start with model convergence, a positive-definite Hessian, finite standard
    errors, and boundary covariance estimates. Use `glmmTMB::diagnose()` as
    supporting evidence rather than as a pass/fail verdict.
  - Scope the initial workflow to the documented two-member Gaussian `glmmTMB`
    models with dyad random effects and `dispformula = ~ 0`.
  - Use unconditional DHARMa simulation, for example
    `simulateResiduals(model, n = 2000, simulateREs = "unconditional",`
    `refit = FALSE, plot = FALSE)`, because conditioning on the fitted dyad
    effects can make this model's residual simulations nearly degenerate.
  - Supplement the ordinary residual checks with fitted-row-aligned
    `recalculateResiduals()` checks for dyad means and within-dyad differences.
    Do not treat partners as independent observations when outcome missingness
    leaves incomplete fitted dyads.
  - State the boundary clearly: these checks do not by themselves validate the
    dyadic covariance structure, exchangeability, or temporal dependence. Do
    not pool temporal autocorrelation tests across repeated member series.
  - Validate the workflow on both distinguishable and exchangeable
    cross-sectional examples, including asymmetric outcome missingness.
  - If the section is executed during vignette builds, add a versioned DHARMa
    entry to `Suggests`, keep runtime CRAN-safe, and verify that simulation does
    not leave altered `glmmTMB` state behind. Otherwise, guard or precompute the
    expensive output explicitly.
  - Require a clean local vignette render and CI/pkgdown render. If the workflow
    remains slow or fragile, retain it in the workshop materials and defer the
    package-vignette addition.

### Additional tests and optional polish

- [ ] Test fitted exchangeable-covariance recovery when outcome missingness
  leaves only one member in some fitted grouping units while both member signs
  remain represented overall.
- [ ] Add a direct `compare_nested_models()` regression test for a valid
  `glmmTMB` fit created with `se = FALSE` if that variant remains supported.
- [ ] If random assignment remains available, document and test how factor-level
  ordering affects reproducibility under a fixed seed.
- [ ] Consider `summary.exchangeable_covariance()` for `brms` draws, with a
  point summary and interval rather than only array dimensions. This is useful
  but additive and is not a 0.2.0 release gate.
- [ ] Consider splitting the large covariance implementation into backend
  extraction, block matching, validation, transformation, and printing files.
  This is maintainability work, not a release gate.

### CRAN release checklist

- [ ] Resolve every release-blocking correctness item and every API decision
  above; update this roadmap with the chosen contracts rather than leaving both
  alternatives documented as if implemented.
- [ ] Update `NEWS.md` with short 0.1.0-to-0.2.0 migration guidance, including
  all changed defaults and generated-column or S3-class names. Do not add
  deprecated wrappers.
- [ ] Update `DESCRIPTION` to version 0.2.0 and the release date; update
  `CITATION.cff` to the same version and date. Verify that
  `citation("dyadMLM")` reports version 0.2.0 while retaining the Zenodo concept
  DOI.
- [ ] Run `devtools::document()`, render `README.Rmd`, and rebuild every package
  vignette affected by the API or numerical changes. Check examples and package
  help for stale names and defaults.
- [ ] If the conditional DHARMa section is included, verify its declared
  dependency, build-time behavior, runtime, fitted-row alignment, and simulation
  state in the exact release tarball.
- [ ] Run the complete test suite, including all new asymmetric-missingness and
  mutation-contract regressions, with no failures, warnings, or unexpected
  skips.
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

- Estimation helpers or syntax-generating wrappers for supported model engines.
- Bayesian model-comparison support for `compare_nested_models()`.
- Exported or generalized diagnostic automation, diagnostic plotting helpers,
  and generalized sparse-composition guidance. The bounded documentation
  workflow above does not imply a new public diagnostics API.
- A wide-to-long preprocessing helper; `prepare_dyad_data()` remains strict
  about the canonical long format.
- A custom Stan backend, advanced ILD/EMA infrastructure, and automated
  AR(1)/VAR diagnostics.
- A preprint or methods note. When developed, cite the Zenodo concept DOI for
  the implementation and use the paper for the broader composition-aware dyadic
  MLM framework.

## Version 0.3.0

- Advanced ILD/EMA data infrastructure
  - Add `"3l"` temporal predictor decomposition only after the `"2l"`
    workflow is stable
  - Require an explicit day, burst, or period variable for `"3l"`
  - Do not infer `"3l"` automatically from EMA nesting or three-level random
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
    latent one-partner missingness in dynamic models
  - Distinguish latent-state handling from the observed-data preparation fixed
    for 0.2.0: known CBP and exact observed `t - 1` values should survive an
    absent current partner row, but latent-state imputation remains out of the
    core preparation API until a modeling layer needs it

## Version 0.4.0 and Later

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

- stable `prepare_dyad_data()` argument names and semantics
- stable generated-column families for compositions, temporal predictor
  components, APIM predictors, and DIM/DSM predictors
- stable analysis-composition controls:
  `keep_compositions`, `set_exchangeable_compositions`, and
  `pool_compositions`
- clear metadata for raw observed compositions versus final analysis
  compositions
- complete getting-started, APIM, mixed-APIM, DIM, and DSM documentation paths
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
