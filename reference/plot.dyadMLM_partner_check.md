# Plot a saved partner-dependence check

**\[experimental\]** Draws the comparison plots without repeating
simulations.

## Usage

``` r
# S3 method for class 'dyadMLM_partner_check'
plot(x, ask = NULL, panel = FALSE, ...)
```

## Arguments

- x:

  A `dyadMLM_partner_check` object.

- ask:

  `TRUE` pauses before the next plot. `FALSE` draws all plots without
  pausing. `NULL` (default) chooses automatically.

- panel:

  If `FALSE` (default), draw plots one after another, with pausing
  controlled by `ask`. If `TRUE`, show all plots together in a
  two-column panel. Graphics settings are restored afterwards.

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
example_data <- dyads_cross[dyads_cross$coupleID <= 40, ]

model <- glmmTMB::glmmTMB(
  closeness ~ 1 + gender + (1 | coupleID),
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
  plot = FALSE
)

plot(check, panel = TRUE)
```
