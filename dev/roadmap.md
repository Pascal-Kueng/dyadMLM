
# Roadmap for 'interdep' R-Package

This package provides functions for preparing and eventually estimating dyadic
models like APIMs, focusing on cross-sectional and intensive longitudinal (ILD)
data.

## Version 0.1.0 - First CRAN Release Candidate

Goal: ship a small, reliable data-preparation workflow before adding larger
model-building features.

- Validate dyadic data and return a model-ready tibble with metadata
- Support cross-sectional and ILD data for distinguishable, exchangeable, and
  partially unknown dyads
- Auto-detect roles, dyad compositions, and distinguishability where possible
- Handle incomplete dyads and missing roles with explicit `error`, `drop`, and
  `keep` behavior
- Return factor columns for `.i_composition` and
  `.i_composition_role`
- Add a print method for `interdep_data`
  - Show number of dyads, whether data are longitudinal, and inferred
    composition counts
  - Make incomplete dyads, missing roles, and unknown compositions visible
- Add composition role indicator columns for cross-sectional model workflows
- Add helper functions to rotate `.i_diff` / Idiff structures back to
  partner-level interpretations
- Constrain and pool compositions
  - Example: treat male-female dyads as exchangeable
  - Example: pool male-male and female-female dyads as same-sex
- Keep README and vignette focused on the data-preparation workflow
- Release to CRAN once checks, tests, docs, README, and vignette are clean

## Version 0.2.0

- Add within- and between-person centering for ILD data
  - Support grand-mean centering
  - Support centering based on means of person means
  - Keep missing-data behavior explicit
- Write static code/syntax to estimate cross-sectional and ILD models using:
  - glmmTMB
  - brms, including priors
  - dynamite or another MLSEM/DSEM framework

## Version 0.3.0

- Estimation helpers for the supported packages
- Model summaries
- Diagnostics
