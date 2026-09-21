# Plot a saved partner-dependence check

**\[experimental\]** Draws the comparison plots without repeating
simulations.

## Usage

``` r
# S3 method for class 'dyadMLM_partner_check'
plot(x, ask = NULL, panels = TRUE, ...)
```

## Arguments

- x:

  A `dyadMLM_partner_check` object.

- ask:

  Whether to pause between figures on an interactive device. `NULL`
  (default) pauses when there is more than one figure; `TRUE` pauses and
  `FALSE` draws without pausing. In panel mode, each composition is one
  figure. File devices never pause.

- panels:

  If `TRUE` (default), show each composition in one figure, with two
  rows and up to three columns. If `FALSE`, draw each statistic
  separately. Graphics settings are restored afterwards.

- ...:

  Additional graphical arguments passed to
  [`graphics::plot()`](https://rdrr.io/r/graphics/plot.default.html).
  `freq`, `xlim`, `ylim`, `main`, `sub`, and `xlab` are controlled by
  this method.

## Value

Invisibly, `x`.

## Details

See
[`check_partner_dependence()`](https://pascal-kueng.github.io/dyadMLM/reference/check_partner_dependence.md)
for interpretation, panel layouts, and technical details.

## Examples

``` r
example_data <- prepare_dyad_data(
  dyads_cross[dyads_cross$coupleID <= 40, ],
  dyad = coupleID,
  member = personID,
  model_types = "none",
  seed = 123
)

model <- glmmTMB::glmmTMB(
  closeness ~ 1 +
    us(1 | coupleID) +
    us(0 + .member_contrast_arbitrary | coupleID),
  dispformula = ~ 0,
  data = example_data
)

simulations <- simulate_dyad_responses(
  model,
  nsim = 50,
  seed = 123
)

check <- check_partner_dependence(
  simulations,
  dyad = coupleID,
  role = gender,
  data = example_data,
  plot = FALSE
)

plot(check, ask = FALSE)
```
