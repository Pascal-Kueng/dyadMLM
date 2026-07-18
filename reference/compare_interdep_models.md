# Compare nested models fitted to equivalent interdep data

Performs a likelihood-ratio test for two nested `glmmTMB` models fitted
to separate
[interdep_data](https://pascal-kueng.github.io/interdep/reference/prepare_interdep_data.md)
objects. Unlike `anova.glmmTMB()`, the model calls do not need to refer
to the same R object. The function instead checks that the prepared data
contain the same original observations before comparing the models.

## Usage

``` r
compare_interdep_models(full, restricted)
```

## Arguments

- full:

  The full (larger) fitted `glmmTMB` model.

- restricted:

  The restricted (smaller) fitted `glmmTMB` model.

## Value

An `anova`-style data frame containing model degrees of freedom,
information criteria, log-likelihoods, the likelihood-ratio statistic,
and its chi-squared p-value.

## Details

Both model calls must use named `interdep_data` objects that remain
available when the models are compared. The checks assume these objects
have not been modified since fitting. Each model must use the same
untransformed response column. The function requires exactly identical
original, non-`.i_` columns, including their types and attributes. It
also checks structural dyad metadata, fitted rows, outcomes, weights and
offsets, model family and link, maximum-likelihood estimation, and model
convergence.

These checks establish that the models use equivalent observations. They
cannot establish that one model is mathematically nested within the
other. The caller remains responsible for supplying a genuinely
restricted model and its corresponding full model. The usual chi-squared
reference distribution may also be inappropriate when tested variance
parameters are on the boundary.

## Examples

``` r
if (requireNamespace("glmmTMB", quietly = TRUE)) {
  restricted_data <- prepare_interdep_data(
    example_dyadic_crosssectional,
    group = coupleID,
    member = personID,
    role = gender
  )
  full_data <- restricted_data

  restricted_model <- glmmTMB::glmmTMB(
    satisfaction ~ 1 + us(1 | coupleID),
    data = restricted_data
  )
  full_model <- glmmTMB::glmmTMB(
    satisfaction ~ gender + us(1 | coupleID),
    data = full_data
  )

  compare_interdep_models(
    full = full_model,
    restricted = restricted_model
  )
}
#> Likelihood-ratio test for nested models fitted to equivalent interdep data
#> Mathematical nesting is assumed and cannot be verified from the data alone.
#> 
#>                  Df    AIC    BIC  logLik deviance  Chisq Chi Df Pr(>Chisq)   
#> restricted_model  3 917.29 926.98 -455.64   911.29                            
#> full_model        4 908.52 921.45 -450.26   900.52 10.765      1   0.001034 **
#> ---
#> Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1
```
