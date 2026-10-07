# ILD partner-dependence check: plan

Status: implemented as planned in §4, 2026-09-29, plus a role check; validation
(§7) completed on 2026-09-30.
**(decided)** marks the author's decisions. Lag and AR checks are a separate
later PR.

## 1. Idea

For intensive longitudinal data (ILD), split every response dataset (observed and
each simulation, after any model-centring) into two levels. Then run the existing
paired statistics on each level:

- **Between:** member means over all of a member's usable occasions
  **(decided)**, paired within the dyad.
- **Within:** each response minus its member's mean, paired by dyad and occasion.

The statistics, compositions, plug-in reference and flag rule stay unchanged.
Every dataset uses its own member means.

## 2. Why this is sound

Gaussian concurrent model, model-centred: `y_jmt = mu_jmt + u_jm + e_jmt`, with
stable effects `u` (variances `tau_m^2`, partner covariance `tau_12`) and occasion
effects `e` (`sig_m^2`, `sig_12`), independent over occasions. Member `m` of dyad
`j` has `n_jm` occasions, `c_j` of them shared with the partner.

| Level | Variance of member `m` | Partner covariance |
|---|---|---|
| Between | `tau_m^2 + sig_m^2 / n_jm` | `tau_12 + sig_12 * c_j / (n_j1 * n_j2)` |
| Within (shared occasions) | `sig_m^2 * (1 - 1/n_jm)` | `sig_12 * (1 - 1/n_j1 - 1/n_j2 + c_j / (n_j1 * n_j2))` |

- With complete data, the within correlation targets the same-occasion
  correlation exactly. The between level mixes stable dependence with
  occasion-level dependence averaged over the occasions, so it is labelled
  "member means", not "stable dependence".
- Pooling within pairs across dyads is valid. The same statistic is computed on
  the observed and on every simulated dataset, and each simulated dataset carries
  the model's dependence. The pairs therefore need not be independent.
  Centring before pooling keeps the levels apart. The within check is related to
  repeated-measures correlation (Bakdash & Marusich, 2017).
- Weighting: between, each dyad counts once. Within, each shared occasion counts
  once.
- The reference is conditional on the observed rows, the predictors and the
  fitted parameters.

## 3. Limits to document (text only, no code)

1. **Misfits cross levels,** especially with few occasions or nonlinear links, so
   both levels must be read together. Exploratory examples:
   - Unequal occasion variances under an equal-variance model flagged the
     between role-difference correlation in 81% of datasets at T = 3 and 21% at
     T = 14.
   - Omitting only the stable covariance of a Poisson model flagged the within
     partner correlation in 79% of datasets.

   The study (§7) did not reproduce these: no row at the other level flagged in
   more than 3.4% of datasets, because free covariance parameters absorbed the
   misfits.
2. **Serial dependence (AR) is not checked.** A model without AR still matches
   the rows its free parameters pin (demo, §8). Reference ranges for restricted
   summaries may then be too narrow. Check temporal dependence separately.
   Lags come in the next PR.
3. These checks can be misleading when the model includes lagged outcomes as
   predictors.
4. Poorly estimated same-occasion effects can affect the within checks.
   Check the fitted model's convergence and covariance estimates.
5. `time` must identify occasions shared by both partners, such as the diary day,
   not timestamps. Rows without their partner on that occasion still count in the
   member mean.

## 4. Minimal implementation

No new exported functions and no refactor of the statistics. The implementation
adds about 100 lines of R code, excluding help text and comments. Most of it is
the internal `prepare_occasion_pairs()`. The statistics loop, the minimum rule,
the messages, and the print and plot methods are unchanged:

1. `member = NULL, time = NULL` after `role`, resolved like `role`. `time`
   requires `member`; `member` is ignored without `time`.
2. If `time` is supplied:
   - Stop if a member or time is missing. Rows with a missing dyad or (supplied)
     role are dropped and counted in the existing omission warning.
   - Stop if a member's role changes across occasions.
   - Stop if a member has two rows at one occasion; otherwise such rows would be
     paired as partners.
   - Compute member means and deviations for all datasets at once and place them
     side by side, so one pair table indexes both levels.
   - Build between pairs with `prepare_partner_pairs()` on one row per member,
     unchanged.
   - Build within pairs by joining each between pair's two members on `time`, so
     they inherit its composition and role order.
   - Stack both levels' composition rows. A `level` column records the level,
     and each label ends with it, such as "female - male (within)".
3. A level-composition is checked with at least three dyads **(decided)**: complete
   dyads between, dyads with a shared occasion within. Within rows therefore
   count dyads in `n_pairs`, and the existing minimum, messages, printout, and
   plot headings apply as they are.
4. Plots show one figure per level and composition, all between figures first.
5. Without `time`, the existing "more than two rows per dyad" error names `member`
   and `time`.

See `prepare_occasion_pairs()` and the member-mean split in
`check_partner_dependence()`. The cross-sectional path and its results do not change. Two existing tests pass
`plot` and `response` by position and need names. The function is unreleased.

Left out on purpose; suggest separately only if wanted:
- unpaired-occasion counts;
- an extra error when no occasion is shared (the skip warning covers it);
- a warning for lag columns;
- type rules for `time`;
- alternative weightings.

## 5. Documentation

- `check_partner_dependence()`: `member` and `time`, plus a short "Repeated
  occasions" section covering §1, the weighting line from §2, and §3. Add one ILD
  example with `dyads_ild`.
- `simulate_dyad_responses()`: drop "currently requires cross-sectional dyads".
- NEWS entry; the dev README and roadmap 0.2.2 scope (all families, lags next).

## 6. Tests

- Port the prototype's hand-calculation tests: both levels, raw and
  model-centred, with and without roles, unpaired occasions, row order and
  member swaps.
- Errors: duplicate member-occasion rows; `member` without `time`.
- A composition skipped at the within level with fewer than three dyads that
  share an occasion.
- Labels that name the level, in the printout and plot headings.
- One `glmmTMB` fit of `dyads_ild` end to end. The NB2 example data give singular
  dyad-occasion fits, so do not use them here.

## 7. Validation (after implementation, once)

The [study script](simulation-studies/ild-partner-dependence/run.R) uses 500
datasets per cell and 1,000 reference simulations per fit. It checks female-male
dyads with `role = gender`, model-centred unless stated. All models include role
intercepts and actor/partner predictors that vary between and within members.

| Part | Data and fitted models | Cells |
|---|---|---|
| Gaussian | Stable SDs 1, 1, correlation 0.4; occasion SDs 1.2, 0.8, correlation 0.3. Fit the correct model, omit either covariance, or impose equal occasion variances. | 50/200 dyads × 3/5/14 occasions × 0/20% missing |
| Serial dependence | Equal occasion variances from a dyad-day block plus independent member AR(1) components, with φ = 0 or 0.7. Fit without AR, without AR plus equal occasion variances, and with AR at φ = 0.7. | 50/200 dyads × 14 occasions × φ = 0/0.7 |
| Poisson | Log link with stable and occasion covariance blocks. Fit the correct model and omit either covariance. | 50/200 dyads × 5/14 occasions |
| Ordinal | Four categories, probit link, stable covariance and a shared dyad-day intercept. Fit the correct model, omit the day intercept, or omit stable covariance. | As Poisson |
| Zero covariance | Gaussian, Poisson and ordinal settings with either stable or occasion covariance truly zero. Fit the full model and the matching restriction. | Gaussian/Poisson: 50/200 dyads × 5/14 occasions; ordinal: 50/200 dyads × 14 occasions; two zero-covariance settings |
| Lagged outcomes | Gaussian and NB2 models with own/partner lags, checked raw and model-centred. These are practical sensitivity analyses, not clean calibration controls. | 50/200 dyads × 14 occasions |

Missing occasions are removed independently per member, so some retained
occasions have no partner. Between means still use every retained occasion.
Response-scale partner correlations are estimated from large generated samples;
latent correlations alone do not describe the size of generalized-response misfit.

Omitted occasion covariance should affect within partner correlation; omitted
stable covariance should affect between partner correlation. Check both levels
for each restriction, since misfits can affect the other level too. The
equal-variance rows assess variance restrictions, and the φ = 0 control separates
their ordinary false alarms from the effect of omitted serial dependence.
Zero-covariance cells assess false alarms where the tested restriction is true.
Freely estimated summaries may flag much less than 5%.

There are 48 cells and 126 fitted models per repetition (63,000 fits in the full
run). The report separates per-statistic flags from flags anywhere in a between figure,
within figure, or either figure. The report uses rank limits based on ordered simulated
values, retaining the earlier quantile rule as a sensitivity comparison, and gives 95% Wilson
intervals, Monte Carlo SEs and denominators. It compares all available checks with
usable fits, which require optimizer convergence, a positive-definite Hessian and
a finite log-likelihood. Gaussian models use BFGS; other families use `nlminb`.
Fits are not retried, and optimizer warnings and failures stay recorded. The full
ordinal model can reach a boundary when the true day-intercept variance is zero.
Parameter recovery is reported only for correctly specified models,
apart from flag rates; lagged-outcome models are excluded from recovery claims.

Reference simulations keep fitted parameters and predictor values fixed and do
not refit models. The study estimates flag rates in these settings, not universal
calibration. A short pilot checks the workflow before the full run. Run from a
fixed checkout, save source/version information, and resume only matching
checkpoints. See the [run instructions](simulation-studies/README.md#longitudinal-partner-dependence-checks)
and [report](../../vignettes/articles/ild-partner-dependence.Rmd).

## 8. Evidence and review log

These entries record early exploratory checks. The completed study is described
in §7 and the linked report.

Demo on the female-male dyads of `dyads_ild` (120 dyads, 14 days, Gaussian, 500
simulations, model-centred). "ok" means inside the middle 95%:

| Fitted model | Between cor | Within cor | Own lag-1 cor (next PR) |
|---|---|---|---|
| Stable + same-day covariance, no AR | ok | ok | 0.05, band [-0.12, -0.04] |
| Same-day covariance omitted | ok | 0.22, band [-0.05, 0.05] | 0.05, band [-0.12, -0.04] |
| Stable + same-day covariance + AR(1) | ok | ok | ok |

Design review: calling `prepare_partner_pairs()` again on dyad × time keys breaks
its minimum and missing-value rules. It also lets a composition disappear
silently. This led to joining on `time` (§4). The two positional test calls were
adopted as well. Its suggested two-line headings and level-aware wording were
later replaced by level suffixes in the labels, which leave print and plot
unchanged. Memory is fine at 100,000
rows, so no caveat is needed.

Generalized review:
- It found limits 2 to 4, from experiments. Examples:
  - With lags in raw mode, Gaussian between-SD rows flagged in 100% of datasets.
  - With lags in model-centred mode, NB2 SD rows flagged in 15–33%.
  - For ordinal responses at 150 dyads, the within correlation flagged in 39 of 40
    datasets.
- It also found that most NB2, beta and ordinal fits with dyad-occasion blocks
  failed convergence checks. This shaped §7.
- Held up:
  - Model-centring stays fair under correct Poisson, zero-inflated Poisson and
    NB2 models (0–8% flags).
  - `simulate_dyad_responses()` redraws `ar1`, `ou`, `cs`, `toep` and similar
    terms, as well as random slopes.

Statistics review:
- Held up under Monte Carlo:
  - The moment table in §2 matches simulations to within 0.007.
  - The check is calibrated under correct models, even with T = 3 and heavy
    unbalanced missingness (0–8% flags).
  - Pinned rows stay at 0–1%.
- Its two major findings are limits 1 and 2 in §3, which went into the help.
- Minor findings that were not adopted, to keep the PR small:
  - Shared per-occasion fixed effects bias within restriction rows when there
    are very few dyads (19% flags at 10 dyads).
  - Unpaired occasions shrink the within-correlation target, identically in
    the simulations.
  - A composition whose within deviations are all zero stops the whole check.
    This happens, for example, when every member has only one occasion.
  - Candidates: a validation cell for the first; for the third, an optional rule
    counting only dyads whose members have at least two occasions.
- Validation (§7) should add T = 3, report flag rates at the other level for
  every misfit, and include a cell with AR in the data but not fitted, under a
  true restriction.

The prototype from 2026-09-19 in the `dyadMLM-ild-checks` worktree predates the
composition refactor. Port its tests, not its code.

## References

Bakdash, J. Z., & Marusich, L. R. (2017). Repeated measures correlation.
*Frontiers in Psychology, 8*, 456. https://doi.org/10.3389/fpsyg.2017.00456

Bland, J. M., & Altman, D. G. (1995). Calculating correlation coefficients with
repeated observations: Part 1—Correlation within subjects. *BMJ, 310*, 446.
https://doi.org/10.1136/bmj.310.6977.446
