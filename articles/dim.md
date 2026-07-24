# Dyad-Individual Model

``` r

library(dyadMLM)
has_glmmTMB <- requireNamespace("glmmTMB", quietly = TRUE)
#> Warning in check_dep_version(dep_pkg = "TMB"): package version mismatch: 
#> glmmTMB was built with TMB package version 1.9.21
#> Current TMB package version is 1.9.23
#> Please re-install glmmTMB from source or restore original 'TMB' package (see '?reinstalling' for more information)
has_htmltools <- requireNamespace("htmltools", quietly = TRUE)
dim_fitted_alt <- "Fitted DIM diagram unavailable."
```

This vignette focuses on the Dyad-Individual Model (DIM) for dyadic
multilevel models and its relationship to the exchangeable Actor-Partner
Interdependence Model (APIM). The DIM separates a predictor into the
dyad’s shared level and each member’s deviation from that level. While
the APIM expresses effects in terms of two interdependent individuals,
the DIM expresses them in terms of the dyad’s shared level and the
contrast between partners.

Under exchangeability constraints, the reduced, label-invariant DSM is
also equivalent to the DIM, as discussed below. For the broader package
workflow and an overview of the available model-specific vignettes,
including the [Actor-Partner Interdependence
Model](https://pascal-kueng.github.io/dyadMLM/articles/apim.md) and
[Dyadic Score
Model](https://pascal-kueng.github.io/dyadMLM/articles/dsm.md), see the
[online package overview](https://pascal-kueng.github.io/dyadMLM/).

## Cross-Sectional Gaussian DIM

The current DIM implementation needs one exchangeable dyad composition.
Exchangeability means that swapping the two member labels does not
change the model (Kenny et al. 2006). Whether roles can and should be
treated as exchangeable is a substantive assumption (see [Testing
distinguishability in the APIM
vignette](https://pascal-kueng.github.io/dyadMLM/articles/apim.html#testing-distinguishability)).

Here, we retain the female-female dyads with `keep_compositions`.
Because both members have the same role, this gives us one genuinely
exchangeable dyad composition. Omitting `role` is another option when
all dyads should be treated as one exchangeable composition. Refer to
the [Getting Started
vignette](https://pascal-kueng.github.io/dyadMLM/articles/getting-started.md)
for how to retain, pool, and constrain dyad compositions.

``` r

cross_exchangeable_data <- dyadMLM::prepare_dyad_data(
  dyads_cross,
  dyad = coupleID,
  member = personID,
  role = gender,
  predictors = provided_support,
  # Create both APIM and DIM columns for comparison.
  model_types = c("apim", "dim"),
  # All three observed compositions in `dyads_cross` are detected and retained by
  # default. This example focuses on `female-female` dyads, so we restrict the
  # analysis here.
  keep_compositions = "female-female",
  seed = 123
)

# Print the first two dyads before changing the generated APIM analysis columns.
print(cross_exchangeable_data, n = 4)
#> # dyadMLM data
#> # Rows: 240 | Dyads: 120 | Intensive longitudinal: no
#> # Structure: dyad = coupleID, member = personID, role = gender
#> #
#> # Dyad compositions:
#> # female_x_female exchangeable 120 dyads
#> #
#> # Added columns:
#> #   .dy_composition                inferred dyad composition
#> #   .dy_composition_role           composition-specific member role
#> #   .dy_is_{role}                  composition-role indicator columns
#> #   .dy_member_contrast_arbitrary  composition-specific member contrasts with
#> #                                  arbitrary direction; 0 for distinguishable
#> #                                  dyads or other exchangeable compositions
#> #   .dy_{pred}_actor               APIM actor predictor: actor's original
#> #                                  predictor values
#> #   .dy_{pred}_partner             APIM partner predictor: partner's original
#> #                                  predictor values
#> #   .dy_{pred}_dyad_mean_gmc       dyad-mean predictor: dyad's average
#> #                                  predictor level, grand-mean centered
#> #   .dy_{pred}_within_dyad_dev     DIM within-dyad member-deviation predictor:
#> #                                  member's difference from the dyad mean
#> #
#> # A tibble: 240 × 14
#>   personID coupleID gender dyad_composition closeness provided_support
#>      <int>    <int> <fct>  <fct>                <dbl>            <dbl>
#> 1      241      121 female female_x_female       7.58             5.41
#> 2      242      121 female female_x_female       6.15             5.19
#> 3      243      122 female female_x_female       8.28             5.89
#> 4      244      122 female female_x_female       8.00             5.57
#> # ℹ 236 more rows
#> # ℹ 8 more variables: .dy_composition <fct>, .dy_composition_role <fct>,
#> #   .dy_is_exchangeable <dbl>, .dy_member_contrast_arbitrary <dbl>,
#> #   .dy_provided_support_actor <dbl>, .dy_provided_support_partner <dbl>,
#> #   .dy_provided_support_dyad_mean_gmc <dbl>,
#> #   .dy_provided_support_within_dyad_dev <dbl>

provided_support_grand_mean <- mean(
  c(
    cross_exchangeable_data$.dy_provided_support_actor,
    cross_exchangeable_data$.dy_provided_support_partner
  ),
  na.rm = TRUE
)

# Use one pooled centering constant for both APIM predictor columns.
cross_exchangeable_data$.dy_provided_support_actor <-
  cross_exchangeable_data$.dy_provided_support_actor -
  provided_support_grand_mean
cross_exchangeable_data$.dy_provided_support_partner <-
  cross_exchangeable_data$.dy_provided_support_partner -
  provided_support_grand_mean
```

For the exchangeable random-effects specification,
[`dyadMLM::prepare_dyad_data()`](https://pascal-kueng.github.io/dyadMLM/reference/prepare_dyad_data.md)
creates a member-difference contrast `.dy_member_contrast_*`, coded as
`+1` for one partner and `-1` for the other. Because these member labels
are arbitrary, setting `seed` makes their assignment reproducible.

### Example DIM Model

In this cross-sectional example, $`x_{ij}`$ denotes provided support
after subtracting the same pooled grand mean across all members in the
analysis sample. Raw scores could instead be used if zero is meaningful
for that variable in the analysis sample; the slopes would be unchanged,
but the intercept would have a different reference point.

For member $`i \in \{1, 2\}`$ of dyad $`j`$, define the dyad mean and
within-dyad member deviation as:

``` math
\bar{x}_j = \frac{x_{1j} + x_{2j}}{2}, \qquad
x_{\mathrm{dev},ij} = x_{ij} - \bar{x}_j.
```

Because each $`x_{ij}`$ uses the same grand-mean reference,
$`\bar{x}_j`$ is already grand-mean centered. The within-dyad deviation
is unchanged by this common shift.

The deviations of the two partners have equal magnitude and opposite
signs: $`x_{\mathrm{dev},1j} = -x_{\mathrm{dev},2j}`$. Outcome means and
deviations are defined analogously. The variables that enter the DIM
fixed effects then separate two associations:

1.  The **between-dyad effect**, $`b_{\mathrm{mean}}`$: whether dyads
    with a higher dyad mean than other dyads also have a higher outcome
    mean.
2.  The **within-dyad effect**, $`b_{\mathrm{dev}}`$: whether the member
    who is above the dyad’s predictor mean is also above the dyad’s
    outcome mean. With two members, each deviation is half the
    corresponding signed partner difference.

The dyad mean varies between dyads, whereas member deviations vary
within a dyad. Accordingly, the upper path is the between-dyad effect
and the lower path is the within-dyad effect. Switching members reverses
both deviations and therefore leaves the pooled $`b_{\mathrm{dev}}`$
unchanged.

![Path diagram for a cross-sectional Dyad-Individual Model. The
grand-mean-centered dyad mean predicts the outcome mean through the
between-dyad effect b mean. Member i's within-dyad member deviation
predicts the same member's outcome deviation through the within-dyad
effect b dev. There are no cross-paths, and only the outcome-mean
equation has intercept b
zero.](dim_files/figure-html/conceptual-dim-diagram-1.svg)

Cross-sectional DIM. The dyad mean has a between-dyad effect, and the
within-dyad member deviation has a within-dyad effect. Mean and
deviation residuals are uncorrelated under exchangeability. Both
members’ residuals and their correlation can be obtained from these
residuals.

Uncorrelated $`r_{\mathrm{m}}`$ and $`r_{\mathrm{d},i}`$ in the
conceptual representation do not imply that the member residuals are
independent: the two component variances together determine the
covariance between the members’ residuals.

The second diagram translates the same decomposition to the
individual-member rows used by the long-format multilevel model. Each
member’s outcome is predicted by the dyad mean and that member’s own
within-dyad member deviation. Both members share the same two
coefficients, so estimation pools information across members under the
exchangeability assumptions.

![Path diagram for two arbitrarily labelled members of an exchangeable
dyad. For each member, the grand-mean-centered dyad mean and the
member's own within-dyad member deviation predict the individual
outcome. Both members share the same between-dyad and within-dyad
coefficients and residual standard deviation, while their outcome
residuals are
correlated.](dim_files/figure-html/conceptual-dim-member-diagram-1.svg)

Individual-level representation of the cross-sectional DIM used for the
long-format multilevel model.

The resulting estimated fixed effects are a reparameterization of the
APIM actor and partner effects (Bolger et al. 2025). And just like the
exchangeable APIM, the random-effects structure comprises a dyad-level
intercept and a dyad-level difference contrast indexed by
`.dy_member_contrast_arbitrary`. In `glmmTMB`, with `dispformula = ~ 0`,
these random effects represent the two members’ Gaussian residual
variance and covariance.

The intercept and difference contrast are specified as separate
random-effects terms. No additional correlation is needed because the
two residual variances already determine the partners’ residual
correlation. Under exchangeability, the mean-deviation residual
correlation is therefore fixed to zero (del Rosario and West 2025).

The full model can be estimated as:

``` r


dim_1 <- glmmTMB::glmmTMB(
  closeness ~

    # Pooled fixed intercept
    1 +

    # Between-dyad effect
    .dy_provided_support_dyad_mean_gmc +

    # Within-dyad effect
    .dy_provided_support_within_dyad_dev +

    # Residual Gaussian covariance structure
    us(1 | coupleID) +
    us(0 + .dy_member_contrast_arbitrary | coupleID)
  , dispformula = ~ 0
  , family = gaussian()
  , data = cross_exchangeable_data
)

summary(dim_1)
#>  Family: gaussian  ( identity )
#> Formula:          
#> closeness ~ 1 + .dy_provided_support_dyad_mean_gmc + .dy_provided_support_within_dyad_dev +  
#>     us(1 | coupleID) + us(0 + .dy_member_contrast_arbitrary |      coupleID)
#> Dispersion:                 ~0
#> Data: cross_exchangeable_data
#> 
#>       AIC       BIC    logLik -2*log(L)  df.resid 
#>     631.5     648.9    -310.7     621.5       235 
#> 
#> Random effects:
#> 
#> Conditional model:
#>  Groups     Name                          Variance Std.Dev.
#>  coupleID   (Intercept)                   0.5650   0.7516  
#>  coupleID.1 .dy_member_contrast_arbitrary 0.2692   0.5189  
#> Number of obs: 240, groups:  coupleID, 120
#> 
#> Conditional model:
#>                                      Estimate Std. Error z value Pr(>|z|)    
#> (Intercept)                           5.94511    0.06861   86.64   <2e-16 ***
#> .dy_provided_support_dyad_mean_gmc    1.54652    0.09582   16.14   <2e-16 ***
#> .dy_provided_support_within_dyad_dev  0.89515    0.10726    8.35   <2e-16 ***
#> ---
#> Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
```

The same mean-and-deviation diagram can now be labelled with the
estimated fixed effects and residual-component standard deviations:

![Fitted DIM. Intercept 5.95, between-dyad effect 1.55, within-dyad
effect 0.90, and mean/deviation residual SDs 0.75 and 0.52; their
correlation is fixed at
zero.](dim_files/figure-html/fitted-dim-diagram-1.svg)

Estimated fixed effects and residual-component standard deviations from
the cross-sectional Gaussian DIM in its mean-and-deviation
representation. The intercept belongs to the outcome-mean equation.

Under these exchangeability constraints, the Gaussian DIM is
algebraically equivalent to the reduced, label-invariant Dyadic Score
Model (DSM) (Iida et al. 2018). Compared to a full DSM, the DIM’s
exchangeability constraints fix the outcome-deviation intercept and both
cross-paths to zero and constrain the mean and deviation residual
components to be uncorrelated (see the diagrams here and compare them
with the [conceptual DSM
diagrams](https://pascal-kueng.github.io/dyadMLM/articles/dsm.html#cross-sectional-gaussian-dsm)).

### Model interpretation

Therefore, each coefficient has both an individual-member interpretation
and an equivalent dyad mean/difference interpretation.

In this Gaussian model, fixed coefficients are interpreted in units of
the outcome, here closeness:

- The intercept (about 5.95) is the expected closeness of either member,
  and therefore the expected couple-average closeness, when both
  members’ provided support equals the sample grand mean.

- The between-dyad effect estimate (about 1.55) means that, comparing
  couples with the same support difference between partners, a one-point
  higher couple-average provided-support level is associated with a
  1.55-point higher expected couple-average closeness. Equivalently,
  each member’s expected closeness is 1.55 points higher.

- The within-dyad effect estimate (about 0.90) means that a one-point
  difference in provided support between partners is associated with a
  0.90-point difference in their expected closeness, holding their
  average support constant. In member terms, suppose one member is 0.5
  points above the dyad mean and the other is 0.5 points below it. Their
  expected closeness is then about 0.45 points above and below the
  couple’s predicted mean, respectively, so they are expected to differ
  by 0.90 points in closeness.

Because the Gaussian DIM is the exchangeability-constrained version of
the full DSM, exchangeability can also be tested by comparing these
nested models. This is equivalent to the comparison shown in [Testing
distinguishability in the APIM
vignette](https://pascal-kueng.github.io/dyadMLM/articles/apim.html#testing-distinguishability).

### Demonstrating model equivalence to APIM

The same model can be written in APIM form. Since we have requested both
sets of variables from
[`dyadMLM::prepare_dyad_data()`](https://pascal-kueng.github.io/dyadMLM/reference/prepare_dyad_data.md),
we can fit one directly. For more guidance on APIM specifications and
different models, see the [Actor-Partner Interdependence Model
vignette](https://pascal-kueng.github.io/dyadMLM/articles/apim.md).

``` r


apim_1 <- glmmTMB::glmmTMB(
  closeness ~ 1 +

    # Fixed effects APIM
    .dy_provided_support_actor + .dy_provided_support_partner +

    # Since both models are equivalent, the same random-effects structure
    # can be used. See the APIM vignette to learn how to back-transform
    # these blocks to a full actor-partner covariance matrix.
    us(1 | coupleID) +
    us(0 + .dy_member_contrast_arbitrary | coupleID)
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
#>   model      AIC     BIC    logLik
#> 1   DIM 631.4539 648.857 -310.7269
#> 2  APIM 631.4539 648.857 -310.7269
```

This demonstrates that the same statistical model is being estimated
with different parameterizations and coefficient interpretations.

Once APIM estimates are present, one can easily obtain DIM estimates,
and the other way around. Let $`b_{\mathrm{actor}}`$ and
$`b_{\mathrm{partner}}`$ denote the APIM actor and partner slopes, and
let $`b_{\mathrm{mean}}`$ and $`b_{\mathrm{dev}}`$ denote the DIM
between-dyad and within-dyad slopes. Grand-mean centering the APIM actor
and partner predictors with the same pooled constant gives the APIM and
DIM the same zero point. This simplifies the fixed-effect transformation
to the formulas shown here; with raw APIM predictors, the slope formulas
would be unchanged but the intercept would need to be recentered.

The shared intercept is

``` math
b_{0,\mathrm{DIM}} = b_{0,\mathrm{APIM}}.
```

The slopes relate as follows:

``` math
b_{\mathrm{mean}} = b_{\mathrm{actor}} + b_{\mathrm{partner}}
```

and

``` math
b_{\mathrm{dev}} = b_{\mathrm{actor}} - b_{\mathrm{partner}}
```

Conversely:

``` math
b_{\mathrm{actor}}
= \frac{b_{\mathrm{mean}} + b_{\mathrm{dev}}}{2}
```

and

``` math
b_{\mathrm{partner}}
= \frac{b_{\mathrm{mean}} - b_{\mathrm{dev}}}{2}
```

In this example we can see that the transformations work:

``` r

apim_coef <- glmmTMB::fixef(apim_1)$cond
dim_coef <- glmmTMB::fixef(dim_1)$cond

b0_apim <- apim_coef[["(Intercept)"]]
b_actor <- apim_coef[[".dy_provided_support_actor"]]
b_partner <- apim_coef[[".dy_provided_support_partner"]]

b0_dim <- dim_coef[["(Intercept)"]]
b_mean <- dim_coef[[".dy_provided_support_dyad_mean_gmc"]]
b_dev <- dim_coef[[".dy_provided_support_within_dyad_dev"]]


cat("From APIM model:\n",
     "  intercept:                     ", round(b0_apim, 3), "\n",
     "  actor effect:                  ", round(b_actor, 3), "\n",
     "  partner effect:                ", round(b_partner, 3), "\n\n",

     "DIM transformation:\n",
     "  b_mean = b_actor + b_partner:  ", round(b_actor + b_partner, 3), "\n",
     "  b_dev = b_actor - b_partner:   ", round(b_actor - b_partner, 3), "\n\n",

     "From DIM model:\n",
     "  intercept:                     ", round(b0_dim, 3), "\n",
     "  between-dyad effect:           ", round(b_mean, 3), "\n",
     "  within-dyad effect:            ", round(b_dev, 3), "\n"
)
#> From APIM model:
#>    intercept:                      5.945 
#>    actor effect:                   1.221 
#>    partner effect:                 0.326 
#> 
#>  DIM transformation:
#>    b_mean = b_actor + b_partner:   1.547 
#>    b_dev = b_actor - b_partner:    0.895 
#> 
#>  From DIM model:
#>    intercept:                      5.945 
#>    between-dyad effect:            1.547 
#>    within-dyad effect:             0.895
```

The DIM and APIM intercepts are equal up to numerical estimation
tolerance because both parameterizations now use the same grand-mean
reference.

### Why Are These Models Equivalent? Exploring the Reparameterization

An intuitive way to think about this is:

- When the dyad mean goes up by 1 unit while the difference between
  partners remains stable, both partners’ values must go up by 1. Both
  the actor and partner effects therefore contribute, which is why the
  between-dyad effect is the actor effect + the partner effect.

- When a person’s deviation from the dyad mean goes up by 1 unit while
  the dyad mean remains constant, the other partner’s value must go
  **down** by 1 unit. The actor value therefore changes by +1 and the
  partner value by -1, which is why the within-dyad effect is the actor
  effect - the partner effect.

The grid below shows the same predictor values in both coordinate
systems. The horizontal and vertical axes are actor and partner values
centered at the sample grand mean. The diagonal axes are their dyad mean
and within-dyad member deviation.

The displayed actor and partner slopes are read from the fitted APIM.
The DIM slopes are their exact sum-and-difference transformation; the
directly fitted DIM estimates above confirm the equivalence. Both forms
therefore make the same change in the linear predictor relative to the
grand-mean reference. The intercept is omitted from both displayed
equations.

**Provided support coordinates**

Reset

APIM coordinates

Grand-mean-centered actor, x_(actor)

0.00

Grand-mean-centered partner, x_(partner)

0.00

DIM coordinates

Dyad mean, x_(mean)

0.00

Within-dyad member deviation, x_(dev)

0.00

x_(mean) = (x_(actor) + x_(partner)) / 2 x_(dev) = (x_(actor) −
x_(partner)) / 2

**APIM**

**DIM**

![](data:image/svg+xml;base64,PHN2ZyBjbGFzcz0id2RnLXBsb3QiIGRhdGEtd2RnLXBsb3Qgdmlld2JveD0iMCAwIDMyMCAzMjAiIHJvbGU9ImltZyIgYXJpYS1sYWJlbGxlZGJ5PSJpbnRlcmRlcC1kaW0tZ3JpZC10aXRsZSBpbnRlcmRlcC1kaW0tZ3JpZC1kZXNjcmlwdGlvbiI+PHRpdGxlIGlkPSJpbnRlcmRlcC1kaW0tZ3JpZC10aXRsZSI+QVBJTSBhbmQgRElNIGNvb3JkaW5hdGUgZ3JpZDwvdGl0bGU+CjxkZXNjIGlkPSJpbnRlcmRlcC1kaW0tZ3JpZC1kZXNjcmlwdGlvbiIgZGF0YS13ZGctZGVzY3JpcHRpb24+VGhlIHNlbGVjdGVkIHBvaW50IGlzIHRoZSBncmFuZC1tZWFuIHJlZmVyZW5jZS48L2Rlc2M+PGRlZnM+PGNsaXBwYXRoIGlkPSJpbnRlcmRlcC1kaW0tZ3JpZC1jbGlwIj48cmVjdCB4PSIzMCIgeT0iMzAiIHdpZHRoPSIyNjAiIGhlaWdodD0iMjYwIiByeD0iNCIgLz48L2NsaXBwYXRoPjwvZGVmcz48cmVjdCB4PSIzMCIgeT0iMzAiIHdpZHRoPSIyNjAiIGhlaWdodD0iMjYwIiByeD0iNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS1vcGFjaXR5PSIwLjMyIiAvPjxnIGRhdGEtd2RnLWdyaWQtbGluZXMgY2xpcC1wYXRoPSJ1cmwoI2ludGVyZGVwLWRpbS1ncmlkLWNsaXApIj48L2c+PGcgZGF0YS13ZGctYXhpcy1sYWJlbHM+PC9nPjxjaXJjbGUgY2xhc3M9IndkZy1oYWxvIiBkYXRhLXdkZy1oYWxvIGN4PSIxNjAiIGN5PSIxNjAiIHI9IjEzIj48L2NpcmNsZT48Y2lyY2xlIGNsYXNzPSJ3ZGctcG9pbnQiIGRhdGEtd2RnLXBvaW50IGN4PSIxNjAiIGN5PSIxNjAiIHI9IjYiPjwvY2lyY2xlPjwvc3ZnPg==)

**Shared dyad level**Both members +1

b_(mean) = a + p

**Within-dyad member deviation**Actor +1, partner −1

b_(dev) = a − p

Drag the dot or move either set of sliders. Both equations give the same
fitted change in the linear predictor.

Enable JavaScript to manipulate this figure. The equations above provide
the same transformation.

### Random-effect transformation

The DIM and APIM models above already use the same sum-and-difference
random-effects parameterization (del Rosario and West 2025). See the
[exchangeable residual-structure section of the APIM
vignette](https://pascal-kueng.github.io/dyadMLM/articles/apim.html#exchangeable-residual-structure)
for the derivation and back-transformation to the member-level
covariance matrix.

## Intensive Longitudinal DIM

For longitudinal DIM, predictors are decomposed into within-person and
between-person components before the dyadic decomposition (Bolger and
Laurenceau 2013; Gistelinck and Loeys 2020). The default `"auto"`
selects `"2l"` when both `time` and `predictors` are supplied. It also
retains raw dyad-occasion means and within-dyad member deviations. The
decomposed columns used below are:

1.  The `cwp` dyad mean captures a shared occasion-specific shift from
    the two members’ usual levels (shared occasion-level variation).
2.  The `cwp` within-dyad member deviation captures which member is
    further above or below their own usual level on that occasion.
3.  The `cbp` dyad mean captures the dyad’s shared usual level relative
    to the sample’s grand mean (stable between-dyad differences).
4.  The `cbp` within-dyad member deviation captures each member’s stable
    difference from the dyad’s usual level.

The `cbp` terms use each member’s mean across the observed occasions to
estimate that member’s longer-run usual level. With few occasions (small
$`T`$), especially when the predictor has low stability over time, these
person means can be unreliable. The associated between-person estimates
can therefore be biased or imprecise, so they should be interpreted
cautiously (Gottfredson 2019).

Use `temporal_decomposition = "none"` to construct only the raw
dyad-occasion mean and within-dyad member deviation.

``` r

ild_exchangeable_data <- dyadMLM::prepare_dyad_data(
  dyads_ild,
  dyad = coupleID,
  member = personID,
  role = gender,
  time = diaryday,
  predictors = provided_support,
  model_types = c("apim", "dim"),
  keep_compositions = "female-female",
  seed = 123
)

print(ild_exchangeable_data)
#> # dyadMLM data
#> # Rows: 3360 | Dyads: 120 | Intensive longitudinal: yes
#> # Structure: dyad = coupleID, member = personID, role = gender, time = diaryday
#> #
#> # Dyad compositions:
#> # female_x_female exchangeable 120 dyads
#> #
#> # Added columns:
#> #   .dy_composition                 inferred dyad composition
#> #   .dy_composition_role            composition-specific member role
#> #   .dy_is_{role}                   composition-role indicator columns
#> #   .dy_member_contrast_arbitrary   composition-specific member contrasts with
#> #                                   arbitrary direction; 0 for distinguishable
#> #                                   dyads or other exchangeable compositions
#> #   .dy_{pred}_cwp                  within-person predictor: momentary
#> #                                   deviations from each person's usual level
#> #   .dy_{pred}_cbp                  between-person predictor: stable
#> #                                   differences from the average person's usual
#> #                                   level
#> #   .dy_{pred}_actor                APIM actor predictor: actor's original
#> #                                   predictor values
#> #   .dy_{pred}_partner              APIM partner predictor: partner's original
#> #                                   predictor values
#> #   .dy_{pred}_cwp_actor            APIM within-person actor predictor: actor's
#> #                                   momentary deviations from their usual level
#> #   .dy_{pred}_cwp_partner          APIM within-person partner predictor:
#> #                                   partner's momentary deviations from their
#> #                                   usual level
#> #   .dy_{pred}_cbp_actor            APIM between-person actor predictor:
#> #                                   actor's stable difference from the average
#> #                                   person's usual level
#> #   .dy_{pred}_cbp_partner          APIM between-person partner predictor:
#> #                                   partner's stable difference from the
#> #                                   average person's usual level
#> #   .dy_{pred}_dyad_mean_gmc        dyad-mean predictor: dyad's average
#> #                                   predictor level, grand-mean centered
#> #   .dy_{pred}_within_dyad_dev      DIM within-dyad member-deviation predictor:
#> #                                   member's difference from the dyad mean
#> #   .dy_{pred}_cwp_dyad_mean        within-person dyad-mean predictor: shared
#> #                                   momentary deviations in the dyad
#> #   .dy_{pred}_cwp_within_dyad_dev  DIM within-person, within-dyad
#> #                                   member-deviation predictor: member's
#> #                                   momentary deviation from the dyad mean
#> #   .dy_{pred}_cbp_dyad_mean        between-person dyad-mean predictor: dyad's
#> #                                   stable usual level, grand-mean centered
#> #   .dy_{pred}_cbp_within_dyad_dev  DIM between-person, within-dyad
#> #                                   member-deviation predictor: member's stable
#> #                                   difference from the dyad's usual level
#> #
#> # A tibble: 3,360 × 25
#>    personID coupleID diaryday gender dyad_composition closeness provided_support
#>       <int>    <int>    <int> <fct>  <fct>                <dbl>            <dbl>
#>  1      241      121        0 female female_x_female       6.59             6.18
#>  2      242      121        0 female female_x_female       5.73             5.70
#>  3      241      121        1 female female_x_female       8.70             4.57
#>  4      242      121        1 female female_x_female       5.61             5.30
#>  5      241      121        2 female female_x_female       7.06             5.19
#>  6      242      121        2 female female_x_female       6.72             3.89
#>  7      241      121        3 female female_x_female       6.36             6.28
#>  8      242      121        3 female female_x_female       6.67             5.26
#>  9      241      121        4 female female_x_female       7.91             6.94
#> 10      242      121        4 female female_x_female       7.35             5.59
#> # ℹ 3,350 more rows
#> # ℹ 18 more variables: .dy_composition <fct>, .dy_composition_role <fct>,
#> #   .dy_is_exchangeable <dbl>, .dy_member_contrast_arbitrary <dbl>,
#> #   .dy_provided_support_cwp <dbl>, .dy_provided_support_cbp <dbl>,
#> #   .dy_provided_support_actor <dbl>, .dy_provided_support_partner <dbl>,
#> #   .dy_provided_support_cwp_actor <dbl>,
#> #   .dy_provided_support_cwp_partner <dbl>, …
```

The example below estimates same-day associations between support and
closeness and includes `diaryday` to adjust for a linear trend across
the study.

``` r


dim_ILD <- glmmTMB::glmmTMB(
  closeness ~
    1 +

    diaryday +

    # Within-person DIM
    .dy_provided_support_cwp_dyad_mean +
    .dy_provided_support_cwp_within_dyad_dev +

    # Between-person DIM
    .dy_provided_support_cbp_dyad_mean +
    .dy_provided_support_cbp_within_dyad_dev +

    # Stable exchangeable dyad-level covariance
    us(1 | coupleID) +
    us(0 + .dy_member_contrast_arbitrary | coupleID) +

    # Residual (same-day) exchangeable dyad-level covariance
    us(1 | coupleID:diaryday) +
    us(0 + .dy_member_contrast_arbitrary | coupleID:diaryday)

  , dispformula = ~ 0
  , family = gaussian()
  , data = ild_exchangeable_data
)

summary(dim_ILD)
#>  Family: gaussian  ( identity )
#> Formula:          
#> closeness ~ 1 + diaryday + .dy_provided_support_cwp_dyad_mean +  
#>     .dy_provided_support_cwp_within_dyad_dev + .dy_provided_support_cbp_dyad_mean +  
#>     .dy_provided_support_cbp_within_dyad_dev + us(1 | coupleID) +  
#>     us(0 + .dy_member_contrast_arbitrary | coupleID) + us(1 |  
#>     coupleID:diaryday) + us(0 + .dy_member_contrast_arbitrary |  
#>     coupleID:diaryday)
#> Dispersion:                 ~0
#> Data: ild_exchangeable_data
#> 
#>       AIC       BIC    logLik -2*log(L)  df.resid 
#>    8514.6    8575.8   -4247.3    8494.6      3350 
#> 
#> Random effects:
#> 
#> Conditional model:
#>  Groups              Name                          Variance Std.Dev.
#>  coupleID            (Intercept)                   0.5359   0.7320  
#>  coupleID.1          .dy_member_contrast_arbitrary 0.2536   0.5036  
#>  coupleID.diaryday   (Intercept)                   0.4070   0.6380  
#>  coupleID.diaryday.1 .dy_member_contrast_arbitrary 0.2182   0.4672  
#> Number of obs: 3360, groups:  coupleID, 120; coupleID:diaryday, 1680
#> 
#> Conditional model:
#>                                           Estimate Std. Error z value Pr(>|z|)
#> (Intercept)                               5.898698   0.073060   80.74   <2e-16
#> diaryday                                  0.007138   0.003861    1.85   0.0645
#> .dy_provided_support_cwp_dyad_mean        0.493141   0.029327   16.82   <2e-16
#> .dy_provided_support_cwp_within_dyad_dev -0.005806   0.026949   -0.22   0.8294
#> .dy_provided_support_cbp_dyad_mean        1.546530   0.095815   16.14   <2e-16
#> .dy_provided_support_cbp_within_dyad_dev  0.895142   0.107261    8.35   <2e-16
#>                                             
#> (Intercept)                              ***
#> diaryday                                 .  
#> .dy_provided_support_cwp_dyad_mean       ***
#> .dy_provided_support_cwp_within_dyad_dev    
#> .dy_provided_support_cbp_dyad_mean       ***
#> .dy_provided_support_cbp_within_dyad_dev ***
#> ---
#> Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
```

### Interpretation of concurrent ILD DIM coefficients

The same mean-and-deviation interpretation applies longitudinally.
Coefficients of dyad means describe both expected individual outcomes
and expected couple-average outcomes. Coefficients of within-dyad member
deviations describe both members’ deviations and their expected
difference.

- The `cbp` dyad-mean estimate (about 1.55) means that, comparing
  couples whose average usual support differs by one point while holding
  the stable difference between partners constant, expected
  couple-average closeness is 1.55 points higher for the higher-support
  couple. Equivalently, each member is expected to report 1.55 points
  higher closeness.

- The `cwp` dyad-mean estimate (about 0.49) means that when both members
  are one point above their respective usual support levels, each
  member’s expected closeness is 0.49 points higher than when both are
  at their usual levels, holding the difference between their momentary
  deviations constant. Equivalently, expected couple-average closeness
  is 0.49 points higher on that occasion.

- The `cbp` within-dyad member-deviation estimate (about 0.90) means
  that if partners differ by one point in their usual support levels,
  they are expected to differ by 0.90 points in closeness, holding the
  couple’s average usual support and the other predictors constant. In
  member terms, suppose one member is 0.5 points above the couple’s
  average usual support and the other is 0.5 points below it. Their
  expected closeness is then about 0.45 points above and below the
  couple’s predicted mean, respectively.

- The `cwp` within-dyad member-deviation estimate (about -0.01) is close
  to zero. If one partner’s momentary deviation from usual support is
  one point higher than the other partner’s deviation, there is
  essentially no expected closeness difference between them from this
  term, holding the occasion-specific dyad mean and the other predictors
  constant.

### Equivalence of APIM and DIM in ILD

The equivalent APIM uses actor and partner effects on both levels, as
shown in the [concurrent ILD APIM
example](https://pascal-kueng.github.io/dyadMLM/articles/apim.html#concurrent-ild-gaussian-apim-for-exchangeable-dyads).
The APIM and DIM again estimate the same model with different
coefficients.

The equivalence holds separately for the within-person (`cwp`) and
between-person (`cbp`) predictor components. For the within-person
component:

``` math
b_{\mathrm{cwp,mean}}
= b_{\mathrm{cwp,actor}} + b_{\mathrm{cwp,partner}}
```

``` math
b_{\mathrm{cwp,dev}}
= b_{\mathrm{cwp,actor}} - b_{\mathrm{cwp,partner}}
```

For the between-person component:

``` math
b_{\mathrm{cbp,mean}}
= b_{\mathrm{cbp,actor}} + b_{\mathrm{cbp,partner}}
```

``` math
b_{\mathrm{cbp,dev}}
= b_{\mathrm{cbp,actor}} - b_{\mathrm{cbp,partner}}
```

An APIM parameterization can therefore be used on one level and a DIM
parameterization on the other. This mixed parameterization changes the
coefficients, but still estimates the same model.

### Including Random Slopes

Random slopes can be included in the DIM by adding the corresponding
within-person effects to the stable dyad-level random-effect blocks. The
shared block contains the DIM intercept, dyad-mean slope, and
within-dyad member-deviation slope. The `.dy_member_contrast_*` block
contains their member-difference counterparts. Together, these blocks
allow the two members to have different random slopes while preserving
exchangeability.

#### Transforming DIM random slopes to APIM slopes

Applying the same transformation to the random-slope coefficients
proceeds in two steps. First, transform the DIM dyad-mean and
within-dyad member-deviation random slopes into APIM actor and partner
random slopes. Random effects use $`u`$, with subscripts that write out
`actor`, `partner`, `mean`, and `dev`. For the shared block,

``` math
u_{\mathrm{actor},j}
= \frac{u_{\mathrm{mean},j} + u_{\mathrm{dev},j}}{2},
\qquad
u_{\mathrm{partner},j}
= \frac{u_{\mathrm{mean},j} - u_{\mathrm{dev},j}}{2},
```

and for the `.dy_member_contrast_*` block, marked by a tilde,

``` math
\widetilde{u}_{\mathrm{actor},j}
= \frac{\widetilde{u}_{\mathrm{mean},j} + \widetilde{u}_{\mathrm{dev},j}}{2},
\qquad
\widetilde{u}_{\mathrm{partner},j}
= \frac{\widetilde{u}_{\mathrm{mean},j} - \widetilde{u}_{\mathrm{dev},j}}{2}.
```

The shared and `.dy_member_contrast_*` random intercepts remain
unchanged.

We now have the shared and `.dy_member_contrast_*` actor and partner
effects which are then back-transformed into the complete and more
readily interpretable member-specific actor-partner covariance matrix.
This is described in the [exchangeable random-slope back-transformation
in the APIM
vignette](https://pascal-kueng.github.io/dyadMLM/articles/apim.html#exchangeable-random-slope-back-transformation).
The APIM vignette also shows how to [test constraints on these random
effects](https://pascal-kueng.github.io/dyadMLM/articles/apim.html#fitted-constraints-and-omitted-blocks).

### Dynamic ILD models

Dynamic dyadic models are most directly expressed in APIM terms: a
member’s own lagged outcome represents stability, whereas the partner’s
lagged outcome represents influence. See the [dynamic ILD APIM
example](https://pascal-kueng.github.io/dyadMLM/articles/apim.html#dynamic-models)
for data preparation, a fitted model, and important cautions about
outcome lags in short time series.

Under exchangeability, the same fixed effects can be reparameterized as
lagged DIM effects. The lagged dyad mean describes how the members’
shared prior outcome level relates to their current outcomes, while the
lagged within-dyad member deviation describes how their prior difference
relates to their current difference. This changes the coefficient
parameterization, not the fitted values.

------------------------------------------------------------------------

Return to the [Actor-Partner Interdependence Model
vignette](https://pascal-kueng.github.io/dyadMLM/articles/apim.md), see
the [Dyadic Score Model
vignette](https://pascal-kueng.github.io/dyadMLM/articles/dsm.md) for a
related model specification, or return to the [online package
overview](https://pascal-kueng.github.io/dyadMLM/).

## References

Bolger, Niall, and Jean-Philippe Laurenceau. 2013. *Intensive
Longitudinal Methods: An Introduction to Diary and Experience Sampling
Research*. Guilford Press.
<https://www.guilford.com/books/Intensive-Longitudinal-Methods/Bolger-Laurenceau/9781462506781>.

Bolger, Niall, Jean-Philippe Laurenceau, and Ana DiGiovanni. 2025.
“Unified Analysis Model for Indistinguishable and Distinguishable
Dyads.” *Innovations in Interpersonal Relationships and Health Research:
Advancing the Integration of Interdisciplinary Approaches to Dyadic
Behavior Change*. <https://doi.org/10.17605/OSF.IO/WYDCJ>.

Gistelinck, Fien, and Tom Loeys. 2020. “Multilevel Autoregressive Models
for Longitudinal Dyadic Data.” *TPM - Testing, Psychometrics,
Methodology in Applied Psychology* 27 (3): 433–52.
<https://doi.org/10.4473/TPM27.3.7>.

Gottfredson, Nisha C. 2019. “A Straightforward Approach for Coping with
Unreliability of Person Means When Parsing Within-Person and
Between-Person Effects in Longitudinal Studies.” *Addictive Behaviors*
94: 156–61. <https://doi.org/10.1016/j.addbeh.2018.09.031>.

Iida, Masumi, Gwendolyn Seidman, and Patrick E. Shrout. 2018. “Models of
Interdependent Individuals Versus Dyadic Processes in Relationship
Research.” *Journal of Social and Personal Relationships* 35 (1): 59–88.
<https://doi.org/10.1177/0265407517725407>.

Kenny, David A, Deborah A Kashy, and William L Cook. 2006. *Dyadic Data
Analysis*. Guilford Press.

Rosario, Kareena S. del, and Tessa V. West. 2025. “A Practical Guide to
Specifying Random Effects in Longitudinal Dyadic Multilevel Modeling.”
*Advances in Methods and Practices in Psychological Science* 8 (3):
25152459251351286. <https://doi.org/10.1177/25152459251351286>.
