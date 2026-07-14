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
DSM predictor scores and their relationship to APIM effects in
distinguishable dyads, see the [Dyadic Score Model
vignette](https://pascal-kueng.github.io/interdep/articles/dsm.md).

> This vignette is under construction and for now only contains a few
> preliminary example models. Please check back soon!

## The cross sectional Gaussian distinguishable APIM

![Path diagram for a distinguishable cross-sectional APIM. Female and
male predictors each have an actor path to their own outcome and a
partner path to the other member's outcome. The female and male outcome
residuals
covary.](apim_files/figure-html/distinguishable-apim-diagram-1.png)

Conceptual cross-sectional APIM for distinguishable female-male dyads.
Actor and partner effects can differ by the role of the outcome member,
and the two outcome residuals covary within dyads.

Here, $`a_f`$ and $`a_m`$ are the actor effects on the female and male
outcomes, whereas $`p_f`$ and $`p_m`$ are the corresponding partner
effects. All four paths can differ in a distinguishable APIM.

We first prepare the example data with
[`prepare_interdep_data()`](https://pascal-kueng.github.io/interdep/reference/prepare_interdep_data.md):

``` r

apim_distinguishable_data <- prepare_interdep_data(
  data = example_dyadic_crosssectional,
  group = coupleID,
  member = personID,
  role = gender,
  predictors = communication,
  model_type = "apim"
)
```

The generated `.i_*` columns can be used directly in the model formula.
Here is a simple example:

``` r

apim_distinguishable_model <- glmmTMB::glmmTMB(
  satisfaction ~

    # Gender-specific intercepts
    0 +
    .i_is_female_x_male_female +
    .i_is_female_x_male_male +

    # Gender-specific actor effects
    .i_is_female_x_male_female:.i_communication_actor +
    .i_is_female_x_male_male:.i_communication_actor +

    # Gender-specific partner effects
    .i_is_female_x_male_female:.i_communication_partner +
    .i_is_female_x_male_male:.i_communication_partner +

    # Dyad-level unstructured random effects represent the two partner
    # residual variances and their covariance when dispformula = ~ 0.
    # This is glmmTMB-specific syntax! lme4 and brms use different syntax.
    us(0 +
         .i_is_female_x_male_female +
         .i_is_female_x_male_male
       | coupleID)

  , dispformula = ~ 0
  , family = gaussian()
  , data = apim_distinguishable_data
)
```

### Residual random-effects structure

For a distinguishable female-male dyad, the two members can have
different residual variances. Their residual covariance matrix is

``` math
\Sigma_{FM} =
\begin{pmatrix}
\sigma_{FM,F}^2 & c_{FM} \\
c_{FM} & \sigma_{FM,M}^2
\end{pmatrix}.
```

With one outcome row per member, this structure is estimated with an
unstructured random-effects block such as
`us(0 + .i_is_female_x_male_female + .i_is_female_x_male_male | coupleID)`
and `dispformula = ~ 0`. The two indicator columns select the female and
male rows, respectively. The `us()` block estimates both variances and
their covariance.

### Interpretation

## The cross-sectional Gaussian exchangeable APIM

![Path diagram for an exchangeable cross-sectional APIM. Each member's
predictor has the same actor effect on their own outcome and the same
partner effect on the other member's outcome. The two outcome residuals
have equal variances and
covary.](apim_files/figure-html/exchangeable-apim-diagram-1.png)

Conceptual cross-sectional APIM for exchangeable dyads. The two members
share one actor effect and one partner effect; their outcome residuals
have equal variances and covary within dyads.

Because the member labels are arbitrary, swapping members 1 and 2 does
not change the model. The two actor paths therefore share the
coefficient $`a`$, and the two partner paths share the coefficient
$`p`$. The two residual variances are also constrained to be equal,
while their covariance is estimated.

### Assumptions

### Residual random-effects structure and back-transformation

For an exchangeable dyad, `interdep` generates an arbitrary
member-difference column, named `.i_diff_*`, that is `+1` for one member
and `-1` for the other. The exchangeable residual structure is
represented by two separate random-effects terms: a shared dyad random
intercept and a random coefficient for this difference column (del
Rosario and West 2025). If their random effects are denoted by
$`u_{Mj}`$ and $`u_{Dj}`$, the two members receive

``` math
r_{1j} = u_{Mj} + u_{Dj}, \qquad
r_{2j} = u_{Mj} - u_{Dj}.
```

Because the shared and difference effects are fitted in separate
random-effects terms, they are uncorrelated. Writing their variances as
$`\sigma_M^2`$ and $`\sigma_D^2`$ gives

``` math
\begin{pmatrix}
u_{Mj} \\
u_{Dj}
\end{pmatrix}
\sim
\mathcal{N}
\left[
\begin{pmatrix}
0 \\
0
\end{pmatrix},
\begin{pmatrix}
\sigma_M^2 & 0 \\
0 & \sigma_D^2
\end{pmatrix}
\right].
```

The implied member-level residual covariance matrix is therefore

``` math
\Sigma =
\begin{pmatrix}
\sigma_M^2 + \sigma_D^2 & \sigma_M^2 - \sigma_D^2 \\
\sigma_M^2 - \sigma_D^2 & \sigma_M^2 + \sigma_D^2
\end{pmatrix}.
```

Thus, both members have the same residual variance
$`V = \sigma_M^2 + \sigma_D^2`$, their covariance is
$`C = \sigma_M^2 - \sigma_D^2`$, and their residual correlation is
$`C/V`$. Conversely, the shared and difference variances can be
recovered from a member-level variance and covariance as

``` math
\sigma_M^2 = \frac{V + C}{2}, \qquad
\sigma_D^2 = \frac{V - C}{2}.
```

Reversing the arbitrary `+1/-1` assignment changes the sign of
$`u_{Dj}`$ but not its variance or the implied member-level covariance
matrix. In longitudinal models, the same transformation applies
separately to stable dyad-level and same-occasion dyad-level covariance
blocks.

### Interpretation

## Testing distinguishability

Distinguishability can be evaluated by comparing a full model in which
the two roles may differ with a restricted exchangeable model. This
comparison tests the imposed equality constraints jointly. Here, they
concern the fixed intercepts, actor effects, partner effects, and
residual variances.

The two parameterizations require different generated columns. The full
distinguishable model was fitted above, so we now prepare the same
original observations as exchangeable:

``` r

apim_exchangeable_data <- prepare_interdep_data(
  example_dyadic_crosssectional,
  group = coupleID,
  member = personID,
  role = gender,
  predictors = communication,
  set_exchangeable_compositions = "female-male"
)
```

The exchangeable model constrains the corresponding fixed effects and
residual variances to be equal across members:

``` r

apim_exchangeable_model <- glmmTMB::glmmTMB(
  satisfaction ~ 0 +
    .i_is_female_x_male +
    .i_communication_actor +
    .i_communication_partner +
    (0 + .i_is_female_x_male | coupleID) +
    (0 + .i_diff_female_x_male_arbitrary | coupleID),
  dispformula = ~ 0,
  family = gaussian(),
  data = apim_exchangeable_data
)
```

[`compare_interdep_models()`](https://pascal-kueng.github.io/interdep/reference/compare_interdep_models.md)
verifies that both models use equivalent original observations before
performing the likelihood-ratio test:

``` r

compare_interdep_models(
  restricted = apim_exchangeable_model,
  full = apim_distinguishable_model
)
#> Likelihood-ratio test for nested models fitted to equivalent interdep data
#> Mathematical nesting is assumed and cannot be verified from the data alone.
#> 
#>                            Df    AIC    BIC  logLik deviance  Chisq Chi Df
#> apim_exchangeable_model     5 603.98 619.84 -296.99   593.98              
#> apim_distinguishable_model  9 589.49 618.03 -285.75   571.49 22.492      4
#>                            Pr(>Chisq)    
#> apim_exchangeable_model                  
#> apim_distinguishable_model  0.0001599 ***
#> ---
#> Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
#> 
#> Under the assumed nesting and chi-squared reference distribution, the test provides evidence that `apim_exchangeable_model` fits the data worse than `apim_distinguishable_model` (likelihood-ratio test: χ²(4) = 22.49, p < .001).
```

The test provides evidence against all restrictions jointly, but it does
not show which parameter differs. The helper also cannot determine
whether the models are mathematically nested; that remains a modeling
requirement. The usual chi-squared reference distribution may be
unreliable when a tested variance parameter lies on its boundary.

## Intensive longitudinal APIMs

### Concurrent ILD Gaussian APIM for distinguishable dyads

Observed person means used to construct the between-person (`cbp`)
predictors can be unreliable when each member contributes few occasions,
which can bias between-person estimates (Gottfredson 2019).

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

### Concurrent ILD Gaussian APIM for exchangeable dyads

### Current limitations of dyadic ILD designs in R

#### Dynamic models

The preparation shown in the Getting Started vignette supports
contemporaneous models, but observations can also remain dependent over
time. Currently, commonly used open-source MLM interfaces in R do not
provide the full dyadic residual VAR structure needed to model serial
dependence across both partners. Within open-source R, such a model
generally requires custom TMB or Stan code.

One practical alternative, especially when carryover and temporal
dynamics are part of the research question, is to create a dynamic model
by including lagged versions of the outcome as predictors.

For this example, we obtain the lagged actor and partner outcome columns
through the `lag_predictors` argument:

``` r

ild_apim_data_dynamic <- prepare_interdep_data(
  example_dyadic_ILD,
  group = coupleID,
  member = personID,
  time = diaryday,
  predictors = closeness,
  lag_predictors = closeness,
  model_type = "apim",
  seed = 123
)
```

A simple fixed-slope dyadic stability and influence model (del Rosario
and West 2025):

``` r

stability_influence <- glmmTMB::glmmTMB(
  closeness ~ 1 +

    # Stability (actor effect across time)
    .i_closeness_actor_lag1 +

    # Influence (partner effect across time)
    .i_closeness_partner_lag1 +

    # Linear time trend
    diaryday +

    # Stable exchangeable dyad-level covariance
    (1 | coupleID) +
    (0 + .i_diff_assumed_exchangeable_arbitrary | coupleID) +

    # Same-day exchangeable dyad-level covariance
    (1 | coupleID:diaryday) +
    (0 + .i_diff_assumed_exchangeable_arbitrary | coupleID:diaryday)

  , dispformula = ~ 0
  , family = gaussian()
  , data = ild_apim_data_dynamic
)

summary(stability_influence)
#>  Family: gaussian  ( identity )
#> Formula:          
#> closeness ~ 1 + .i_closeness_actor_lag1 + .i_closeness_partner_lag1 +  
#>     diaryday + (1 | coupleID) + (0 + .i_diff_assumed_exchangeable_arbitrary |  
#>     coupleID) + (1 | coupleID:diaryday) + (0 + .i_diff_assumed_exchangeable_arbitrary |  
#>     coupleID:diaryday)
#> Dispersion:                 ~0
#> Data: ild_apim_data_dynamic
#> 
#>       AIC       BIC    logLik -2*log(L)  df.resid 
#>    2929.0    2968.0   -1456.5    2913.0       967 
#> 
#> Random effects:
#> 
#> Conditional model:
#>  Groups              Name                                   Variance Std.Dev.
#>  coupleID            (Intercept)                            0.9161   0.9571  
#>  coupleID.1          .i_diff_assumed_exchangeable_arbitrary 0.5742   0.7578  
#>  coupleID.diaryday   (Intercept)                            0.3925   0.6265  
#>  coupleID.diaryday.1 .i_diff_assumed_exchangeable_arbitrary 0.5234   0.7235  
#> Number of obs: 975, groups:  coupleID, 40; coupleID:diaryday, 497
#> 
#> Conditional model:
#>                            Estimate Std. Error z value Pr(>|z|)    
#> (Intercept)                4.213120   0.300184  14.035  < 2e-16 ***
#> .i_closeness_actor_lag1    0.143973   0.035326   4.076 4.59e-05 ***
#> .i_closeness_partner_lag1  0.028758   0.035386   0.813    0.416    
#> diaryday                  -0.005281   0.007643  -0.691    0.490    
#> ---
#> Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
```

This model can be extended with contemporaneous actor and partner
predictor associations and other lagged predictors. Time-varying
predictors should usually be separated into within-person and
between-person components. Their contemporaneous coefficients are then
conditional on both partners’ prior outcomes.

**Note:** Person-mean centering a lagged outcome can introduce Nickell
bias, especially in shorter time series (Hamaker and Grasman 2015;
Nickell 1981; Gistelinck et al. 2021). Refer to the [DIM
vignette](https://pascal-kueng.github.io/interdep/articles/dim.md) for a
fuller discussion of exchangeable models.

------------------------------------------------------------------------

From here, choose the model-specific vignette that matches the research
question:

- [Mixed-Composition APIM
  vignette](https://pascal-kueng.github.io/interdep/articles/mixed-apim.md)
  for analyses combining distinguishable and exchangeable dyad
  compositions;
- [Dyad-Individual Model
  vignette](https://pascal-kueng.github.io/interdep/articles/dim.md) for
  the exchangeable DIM parameterization; or
- [Dyadic Score Model
  vignette](https://pascal-kueng.github.io/interdep/articles/dsm.md) for
  the distinguishable DSM parameterization.

Or return to the
[Overview](https://pascal-kueng.github.io/interdep/articles/index.md).

A vignette with non-Gaussian generalized APIM examples is planned.

## References

Gistelinck, Fien, Tom Loeys, and Nele Flamant. 2021. “Multilevel
Autoregressive Models When the Number of Time Points Is Small.”
*Structural Equation Modeling: A Multidisciplinary Journal* 28 (1):
15–27. <https://doi.org/10.1080/10705511.2020.1753517>.

Gottfredson, Nisha C. 2019. “A Straightforward Approach for Coping with
Unreliability of Person Means When Parsing Within-Person and
Between-Person Effects in Longitudinal Studies.” *Addictive Behaviors*
94: 156–61. <https://doi.org/10.1016/j.addbeh.2018.09.031>.

Hamaker, Ellen L., and Raoul P. P. P. Grasman. 2015. “To Center or Not
to Center? Investigating Inertia with a Multilevel Autoregressive
Model.” *Frontiers in Psychology* 5: 1492.
<https://doi.org/10.3389/fpsyg.2014.01492>.

Nickell, Stephen. 1981. “Biases in Dynamic Models with Fixed Effects.”
*Econometrica* 49 (6): 1417–26. <https://doi.org/10.2307/1911408>.

Rosario, Kareena S. del, and Tessa V. West. 2025. “A Practical Guide to
Specifying Random Effects in Longitudinal Dyadic Multilevel Modeling.”
*Advances in Methods and Practices in Psychological Science* 8 (3):
25152459251351286. <https://doi.org/10.1177/25152459251351286>.
