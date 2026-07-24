# Compare nested glmmTMB models fitted to equivalent data

Performs a likelihood-ratio test for two nested `glmmTMB` models. The
models may use ordinary data frames or
[dyadMLM_data](https://pascal-kueng.github.io/dyadMLM/reference/prepare_dyad_data.md)
objects, and their calls do not need to refer to the same R object.
Models may be supplied in either order. The model with fewer estimated
parameters is shown first in the result.

## Usage

``` r
compare_nested_glmmTMB_models(model1, model2)
```

## Arguments

- model1, model2:

  Two fitted `glmmTMB` models to compare.

## Value

An `anova`-style data frame containing model degrees of freedom,
information criteria, log-likelihoods, the likelihood-ratio statistic,
and its chi-squared p-value. When printed, a short conclusion interprets
the test at the 5% significance level.

## Details

Both model calls must use named data-frame objects that remain available
when the models are compared. The checks assume these objects have not
been modified since fitting. All ordinary data columns must be
identical, including their types and attributes. For `dyadMLM_data`,
package-generated columns may differ, but the original columns must be
identical. Ordinary and prepared data may be compared with each other.
Dyad metadata are checked when both models use `dyadMLM_data`. The
function also checks fitted rows, outcomes, weights and offsets, model
family and link, maximum-likelihood estimation, and model convergence.
Each model must use the same untransformed response column.

These checks establish that the models use equivalent observations. They
cannot establish that one model is mathematically nested within the
other. The caller remains responsible for supplying genuinely nested
models. The usual chi-squared reference distribution may also be
inappropriate when tested variance parameters are on the boundary.

## Examples

``` r
if (requireNamespace("glmmTMB", quietly = TRUE)) {
  restricted_data <- prepare_dyad_data(
    dyads_cross,
    dyad = coupleID,
    member = personID,
    role = gender,
    # All three observed compositions in `dyads_cross` are detected and retained
    # by default. This example focuses on `female-male` dyads, so we restrict the
    # analysis here.
    keep_compositions = "female-male"
  )
  full_data <- restricted_data

  restricted_model <- glmmTMB::glmmTMB(
    closeness ~ 1 + us(1 | coupleID),
    data = restricted_data
  )
  full_model <- glmmTMB::glmmTMB(
    closeness ~ gender + us(1 | coupleID),
    data = full_data
  )

  compare_nested_glmmTMB_models(restricted_model, full_model)
}
#> Likelihood-ratio test for nested models fitted to equivalent data
#> Assumes mathematical nesting and an appropriate chi-squared reference distribution.
#> 
#>                  Df    AIC    BIC  logLik deviance  Chisq Chi Df Pr(>Chisq)    
#> restricted_model  3 882.71 893.15 -438.36   876.71                             
#> full_model        4 813.42 827.35 -402.71   805.42 71.289      1  < 2.2e-16 ***
#> ---
#> Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1
#> 
#> Conclusion (5% level): The likelihood-ratio test provides evidence that `full_model` fits better than `restricted_model` (p < 0.001).
```
