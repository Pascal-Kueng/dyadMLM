# Spec: people observed without their partner

Status: agreed design for version 1, not yet implemented. Work happens on
`mixed-dyad-vignette` in separate commits, each with its own help and tests:
(A) print line, error message and help for current behavior (they may
already refer to `partner_exists`, since nothing is merged before B); (B) version 1 below; (C) `I()` support in
`recover_exchangeable_covariance()`; (D) vignette, rendered; plus a small
commit for #83 (warning for all-missing lag columns).

## In short

`prepare_dyad_data()` gets one optional argument, `partner_exists`: whether a
partner existed at each occasion. `recover_exchangeable_covariance()` learns to
read summed indicators such as `I(a + b)`.

Without the new argument, nothing changes: a partner seen once is assumed to
exist at every observed occasion of the dyad, and one-person dyads stop with an
error or are dropped (`incomplete_dyads`).

Principle: every kind of person observed alone forms its own group with its
own indicator. Groups are separate by default; parameters are shared by adding
indicators in the model formula. The package never places anyone in a
composition they were not observed in.

Use recorded status (e.g., relationship status, widowhood), not data presence.
Building `partner_exists` from the number of rows per dyad (`n() == 2`) mixes
people without a partner with people whose partner did not take part.

## Terms

Two terms are used in help, messages, and vignette:

- **No partner**: no partner existed at that occasion (single, before a
  relationship, after a separation or death). Partner predictors use two-part
  coding: they are 0, and `.partner_exists = 0` marks these rows.
- **Partner not in the data**: a partner exists but has no data, at one
  occasion or never. Partner predictors are `NA` wherever the partner's value is
  unknown. Models with these predictors leave those rows out (listwise
  deletion). These rows can enter models that omit the unavailable
  predictors. A person whose partner never appears can still contribute rows
  to partner-predictor models: rows where the needed partner predictors are
  structural zeros (no partner at t, or for lags no partner at t-1).

Labels for one-person dyads (own role first):

| Person observed alone | Label | Indicator |
|---|---|---|
| No partner | `singleton_male` | `.is_singleton_male` |
| Partner not in data | `male_x_missing` | `.is_male_x_missing` |
| Without `role`: no partner | `singleton` | `.is_singleton` |
| Without `role`: partner not in data | `missing_partner` | `.is_missing_partner` |

Complete couples keep their alphabetically sorted labels (`female_x_male`); the
help states both naming rules next to the table.

## Argument

`partner_exists = NULL`: `TRUE`, `FALSE`, or a column with TRUE/FALSE or 1/0.

| Value | Meaning |
|---|---|
| `NULL` (default) | Current behavior. One-person dyads go to `incomplete_dyads`. |
| `TRUE` | All people observed alone have a partner who is not in the data. |
| `FALSE` | All people observed alone have no partner. |
| column | Row by row, for status that differs between people or over time. |

- A scalar only describes people observed alone (one-person dyads across the
  whole dataset). People whose partner appears in the data are partnered unless
  a column says otherwise. A missed occasion is never read as "no partner".
- `NA` is an error (E2).
- If both members have a row at the same occasion, their values must agree
  (E3). Both `FALSE` is allowed (e.g., former partners who both keep taking
  part after a separation). `FALSE` for one member is allowed when the other
  has no row at that occasion.
- `incomplete_dyads` only applies when `partner_exists` is `NULL`;
  `incomplete_dyads = "drop"` with `partner_exists` is an error (E4).
- A one-person dyad with `FALSE` on every row is a singleton. With `TRUE` on
  any row, it is `<role>_x_missing`; its `FALSE` rows get two-part coding.
- `FALSE` followed by `TRUE` is a partnership forming and needs no message.
  `TRUE`, then `FALSE`, then `TRUE` again within a dyad is read as the same
  partner returning (message M1). Re-partnering with a new partner is not
  supported: a new dyad ID would put the person in two dyads.
- The role value `"missing"` is reserved (E8; a validation change noted in
  NEWS).

## What each person gets

| Situation | Composition | Partner predictors | `.partner_exists` |
|---|---|---|---|
| Both observed | e.g. `female_x_male` | partner's values | 1 |
| Partner missed this occasion | unchanged | raw, cwp, gmc `NA`; cbp and lag partner's value if available | 1 |
| No partner at this occasion (in a dyad) | unchanged | contemporaneous 0; lagged follow status at t-1 | 0 |
| Singleton | `singleton_<role>` | 0 | 0 |
| Partner never in data | `<role>_x_missing` | `NA` (0 where `FALSE`) | 1 (0 where `FALSE`) |

The composition stays fixed per dyad. A person who loses their partner keeps
their composition; only the no-partner occasions change.

## Generated columns

- Indicators as in the label table.
- Member contrasts: none for people observed alone. Seeded contrasts of
  complete dyads do not change.
- Two-part coding: all numeric APIM partner columns (raw, gmc, cwp, cbp, lag1).
  Centering first, over all observed rows including people observed alone;
  then 0 where no partner existed. Non-numeric partner predictors stay `NA`
  there, with one warning recommending numeric coding.
- Lagged partner columns: 0 where no partner existed at t-1; otherwise the
  partner's t-1 value (also when the partner has no row at t); `NA` if neither
  member has a row at t-1.
- `.partner_exists`: created only when it varies (some `TRUE`, some `FALSE`).
- `.partner_exists_lag1`: created with `lag1_predictors` when `.partner_exists`
  exists. The dyad's status at t-1, from whichever member has a row then; `NA`
  if neither has a row. To keep it, add a row for the person at t-1 with valid
  IDs, the recorded status, and missing measures (never a row for an invented
  partner).
- Short column names: groups of people observed alone do not count toward the
  one-composition rule (e.g., `.is_female`, `.is_male` stay next to
  `.is_singleton_male`).

## Interplay and edge cases

- `keep_compositions` accepts the new labels (also with `-` or space).
- `pool_compositions` and `set_exchangeable_compositions` reject them (E6).
  Sharing works by adding indicators in the formula.
- DIM/DSM cannot be combined with `partner_exists` (E7).
- `missing_role` applies as before; people observed alone dropped this way are
  counted in `print()`.
- The existing minimum of two dyad IDs stays; one-person dyads count.
- One dyad per person; re-partnering is not supported.
- Both members `FALSE` in a cross-sectional complete dyad is allowed.

## Errors

- **E1** (one-person dyads, `partner_exists = NULL`):
  > Found 12 dyads with only one person (e.g., 104, 117, … and 10 more). Use recorded status, not the number of rows:
  > • If none of them has a partner, use `partner_exists = FALSE`.
  > • If all of them have a partner who is not in the data, use `partner_exists = TRUE`.
  > • If this differs between people or over time, supply `partner_exists` as a TRUE/FALSE column.
  > • To remove them, use `incomplete_dyads = "drop"`.
  > `TRUE` and `FALSE` only describe people observed alone. See `vignette("mixed-apim")`.
- **E2**: `partner_exists` is missing in 8 rows (dyads 104, 117, …). Use TRUE or FALSE in every row; missing values are not read as "no partner". Placeholder rows without data (e.g., after a death) can be removed.
- **E3**: `partner_exists` differs between the two members at the same occasion in 4 rows (dyad 12, times 3–4; …). Both members must agree on whether they are partners at that occasion. If partners report differently, pick one rule, e.g. FALSE if either reports a separation.
- **E4**: `incomplete_dyads = "drop"` cannot be combined with `partner_exists`. Remove those dyads beforehand, or use `partner_exists` to keep them.
- **E5**: `partner_exists` must be `TRUE`, `FALSE`, or a column with TRUE/FALSE or 1/0 values.
- **E6**: `pool_compositions` cannot include singleton_male or male_x_missing. To let them share parameters with dyad members, add their indicators in the formula, e.g. `I(.is_female_x_male_male + .is_male_x_missing)`. See `vignette("mixed-apim")`. (Same for `set_exchangeable_compositions`.)
- **E7**: `partner_exists` cannot be used with DIM or DSM columns yet.
- **E8**: `role` must not be "missing"; this label is reserved for people whose partner is not in the data.
- **E9** (missing dyad IDs): in A: `dyad` is missing in 70 rows. Give each person observed alone their own dyad ID; see `incomplete_dyads`. B adds: "then see `partner_exists`".

## Messages

- **M1** (TRUE, then FALSE, then TRUE): `partner_exists` returns to TRUE after FALSE in 3 dyads (12, 40, 77). This is treated as the same partner returning. A different, new partner is not supported yet; end the person's data before the new partnership.

## Print

```
# People observed alone: 21 without a partner, 10 with a partner not in the data
# Rows missing at least one generated partner predictor (incl. lags): 410 of 4,812
#   Which rows a model uses depends on its formula; check nobs().
# Dyad-occasions with one member observed: 230 of 2,520 (partners are treated as existing but having missing data at these occasions).
#   If no partner existed at some of these occasions, a different coding is needed: use `partner_exists`.
```

- First line when one-person dyads are kept. The missing-partner-predictor
  line counts rows missing any generated partner predictor, including lagged
  ones; it is a description of the data, not of a model. Last line in
  longitudinal data;
  with a `partner_exists` column: "… (180 without a partner; 50 treated as
  missing)". Neutral style.
- The compositions table lists the new groups with counts; `summary()` follows.

## `recover_exchangeable_covariance()`

- Automatic matching also recognizes summed terms such as
  `I(.is_male_x_male + .is_singleton_male)` and
  `I(.member_contrast_male_x_male_arbitrary + .is_singleton_male)`, and their
  ordinary interactions such as `I(a + b):time`.
- Each whole expression is matched, because shared and contrast terms can
  contain the same added indicator. The fitted values of these columns are
  validated like the existing indicator columns.
- Added indicators are read as additional groups sharing the variance; the
  covariance calculation is unchanged. `block_pairings` accepts these terms
  (and custom summed columns created with `mutate()`) and remains the way to
  resolve ambiguous cases.
- Version 1 supports full sharing only: an added indicator must appear in both
  terms of a shared/contrast pair. If it appears in only one, recovery stops
  with an error (the existing strict validation stays), e.g.:
  "`.is_singleton_male` appears in the shared term but not in the contrast
  term, so singletons would get variance a, not a + b. Add it to both terms to
  share the dyad members' variance." Recovery for partial sharing is deferred.
- Docs framing: pooling treats a person observed alone like one member of the
  exchangeable dyad (shared = 1, contrast = +1). The sign does not matter
  because the two terms are independent; with random slopes, the sign must be
  the same across all coefficients and occasions of that person.

## Documentation

- `prepare_dyad_data()`: `@param partner_exists` (scalars describe people
  observed alone only); `incomplete_dyads` points to `partner_exists`.
- Details section "People observed without their partner": the recorded-status
  rule (bold); terms; label table with both naming rules; "a partner seen once
  is assumed to exist at every observed occasion"; `filter()` recipe for
  removing occasions; listwise deletion of rows with missing partner
  predictors; one dyad per person; the death example table.
- Interpretation notes:
  - Omit a status term only when the intercept indicators already represent
    its variation. Example: if status never changes within a person, the
    singleton indicators already give people without a partner their own
    mean. If no-partner occasions occur inside dyads, include `.partner_exists`
    (and `.partner_exists_lag1` with lags), also next to singleton indicators.
  - `.partner_exists` is a contrast at partner predictors = 0, not "the effect
    of having a partner"; it mixes change over time and differences between
    people.
  - What 0 means depends on the component: cwp 0 is the partner at their own
    mean; cbp 0 is a partner whose person mean equals the mean of person
    means; gmc 0 is the grand mean; raw 0 is the scale's 0 (prefer centered
    components). Adding people observed alone changes the gmc and cbp
    reference averages and thus the meaning of couple coefficients; it does
    not change an existing person's cwp reference (their own mean).
  - With changing status, zeroing makes partner components status-dependent:
    cwp no longer averages 0 and cbp is no longer constant within a person.
  - Sharing parameters: add indicators, in the formula or as summed columns
    with `mutate()`. Fully pooling a `_x_missing` group with a composition gives
    the same model as adding empty partner rows, provided the fitted
    observations, predictors and model constraints are identical. Pooling only
    some parameters lets `compare_nested_models()` test whether these people
    differ.
  - People observed alone supply no observed partner pairs, but sharing
    variance parameters with them can still change the estimated partner
    covariance and correlation.
  - The +1 on the contrast column is valid only because shared and contrast
    terms are separate random-effect terms.
  - Lagged partner columns after a separation hold the former partner's t-1
    value, by design. To set them to 0 instead, use a condition, because
    `0 * NA` stays `NA`: `if_else(.partner_exists == 0, 0, .x_partner_lag1)`.
- NEWS: `partner_exists`, print lines, `I()` support, clearer missing-dyad-ID
  message, the all-missing-lag warning (#83), and `"missing"` no longer
  accepted as a role value.

## Vignette (`vignettes/mixed-apim.Rmd`)

- Definitions: no partner vs. partner not in the data; the label table; the
  recorded-status rule.
- Replace the manual construction with `prepare_dyad_data(..., partner_exists = ...)`.
- Fixes from review: keep the seed for "Separate actor slopes", but show SEs or
  CIs and state that the difference (about 2 SE) is due to chance; recovery
  claims belong to the simulation study. `| coupleID` instead of `| personID`
  for singleton terms; note on partners not in the data in the
  `is_solo * x_actor_c` sentence; consistent wording on the partner
  correlation under pooling.
- Sharing parameters by adding indicators (means, slopes, variances; both
  exchangeable terms), and testing partial pooling.
- Small partner-loss example (one person, partnered → no partner), no model.
- Partners not in the data: listwise deletion in models with partner
  predictors; check `nobs()`; compare results with and without them; pointer to
  multiple imputation; reporting sentence ("n rows from m people had missing
  partner predictors; they were retained for centering and excluded from
  models including those predictors"), with n and m taken from the fitted
  model.
- Panel and lag material is reference-level (help and a short section), not
  the main thread.

## Examples

### Two-part predictors

Wherever partner predictors are 0 for people without a partner, the model
needs a status term that gives these rows their own mean
[@dziakTwoPartPredictors2017]:

- contemporaneous partner predictors pair with `.partner_exists` (or, when
  status never changes within a person, with the singleton indicators);
- lagged partner predictors pair with `.partner_exists_lag1`.

Interpretation: the partner slope is estimated among partnered people only;
the status coefficient compares people with and without a partner when the
partner predictor is at its reference (0 of the centered component). An
interaction such as `.partner_exists:.support_gmc_actor` lets the actor slope
differ by status. Every example below states which pairs it uses.

### Sharing parameters: add indicators

```r
# Means: men in female-male couples and men whose partner is not in the data
0 + I(.is_female_x_male_male + .is_male_x_missing) + ...

# Slopes: one actor slope for both
I(.is_female_x_male_male + .is_male_x_missing):.support_gmc_actor

# Distinguishable block: they share the male variance
us(0 + .is_female_x_male_female + I(.is_female_x_male_male + .is_male_x_missing) | coupleID)

# Exchangeable block: treat singletons like one member of a male-male dyad
# (add to the shared AND the contrast term)
us(0 + I(.is_male_x_male + .is_singleton_male) | coupleID) +
us(0 + I(.member_contrast_male_x_male_arbitrary + .is_singleton_male) | coupleID)
```

People observed alone supply no observed partner pairs. Sharing variance
parameters with them can still change the estimated partner covariance.

### 1. Cross-sectional survey: all compositions, singles, partners who did not answer

```r
survey <- survey |> mutate(partnered = status != "single")

prep <- prepare_dyad_data(
  survey, dyad = coupleID, member = personID, role = gender,
  predictors = support, add_apim_gmc_predictors = TRUE,
  partner_exists = partnered, seed = 1
)
```

Groups: `female_x_male`, `female_x_female`, `male_x_male`,
`singleton_female`, `singleton_male`, `female_x_missing`, `male_x_missing`.

Do singles and partnered people differ in the actor effect? With an intercept,
`.partner_exists` gives singles their own mean, so no singleton indicators:

```r
fit <- glmmTMB(
  satisfaction ~ 1 + .partner_exists * .support_gmc_actor + .support_gmc_partner +
    # residual covariance per composition, as in the mixed-composition APIM
    us(0 + .is_female_x_male_female + .is_female_x_male_male | coupleID) +
    us(0 + .is_female_x_female | coupleID) +
    us(0 + .member_contrast_female_x_female_arbitrary | coupleID) +
    us(0 + .is_male_x_male | coupleID) +
    us(0 + .member_contrast_male_x_male_arbitrary | coupleID) +
    # singles: one residual variance per role
    us(0 + .is_singleton_female | coupleID) + us(0 + .is_singleton_male | coupleID),
  family = gaussian(), dispformula = ~ 0, data = prep
)
nobs(fit)   # rows of people whose partner did not answer are not included
```

Two-part: `.support_gmc_partner` is 0 for singles and pairs with
`.partner_exists`. Its coefficient is the partner effect among partnered
people. `.partner_exists` compares partnered people and singles when both
actor and partner support are at their grand means; away from the actor mean,
the contrast also includes `.partner_exists:.support_gmc_actor`, the
difference in actor slopes. The single intercept for all couples keeps the
focus on singles vs. partnered people. A full analysis would usually use
composition-specific intercepts (`0 + .is_*`); singles then get their own
intercepts from the singleton indicators instead of `.partner_exists`.

People whose partner did not answer have `NA` partner predictors and drop out
of this model. To use them, fit an actor-only model and add `.is_*_x_missing`
to the indicators as needed.

### 2. Diary study, female–male couples, some partners never took part

21 days, missed days common, nobody single.

```r
prep <- prepare_dyad_data(
  diary, dyad = coupleID, member = personID, role = gender, time = day,
  predictors = support, partner_exists = TRUE, seed = 1
)
```

Two-part coding is not needed here: everyone has a partner, so no partner
predictor is set to 0 and `.partner_exists` is not created.

The usual APIM formula stays unchanged. People whose partner never took part
(`.is_female_x_missing`, `.is_male_x_missing`) drop out of it; `print()` says
so. In an actor-only model they can be pooled with their role:
`I(.is_female + .is_female_x_missing)`, also in the `coupleID` and
`coupleID:day` terms.

### 3. Panel study, partners dying

10 yearly waves (`wave` = 1, …, 10). Partners skip waves; some die; `widowed`
per wave.

```r
panel <- panel |> mutate(partner_alive = !widowed)

prep <- prepare_dyad_data(
  panel, dyad = coupleID, member = personID, role = gender, time = wave,
  predictors = health, lag1_predictors = health,
  partner_exists = partner_alive, seed = 1
)
```

Wife; husband skips wave 4 and dies before wave 5:

| wave | `partner_alive` | husband's row | `.health_cwp_partner` | `.health_cwp_partner_lag1` | `.partner_exists` | `.partner_exists_lag1` |
|---|---|---|---|---|---|---|
| 3 | TRUE | yes | his w3 | his w2 | 1 | 1 |
| 4 | TRUE | no | `NA` | his w3 | 1 | 1 |
| 5 | FALSE | no | 0 | `NA` (he skipped w4) | 0 | 1 |
| 6 | FALSE | no | 0 | 0 | 0 | 0 |

Wave 5 is the first wave after the death (`.partner_exists = 0`,
`.partner_exists_lag1 = 1`). Because he skipped wave 4, this wave drops out of
lag models; had he answered, the lag would hold his last value.

```r
wellbeing ~ 1 + .partner_exists + .partner_exists_lag1 +
  .health_cwp_actor + .health_cbp_actor +
  .health_cwp_partner + .health_cbp_partner + .health_cwp_partner_lag1 + ...
```

Two-part: `.health_cwp_partner` and `.health_cbp_partner` are 0 after the
death and pair with `.partner_exists`; `.health_cwp_partner_lag1` pairs with
`.partner_exists_lag1`. `.partner_exists` is the difference between widowed
and partnered waves with the partner's health at its references; it mixes the
change at the death with differences between people.

Placeholder rows for the deceased trigger E2 and are removed beforehand.
Re-partnering is not supported.

### 4. Three waves, several compositions, separations

Waves 1–3; female–male, female–female, male–male; same-sex couples pooled.
Some couples separate after wave 1, others after wave 2; both may keep taking
part; `together` per wave.
Grand-mean centering because of three waves.

```r
prep <- prepare_dyad_data(
  couples3, dyad = coupleID, member = personID, role = gender, time = wave,
  predictors = conflict, lag1_predictors = conflict,
  temporal_decomposition = "none", add_apim_gmc_predictors = TRUE,
  pool_compositions = list(same_sex = c("female-female", "male-male")),
  partner_exists = together, seed = 1
)
```

- Separation after wave 2: both have `together = FALSE` at wave 3, both rows
  stay; contemporaneous partner predictors 0, `.partner_exists = 0`;
  `.conflict_gmc_partner_lag1` still holds the former partner's wave-2 value.
- Separation after wave 1: at wave 3 the lag is 0 and `.partner_exists_lag1 = 0`.
  Without such earlier separations, `.partner_exists_lag1` would be 1 on all
  retained waves (2–3) and duplicate the intercepts; then leave it out.
- One `TRUE`, the other `FALSE`: E3.

```r
conflict ~ 0 + .is_female_x_male_female + .is_female_x_male_male + .is_same_sex +
  .partner_exists + .partner_exists_lag1 +
  .conflict_gmc_actor_lag1 + .conflict_gmc_partner_lag1 + ...
```

Two-part: `.conflict_gmc_partner_lag1` pairs with `.partner_exists_lag1`. At
the first wave after a separation the lag still holds the former partner's
value (`.partner_exists_lag1 = 1`); from the second wave on it is 0
(`.partner_exists_lag1 = 0`). `.partner_exists` captures the contemporaneous
status; add `.conflict_gmc_partner` to it for contemporaneous partner effects.
`.partner_exists` is required because no-partner occasions occur inside dyads.
Rows of people whose partner never took part enter this lag model only where
status at t-1 was "no partner" (structural-zero lag). Retention depends on
status at t-1, not at t: the first no-partner row after a separation can still
have a missing lag, and a newly partnered row can have a structural-zero lag.
With lags, wave 1 drops out.

## Tests

- `partner_exists`: `NULL`, `TRUE`, `FALSE`; columns (one-person dyads all
  `TRUE` / all `FALSE` / mixed; occasions inside dyads; both members `FALSE`);
  E3 on disagreement; M1 on TRUE → FALSE → TRUE, no message on FALSE → TRUE
  (partnership forming).
- Labels: `singleton_*`, `*_x_missing`, no-role labels; own role first
  independent of locale; reserved role value (E8).
- E1–E9.
- `.partner_exists` created only when it varies.
- Zeroing after centering for raw, gmc, cwp, cbp, lag1; non-numeric warning;
  `.partner_exists_lag1` incl. death and separation; temporary rows ignored in
  checks.
- Seeded contrasts of complete dyads unchanged; short column names unchanged.
- `keep_compositions` with the new labels.
- Print and summary counts, including the missing-partner-predictors line.
- `recover_exchangeable_covariance()`: `I()` sums with and without slopes; the
  same indicator in shared and contrast terms; `block_pairings`; error when
  an indicator is in only one term of a pair; opposite signs across separate
  singleton groups cannot substitute for paired information at the requested
  grouping level; existing mappings with genuinely omitted blocks (`NULL`)
  still work.
- #83: warning when a lag column is entirely missing.
- Cross-checks: same fit as the vignette's manual construction; a fully pooled
  `_x_missing` group gives the same fit as manually added empty partner rows
  (same fitted rows and constraints).

## Not included (can be added later without breaking changes)

- `partner_role` (labels such as `male_x_missing_female`); until then, split
  `.is_male_x_missing` in the formula with a user column if needed.
- Unknown partnership status (`NA` → its own group).
- Automatic placement into compositions.
- Re-partnering in panels (a person in several dyads).
- DIM/DSM with `partner_exists`.
- Diagnostics for people observed alone (#82).
