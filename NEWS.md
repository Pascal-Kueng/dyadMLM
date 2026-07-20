# dyadMLM 0.0.1

* Initial release.
* Renamed the package from `interdep` to `dyadMLM`; package-generated columns
  now use the `.dy_` prefix instead of `.i_`.
* Added validation and preparation of cross-sectional and intensive
  longitudinal dyadic data with distinguishable, exchangeable, and mixed dyad
  compositions.
* Added composition filtering, exchangeability overrides, and pooling.
* Exchangeable-dyad difference columns now use an `_arbitrary` suffix.
* Added temporal predictor decomposition and model-ready columns for APIM,
  DIM, and DSM parameterizations.
* Added `compare_dyad_models()` for compatible nested `glmmTMB` models and
  `exchangeable_rescov()` for back-transforming shared/difference random-effect
  covariance structures.
* Added example datasets, getting-started and model-specific vignettes, and a
  concise print method for prepared data.
