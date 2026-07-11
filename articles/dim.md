# Dyad-Individual Model

``` r

library(interdep)
has_glmmTMB <- requireNamespace("glmmTMB", quietly = TRUE)
```

This vignette focuses on the Dyad-Individual Model (DIM) for dyadic
multilevel models and its relationship to the Actor-Partner
Interdependence Model (APIM) parameterizations.

For broader guidance on using this package for data preparation for
various dyadic model types, especially APIMs with multiple dyad types,
generalized outcomes, intensive longitudinal models, and optimizer
choices, see the [Getting Started
vignette](https://pascal-kueng.github.io/interdep/articles/getting-started.md)
and the [Actor-Partner Interdependence Model
vignette](https://pascal-kueng.github.io/interdep/articles/apim.md). For
undirected dyadic score outcomes, see the [Undirected Dyadic Score Model
vignette](https://pascal-kueng.github.io/interdep/articles/undirected-dsm.md).

## Cross-Sectional Gaussian DIM

The current DIM implementation prepares undirected DIM predictors. This
means that the dyad members are treated as exchangeable. One way to
achieve this is to omit `role` from `prepare_interdep_data`, which then
assumes all dyads are the same type of exchangeable dyads.

``` r

cross_exchangeable_data <- prepare_interdep_data(
  example_dyadic_crosssectional,
  group = coupleID,
  member = personID,
  predictors = communication,
  # Create both APIM and DIM columns for comparison.
  model_type = c("apim", "dim"),
  seed = 123
)

# printing the first couple
print(cross_exchangeable_data, n = 20)
#> # interdep data
#> # Rows: 190 | Dyads: 95 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID
#> #
#> # Dyad compositions:
#> # assumed_exchangeable exchangeable 95 dyads
#> #
#> # Added columns:
#> #   .i_composition                  inferred dyad composition
#> #   .i_composition_role             composition-specific member role
#> #   .i_is_*                         composition-role indicator columns
#> #   .i_diff_*                       composition-specific sum-diff contrasts; 0
#> #                                   for distinguishable dyads or other
#> #                                   exchangeable compositions
#> #   .i_*_raw_actor                  APIM actor predictor: actor's original
#> #                                   predictor values
#> #   .i_*_raw_partner                APIM partner predictor: partner's original
#> #                                   predictor values
#> #   .i_*_raw_dyad_mean_gmc          DIM dyad-mean predictor: dyad's average
#> #                                   predictor level, grand-mean centered
#> #   .i_*_raw_within_dyad_deviation  DIM within-dyad predictor deviation:
#> #                                   person's difference from the dyad average
#> #
#> # A tibble: 190 × 13
#>    personID coupleID gender communication satisfaction .i_composition      
#>       <int>    <int> <fct>          <dbl>        <dbl> <fct>               
#>  1        1        1 female          4.79        4.37  assumed_exchangeable
#>  2        2        1 male            3.80        2.34  assumed_exchangeable
#>  3        3        2 female          2.91        2.44  assumed_exchangeable
#>  4        4        2 male            6.51        6.08  assumed_exchangeable
#>  5        5        3 female          5.70        5.87  assumed_exchangeable
#>  6        6        3 male            8.22        9.66  assumed_exchangeable
#>  7        7        4 female          5.28        6.50  assumed_exchangeable
#>  8        8        4 male            4.89        3.08  assumed_exchangeable
#>  9        9        5 female          6.01        7.41  assumed_exchangeable
#> 10       10        5 male            4.32        1.47  assumed_exchangeable
#> 11       11        6 female          7.74        7.85  assumed_exchangeable
#> 12       12        6 male            6.57        9.84  assumed_exchangeable
#> 13       13        7 female          5.37        4.82  assumed_exchangeable
#> 14       14        7 male            5.79        6.15  assumed_exchangeable
#> 15       15        8 female          3.62        2.33  assumed_exchangeable
#> 16       16        8 male            3.21       -1.35  assumed_exchangeable
#> 17       17        9 female          4.42        4.96  assumed_exchangeable
#> 18       18        9 male            3.85        1.56  assumed_exchangeable
#> 19       19       10 female          5.22        4.23  assumed_exchangeable
#> 20       20       10 male            3.66       -0.496 assumed_exchangeable
#> # ℹ 170 more rows
#> # ℹ 7 more variables: .i_composition_role <fct>,
#> #   .i_is_assumed_exchangeable <dbl>, .i_diff_assumed_exchangeable <dbl>,
#> #   .i_communication_raw_actor <dbl>, .i_communication_raw_partner <dbl>,
#> #   .i_communication_raw_dyad_mean_gmc <dbl>,
#> #   .i_communication_raw_within_dyad_deviation <dbl>
```

Passing a `role` is also possible when it leads to exactly one
exchangeable composition (e.g., only female-female dyads).

Other datasets need a preparation step that produces exactly one
exchangeable composition before DIM columns can be constructed. In a
dataset with mixed dyad types, the right preparation depends on the
analysis goal.

For instance, we can filter dyads and keep only male-male and
female-female dyads. Because DIM currently supports a single type of
exchangeable dyad, we would pool those like this:

``` r

cross_same_sex_pooled_data <- prepare_interdep_data(
  example_dyadic_crosssectional_mixed,
  group = coupleID,
  member = personID,
  role = gender,
  predictors = satisfaction,
  model_type = c("apim", "dim"),
  # removing "male-female" dyads
  include_compositions = c("male-male", "female-female"),
  pool_compositions = list(
    "same-sex-couples" = c("male-male", "female-female")
  ),
  seed = 123
)

print(cross_same_sex_pooled_data, n = 4)
#> # interdep data
#> # Rows: 400 | Dyads: 200 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID, role = gender
#> #
#> # Dyad compositions:
#> # same-sex-couples (pooled) exchangeable 200 dyads
#> #   female_x_female
#> #   male_x_male
#> #
#> # Added columns:
#> #   .i_composition                  inferred dyad composition
#> #   .i_composition_role             composition-specific member role
#> #   .i_is_*                         composition-role indicator columns
#> #   .i_diff_*                       composition-specific sum-diff contrasts; 0
#> #                                   for distinguishable dyads or other
#> #                                   exchangeable compositions
#> #   .i_*_raw_actor                  APIM actor predictor: actor's original
#> #                                   predictor values
#> #   .i_*_raw_partner                APIM partner predictor: partner's original
#> #                                   predictor values
#> #   .i_*_raw_dyad_mean_gmc          DIM dyad-mean predictor: dyad's average
#> #                                   predictor level, grand-mean centered
#> #   .i_*_raw_within_dyad_deviation  DIM within-dyad predictor deviation:
#> #                                   person's difference from the dyad average
#> #
#> # A tibble: 400 × 12
#>   personID coupleID gender satisfaction .i_composition   .i_composition_role
#>      <int>    <int> <fct>         <dbl> <fct>            <fct>              
#> 1      241      121 female         5.32 same-sex-couples same-sex-couples   
#> 2      242      121 female         5.37 same-sex-couples same-sex-couples   
#> 3      243      122 female         5.99 same-sex-couples same-sex-couples   
#> 4      244      122 female         6.93 same-sex-couples same-sex-couples   
#> # ℹ 396 more rows
#> # ℹ 6 more variables: .i_is_same_sex_couples <dbl>,
#> #   .i_diff_same_sex_couples <dbl>, .i_satisfaction_raw_actor <dbl>,
#> #   .i_satisfaction_raw_partner <dbl>, .i_satisfaction_raw_dyad_mean_gmc <dbl>,
#> #   .i_satisfaction_raw_within_dyad_deviation <dbl>
```

If we want to include, for instance, only male-female couples and treat
those as exchangeable, we can do:

``` r

cross_male_female_exchangeable_data <- prepare_interdep_data(
  example_dyadic_crosssectional_mixed,
  group = coupleID,
  member = personID,
  role = gender,
  predictors = satisfaction,
  model_type = c("apim", "dim"),
  include_compositions = "male-female",
  set_exchangeable_compositions = "male-female",
  seed = 123
)

print(cross_male_female_exchangeable_data, n = 4)
#> # interdep data
#> # Rows: 240 | Dyads: 120 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID, role = gender
#> #
#> # Dyad compositions:
#> # female_x_male exchangeable (set by user) 120 dyads
#> #
#> # Added columns:
#> #   .i_composition                  inferred dyad composition
#> #   .i_composition_role             composition-specific member role
#> #   .i_is_*                         composition-role indicator columns
#> #   .i_diff_*                       composition-specific sum-diff contrasts; 0
#> #                                   for distinguishable dyads or other
#> #                                   exchangeable compositions
#> #   .i_*_raw_actor                  APIM actor predictor: actor's original
#> #                                   predictor values
#> #   .i_*_raw_partner                APIM partner predictor: partner's original
#> #                                   predictor values
#> #   .i_*_raw_dyad_mean_gmc          DIM dyad-mean predictor: dyad's average
#> #                                   predictor level, grand-mean centered
#> #   .i_*_raw_within_dyad_deviation  DIM within-dyad predictor deviation:
#> #                                   person's difference from the dyad average
#> #
#> # A tibble: 240 × 12
#>   personID coupleID gender satisfaction .i_composition .i_composition_role
#>      <int>    <int> <fct>         <dbl> <fct>          <fct>              
#> 1        1        1 female         4.95 female_x_male  female_x_male      
#> 2        2        1 male           5.26 female_x_male  female_x_male      
#> 3        3        2 female         5.14 female_x_male  female_x_male      
#> 4        4        2 male           3.11 female_x_male  female_x_male      
#> # ℹ 236 more rows
#> # ℹ 6 more variables: .i_is_female_x_male <dbl>, .i_diff_female_x_male <dbl>,
#> #   .i_satisfaction_raw_actor <dbl>, .i_satisfaction_raw_partner <dbl>,
#> #   .i_satisfaction_raw_dyad_mean_gmc <dbl>,
#> #   .i_satisfaction_raw_within_dyad_deviation <dbl>
```

This allows full control over which dyads are included, how they are
treated, and which are pooled.

### Example DIM Model

The variables that enter the DIM in the fixed effects include:

1.  A dyad-mean variable that is grand-mean centered. This describes a
    couple’s shared level compared to all other couples.
2.  A within-dyad variable describing each partner’s deviation from the
    couple mean, equivalently half the signed difference between
    partners.

The random-effects structure is equivalent to an APIM for exchangeable
dyads, because the APIM and the DIM are just reparametrizations of the
same model. The random effects thus contain a dyad-level intercept and a
within-dyad deviation indexed by `.i_diff_assumed_exchangeable`. In
glmmTMB, with `dispformula = ~ 0`, these dyad-level random effects model
the Gaussian residual covariance.

``` r


dim_1 <- glmmTMB::glmmTMB(
  satisfaction ~

    # Pooled fixed intercept
    1 +

    # Between-couple effect
    .i_communication_raw_dyad_mean_gmc +

    # Within-couple effect
    .i_communication_raw_within_dyad_deviation +

    # Residual Gaussian variance-covariance
    (1 | coupleID) +
    (0 + .i_diff_assumed_exchangeable | coupleID)
  , dispformula = ~ 0
  , family = gaussian()
  , data = cross_exchangeable_data
)

summary(dim_1)
#>  Family: gaussian  ( identity )
#> Formula:          
#> satisfaction ~ 1 + .i_communication_raw_dyad_mean_gmc + .i_communication_raw_within_dyad_deviation +  
#>     (1 | coupleID) + (0 + .i_diff_assumed_exchangeable | coupleID)
#> Dispersion:                    ~0
#> Data: cross_exchangeable_data
#> 
#>       AIC       BIC    logLik -2*log(L)  df.resid 
#>     604.0     619.8    -297.0     594.0       171 
#> 
#> Random effects:
#> 
#> Conditional model:
#>  Groups     Name                         Variance Std.Dev.
#>  coupleID   (Intercept)                  0.6346   0.7966  
#>  coupleID.1 .i_diff_assumed_exchangeable 1.1532   1.0739  
#> Number of obs: 176, groups:  coupleID, 88
#> 
#> Conditional model:
#>                                            Estimate Std. Error z value Pr(>|z|)
#> (Intercept)                                 5.04066    0.08492   59.36   <2e-16
#> .i_communication_raw_dyad_mean_gmc          1.99563    0.07797   25.59   <2e-16
#> .i_communication_raw_within_dyad_deviation  1.51989    0.14406   10.55   <2e-16
#>                                               
#> (Intercept)                                ***
#> .i_communication_raw_dyad_mean_gmc         ***
#> .i_communication_raw_within_dyad_deviation ***
#> ---
#> Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
```

``` r

message("Install glmmTMB to run the fitted-model examples in this vignette.")
```

The same model can be written in APIM form. Since we have requested both
sets of variables from `prepare_interdep_data`, we can fit one directly.
For more guidance on APIM specifications and different models, see the
[Actor-Partner Interdependence Model
vignette](https://pascal-kueng.github.io/interdep/articles/apim.md).

``` r


apim_1 <- glmmTMB::glmmTMB(
  satisfaction ~ 1 +
    .i_communication_raw_actor + .i_communication_raw_partner +
    (1 | coupleID) +
    (0 + .i_diff_assumed_exchangeable | coupleID)
  , dispformula = ~ 0
  , family = gaussian()
  , data = cross_exchangeable_data
)

summary(apim_1)
#>  Family: gaussian  ( identity )
#> Formula:          
#> satisfaction ~ 1 + .i_communication_raw_actor + .i_communication_raw_partner +  
#>     (1 | coupleID) + (0 + .i_diff_assumed_exchangeable | coupleID)
#> Dispersion:                    ~0
#> Data: cross_exchangeable_data
#> 
#>       AIC       BIC    logLik -2*log(L)  df.resid 
#>     604.0     619.8    -297.0     594.0       171 
#> 
#> Random effects:
#> 
#> Conditional model:
#>  Groups     Name                         Variance Std.Dev.
#>  coupleID   (Intercept)                  0.6346   0.7966  
#>  coupleID.1 .i_diff_assumed_exchangeable 1.1532   1.0739  
#> Number of obs: 176, groups:  coupleID, 88
#> 
#> Conditional model:
#>                              Estimate Std. Error z value Pr(>|z|)    
#> (Intercept)                   -5.2330     0.4103 -12.754  < 2e-16 ***
#> .i_communication_raw_actor     1.7578     0.0819  21.461  < 2e-16 ***
#> .i_communication_raw_partner   0.2379     0.0819   2.904  0.00368 ** 
#> ---
#> Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
```

The two models have identical fit statistics:

``` r

data.frame(
  model = c("DIM", "APIM"),
  AIC = c(AIC(dim_1), AIC(apim_1)),
  BIC = c(BIC(dim_1), BIC(apim_1)),
  logLik = c(as.numeric(logLik(dim_1)), as.numeric(logLik(apim_1)))
)
#>   model      AIC      BIC    logLik
#> 1   DIM 603.9834 619.8358 -296.9917
#> 2  APIM 603.9834 619.8358 -296.9917
```

This demonstrates that the same statistical model is being estimated
with different parameterizations and coefficient interpretations.

The coefficients relate as follows:

``` math
\beta_{\text{dyad mean}} =
\beta_{\text{actor}} + \beta_{\text{partner}}
```

and

``` math
\beta_{\text{within-dyad deviation}} =
\beta_{\text{actor}} - \beta_{\text{partner}}
```

In this example:

``` r

apim_coef <- glmmTMB::fixef(apim_1)$cond
dim_coef <- glmmTMB::fixef(dim_1)$cond

b_actor <- round(apim_coef[[".i_communication_raw_actor"]], 3)
b_partner <- round(apim_coef[[".i_communication_raw_partner"]], 3)

b_dyad_mean <- round(dim_coef[[".i_communication_raw_dyad_mean_gmc"]], 3)
b_within_dyad <- round(dim_coef[[".i_communication_raw_within_dyad_deviation"]], 3)

cat("From APIM model:\n")
#> From APIM model:
cat("  actor effect:                  ",  b_actor, "\n")
#>   actor effect:                   1.758
cat("  partner effect:                ", b_partner, "\n\n")
#>   partner effect:                 0.238

cat("  DIM transformation:\n")
#>   DIM transformation:
cat("  actor effect + partner effect: ", b_actor + b_partner, "\n")
#>   actor effect + partner effect:  1.996
cat("  actor effect - partner effect: ", b_actor - b_partner, "\n\n")
#>   actor effect - partner effect:  1.52

cat("From DIM model:\n")
#> From DIM model:
cat("  dyad-mean effect:              ", b_dyad_mean, "\n")
#>   dyad-mean effect:               1.996
cat("  within-dyad-deviation effect:  ", b_within_dyad, "\n")
#>   within-dyad-deviation effect:   1.52
```

## Intensive longitudinal DIM

For longitudinal DIM, predictors are decomposed into within-person and
between-person components with `time_2l`.
`temporal_predictor_decomposition = "none"` is currently rejected for
DIM and undirected DSM longitudinal predictor construction.

``` r

ild_exchangeable_data <- prepare_interdep_data(
  example_dyadic_ILD,
  group = coupleID,
  member = personID,
  time = diaryday,
  predictors = provided_support,
  model_type = c("apim", "dim"),
  seed = 123
)

print(ild_exchangeable_data)
#> # interdep data
#> # Rows: 1120 | Dyads: 40 | Intensive longitudinal: yes
#> # Structure: group = coupleID, member = personID, time = diaryday
#> #
#> # Dyad compositions:
#> # assumed_exchangeable exchangeable 40 dyads
#> #
#> # Added columns:
#> #   .i_composition                  inferred dyad composition
#> #   .i_composition_role             composition-specific member role
#> #   .i_is_*                         composition-role indicator columns
#> #   .i_diff_*                       composition-specific sum-diff contrasts; 0
#> #                                   for distinguishable dyads or other
#> #                                   exchangeable compositions
#> #   .i_*_cwp                        within-person predictor: momentary
#> #                                   deviations from each person's usual level
#> #   .i_*_cbp                        between-person predictor: stable
#> #                                   differences from the average person's usual
#> #                                   level
#> #   .i_*_cwp_actor                  APIM within-person actor predictor: actor's
#> #                                   momentary deviations from their usual level
#> #   .i_*_cwp_partner                APIM within-person partner predictor:
#> #                                   partner's momentary deviations from their
#> #                                   usual level
#> #   .i_*_cbp_actor                  APIM between-person actor predictor:
#> #                                   actor's stable difference from the average
#> #                                   person's usual level
#> #   .i_*_cbp_partner                APIM between-person partner predictor:
#> #                                   partner's stable difference from the
#> #                                   average person's usual level
#> #   .i_*_cwp_dyad_mean              DIM within-person dyad-mean predictor:
#> #                                   shared momentary deviations in the dyad
#> #   .i_*_cwp_within_dyad_deviation  DIM within-person within-dyad predictor
#> #                                   deviation: person's momentary deviation
#> #                                   from the dyad average
#> #   .i_*_cbp_dyad_mean              DIM between-person dyad-mean predictor:
#> #                                   dyad's stable usual level, grand-mean
#> #                                   centered
#> #   .i_*_cbp_within_dyad_deviation  DIM between-person within-dyad predictor
#> #                                   deviation: person's stable difference from
#> #                                   the dyad's usual level
#> #
#> # A tibble: 1,120 × 20
#>    personID coupleID diaryday gender closeness provided_support .i_composition  
#>       <int>    <int>    <int> <fct>      <dbl>            <dbl> <fct>           
#>  1        1        1        0 female      5.03             4.30 assumed_exchang…
#>  2        1        1        1 female      5.64             4.24 assumed_exchang…
#>  3        1        1        2 female      5.49             3.54 assumed_exchang…
#>  4        1        1        3 female      6.71             5.04 assumed_exchang…
#>  5        1        1        4 female      5.61             4.74 assumed_exchang…
#>  6        1        1        5 female      6.11             4.72 assumed_exchang…
#>  7        1        1        6 female      6.96             5.12 assumed_exchang…
#>  8        1        1        7 female      7.03             5.21 assumed_exchang…
#>  9        1        1        8 female      8.07             5.20 assumed_exchang…
#> 10        1        1        9 female      4.87             4.69 assumed_exchang…
#> # ℹ 1,110 more rows
#> # ℹ 13 more variables: .i_composition_role <fct>,
#> #   .i_is_assumed_exchangeable <dbl>, .i_diff_assumed_exchangeable <dbl>,
#> #   .i_provided_support_cwp <dbl>, .i_provided_support_cbp <dbl>,
#> #   .i_provided_support_cwp_actor <dbl>, .i_provided_support_cwp_partner <dbl>,
#> #   .i_provided_support_cbp_actor <dbl>, .i_provided_support_cbp_partner <dbl>,
#> #   .i_provided_support_cwp_dyad_mean <dbl>, …
```

``` r


dim_ILD <- glmmTMB::glmmTMB(
  closeness ~
    1 +

    diaryday +

    # Within-person DIM
    .i_provided_support_cwp_dyad_mean +
    .i_provided_support_cwp_within_dyad_deviation +

    # Between-person DIM
    .i_provided_support_cbp_dyad_mean +
    .i_provided_support_cbp_within_dyad_deviation +

    # Stable exchangeable dyad-level covariance
    (1 | coupleID) +
    (0 + .i_diff_assumed_exchangeable | coupleID) +

    # Residual (same-day) exchangeable dyad-level covariance
    (1 | coupleID:diaryday) +
    (0 + .i_diff_assumed_exchangeable | coupleID:diaryday)

  , dispformula = ~ 0
  , family = gaussian()
  , data = ild_exchangeable_data
)

summary(dim_ILD)
#>  Family: gaussian  ( identity )
#> Formula:          
#> closeness ~ 1 + diaryday + .i_provided_support_cwp_dyad_mean +  
#>     .i_provided_support_cwp_within_dyad_deviation + .i_provided_support_cbp_dyad_mean +  
#>     .i_provided_support_cbp_within_dyad_deviation + (1 | coupleID) +  
#>     (0 + .i_diff_assumed_exchangeable | coupleID) + (1 | coupleID:diaryday) +  
#>     (0 + .i_diff_assumed_exchangeable | coupleID:diaryday)
#> Dispersion:                 ~0
#> Data: ild_exchangeable_data
#> 
#>       AIC       BIC    logLik -2*log(L)  df.resid 
#>    2977.2    3026.6   -1478.6    2957.2      1024 
#> 
#> Random effects:
#> 
#> Conditional model:
#>  Groups              Name                         Variance Std.Dev.
#>  coupleID            (Intercept)                  0.5254   0.7248  
#>  coupleID.1          .i_diff_assumed_exchangeable 0.6416   0.8010  
#>  coupleID.diaryday   (Intercept)                  0.3185   0.5643  
#>  coupleID.diaryday.1 .i_diff_assumed_exchangeable 0.5184   0.7200  
#> Number of obs: 1034, groups:  coupleID, 40; coupleID:diaryday, 517
#> 
#> Conditional model:
#>                                                Estimate Std. Error z value
#> (Intercept)                                    5.079988   0.124223   40.89
#> diaryday                                      -0.008077   0.006234   -1.30
#> .i_provided_support_cwp_dyad_mean              0.487152   0.041725   11.68
#> .i_provided_support_cwp_within_dyad_deviation  0.055002   0.072173    0.76
#> .i_provided_support_cbp_dyad_mean              1.510701   0.193894    7.79
#> .i_provided_support_cbp_within_dyad_deviation  0.776673   0.302810    2.56
#>                                               Pr(>|z|)    
#> (Intercept)                                    < 2e-16 ***
#> diaryday                                        0.1951    
#> .i_provided_support_cwp_dyad_mean              < 2e-16 ***
#> .i_provided_support_cwp_within_dyad_deviation   0.4460    
#> .i_provided_support_cbp_dyad_mean             6.63e-15 ***
#> .i_provided_support_cbp_within_dyad_deviation   0.0103 *  
#> ---
#> Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
```

The equivalent APIM uses actor and partner effects on both levels:

``` r


apim_ILD <- glmmTMB::glmmTMB(
  closeness ~
    1 +

    diaryday +

    # Within-person APIM
    .i_provided_support_cwp_actor +
    .i_provided_support_cwp_partner +

    # Between-person APIM
    .i_provided_support_cbp_actor +
    .i_provided_support_cbp_partner +

    # Stable exchangeable dyad-level covariance
    (1 | coupleID)  + (0 + .i_diff_assumed_exchangeable | coupleID) +

    # Residual (same-day) exchangeable dyad-level covariance
    (1 | coupleID:diaryday) +
    (0 + .i_diff_assumed_exchangeable | coupleID:diaryday)

  , dispformula = ~ 0
  , family = gaussian()
  , data = ild_exchangeable_data
)

summary(apim_ILD)
#>  Family: gaussian  ( identity )
#> Formula:          
#> closeness ~ 1 + diaryday + .i_provided_support_cwp_actor + .i_provided_support_cwp_partner +  
#>     .i_provided_support_cbp_actor + .i_provided_support_cbp_partner +  
#>     (1 | coupleID) + (0 + .i_diff_assumed_exchangeable | coupleID) +  
#>     (1 | coupleID:diaryday) + (0 + .i_diff_assumed_exchangeable |  
#>     coupleID:diaryday)
#> Dispersion:                 ~0
#> Data: ild_exchangeable_data
#> 
#>       AIC       BIC    logLik -2*log(L)  df.resid 
#>    2977.2    3026.6   -1478.6    2957.2      1024 
#> 
#> Random effects:
#> 
#> Conditional model:
#>  Groups              Name                         Variance Std.Dev.
#>  coupleID            (Intercept)                  0.5254   0.7248  
#>  coupleID.1          .i_diff_assumed_exchangeable 0.6416   0.8010  
#>  coupleID.diaryday   (Intercept)                  0.3185   0.5643  
#>  coupleID.diaryday.1 .i_diff_assumed_exchangeable 0.5184   0.7200  
#> Number of obs: 1034, groups:  coupleID, 40; coupleID:diaryday, 517
#> 
#> Conditional model:
#>                                  Estimate Std. Error z value Pr(>|z|)    
#> (Intercept)                      5.079989   0.124223   40.89  < 2e-16 ***
#> diaryday                        -0.008077   0.006234   -1.30   0.1951    
#> .i_provided_support_cwp_actor    0.271077   0.041683    6.50 7.86e-11 ***
#> .i_provided_support_cwp_partner  0.216075   0.041683    5.18 2.17e-07 ***
#> .i_provided_support_cbp_actor    1.143686   0.179784    6.36 2.00e-10 ***
#> .i_provided_support_cbp_partner  0.367013   0.179784    2.04   0.0412 *  
#> ---
#> Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
```

The two ILD models again have identical fit statistics:

``` r

data.frame(
  model = c("DIM", "APIM"),
  AIC = c(AIC(dim_ILD), AIC(apim_ILD)),
  BIC = c(BIC(dim_ILD), BIC(apim_ILD)),
  logLik = c(as.numeric(logLik(dim_ILD)), as.numeric(logLik(apim_ILD)))
)
#>   model      AIC      BIC    logLik
#> 1   DIM 2977.225 3026.637 -1478.613
#> 2  APIM 2977.225 3026.637 -1478.613
```

The equivalence holds separately for the within-person (`cwp`) and
between-person (`cbp`) predictor components. For the within-person
component:

``` math
\beta_{\text{cwp dyad mean}} =
\beta_{\text{cwp actor}} + \beta_{\text{cwp partner}}
```

``` math
\beta_{\text{cwp within-dyad deviation}} =
\beta_{\text{cwp actor}} - \beta_{\text{cwp partner}}
```

For the between-person component:

``` math
\beta_{\text{cbp dyad mean}} =
\beta_{\text{cbp actor}} + \beta_{\text{cbp partner}}
```

``` math
\beta_{\text{cbp within-dyad deviation}} =
\beta_{\text{cbp actor}} - \beta_{\text{cbp partner}}
```

This also means that an APIM parameterization can be used on one level
and a DIM parameterization on the other. For example:

``` r


apim_dim_ILD <- glmmTMB::glmmTMB(
  closeness ~
    1 +

    diaryday +

    # Within-person APIM
    .i_provided_support_cwp_actor +
    .i_provided_support_cwp_partner +

    # Between-person DIM
    .i_provided_support_cbp_dyad_mean +
    .i_provided_support_cbp_within_dyad_deviation +

    # Stable exchangeable dyad-level covariance
    (1 | coupleID)  + (0 + .i_diff_assumed_exchangeable | coupleID) +

    # Same-day exchangeable dyad-level covariance
    (1 | coupleID:diaryday) +
    (0 + .i_diff_assumed_exchangeable | coupleID:diaryday)

  , dispformula = ~ 0
  , family = gaussian()
  , data = ild_exchangeable_data
)

summary(apim_dim_ILD)
#>  Family: gaussian  ( identity )
#> Formula:          
#> closeness ~ 1 + diaryday + .i_provided_support_cwp_actor + .i_provided_support_cwp_partner +  
#>     .i_provided_support_cbp_dyad_mean + .i_provided_support_cbp_within_dyad_deviation +  
#>     (1 | coupleID) + (0 + .i_diff_assumed_exchangeable | coupleID) +  
#>     (1 | coupleID:diaryday) + (0 + .i_diff_assumed_exchangeable |  
#>     coupleID:diaryday)
#> Dispersion:                 ~0
#> Data: ild_exchangeable_data
#> 
#>       AIC       BIC    logLik -2*log(L)  df.resid 
#>    2977.2    3026.6   -1478.6    2957.2      1024 
#> 
#> Random effects:
#> 
#> Conditional model:
#>  Groups              Name                         Variance Std.Dev.
#>  coupleID            (Intercept)                  0.5254   0.7249  
#>  coupleID.1          .i_diff_assumed_exchangeable 0.6416   0.8010  
#>  coupleID.diaryday   (Intercept)                  0.3185   0.5643  
#>  coupleID.diaryday.1 .i_diff_assumed_exchangeable 0.5184   0.7200  
#> Number of obs: 1034, groups:  coupleID, 40; coupleID:diaryday, 517
#> 
#> Conditional model:
#>                                                Estimate Std. Error z value
#> (Intercept)                                    5.079996   0.124224   40.89
#> diaryday                                      -0.008078   0.006234   -1.30
#> .i_provided_support_cwp_actor                  0.271072   0.041683    6.50
#> .i_provided_support_cwp_partner                0.216077   0.041683    5.18
#> .i_provided_support_cbp_dyad_mean              1.510702   0.193895    7.79
#> .i_provided_support_cbp_within_dyad_deviation  0.776668   0.302809    2.56
#>                                               Pr(>|z|)    
#> (Intercept)                                    < 2e-16 ***
#> diaryday                                        0.1951    
#> .i_provided_support_cwp_actor                 7.86e-11 ***
#> .i_provided_support_cwp_partner               2.17e-07 ***
#> .i_provided_support_cbp_dyad_mean             6.63e-15 ***
#> .i_provided_support_cbp_within_dyad_deviation   0.0103 *  
#> ---
#> Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
```

This mixed parameterization still estimates the same model:

``` r

data.frame(
  model = c("DIM within / DIM between", "APIM within / APIM between", "APIM within / DIM between"),
  AIC = c(AIC(dim_ILD), AIC(apim_ILD), AIC(apim_dim_ILD)),
  BIC = c(BIC(dim_ILD), BIC(apim_ILD), BIC(apim_dim_ILD)),
  logLik = c(
    as.numeric(logLik(dim_ILD)),
    as.numeric(logLik(apim_ILD)),
    as.numeric(logLik(apim_dim_ILD))
  )
)
#>                        model      AIC      BIC    logLik
#> 1   DIM within / DIM between 2977.225 3026.637 -1478.613
#> 2 APIM within / APIM between 2977.225 3026.637 -1478.613
#> 3  APIM within / DIM between 2977.225 3026.637 -1478.613
```

## Including random slopes

Random-slope DIM and APIM parameterizations can be written analogously
by adding the corresponding within-person effects to the stable
dyad-level random-effect blocks. In the example data below these larger
models do not converge cleanly, so the chunks are not evaluated and
should absolutely **not be interpreted**. This structure can be
reasonable if convergence diagnostics are clean.

In the APIM:

``` r


apim_ILD_random <- glmmTMB::glmmTMB(
  closeness ~
    1 +

    diaryday +

    # Within-person APIM
    .i_provided_support_cwp_actor +
    .i_provided_support_cwp_partner +

    # Between-person APIM
    .i_provided_support_cbp_actor +
    .i_provided_support_cbp_partner +

    # Stable dyad-level covariance with within-person random slopes
    (1 +
         .i_provided_support_cwp_actor +
         .i_provided_support_cwp_partner
       | coupleID)  +
    (0 +
         .i_diff_assumed_exchangeable +
         .i_diff_assumed_exchangeable:.i_provided_support_cwp_actor +
         .i_diff_assumed_exchangeable:.i_provided_support_cwp_partner
       | coupleID) +

    # Same-day exchangeable dyad-level covariance
    (1 | coupleID:diaryday) +
    (0 + .i_diff_assumed_exchangeable | coupleID:diaryday)

  , dispformula = ~ 0
  , family = gaussian()
  , data = ild_exchangeable_data
)
```

In the DIM:

``` r


dim_ILD_random <- glmmTMB::glmmTMB(
  closeness ~
    1 +

    diaryday +

    # Within-person DIM
    .i_provided_support_cwp_dyad_mean +
    .i_provided_support_cwp_within_dyad_deviation +

    # Between-person DIM
    .i_provided_support_cbp_dyad_mean +
    .i_provided_support_cbp_within_dyad_deviation +

    # Stable dyad-level covariance with within-person random slopes
    (1 +
       .i_provided_support_cwp_dyad_mean +
       .i_provided_support_cwp_within_dyad_deviation
     | coupleID)  +
    (0 +
       .i_diff_assumed_exchangeable +
       .i_diff_assumed_exchangeable:.i_provided_support_cwp_dyad_mean +
       .i_diff_assumed_exchangeable:.i_provided_support_cwp_within_dyad_deviation
     | coupleID) +

    # Same-day exchangeable dyad-level covariance
    (1 | coupleID:diaryday) +
    (0 + .i_diff_assumed_exchangeable | coupleID:diaryday)

  , dispformula = ~ 0
  , family = gaussian()
  , data = ild_exchangeable_data
)
```

For APIM formulas with distinguishable, exchangeable, generalized, and
mixed-composition dyads, see the [Actor-Partner Interdependence Model
vignette](https://pascal-kueng.github.io/interdep/articles/apim.md). For
undirected dyadic score outcomes, see the [Undirected Dyadic Score Model
vignette](https://pascal-kueng.github.io/interdep/articles/undirected-dsm.md).
For the broader data-preparation workflow, return to the [Getting
Started
vignette](https://pascal-kueng.github.io/interdep/articles/getting-started.md).
