# APIMs with Mixed Dyad Compositions

``` r

library(interdep)
```

This vignette covers APIMs that combine distinguishable and exchangeable
dyad compositions in one analysis. The unified model presented by
Bolger, Laurenceau, and DiGiovanni is the basis and inspiration for this
vignette. Their presentation includes a hybrid model for these dyad
types in SEM (Bolger et al. 2025). Here, we implement the same general
idea in one multilevel model. The vignette assumes familiarity with the
data-preparation workflow in the [Getting Started
vignette](https://pascal-kueng.github.io/interdep/articles/getting-started.md)
and with the single-composition models in the [Actor-Partner
Interdependence Model
vignette](https://pascal-kueng.github.io/interdep/articles/apim.md). For
DIM predictors and their equivalence to APIM effects in exchangeable
dyads, see the [Dyad-Individual Model
vignette](https://pascal-kueng.github.io/interdep/articles/dim.md). For
DSM predictor scores and their relationship to APIM effects in
distinguishable dyads, see the [Dyadic Score Model
vignette](https://pascal-kueng.github.io/interdep/articles/dsm.md).

## Cross-sectional mixed-composition APIM

The data were simulated with the following fixed effects and covariance
parameters. For exchangeable dyads, `sum_variance` and `diff_variance`
imply the partner correlation.

    #>             block     parameter    value
    #> 1   female_x_male   female_mean  5.50000
    #> 2   female_x_male     male_mean  4.50000
    #> 3   female_x_male   correlation -0.30000
    #> 4 female_x_female          mean  5.80000
    #> 5 female_x_female  sum_variance  0.67500
    #> 6 female_x_female diff_variance  0.32500
    #> 7     male_x_male          mean  4.20000
    #> 8     male_x_male  sum_variance  0.63375
    #> 9     male_x_male diff_variance  1.05625

We first prepare the data with
[`prepare_interdep_data()`](https://pascal-kueng.github.io/interdep/reference/prepare_interdep_data.md),
which identifies all observed dyad compositions.

``` r

mixed_cross_data <- prepare_interdep_data(
  example_dyadic_crosssectional_mixed,
  group = coupleID,
  member = personID,
  role = gender,
  seed = 123
)

print(mixed_cross_data, n = 4)
#> # interdep data
#> # Rows: 640 | Dyads: 320 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID, role = gender
#> #
#> # Dyad compositions:
#> # female_x_female exchangeable    100 dyads
#> # female_x_male   distinguishable 120 dyads
#> # male_x_male     exchangeable    100 dyads
#> #
#> # Added columns:
#> #   .i_composition       inferred dyad composition
#> #   .i_composition_role  composition-specific member role
#> #   .i_is_{comp-role}    composition-role indicator columns
#> #   .i_diff_{comp}       composition-specific sum-diff contrasts with arbitrary
#> #                        direction; 0 for distinguishable dyads or other
#> #                        exchangeable compositions
#> #
#> # A tibble: 640 × 12
#>   personID coupleID gender satisfaction .i_composition .i_composition_role 
#>      <int>    <int> <fct>         <dbl> <fct>          <fct>               
#> 1        1        1 female         4.95 female_x_male  female_x_male_female
#> 2        2        1 male           5.26 female_x_male  female_x_male_male  
#> 3        3        2 female         5.14 female_x_male  female_x_male_female
#> 4        4        2 male           3.11 female_x_male  female_x_male_male  
#> # ℹ 636 more rows
#> # ℹ 6 more variables: .i_is_female_x_female <dbl>,
#> #   .i_is_female_x_male_female <dbl>, .i_is_female_x_male_male <dbl>,
#> #   .i_is_male_x_male <dbl>, .i_diff_female_x_female_arbitrary <dbl>,
#> #   .i_diff_male_x_male_arbitrary <dbl>
```

For each composition, the model uses either distinguishable or
exchangeable APIM terms. For exchangeable compositions, it uses a
sum-and-difference parameterization. This gives the two members equal
variances while allowing their within-dyad covariance to be estimated
(del Rosario and West 2025).

The returned `.i_diff_*` variables contain `-1` and `1` for the
corresponding exchangeable composition and `0` for all other
compositions.
[`prepare_interdep_data()`](https://pascal-kueng.github.io/interdep/reference/prepare_interdep_data.md)
creates this structure automatically.

The model can then be specified as follows (example for an
intercept-only model):

``` r


mixed_cross_gaussian_model <- glmmTMB::glmmTMB(
  satisfaction ~ 0 +

    ##### INTERCEPTS ######
    # fixed intercepts for individuals from distinguishable female-male couples
    .i_is_female_x_male_female + .i_is_female_x_male_male +

    # fixed pooled intercept for female-female couples
    .i_is_female_x_female +

    # fixed pooled intercept for male-male couples
    .i_is_male_x_male +

    ##### RESIDUAL STRUCTURE ######
    # distinguishable female-male residual covariance
    us(0 + .i_is_female_x_male_female + .i_is_female_x_male_male | coupleID) +

    # exchangeable female-female residual covariance via sum-diff
    (0 + .i_is_female_x_female | coupleID) +
    (0 + .i_diff_female_x_female_arbitrary | coupleID) +

    # exchangeable male-male residual covariance via sum-diff
    (0 + .i_is_male_x_male | coupleID) +
    (0 + .i_diff_male_x_male_arbitrary | coupleID)

  , dispformula = ~ 0
  , family = gaussian()
  , data = mixed_cross_data
)

summary(mixed_cross_gaussian_model)
```

The four fixed-effect indicators are mutually exclusive. With $`I`$
denoting a shorter label for each generated composition-and-role
indicator, the fixed part of the model can be written as:

``` math
\mu_{ij}^{\mathrm{fixed}} =
\beta_{FM,F} I_{FM,F,ij} +
\beta_{FM,M} I_{FM,M,ij} +
\beta_{FF} I_{FF,ij} +
\beta_{MM} I_{MM,ij}.
```

The active indicator for each person is shown below:

| Row | $`I_{FM,F}`$ | $`I_{FM,M}`$ | $`I_{FF}`$ | $`I_{MM}`$ | Fixed intercept |
|:---|---:|---:|---:|---:|:---|
| Female in a female-male dyad | **1** | 0 | 0 | 0 | $`\beta_{FM,F}`$ |
| Male in a female-male dyad | 0 | **1** | 0 | 0 | $`\beta_{FM,M}`$ |
| Member of a female-female dyad | 0 | 0 | **1** | 0 | $`\beta_{FF}`$ |
| Member of a male-male dyad | 0 | 0 | 0 | **1** | $`\beta_{MM}`$ |

Therefore, for a member of a male-male dyad, for example, the fixed part
reduces to

``` math
0\beta_{FM,F} + 0\beta_{FM,M} + 0\beta_{FF} + 1\beta_{MM}
= \beta_{MM}.
```

The random-effects terms reduce in the same way because their indicator
columns are also `0` outside the relevant composition. For a female-male
dyad, the `us()` term gives the female and male members separate random
intercepts and estimates their covariance:

``` math
\mu_{Fj} = \beta_{FM,F} + u_{Fj}, \qquad
\mu_{Mj} = \beta_{FM,M} + u_{Mj}.
```

For an exchangeable composition $`C`$ (female-female or male-male), the
two random-effects terms give a shared dyad effect $`u_{Cj}`$ and an
opposite member effect $`v_{Cj}`$:

``` math
\mu_{Cij} = \beta_C + u_{Cj} + d_{Cij}v_{Cj},
\qquad d_{Cij} \in \{-1, 1\}.
```

Thus, the shared effect moves both members together, while the
difference effect moves them in opposite directions. Its `-1`/`1`
direction is arbitrary.

The five random-effects terms in the model form separate blocks: one
correlated female-male block, two female-female sum-and-difference
blocks, and two male-male sum-and-difference blocks. No random-effect
covariance is estimated between compositions. The two blocks within each
exchangeable composition are also separate, so the shared and difference
effects are uncorrelated. Because this is a cross-sectional model with
one observation per member and `dispformula = ~ 0`, these dyad-level
random effects represent the member variances and within-dyad covariance
without an additional observation-level residual variance.

This illustration is limited to the fixed-intercept model. The ILD
example below shows how composition-specific slopes can be added.

### Single versus separate mixed-composition fits

The mixed-composition models described in this vignette fit all dyad
compositions in one model call. This is useful when the goal is to
compare effects across compositions, test equality constraints, or make
those comparisons within one joint fitted model.

[`marginaleffects::hypotheses()`](https://rdrr.io/pkg/marginaleffects/man/hypotheses.html)
provides a string interface for testing linear combinations of `glmmTMB`
fixed effects. In these equations, `conditional_` identifies
coefficients from the conditional model. A positive estimate means that
the quantity on the left side is higher than the quantity on the right
side.

``` r

# Test whether male-male and female-female pooled intercepts are different
marginaleffects::hypotheses(
  mixed_cross_gaussian_model,
  hypothesis = "conditional_.i_is_male_x_male = conditional_.i_is_female_x_female",
  re.form = NA
)

# Test whether the average female-male intercept is different from the pooled
# male-male intercept
marginaleffects::hypotheses(
  mixed_cross_gaussian_model,
  hypothesis = "(conditional_.i_is_female_x_male_female + conditional_.i_is_female_x_male_male) / 2 = conditional_.i_is_male_x_male",
  re.form = NA
)

# Test whether the male intercept from a female-male couple is different from
# the pooled male intercept from a male-male couple
marginaleffects::hypotheses(
  mixed_cross_gaussian_model,
  hypothesis = "conditional_.i_is_female_x_male_male = conditional_.i_is_male_x_male",
  re.form = NA
)
```

These are population-level fixed-effect comparisons. Setting
`re.form = NA` excludes dyad-specific random effects from the quantities
being compared; it does not remove the random-effects structure from the
fitted model. Uncertainty is calculated for the fixed-effect comparison,
which is the intended target here.

It is important to note that such a fixed-effect formula with all
compositions in one model call does not, by itself, create partial
pooling across dyad compositions. The composition-specific intercepts
and slopes above are ordinary fixed effects, so estimates for
female-female or male-male dyads are not automatically shrunk toward
estimates from the other dyad types. If every mean, variance, and
covariance parameter is composition-specific, the likelihood largely
factorizes by composition. In that case, a combined fit can closely
match separate composition-specific fits. Its main advantage is that
formal parameter comparisons can be made within one fitted model, and
that models with different versions of pooling can be compared. For
example, it can be tested whether pooling male-male and female-female
couples as same-sex substantially worsens model fit, considering both
the fixed effects and random-effects structure. Such model comparisons
require the restricted and unrestricted models to use the same
observations; separate fits to different compositions should not be
compared this way.

If partial pooling is desired, for instance with few dyads for one
particular type, a different model specification is required, such as a
common effect plus composition deviations with a hierarchical prior, or
a random dyad-type effect. However, with only a few dyad types,
frequentist random dyad-type variance components are usually weakly
identified.

## Mixed-composition intensive longitudinal (ILD) Gaussian model

`example_dyadic_ILD_mixed` contains the same three dyad compositions as
the mixed-composition cross-sectional example, but each dyad contributes
repeated paired observations over `diaryday`.

To keep the example lighter, we pool female-female and male-male dyads
into one same-sex composition. This is a simplifying modeling assumption
and does not reflect all differences used to simulate these example
data. In an applied analysis, pooling should be theoretically justified
or evaluated by comparing pooled and unpooled models fitted to the same
observations.

Aside from the pooling, we prepare the data in the same way, now adding
`time` and a predictor:

``` r

mixed_ild_data <- prepare_interdep_data(
  example_dyadic_ILD_mixed,
  group = coupleID,
  member = personID,
  role = gender,
  pool_compositions = list(
    "same-sex" = c("male-male", "female-female")
  ),
  time = diaryday,
  predictors = provided_support,
  seed = 123
)

print(mixed_ild_data)
#> # interdep data
#> # Rows: 5600 | Dyads: 200 | Intensive longitudinal: yes
#> # Structure: group = coupleID, member = personID, role = gender, time =
#> # diaryday
#> #
#> # Dyad compositions:
#> # female_x_male          distinguishable  80 dyads
#> # same-sex (pooled)      exchangeable    120 dyads
#> #   female_x_female
#> #   male_x_male
#> #
#> # Added columns:
#> #   .i_composition         inferred dyad composition
#> #   .i_composition_role    composition-specific member role
#> #   .i_is_{comp-role}      composition-role indicator columns
#> #   .i_diff_{comp}         composition-specific sum-diff contrasts with
#> #                          arbitrary direction; 0 for distinguishable dyads or
#> #                          other exchangeable compositions
#> #   .i_{pred}_cwp          within-person predictor: momentary deviations from
#> #                          each person's usual level
#> #   .i_{pred}_cbp          between-person predictor: stable differences from
#> #                          the average person's usual level
#> #   .i_{pred}_actor        APIM actor predictor: actor's original predictor
#> #                          values
#> #   .i_{pred}_partner      APIM partner predictor: partner's original predictor
#> #                          values
#> #   .i_{pred}_cwp_actor    APIM within-person actor predictor: actor's
#> #                          momentary deviations from their usual level
#> #   .i_{pred}_cwp_partner  APIM within-person partner predictor: partner's
#> #                          momentary deviations from their usual level
#> #   .i_{pred}_cbp_actor    APIM between-person actor predictor: actor's stable
#> #                          difference from the average person's usual level
#> #   .i_{pred}_cbp_partner  APIM between-person partner predictor: partner's
#> #                          stable difference from the average person's usual
#> #                          level
#> #
#> # A tibble: 5,600 × 20
#>    personID coupleID diaryday gender closeness provided_support .i_composition
#>       <int>    <int>    <int> <fct>      <dbl>            <dbl> <fct>         
#>  1        1        1        0 female      3.79             4.85 female_x_male 
#>  2        1        1        1 female      2.89             4.13 female_x_male 
#>  3        1        1        2 female      4.20             4.62 female_x_male 
#>  4        1        1        3 female      5.79             5.09 female_x_male 
#>  5        1        1        4 female      3.97             4.92 female_x_male 
#>  6        1        1        5 female      3.53             4.51 female_x_male 
#>  7        1        1        6 female      4.38             5.09 female_x_male 
#>  8        1        1        7 female      3.51             4.92 female_x_male 
#>  9        1        1        8 female      4.45             4.11 female_x_male 
#> 10        1        1        9 female      3.17             4.01 female_x_male 
#> # ℹ 5,590 more rows
#> # ℹ 13 more variables: .i_composition_role <fct>,
#> #   .i_is_female_x_male_female <dbl>, .i_is_female_x_male_male <dbl>,
#> #   .i_is_same_sex <dbl>, .i_diff_same_sex_arbitrary <dbl>,
#> #   .i_provided_support_cwp <dbl>, .i_provided_support_cbp <dbl>,
#> #   .i_provided_support_actor <dbl>, .i_provided_support_partner <dbl>,
#> #   .i_provided_support_cwp_actor <dbl>, …
```

This mixed-composition ILD model includes composition-specific fixed
intercepts, time slopes, and within-person and between-person actor and
partner effects. It omits random slopes, as they would add several
variances and covariances to an already large model.

This model is complex and may produce optimizer convergence warnings,
especially when the random-effects structure is too complex for the
available data or some components are close to zero (del Rosario and
West 2025). When near-zero covariance components make a frequentist fit
unstable, regularizing priors in a Bayesian model can sometimes help,
but they do not replace careful model checks (del Rosario and West
2025). A Bayesian implementation of this mixed-composition model is
beyond the scope of this vignette. For these example data, we use the
BFGS optimizer with a higher iteration limit.

``` r


mixed_ild_gaussian_model <- glmmTMB::glmmTMB(
  closeness ~ 0 +

    # Composition-specific intercepts
    .i_is_female_x_male_female + .i_is_female_x_male_male +
    
    .i_is_same_sex +

    # Composition-specific time trends
    .i_is_female_x_male_female:diaryday +
    .i_is_female_x_male_male:diaryday +
    
    .i_is_same_sex:diaryday +

    # Composition-specific within-person actor effects
    .i_is_female_x_male_female:.i_provided_support_cwp_actor +
    .i_is_female_x_male_male:.i_provided_support_cwp_actor +
    
    .i_is_same_sex:.i_provided_support_cwp_actor +

    # Composition-specific within-person partner effects
    .i_is_female_x_male_female:.i_provided_support_cwp_partner +
    .i_is_female_x_male_male:.i_provided_support_cwp_partner +
    
    .i_is_same_sex:.i_provided_support_cwp_partner +

    # Composition-specific between-person actor effects
    .i_is_female_x_male_female:.i_provided_support_cbp_actor +
    .i_is_female_x_male_male:.i_provided_support_cbp_actor +
    
    .i_is_same_sex:.i_provided_support_cbp_actor +

    # Composition-specific between-person partner effects
    .i_is_female_x_male_female:.i_provided_support_cbp_partner +
    .i_is_female_x_male_male:.i_provided_support_cbp_partner +
    
    .i_is_same_sex:.i_provided_support_cbp_partner +

    # stable dyad-level covariance
    us(0 + .i_is_female_x_male_female + .i_is_female_x_male_male | coupleID) +
    
    (0 + .i_is_same_sex | coupleID) +
    (0 + .i_diff_same_sex_arbitrary | coupleID) +

    # same-day covariance
    us(0 + .i_is_female_x_male_female + .i_is_female_x_male_male | coupleID:diaryday) +
    
    (0 + .i_is_same_sex | coupleID:diaryday) +
    (0 + .i_diff_same_sex_arbitrary | coupleID:diaryday)

  , dispformula = ~ 0
  , family = gaussian()
  , data = mixed_ild_data
  , control = glmmTMB::glmmTMBControl(
      optimizer = stats::optim,
      optArgs = list(method = "BFGS"),
      optCtrl = list(maxit = 10000)
    )
)

summary(mixed_ild_gaussian_model)
```

This worked example omits random slopes, as they would add further
complexity. One possible extension is to let the within-person actor and
partner effects vary across dyads. The following blocks would replace
the stable dyad-level covariance terms in the model above. Each `us()`
block estimates all variances and covariances among the terms inside it.

``` r

# distinguishable female-male random intercepts and slopes
us(
  0 +
    .i_is_female_x_male_female +
    .i_is_female_x_male_male +
    .i_is_female_x_male_female:.i_provided_support_cwp_actor +
    .i_is_female_x_male_male:.i_provided_support_cwp_actor +
    .i_is_female_x_male_female:.i_provided_support_cwp_partner +
    .i_is_female_x_male_male:.i_provided_support_cwp_partner |
    coupleID
) +

# exchangeable same-sex shared block
us(
  0 +
    .i_is_same_sex +
    .i_is_same_sex:.i_provided_support_cwp_actor +
    .i_is_same_sex:.i_provided_support_cwp_partner |
    coupleID
) +

# exchangeable same-sex difference block
us(
  0 +
    .i_diff_same_sex_arbitrary +
    .i_diff_same_sex_arbitrary:.i_provided_support_cwp_actor +
    .i_diff_same_sex_arbitrary:.i_provided_support_cwp_partner |
    coupleID
)
```

This extension estimates a very large covariance structure and may not
be supported by many datasets. Regularizing priors may help with
estimation, but they do not necessarily make an unsupported
random-effects structure appropriate.

## Practical takeaway

Mixed dyad compositions do not require separate data-preparation calls.
`interdep` creates the composition-specific indicator and difference
columns, and the fitted model can place the corresponding fixed effects
and covariance terms in one formula.

It is often useful to begin with separate composition-specific models or
simpler covariance structures. Combine them when an equality constraint
or a comparison of effects across compositions is part of the research
question, and add further random effects only when the data support the
additional complexity.

------------------------------------------------------------------------

**Continue** with the [Dyad-Individual Model
vignette](https://pascal-kueng.github.io/interdep/articles/dim.md),
refer to the [Actor-Partner Interdependence Model
vignette](https://pascal-kueng.github.io/interdep/articles/apim.md) or
the [Dyadic Score Model
vignette](https://pascal-kueng.github.io/interdep/articles/dsm.md), or
return to the
[Overview](https://pascal-kueng.github.io/interdep/articles/index.md).

Bolger, Niall, Jean-Philippe Laurenceau, and Ana DiGiovanni. 2025.
“Unified Analysis Model for Indistinguishable and Distinguishable
Dyads.” *Innovations in Interpersonal Relationships and Health Research:
Advancing the Integration of Interdisciplinary Approaches to Dyadic
Behavior Change*. <https://doi.org/10.17605/OSF.IO/WYDCJ>.

Rosario, Kareena S. del, and Tessa V. West. 2025. “A Practical Guide to
Specifying Random Effects in Longitudinal Dyadic Multilevel Modeling.”
*Advances in Methods and Practices in Psychological Science* 8 (3):
25152459251351286. <https://doi.org/10.1177/25152459251351286>.
