# Changelog

## dyadMLM (development version)

- Retained generated columns now use a single leading dot instead of
  `.dy_` for more readable model formulas. For example, `.dy_x_actor`
  becomes `.x_actor`. The `.dy_` prefix is reserved for temporary
  implementation columns.
- [`prepare_dyad_data()`](https://pascal-kueng.github.io/dyadMLM/reference/prepare_dyad_data.md)
  now uses compact composition-column names when the final data contain
  one composition, such as `.is_female` and
  `.member_contrast_arbitrary`. Set `short_colnames = FALSE` to retain
  composition-qualified names.
  [`recover_exchangeable_covariance()`](https://pascal-kueng.github.io/dyadMLM/reference/recover_exchangeable_covariance.md)
  recognizes both forms.
- `prepare_dyad_data(include_arbitrary_member_contrast = TRUE)` can now
  add arbitrary member contrasts for distinguishable compositions
  without changing their metadata or role indicators. This supports full
  and exchangeability-constrained APIMs from the same prepared data.
  `set_exchangeable_compositions` still performs reclassification for
  pooling and DIM preparation.
- Added a [`summary()`](https://rdrr.io/r/base/summary.html) method for
  prepared data that prints the dyadic structure followed by standard
  summaries of all columns.
- Generated-column tracking now records all retained composition and
  modeling columns. Printing and model comparison use these records
  rather than inferring column ownership from a prefix, and generated
  names are checked for collisions and valid R syntax before they are
  written.
- `prepare_dyad_data(add_apim_gmc_predictors = TRUE)` now adds GMC
  source, actor, and partner columns alongside raw APIM columns, plus
  lagged variants when requested. It uses one mean over retained
  non-missing values, warns about skipped non-numeric predictors in
  mixed selections, and leaves DIM/DSM centering unchanged.
- For longitudinal data,
  [`prepare_dyad_data()`](https://pascal-kueng.github.io/dyadMLM/reference/prepare_dyad_data.md)
  now temporarily adds an all-missing partner row when only one member
  is present at an observed dyad-occasion. This preserves partner CBP
  values and exact source-occasion APIM, DIM, and DSM lags. Temporary
  rows are removed before the prepared data are returned. This is
  structural completion for column construction, not imputation or the
  addition of analysis rows.
- Numeric structural columns and numeric predictors selected for
  preparation now reject `Inf` and `-Inf` before model-ready columns are
  generated. Errors identify the affected columns and input rows; `NA`
  and `NaN` remain supported as missing predictor values.
- Renamed `compare_nested_glmmTMB_models()` to
  [`compare_nested_models()`](https://pascal-kueng.github.io/dyadMLM/reference/compare_nested_models.md).
- Naming changes in this development version are intentionally breaking:
  names from 0.1.0 are not retained.
- Added package-level help at
  [`?dyadMLM`](https://pascal-kueng.github.io/dyadMLM/reference/dyadMLM-package.md),
  with links to the main functions, example datasets, and
  getting-started documentation.
- Example datasets no longer include the redundant `dyad_composition`
  column. Instead, `dyads_ild` now includes member-specific AR(1)
  residual processes.

## dyadMLM 0.1.0

CRAN release: 2026-07-30

- Initial release.
- Cleaned up the pre-release public API with these direct migration
  mappings: `group` to `dyad`, `lag_predictors` to `lag1_predictors`,
  `model_type` to `model_types`, `temporal_predictor_decomposition` to
  `temporal_decomposition`, `"time_2l"` to `"2l"`,
  `include_compositions` to `keep_compositions`, `compare_dyad_models()`
  to `compare_nested_glmmTMB_models()`, `exchangeable_rescov()` to
  [`recover_exchangeable_covariance()`](https://pascal-kueng.github.io/dyadMLM/reference/recover_exchangeable_covariance.md),
  `pairs` to `block_pairings`, pairing fields `shared` and `difference`
  to `shared_block` and `difference_block`, and print argument `what` to
  `representation`.
- Renamed generated exchangeable-member contrasts from
  `.dy_diff_{composition}_arbitrary` to
  `.dy_member_contrast_{composition}_arbitrary`.
- Renamed the package from `interdep` to `dyadMLM`. Package-generated
  columns now use the `.dy_` prefix instead of `.i_`.
- Added validation and preparation of cross-sectional and intensive
  longitudinal dyadic data with distinguishable, exchangeable, and mixed
  dyad compositions.
- Added composition filtering, exchangeability overrides, and pooling.
- Exchangeable-dyad difference columns now use an `_arbitrary` suffix.
- Added temporal predictor decomposition and model-ready columns for
  APIM, DIM, and DSM parameterizations.
- Added `compare_nested_glmmTMB_models()` for compatible nested
  `glmmTMB` models and
  [`recover_exchangeable_covariance()`](https://pascal-kueng.github.io/dyadMLM/reference/recover_exchangeable_covariance.md)
  for back-transforming shared/difference random-effect covariance
  structures.
- Added example datasets, getting-started and model-specific vignettes,
  and a concise print method for prepared data.
