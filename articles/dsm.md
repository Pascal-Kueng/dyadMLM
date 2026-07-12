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

A DSM requires a substantively meaningful direction (similar to a
distinguishable APIM that distinguishes by gender). We therefore supply
the two roles in `dsm_role_order`. Here, `c("female", "male")` defines
every difference as female minus male.

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
#> #   .i_composition              inferred dyad composition
#> #   .i_composition_role         composition-specific member role
#> #   .i_is_{comp-role}           composition-role indicator columns
#> #   .i_dsm_role_contrast        DSM role contrast: +0.5 for the first declared
#> #                               role and -0.5 for the second declared role
#> #   .i_{pred}_dyad_mean_gmc     dyad-mean predictor: dyad's average predictor
#> #                               level, grand-mean centered
#> #   .i_{pred}_within_dyad_diff  DSM signed predictor difference: first declared
#> #                               role minus second declared role
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
#> #   .i_communication_within_dyad_diff <dbl>
```

For predictor values $`X_{female}`$ and $`X_{male}`$, `interdep` then
creates:

- `.i_communication_dyad_mean_gmc` $`=
  \frac{X_{female} + X_{male}}{2}`$, grand-mean centered;
- `.i_communication_within_dyad_diff` $`= X_{female} - X_{male}`$; and
- `.i_dsm_role_contrast` $`= +0.5`$ for female and $`-0.5`$ for male.

The dyad mean and signed difference are repeated on both member rows.
The original member-level outcome remains unchanged and is selected in
the model formula. No outcome argument or outcome transformation is
needed.

The `+0.5/-0.5` contrast is important: coefficients involving the
contrast equal the full female-minus-male outcome difference. Reversing
`dsm_role_order` reverses all directional differences and the contrast
exactly.

## Cross-Sectional Gaussian DSM

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
    .i_communication_within_dyad_diff +
    .i_dsm_role_contrast +
    .i_communication_dyad_mean_gmc:.i_dsm_role_contrast +
    .i_communication_within_dyad_diff:.i_dsm_role_contrast +
    (1 + .i_dsm_role_contrast | coupleID),
  dispformula = ~ 0,
  family = gaussian(),
  data = cross_dsm_data
)

summary(dsm_model)
```

### Reversing the coding

Instead of computing $`X_{female} - X_{male}`$, we can reverse the
direction and compute $`X_{male} - X_{female}`$:

``` r

cross_dsm_data_inverted <- prepare_interdep_data(
  example_dyadic_crosssectional,
  group = coupleID,
  member = personID,
  role = gender,
  predictors = communication,
  model_type = "dsm",
  dsm_role_order = c("male", "female")
)
```

``` r

dsm_model_inverted <- glmmTMB::glmmTMB(
  satisfaction ~
    .i_communication_dyad_mean_gmc +
    .i_communication_within_dyad_diff +
    .i_dsm_role_contrast +
    .i_communication_dyad_mean_gmc:.i_dsm_role_contrast +
    .i_communication_within_dyad_diff:.i_dsm_role_contrast +
    (1 + .i_dsm_role_contrast | coupleID),
  dispformula = ~ 0,
  family = gaussian(),
  data = cross_dsm_data_inverted
)

summary(dsm_model_inverted)
```

The two models have identical fitted values and model fit. Reversing the
role order reverses both the predictor difference and the outcome
difference represented by the role contrast. Consequently, the
predictor-difference main effect, role-contrast main effect, and
dyad-mean-by-role-contrast interaction reverse sign. The
difference-by-role-contrast interaction does not reverse because both
variables in this product reverse. The random-effect variances also
remain unchanged, whereas their covariance reverses sign.

### Interpreting the DSM paths

The long-format model estimates the paths of the conventional
score-based DSM directly. Define

``` math
X_L = \frac{X_{female} + X_{male}}{2}, \qquad
X_D = X_{female} - X_{male},
```

where $`X_L`$ is grand-mean centered in this example. Similarly, define
outcome level and outcome difference as

``` math
Y_L = \frac{Y_{female} + Y_{male}}{2}, \qquad
Y_D = Y_{female} - Y_{male}.
```

Although `interdep` does not materialize $`Y_L`$ and $`Y_D`$ as columns,
the fitted long-format model estimates their two DSM equations:

``` math
\widehat{Y_L} = a_{10} + a_{11}X_L + a_{12}X_D,
```

``` math
\widehat{Y_D} = a_{20} + a_{21}X_L + a_{22}X_D.
```

The fixed effects map directly to these paths:

| Long-format fixed effect | DSM path and interpretation |
|----|----|
| Intercept | $`a_{10}`$: expected dyad-average satisfaction at the sample-average communication level and no female-male communication difference |
| Communication dyad mean | $`a_{11}`$: predictor level $`\rightarrow`$ outcome level |
| Communication difference | $`a_{12}`$: predictor difference $`\rightarrow`$ outcome level |
| DSM role contrast | $`a_{20}`$: expected female-minus-male outcome difference at the predictor reference values |
| Dyad mean $`\times`$ role contrast | $`a_{21}`$: predictor level $`\rightarrow`$ outcome difference |
| Communication difference $`\times`$ role contrast | $`a_{22}`$: predictor difference $`\rightarrow`$ outcome difference |

Thus, for example, $`a_{12}`$ is the change in dyad-average satisfaction
associated with a one-unit larger female-minus-male communication
difference, holding communication level constant. In contrast,
$`a_{22}`$ is the change in the female-minus-male satisfaction
difference associated with that same one-unit larger communication
difference, holding communication level constant. The $`a_{12}`$ and
$`a_{21}`$ coefficients are the DSM cross-paths. They are omitted from
the reduced DSM but are needed for the full model.

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
