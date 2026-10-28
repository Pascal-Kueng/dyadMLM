# dyadMLM (development version)

* `prepare_dyad_data()` gains `partner_exists`, which records whether a
  partner existed. It keeps people observed alone (singletons and people whose
  partner did not take part) with their own compositions, and sets partner
  predictors to 0 where no partner existed (two-part coding, with a
  `.partner_exists` column). The status must stay the same within each dyad.
  See `vignette("partner-exists")`.

* `print()` and `summary()` of prepared data now report people observed
  alone, dyad-occasions with a row for only one member, rows with missing
  partner predictors, and suggested model terms: composition indicators for
  the fixed part, variance terms for people observed alone, and the partner
  terms of two-part coding. A new help section in `prepare_dyad_data()`
  explains how these cases are prepared.

* `recover_exchangeable_covariance()` recognizes summed indicators such as
  `I(.is_male_x_male + .is_singleton_male)`, which let people observed alone
  share the variance of an exchangeable composition.

# dyadMLM 0.3.0

* `prepare_dyad_data()` now rejects pool names that match generated role labels
  in other compositions, preventing distinct groups from silently sharing an
  indicator column (thanks to [@JorAlEs](https://github.com/JorAlEs),
  [#108](https://github.com/Pascal-Kueng/dyadMLM/pull/108)).

* Changed the package license from MIT to GPL-3.

* Added experimental `simulate_dyad_responses()` and
  `check_partner_dependence()` to check response variances and partner
  correlations in `glmmTMB` models with Gaussian or selected non-Gaussian
  responses, including ordinal, zero-inflated, and hurdle models. Checks can be
  performed separately for each dyad composition. For repeated occasions,
  supply `member` and `time` to `check_partner_dependence()` to check member
  means and same-occasion deviations separately.

* Added experimental `check_dyad_residuals()` for simulated probability
  integral transform (PIT) residuals and `check_dyad_outcomes()` for response
  distributions, SDs, extremes, and zero counts. Both use the output from
  `simulate_dyad_responses()`. The PIT residuals follow Florian Hartig's
  DHARMa approach and Dunn and Smyth's (1996) randomized quantile residuals,
  but the simulations and reference distributions account
  for the dyadic and temporal dependence the model includes. DHARMa is not
  required. A
  [simulation study](https://pascal-kueng.github.io/dyadMLM/articles/distribution-checks.html)
  evaluates sensitivity and false-positive flags.

* Added `quartile_lines = "qgam"` to `check_dyad_residuals()` to fit the PIT
  quartile lines with the qgam package, as DHARMa does. These lines can show
  trends near the ends of a numeric axis more clearly, but take much longer,
  and their envelopes are approximate.

* Improved function help and the model-comparison example (thanks to
  [@musanyaks](https://github.com/musanyaks),
  [#50](https://github.com/Pascal-Kueng/dyadMLM/pull/50)).

* Fixed an internal vctrs error in `prepare_dyad_data()` when no member rows
  are missing and the data contain, for example, an `hms` column while the hms
  package is not loaded.

* Fixed `recover_exchangeable_covariance()` accepting a custom shared
  indicator with values other than 0 and 1, such as 0.5, when
  `difference_block = NULL`. It now gives an error.

* Fixed predictive means for `glmmTMB` 1.1.15.2 and later when the
  zero-inflation component has random effects but no fixed effects.

* Fixed `compare_nested_models()` reporting a likelihood-ratio test for
  `glmmTMB` models fitted with `priors`. It now asks to refit them without
  priors.

* Fixed `prepare_dyad_data()` silently using another column when `predictors`
  or `lag1_predictors` renamed a column, as in `c(z = x)`. Renaming now gives
  an error.

* Fixed `prepare_dyad_data()` failing when an APIM predictor is also the
  `dyad`, `member`, or `time` column, as in growth models that use time as a
  predictor.

* Fixed `prepare_dyad_data()` failing with dplyr 1.1.0. dyadMLM now requires
  dplyr 1.1.1 or later.

* Fixed `prepare_dyad_data()` keeping incomplete dyads despite
  `incomplete_dyads = "drop"` when the `dyad` column was named `n_members`.
  Messages and metadata also showed member counts instead of dyad IDs.

* `prepare_dyad_data()` now gives a clear error when `data` is supplied
  twice, for example through the pipe and as an argument.

* `prepare_dyad_data()` warns when all lag-1 values of a predictor are
  missing, for example when `time` counts years with two-year waves
  ([#83](https://github.com/Pascal-Kueng/dyadMLM/issues/83)).

* Fixed `recover_exchangeable_covariance()` accepting member contrasts from
  `prepare_dyad_data()` when no fitted group contained both partners, for
  example in a model grouped by person instead of couple. It now gives an
  error.

# dyadMLM 0.2.0

* This early API-stabilization release intentionally makes a few direct,
  breaking changes from 0.1.0. Compatibility wrappers are not retained.

* Retained generated columns now use a single leading dot instead of `.dy_`
  for more readable model formulas. For example, `.dy_x_actor` becomes
  `.x_actor`. The `.dy_` prefix is reserved for temporary implementation
  columns.
* `prepare_dyad_data()` now uses compact composition-column names when the
  final data contain one composition, such as `.is_female` and
  `.member_contrast_arbitrary`. Set `short_colnames = FALSE` to retain
  composition-qualified names. `recover_exchangeable_covariance()` recognizes
  both forms.
* `prepare_dyad_data(include_arbitrary_member_contrast = TRUE)` can now add arbitrary
  member contrasts for distinguishable compositions without changing their
  metadata or role indicators. This supports full and
  exchangeability-constrained APIMs from the same prepared data.
  `set_exchangeable_compositions` still performs reclassification for pooling
  and DIM preparation.
* Added a `summary()` method for prepared data that prints the dyadic structure
  followed by standard summaries of all columns.
* Printing prepared data now uses current dyad and composition counts. If a
  required column has been removed, the unavailable summary is
  identified instead of displaying its preparation-time count.
* Generated-column tracking now records all retained composition and modeling
  columns. Printing and model comparison use these records rather than
  inferring column ownership from a prefix, and generated names are checked for
  collisions and valid R syntax before they are written.
* `prepare_dyad_data(add_apim_gmc_predictors = TRUE)` now adds GMC source,
  actor, and partner columns alongside raw APIM columns, plus lagged variants
  when requested. It uses one mean over retained non-missing values, warns
  about skipped non-numeric predictors in mixed selections, and leaves DIM/DSM
  centering unchanged.
* For longitudinal data, `prepare_dyad_data()` now temporarily adds an
  all-missing partner row when only one member is present at an observed
  dyad-occasion. This preserves partner CBP values and exact source-occasion
  APIM, DIM, and DSM lags. Temporary rows are removed before the prepared data
  are returned. This is structural completion for column construction, not
  imputation or the addition of analysis rows.
* Numeric structural columns and numeric predictors selected for preparation
  now reject `Inf` and `-Inf` before model-ready columns are generated. Errors
  identify the affected columns and input rows; `NA` and `NaN` remain supported
  as missing predictor values.
* Renamed `compare_nested_glmmTMB_models()` to `compare_nested_models()`.
  Its printed conclusion now uses a configurable `alpha` level and no longer
  recommends a model solely because the likelihood-ratio test is not
  significant.
* `recover_exchangeable_covariance()` now returns an
  `exchangeable_covariance` object instead of an `exchangeable_rescov` object,
  with a clearer member-level print heading.
* For `brms` models, `recover_exchangeable_covariance()` now returns posterior-
  mean matrices by default. Use `posterior = "median"` or `"draws"` for the
  corresponding alternatives.
* Added package-level help at `?dyadMLM`, with links to the main functions,
  example datasets, and getting-started documentation.
* Example datasets no longer include the redundant `dyad_composition` column.
  Instead, `dyads_ild` now includes member-specific AR(1) residual processes.

# dyadMLM 0.1.0

* Initial release.
* Cleaned up the pre-release public API with these direct migration mappings:
  `group` to `dyad`, `lag_predictors` to `lag1_predictors`, `model_type` to
  `model_types`, `temporal_predictor_decomposition` to
  `temporal_decomposition`, `"time_2l"` to `"2l"`, `include_compositions` to
  `keep_compositions`, `compare_dyad_models()` to
  `compare_nested_glmmTMB_models()`, `exchangeable_rescov()` to
  `recover_exchangeable_covariance()`, `pairs` to `block_pairings`, pairing
  fields `shared` and `difference` to `shared_block` and `difference_block`,
  and print argument `what` to `representation`.
* Renamed generated exchangeable-member contrasts from
  `.dy_diff_{composition}_arbitrary` to
  `.dy_member_contrast_{composition}_arbitrary`.
* Renamed the package from `interdep` to `dyadMLM`. Package-generated columns
  now use the `.dy_` prefix instead of `.i_`.
* Added validation and preparation of cross-sectional and intensive
  longitudinal dyadic data with distinguishable, exchangeable, and mixed dyad
  compositions.
* Added composition filtering, exchangeability overrides, and pooling.
* Exchangeable-dyad difference columns now use an `_arbitrary` suffix.
* Added temporal predictor decomposition and model-ready columns for APIM,
  DIM, and DSM parameterizations.
* Added `compare_nested_glmmTMB_models()` for compatible nested `glmmTMB` models and
  `recover_exchangeable_covariance()` for back-transforming shared/difference random-effect
  covariance structures.
* Added example datasets, getting-started and model-specific vignettes, and a
  concise print method for prepared data.
