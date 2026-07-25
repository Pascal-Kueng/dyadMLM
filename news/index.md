# Changelog

## dyadMLM (development version)

- Retained generated columns now use a single leading dot instead of
  `.dy_` for more readable model formulas; for example, `.dy_x_actor`
  becomes `.x_actor`. The `.dy_` prefix is reserved for temporary
  implementation columns.
- [`prepare_dyad_data()`](https://pascal-kueng.github.io/dyadMLM/reference/prepare_dyad_data.md)
  now uses compact composition-column names when the final data contain
  one composition, such as `.is_female` and
  `.member_contrast_arbitrary`. Set `short_colnames = FALSE` to retain
  composition-qualified names.
  [`recover_exchangeable_covariance()`](https://pascal-kueng.github.io/dyadMLM/reference/recover_exchangeable_covariance.md)
  recognizes both forms.
- Added a [`summary()`](https://rdrr.io/r/base/summary.html) method for
  prepared data that prints the dyadic structure followed by standard
  summaries of all columns.
- Generated-column tracking now records all retained composition and
  modeling columns. Printing and model comparison use these records
  rather than inferring column ownership from a prefix, and generated
  names are checked for collisions and valid R syntax before they are
  written.
- Updated the APIM, DIM, and DSM vignettes to use a common pooled grand
  mean when comparing parameterizations, so their intercepts share the
  same reference point.
- Added package-level help at
  [`?dyadMLM`](https://pascal-kueng.github.io/dyadMLM/reference/dyadMLM-package.md),
  with links to the main functions, example datasets, and
  getting-started documentation.

## dyadMLM 0.1.0

- Initial release.
- Cleaned up the pre-release public API with these direct migration
  mappings: `group` to `dyad`, `lag_predictors` to `lag1_predictors`,
  `model_type` to `model_types`, `temporal_predictor_decomposition` to
  `temporal_decomposition`, `"time_2l"` to `"2l"`,
  `include_compositions` to `keep_compositions`, `compare_dyad_models()`
  to
  [`compare_nested_glmmTMB_models()`](https://pascal-kueng.github.io/dyadMLM/reference/compare_nested_glmmTMB_models.md),
  `exchangeable_rescov()` to
  [`recover_exchangeable_covariance()`](https://pascal-kueng.github.io/dyadMLM/reference/recover_exchangeable_covariance.md),
  `pairs` to `block_pairings`, pairing fields `shared` and `difference`
  to `shared_block` and `difference_block`, and print argument `what` to
  `representation`.
- Renamed generated exchangeable-member contrasts from
  `.dy_diff_{composition}_arbitrary` to
  `.dy_member_contrast_{composition}_arbitrary`. Covariance recovery
  continues to recognize legacy contrast names in previously fitted
  models.
- Renamed the package from `interdep` to `dyadMLM`; package-generated
  columns now use the `.dy_` prefix instead of `.i_`.
- Added validation and preparation of cross-sectional and intensive
  longitudinal dyadic data with distinguishable, exchangeable, and mixed
  dyad compositions.
- Added composition filtering, exchangeability overrides, and pooling.
- Exchangeable-dyad difference columns now use an `_arbitrary` suffix.
- Added temporal predictor decomposition and model-ready columns for
  APIM, DIM, and DSM parameterizations.
- Added
  [`compare_nested_glmmTMB_models()`](https://pascal-kueng.github.io/dyadMLM/reference/compare_nested_glmmTMB_models.md)
  for compatible nested `glmmTMB` models and
  [`recover_exchangeable_covariance()`](https://pascal-kueng.github.io/dyadMLM/reference/recover_exchangeable_covariance.md)
  for back-transforming shared/difference random-effect covariance
  structures.
- Added example datasets, getting-started and model-specific vignettes,
  and a concise print method for prepared data.
