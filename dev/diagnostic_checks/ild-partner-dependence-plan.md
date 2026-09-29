# ILD partner-dependence check: plan

Status: implemented as planned in §4, 2026-09-29; validation (§7) is pending.
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
   both levels must be read together. Examples:
   - Unequal occasion variances under an equal-variance model flagged the
     between role-difference correlation in 81% of datasets at T = 3 and 21% at
     T = 14.
   - Omitting only the stable covariance of a Poisson model flagged the within
     partner correlation in 79% of datasets.
2. **Serial dependence (AR) is not checked.** A model without AR still matches
   the rows its free parameters pin (demo, §8). But the simulations then vary too
   little, so within rows tied to restrictions flag too often (11–13% at
   `phi = 0.5`). Lags come in the next PR.
3. If the model includes lagged values of the outcome as predictors, these
   checks may not be valid.
4. **Ordinal and beta responses:** with two observations per dyad and occasion,
   same-occasion effects are poorly estimated. Within rows can then flag even when
   the model form is right.
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
- a check that each member keeps one role;
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

One script, lean grid, 200 datasets and 500 reference simulations per condition:

- **Gaussian:** fit the correct model, and models omitting the same-occasion
  covariance, the stable covariance, or AR. Add an equal-variance model when
  occasion variances differ. Use 50 and 200 dyads, and 3, 5 and 14 occasions,
  with and without 20% missing occasions. Include AR in the data but not in the
  model under a true restriction, to confirm limit 2.
- **Poisson or NB2, and ordinal:** fit the correct model, and models omitting the
  same-occasion covariance or the stable covariance. Set effect sizes on the
  response scale.
- **Lagged outcome** (Gaussian and NB2, raw and model-centred): confirm limit 3.
- **Report:**
  - flag rates per row at both levels for every misfit, and how often any figure
    flags;
  - all fits, with converged fits shown separately;
  - latent-parameter recovery, kept apart from check calibration.

## 8. Evidence and review log

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
