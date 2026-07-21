# Actor-Partner Interdependence Model (APIM)

``` r

library(dyadMLM)
has_glmmTMB <- requireNamespace("glmmTMB", quietly = TRUE)
apim_distinguishable_fitted_alt <-
  "Fitted distinguishable APIM diagram unavailable."
apim_exchangeable_fitted_alt <-
  "Fitted exchangeable APIM diagram unavailable."
```

> This vignette is under construction and preliminary. Please check back
> soon!

This vignette focuses on the Gaussian cross-sectional and intensive
longitudinal Actor-Partner Interdependence model for distinguishable and
exchangeable dyads.

For the broader package workflow and an overview of the available
model-specific vignettes, including the [Dyad-Individual
Model](https://pascal-kueng.github.io/dyadMLM/articles/dim.md) and
[Dyadic Score
Model](https://pascal-kueng.github.io/dyadMLM/articles/dsm.md), see the
[online package overview](https://pascal-kueng.github.io/dyadMLM/).

A vignette for non-Gaussian generalized models is planned.

## Cross sectional APIMs

### The distinguishable APIM

A conceptual example for distinguishable female-male dyads:

![Path diagram for a distinguishable cross-sectional APIM. Female and
male outcomes have separate intercepts. Female and male predictors each
have an actor path to their own outcome and a partner path to the other
member's outcome. The female and male outcome residuals
covary.](apim_files/figure-html/distinguishable-apim-diagram-1.svg)

Conceptual cross-sectional APIM for distinguishable female-male dyads.
Intercepts $`b_\mathrm{0}`$, actor effects $`a`$, and partner effects
$`p`$ can differ by the role of the outcome member (F and M), and the
two outcome residuals covary within dyads.

For univariate MLM software like `glmmTMB`, this model is fitted in long
format with one outcome row per member, which can be visualized as:

![Two-panel path diagram for a distinguishable female-male APIM. The
female and male outcomes have separate intercepts. In the female outcome
panel, female X is the actor predictor and male X is the partner
predictor of female Y, with coefficients a F and p F. In the male
outcome panel, male X is the actor predictor and female X is the partner
predictor of male Y, with coefficients a M and p M. The female and male
outcome residuals
covary.](apim_files/figure-html/distinguishable-apim-member-diagram-1.svg)

Individual-level representation of the distinguishable cross-sectional
APIM used for the long-format multilevel model. For the female outcome,
the female predictor is the actor predictor and the male predictor is
the partner predictor; these roles reverse for the male outcome.
Intercepts, actor coefficients, and partner coefficients may differ by
outcome role, and the two member residuals may have different variances
and covary.

#### Residual random-effects structure

For a distinguishable female-male dyad, the two members can have
different residual variances. The within-dyad residual covariance block
(shared across dyads) is:

``` math
\operatorname{Cov}
\begin{pmatrix}
\epsilon_{Fi} \\
\epsilon_{Mi}
\end{pmatrix}
= \boldsymbol{\Sigma}_{\epsilon}
= \begin{bmatrix}
\sigma_{\epsilon_F}^{2}
& \rho_{\epsilon_F\epsilon_M}\sigma_{\epsilon_F}\sigma_{\epsilon_M} \\
\rho_{\epsilon_F\epsilon_M}\sigma_{\epsilon_F}\sigma_{\epsilon_M}
& \sigma_{\epsilon_M}^{2}
\end{bmatrix}
```

And the full residual covariance matrix for all dyads (first three
shown) is then block-diagonal:

``` math
\boldsymbol{\Sigma}_{\mathrm{model}}
= \begin{bmatrix}
\boldsymbol{\Sigma}_{\epsilon} & \boldsymbol{0} & \boldsymbol{0} & \cdots \\
\boldsymbol{0} & \boldsymbol{\Sigma}_{\epsilon} & \boldsymbol{0} & \cdots \\
\boldsymbol{0} & \boldsymbol{0} & \boldsymbol{\Sigma}_{\epsilon} & \cdots \\
\vdots & \vdots & \vdots & \ddots
\end{bmatrix}
```

This structure is estimated with an unstructured random-effects block
such as
`us(0 + .dy_is_female_x_male_female + .dy_is_female_x_male_male | coupleID)`
and `dispformula = ~ 0`.

#### Fitting the distinguishable APIM with glmmTMB

We first prepare the example data with
[`dyadMLM::prepare_dyad_data()`](https://pascal-kueng.github.io/dyadMLM/reference/prepare_dyad_data.md):

``` r

apim_distinguishable_data <- dyadMLM::prepare_dyad_data(
  data = example_dyadic_crosssectional,
  dyad = coupleID,
  member = personID,
  role = gender,
  predictors = communication,
  model_types = "apim"
)

print(apim_distinguishable_data, n=4)
#> # dyadMLM data
#> # Rows: 190 | Dyads: 95 | Intensive longitudinal: no
#> # Structure: dyad = coupleID, member = personID, role = gender
#> #
#> # Dyad compositions:
#> # female_x_male distinguishable 95 dyads
#> #
#> # Added columns:
#> #   .dy_composition       inferred dyad composition
#> #   .dy_composition_role  composition-specific member role
#> #   .dy_is_{comp-role}    composition-role indicator columns
#> #   .dy_{pred}_actor      APIM actor predictor: actor's original predictor
#> #                         values
#> #   .dy_{pred}_partner    APIM partner predictor: partner's original predictor
#> #                         values
#> #
#> # A tibble: 190 × 11
#>   personID coupleID gender communication satisfaction .dy_composition
#>      <int>    <int> <fct>          <dbl>        <dbl> <fct>          
#> 1        1        1 female          4.79         4.37 female_x_male  
#> 2        2        1 male            3.80         2.34 female_x_male  
#> 3        3        2 female          2.91         2.44 female_x_male  
#> 4        4        2 male            6.51         6.08 female_x_male  
#> # ℹ 186 more rows
#> # ℹ 5 more variables: .dy_composition_role <fct>,
#> #   .dy_is_female_x_male_female <dbl>, .dy_is_female_x_male_male <dbl>,
#> #   .dy_communication_actor <dbl>, .dy_communication_partner <dbl>
```

The generated `.dy_*` columns can be used directly in the model formula.
Here is a simple example:

``` r

apim_distinguishable_model <- glmmTMB::glmmTMB(
  satisfaction ~

    # Gender-specific intercepts
    0 +
    .dy_is_female_x_male_female +
    .dy_is_female_x_male_male +

    # Gender-specific actor effects
    .dy_is_female_x_male_female:.dy_communication_actor +
    .dy_is_female_x_male_male:.dy_communication_actor +

    # Gender-specific partner effects
    .dy_is_female_x_male_female:.dy_communication_partner +
    .dy_is_female_x_male_male:.dy_communication_partner +

    # Dyad-level unstructured random effects represent the two partner
    # residual variances and their covariance when dispformula = ~ 0.
    # This is glmmTMB-specific syntax! `brms` uses different syntax.
    us(0 +
         .dy_is_female_x_male_female +
         .dy_is_female_x_male_male
       | coupleID)

  , dispformula = ~ 0
  , family = gaussian()
  , data = apim_distinguishable_data
)

summary(apim_distinguishable_model)
#>  Family: gaussian  ( identity )
#> Formula:          
#> satisfaction ~ 0 + .dy_is_female_x_male_female + .dy_is_female_x_male_male +  
#>     .dy_is_female_x_male_female:.dy_communication_actor + .dy_is_female_x_male_male:.dy_communication_actor +  
#>     .dy_is_female_x_male_female:.dy_communication_partner + .dy_is_female_x_male_male:.dy_communication_partner +  
#>     us(0 + .dy_is_female_x_male_female + .dy_is_female_x_male_male |  
#>         coupleID)
#> Dispersion:                    ~0
#> Data: apim_distinguishable_data
#> 
#>       AIC       BIC    logLik -2*log(L)  df.resid 
#>     589.5     618.0    -285.7     571.5       167 
#> 
#> Random effects:
#> 
#> Conditional model:
#>  Groups   Name                        Variance Std.Dev. Corr  
#>  coupleID .dy_is_female_x_male_female 1.311    1.145          
#>           .dy_is_female_x_male_male   1.792    1.339    -0.19 
#> Number of obs: 176, groups:  coupleID, 88
#> 
#> Conditional model:
#>                                                       Estimate Std. Error
#> .dy_is_female_x_male_female                           -4.36874    0.59416
#> .dy_is_female_x_male_male                             -6.03808    0.69452
#> .dy_is_female_x_male_female:.dy_communication_actor    1.67170    0.10089
#> .dy_is_female_x_male_male:.dy_communication_actor      1.80495    0.10562
#> .dy_is_female_x_male_female:.dy_communication_partner  0.24930    0.09035
#> .dy_is_female_x_male_male:.dy_communication_partner    0.25453    0.11793
#>                                                       z value Pr(>|z|)    
#> .dy_is_female_x_male_female                            -7.353 1.94e-13 ***
#> .dy_is_female_x_male_male                              -8.694  < 2e-16 ***
#> .dy_is_female_x_male_female:.dy_communication_actor    16.570  < 2e-16 ***
#> .dy_is_female_x_male_male:.dy_communication_actor      17.090  < 2e-16 ***
#> .dy_is_female_x_male_female:.dy_communication_partner   2.759  0.00579 ** 
#> .dy_is_female_x_male_male:.dy_communication_partner     2.158  0.03090 *  
#> ---
#> Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
```

The estimated coefficients map as follows:

![Fitted distinguishable APIM. Female and male intercepts -4.37 and
-6.04; actor effects 1.67 and 1.80; partner effects 0.25 and 0.25;
residual SDs 1.15 and 1.34, with correlation
-0.19.](apim_files/figure-html/fitted-distinguishable-apim-diagram-1.svg)

Fitted cross-sectional distinguishable APIM for the example data. Fixed
effects, residual standard deviations, and the residual correlation are
extracted from the fitted model.

### The exchangeable APIM

Conceptually, the exchangeable APIM constrains several of the effects to
be equal:

![Path diagram for an exchangeable cross-sectional APIM. Both outcomes
have the same intercept. Each member's predictor has the same actor
effect on their own outcome and the same partner effect on the other
member's outcome. The two outcome residuals have equal variances and
covary.](apim_files/figure-html/exchangeable-apim-diagram-1.svg)

Conceptual cross-sectional APIM for exchangeable dyads. The two members
share one intercept, one actor effect, and one partner effect. Their
outcome residuals have equal variances, yet still covary within dyads.

Because the member labels are arbitrary, swapping members 1 and 2 does
**not** change the model.

To estimate this model in a univariate MLM framework, we can draw a
conceptual diagram as such:

![Two-panel path diagram for an exchangeable APIM. Both outcomes have
the same intercept. For arbitrary member 1, X 1 is the actor predictor
and X 2 is the partner predictor of Y 1. For arbitrary member 2, X 2 is
the actor predictor and X 1 is the partner predictor of Y 2. Both panels
use the same actor coefficient a and partner coefficient p, and their
outcome residuals
covary.](apim_files/figure-html/exchangeable-apim-member-diagram-1.svg)

Individual-level representation of the exchangeable cross-sectional APIM
used for the long-format multilevel model. Both members share the same
intercept. Each member’s own predictor has the shared actor effect, and
the other member’s predictor has the shared partner effect. The two
residual variances are equal and the residuals may covary.

#### Modeling the residual random-effects structure

Currently, glmmTMB and brms allow us to specify the relevant residual
correlation structure, but any additional random effects structure that
includes more than just a random intercept presents a problem:

For instance, in glmmTMB the expression
`homcs(0 + arbitrary_member_1 + arbitrary_member_2 | coupleID)` would
achieve in setting both residual variances equal while still estimating
a correlation between the residuals. However, if we want to model
intensive longitudinal data, like we do below, using
`homcs(0 + arbitrary_member_1 + arbitrary_member_2 + time:arbitrary_member1 + arbitrary_member_2 | coupleID)`
would impose a single variance shared by both intercepts *and* both time
slopes.
`homcs(0 + arbitrary_member_1 + arbitrary_member_2) + homcs(time:arbitrary_member1 + arbitrary_member_2 | coupleID)`
would produce the correct variance restrictions, but does then not model
a correlation between slopes and intercepts anymore.

Therefore, we introduce a solution that works for residuals and other
random effect terms regardless of slopes. Following del Rosario and West
(2025),
[`dyadMLM::prepare_dyad_data()`](https://pascal-kueng.github.io/dyadMLM/reference/prepare_dyad_data.md)
generates an arbitrary member-difference column, named
`.dy_member_contrast_*`, that is `+1` for one member and `-1` for the
other. The exchangeable residual structure is represented by two
separate random-effects terms: a shared dyad random intercept and a
random coefficient for this difference column.

We will now fit the model and then use the
[`dyadMLM::recover_exchangeable_covariance()`](https://pascal-kueng.github.io/dyadMLM/reference/recover_exchangeable_covariance.md)
function that back-transforms the structure to the often more
interpretable actor-partner residual-covariance matrix we are used to.

#### Fitting the exchangeable APIM with glmmTMB

We use the same dataset as before, but do not distinguish males and
females, so we can test distinguishability later. Another option here
would be to omit roles, especially if there is no clear role in the
data.

``` r

apim_exchangeable_data <- dyadMLM::prepare_dyad_data(
  example_dyadic_crosssectional,
  dyad = coupleID,
  member = personID,
  role = gender,
  predictors = communication,
  set_exchangeable_compositions = "female-male",
  seed = 123
)

print(apim_exchangeable_data, n = 4)
#> # dyadMLM data
#> # Rows: 190 | Dyads: 95 | Intensive longitudinal: no
#> # Structure: dyad = coupleID, member = personID, role = gender
#> #
#> # Dyad compositions:
#> # female_x_male exchangeable (set by user) 95 dyads
#> #
#> # Added columns:
#> #   .dy_composition                       inferred dyad composition
#> #   .dy_composition_role                  composition-specific member role
#> #   .dy_is_{comp-role}                    composition-role indicator columns
#> #   .dy_member_contrast_{comp}_arbitrary  composition-specific member contrasts
#> #                                         with arbitrary direction; 0 for
#> #                                         distinguishable dyads or other
#> #                                         exchangeable compositions
#> #   .dy_{pred}_actor                      APIM actor predictor: actor's
#> #                                         original predictor values
#> #   .dy_{pred}_partner                    APIM partner predictor: partner's
#> #                                         original predictor values
#> #
#> # A tibble: 190 × 11
#>   personID coupleID gender communication satisfaction .dy_composition
#>      <int>    <int> <fct>          <dbl>        <dbl> <fct>          
#> 1        1        1 female          4.79         4.37 female_x_male  
#> 2        2        1 male            3.80         2.34 female_x_male  
#> 3        3        2 female          2.91         2.44 female_x_male  
#> 4        4        2 male            6.51         6.08 female_x_male  
#> # ℹ 186 more rows
#> # ℹ 5 more variables: .dy_composition_role <fct>, .dy_is_female_x_male <dbl>,
#> #   .dy_member_contrast_female_x_male_arbitrary <dbl>,
#> #   .dy_communication_actor <dbl>, .dy_communication_partner <dbl>
```

We then use the columns to fit the model as follows:

``` r

apim_exchangeable_model <- glmmTMB::glmmTMB(
  satisfaction ~ 
    
    # Pooled single intercept
    1 +
    
    # Pooled single actor and partner effects
    .dy_communication_actor +
    .dy_communication_partner +
    
    # Residual variance covariance matrix via the shared/difference
    # specification in two uncorrelated blocks
    us(1 | coupleID) +
    us(0 + .dy_member_contrast_female_x_male_arbitrary | coupleID),
  dispformula = ~ 0,
  family = gaussian(),
  data = apim_exchangeable_data
)

summary(apim_exchangeable_model)
#>  Family: gaussian  ( identity )
#> Formula:          
#> satisfaction ~ 1 + .dy_communication_actor + .dy_communication_partner +  
#>     us(1 | coupleID) + us(0 + .dy_member_contrast_female_x_male_arbitrary |  
#>     coupleID)
#> Dispersion:                    ~0
#> Data: apim_exchangeable_data
#> 
#>       AIC       BIC    logLik -2*log(L)  df.resid 
#>     604.0     619.8    -297.0     594.0       171 
#> 
#> Random effects:
#> 
#> Conditional model:
#>  Groups     Name                                        Variance Std.Dev.
#>  coupleID   (Intercept)                                 0.6346   0.7966  
#>  coupleID.1 .dy_member_contrast_female_x_male_arbitrary 1.1532   1.0739  
#> Number of obs: 176, groups:  coupleID, 88
#> 
#> Conditional model:
#>                           Estimate Std. Error z value Pr(>|z|)    
#> (Intercept)                -5.2330     0.4103 -12.754  < 2e-16 ***
#> .dy_communication_actor     1.7578     0.0819  21.461  < 2e-16 ***
#> .dy_communication_partner   0.2379     0.0819   2.904  0.00368 ** 
#> ---
#> Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
```

We use the
[`dyadMLM::recover_exchangeable_covariance()`](https://pascal-kueng.github.io/dyadMLM/reference/recover_exchangeable_covariance.md)
to recover the interpretable variance-covariance matrix:

``` r

backtransformed <- dyadMLM::recover_exchangeable_covariance(apim_exchangeable_model)

# residual variance-covariance and SD-correlation representations
print(backtransformed)
#> Exchangeable residual covariance
#> 
#> Pair `pair_1`
#> Shared:     us(1 | coupleID)
#> Difference: us(0 + .dy_member_contrast_female_x_male_arbitrary | coupleID)
#> 
#> Variance-covariance:
#>                       member_1: (Intercept) member_2: (Intercept)
#> member_1: (Intercept)             1.7877999            -0.5186522
#> member_2: (Intercept)            -0.5186522             1.7877999
#> 
#> Standard deviations and correlations:
#>                       member_1: (Intercept) member_2: (Intercept)
#> member_1: (Intercept)             1.3370864            -0.2901064
#> member_2: (Intercept)            -0.2901064             1.3370864
```

The output can now be mapped as follows:

![Fitted exchangeable APIM. Intercept -5.23, actor effect 1.76, partner
effect 0.24, common residual SD 1.34, and residual correlation
-0.29.](apim_files/figure-html/fitted-exchangeable-apim-diagram-1.svg)

Fitted cross-sectional exchangeable APIM for the example data. The
common member residual standard deviation and residual correlation are
back-transformed from the fitted mean and difference components.

##### Fitted constraints and omitted blocks

The function can also recover the member-level implication of
constraints that were imposed when fitting the model. For example, we
can omit the entire shared block:

``` r

apim_exchangeable_model_no_shared <- glmmTMB::glmmTMB(
  satisfaction ~  1 +
    .dy_communication_actor +
    .dy_communication_partner +
    
    # Residual variance covariance matrix
    # omitting the us(1 | coupleID) block
    us(0 + .dy_member_contrast_female_x_male_arbitrary | coupleID),
  dispformula = ~ 0,
  family = gaussian(),
  data = apim_exchangeable_data
)

summary(apim_exchangeable_model_no_shared)
#>  Family: gaussian  ( identity )
#> Formula:          
#> satisfaction ~ 1 + .dy_communication_actor + .dy_communication_partner +  
#>     us(0 + .dy_member_contrast_female_x_male_arbitrary | coupleID)
#> Dispersion:                    ~0
#> Data: apim_exchangeable_data
#> 
#>         AIC         BIC      logLik   -2*log(L)    df.resid 
#>  7495052519  7495052532 -3747526256  7495052511         172 
#> 
#> Random effects:
#> 
#> Conditional model:
#>  Groups   Name                                        Variance Std.Dev.
#>  coupleID .dy_member_contrast_female_x_male_arbitrary 1.159    1.076   
#> Number of obs: 176, groups:  coupleID, 88
#> 
#> Conditional model:
#>                             Estimate Std. Error z value Pr(>|z|)    
#> (Intercept)               -5.233e+00  4.446e-05 -117705  < 2e-16 ***
#> .dy_communication_actor    1.764e+00  7.221e-02      24  < 2e-16 ***
#> .dy_communication_partner  2.317e-01  7.221e-02       3  0.00133 ** 
#> ---
#> Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
```

Since matching is now not automatically possible anymore, we need to
tell the function where both blocks are. Since we completely omitted one
block, we tell the function:

``` r

backtransformed <- dyadMLM::recover_exchangeable_covariance(
  apim_exchangeable_model_no_shared, 
  block_pairings = list(
    shared_block = NULL,
    difference_block = "us(0 + .dy_member_contrast_female_x_male_arbitrary | coupleID)",
    difference_indicator =".dy_member_contrast_female_x_male_arbitrary"
  )
)
#> Warning: Review possible residual-level structure:
#> 
#> Pair `pair_1` for `.dy_member_contrast_female_x_male_arbitrary` (group `coupleID`) may be residual-level: at most two fitted rows per group. Row-count check only; partner positions were not verified.
#> 
#> - Terms absent from the shared block: `(Intercept)`. The fitted model fixes their shared components at zero, implying equal and opposite member effects (correlation -1 when variance > 0; undefined at zero) and singular member covariance. If unintended, revise this block and refit.

# residual variance-covariance and SD-correlation representations
backtransformed
#> Exchangeable residual covariance
#> 
#> Pair `pair_1`
#> Shared:     <omitted>
#> Difference: us(0 + .dy_member_contrast_female_x_male_arbitrary | coupleID)
#> 
#> Variance-covariance:
#>                       member_1: (Intercept) member_2: (Intercept)
#> member_1: (Intercept)              1.158728             -1.158728
#> member_2: (Intercept)             -1.158728              1.158728
#> 
#> Standard deviations and correlations:
#>                       member_1: (Intercept) member_2: (Intercept)
#> member_1: (Intercept)              1.076442             -1.000000
#> member_2: (Intercept)             -1.000000              1.076442
```

If we fit a model that allows us to also specify higher-level random
effect terms, such as an intensive longitudinal model, we can also omit
individual terms from any of the two blocks to allow for several
restraints. Speficications such as
`diag(1 + x1 + x2 + x3 | coupleID) + homcs(0 + idiff + x3:idiff | coupleID)`
are possible, for instance.

Or something like like:
`(1 + x1 || coupleID) + (0 + x3:idiff | coupleID)`

#### Interpretation

### Testing distinguishability

Distinguishability can be evaluated by comparing a full model in which
the two roles may differ with a restricted exchangeable model. This
comparison tests the imposed equality constraints jointly. Here, they
concern the fixed intercepts, actor effects, partner effects, and
residual variances.

The two parameterizations require different generated columns. The full
distinguishable model was fitted above, so we now prepare the same
original observations as exchangeable:

[`dyadMLM::compare_nested_glmmTMB_models()`](https://pascal-kueng.github.io/dyadMLM/reference/compare_nested_glmmTMB_models.html)
verifies that both models use equivalent original observations before
performing the likelihood-ratio test:

``` r

dyadMLM::compare_nested_glmmTMB_models(
  apim_exchangeable_model,
  apim_distinguishable_model
)
#> Likelihood-ratio test for nested models fitted to equivalent data
#> Assumes mathematical nesting and an appropriate chi-squared reference distribution.
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
#> Conclusion (5% level): The likelihood-ratio test provides evidence that `apim_distinguishable_model` fits better than `apim_exchangeable_model` (p < 0.001).
```

The test provides evidence against all restrictions jointly, but it does
not show which parameter differs. The helper also cannot determine
whether the models are mathematically nested; that remains a modeling
requirement. The usual chi-squared reference distribution may be
unreliable when a tested variance parameter lies on its boundary.

### Intensive longitudinal APIMs

#### Concurrent ILD Gaussian APIM for distinguishable dyads

Observed person means used to construct the between-person (`cbp`)
predictors can be unreliable when each member contributes few occasions,
which can bias between-person estimates (Gottfredson 2019).

Example model specification:

``` r


ild_distinguishable_model <- glmmTMB::glmmTMB(
  closeness ~ 0 + 
    
    .dy_is_female_x_male_female +
    .dy_is_female_x_male_male +
    
    # Gender specific time trends
    .dy_is_female_x_male_female:diaryday +
    .dy_is_female_x_male_male:diaryday +
    
    # Gender-specific within-person actor effects
    .dy_is_female_x_male_female:.dy_provided_support_cwp_actor +
    .dy_is_female_x_male_male:.dy_provided_support_cwp_actor +

    # Gender-specific within-person partner effects
    .dy_is_female_x_male_female:.dy_provided_support_cwp_partner +
    .dy_is_female_x_male_male:.dy_provided_support_cwp_partner +
    
    # Gender-specific between-person actor effects
    .dy_is_female_x_male_female:.dy_provided_support_cbp_actor +
    .dy_is_female_x_male_male:.dy_provided_support_cbp_actor +

    # Gender-specific between-person partner effects
    .dy_is_female_x_male_female:.dy_provided_support_cbp_partner +
    .dy_is_female_x_male_male:.dy_provided_support_cbp_partner +
    
    # random effects for stable non-independence (means)
    us(0 + 
         .dy_is_female_x_male_female +
         .dy_is_female_x_male_male
       | coupleID)  +

    # Same-day residual covariance
    us(0 + 
         .dy_is_female_x_male_female +
         .dy_is_female_x_male_male
       | coupleID:diaryday) 

  , dispformula = ~ 0  
  , family = gaussian()
  , data = ild_distinguishable_data
)

summary(ild_distinguishable_model)
```

#### Concurrent ILD Gaussian APIM for exchangeable dyads

Following del Rosario and West, the stable dyad covariance can be
represented using sum-and-difference random effects (del Rosario and
West 2025). In longitudinal Gaussian APIMs fitted with `glmmTMB`, the
same parameterization can be extended to the dyad-occasion level to
represent same-occasion residual dependence.

##### Extension to exchangeable random slopes

The same shared/difference back-transformation applies to random slopes
(del Rosario and West 2025). For example, let $`u_{\mathrm{actor},j}`$
denote the shared actor random slope for dyad $`j`$ and
$`\widetilde{u}_{\mathrm{actor},j}`$ the corresponding
`.dy_member_contrast_*` random slope. The tilde marks random
coefficients from the member-difference block. The actor slopes for the
members assigned `+1` and `-1` are

``` math
u_{\mathrm{actor},1j}
= u_{\mathrm{actor},j} + \widetilde{u}_{\mathrm{actor},j},
\qquad
u_{\mathrm{actor},2j}
= u_{\mathrm{actor},j} - \widetilde{u}_{\mathrm{actor},j}.
```

Because the shared and `.dy_member_contrast_*` blocks are fitted as
separate random-effects terms, they are independent. Therefore,

``` math
\operatorname{Var}(u_{\mathrm{actor},1j})
= \operatorname{Var}(u_{\mathrm{actor},2j})
= \operatorname{Var}(u_{\mathrm{actor},j})
+ \operatorname{Var}(\widetilde{u}_{\mathrm{actor},j}),
```

and

``` math
\operatorname{Cov}(u_{\mathrm{actor},1j}, u_{\mathrm{actor},2j})
= \operatorname{Var}(u_{\mathrm{actor},j})
- \operatorname{Var}(\widetilde{u}_{\mathrm{actor},j}).
```

The same calculation applies to the partner slopes and random
intercepts. Any covariances among the random intercept, actor slope, and
partner slope can be back-transformed in the same way.

#### Current limitations of dyadic ILD designs in R

Concurrent dyadic ILD models can adjust for a time trend and account for
stable dyadic dependence and same-occasion partner dependence. They do
not model residual serial dependence, however, and therefore estimate
concurrent associations under the assumption that residuals from
different days are independent.

If the goal is to retain these concurrent APIM associations while
accounting for serial dependence, the closest extension is a dyadic
residual dynamic structural equation model (RDSEM). It keeps the
concurrent regression separate from a VAR model for its residuals
(Asparouhov and Muthén 2020; McNeish and Hamaker 2020). This
residual-VAR structure is not directly available through the `glmmTMB`
interface used here, and open-source support for dyadic dynamic models
remains very limited (del Rosario and West 2025). Within open-source R,
such a model generally requires custom TMB or Stan code.

##### Dynamic models

A **practical alternative** is a model with lagged outcomes, especially
when carryover or temporal dynamics are part of the research question
(Gistelinck and Loeys 2020). In such a model, the interpretation
changes. All APIM predictor effects then describe associations
conditional on the members’ prior outcomes.

By adding the outcome to `predictors` and selecting it with
`lag1_predictors`,
[`dyadMLM::prepare_dyad_data()`](https://pascal-kueng.github.io/dyadMLM/reference/prepare_dyad_data.md)
returns lag-1 raw and within-person scores alongside the contemporaneous
scores. Between-person scores are not lagged because they describe
stable differences between members.

For this example, we obtain the lagged actor and partner outcome columns
through the `lag1_predictors` argument:

``` r

ild_apim_data_dynamic <- dyadMLM::prepare_dyad_data(
  example_dyadic_ILD,
  dyad = coupleID,
  member = personID,
  time = diaryday,
  predictors = closeness,
  lag1_predictors = closeness,
  model_types = "apim",
  seed = 123
)
```

This returns all necessary variables for either choice, including lag-1
raw and within-person closeness scores. Lags are matched at exactly
`diaryday - 1`, so omitted diary days are not bridged.

A simple fixed-slope dyadic stability and influence model (del Rosario
and West 2025):

``` r

stability_influence <- glmmTMB::glmmTMB(
  closeness ~ 1 +

    # Stability (actor effect across time)
    .dy_closeness_actor_lag1 +

    # Influence (partner effect across time)
    .dy_closeness_partner_lag1 +

    # Linear time trend
    diaryday +

    # Stable exchangeable dyad-level covariance
    us(1 | coupleID) +
    us(0 + .dy_member_contrast_assumed_exchangeable_arbitrary | coupleID) +

    # Same-day exchangeable dyad-level covariance
    us(1 | coupleID:diaryday) +
    us(0 + .dy_member_contrast_assumed_exchangeable_arbitrary | coupleID:diaryday)

  , dispformula = ~ 0
  , family = gaussian()
  , data = ild_apim_data_dynamic
)

summary(stability_influence)
#>  Family: gaussian  ( identity )
#> Formula:          
#> closeness ~ 1 + .dy_closeness_actor_lag1 + .dy_closeness_partner_lag1 +  
#>     diaryday + us(1 | coupleID) + us(0 + .dy_member_contrast_assumed_exchangeable_arbitrary |  
#>     coupleID) + us(1 | coupleID:diaryday) + us(0 + .dy_member_contrast_assumed_exchangeable_arbitrary |  
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
#>  Groups              Name                                              
#>  coupleID            (Intercept)                                       
#>  coupleID.1          .dy_member_contrast_assumed_exchangeable_arbitrary
#>  coupleID.diaryday   (Intercept)                                       
#>  coupleID.diaryday.1 .dy_member_contrast_assumed_exchangeable_arbitrary
#>  Variance Std.Dev.
#>  0.9161   0.9571  
#>  0.5742   0.7578  
#>  0.3925   0.6265  
#>  0.5234   0.7235  
#> Number of obs: 975, groups:  coupleID, 40; coupleID:diaryday, 497
#> 
#> Conditional model:
#>                             Estimate Std. Error z value Pr(>|z|)    
#> (Intercept)                 4.213120   0.300184  14.035  < 2e-16 ***
#> .dy_closeness_actor_lag1    0.143973   0.035326   4.076 4.59e-05 ***
#> .dy_closeness_partner_lag1  0.028758   0.035386   0.813    0.416    
#> diaryday                   -0.005281   0.007643  -0.691    0.490    
#> ---
#> Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
```

This model can be extended with contemporaneous actor and partner
predictor associations and other lagged predictors. Time-varying
predictors should usually be separated into within-person and
between-person components. Their contemporaneous coefficients are then
conditional on both partners’ prior outcomes.

The model above uses raw lagged outcomes. The corresponding
within-person-centered lagged terms are `.dy_closeness_cwp_actor_lag1`
and `.dy_closeness_cwp_partner_lag1`.

Whether to use a raw or within-person-centered lagged outcome depends on
the research question and the data. Person-mean centering the outcome
lag can bias the average carryover estimate downward (Hamaker and
Grasman 2015). This downward bias is known as Nickell bias (Nickell
1981). A raw lag avoids this centering bias, but a standard
random-intercept model can still be biased because it assumes that the
lag is unrelated to stable member levels (Gistelinck et al. 2021).

Both problems matter most when there are few occasions. In one simple
simulation, most approaches other than person-mean centering performed
acceptably from about ten occasions, but this is not a universal cutoff
(Gistelinck et al. 2021). For shorter panels, consider an LD-APIM, which
lets the first outcomes relate to the members’ stable levels in a
wide-format SEM (Gistelinck and Loeys 2020).

These manifest-lag models are not equivalent to Mplus DSEM, which uses
latent person-mean centering by default and can estimate multivariate or
residual dynamics jointly (McNeish and Hamaker 2020). For very short
panels, however, default DSEM may still be biased or unstable, so the
LD-APIM recommendation above may be preferable (Gistelinck et al. 2021).

These lagged-outcome issues are separate from the earlier concern about
unreliable person means used to construct `cbp` predictors with few
occasions.

------------------------------------------------------------------------

From here, choose the model-specific vignette that matches the research
question:

- [Dyad-Individual Model
  vignette](https://pascal-kueng.github.io/dyadMLM/articles/dim.md) for
  the exchangeable DIM parameterization; or
- [Dyadic Score Model
  vignette](https://pascal-kueng.github.io/dyadMLM/articles/dsm.md) for
  the distinguishable DSM parameterization.

Or return to the [online package
overview](https://pascal-kueng.github.io/dyadMLM/).

A vignette with non-Gaussian generalized APIM examples is planned.

### References

Asparouhov, Tihomir, and Bengt Muthén. 2020. “Comparison of Models for
the Analysis of Intensive Longitudinal Data.” *Structural Equation
Modeling: A Multidisciplinary Journal* 27 (2): 275–97.
<https://doi.org/10.1080/10705511.2019.1626733>.

Gistelinck, Fien, and Tom Loeys. 2020. “Multilevel Autoregressive Models
for Longitudinal Dyadic Data.” *TPM - Testing, Psychometrics,
Methodology in Applied Psychology* 27 (3): 433–52.
<https://doi.org/10.4473/TPM27.3.7>.

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

McNeish, Daniel, and Ellen L. Hamaker. 2020. “A Primer on Two-Level
Dynamic Structural Equation Models for Intensive Longitudinal Data in
Mplus.” *Psychological Methods* 25 (5): 610–35.
<https://doi.org/10.1037/met0000250>.

Nickell, Stephen. 1981. “Biases in Dynamic Models with Fixed Effects.”
*Econometrica* 49 (6): 1417–26. <https://doi.org/10.2307/1911408>.

Rosario, Kareena S. del, and Tessa V. West. 2025. “A Practical Guide to
Specifying Random Effects in Longitudinal Dyadic Multilevel Modeling.”
*Advances in Methods and Practices in Psychological Science* 8 (3):
25152459251351286. <https://doi.org/10.1177/25152459251351286>.
