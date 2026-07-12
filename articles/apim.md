# Actor-Partner Interdependence Model (APIM)

``` r

library(interdep)
```

This vignette focuses on the cross-sectional and intensive longitudinal
Actor-Partner Interdependence model for distinguishable and exchangeable
dyads.

For the main data requirements and validation workflow of the `interdep`
package, start with the [Getting Started
vignette](https://pascal-kueng.github.io/interdep/articles/getting-started.md).
For APIMs that combine distinguishable and exchangeable dyad
compositions, see the [Mixed-Composition APIM
vignette](https://pascal-kueng.github.io/interdep/articles/mixed-apim.md).
For DIM predictors and their equivalence to APIM effects in exchangeable
dyads, see the [Dyad-Individual Model
vignette](https://pascal-kueng.github.io/interdep/articles/dim.md). For
undirected dyadic score outcomes, see the [Undirected Dyadic Score Model
vignette](https://pascal-kueng.github.io/interdep/articles/undirected-dsm.md).

> This vignette is currently under construction. Please check back soon!

### Test distinguishability

Aside from using a Wald test on the first model, nested model
comparisons require models fit to the same prepared data object. Helpers
for creating those constrained columns are planned.

## Semi-continuous cross-sectional data

`example_dyadic_crosssectional_tweedie` has the same dyadic structure as
before, but the outcome has exact zeros and positive skewed values, as
in some physical activity outcomes, in contrast to the Gaussian
distribution from the previous example.

``` r

knitr::kable(
  head(example_dyadic_crosssectional_tweedie),
  digits = 2,
  caption = "First six observations."
)
```

| personID | coupleID | gender | motivation | physical_activity |
|---------:|---------:|:-------|-----------:|------------------:|
|        1 |        1 | female |      -1.34 |              4.03 |
|        2 |        1 | male   |      -0.94 |              3.43 |
|        3 |        2 | female |      -0.64 |              3.08 |
|        4 |        2 | male   |       0.70 |             13.72 |
|        5 |        3 | female |      -0.61 |              7.81 |
|        6 |        3 | male   |      -0.65 |              7.08 |

First six observations. {.table}

``` r

hist(example_dyadic_crosssectional_tweedie$physical_activity, breaks = 20)
```

![](apim_files/figure-html/tweedie-raw-1.png)

Validation and modeling work the same way because the dyadic structure
is the same. The random-effect interpretation is different from the
Gaussian case: Tweedie random effects are latent effects on the log-mean
scale, while the observation-level Tweedie variance remains part of the
model.

### Distinguishable Tweedie APIM

``` r

tweedie_distinguishable_data <- prepare_interdep_data(
  example_dyadic_crosssectional_tweedie,
  group = coupleID,
  member = personID,
  role = gender,
  predictors = motivation,
  # when no model_type is specified, apim is the default.
  seed = 123
)

print(tweedie_distinguishable_data)
#> # interdep data
#> # Rows: 240 | Dyads: 120 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID, role = gender
#> #
#> # Dyad compositions:
#> # female_x_male distinguishable 120 dyads
#> #
#> # Added columns:
#> #   .i_composition       inferred dyad composition
#> #   .i_composition_role  composition-specific member role
#> #   .i_is_*              composition-role indicator columns
#> #   .i_*_raw_actor       APIM actor predictor: actor's original predictor
#> #                        values
#> #   .i_*_raw_partner     APIM partner predictor: partner's original predictor
#> #                        values
#> #
#> # A tibble: 240 × 11
#>    personID coupleID gender motivation physical_activity .i_composition
#>       <int>    <int> <fct>       <dbl>             <dbl> <fct>         
#>  1        1        1 female    -1.34                4.03 female_x_male 
#>  2        2        1 male      -0.938               3.43 female_x_male 
#>  3        3        2 female    -0.637               3.08 female_x_male 
#>  4        4        2 male       0.700              13.7  female_x_male 
#>  5        5        3 female    -0.608               7.81 female_x_male 
#>  6        6        3 male      -0.646               7.08 female_x_male 
#>  7        7        4 female    -0.0316              1.45 female_x_male 
#>  8        8        4 male       0.380              23.3  female_x_male 
#>  9        9        5 female     0.575               3.98 female_x_male 
#> 10       10        5 male       1.77               20.1  female_x_male 
#> # ℹ 230 more rows
#> # ℹ 5 more variables: .i_composition_role <fct>,
#> #   .i_is_female_x_male_female <dbl>, .i_is_female_x_male_male <dbl>,
#> #   .i_motivation_raw_actor <dbl>, .i_motivation_raw_partner <dbl>
```

``` r


tweedie_distinguishable_model <- glmmTMB(
  physical_activity ~ 
    # remove standard intercept and model separate intercepts for male and female
    0 + .i_is_female_x_male_female + .i_is_female_x_male_male + 
    
    # gender-specific slopes for motivation actor effect
    .i_is_female_x_male_female:.i_motivation_raw_actor + .i_is_female_x_male_male:.i_motivation_raw_actor +
    
    # gender-specific slopes for motivation partner effect
    .i_is_female_x_male_female:.i_motivation_raw_partner + .i_is_female_x_male_male:.i_motivation_raw_partner +
    
    # keep a simple couple-level latent effect for stable non-independence
    # important limitation: this can only induce positive partner dependence
    (1 | coupleID) 
  
  # allow role-specific Tweedie dispersion
  , dispformula = ~ 0 + .i_is_female_x_male_female + .i_is_female_x_male_male
  , family = tweedie()
  , data = tweedie_distinguishable_data
)

summary(tweedie_distinguishable_model)
```

### Exchangeable Tweedie APIM

``` r

tweedie_exchangeable_data <- prepare_interdep_data(
  example_dyadic_crosssectional_tweedie,
  group = coupleID,
  member = personID,
  # role = gender,
  predictors = motivation,
  seed = 123
)

print(tweedie_exchangeable_data)
#> # interdep data
#> # Rows: 240 | Dyads: 120 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID
#> #
#> # Dyad compositions:
#> # assumed_exchangeable exchangeable 120 dyads
#> #
#> # Added columns:
#> #   .i_composition       inferred dyad composition
#> #   .i_composition_role  composition-specific member role
#> #   .i_is_*              composition-role indicator columns
#> #   .i_diff_*            composition-specific sum-diff contrasts with arbitrary
#> #                        direction; 0 for distinguishable dyads or other
#> #                        exchangeable compositions
#> #   .i_*_raw_actor       APIM actor predictor: actor's original predictor
#> #                        values
#> #   .i_*_raw_partner     APIM partner predictor: partner's original predictor
#> #                        values
#> #
#> # A tibble: 240 × 11
#>    personID coupleID gender motivation physical_activity .i_composition      
#>       <int>    <int> <fct>       <dbl>             <dbl> <fct>               
#>  1        1        1 female    -1.34                4.03 assumed_exchangeable
#>  2        2        1 male      -0.938               3.43 assumed_exchangeable
#>  3        3        2 female    -0.637               3.08 assumed_exchangeable
#>  4        4        2 male       0.700              13.7  assumed_exchangeable
#>  5        5        3 female    -0.608               7.81 assumed_exchangeable
#>  6        6        3 male      -0.646               7.08 assumed_exchangeable
#>  7        7        4 female    -0.0316              1.45 assumed_exchangeable
#>  8        8        4 male       0.380              23.3  assumed_exchangeable
#>  9        9        5 female     0.575               3.98 assumed_exchangeable
#> 10       10        5 male       1.77               20.1  assumed_exchangeable
#> # ℹ 230 more rows
#> # ℹ 5 more variables: .i_composition_role <fct>,
#> #   .i_is_assumed_exchangeable <dbl>,
#> #   .i_diff_assumed_exchangeable_arbitrary <dbl>,
#> #   .i_motivation_raw_actor <dbl>, .i_motivation_raw_partner <dbl>
```

``` r


tweedie_exchangeable_model <- glmmTMB(
  physical_activity ~ 
    # pooled intercept 
    1 + 
    
    # pooled actor slope for motivation
    .i_motivation_raw_actor +
    
    # pooled partner slope for motivation
    .i_motivation_raw_partner +
    
    # exchangeable latent dyad block on the log-mean scale
    (1 | coupleID) + (0 + .i_diff_assumed_exchangeable_arbitrary | coupleID)
    
  # estimate a single pooled Tweedie dispersion parameter
  , dispformula = ~ 1
  , family = tweedie()
  , data = tweedie_exchangeable_data
)

summary(tweedie_exchangeable_model)
```

## ILD

Example model specification:

``` r


ild_distinguishable_model <- glmmTMB(
  closeness ~ 0 + 
    
    .i_is_female_x_male_female + 
    .i_is_female_x_male_male + 
    
    # Gender specific time trends
    .i_is_female_x_male_female:diaryday + 
    .i_is_female_x_male_male:diaryday +
    
    # Gender-specific within-person actor effects
    .i_is_female_x_male_female:.i_provided_support_cwp_actor +
    .i_is_female_x_male_male:.i_provided_support_cwp_actor +

    # Gender-specific within-person partner effects
    .i_is_female_x_male_female:.i_provided_support_cwp_partner +
    .i_is_female_x_male_male:.i_provided_support_cwp_partner +
    
    # Gender-specific between-person actor effects
    .i_is_female_x_male_female:.i_provided_support_cbp_actor +
    .i_is_female_x_male_male:.i_provided_support_cbp_actor +

    # Gender-specific between-person partner effects
    .i_is_female_x_male_female:.i_provided_support_cbp_partner +
    .i_is_female_x_male_male:.i_provided_support_cbp_partner +
    
    # random effects for stable non-independence (means)
    us(0 + 
         .i_is_female_x_male_female + 
         .i_is_female_x_male_male 
       | coupleID)  +

    # Same-day residual covariance
    us(0 + 
         .i_is_female_x_male_female + 
         .i_is_female_x_male_male 
       | coupleID:diaryday) 

  , dispformula = ~ 0  
  , family = gaussian()
  , data = ild_distinguishable_data
)

summary(ild_distinguishable_model)
```

## Semi-continuous intensive longitudinal dyadic data

`example_dyadic_ILD_tweedie` has the same intensive longitudinal dyadic
structure as `example_dyadic_ILD`, but the outcome is semi-continuous.

``` r

knitr::kable(
  head(example_dyadic_ILD_tweedie, n = 8),
  digits = 2,
  caption = "First eight person-day observations."
)
```

| personID | coupleID | diaryday | gender | physical_activity | provided_support |
|---------:|---------:|---------:|:-------|------------------:|-----------------:|
|        1 |        1 |        0 | female |              4.29 |             4.73 |
|        1 |        1 |        1 | female |              9.52 |             4.46 |
|        1 |        1 |        2 | female |             10.54 |             3.79 |
|        1 |        1 |        3 | female |              7.63 |             4.33 |
|        1 |        1 |        4 | female |              6.77 |             4.61 |
|        1 |        1 |        5 | female |             26.84 |             5.56 |
|        1 |        1 |        6 | female |              0.00 |             4.91 |
|        1 |        1 |        7 | female |              0.00 |             4.06 |

First eight person-day observations. {.table}

``` r

hist(example_dyadic_ILD_tweedie$physical_activity, breaks = 20)
```

![](apim_files/figure-html/ild-tweedie-raw-1.png)

### Distinguishable Tweedie ILD APIM

``` r

ild_tweedie_distinguishable_data <- prepare_interdep_data(
  example_dyadic_ILD_tweedie,
  group = coupleID,
  member = personID,
  role = gender,
  time = diaryday,
  predictors = provided_support,
  seed = 123
)

print(ild_tweedie_distinguishable_data)
#> # interdep data
#> # Rows: 1120 | Dyads: 40 | Intensive longitudinal: yes
#> # Structure: group = coupleID, member = personID, role = gender, time =
#> # diaryday
#> #
#> # Dyad compositions:
#> # female_x_male distinguishable 40 dyads
#> #
#> # Added columns:
#> #   .i_composition       inferred dyad composition
#> #   .i_composition_role  composition-specific member role
#> #   .i_is_*              composition-role indicator columns
#> #   .i_*_cwp             within-person predictor: momentary deviations from
#> #                        each person's usual level
#> #   .i_*_cbp             between-person predictor: stable differences from the
#> #                        average person's usual level
#> #   .i_*_cwp_actor       APIM within-person actor predictor: actor's momentary
#> #                        deviations from their usual level
#> #   .i_*_cwp_partner     APIM within-person partner predictor: partner's
#> #                        momentary deviations from their usual level
#> #   .i_*_cbp_actor       APIM between-person actor predictor: actor's stable
#> #                        difference from the average person's usual level
#> #   .i_*_cbp_partner     APIM between-person partner predictor: partner's
#> #                        stable difference from the average person's usual
#> #                        level
#> #
#> # A tibble: 1,120 × 16
#>    personID coupleID diaryday gender physical_activity provided_support
#>       <int>    <int>    <int> <fct>              <dbl>            <dbl>
#>  1        1        1        0 female              4.29             4.73
#>  2        1        1        1 female              9.52             4.46
#>  3        1        1        2 female             10.5              3.79
#>  4        1        1        3 female              7.63             4.33
#>  5        1        1        4 female              6.77             4.61
#>  6        1        1        5 female             26.8              5.56
#>  7        1        1        6 female              0                4.91
#>  8        1        1        7 female              0                4.06
#>  9        1        1        8 female             10.2              4.53
#> 10        1        1        9 female              0                3.72
#> # ℹ 1,110 more rows
#> # ℹ 10 more variables: .i_composition <fct>, .i_composition_role <fct>,
#> #   .i_is_female_x_male_female <dbl>, .i_is_female_x_male_male <dbl>,
#> #   .i_provided_support_cwp <dbl>, .i_provided_support_cbp <dbl>,
#> #   .i_provided_support_cwp_actor <dbl>, .i_provided_support_cwp_partner <dbl>,
#> #   .i_provided_support_cbp_actor <dbl>, .i_provided_support_cbp_partner <dbl>
```

For Tweedie models, the random-effect blocks are latent effects on the
log-mean scale. They can induce partner dependence, but they are not
residual covariance structures in the same direct sense as in Gaussian
models, because the Tweedie observation-level variance remains part of
the model.

The first model uses role-specific stable couple effects and a simple
same-day shared latent shock. This is the easier teaching model: it
keeps role-specific Tweedie dispersion, but the same-day latent shock
can only induce positive partner dependence.

``` r


ild_tweedie_distinguishable_shared_day_model <- glmmTMB(
  physical_activity ~ 0 +

    .i_is_female_x_male_female + .i_is_female_x_male_male +

    .i_is_female_x_male_female:diaryday + .i_is_female_x_male_male:diaryday +

    # Gender-specific within-person actor effects
    .i_is_female_x_male_female:.i_provided_support_cwp_actor +
    .i_is_female_x_male_male:.i_provided_support_cwp_actor +

    # Gender-specific within-person partner effects
    .i_is_female_x_male_female:.i_provided_support_cwp_partner +
    .i_is_female_x_male_male:.i_provided_support_cwp_partner +

    # Gender-specific between-person actor effects
    .i_is_female_x_male_female:.i_provided_support_cbp_actor +
    .i_is_female_x_male_male:.i_provided_support_cbp_actor +

    # Gender-specific between-person partner effects
    .i_is_female_x_male_female:.i_provided_support_cbp_partner +
    .i_is_female_x_male_male:.i_provided_support_cbp_partner +

    # random effects for stable non-independence (means)
    (0 + .i_is_female_x_male_female + .i_is_female_x_male_male | coupleID) +

    # same-day shared latent shock; positive dependence only
    (1 | coupleID:diaryday)

  , dispformula = ~ 0 + .i_is_female_x_male_female + .i_is_female_x_male_male
  , family = tweedie()
  , data = ild_tweedie_distinguishable_data
)

summary(ild_tweedie_distinguishable_shared_day_model)
```

The second model uses a role-specific same-day latent covariance block.
This is closer to the Gaussian ILD covariance structure and can
represent positive or negative same-day partner dependence. In this ILD
example, the repeated paired occasions provide enough information to
also estimate role-specific Tweedie dispersion.

``` r


ild_tweedie_distinguishable_latent_day_cov_model <- glmmTMB(
  physical_activity ~ 0 +

    .i_is_female_x_male_female + .i_is_female_x_male_male +

    .i_is_female_x_male_female:diaryday + .i_is_female_x_male_male:diaryday +

    # Gender-specific within-person actor effects
    .i_is_female_x_male_female:.i_provided_support_cwp_actor +
    .i_is_female_x_male_male:.i_provided_support_cwp_actor +

    # Gender-specific within-person partner effects
    .i_is_female_x_male_female:.i_provided_support_cwp_partner +
    .i_is_female_x_male_male:.i_provided_support_cwp_partner +

    # Gender-specific between-person actor effects
    .i_is_female_x_male_female:.i_provided_support_cbp_actor +
    .i_is_female_x_male_male:.i_provided_support_cbp_actor +

    # Gender-specific between-person partner effects
    .i_is_female_x_male_female:.i_provided_support_cbp_partner +
    .i_is_female_x_male_male:.i_provided_support_cbp_partner +

    # random effects for stable non-independence (means)
    (0 + .i_is_female_x_male_female + .i_is_female_x_male_male | coupleID) +

    # same-day role-specific latent covariance; positive or negative dependence
    (0 + .i_is_female_x_male_female + .i_is_female_x_male_male | coupleID:diaryday)

  , dispformula = ~ 0 + .i_is_female_x_male_female + .i_is_female_x_male_male
  # in case of non-convergence, a first simplification could be to remove the
  # role-specific dispersion formula
  , family = tweedie()
  , data = ild_tweedie_distinguishable_data
)

summary(ild_tweedie_distinguishable_latent_day_cov_model)
```

The fuller same-day latent covariance structure is much more fragile in
the cross-sectional case because each dyad contributes only one paired
occasion. The same pair of observations must inform the fixed effects,
Tweedie dispersion and power, and the dyadic dependence structure. In
ILD data, each dyad contributes many paired occasions, so the stable
couple-level block and the same-day occasion-level block are informed by
repeated within-dyad patterns over time.

### Exchangeable Tweedie ILD APIM

``` r

ild_tweedie_exchangeable_data <- prepare_interdep_data(
  example_dyadic_ILD_tweedie,
  group = coupleID,
  member = personID,
  time = diaryday,
  predictors = provided_support,
  seed = 123
)

print(ild_tweedie_exchangeable_data)
#> # interdep data
#> # Rows: 1120 | Dyads: 40 | Intensive longitudinal: yes
#> # Structure: group = coupleID, member = personID, time = diaryday
#> #
#> # Dyad compositions:
#> # assumed_exchangeable exchangeable 40 dyads
#> #
#> # Added columns:
#> #   .i_composition       inferred dyad composition
#> #   .i_composition_role  composition-specific member role
#> #   .i_is_*              composition-role indicator columns
#> #   .i_diff_*            composition-specific sum-diff contrasts with arbitrary
#> #                        direction; 0 for distinguishable dyads or other
#> #                        exchangeable compositions
#> #   .i_*_cwp             within-person predictor: momentary deviations from
#> #                        each person's usual level
#> #   .i_*_cbp             between-person predictor: stable differences from the
#> #                        average person's usual level
#> #   .i_*_cwp_actor       APIM within-person actor predictor: actor's momentary
#> #                        deviations from their usual level
#> #   .i_*_cwp_partner     APIM within-person partner predictor: partner's
#> #                        momentary deviations from their usual level
#> #   .i_*_cbp_actor       APIM between-person actor predictor: actor's stable
#> #                        difference from the average person's usual level
#> #   .i_*_cbp_partner     APIM between-person partner predictor: partner's
#> #                        stable difference from the average person's usual
#> #                        level
#> #
#> # A tibble: 1,120 × 16
#>    personID coupleID diaryday gender physical_activity provided_support
#>       <int>    <int>    <int> <fct>              <dbl>            <dbl>
#>  1        1        1        0 female              4.29             4.73
#>  2        1        1        1 female              9.52             4.46
#>  3        1        1        2 female             10.5              3.79
#>  4        1        1        3 female              7.63             4.33
#>  5        1        1        4 female              6.77             4.61
#>  6        1        1        5 female             26.8              5.56
#>  7        1        1        6 female              0                4.91
#>  8        1        1        7 female              0                4.06
#>  9        1        1        8 female             10.2              4.53
#> 10        1        1        9 female              0                3.72
#> # ℹ 1,110 more rows
#> # ℹ 10 more variables: .i_composition <fct>, .i_composition_role <fct>,
#> #   .i_is_assumed_exchangeable <dbl>,
#> #   .i_diff_assumed_exchangeable_arbitrary <dbl>,
#> #   .i_provided_support_cwp <dbl>, .i_provided_support_cbp <dbl>,
#> #   .i_provided_support_cwp_actor <dbl>, .i_provided_support_cwp_partner <dbl>,
#> #   .i_provided_support_cbp_actor <dbl>, …
```

This is the exchangeable analogue of the fuller Tweedie ILD model above.
The sum-diff random-effect blocks provide stable and same-day
exchangeable latent covariance structures. The Tweedie dispersion stays
pooled because the sum-diff signs identify exchangeable positions, not
substantive roles.

``` r


ild_tweedie_exchangeable_model <- glmmTMB(
  physical_activity ~
    1 +

    diaryday +

    # Pooled within-person actor and partner effects
    .i_provided_support_cwp_actor +
    .i_provided_support_cwp_partner +

    # Pooled between-person actor and partner effects
    .i_provided_support_cbp_actor +
    .i_provided_support_cbp_partner +

    # stable exchangeable latent covariance
    (1 | coupleID) + (0 + .i_diff_assumed_exchangeable_arbitrary | coupleID) +
  
    # same-day exchangeable latent covariance
    (1 | coupleID:diaryday) + (0 + .i_diff_assumed_exchangeable_arbitrary | coupleID:diaryday)

  # pooled dispersion; exchangeable positions should not define dispersion differences
  , dispformula = ~ 1
  , family = tweedie()
  , data = ild_tweedie_exchangeable_data
)

summary(ild_tweedie_exchangeable_model)
```

For models that combine distinguishable and exchangeable dyad
compositions, continue with the [Mixed-Composition APIM
vignette](https://pascal-kueng.github.io/interdep/articles/mixed-apim.md).
For the main data-preparation workflow, return to the [Getting Started
vignette](https://pascal-kueng.github.io/interdep/articles/getting-started.md).
For the alternative DIM parameterization of exchangeable dyads, see the
[Dyad-Individual Model
vignette](https://pascal-kueng.github.io/interdep/articles/dim.md), or
continue to the [Undirected Dyadic Score Model
vignette](https://pascal-kueng.github.io/interdep/articles/undirected-dsm.md).

For an in-depth tutorial covering data preparation, model fitting,
diagnostics, and assumption checks, see [Distinguishable and
Exchangeable Dyads: Bayesian Multilevel
Modelling](https://pascal-kueng.github.io/05DyadicDataAnalysis/). It
uses `interdep` for cross-sectional and intensive longitudinal APIM and
DIM workflows, with models fitted primarily using `brms`
([source](https://github.com/Pascal-Kueng/05DyadicDataAnalysis),
[DOI](https://doi.org/10.5281/zenodo.17400655)).
