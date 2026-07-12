
<!-- README.md is generated from README.Rmd. Please edit that file -->

# interdep

<!-- badges: start -->

[![R-CMD-check](https://github.com/Pascal-Kueng/interdep/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/Pascal-Kueng/interdep/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

`interdep` helps researchers prepare cross-sectional and intensive
longitudinal dyadic data for multilevel models, including generalized
multilevel models.

It supports dyadic datasets with distinguishable dyads, exchangeable
dyads, or mixed dyad types in the same data, such as female-male,
female-female, and male-male couples. It creates composition-aware,
model-ready columns for dyadic multilevel model parameterizations such
as the Actor-Partner Interdependence Model (APIM), Dyad-Individual Model
(DIM), and undirected Dyadic Score Model (DSM). Current DIM and
undirected DSM helpers require one exchangeable dyad composition.

Start with the vignettes, or scroll down for a quick-start.

| Vignette | Focus |
|----|----|
| [Getting Started](https://pascal-kueng.github.io/interdep/articles/getting-started.html) | Data structure, validation, dyad compositions, generated columns, and basic preparation |
| [Actor-Partner Interdependence Model](https://pascal-kueng.github.io/interdep/articles/apim.html) | APIM preparation and formulas for distinguishable, exchangeable, generalized, and intensive longitudinal dyads |
| [APIMs with Mixed Dyad Compositions](https://pascal-kueng.github.io/interdep/articles/mixed-apim.html) | APIMs that combine distinguishable and exchangeable dyad compositions in one analysis |
| [Dyad-Individual Model](https://pascal-kueng.github.io/interdep/articles/dim.html) | DIM predictor construction, formulas, and an interactive demonstration of APIM-DIM equivalence for exchangeable dyads |
| [Undirected Dyadic Score Model](https://pascal-kueng.github.io/interdep/articles/undirected-dsm.html) | Undirected DSM outcome and predictor construction, with model formulas |

For an in-depth tutorial covering data preparation, model fitting,
diagnostics, and assumption checks, see [Distinguishable and
Exchangeable Dyads: Bayesian Multilevel
Modelling](https://pascal-kueng.github.io/05DyadicDataAnalysis/). It
uses `interdep` for cross-sectional and intensive longitudinal APIM and
DIM workflows, with models fitted primarily using `brms`
([source](https://github.com/Pascal-Kueng/05DyadicDataAnalysis),
[DOI](https://doi.org/10.5281/zenodo.17400655)).

The tutorial does not cover models that combine distinguishable and
exchangeable dyads in a single analysis. For that workflow, see the
[Mixed-Composition APIM
vignette](https://pascal-kueng.github.io/interdep/articles/mixed-apim.html).

## Installation

You can install the development version of `interdep` from GitHub with:

``` r
# install.packages("pak")
pak::pak("Pascal-Kueng/interdep")
```

## Simple Cross-Sectional Example

Prepare distinguishable dyads for a cross-sectional APIM:

``` r
library(interdep)

prepared_data <- prepare_interdep_data(
  example_dyadic_crosssectional,
  group = coupleID,
  member = personID,
  role = gender,
  predictors = communication,
  model_type = "apim"
)

print(prepared_data)
#> # interdep data
#> # Rows: 190 | Dyads: 95 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID, role = gender
#> #
#> # Dyad compositions:
#> # female_x_male distinguishable 95 dyads
#> #
#> # Added columns:
#> #   .i_composition       inferred dyad composition
#> #   .i_composition_role  composition-specific member role
#> #   .i_is_*              composition-role indicator columns
#> #   .i_*_raw_actor       APIM actor predictor: actor's original predictor
#> #                        values
#> #   .i_*_raw_partner     APIM partner predictor: partner's original predictor
#> #                        values
#> #
#> # A tibble: 190 × 11
#>    personID coupleID gender communication satisfaction .i_composition
#>       <int>    <int> <fct>          <dbl>        <dbl> <fct>         
#>  1        1        1 female          4.79         4.37 female_x_male 
#>  2        2        1 male            3.80         2.34 female_x_male 
#>  3        3        2 female          2.91         2.44 female_x_male 
#>  4        4        2 male            6.51         6.08 female_x_male 
#>  5        5        3 female          5.70         5.87 female_x_male 
#>  6        6        3 male            8.22         9.66 female_x_male 
#>  7        7        4 female          5.28         6.50 female_x_male 
#>  8        8        4 male            4.89         3.08 female_x_male 
#>  9        9        5 female          6.01         7.41 female_x_male 
#> 10       10        5 male            4.32         1.47 female_x_male 
#> # ℹ 180 more rows
#> # ℹ 5 more variables: .i_composition_role <fct>,
#> #   .i_is_female_x_male_female <dbl>, .i_is_female_x_male_male <dbl>,
#> #   .i_communication_raw_actor <dbl>, .i_communication_raw_partner <dbl>
```

The prepared data contains the composition indicators and APIM
actor/partner predictor columns used in the model formulas below.

One possible APIM formula is:

``` r
simple_apim <- glmmTMB::glmmTMB(
  satisfaction ~ 

    # Gender-specific intercepts
    0 + .i_is_female_x_male_female + .i_is_female_x_male_male +

    # Gender-specific actor effects
    .i_communication_raw_actor:.i_is_female_x_male_female +
    .i_communication_raw_actor:.i_is_female_x_male_male +

    # Gender-specific partner effects
    .i_communication_raw_partner:.i_is_female_x_male_female +
    .i_communication_raw_partner:.i_is_female_x_male_male +

    # Dyad-level random effects represent the partner residual
    # variance-covariance structure
    (0 + .i_is_female_x_male_female + .i_is_female_x_male_male | coupleID),

  # With the residual variance-covariance represented by the dyad-level
  # random effects above, the Gaussian residual dispersion is fixed near zero.
  dispformula = ~ 0,
  family = gaussian(),
  data = prepared_data
)
```

## Citation

If you use `interdep`, please cite the package directly:

``` bibtex
@Manual{interdep,
  title = {interdep: Prepare Dyadic Data for Multilevel Models},
  author = {Pascal Küng},
  year = {2026},
  note = {R package version 0.0.0.9000},
  url = {https://github.com/Pascal-Kueng/interdep},
}
```

An archival DOI will be added once the package has a public release
archive.
