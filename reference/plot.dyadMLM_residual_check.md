# Read residual check plots

How to read the pages drawn by
[`check_dyad_residuals()`](https://pascal-kueng.github.io/dyadMLM/reference/check_dyad_residuals.md)
and how to follow up flags.
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) redraws a check
saved with `plot = FALSE`.

## Usage

``` r
# S3 method for class 'dyadMLM_residual_check'
plot(x, ask = NULL, panels = TRUE, ...)
```

## Arguments

- x:

  A result from
  [`check_dyad_residuals()`](https://pascal-kueng.github.io/dyadMLM/reference/check_dyad_residuals.md).

- ask:

  Whether to pause between figures on an interactive device. `NULL`
  (default) pauses when there is more than one figure, `TRUE` pauses and
  `FALSE` draws without pausing. File devices never pause.

- panels:

  If `TRUE` (default), arrange checks in figures by composition, with
  one column per role or a pooled column. If `FALSE`, draw each check
  and role separately.

- ...:

  Unused.

## Value

`x`, invisibly.

## Residual check pages

For each composition, the first page shows uniform QQ and PIT quartiles
against predicted outcomes, like DHARMa's main plot. The second shows
mean PIT distance. Each supplied predictor gets a page of PIT quartiles.

PIT (probability integral transform) residuals rank each outcome from 0
(low) to 1 (high) relative to its own simulated values. A suitable model
should produce ranks roughly evenly spread between 0 and 1, allowing for
the variation shown in blue. PIT distance is `2 * abs(PIT - 0.5)`. Blue
envelopes are global: they are built so that the whole red curve of a
correct model stays inside in a nominal 95% of datasets. This holds
within each panel, not across roles, predictors, or pages. Because the
model was fitted to these same data, departures often look smaller than
they are, as in the settings studied by Robins et al. (2000) and in our
simulations.

Predicted outcomes and numeric predictors with more than eight distinct
values are grouped into up to eight bins per role, with at least about
20 observations per bin. As in DHARMa, these axes show ranks. Tick
labels give the original values at the minimum, quartiles and maximum.
Grey points show the observed PIT residuals. With four or more bins, PIT
quartiles are smoothed across neighboring bins, using distances on the
original scale. `quartile_lines = "qgam"` in
[`check_dyad_residuals()`](https://pascal-kueng.github.io/dyadMLM/reference/check_dyad_residuals.md)
replaces these smoothed quartiles with qgam lines. Because simulated
datasets reuse the qgam tuning of the observed data, the 95% coverage of
these envelopes is approximate. Categories, and predicted outcomes or
numeric predictors with up to eight distinct values, get a box per
value, as in DHARMa: a red box spans the observed 25th to 75th
percentile, with the median in bold. Red points mark each observed
quartile on its own blue range (25th left, median centre, 75th right).
Flags come from these points, not from the box lines. All PIT quartile
panels show full-model residuals, not partial effects. Bins and separate
predictors can hide local patterns and interactions.

## Views and compositions

Start with everyone pooled (`role = NULL`), then also inspect meaningful
roles, such as gender, even when the model treats partners as
exchangeable: role-specific problems show only there. Use `predictors`
of
[`check_dyad_residuals()`](https://pascal-kueng.github.io/dyadMLM/reference/check_dyad_residuals.md)
to examine other measured characteristics. For separate plots and
summaries by a person-level categorical characteristic, use that
variable as `role`.

Each composition gets one pooled column for same-role partners, or
separate columns for distinct roles. Supplying roles does not change the
model's assumptions. Observations whose composition or role is unknown,
for example because the partner's row is missing and `data` was not
supplied, are omitted with a warning.

## Reading flags

A flag is a red curve or point outside its blue envelope or range, or a
red line outside its dashed limits. Each panel alone rarely flags a
correct model, but flags add up across panels, roles, and predictor
pages, so look for a consistent pattern, not any single flag. The
[simulation
study](https://pascal-kueng.github.io/dyadMLM/articles/distribution-checks.html)
reports how often correct and mismatched models were flagged.

With about 40 dyads, most mismatches studied were hard to detect, so the
absence of flags does not show a good fit. Panels suggest possible
problems, not their cause. Neither a flag nor its absence shows whether
estimates or standard errors are wrong. After a flag, fit the model the
pattern suggests and compare the estimates and standard errors you
report. Mismatches showed mainly in these panels of both checks:

- Poisson fitted to overdispersed counts: mean PIT distance, number of
  zeros, QQ.

- Extra zeros: QQ and PIT quartiles (the number of zeros less often).

- Omitted role means: QQ and PIT quartiles across predicted outcomes, by
  role.

- Different role SDs: response SD and mean PIT distance, by role.

- Spread rising with a predictor: largest absolute deviation, mean PIT
  distance, QQ, and PIT quartiles across that predictor.

- Omitted partner effect: PIT quartiles across the partner's predictor
  (supply it in `predictors` of
  [`check_dyad_residuals()`](https://pascal-kueng.github.io/dyadMLM/reference/check_dyad_residuals.md)).

## References

Robins, J. M., van der Vaart, A., & Ventura, V. (2000). Asymptotic
distribution of P values in composite null models. *Journal of the
American Statistical Association, 95*(452), 1143–1156.
[doi:10.1080/01621459.2000.10474310](https://doi.org/10.1080/01621459.2000.10474310)

## See also

[`check_dyad_residuals()`](https://pascal-kueng.github.io/dyadMLM/reference/check_dyad_residuals.md),
[`plot.dyadMLM_outcome_check()`](https://pascal-kueng.github.io/dyadMLM/reference/plot.dyadMLM_outcome_check.md)
