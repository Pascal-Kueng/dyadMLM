# Compare nested models fitted to equivalent interdep data

Performs a likelihood-ratio test for two nested `glmmTMB` models fitted
to separate
[interdep_data](https://pascal-kueng.github.io/interdep/reference/prepare_interdep_data.md)
objects. Unlike `anova.glmmTMB()`, the model calls do not need to refer
to the same R object. The function instead checks that the prepared data
contain the same original observations before comparing the models.

## Usage

``` r
compare_interdep_models(full, restricted, alpha = 0.05)
```

## Arguments

- full:

  The full (larger) fitted `glmmTMB` model.

- restricted:

  The restricted (smaller) fitted `glmmTMB` model.

- alpha:

  Significance level used for the printed interpretation.

## Value

An `anova`-style data frame containing model degrees of freedom,
information criteria, log-likelihoods, the likelihood-ratio statistic,
and its chi-squared p-value. Printing the result adds a cautious
interpretation based on `alpha`.

## Details

Both model calls must use named `interdep_data` objects. The function
checks the original, non-`.i_` columns, structural dyad metadata,
outcome values and missingness, fitted row identities, model family and
link, maximum-likelihood estimation, and model convergence.

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
    satisfaction ~ 1 + (1 | coupleID),
    data = restricted_data
  )
  full_model <- glmmTMB::glmmTMB(
    satisfaction ~ gender + (1 | coupleID),
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
#> 
#> Under the assumed nesting and chi-squared reference distribution, the test provides evidence that `restricted_model` fits the data worse than `full_model` (likelihood-ratio test: χ²(1) = 10.77, p = 0.001).
```
