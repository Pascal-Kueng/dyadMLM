# Diagnostic Development Specifications

This directory contains development specifications and validation material for
simulation-based dyadic diagnostics. Each supported design has one
authoritative specification; this README is only an index and shared status
summary.

## Current and planned specifications

- [`gaussian-cross-sectional-partner-dependence.md`](gaussian-cross-sectional-partner-dependence.md)
  is authoritative for the current Gaussian identity-link `glmmTMB`
  simulation constructor and cross-sectional `check_partner_dependence()`
  feature.
- [`gaussian-ild-partner-dependence.md`](gaussian-ild-partner-dependence.md)
  specifies the planned Gaussian intensive-longitudinal extension of the same
  public function. It covers stable, concurrent, own-member lagged, and
  cross-member lagged dependence.
- [`brms-partner-prototype.md`](brms-partner-prototype.md) records the
  development-only Bayesian backend prototype and its promotion gates.
- [`../roadmap.md`](../roadmap.md) owns milestone order, later generalized and
  three-level paths, and the eventual diagnostic capability matrix.

The accompanying `.R`, `.Rmd`, and rendered review files are validation or
prototype material. They do not establish package support by themselves.

## Shared boundaries

- Compare observed summaries with the same summaries calculated from complete
  response datasets simulated by the fitted model.
- Preserve fitted-row alignment and the complete dyadic dependence structure.
- Treat reference intervals and curve envelopes as descriptive checks, not
  p-values, pass/fail tests, or a general model-adequacy score.
- Keep model comparison, convergence checks, and leave-one-dyad-out
  cross-validation as separate workflows.
- Do not infer support for another design, backend, family, link, or dyad type
  from one validated path.

## Planned sequence

1. Complete and review the Gaussian cross-sectional `glmmTMB` feature.
2. Extend the same public function to the complete four-part Gaussian ILD
   profile.
3. Add response-distribution checks.
4. Consolidate the user-facing documentation and publish a capability matrix.

Generalized, `brms`, mixed-composition, and three-level diagnostic paths remain
separately validated later increments. Add a dedicated generalized diagnostic
specification only when that work begins; do not create an empty placeholder or
use this index as its specification.
