# Dyadic Score Model (DSM)

``` r

library(dyadMLM)
has_glmmTMB <- requireNamespace("glmmTMB", quietly = TRUE)
dsm_fitted_alt <- "Fitted DSM diagram unavailable."
```

This vignette focuses on the Dyadic Score Model (DSM) for
distinguishable dyads and its relationship to the distinguishable
Actor-Partner Interdependence Model (APIM). The DSM expresses
associations in terms of the dyad’s shared level and the directional
difference between partners (Iida et al. 2018).

For the broader package workflow and an overview of the available
model-specific vignettes, including the [Actor-Partner Interdependence
Model](https://pascal-kueng.github.io/dyadMLM/articles/apim.md),
[Mixed-Composition
APIM](https://pascal-kueng.github.io/dyadMLM/articles/mixed-apim.md),
and [Dyad-Individual
Model](https://pascal-kueng.github.io/dyadMLM/articles/dim.md), see the
[Overview](https://pascal-kueng.github.io/dyadMLM/articles/index.md).

## Preparing DSM Data

A DSM requires an explicitly declared direction. This direction should
be substantively meaningful when the directional coefficients are
interpreted. Here, `c("female", "male")` defines every difference as
female minus male.

``` r

cross_dsm_data <- dyadMLM::prepare_dyad_data(
  example_dyadic_crosssectional,
  group = coupleID,
  member = personID,
  role = gender,
  predictors = communication,
  model_type = "dsm",
  dsm_role_order = c("female", "male")
)

print(cross_dsm_data, n = 4)
#> # dyadMLM data
#> # Rows: 190 | Dyads: 95 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID, role = gender
#> # DSM direction: female - male
#> #
#> # Dyad compositions:
#> # female_x_male distinguishable 95 dyads
#> #
#> # Added columns:
#> #   .dy_composition              inferred dyad composition
#> #   .dy_composition_role         composition-specific member role
#> #   .dy_is_{comp-role}           composition-role indicator columns
#> #   .dy_dsm_role_contrast        DSM role contrast: +0.5 for the first declared
#> #                                role and -0.5 for the second declared role
#> #   .dy_{pred}_dyad_mean_gmc     dyad-mean predictor: dyad's average predictor
#> #                                level, grand-mean centered
#> #   .dy_{pred}_within_dyad_diff  DSM signed predictor difference: first
#> #                                declared role minus second declared role
#> #
#> # A tibble: 190 × 12
#>   personID coupleID gender communication satisfaction .dy_composition
#>      <int>    <int> <fct>          <dbl>        <dbl> <fct>          
#> 1        1        1 female          4.79         4.37 female_x_male  
#> 2        2        1 male            3.80         2.34 female_x_male  
#> 3        3        2 female          2.91         2.44 female_x_male  
#> 4        4        2 male            6.51         6.08 female_x_male  
#> # ℹ 186 more rows
#> # ℹ 6 more variables: .dy_composition_role <fct>,
#> #   .dy_is_female_x_male_female <dbl>, .dy_is_female_x_male_male <dbl>,
#> #   .dy_dsm_role_contrast <dbl>, .dy_communication_dyad_mean_gmc <dbl>,
#> #   .dy_communication_within_dyad_diff <dbl>
```

For predictor values $`X_{\mathrm{female}}`$ and $`X_{\mathrm{male}}`$,
`dyadMLM` then creates:

- `.dy_communication_dyad_mean_gmc` $`=
  \frac{X_{\mathrm{female}} + X_{\mathrm{male}}}{2} - \mu_X`$ (with
  $`\mu_X`$ representing the sample grand mean of the dyad-level
  predictor means)

- `.dy_communication_within_dyad_diff`
  $`= X_{\mathrm{female}} - X_{\mathrm{male}}`$

- `.dy_dsm_role_contrast` $`= +0.5`$ for female and $`-0.5`$ for male.

The dyad mean and signed difference are repeated on both member rows.
The outcome remains unchanged and no transformation is needed.

## Cross-Sectional Gaussian DSM

For a cross-sectional Gaussian DSM, a correlated dyad random intercept
and role-contrast slope represent unexplained outcome-level and
outcome-difference variation.

![Path diagram for a cross-sectional dyadic score model. The centered
female-male predictor mean and female-minus-male predictor difference
each predict the female-male outcome mean and female-minus-male outcome
difference. Paths are labelled a11, a12, a21, and a22, and outcome
intercepts are labelled a10 and
a20.](dsm_files/figure-html/conceptual-dsm-diagram-1.svg)

Conceptual cross-sectional DSM. Predictor mean and predictor difference
each predict both outcome scores.

The same model can be displayed in the individual-member rows used by
the long-format multilevel model.

![Two-panel path diagram for a female-minus-male dyadic score model.
Both panels contain the centered predictor mean and female-minus-male
predictor difference. For the female outcome, the intercept is a10 plus
half a20, the predictor-mean coefficient is a11 plus half a21, and the
predictor-difference coefficient is a12 plus half a22. For the male
outcome, the same combinations use minus signs. The two member residuals
covary.](dsm_files/figure-html/conceptual-dsm-member-diagram-1.svg)

Individual-level representation of the cross-sectional DSM used for the
long-format multilevel model. The centered predictor mean and
female-minus-male predictor difference appear on both member rows. For
the female outcome, the intercept and slopes add one-half of the
corresponding outcome-difference parameters. For the male outcome, they
subtract one-half. The female and male residuals may have different
variances and covary.

The path labels correspond directly to the terms in the model below:

``` r

dsm_model <- glmmTMB::glmmTMB(
  satisfaction ~

    # Outcome-level intercept
    1 +

    # Predictor level -> outcome level (a11)
    .dy_communication_dyad_mean_gmc +

    # Predictor difference -> outcome level (a12)
    .dy_communication_within_dyad_diff +

    # Outcome-difference intercept (a20)
    .dy_dsm_role_contrast +

    # Predictor level -> outcome difference (a21)
    .dy_communication_dyad_mean_gmc:.dy_dsm_role_contrast +

    # Predictor difference -> outcome difference (a22)
    .dy_communication_within_dyad_diff:.dy_dsm_role_contrast +

    # Outcome-level and outcome-difference residual variances and their covariance
    us(1 + .dy_dsm_role_contrast | coupleID),
  dispformula = ~ 0,
  family = gaussian(),
  data = cross_dsm_data
)

summary(dsm_model)
#>  Family: gaussian  ( identity )
#> Formula:          
#> satisfaction ~ 1 + .dy_communication_dyad_mean_gmc + .dy_communication_within_dyad_diff +  
#>     .dy_dsm_role_contrast + .dy_communication_dyad_mean_gmc:.dy_dsm_role_contrast +  
#>     .dy_communication_within_dyad_diff:.dy_dsm_role_contrast +  
#>     us(1 + .dy_dsm_role_contrast | coupleID)
#> Dispersion:                    ~0
#> Data: cross_dsm_data
#> 
#>       AIC       BIC    logLik -2*log(L)  df.resid 
#>     589.5     618.0    -285.7     571.5       167 
#> 
#> Random effects:
#> 
#> Conditional model:
#>  Groups   Name                  Variance Std.Dev. Corr  
#>  coupleID (Intercept)           0.632    0.795          
#>           .dy_dsm_role_contrast 3.678    1.918    -0.16 
#> Number of obs: 176, groups:  coupleID, 88
#> 
#> Conditional model:
#>                                                          Estimate Std. Error
#> (Intercept)                                               5.04256    0.08481
#> .dy_communication_dyad_mean_gmc                           1.99024    0.07834
#> .dy_communication_within_dyad_diff                       -0.03201    0.05372
#> .dy_dsm_role_contrast                                     0.95644    0.20459
#> .dy_communication_dyad_mean_gmc:.dy_dsm_role_contrast    -0.13847    0.18899
#> .dy_communication_within_dyad_diff:.dy_dsm_role_contrast  1.48641    0.12959
#>                                                          z value Pr(>|z|)    
#> (Intercept)                                                59.46  < 2e-16 ***
#> .dy_communication_dyad_mean_gmc                            25.41  < 2e-16 ***
#> .dy_communication_within_dyad_diff                         -0.60    0.551    
#> .dy_dsm_role_contrast                                       4.67 2.94e-06 ***
#> .dy_communication_dyad_mean_gmc:.dy_dsm_role_contrast      -0.73    0.464    
#> .dy_communication_within_dyad_diff:.dy_dsm_role_contrast   11.47  < 2e-16 ***
#> ---
#> Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
```

### Interpreting the DSM paths

For the outcomes given the predictors, the long-format model estimates
the same paths as the conventional score-based DSM (Iida et al. 2018).

In the conventional score-based representation, the **predictors** are
decomposed in the same way:

``` math
X_{\mathrm{mean}}
= \frac{X_{\mathrm{female}} + X_{\mathrm{male}}}{2} - \mu_X,
\qquad
X_{\mathrm{diff}} = X_{\mathrm{female}} - X_{\mathrm{male}},
```

where $`\mu_X`$ is the sample grand mean of the dyad-level predictor
means.

The **outcomes** are also decomposed:

``` math
Y_{\mathrm{mean}} = \frac{Y_{\mathrm{female}} + Y_{\mathrm{male}}}{2},
\qquad
Y_{\mathrm{diff}} = Y_{\mathrm{female}} - Y_{\mathrm{male}}.
```

The long-format model fitted here does not create $`Y_{\mathrm{mean}}`$
and $`Y_{\mathrm{diff}}`$ as observed variables. Instead, it uses the
member-level outcome directly. With complete outcome pairs, this is an
equivalent parameterization of the same conditional outcome regressions.

Consider the conceptual SEM formulas:

``` math
\widehat{Y_{\mathrm{mean}}}
= a_{10} + a_{11}X_{\mathrm{mean}} + a_{12}X_{\mathrm{diff}},
```

``` math
\widehat{Y_{\mathrm{diff}}}
= a_{20} + a_{21}X_{\mathrm{mean}} + a_{22}X_{\mathrm{diff}}.
```

The fitted paths for this example are:

![Fitted DSM. Intercepts a10 5.04 and a20 0.96; paths a11 1.99, a12
-0.03, a21 -0.14, and a22 1.49; residual SDs 0.79 and 1.92, with
correlation -0.16.](dsm_files/figure-html/fitted-dsm-diagram-1.svg)

Fitted cross-sectional DSM for the example data. The nodes identify the
mean and difference scores; edge and intercept labels show the estimated
DSM coefficients, and the residual labels show the estimated
score-component standard deviations and correlation.

The fixed effects from our MLM model map directly to these paths as
such:

| Long-format fixed effect | DSM SEM path and interpretation |
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

The curved arrow $`\rho_{r_m r_d}`$ is the scale-free correlation
between the outcome-mean residual and the outcome-difference residual.
It is **not** the female-male residual correlation
$`\rho_{\epsilon_F\epsilon_M}`$ from the APIM.

The DSM uses the full female-minus-male difference:

``` math
e_{\mathrm{F}} = r_{\mathrm{m}} + \frac{1}{2}r_{\mathrm{d}},
\qquad
e_{\mathrm{M}} = r_{\mathrm{m}} - \frac{1}{2}r_{\mathrm{d}}.
```

Therefore, this relationship applies:

``` math
\operatorname{Cov}(r_{\mathrm{m}},r_{\mathrm{d}})
=
\frac{\operatorname{Var}(e_{\mathrm{F}})-\operatorname{Var}(e_{\mathrm{M}})}{2}.
```

For this reason, a nonzero $`\rho_{r_m r_d}`$ indicates that the two
roles have different residual variances. The remaining covariance
between the partners’ residuals is

``` math
\operatorname{Cov}(e_{\mathrm{F}},e_{\mathrm{M}})
=
\operatorname{Var}(r_{\mathrm{m}})-\frac{1}{4}\operatorname{Var}(r_{\mathrm{d}}).
```

### Reversing the coding

Instead of computing $`X_{\mathrm{female}} - X_{\mathrm{male}}`$, we can
reverse the direction and compute
$`X_{\mathrm{male}} - X_{\mathrm{female}}`$. This changes the direction
of the differences, but not the substantive model.

``` r

cross_dsm_data_inverted <- dyadMLM::prepare_dyad_data(
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
    .dy_communication_dyad_mean_gmc +
    .dy_communication_within_dyad_diff +
    .dy_dsm_role_contrast +
    .dy_communication_dyad_mean_gmc:.dy_dsm_role_contrast +
    .dy_communication_within_dyad_diff:.dy_dsm_role_contrast +
    us(1 + .dy_dsm_role_contrast | coupleID),
  dispformula = ~ 0,
  family = gaussian(),
  data = cross_dsm_data_inverted
)

female_minus_male <- glmmTMB::fixef(dsm_model)$cond
male_minus_female <- glmmTMB::fixef(dsm_model_inverted)$cond

knitr::kable(
  data.frame(
    `model term` = names(female_minus_male),
    `female - male` = unname(female_minus_male),
    `male - female` = unname(male_minus_female),
    check.names = FALSE
  ),
  digits = 3,
  align = c("l", "r", "r")
)
```

| model term | female - male | male - female |
|:---|---:|---:|
| (Intercept) | 5.043 | 5.043 |
| .dy_communication_dyad_mean_gmc | 1.990 | 1.990 |
| .dy_communication_within_dyad_diff | -0.032 | 0.032 |
| .dy_dsm_role_contrast | 0.956 | -0.956 |
| .dy_communication_dyad_mean_gmc:.dy_dsm_role_contrast | -0.138 | 0.138 |
| .dy_communication_within_dyad_diff:.dy_dsm_role_contrast | 1.486 | 1.486 |

The two models have identical fitted values and model fit:

- `.dy_communication_within_dyad_diff` reverses because the predictor
  difference reverses.

- `.dy_dsm_role_contrast` reverses because the represented outcome
  difference reverses.

- `.dy_communication_dyad_mean_gmc:.dy_dsm_role_contrast` reverses
  because only the outcome difference reverses.

- `.dy_communication_within_dyad_diff:.dy_dsm_role_contrast` remains
  unchanged because both differences reverse.

The intercept and `.dy_communication_dyad_mean_gmc` also remain
unchanged. For the random effects, the variances of `(Intercept)` and
`.dy_dsm_role_contrast` remain unchanged, whereas their covariance
reverses sign.

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
    .dy_is_female_x_male_female +
    .dy_is_female_x_male_male +

    # Role-specific actor effects
    .dy_is_female_x_male_female:.dy_communication_actor +
    .dy_is_female_x_male_male:.dy_communication_actor +

    # Role-specific partner effects
    .dy_is_female_x_male_female:.dy_communication_partner +
    .dy_is_female_x_male_male:.dy_communication_partner +

    # Role-specific Gaussian residual covariance structure
    us(0 +
         .dy_is_female_x_male_female +
         .dy_is_female_x_male_male
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

Let $`b_{\mathrm{actor},\mathrm{female}}`$ and
$`b_{\mathrm{actor},\mathrm{male}}`$ denote the actor effects on the
female and male outcomes. The corresponding partner effects are
$`b_{\mathrm{partner},\mathrm{female}}`$ and
$`b_{\mathrm{partner},\mathrm{male}}`$, and the APIM intercepts are
$`b_{0,\mathrm{female}}`$ and $`b_{0,\mathrm{male}}`$. Fixed APIM
coefficients use $`b`$ and write out their effect and outcome role. The
numbered paths $`a_{10}`$ through $`a_{22}`$ retain the published DSM
notation.

The slope transformation can be understood in two steps. First, for each
outcome role $`r \in \{\mathrm{female},\mathrm{male}\}`$, form the
actor-plus-partner and actor-minus-partner combinations:

``` math
\begin{aligned}
b_{\mathrm{sum},r}
&= b_{\mathrm{actor},r} + b_{\mathrm{partner},r}, \\
b_{\mathrm{difference},r}
&= b_{\mathrm{actor},r} - b_{\mathrm{partner},r}.
\end{aligned}
```

The DSM slopes then follow by combining the female- and male-outcome
effects:

``` math
\begin{aligned}
a_{11}
&= \frac{b_{\mathrm{sum},\mathrm{female}}
        + b_{\mathrm{sum},\mathrm{male}}}{2},
&
a_{21}
&= b_{\mathrm{sum},\mathrm{female}}
   - b_{\mathrm{sum},\mathrm{male}}, \\
a_{12}
&= \frac{b_{\mathrm{difference},\mathrm{female}}
        - b_{\mathrm{difference},\mathrm{male}}}{4},
&
a_{22}
&= \frac{b_{\mathrm{difference},\mathrm{female}}
        + b_{\mathrm{difference},\mathrm{male}}}{2}.
\end{aligned}
```

The APIM predictors retain their original scale, whereas the DSM
predictor level is grand-mean centered. Keeping the raw APIM predictors
on their original scale preserves their reference values; the centering
difference is handled explicitly in the intercept transformation. If
$`\mu_X`$ is the grand mean subtracted from the DSM predictor level, the
intercepts transform as

``` math
a_{10}
= \frac{b_{0,\mathrm{female}} + b_{0,\mathrm{male}}}{2} + \mu_X a_{11},
\qquad
a_{20} = b_{0,\mathrm{female}} - b_{0,\mathrm{male}} + \mu_X a_{21}.
```

For the reverse slope transformation, first recover the role-specific
actor-plus-partner and actor-minus-partner combinations:

``` math
\begin{aligned}
b_{\mathrm{sum},\mathrm{female}}
&= a_{11} + \frac{a_{21}}{2},
&
b_{\mathrm{sum},\mathrm{male}}
&= a_{11} - \frac{a_{21}}{2}, \\
b_{\mathrm{difference},\mathrm{female}}
&= a_{22} + 2a_{12},
&
b_{\mathrm{difference},\mathrm{male}}
&= a_{22} - 2a_{12}.
\end{aligned}
```

Then, for each outcome role $`r`$,

``` math
b_{\mathrm{actor},r}
= \frac{b_{\mathrm{sum},r} + b_{\mathrm{difference},r}}{2},
\qquad
b_{\mathrm{partner},r}
= \frac{b_{\mathrm{sum},r} - b_{\mathrm{difference},r}}{2}.
```

The intercepts transform back as

``` math
b_{0,\mathrm{female}} = a_{10} + \frac{a_{20}}{2}
- \mu_X\left(a_{11} + \frac{a_{21}}{2}\right),
```

``` math
b_{0,\mathrm{male}} = a_{10} - \frac{a_{20}}{2}
- \mu_X\left(a_{11} - \frac{a_{21}}{2}\right).
```

The following comparison applies the APIM-to-DSM transformation to all
six fixed effects:

| DSM path | From APIM transformation | From DSM model |
|:---------|-------------------------:|---------------:|
| a10      |                    5.043 |          5.043 |
| a11      |                    1.990 |          1.990 |
| a12      |                   -0.032 |         -0.032 |
| a20      |                    0.956 |          0.956 |
| a21      |                   -0.138 |         -0.138 |
| a22      |                    1.486 |          1.486 |

APIM-to-DSM fixed-effect transformation (centering constant = 5.148).
{.table}

### Random-effect transformation

Let $`u_{\mathrm{female}}`$ and $`u_{\mathrm{male}}`$ be the APIM random
effects for the female and male outcomes. The DSM outcome-level and
outcome-difference residuals are the same random effects expressed in
different coordinates:

``` math
\begin{pmatrix} r_{Y,\mathrm{mean}} \\ r_{Y,\mathrm{diff}} \end{pmatrix}
=
\begin{pmatrix} 1/2 & 1/2 \\ 1 & -1 \end{pmatrix}
\begin{pmatrix} u_{\mathrm{female}} \\ u_{\mathrm{male}} \end{pmatrix}.
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
  parameter = c(
    "Var(outcome mean)",
    "Cov(outcome mean, outcome diff)",
    "Var(outcome diff)"
  ),
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
#>                         parameter from_DSM from_APIM_transformation
#> 1               Var(outcome mean)    0.632                    0.632
#> 2 Cov(outcome mean, outcome diff)   -0.240                   -0.240
#> 3               Var(outcome diff)    3.678                    3.678
```

For exchangeable dyads, the direction of a member difference is
arbitrary. The directional intercept, both cross-paths, and the
covariance between outcome level and outcome difference must then be
zero. The remaining reduced, label-invariant DSM is algebraically the
Gaussian Dyad-Individual Model (DIM). In `dyadMLM`, use
`model_type = "dim"` for this exchangeable model and reserve
`model_type = "dsm"` for distinguishable dyads.

Because the Gaussian DIM is the exchangeability-constrained version of
the full DSM, exchangeability can also be tested by comparing these
nested models. This is equivalent to the comparison shown in [Testing
distinguishability in the APIM
vignette](https://pascal-kueng.github.io/dyadMLM/articles/apim.html#testing-distinguishability).

## Intensive longitudinal DSM

> The following sections are under construction and are coming soon!
> This extension is equivalent to the extension from the cross-sectional
> DIM to the ILD DIM. Please refer to that section.

### Interpretation of concurrent ILD DSM coefficients

### Equivalence of APIM and DSM in ILD

### Including Random Slopes

#### Transforming DSM random slopes to APIM slopes

### Dynamic ILD DSM example

The ILD models above do not model residual serial dependence. One way to
model dynamics or to account for temporal dependency is to include
lagged outcomes as predictors.

**Note:** Dynamic models, especially with small time series, are subject
to bias. This, and the choice between raw and within-person-centered
outcome lags, are addressed in the [APIM vignette’s discussion of
dynamic
models](https://pascal-kueng.github.io/dyadMLM/articles/apim.html#dynamic-models).

------------------------------------------------------------------------

Return to the [Actor-Partner Interdependence Model
vignette](https://pascal-kueng.github.io/dyadMLM/articles/apim.md), see
the [Mixed-Composition APIM
vignette](https://pascal-kueng.github.io/dyadMLM/articles/mixed-apim.md)
or the [Dyad-Individual Model
vignette](https://pascal-kueng.github.io/dyadMLM/articles/dim.md) for
related model specifications, or return to the
[Overview](https://pascal-kueng.github.io/dyadMLM/articles/index.md).

## References

Iida, Masumi, Gwendolyn Seidman, and Patrick E. Shrout. 2018. “Models of
Interdependent Individuals Versus Dyadic Processes in Relationship
Research.” *Journal of Social and Personal Relationships* 35 (1): 59–88.
<https://doi.org/10.1177/0265407517725407>.
