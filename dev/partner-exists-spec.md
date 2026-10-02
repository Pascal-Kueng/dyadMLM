# Spec: people observed without their partner

Status: agreed design for version 1, not yet implemented. Work happens on
`mixed-dyad-vignette` in separate commits, each with its own help and tests:
(A) print line, error message and help for current behavior, without
mentioning `partner_exists`; (B) version 1 below; (C) `I()` support in
`recover_exchangeable_covariance()`; (D) vignette, rendered.

## In short

`prepare_dyad_data()` gets two optional arguments:

- `partner_exists`: whether a partner existed at each occasion.
- `partner_role`: the role of a partner who has no rows anywhere in the data.

`recover_exchangeable_covariance()` learns to read summed indicators such as
`I(a + b)`.

Without the new arguments, nothing changes: a partner seen once is assumed to
exist at every observed occasion of the dyad, and one-person dyads stop with an
error or are dropped (`incomplete_dyads`).

## Terms

Two terms are used in help, messages, and vignette:

- **No partner**: no partner existed at that occasion (single, before a
  relationship, after a separation or death). Partner predictors use two-part
  coding: they are 0, and `.partner_exists = 0` marks these rows.
- **Partner not in the data**: a partner exists but has no data, at one
  occasion or never. Partner predictors are `NA` wherever the partner's value is
  unknown. Models with these predictors leave those rows out (listwise
  deletion, not a missing-at-random method).

Labels:

- `singleton_<role>`: a person in a one-person dyad who never has a partner
  (`singleton` without `role`).
- `<role>_x_unknown`: a person in a one-person dyad whose partner exists but
  whose role is unknown. Own role first, e.g. `male_x_unknown`.

## Arguments

`partner_exists = NULL`: `TRUE`, `FALSE`, or a column with TRUE/FALSE or 1/0.

| Value | Meaning |
|---|---|
| `NULL` (default) | Current behavior. One-person dyads go to `incomplete_dyads`. |
| `TRUE` | All people observed alone have a partner who is not in the data. |
| `FALSE` | All people observed alone have no partner. |
| column | Row by row, for status that differs between people or over time. |

- A scalar only describes one-person dyads (one person across the whole
  dataset). People whose partner appears in the data are partnered unless a
  column says otherwise. A missed occasion is never read as "no partner".
- `NA` is an error (E2).
- If both members have a row at the same occasion, their values must agree
  (E3). Both `FALSE` is allowed (e.g., former partners who both keep taking
  part after a separation). `FALSE` for one member is allowed when the other
  has no row at that occasion.
- `incomplete_dyads` only applies when `partner_exists` is `NULL`;
  `incomplete_dyads = "drop"` with `partner_exists` is an error (E4).

`partner_role = NULL`: a column with the role of a partner who has no rows
anywhere in the data.

- Read only for one-person dyads, on rows where `partner_exists` is `TRUE`.
- Values given must be the same within a dyad (E7). If all are `NA`, the person
  becomes `<role>_x_unknown`.
- Same rules as `role` (not empty, no `_x_`). `"unknown"` and `"NA"` are
  reserved, for `role` as well (E10; a validation change noted in NEWS).
  Requires `role` (E6).
- A composition may consist only of people observed alone. It supports fixed
  effects and marginal variances, and can share covariance parameters with
  another composition through added indicators. Whether a partner covariance
  is identified is checked in the fitted model, not in preparation; `print()`
  shows such compositions with their counts.
- It only places the person in a composition; it says nothing about the
  partner correlation.

Without `role`, a person whose partner is not in the data joins the only
composition; a person with no partner becomes `singleton`.

## What each person gets

| Situation | Composition | Partner predictors | `.partner_exists` |
|---|---|---|---|
| Both observed | e.g. `female_x_male` | partner's values | 1 |
| Partner missed this occasion | unchanged | raw, cwp, gmc `NA`; cbp and lag partner's value if available | 1 |
| No partner at this occasion (in a dyad) | unchanged | contemporaneous 0; lagged follow status at t-1 | 0 |
| Singleton | `singleton_<role>` | 0 | 0 |
| Partner never in data, role given | real composition | `NA` (0 where `FALSE`) | 1 (0 where `FALSE`) |
| Partner never in data, role unknown | `<role>_x_unknown` | `NA` (0 where `FALSE`) | 1 (0 where `FALSE`) |

The composition stays fixed per dyad. A person who loses their partner keeps
their composition; only the no-partner occasions change.

## Generated columns

- Indicators: `.is_singleton_female`, `.is_male_x_unknown` (or `.is_singleton`).
- Member contrasts: none for singletons and `_x_unknown`. People placed in an
  exchangeable composition get ±1 (also in distinguishable ones with
  `include_arbitrary_member_contrast = TRUE`), assigned after complete dyads so
  seeded contrasts of complete dyads do not change.
- Two-part coding: all numeric APIM partner columns (raw, gmc, cwp, cbp, lag1).
  Centering first, over all observed rows including singletons; then 0 where
  no partner existed. Non-numeric partner predictors stay `NA` there, with one
  warning recommending numeric coding.
- Lagged partner columns: 0 where no partner existed at t-1; otherwise the
  partner's t-1 value (also when the partner has no row at t); `NA` if neither
  member has a row at t-1.
- `.partner_exists`: created whenever `partner_exists` is supplied (constant
  with `TRUE`; users leave it out then).
- `.partner_exists_lag1`: with `lag1_predictors`. The dyad's status at t-1,
  from whichever member has a row then; `NA` if neither has a row.
- Short column names: singleton and `_x_unknown` groups do not count toward
  the one-composition rule (e.g., `.is_female`, `.is_male` stay next to
  `.is_singleton_male`).

## Interplay and edge cases

- `keep_compositions` accepts `"singleton_male"`, `"male_x_unknown"` (also
  `-` or space). People placed via `partner_role` belong to their composition;
  if it is removed, they are removed and counted in `print()`.
- `pool_compositions` and `set_exchangeable_compositions` reject singleton and
  `_x_unknown` labels (E8). Sharing works by adding indicators in the formula.
- DIM/DSM cannot be combined with `partner_exists` (E9).
- `missing_role` applies as before; people observed alone dropped this way are
  counted in `print()`.
- The existing minimum of two dyad IDs stays; one-person dyads count.
- One dyad per person; re-partnering is not supported.
- Both members `FALSE` in a cross-sectional complete dyad is allowed.

## Errors

- **E1** (one-person dyads, `partner_exists = NULL`):
  > Found 12 dyads with only one person (e.g., 104, 117, … and 10 more).
  > • If all of them have no partner, use `partner_exists = FALSE`.
  > • If all of them have a partner who is not in the data, use `partner_exists = TRUE` (with `role`, add `partner_role` to place them in their composition).
  > • If this differs between people or over time, supply `partner_exists` as a TRUE/FALSE column.
  > • To remove them, use `incomplete_dyads = "drop"`.
  > See `vignette("mixed-apim")`.
- **E2**: `partner_exists` is missing in 8 rows (dyads 104, 117, …). Use TRUE or FALSE in every row; missing values are not read as "no partner". Placeholder rows without data (e.g., after a death) can be removed.
- **E3**: `partner_exists` differs between the two members at the same occasion in 4 rows (dyad 12, times 3–4; …). Both members must agree on whether they are partners at that occasion.
- **E4**: `incomplete_dyads = "drop"` cannot be combined with `partner_exists`. Remove those dyads beforehand, or use `partner_exists` to keep them.
- **E5**: `partner_exists` must be `TRUE`, `FALSE`, or a column with TRUE/FALSE or 1/0 values.
- **E6**: `partner_role` requires `role`.
- **E7**: `partner_role` differs within 2 dyads (104, 117). A new partner needs a new dyad ID.
- **E8**: `pool_compositions` cannot include singleton_male or male_x_unknown. To let them share parameters with dyad members, add their indicators in the formula, e.g. `I(.is_female_x_male_male + .is_male_x_unknown)`. See `vignette("mixed-apim")`. (Same for `set_exchangeable_compositions`.)
- **E9**: `partner_exists` cannot be used with DIM or DSM columns yet.
- **E10**: `role` and `partner_role` must not use the values "unknown" or "NA".
- **E11** (missing dyad IDs): in A: `dyad` is missing in 70 rows. Give each person observed alone their own dyad ID; see `incomplete_dyads`. B adds: "then see `partner_exists`".

## Print

```
# People observed alone: 21 without a partner, 10 with a partner not in the data (4 with unknown partner role)
# Dyad-occasions with one member observed: 230 of 2,520 (treated as missing partner data)
```

- First line when one-person dyads are kept. Second line in longitudinal data;
  with a `partner_exists` column: "… (180 without a partner; 50 treated as
  missing)". Neutral style.
- The compositions table includes the new groups; `summary()` follows.

## `recover_exchangeable_covariance()`

- Automatic matching also recognizes summed terms such as
  `I(.is_male_x_male + .is_singleton_male)` and
  `I(.member_contrast_male_x_male_arbitrary + .is_singleton_male)`, and their
  ordinary interactions such as `I(a + b):time`.
- Each whole expression is matched, because shared and contrast terms can
  contain the same singleton indicator. The fitted values of these columns are
  validated like the existing indicator columns.
- Added indicators are read as additional groups sharing the variance; the
  covariance calculation is unchanged. `block_pairings` accepts these terms and
  remains the way to resolve ambiguous cases.
- Warning when an added indicator appears in only one term of a shared/contrast
  pair, e.g.: "`.is_singleton_male` appears in the shared term but not in the
  contrast term, so singletons get variance a, not a + b. Add it to both terms
  to share the dyad members' variance."
- Docs framing: pooling treats a singleton like one member of the exchangeable
  dyad (shared = 1, contrast = +1); the sign does not matter because the two
  terms are independent.

## Documentation

- `prepare_dyad_data()`: `@param partner_exists`, `@param partner_role`;
  `incomplete_dyads` points to `partner_exists`.
- Details section "People observed without their partner": terms, rules,
  table; "a partner seen once is assumed to exist at every observed occasion";
  `filter()` recipe for removing occasions; listwise deletion of rows with
  missing partner predictors; one dyad per person.
- Interpretation notes:
  - Singleton indicators are enough only if no-partner occasions occur in
    singletons only. Otherwise include `.partner_exists` (and
    `.partner_exists_lag1` with lags).
  - What 0 means depends on the component, and `.partner_exists` compares
    against it: cwp 0 is the partner at their own mean; cbp 0 is a partner
    whose person mean equals the mean of person means; gmc 0 is the grand
    mean. These references include singletons.
  - With changing status, zeroing makes partner components status-dependent:
    cwp no longer averages 0 and cbp is no longer constant within a person.
  - `.partner_exists` mixes change over time and differences between people.
  - The +1 on the contrast column is valid only because shared and contrast
    terms are separate random-effect terms.
- NEWS: new arguments, print lines, `I()` support, clearer missing-dyad-ID
  message, and `"unknown"`/`"NA"` no longer accepted as role values.

## Vignette (`vignettes/mixed-apim.Rmd`)

- Definitions: no partner vs. partner not in the data.
- Replace the manual construction with `prepare_dyad_data(..., partner_exists = ...)`.
- Fixes from review: keep the seed for "Separate actor slopes", but show SEs or
  CIs and state that the difference (about 2 SE) is due to chance; recovery
  claims belong to the simulation study. `| coupleID` instead of `| personID`
  for singleton terms; note on partners not in the data in the
  `is_solo * x_actor_c` sentence; consistent wording on the partner
  correlation under pooling.
- Sharing parameters by adding indicators, including both exchangeable terms.
- Small partner-loss example (one person, partnered → no partner), no model.
- Partners not in the data: listwise deletion in models with partner
  predictors; compare results with and without them.

## Examples

### Sharing parameters: add indicators

```r
# One male intercept for men in female-male couples, men with unknown partner role, and singleton men
I(.is_female_x_male_male + .is_male_x_unknown + .is_singleton_male)

# Distinguishable block: these men share the male variance
us(0 + .is_female_x_male_female + I(.is_female_x_male_male + .is_male_x_unknown) | coupleID)

# Exchangeable block: add to the shared AND the contrast term (separate terms)
us(0 + I(.is_male_x_male + .is_singleton_male) | coupleID) +
us(0 + I(.member_contrast_male_x_male_arbitrary + .is_singleton_male) | coupleID)
```

### 1. Diary study, female–male couples

21 days, missed days common, singles from intake as comparison group, some
partners never took part. `status` recorded once at intake.

```r
diary <- diary |>
  mutate(
    partnered = status == "partnered",
    partner_gender = if_else(gender == "female", "male", "female")
  )

prep <- prepare_dyad_data(
  diary, dyad = coupleID, member = personID, role = gender, time = day,
  predictors = support,
  partner_exists = partnered, partner_role = partner_gender, seed = 1
)
```

Couples get `.is_female` / `.is_male` (one composition). Missed days are
missing partner data. People whose partner never took part join the couples
with `NA` partner predictors. Singles get `.is_singleton_female` /
`.is_singleton_male` with partner predictors 0.

```r
closeness ~ 0 + .is_female + .is_male + .is_singleton_female + .is_singleton_male +
  .support_cwp_actor + .support_cwp_partner + .support_cbp_actor + .support_cbp_partner +
  us(0 + I(.is_female + .is_singleton_female) + I(.is_male + .is_singleton_male) | coupleID) +
  us(0 + I(.is_female + .is_singleton_female) + I(.is_male + .is_singleton_male) | coupleID:day),
family = gaussian(), dispformula = ~ 0
```

`dispformula = ~ 0` lets the occasion-level terms take the residual variance.

Status is fixed at intake, so no-partner occasions only occur in singletons and
the singleton indicators suffice. People whose partner never took part drop out
of this model; in actor-only models they stay.

### 2. Diary study, several compositions

Same call. `partner_gender` from intake, missing for a few people:

- Known: the person joins their composition (±1 contrast in `male_x_male`).
- Unknown: `male_x_unknown` / `female_x_unknown`, with own parameters or shared
  by adding indicators.
- Singles: `singleton_<role>`.

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

| wave | `partner_alive` | husband's row | `.health_partner` | `.health_partner_lag1` | `.partner_exists` | `.partner_exists_lag1` |
|---|---|---|---|---|---|---|
| 3 | TRUE | yes | his w3 | his w2 | 1 | 1 |
| 4 | TRUE | no | `NA` | his w3 | 1 | 1 |
| 5 | FALSE | no | 0 | `NA` (he skipped w4) | 0 | 1 |
| 6 | FALSE | no | 0 | 0 | 0 | 0 |

Wave 5 is the first wave after the death (`.partner_exists = 0`,
`.partner_exists_lag1 = 1`). Had he answered in wave 4, the wave-5 lag would
hold his last value.

```r
wellbeing ~ 1 + .partner_exists + .partner_exists_lag1 +
  .health_cwp_actor + .health_cwp_partner + .health_partner_lag1 + ...
```

Placeholder rows for the deceased trigger E2 and are removed beforehand.
Re-partnering is not supported.

### 4. Three waves, several compositions, separations

Waves 1–3; female–male, female–female, male–male; same-sex couples pooled.
Some partners never took part (gender known). Some couples separate and both
may keep taking part; `together` per wave. Grand-mean centering because of
three waves.

```r
prep <- prepare_dyad_data(
  couples3, dyad = coupleID, member = personID, role = gender, time = wave,
  predictors = conflict, lag1_predictors = conflict,
  temporal_decomposition = "none", add_apim_gmc_predictors = TRUE,
  pool_compositions = list(same_sex = c("female-female", "male-male")),
  partner_exists = together, partner_role = partner_gender, seed = 1
)
```

- People whose partner never took part are placed in `female_x_male` or
  `same_sex`; pooling applies to them as to everyone.
- Separation after wave 2: both have `together = FALSE` at wave 3, both rows
  stay; contemporaneous partner predictors 0, `.partner_exists = 0`;
  `.conflict_gmc_partner_lag1` still holds the former partner's wave-2 value.
- One `TRUE`, the other `FALSE`: E3.

```r
conflict ~ 0 + .is_female_x_male_female + .is_female_x_male_male + .is_same_sex +
  .partner_exists + .partner_exists_lag1 +
  .conflict_gmc_actor_lag1 + .conflict_gmc_partner_lag1 + ...
```

`.partner_exists` is required here because no-partner occasions occur inside
dyads. If people with no partner on every row exist, add their
`.is_singleton_*` indicators. With lags, wave 1 drops out.

## Tests

- `partner_exists`: `NULL`, `TRUE`, `FALSE`; columns (one-person dyads all
  `TRUE` / all `FALSE` / mixed; occasions inside dyads; both members `FALSE`);
  E3 on disagreement.
- `partner_role`: given, `NA` → `_x_unknown`, exchangeable target, a
  composition with only people observed alone, without `role`,
  `include_arbitrary_member_contrast`.
- E1–E11.
- Zeroing after centering for raw, gmc, cwp, cbp, lag1; non-numeric warning;
  `.partner_exists_lag1` incl. death and separation; temporary rows ignored in
  checks; label order independent of locale.
- Seeded contrasts of complete dyads unchanged; short column names unchanged.
- `keep_compositions` with new labels and removed compositions.
- Print and summary counts.
- `recover_exchangeable_covariance()`: `I()` sums with and without slopes; the
  same indicator in shared and contrast terms; `block_pairings`; warning when an indicator is in only one term of a pair.
- Cross-checks: same fit as the vignette's manual construction; `partner_role`
  vs. manually added partner rows give identical columns.

## Not included (can be added later without breaking changes)

- Unknown partnership status (`NA` → its own group).
- Placement through a `join_compositions`-type argument.
- Re-partnering in panels.
- DIM/DSM with `partner_exists`.
- Diagnostics for singletons (#82).
- Warning for all-missing lag columns (#83).
