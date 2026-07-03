# Maintenance Report: `interdep` Package

## 1. Scope & Current Status
- **Goal:** The package `interdep` prepares dyadic data for interdependency analyses.
- **CI/CD:** No CI workflows detected (missing `.github/workflows`, `.travis.yml`, etc.).
- **Tests:** `testthat` suite passes (128 passing tests).
- **Issues:** No open GitHub issues.
- **Dependencies:** Built on `rlang`, `dplyr`, `tibble`.

## 2. Identified Risks & Gaps
1. **No Continuous Integration (CI):**
   - *Risk:* Future PRs may break the `testthat` suite without automated feedback.
   - *Recommendation:* Add a GitHub Actions workflow (e.g., `usethis::use_github_action("check-standard")`).

2. **Missing `covr` tests or code coverage report:**
   - *Risk:* Unclear test coverage for `prepare_interdep_data.R` and `infer_dyad_compositions.R`.

3. **Column Prefix Strategy & Naming:**
   - *Risk:* Indicator columns are named such as `.i_is_female_x_male_female`. This might grow awkwardly for very complex role labels. It also relies on `stats::model.matrix` silently, which drops `NA` values and might cause unexpected mismatches if not handled properly (though `NA`s in `role` seem to be replaced with `"unknown"`).

4. **Handling non-standard Characters in Roles:**
   - *Risk:* `gsub("[^[:alnum:]_]+", "_", ...)` cleans labels into valid variable names but could collide (e.g., `role_a` and `role-a` both become `role_a`).

## 3. Recommended Next Tasks
- **Task 1: Set up CI.** Introduce GitHub Actions for `R CMD check` on multiple OSs (Linux, macOS, Windows).
- **Task 2: Code Coverage.** Introduce `covr` and generate a `codecov` badge to monitor test completion.
- **Task 3: Refine sanitize logic.** Explicitly document or enforce standard labels in `role` variables to prevent label collisions during dummy matrix creation.
