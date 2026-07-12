# Undirected Dyadic Score Model (DSM)

``` r

library(interdep)
```

This vignette focuses on undirected Dyadic Score Model (DSM)
preparation. For the main data requirements and validation workflow,
start with the [Getting Started
vignette](https://pascal-kueng.github.io/interdep/articles/getting-started.md).
For actor-partner predictor preparation, see the [Actor-Partner
Interdependence Model
vignette](https://pascal-kueng.github.io/interdep/articles/apim.md). For
APIMs that combine distinguishable and exchangeable dyad compositions,
see the [Mixed-Composition APIM
vignette](https://pascal-kueng.github.io/interdep/articles/mixed-apim.md).
For dyad-mean and within-dyad-deviation predictors, see the
[Dyad-Individual Model
vignette](https://pascal-kueng.github.io/interdep/articles/dim.md).

> This vignette is under construction and for now only contains a few
> preliminary example models. Please check back soon!

The model is an expantion of the DIM, but we now also decompose the
outcome. In preparaten, we therefore need to specify which variable is
the outcome.

``` r

cross_exchangeable_data <- prepare_interdep_data(
  example_dyadic_crosssectional,
  group = coupleID,
  member = personID,
  predictors = communication,
  outcomes = satisfaction,
  # Create both APIM and DSM columns for comparison.
  model_type = c("apim", "undirected_dsm"),
  seed = 123
)

# Print the first two dyads.
print(cross_exchangeable_data, n = 4)
#> # interdep data
#> # Rows: 190 | Dyads: 95 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID
#> #
#> # Dyad compositions:
#> # assumed_exchangeable exchangeable 95 dyads
#> #
#> # Added columns:
#> #   .i_composition                       inferred dyad composition
#> #   .i_composition_role                  composition-specific member role
#> #   .i_is_{comp-role}                    composition-role indicator columns
#> #   .i_diff_{comp}                       composition-specific sum-diff
#> #                                        contrasts with arbitrary direction; 0
#> #                                        for distinguishable dyads or other
#> #                                        exchangeable compositions
#> #   .i_{pred}_raw_actor                  APIM actor predictor: actor's original
#> #                                        predictor values
#> #   .i_{pred}_raw_partner                APIM partner predictor: partner's
#> #                                        original predictor values
#> #   .i_{pred}_raw_dyad_mean_gmc          DIM dyad-mean predictor: dyad's
#> #                                        average predictor level, grand-mean
#> #                                        centered
#> #   .i_{pred}_raw_within_dyad_deviation  DIM within-dyad predictor deviation:
#> #                                        person's difference from the dyad
#> #                                        average
#> #   .i_{out}_raw_dyad_mean               DSM dyad-mean outcome: dyad's average
#> #                                        outcome level
#> #   .i_{out}_raw_within_dyad_deviation   DSM within-dyad outcome deviation:
#> #                                        person's difference from the dyad
#> #                                        average
#> #
#> # A tibble: 190 × 15
#>   personID coupleID gender communication satisfaction .i_composition      
#>      <int>    <int> <fct>          <dbl>        <dbl> <fct>               
#> 1        1        1 female          4.79         4.37 assumed_exchangeable
#> 2        2        1 male            3.80         2.34 assumed_exchangeable
#> 3        3        2 female          2.91         2.44 assumed_exchangeable
#> 4        4        2 male            6.51         6.08 assumed_exchangeable
#> # ℹ 186 more rows
#> # ℹ 9 more variables: .i_composition_role <fct>,
#> #   .i_is_assumed_exchangeable <dbl>,
#> #   .i_diff_assumed_exchangeable_arbitrary <dbl>,
#> #   .i_communication_raw_actor <dbl>, .i_communication_raw_partner <dbl>,
#> #   .i_communication_raw_dyad_mean_gmc <dbl>,
#> #   .i_communication_raw_within_dyad_deviation <dbl>, …
```

For the main data-preparation workflow, return to the [Getting Started
vignette](https://pascal-kueng.github.io/interdep/articles/getting-started.md).
For actor-partner models, see the [Actor-Partner Interdependence Model
vignette](https://pascal-kueng.github.io/interdep/articles/apim.md) and
the advanced [Mixed-Composition APIM
vignette](https://pascal-kueng.github.io/interdep/articles/mixed-apim.md).
For the DIM parameterization, see the [Dyad-Individual Model
vignette](https://pascal-kueng.github.io/interdep/articles/dim.md).

For an in-depth tutorial covering data preparation, model fitting,
diagnostics, and assumption checks, see [Distinguishable and
Exchangeable Dyads: Bayesian Multilevel
Modelling](https://pascal-kueng.github.io/05DyadicDataAnalysis/). It
uses `interdep` for cross-sectional and intensive longitudinal APIM and
DIM workflows, with models fitted primarily using `brms`
([source](https://github.com/Pascal-Kueng/05DyadicDataAnalysis),
[DOI](https://doi.org/10.5281/zenodo.17400655)).
