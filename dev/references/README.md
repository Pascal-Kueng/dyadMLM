# Development reference library

This directory contains the local reading library used to develop and validate
`dyadMLM`. PDFs are ignored by `dev/.gitignore`, and all of `dev/` is excluded
from package builds. Some files are open access; others are local reading
copies. Check the license before redistributing any PDF.

## Organization

- [`model_estimation/`](model_estimation/README.md) contains papers that define
  dyadic models, covariance parameterizations, random-effects structures, or
  the modeling software used to estimate them.
- [`simulation_checks/`](simulation_checks/README.md) contains predictive-check
  theory, graphical workflows, residual methods, calibration work, and direct
  precedents for the package's simulation-based dyadic checks.
- [`validation_studies/`](validation_studies/README.md) contains guidance for
  simulation studies that evaluate statistical methods and implementations.

Each PDF has one physical home based on its main use in this repository.
Cross-cutting papers are linked from the other relevant index rather than
duplicated. Filenames follow `year-author-short-title.pdf` where practical.
