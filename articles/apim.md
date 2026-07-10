# Actor-Partner Interdependence Model (APIM)

``` r

library(interdep)
```

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

print(head(example_dyadic_crosssectional_tweedie))
#>   personID coupleID gender motivation physical_activity
#> 1        1        1 female -1.3379394          4.029024
#> 2        2        1   male -0.9379639          3.432234
#> 3        3        2 female -0.6370109          3.078311
#> 4        4        2   male  0.6999823         13.721497
#> 5        5        3 female -0.6078674          7.812779
#> 6        6        3   male -0.6459191          7.078761
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
#>       <int>    <int> <chr>       <dbl>             <dbl> <fct>         
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
summary(tweedie_distinguishable_data)
#>     personID         coupleID            gender      motivation       
#>  Min.   :  1.00   Min.   :  1.00   Length   :240   Min.   :-2.320532  
#>  1st Qu.: 60.75   1st Qu.: 30.75   N.unique :  2   1st Qu.:-0.580126  
#>  Median :120.50   Median : 60.50   N.blank  :  0   Median :-0.032795  
#>  Mean   :120.50   Mean   : 60.50   Min.nchar:  4   Mean   :-0.008869  
#>  3rd Qu.:180.25   3rd Qu.: 90.25   Max.nchar:  6   3rd Qu.: 0.537262  
#>  Max.   :240.00   Max.   :120.00                   Max.   : 2.423337  
#>                                                    NAs    :9          
#>  physical_activity       .i_composition           .i_composition_role
#>  Min.   : 0.000    female_x_male:240    female_x_male_female:120     
#>  1st Qu.: 1.445                         female_x_male_male  :120     
#>  Median : 7.855                                                      
#>  Mean   :11.026                                                      
#>  3rd Qu.:15.147                                                      
#>  Max.   :85.043                                                      
#>  NAs    :4                                                           
#>  .i_is_female_x_male_female .i_is_female_x_male_male .i_motivation_raw_actor
#>  Min.   :0.0                Min.   :0.0              Min.   :-2.320532      
#>  1st Qu.:0.0                1st Qu.:0.0              1st Qu.:-0.580126      
#>  Median :0.5                Median :0.5              Median :-0.032795      
#>  Mean   :0.5                Mean   :0.5              Mean   :-0.008869      
#>  3rd Qu.:1.0                3rd Qu.:1.0              3rd Qu.: 0.537262      
#>  Max.   :1.0                Max.   :1.0              Max.   : 2.423337      
#>                                                      NAs    :9              
#>  .i_motivation_raw_partner
#>  Min.   :-2.320532        
#>  1st Qu.:-0.580126        
#>  Median :-0.032795        
#>  Mean   :-0.008869        
#>  3rd Qu.: 0.537262        
#>  Max.   : 2.423337        
#>  NAs    :9
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
#> #   .i_diff_*            composition-specific sum-diff contrasts; 0 for
#> #                        distinguishable dyads or other exchangeable
#> #                        compositions
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
#> #   .i_is_assumed_exchangeable <dbl>, .i_diff_assumed_exchangeable <dbl>,
#> #   .i_motivation_raw_actor <dbl>, .i_motivation_raw_partner <dbl>
summary(tweedie_exchangeable_data)
#>     personID         coupleID         gender      motivation       
#>  Min.   :  1.00   Min.   :  1.00   female:120   Min.   :-2.320532  
#>  1st Qu.: 60.75   1st Qu.: 30.75   male  :120   1st Qu.:-0.580126  
#>  Median :120.50   Median : 60.50                Median :-0.032795  
#>  Mean   :120.50   Mean   : 60.50                Mean   :-0.008869  
#>  3rd Qu.:180.25   3rd Qu.: 90.25                3rd Qu.: 0.537262  
#>  Max.   :240.00   Max.   :120.00                Max.   : 2.423337  
#>                                                 NAs    :9          
#>  physical_activity              .i_composition           .i_composition_role
#>  Min.   : 0.000    assumed_exchangeable:240    assumed_exchangeable:240     
#>  1st Qu.: 1.445                                                             
#>  Median : 7.855                                                             
#>  Mean   :11.026                                                             
#>  3rd Qu.:15.147                                                             
#>  Max.   :85.043                                                             
#>  NAs    :4                                                                  
#>  .i_is_assumed_exchangeable .i_diff_assumed_exchangeable
#>  Min.   :1                  Min.   :-1                  
#>  1st Qu.:1                  1st Qu.:-1                  
#>  Median :1                  Median : 0                  
#>  Mean   :1                  Mean   : 0                  
#>  3rd Qu.:1                  3rd Qu.: 1                  
#>  Max.   :1                  Max.   : 1                  
#>                                                         
#>  .i_motivation_raw_actor .i_motivation_raw_partner
#>  Min.   :-2.320532       Min.   :-2.320532        
#>  1st Qu.:-0.580126       1st Qu.:-0.580126        
#>  Median :-0.032795       Median :-0.032795        
#>  Mean   :-0.008869       Mean   :-0.008869        
#>  3rd Qu.: 0.537262       3rd Qu.: 0.537262        
#>  Max.   : 2.423337       Max.   : 2.423337        
#>  NAs    :9               NAs    :9
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
    (1 | coupleID) + (0 + .i_diff_assumed_exchangeable | coupleID)
    
  # estimate a single pooled Tweedie dispersion parameter
  , dispformula = ~ 1
  , family = tweedie()
  , data = tweedie_exchangeable_data
)

summary(tweedie_exchangeable_model)
```
