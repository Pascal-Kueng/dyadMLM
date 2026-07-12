# Dyadic Score Model (DSM)

``` r

library(interdep)
```

This vignette focuses on the Dyadic Score Model (DSM) for
distinguishable dyads and its relationship to the distinguishable
Actor-Partner Interdependence Model (APIM). The DSM expresses
associations in terms of the dyad’s shared level and the directional
difference between partners.

For the broader data-preparation workflow, see the [Getting Started
vignette](https://pascal-kueng.github.io/interdep/articles/getting-started.md).
For distinguishable, exchangeable, generalized, and intensive
longitudinal APIMs, see the [Actor-Partner Interdependence Model
vignette](https://pascal-kueng.github.io/interdep/articles/apim.md). For
APIMs combining distinguishable and exchangeable compositions, see the
[Mixed-Composition APIM
vignette](https://pascal-kueng.github.io/interdep/articles/mixed-apim.md).
For the exchangeable Dyad-Individual Model (DIM), see the
[Dyad-Individual Model
vignette](https://pascal-kueng.github.io/interdep/articles/dim.md).

## Preparing DSM Data

A DSM requires a substantively meaningful direction. We therefore supply
the two roles in `dsm_role_order`. Here, `c("female", "male")` defines
every difference as female minus male, independently of row order.

``` r

cross_dsm_data <- prepare_interdep_data(
  example_dyadic_crosssectional,
  group = coupleID,
  member = personID,
  role = gender,
  predictors = communication,
  model_type = "dsm",
  dsm_role_order = c("female", "male")
)

print(cross_dsm_data, n = 4)
#> # interdep data
#> # Rows: 190 | Dyads: 95 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID, role = gender
#> # DSM direction: female - male
#> #
#> # Dyad compositions:
#> # female_x_male distinguishable 95 dyads
#> #
#> # Added columns:
#> #   .i_composition             inferred dyad composition
#> #   .i_composition_role        composition-specific member role
#> #   .i_is_{comp-role}          composition-role indicator columns
#> #   .i_dsm_role_contrast       DSM role contrast: +0.5 for the first declared
#> #                              role and -0.5 for the second declared role
#> #   .i_{pred}_dyad_mean_gmc    dyad-mean predictor: dyad's average predictor
#> #                              level, grand-mean centered
#> #   .i_{pred}_dyad_difference  DSM signed predictor difference: first declared
#> #                              role minus second declared role
#> #
#> # A tibble: 190 × 12
#>   personID coupleID gender communication satisfaction .i_composition
#>      <int>    <int> <fct>          <dbl>        <dbl> <fct>         
#> 1        1        1 female          4.79         4.37 female_x_male 
#> 2        2        1 male            3.80         2.34 female_x_male 
#> 3        3        2 female          2.91         2.44 female_x_male 
#> 4        4        2 male            6.51         6.08 female_x_male 
#> # ℹ 186 more rows
#> # ℹ 6 more variables: .i_composition_role <fct>,
#> #   .i_is_female_x_male_female <dbl>, .i_is_female_x_male_male <dbl>,
#> #   .i_dsm_role_contrast <dbl>, .i_communication_dyad_mean_gmc <dbl>,
#> #   .i_communication_dyad_difference <dbl>
```

For predictor values `X_female` and `X_male`, `interdep` creates:

``` text
.i_communication_dyad_mean_gmc
  = (X_female + X_male) / 2, grand-mean centered

.i_communication_dyad_difference
  = X_female - X_male

.i_dsm_role_contrast
  = +0.5 for female and -0.5 for male
```

The dyad mean and signed difference are repeated on both member rows.
The original member-level outcome remains unchanged and is selected in
the model formula. No outcome argument or outcome transformation is
needed.

The `+0.5/-0.5` contrast is important: coefficients involving the
contrast equal the full female-minus-male outcome difference. Reversing
`dsm_role_order` reverses all directional differences and the contrast,
but does not change fitted member outcomes.

## Cross-Sectional Gaussian DSM

Let `XLevel` denote the centered predictor dyad mean, `XDiff` the signed
predictor difference, and `C` the DSM role contrast. Iida et al.’s full
DSM can be fitted to the unchanged member-level outcome using:

``` text
outcome ~ XLevel + XDiff + C + XLevel:C + XDiff:C
```

For a cross-sectional Gaussian DSM, a correlated dyad random intercept
and role-contrast slope represent unexplained outcome-level and
outcome-difference variation. The ordinary member-level residual
variance is suppressed because the three random-effect covariance
parameters already span the three unique elements of the two-member
residual covariance matrix.

``` r

dsm_model <- glmmTMB::glmmTMB(
  satisfaction ~
    .i_communication_dyad_mean_gmc +
    .i_communication_dyad_difference +
    .i_dsm_role_contrast +
    .i_communication_dyad_mean_gmc:.i_dsm_role_contrast +
    .i_communication_dyad_difference:.i_dsm_role_contrast +
    (1 + .i_dsm_role_contrast | coupleID),
  dispformula = ~ 0,
  family = gaussian(),
  data = cross_dsm_data
)

summary(dsm_model)
```

In this example, the fixed effects have the following interpretations:

1.  **Intercept:** the expected dyad-average satisfaction when the
    couple has the sample-average communication level and no female-male
    communication difference.
2.  **Communication dyad mean:** the difference in dyad-average
    satisfaction associated with a one-unit higher shared communication
    level, holding the communication difference constant.
3.  **Communication difference:** the difference in dyad-average
    satisfaction associated with a one-unit larger female-minus-male
    communication difference, holding the shared level constant.
4.  **DSM role contrast:** the expected female-minus-male satisfaction
    difference when the shared communication level is at its reference
    value and the communication difference is zero.
5.  **Dyad mean by role contrast:** the change in the female-minus-male
    satisfaction difference associated with a one-unit higher shared
    communication level.
6.  **Communication difference by role contrast:** the change in the
    female-minus-male satisfaction difference associated with a one-unit
    larger female-minus-male communication difference.

The third and fifth coefficients are the DSM cross-paths: predictor
difference to outcome level and predictor level to outcome difference.
They are omitted from the reduced DSM but are needed for the full model.

The random intercept variance is unexplained variation in outcome level,
and the random role-contrast slope variance is unexplained variation in
the full directional outcome difference. Their covariance indicates
whether unexplained outcome level and unexplained outcome difference are
associated.

## Relationship to the APIM and DIM

For distinguishable dyads, the full DSM and an unconstrained
distinguishable APIM are alternative parameterizations of the same fixed
associations. The APIM estimates separate actor and partner effects for
each role. The DSM re-expresses those four slopes as:

- predictor level to outcome level;
- predictor difference to outcome level;
- predictor level to outcome difference; and
- predictor difference to outcome difference.

Neither parameterization is generally more correct. The APIM is often
clearer for questions about actor and partner effects, whereas the DSM
directly addresses questions about shared dyadic levels and directional
discrepancies.

For exchangeable dyads, the direction of a member difference is
arbitrary. The directional intercept, both cross-paths, and the
covariance between outcome level and outcome difference must then be
zero. The remaining reduced, label-invariant DSM is algebraically the
Gaussian DIM. In `interdep`, use `model_type = "dim"` for this
exchangeable model and reserve `model_type = "dsm"` for distinguishable
dyads.

------------------------------------------------------------------------

Refer to the:

- [Actor-Partner Interdependence Model (APIM)
  vignette](https://pascal-kueng.github.io/interdep/articles/apim.md),
- [Mixed-Composition APIM
  vignette](https://pascal-kueng.github.io/interdep/articles/mixed-apim.md),
  or
- [Dyad-Individual Model
  vignette](https://pascal-kueng.github.io/interdep/articles/dim.md),

or return to the
[Overview](https://pascal-kueng.github.io/interdep/articles/index.md).
