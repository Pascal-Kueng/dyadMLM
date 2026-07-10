# Dyad-Individual Model

``` r

library(interdep)
has_glmmTMB <- requireNamespace("glmmTMB", quietly = TRUE)
```

This vignette focuses on Dyad-Individual Model (DIM) predictor
construction and its relationship to APIM parameterizations. For broader
guidance on fitting dyadic models with `interdep`-prepared data,
especially APIMs with multiple dyad types, generalized outcomes,
intensive longitudinal models, and optimizer choices, see
[`vignette("getting-started")`](https://pascal-kueng.github.io/interdep/articles/getting-started.md).

## Cross-Sectional Gaussian DIM

The current DIM implementation prepares undirected DIM predictors. This
means that the dyad members are treated as exchangeable for DIM
construction. Here we therefore omit `role`, which makes
[`prepare_interdep_data()`](https://pascal-kueng.github.io/interdep/reference/prepare_interdep_data.md)
create a valid `.i_diff_assumed_exchangeable` contrast with values `-1`
and `1` within each dyad.

A supplied `role` column is also allowed when it yields exactly one
exchangeable composition, such as all female-female dyads. DIM
construction is currently rejected for distinguishable compositions and
for multiple exchangeable compositions.

``` r

cross_exchangeable_data <- prepare_interdep_data(
  example_dyadic_crosssectional,
  group = coupleID,
  member = personID,
  predictors = communication,
  # returning both apim and dim columns for comparison
  model_type = c("apim", "dim"),
  seed = 123
)

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
#> #                                   predictor level, grand-mean centred
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

### Example DIM Model

The random-effects structure contains a dyad-level random intercept and
a within-dyad random deviation indexed by
`.i_diff_assumed_exchangeable`.

``` r


dim_1 <- glmmTMB::glmmTMB(
  satisfaction ~ 1 +
    .i_communication_raw_dyad_mean_gmc + .i_communication_raw_within_dyad_deviation +
    (1 | coupleID) + (0 + .i_diff_assumed_exchangeable | coupleID),
  data = cross_exchangeable_data
)

summary(dim_1)
#>  Family: gaussian  ( identity )
#> Formula:          
#> satisfaction ~ 1 + .i_communication_raw_dyad_mean_gmc + .i_communication_raw_within_dyad_deviation +  
#>     (1 | coupleID) + (0 + .i_diff_assumed_exchangeable | coupleID)
#> Data: cross_exchangeable_data
#> 
#>       AIC       BIC    logLik -2*log(L)  df.resid 
#>       606       625      -297       594       170 
#> 
#> Random effects:
#> 
#> Conditional model:
#>  Groups     Name                         Variance Std.Dev.
#>  coupleID   (Intercept)                  0.2582   0.5081  
#>  coupleID.1 .i_diff_assumed_exchangeable 0.7768   0.8814  
#>  Residual                                0.7528   0.8676  
#> Number of obs: 176, groups:  coupleID, 88
#> 
#> Dispersion estimate for gaussian family (sigma^2): 0.753 
#> 
#> Conditional model:
#>                                            Estimate Std. Error z value Pr(>|z|)
#> (Intercept)                                 5.04066    0.08492   59.36   <2e-16
#> .i_communication_raw_dyad_mean_gmc          1.99562    0.07797   25.59   <2e-16
#> .i_communication_raw_within_dyad_deviation  1.51987    0.14406   10.55   <2e-16
#>                                               
#> (Intercept)                                ***
#> .i_communication_raw_dyad_mean_gmc         ***
#> .i_communication_raw_within_dyad_deviation ***
#> ---
#> Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
```

The same model can be written in APIM form:

``` r


apim_1 <- glmmTMB::glmmTMB(
  satisfaction ~ 1 +
    .i_communication_raw_actor + .i_communication_raw_partner +
    (1 | coupleID) + (0 + .i_diff_assumed_exchangeable | coupleID),
  data = cross_exchangeable_data
)

summary(apim_1)
#>  Family: gaussian  ( identity )
#> Formula:          
#> satisfaction ~ 1 + .i_communication_raw_actor + .i_communication_raw_partner +  
#>     (1 | coupleID) + (0 + .i_diff_assumed_exchangeable | coupleID)
#> Data: cross_exchangeable_data
#> 
#>       AIC       BIC    logLik -2*log(L)  df.resid 
#>       606       625      -297       594       170 
#> 
#> Random effects:
#> 
#> Conditional model:
#>  Groups     Name                         Variance Std.Dev.
#>  coupleID   (Intercept)                  0.2500   0.5000  
#>  coupleID.1 .i_diff_assumed_exchangeable 0.7687   0.8768  
#>  Residual                                0.7691   0.8770  
#> Number of obs: 176, groups:  coupleID, 88
#> 
#> Dispersion estimate for gaussian family (sigma^2): 0.769 
#> 
#> Conditional model:
#>                              Estimate Std. Error z value Pr(>|z|)    
#> (Intercept)                   -5.2330     0.4103 -12.754  < 2e-16 ***
#> .i_communication_raw_actor     1.7577     0.0819  21.461  < 2e-16 ***
#> .i_communication_raw_partner   0.2379     0.0819   2.904  0.00368 ** 
#> ---
#> Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
```

``` r

message("Install glmmTMB to run the fitted-model examples in this vignette.")
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
#> 1   DIM 605.9834 625.0063 -296.9917
#> 2  APIM 605.9834 625.0063 -296.9917
```

This shows that the same statistical model is being estimated with
different parameterizations and coefficient interpretations.

The coefficients relate as follows:

``` math
 
b_{dyad\ mean} = b_{actor} + b_{partner}
```

and

``` math
 
b_{within\ dyad\ deviation} = b_{actor} - b_{partner}
```

For example:

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

cat("  Computes to: \n")
#>   Computes to:
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

For longitudinal DIM, predictors are decomposed with `time_2l`.
`temporal_predictor_decomposition = "none"` is currently rejected for
DIM and undirected DSM longitudinal predictor construction.

``` r

ild_exchangeable_data <- prepare_interdep_data(
  example_dyadic_ILD,
  group = coupleID,
  member = personID,
  # role = gender,
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
#> #                                   centred
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

    # random effects for stable non-independence (means)
    us(1 | coupleID)  + us(0 + .i_diff_assumed_exchangeable | coupleID) +

    # Same-day residual covariance
    us(1 | coupleID:diaryday) + us(0 + .i_diff_assumed_exchangeable | coupleID:diaryday)

  , dispformula = ~ 0
  , family = gaussian()
  , data = ild_exchangeable_data
)

summary(dim_ILD)
#>  Family: gaussian  ( identity )
#> Formula:          
#> closeness ~ 1 + diaryday + .i_provided_support_cwp_dyad_mean +  
#>     .i_provided_support_cwp_within_dyad_deviation + .i_provided_support_cbp_dyad_mean +  
#>     .i_provided_support_cbp_within_dyad_deviation + us(1 | coupleID) +  
#>     us(0 + .i_diff_assumed_exchangeable | coupleID) + us(1 |  
#>     coupleID:diaryday) + us(0 + .i_diff_assumed_exchangeable |  
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

Compare to the APIM on both levels:

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

    # random effects for stable non-independence (means)
    us(1 | coupleID)  + us(0 + .i_diff_assumed_exchangeable | coupleID) +

    # Same-day residual covariance
    us(1 | coupleID:diaryday) + us(0 + .i_diff_assumed_exchangeable | coupleID:diaryday)

  , dispformula = ~ 0
  , family = gaussian()
  , data = ild_exchangeable_data
)

summary(apim_ILD)
#>  Family: gaussian  ( identity )
#> Formula:          
#> closeness ~ 1 + diaryday + .i_provided_support_cwp_actor + .i_provided_support_cwp_partner +  
#>     .i_provided_support_cbp_actor + .i_provided_support_cbp_partner +  
#>     us(1 | coupleID) + us(0 + .i_diff_assumed_exchangeable |  
#>     coupleID) + us(1 | coupleID:diaryday) + us(0 + .i_diff_assumed_exchangeable |  
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

The equivalence holds separately for the within-person and
between-person predictor components. For example:

`b_.i_provided_support_cwp_actor + b_.i_provided_support_cwp_partner`
corresponds to `b_.i_provided_support_cwp_dyad_mean`.

Analogous sum and difference transformations apply to the other
within-person and between-person components.

This also means that an APIM parameterization can be used on one level
and a DIM parameterization on the other.

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

    # random effects for stable non-independence (means)
    us(1 | coupleID)  + us(0 + .i_diff_assumed_exchangeable | coupleID) +

    # Same-day residual covariance
    us(1 | coupleID:diaryday) + us(0 + .i_diff_assumed_exchangeable | coupleID:diaryday)

  , dispformula = ~ 0
  , family = gaussian()
  , data = ild_exchangeable_data
)

summary(apim_dim_ILD)
#>  Family: gaussian  ( identity )
#> Formula:          
#> closeness ~ 1 + diaryday + .i_provided_support_cwp_actor + .i_provided_support_cwp_partner +  
#>     .i_provided_support_cbp_dyad_mean + .i_provided_support_cbp_within_dyad_deviation +  
#>     us(1 | coupleID) + us(0 + .i_diff_assumed_exchangeable |  
#>     coupleID) + us(1 | coupleID:diaryday) + us(0 + .i_diff_assumed_exchangeable |  
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

Which is still the same model:

``` r

data.frame(
  model = c("DIM", "APIM", "APIM within / DIM between"),
  AIC = c(AIC(dim_ILD), AIC(apim_ILD), AIC(apim_dim_ILD)),
  BIC = c(BIC(dim_ILD), BIC(apim_ILD), BIC(apim_dim_ILD)),
  logLik = c(
    as.numeric(logLik(dim_ILD)),
    as.numeric(logLik(apim_ILD)),
    as.numeric(logLik(apim_dim_ILD))
  )
)
#>                       model      AIC      BIC    logLik
#> 1                       DIM 2977.225 3026.637 -1478.613
#> 2                      APIM 2977.225 3026.637 -1478.613
#> 3 APIM within / DIM between 2977.225 3026.637 -1478.613
```

## Advanced: Role-Moderated DIM Fixed Effects

A possible extension is to let a distinguishable variable, such as
gender, moderate the DIM fixed effects. Conceptually, this creates
role-specific dyad-mean and within-dyad-deviation effects. Those
role-specific DIM effects can then be translated back to actor and
partner effects using the same sum and difference logic shown above.

This is close to the fixed-effect interpretation of a distinguishable
APIM, but it is not yet full distinguishable DIM support. In particular,
the random-effect and residual structures would also need role-specific
treatment before this could be treated as a complete distinguishable
dyadic model.

## Advanced: Random slopes

To include equivalent random slopes between the two models, the
within-person model coefficients can be entered as slopes as such:

WARNING: careful about model convergence, the following models do not
converge properly and should not be interpreted. They only show the
conceptual way of incorporating random slopes.

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

    # random effects for stable non-independence (means)
    us(1 + .i_provided_support_cwp_actor + .i_provided_support_cwp_partner | coupleID)  + 
    us(0 + .i_diff_assumed_exchangeable + .i_diff_assumed_exchangeable:.i_provided_support_cwp_actor + .i_diff_assumed_exchangeable:.i_provided_support_cwp_partner | coupleID) +

    # Same-day residual covariance
    us(1 | coupleID:diaryday) + us(0 + .i_diff_assumed_exchangeable | coupleID:diaryday)

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

    # random effects for stable non-independence (means)
    us(1 + .i_provided_support_cwp_dyad_mean + .i_provided_support_cwp_within_dyad_deviation | coupleID)  + 
    us(0 + .i_diff_assumed_exchangeable + .i_diff_assumed_exchangeable:.i_provided_support_cwp_dyad_mean + .i_diff_assumed_exchangeable:.i_provided_support_cwp_within_dyad_deviation | coupleID) +

    # Same-day residual covariance
    us(1 | coupleID:diaryday) + us(0 + .i_diff_assumed_exchangeable | coupleID:diaryday)

  , dispformula = ~ 0
  , family = gaussian()
  , data = ild_exchangeable_data
)
```
