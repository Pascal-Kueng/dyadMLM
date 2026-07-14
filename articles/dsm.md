# Dyadic Score Model (DSM)

``` r

library(interdep)
has_glmmTMB <- requireNamespace("glmmTMB", quietly = TRUE)
```

This vignette focuses on the Dyadic Score Model (DSM) for
distinguishable dyads and its relationship to the distinguishable
Actor-Partner Interdependence Model (APIM). The DSM expresses
associations in terms of the dyad’s shared level and the directional
difference between partners (Iida et al. 2018).

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
  \frac{X_{female} + X_{male}}{2} - \mu_X`$, where $`\mu_X`$ is the
  sample grand mean of the dyad-level predictor means;
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
#>  Family: gaussian  ( identity )
#> Formula:          
#> satisfaction ~ .i_communication_dyad_mean_gmc + .i_communication_within_dyad_diff +  
#>     .i_dsm_role_contrast + .i_communication_dyad_mean_gmc:.i_dsm_role_contrast +  
#>     .i_communication_within_dyad_diff:.i_dsm_role_contrast +  
#>     (1 + .i_dsm_role_contrast | coupleID)
#> Dispersion:                    ~0
#> Data: cross_dsm_data
#> 
#>       AIC       BIC    logLik -2*log(L)  df.resid 
#>     589.5     618.0    -285.7     571.5       167 
#> 
#> Random effects:
#> 
#> Conditional model:
#>  Groups   Name                 Variance Std.Dev. Corr  
#>  coupleID (Intercept)          0.632    0.795          
#>           .i_dsm_role_contrast 3.678    1.918    -0.16 
#> Number of obs: 176, groups:  coupleID, 88
#> 
#> Conditional model:
#>                                                        Estimate Std. Error
#> (Intercept)                                             5.04256    0.08481
#> .i_communication_dyad_mean_gmc                          1.99024    0.07834
#> .i_communication_within_dyad_diff                      -0.03201    0.05372
#> .i_dsm_role_contrast                                    0.95644    0.20459
#> .i_communication_dyad_mean_gmc:.i_dsm_role_contrast    -0.13847    0.18899
#> .i_communication_within_dyad_diff:.i_dsm_role_contrast  1.48641    0.12959
#>                                                        z value Pr(>|z|)    
#> (Intercept)                                              59.46  < 2e-16 ***
#> .i_communication_dyad_mean_gmc                           25.41  < 2e-16 ***
#> .i_communication_within_dyad_diff                        -0.60    0.551    
#> .i_dsm_role_contrast                                      4.67 2.94e-06 ***
#> .i_communication_dyad_mean_gmc:.i_dsm_role_contrast      -0.73    0.464    
#> .i_communication_within_dyad_diff:.i_dsm_role_contrast   11.47  < 2e-16 ***
#> ---
#> Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
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
  # Request APIM columns too for comparison below.
  model_type = c("dsm", "apim"),
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
#>  Family: gaussian  ( identity )
#> Formula:          
#> satisfaction ~ .i_communication_dyad_mean_gmc + .i_communication_within_dyad_diff +  
#>     .i_dsm_role_contrast + .i_communication_dyad_mean_gmc:.i_dsm_role_contrast +  
#>     .i_communication_within_dyad_diff:.i_dsm_role_contrast +  
#>     (1 + .i_dsm_role_contrast | coupleID)
#> Dispersion:                    ~0
#> Data: cross_dsm_data_inverted
#> 
#>       AIC       BIC    logLik -2*log(L)  df.resid 
#>     589.5     618.0    -285.7     571.5       167 
#> 
#> Random effects:
#> 
#> Conditional model:
#>  Groups   Name                 Variance Std.Dev. Corr 
#>  coupleID (Intercept)          0.632    0.795         
#>           .i_dsm_role_contrast 3.678    1.918    0.16 
#> Number of obs: 176, groups:  coupleID, 88
#> 
#> Conditional model:
#>                                                        Estimate Std. Error
#> (Intercept)                                             5.04257    0.08481
#> .i_communication_dyad_mean_gmc                          1.99024    0.07834
#> .i_communication_within_dyad_diff                       0.03200    0.05372
#> .i_dsm_role_contrast                                   -0.95644    0.20459
#> .i_communication_dyad_mean_gmc:.i_dsm_role_contrast     0.13848    0.18899
#> .i_communication_within_dyad_diff:.i_dsm_role_contrast  1.48641    0.12959
#>                                                        z value Pr(>|z|)    
#> (Intercept)                                              59.46  < 2e-16 ***
#> .i_communication_dyad_mean_gmc                           25.41  < 2e-16 ***
#> .i_communication_within_dyad_diff                         0.60    0.551    
#> .i_dsm_role_contrast                                     -4.67 2.94e-06 ***
#> .i_communication_dyad_mean_gmc:.i_dsm_role_contrast       0.73    0.464    
#> .i_communication_within_dyad_diff:.i_dsm_role_contrast   11.47  < 2e-16 ***
#> ---
#> Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
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

For the outcomes given the predictors, the long-format model estimates
the same paths as the conventional score-based DSM (Iida et al. 2018).
Unlike the original SEM approach, it does not also model the predictor
scores or provide an overall SEM fit test. Define

``` math
X_L = \frac{X_{female} + X_{male}}{2} - \mu_X, \qquad
X_D = X_{female} - X_{male},
```

where $`\mu_X`$ is the sample grand mean of the dyad-level predictor
means. Similarly, define outcome level and outcome difference as

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

Observed $`Y_L`$ and $`Y_D`$ scores require both partners’ outcomes. The
long-format model can still use one partner’s available outcome when the
other is missing; in that case, these equations describe the paired
expected outcomes rather than observed outcome scores for that dyad.

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
associations (Iida et al. 2018).

Let’s fit the equivalent distinguishable APIM:

``` r

apim_model <- glmmTMB::glmmTMB(
  satisfaction ~
    # Role-specific intercepts
    0 +
    .i_is_female_x_male_female +
    .i_is_female_x_male_male +

    # Role-specific actor effects
    .i_is_female_x_male_female:.i_communication_actor +
    .i_is_female_x_male_male:.i_communication_actor +

    # Role-specific partner effects
    .i_is_female_x_male_female:.i_communication_partner +
    .i_is_female_x_male_male:.i_communication_partner +

    # Role-specific Gaussian residual variance-covariance
    us(0 +
         .i_is_female_x_male_female +
         .i_is_female_x_male_male
       | coupleID),
  dispformula = ~ 0,
  family = gaussian(),
  data = cross_dsm_data_inverted
)
```

The two DSM directions and the APIM have identical fit statistics:

``` r

data.frame(
  model = c("DSM: female - male", "DSM: male - female", "APIM"),
  AIC = round(c(AIC(dsm_model), AIC(dsm_model_inverted), AIC(apim_model)), 3),
  BIC = round(c(BIC(dsm_model), BIC(dsm_model_inverted), BIC(apim_model)), 3),
  logLik = round(c(
    as.numeric(logLik(dsm_model)),
    as.numeric(logLik(dsm_model_inverted)),
    as.numeric(logLik(apim_model))
  ), 3)
)
#>                model     AIC     BIC   logLik
#> 1 DSM: female - male 589.491 618.026 -285.746
#> 2 DSM: male - female 589.491 618.026 -285.746
#> 3               APIM 589.491 618.026 -285.746
```

### Fixed-effect transformation

Let $`A_f`$ and $`A_m`$ denote the female and male actor effects, and
let $`P_f`$ and $`P_m`$ denote the partner effects on the female and
male outcomes, respectively. Let $`\alpha_f`$ and $`\alpha_m`$ be the
corresponding APIM intercepts. The APIM slopes transform into the
female-minus-male DSM paths as

``` math
\begin{aligned}
a_{11} &= \frac{A_f + P_f + A_m + P_m}{2}, &
a_{12} &= \frac{A_f - P_f + P_m - A_m}{4}, \\
a_{21} &= A_f + P_f - A_m - P_m, &
a_{22} &= \frac{A_f + A_m - P_f - P_m}{2}.
\end{aligned}
```

The APIM predictors retain their original scale, whereas the DSM
predictor level is grand-mean centered. If $`\mu_X`$ is the grand mean
subtracted from the DSM predictor level, the intercepts therefore
transform as

``` math
a_{10} = \frac{\alpha_f + \alpha_m}{2} + \mu_X a_{11}, \qquad
a_{20} = \alpha_f - \alpha_m + \mu_X a_{21}.
```

The reverse slope transformation is

``` math
\begin{aligned}
A_f &= \frac{a_{11}}{2} + a_{12} + \frac{a_{21}}{4} + \frac{a_{22}}{2}, &
P_f &= \frac{a_{11}}{2} - a_{12} + \frac{a_{21}}{4} - \frac{a_{22}}{2}, \\
A_m &= \frac{a_{11}}{2} - a_{12} - \frac{a_{21}}{4} + \frac{a_{22}}{2}, &
P_m &= \frac{a_{11}}{2} + a_{12} - \frac{a_{21}}{4} - \frac{a_{22}}{2}.
\end{aligned}
```

Similarly,

``` math
\alpha_f = a_{10} + \frac{a_{20}}{2}
- \mu_X\left(a_{11} + \frac{a_{21}}{2}\right),
```

``` math
\alpha_m = a_{10} - \frac{a_{20}}{2}
- \mu_X\left(a_{11} - \frac{a_{21}}{2}\right).
```

The following comparison applies the APIM-to-DSM transformation to all
six fixed effects:

    #> From APIM model:
    #>    female intercept:        -4.369 
    #>    female actor effect:     1.672 
    #>    female partner effect:   0.249 
    #>    male intercept:          -6.038 
    #>    male actor effect:       1.805 
    #>    male partner effect:     0.255 
    #>    centering constant:      5.148 
    #> 
    #>  DSM transformation:
    #>    a10 = (female intercept + male intercept) / 2 +
    #>           mu_X * a11:                                       5.043 
    #>    a11 = (female actor + female partner + male actor +
    #>           male partner) / 2:                                1.99 
    #>    a12 = (female actor - female partner + male partner -
    #>           male actor) / 4:                                  -0.032 
    #>    a20 = female intercept - male intercept + mu_X * a21:    0.956 
    #>    a21 = female actor + female partner - male actor -
    #>           male partner:                                     -0.138 
    #>    a22 = (female actor + male actor - female partner -
    #>           male partner) / 2:                                1.486 
    #> 
    #>  From DSM model:
    #>    outcome-level intercept (a10):        5.043 
    #>    level -> level (a11):                 1.99 
    #>    difference -> level (a12):            -0.032 
    #>    outcome-difference intercept (a20):   0.956 
    #>    level -> difference (a21):            -0.138 
    #>    difference -> difference (a22):       1.486

### Random-effect transformation

Let $`u_f`$ and $`u_m`$ be the APIM random effects for the female and
male outcomes. The DSM outcome-level and outcome-difference residuals
are the same random effects expressed in different coordinates:

``` math
\begin{pmatrix} r_{YL} \\ r_{YD} \end{pmatrix}
=
\begin{pmatrix} 1/2 & 1/2 \\ 1 & -1 \end{pmatrix}
\begin{pmatrix} u_f \\ u_m \end{pmatrix}.
```

Applying this rotation to the APIM covariance matrix reproduces the DSM
random intercept variance, intercept-slope covariance, and role-slope
variance:

``` r

apim_vcov <- as.matrix(glmmTMB::VarCorr(apim_model)$cond$coupleID)
dsm_vcov <- as.matrix(glmmTMB::VarCorr(dsm_model)$cond$coupleID)

rotation <- rbind(
  outcome_level = c(0.5, 0.5),
  outcome_difference = c(1, -1)
)
apim_to_dsm_vcov <- rotation %*% apim_vcov %*% t(rotation)

data.frame(
  parameter = c("Var(r_YL)", "Cov(r_YL, r_YD)", "Var(r_YD)"),
  from_DSM = round(c(
    dsm_vcov[1, 1],
    dsm_vcov[1, 2],
    dsm_vcov[2, 2]
  ), 3),
  from_APIM_transformation = round(c(
    apim_to_dsm_vcov[1, 1],
    apim_to_dsm_vcov[1, 2],
    apim_to_dsm_vcov[2, 2]
  ), 3)
)
#>         parameter from_DSM from_APIM_transformation
#> 1       Var(r_YL)    0.632                    0.632
#> 2 Cov(r_YL, r_YD)   -0.240                   -0.240
#> 3       Var(r_YD)    3.678                    3.678
```

For exchangeable dyads, the direction of a member difference is
arbitrary. The directional intercept, both cross-paths, and the
covariance between outcome level and outcome difference must then be
zero. The remaining reduced, label-invariant DSM is algebraically the
Gaussian Dyad-Individual Model (DIM). In `interdep`, use
`model_type = "dim"` for this exchangeable model and reserve
`model_type = "dsm"` for distinguishable dyads.

------------------------------------------------------------------------

Continue with the [Dyad-Individual Model
vignette](https://pascal-kueng.github.io/interdep/articles/dim.md),

refer to the:

- [Actor-Partner Interdependence Model (APIM)
  vignette](https://pascal-kueng.github.io/interdep/articles/apim.md),
- [Mixed-Composition APIM
  vignette](https://pascal-kueng.github.io/interdep/articles/mixed-apim.md),

or return to the
[Overview](https://pascal-kueng.github.io/interdep/articles/index.md).

## References

Iida, Masumi, Gwendolyn Seidman, and Patrick E. Shrout. 2018. “Models of
Interdependent Individuals Versus Dyadic Processes in Relationship
Research.” *Journal of Social and Personal Relationships* 35 (1): 59–88.
<https://doi.org/10.1177/0265407517725407>.
