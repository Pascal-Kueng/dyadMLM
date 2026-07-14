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

### Residual random effects structure

### Interpretation

## The cross-sectional Gaussian exchangeable APIM

### Assumptions

### Residual random effects structure - and back-transformation

### Interpretation

## Testing distinguishability

Aside from using a Wald test on the first model, nested model
comparisons require models fit to the same prepared data object. Helpers
for creating those constrained columns are planned.

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

Gottfredson, Nisha C. 2019. “A Straightforward Approach for Coping with
Unreliability of Person Means When Parsing Within-Person and
Between-Person Effects in Longitudinal Studies.” *Addictive Behaviors*
94: 156–61. <https://doi.org/10.1016/j.addbeh.2018.09.031>.
