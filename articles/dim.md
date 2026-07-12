# Dyad-Individual Model

``` r

library(interdep)
has_glmmTMB <- requireNamespace("glmmTMB", quietly = TRUE)
```

This vignette focuses on the Dyad-Individual Model (DIM) for dyadic
multilevel models and its relationship to the Actor-Partner
Interdependence Model (APIM). The DIM separates a predictor into the
dyad’s shared level and each member’s deviation from that level.

For the broader data-preparation workflow, see the [Getting Started
vignette](https://pascal-kueng.github.io/interdep/articles/getting-started.md).
For distinguishable, exchangeable, generalized, and intensive
longitudinal APIMs, see the [Actor-Partner Interdependence Model
vignette](https://pascal-kueng.github.io/interdep/articles/apim.md). For
APIMs that combine distinguishable and exchangeable dyad compositions,
see the [Mixed-Composition APIM
vignette](https://pascal-kueng.github.io/interdep/articles/mixed-apim.md).
For undirected dyadic score outcomes, see the [Undirected Dyadic Score
Model
vignette](https://pascal-kueng.github.io/interdep/articles/undirected-dsm.md).

## Cross-Sectional Gaussian DIM

The current DIM implementation prepares predictors for one exchangeable
dyad composition. Exchangeability means that swapping the two member
labels does not change the model. One way to make this assumption is to
omit `role` from
[`prepare_interdep_data()`](https://pascal-kueng.github.io/interdep/reference/prepare_interdep_data.md),
which treats all dyads as the same exchangeable composition.

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

# Print the first two dyads.
print(cross_exchangeable_data, n = 4)
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
#> #   .i_diff_*                       composition-specific sum-diff contrasts
#> #                                   with arbitrary direction; 0 for
#> #                                   distinguishable dyads or other exchangeable
#> #                                   compositions
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
#>   personID coupleID gender communication satisfaction .i_composition      
#>      <int>    <int> <fct>          <dbl>        <dbl> <fct>               
#> 1        1        1 female          4.79         4.37 assumed_exchangeable
#> 2        2        1 male            3.80         2.34 assumed_exchangeable
#> 3        3        2 female          2.91         2.44 assumed_exchangeable
#> 4        4        2 male            6.51         6.08 assumed_exchangeable
#> # ℹ 186 more rows
#> # ℹ 7 more variables: .i_composition_role <fct>,
#> #   .i_is_assumed_exchangeable <dbl>,
#> #   .i_diff_assumed_exchangeable_arbitrary <dbl>,
#> #   .i_communication_raw_actor <dbl>, .i_communication_raw_partner <dbl>,
#> #   .i_communication_raw_dyad_mean_gmc <dbl>,
#> #   .i_communication_raw_within_dyad_deviation <dbl>
```

The fixed `seed` makes the arbitrary member labels used to construct the
exchangeable-dyad difference contrast `.i_diff_*` reproducible.

Passing a `role` is also possible when it leads to exactly one
exchangeable composition (e.g., only female-female dyads).

In a dataset with mixed dyad types, the right preparation depends on the
analysis goal.

For instance, we can filter dyads and keep only male-male and
female-female dyads. Because DIM currently supports a single type of
exchangeable dyad, we might pool those like this:

``` r

cross_same_sex_pooled_data <- prepare_interdep_data(
  example_dyadic_crosssectional_mixed,
  group = coupleID,
  member = personID,
  role = gender,
  predictors = satisfaction,
  model_type = c("apim", "dim"),
  # Remove male-female dyads.
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
#> #   .i_diff_*                       composition-specific sum-diff contrasts
#> #                                   with arbitrary direction; 0 for
#> #                                   distinguishable dyads or other exchangeable
#> #                                   compositions
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
#> #   .i_diff_same_sex_couples_arbitrary <dbl>, .i_satisfaction_raw_actor <dbl>,
#> #   .i_satisfaction_raw_partner <dbl>, .i_satisfaction_raw_dyad_mean_gmc <dbl>,
#> #   .i_satisfaction_raw_within_dyad_deviation <dbl>
```

If we want to include only male-female couples and treat those as
exchangeable, we can do:

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
#> #   .i_diff_*                       composition-specific sum-diff contrasts
#> #                                   with arbitrary direction; 0 for
#> #                                   distinguishable dyads or other exchangeable
#> #                                   compositions
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
#> # ℹ 6 more variables: .i_is_female_x_male <dbl>,
#> #   .i_diff_female_x_male_arbitrary <dbl>, .i_satisfaction_raw_actor <dbl>,
#> #   .i_satisfaction_raw_partner <dbl>, .i_satisfaction_raw_dyad_mean_gmc <dbl>,
#> #   .i_satisfaction_raw_within_dyad_deviation <dbl>
```

Pooling compositions constrains them to share DIM effects. These are
substantive modeling decisions, not only data-processing choices, and
should follow the research question.

### Example DIM Model

For members $`j \in \{1, 2\}`$ of dyad $`i`$, the DIM decomposition is

``` math
\bar{x}_i = \frac{x_{i1} + x_{i2}}{2}, \qquad
d_{ij} = x_{ij} - \bar{x}_i.
```

The two deviations have equal magnitude and opposite signs:
$`d_{i1} = -d_{i2}`$. The variables that enter the DIM fixed effects
are:

1.  A dyad-mean variable that is grand-mean centered. This describes a
    couple’s shared level compared to all other couples.
2.  A within-dyad variable describing each partner’s deviation from the
    couple mean, equivalently half the signed difference between
    partners.

The fixed effects are a reparameterization of the APIM actor and partner
effects. The same random-effects structure can therefore be used for
both fixed-effect parameterizations: a dyad-level intercept and a
dyad-level difference contrast indexed by
`.i_diff_assumed_exchangeable_arbitrary`. In `glmmTMB`, with
`dispformula = ~ 0`, these random effects represent the two members’
Gaussian residual variance and covariance.

The intercept and difference contrast are specified as separate
random-effects terms, which constrains their correlation to zero. This
preserves exchangeability: swapping the arbitrary member labels leaves
the intercept term unchanged but reverses the difference contrast. A
nonzero correlation between them would therefore make the random-effects
distribution depend on the arbitrary labeling.

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
    (0 + .i_diff_assumed_exchangeable_arbitrary | coupleID)
  , dispformula = ~ 0
  , family = gaussian()
  , data = cross_exchangeable_data
)

summary(dim_1)
#>  Family: gaussian  ( identity )
#> Formula:          
#> satisfaction ~ 1 + .i_communication_raw_dyad_mean_gmc + .i_communication_raw_within_dyad_deviation +  
#>     (1 | coupleID) + (0 + .i_diff_assumed_exchangeable_arbitrary |  
#>     coupleID)
#> Dispersion:                    ~0
#> Data: cross_exchangeable_data
#> 
#>       AIC       BIC    logLik -2*log(L)  df.resid 
#>     604.0     619.8    -297.0     594.0       171 
#> 
#> Random effects:
#> 
#> Conditional model:
#>  Groups     Name                                   Variance Std.Dev.
#>  coupleID   (Intercept)                            0.6346   0.7966  
#>  coupleID.1 .i_diff_assumed_exchangeable_arbitrary 1.1532   1.0739  
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

Because this Gaussian model uses an identity link, fixed coefficients
are interpreted in satisfaction units:

- The intercept (about 5.04) is the expected satisfaction for a member
  whose communication equals the mean of a dyad with average
  communication.

- The dyad-mean estimate (about 2.00) means that a shared one-point
  difference in both members’ communication is associated with a
  two-point difference in expected satisfaction, holding their
  difference constant.

- The within-dyad-deviation estimate (about 1.52) means that the member
  whose communication is one point higher than their partner’s is
  expected to report satisfaction 1.52 points higher, holding the other
  model terms constant. This is a within-dyad association, not the
  expected change from increasing only one member’s communication, which
  would also change the dyad mean.

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
    (0 + .i_diff_assumed_exchangeable_arbitrary | coupleID)
  , dispformula = ~ 0
  , family = gaussian()
  , data = cross_exchangeable_data
)
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

The slope coefficients relate as follows:

``` math
\beta_{\text{dyad mean}} =
\beta_{\text{actor}} + \beta_{\text{partner}}
```

and

``` math
\beta_{\text{within-dyad deviation}} =
\beta_{\text{actor}} - \beta_{\text{partner}}
```

Conversely:

``` math
\beta_{\text{actor}} =
\frac{\beta_{\text{dyad mean}} + \beta_{\text{within-dyad deviation}}}{2}
```

and

``` math
\beta_{\text{partner}} =
\frac{\beta_{\text{dyad mean}} - \beta_{\text{within-dyad deviation}}}{2}
```

### Why Are These Models Equivalent? Exploring the Reparameterization

An intuitive way to think about this is:

- When the dyad mean goes up by 1 unit while the difference between
  partners remains stable, both partners’ values must go up by 1. Both
  the actor and partner effects therefore contribute, which is why the
  dyad-mean effect is the actor effect + the partner effect.

- When a person’s deviation from the dyad mean goes up by 1 unit while
  the dyad mean remains constant, the other partner’s value must go
  **down** by 1 unit. The actor value therefore changes by +1 and the
  partner value by -1, which is why the within-dyad-deviation effect is
  the actor effect - the partner effect.

The grid below shows the same predictor values in both coordinate
systems. The horizontal and vertical axes are actor and partner values
centered at the sample grand mean. The diagonal axes are their dyad mean
and within-dyad deviation.

The displayed slope values approximate the fitted example above and
illustrate that the two forms make the same change in the linear
predictor relative to the grand-mean reference. The intercept is omitted
from both displayed equations.

**Predictor coordinates**

Reset

APIM coordinates

Grand-mean-centered actor, *x*_(actor)

0.0

Grand-mean-centered partner, *x*_(partner)

0.0

DIM coordinates

Dyad mean, *x*_(mean)

0.0

Within-dyad deviation, *x*_(within)

0.0

*x*_(mean) = (*x*_(actor) + *x*_(partner)) / 2

*x*_(within) = (*x*_(actor) - *x*_(partner)) / 2

APIM0.00 = 0.00

DIM0.00 = 0.00

Slopes*b*_(mean) = 1.76 + 0.24 = 2.00; *b*_(within) = 1.76 - 0.24 = 1.52

![](data:image/svg+xml;base64,PHN2ZyBjbGFzcz0iaWRnLXBsb3QiIGRhdGEtaWRnLXBsb3Qgdmlld2JveD0iMCAwIDMyMCAzMjAiIHJvbGU9ImltZyIgYXJpYS1sYWJlbGxlZGJ5PSJpZGctcGxvdC10aXRsZSBpZGctcGxvdC1kZXNjcmlwdGlvbiI+PHRpdGxlIGlkPSJpZGctcGxvdC10aXRsZSI+QVBJTSBhbmQgRElNIGNvb3JkaW5hdGUgZ3JpZDwvdGl0bGU+CjxkZXNjIGlkPSJpZGctcGxvdC1kZXNjcmlwdGlvbiI+VGhlIHNlbGVjdGVkIHBvaW50IGhhcyBhY3RvciwgcGFydG5lciwgZHlhZC1tZWFuLCBhbmQgd2l0aGluLWR5YWQgdmFsdWVzIG9mIHplcm8uPC9kZXNjPjxkZWZzPjxjbGlwcGF0aCBpZD0iaWRnLXBsb3QtY2xpcCI+PHJlY3QgeD0iMzAiIHk9IjMwIiB3aWR0aD0iMjYwIiBoZWlnaHQ9IjI2MCIgcng9IjQiIC8+PC9jbGlwcGF0aD48L2RlZnM+PHJlY3QgeD0iMzAiIHk9IjMwIiB3aWR0aD0iMjYwIiBoZWlnaHQ9IjI2MCIgcng9IjQiIGZpbGw9Im5vbmUiIHN0cm9rZT0iY3VycmVudENvbG9yIiBzdHJva2Utb3BhY2l0eT0iMC4zNSIgLz48ZyBkYXRhLWlkZy1ncmlkLWxpbmVzIGNsaXAtcGF0aD0idXJsKCNpZGctcGxvdC1jbGlwKSI+PC9nPjxnIGRhdGEtaWRnLWF4aXMtbGFiZWxzPjwvZz48Y2lyY2xlIGNsYXNzPSJpZGctaGFsbyIgZGF0YS1pZGctaGFsbyBjeD0iMTYwIiBjeT0iMTYwIiByPSIxMyI+PC9jaXJjbGU+PGNpcmNsZSBjbGFzcz0iaWRnLXBvaW50IiBkYXRhLWlkZy1wb2ludCBjeD0iMTYwIiBjeT0iMTYwIiByPSI2Ij48L2NpcmNsZT48L3N2Zz4=)

**Shared dyad level**

Show

When both members are one point higher, the dyad mean is one point
higher and the deviation is unchanged.

*b*_(mean) = *b*_(actor) + *b*_(partner)

**Within-dyad difference**

Show

When one member is one point higher and the other one point lower, the
dyad mean is unchanged and the deviation is one point.

*b*_(within) = *b*_(actor) - *b*_(partner)

The dot uses APIM coordinates. The diagonal lines show the same point in
DIM coordinates.

Enable JavaScript to manipulate this figure. The equations and
discussion above provide the same transformation.

The DIM and APIM intercepts are not expected to be equal because the DIM
dyad mean is grand-mean centered, whereas the APIM predictors retain
their original scale.

In this example:

    #> From APIM model:
    #>   actor effect:                   1.758
    #>   partner effect:                 0.238
    #> DIM transformation:
    #>   actor effect + partner effect:  1.996
    #>   actor effect - partner effect:  1.52
    #> From DIM model:
    #>   dyad-mean effect:               1.996
    #>   within-dyad-deviation effect:   1.52

## Intensive Longitudinal DIM

For longitudinal DIM, predictors are decomposed into within-person and
between-person components before the dyadic decomposition. The default
`"auto"` strategy selects `"time_2l"` when both `time` and `predictors`
are supplied:

1.  The `cwp` dyad mean captures a shared occasion-specific shift from
    the two members’ usual levels (shared occasion-level variation).
2.  The `cwp` within-dyad deviation captures which member is further
    above or below their own usual level on that occasion.
3.  The `cbp` dyad mean captures the dyad’s shared usual level relative
    to the sample’s grand mean (stable between-dyad differences).
4.  The `cbp` within-dyad deviation captures each member’s stable
    difference from the dyad’s usual level.

`temporal_predictor_decomposition = "none"` is not available for
longitudinal DIM or undirected DSM predictor construction.

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
#> #   .i_diff_*                       composition-specific sum-diff contrasts
#> #                                   with arbitrary direction; 0 for
#> #                                   distinguishable dyads or other exchangeable
#> #                                   compositions
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
#> #   .i_is_assumed_exchangeable <dbl>,
#> #   .i_diff_assumed_exchangeable_arbitrary <dbl>,
#> #   .i_provided_support_cwp <dbl>, .i_provided_support_cbp <dbl>,
#> #   .i_provided_support_cwp_actor <dbl>, .i_provided_support_cwp_partner <dbl>,
#> #   .i_provided_support_cbp_actor <dbl>, …
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
    (0 + .i_diff_assumed_exchangeable_arbitrary | coupleID) +

    # Residual (same-day) exchangeable dyad-level covariance
    (1 | coupleID:diaryday) +
    (0 + .i_diff_assumed_exchangeable_arbitrary | coupleID:diaryday)

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
#>     (0 + .i_diff_assumed_exchangeable_arbitrary | coupleID) +  
#>     (1 | coupleID:diaryday) + (0 + .i_diff_assumed_exchangeable_arbitrary |  
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
#>  Groups              Name                                   Variance Std.Dev.
#>  coupleID            (Intercept)                            0.5254   0.7248  
#>  coupleID.1          .i_diff_assumed_exchangeable_arbitrary 0.6416   0.8010  
#>  coupleID.diaryday   (Intercept)                            0.3185   0.5643  
#>  coupleID.diaryday.1 .i_diff_assumed_exchangeable_arbitrary 0.5184   0.7200  
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

The fitted coefficients can be interpreted as:

- The `cwp` dyad-mean estimate (about 0.49) describes the expected
  change in closeness when both members are one point above their
  respective usual support levels.

- The `cbp` dyad-mean estimate (about 1.51) instead compares dyads whose
  members’ average usual support levels differ by one point.

- The `cwp` within-dyad estimate (about 0.06) describes the expected
  closeness difference associated with a one-point difference between
  members in their momentary deviations from usual support.

- The `cbp` within-dyad estimate (about 0.78) describes the expected
  closeness difference associated with a one-point difference between
  members in their usual support levels.

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
    (1 | coupleID)  + (0 + .i_diff_assumed_exchangeable_arbitrary | coupleID) +

    # Residual (same-day) exchangeable dyad-level covariance
    (1 | coupleID:diaryday) +
    (0 + .i_diff_assumed_exchangeable_arbitrary | coupleID:diaryday)

  , dispformula = ~ 0
  , family = gaussian()
  , data = ild_exchangeable_data
)
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
    (1 | coupleID)  + (0 + .i_diff_assumed_exchangeable_arbitrary | coupleID) +

    # Same-day exchangeable dyad-level covariance
    (1 | coupleID:diaryday) +
    (0 + .i_diff_assumed_exchangeable_arbitrary | coupleID:diaryday)

  , dispformula = ~ 0
  , family = gaussian()
  , data = ild_exchangeable_data
)
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

## Including Random Slopes

Random-slope DIM and APIM parameterizations can be written analogously
by adding the corresponding within-person effects to the stable
dyad-level random-effect blocks. These larger models do not converge
cleanly with the example data, so the chunks are not evaluated. Such
models can be fit when the study design, data, and convergence
diagnostics support the added complexity.

A random-slope standard deviation describes how much the corresponding
association varies across dyads around its fixed effect. Correlations
within a random-effects block describe how its latent dyad-specific
effects co-vary; they are not correlations between observed predictors
or partners. Separate random-effects terms define separate covariance
blocks, so correlations across those blocks are constrained to zero,
preserving the exchangeability condition described above.

For an exchangeable APIM, the sum-difference random-effects
representation involving `.i_diff_*` can be rotated back to a
constrained actor-partner representation. This can make actor and
partner random effects easier to interpret, while offering no analogous
interpretive advantage for the DIM. The [APIM
vignette](https://pascal-kueng.github.io/interdep/articles/apim.md)
describes this rotation and the constraints required to preserve
exchangeability.

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
         .i_diff_assumed_exchangeable_arbitrary +
         .i_diff_assumed_exchangeable_arbitrary:.i_provided_support_cwp_actor +
         .i_diff_assumed_exchangeable_arbitrary:.i_provided_support_cwp_partner
       | coupleID) +

    # Same-day exchangeable dyad-level covariance
    (1 | coupleID:diaryday) +
    (0 + .i_diff_assumed_exchangeable_arbitrary | coupleID:diaryday)

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
       .i_diff_assumed_exchangeable_arbitrary +
       .i_diff_assumed_exchangeable_arbitrary:.i_provided_support_cwp_dyad_mean +
       .i_diff_assumed_exchangeable_arbitrary:.i_provided_support_cwp_within_dyad_deviation
     | coupleID) +

    # Same-day exchangeable dyad-level covariance
    (1 | coupleID:diaryday) +
    (0 + .i_diff_assumed_exchangeable_arbitrary | coupleID:diaryday)

  , dispformula = ~ 0
  , family = gaussian()
  , data = ild_exchangeable_data
)
```

For APIM formulas with distinguishable, exchangeable, generalized, and
intensive longitudinal dyads, see the [Actor-Partner Interdependence
Model
vignette](https://pascal-kueng.github.io/interdep/articles/apim.md). For
models combining multiple dyad compositions, see the [Mixed-Composition
APIM
vignette](https://pascal-kueng.github.io/interdep/articles/mixed-apim.md).
For undirected dyadic score outcomes, see the [Undirected Dyadic Score
Model
vignette](https://pascal-kueng.github.io/interdep/articles/undirected-dsm.md).
For the broader data-preparation workflow, return to the [Getting
Started
vignette](https://pascal-kueng.github.io/interdep/articles/getting-started.md).

For an in-depth tutorial covering data preparation, model fitting,
diagnostics, and assumption checks, see [Distinguishable and
Exchangeable Dyads: Bayesian Multilevel
Modelling](https://pascal-kueng.github.io/05DyadicDataAnalysis/). It
uses `interdep` for cross-sectional and intensive longitudinal APIM and
DIM workflows, with models fitted primarily using `brms`
([source](https://github.com/Pascal-Kueng/05DyadicDataAnalysis),
[DOI](https://doi.org/10.5281/zenodo.17400655)).
