# Changelog

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
- [`prepare_dyad_data()`](https://pascal-kueng.github.io/dyadMLM/reference/prepare_dyad_data.md)
  now uses shorter composition-column names when the final data contain
  one composition. Set `short_colnames = FALSE` to retain
  composition-qualified names.
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
