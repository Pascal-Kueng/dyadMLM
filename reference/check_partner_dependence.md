# Check whether a fitted model reproduces partner dependence

**\[experimental\]** A dyadic model should reproduce how much responses
vary and how strongly partners' responses are related. This check
computes variances and correlations of simulated responses based on the
model and compares them to the observed response variances and
correlations from the data. This helps identify mismatches in the
model's assumptions.

## Usage

``` r
check_partner_dependence(
  simulations,
  dyad,
  role = NULL,
  plot = TRUE,
  response = c("model-centred", "raw"),
  ask = NULL,
  panels = TRUE,
  data = NULL
)
```

## Arguments

- simulations:

  An object returned by
  [`simulate_dyad_responses()`](https://pascal-kueng.github.io/dyadMLM/reference/simulate_dyad_responses.md).

- dyad:

  The dyad column name. Looked up first in the fitted model frame, then
  in `data` if supplied.

- role:

  The role column name. Looked up first in the fitted model frame, then
  in `data` if supplied. `NULL` (default) pools all dyads as
  exchangeable. Supply roles even for an exchangeable model to reveal
  variance or partner-correlation mismatches that pooling may hide. Each
  role pair is checked separately, using exchangeable summaries for
  same-role pairs and role-specific summaries otherwise.

- plot:

  If `TRUE` (default), draw the comparison plots for visual checks. If
  `FALSE`, `ask` and `panels` are ignored.

- response:

  `"model-centred"` (default) subtracts the same model predictions from
  observed and simulated responses. The predictive check then assesses
  whether the model reproduces the variance and partner correlations
  remaining after accounting for its fixed-effect predictions. This
  includes random effects and observation-level noise. With `"raw"`, the
  predictive check assesses whether the full model, including fixed
  effects, reproduces the overall response variances and partner
  correlations. See
  [`simulate_dyad_responses()`](https://pascal-kueng.github.io/dyadMLM/reference/simulate_dyad_responses.md)
  for how predictions are defined.

- ask:

  Whether to pause between figures on an interactive device. `NULL`
  (default) pauses when there is more than one figure; `TRUE` pauses and
  `FALSE` draws without pausing. In panel mode, each composition is one
  figure. File devices never pause.

- panels:

  If `TRUE` (default), show each composition in one figure, with two
  rows and up to three columns. If `FALSE`, draw each statistic
  separately. Graphics settings are restored afterwards.

- data:

  Optional data frame used to fit the model. Supply it when `dyad` or
  `role` is absent from the fitted model frame. Use the exact unchanged
  data that was passed to the model when fitting.

## Value

The comparison plots (shown by default) are the main output. The
function invisibly returns a `dyadMLM_partner_check` object containing
the `compositions` table with pair counts and a statistics tibble for
each composition. Each tibble has one observed row followed by one row
per simulation, identified by `dataset`. The object includes omission
counts and settings, and can be saved and plotted later.

## Reading the plots

Histograms show simulated summaries. Red lines mark observed values.
Dashed lines enclose the middle 95% of simulations (no formal confidence
intervals). The heading shows the dyad composition, its number of usable
dyads, and the total across all compositions. The top row shows member
SDs and partner correlation. The bottom row shows the same information
using dyad averages and partner differences.

An observed value far from most simulated values may indicate that the
model does not reproduce that feature of the data well.

The first set of plots compares:

- **Response SDs:** one for each role, or one common SD for exchangeable
  members.

- **Partner correlation:** how strongly partners' responses are related.

The second set shows *the same information* using dyad averages and
partner differences:

- **Dyad-average SD:** how much dyads differ in their average response.

- **Half-difference SD or RMS:** each partner difference is divided by
  two. With distinct roles, the SD shows how much signed differences
  vary across dyads. For exchangeable members, the RMS shows their
  typical size, regardless of partner order.

- **Mean/difference correlation:** plotted only for distinct roles,
  because it depends on how partners are ordered. Positive values
  indicate greater variance for the first named role. Negative values
  indicate greater variance for the second.

These checks are particularly useful when a simpler model is needed and
a less restricted model does not converge and can't be used for model
comparison. It shows how well the simpler model reproduces the observed
variances and partner correlations.

Rows with missing IDs or roles and incomplete dyads are omitted with a
warning. The warning lists affected dyad IDs and row positions in the
fitted data. Long lists are shortened; counts are also shown when
printing the result.

## Technical details

After any centring, paired responses `a` and `b` are used to compute
dyad averages `M = (a + b) / 2` and half-differences `D = (a - b) / 2`.
Roles follow factor levels or sorted values.

For exchangeable members, common member variance is `var(M) + mean(D^2)`
and partner covariance is `var(M) - mean(D^2)`. Partner correlation is
covariance divided by variance. Half-difference RMS is
`sqrt(mean(D^2))`.

The variance and covariance calculations for exchangeable dyads follow
Woody and Sadler (2005).

## References

Woody, E., & Sadler, P. (2005). Structural equation models for
interchangeable dyads: Being the same makes a difference. *Psychological
Methods, 10*(2), 139-158.
[doi:10.1037/1082-989X.10.2.139](https://doi.org/10.1037/1082-989X.10.2.139)
.

Gelman, A., Meng, X.-L., & Stern, H. S. (1996). Posterior predictive
assessment of model fitness via realized discrepancies. *Statistica
Sinica, 6*, 733-807.

## Examples

``` r
# Data contains three compositions: female-female, female-male, and male-male.
example_data <- prepare_dyad_data(
  dyads_cross,
  dyad = coupleID,
  member = personID,
  model_types = "none",
  seed = 123
)

# This model pools all compositions and treats every dyad as exchangeable.
model <- glmmTMB::glmmTMB(
  closeness ~ 1 +
    us(1 | coupleID) +
    us(0 + .member_contrast_arbitrary | coupleID),
  dispformula = ~ 0,
  data = example_data
)

# Fewer simulations for a quick example (the default is 1000).
simulations <- simulate_dyad_responses(
  model,
  nsim = 100,
  seed = 123
)

check_partner_dependence(
  simulations,
  dyad = coupleID,
  role = gender,
  # Supply the fitting data because gender is not in the model formula.
  data = example_data
)




# Optionally, suppress plot, store object, and plot later.
check <- check_partner_dependence(
  simulations,
  dyad = coupleID,
  role = gender,
  data = example_data,
  plot = FALSE
)

# Check how well the model reproduces variances and partner correlations
# within each dyad composition.
plot(check, ask = FALSE, panels = TRUE)



print(check)
#> <dyadMLM partner-dependence check>
#> 14 statistics; 360 usable complete pairs
#> Response: model-centred
#> Reference: 100 plug-in predictive datasets with new random effects
#> female - female: 120 of 360 usable dyads
#> female - male: 120 of 360 usable dyads
#> male - male: 120 of 360 usable dyads
#> Use plot(x) to view the comparisons.

```
