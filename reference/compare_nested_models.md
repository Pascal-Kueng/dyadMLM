# Compare nested glmmTMB models fitted to equivalent data

Performs a likelihood-ratio test for two nested `glmmTMB` models. The
models may use ordinary data frames or
[dyadMLM_data](https://pascal-kueng.github.io/dyadMLM/reference/prepare_dyad_data.md)
objects, and their calls do not need to refer to the same R object.
Models may be supplied in either order. The model with fewer estimated
parameters is shown first in the result.

## Usage

``` r
compare_nested_models(model1, model2, alpha = 0.05)
```

## Arguments

- model1, model2:

  Two fitted `glmmTMB` models to compare.

- alpha:

  Significance level used for the printed conclusion. Must be one number
  between 0 and 1.

## Value

An `anova`-style data frame containing model degrees of freedom,
information criteria, log-likelihoods, the likelihood-ratio statistic,
and its chi-squared p-value. When printed, a short conclusion interprets
the test at the selected significance level.

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
`alpha` affects only the printed conclusion, not the test results.

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
    keep_compositions = "female-male",
    include_arbitrary_member_contrast = TRUE,
    seed = 123
  )
  full_data <- restricted_data

  # Compare an exchangeable model with a distinguishable model.
  restricted_model <- glmmTMB::glmmTMB(
    closeness ~ 1 +
      us(1 | coupleID) +
      us(0 + .member_contrast_arbitrary | coupleID),
    dispformula = ~ 0,
    data = restricted_data
  )

  full_model <- glmmTMB::glmmTMB(
    closeness ~ 0 + gender +
      us(0 + gender | coupleID),
    dispformula = ~ 0,
    data = full_data
  )

  # Test equal means and residual variances jointly.
  compare_nested_models(restricted_model, full_model)
}
#> Likelihood-ratio test for nested models fitted to equivalent data
#> Assumes mathematical nesting and an appropriate chi-squared reference distribution.
#> 
#>                  Df    AIC    BIC  logLik deviance  Chisq Chi Df Pr(>Chisq)    
#> restricted_model  3 894.85 905.29 -444.42   888.85                             
#> full_model        5 821.88 839.28 -405.94   811.88 76.966      2  < 2.2e-16 ***
#> ---
#> Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1
#> 
#> Conclusion (5% level): The likelihood-ratio test provides evidence that `full_model` fits better than `restricted_model` (p < 0.001).
```
