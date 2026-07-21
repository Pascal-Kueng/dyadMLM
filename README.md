
<!-- README.md is generated from README.Rmd. Please edit that file -->

# dyadMLM

<!-- badges: start -->

[![R-CMD-check](https://github.com/Pascal-Kueng/dyadMLM/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/Pascal-Kueng/dyadMLM/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

`dyadMLM` provides tools for dyadic multilevel modeling with linear and
generalized linear mixed-effects models. It validates and prepares
cross-sectional and intensive longitudinal dyadic data.

It supports dyadic datasets with distinguishable dyads, exchangeable
dyads, or mixed dyad types in the same data, such as female-male,
female-female, and male-male couples. It creates composition-aware,
model-ready columns for dyadic multilevel model parameterizations such
as the Actor-Partner Interdependence Model (APIM), Dyad-Individual Model
(DIM), and Dyadic Score Model (DSM).

Selected post-estimation tools compare compatible fitted models and
back-transform exchangeable random-effect covariance structures into
member-level quantities.

Start with the vignettes, or scroll down for a quick-start.

| Vignette | Focus |
|----|----|
| [Getting Started](https://pascal-kueng.github.io/dyadMLM/articles/getting-started.html) | Data structure, validation, dyad compositions, generated columns, and basic preparation |
| [Actor-Partner Interdependence Model](https://pascal-kueng.github.io/dyadMLM/articles/apim.html) | APIM preparation and formulas for distinguishable and exchangeable dyads in cross-sectional and intensive longitudinal data |
| [APIMs with Mixed Dyad Compositions](https://pascal-kueng.github.io/dyadMLM/articles/mixed-apim.html) | APIMs that combine distinguishable and exchangeable dyad compositions in one analysis |
| [Dyad-Individual Model](https://pascal-kueng.github.io/dyadMLM/articles/dim.html) | DIM predictor construction, formulas, and an interactive demonstration of APIM-DIM equivalence for exchangeable dyads |
| [Dyadic Score Model](https://pascal-kueng.github.io/dyadMLM/articles/dsm.html) | DSM predictor-score and contrast construction, formulas, and the relationship between the DSM and APIM for distinguishable dyads |

For an in-depth tutorial covering data preparation, model fitting,
diagnostics, and assumption checks, see [Distinguishable and
Exchangeable Dyads: Bayesian Multilevel
Modelling](https://pascal-kueng.github.io/05DyadicDataAnalysis/). It
uses `dyadMLM` for cross-sectional and intensive longitudinal APIM and
DIM workflows, with models fitted primarily using `brms`
([source](https://github.com/Pascal-Kueng/05DyadicDataAnalysis),
[DOI](https://doi.org/10.5281/zenodo.17400655)).

## Installation

You can install the development version of `dyadMLM` from GitHub with:

``` r
# install.packages("pak")
pak::pak("Pascal-Kueng/dyadMLM")
```

## Simple Cross-Sectional Example

Prepare distinguishable dyads for a cross-sectional APIM:

``` r
library(dyadMLM)

prepared_data <- prepare_dyad_data(
  example_dyadic_crosssectional,
  dyad = coupleID,
  member = personID,
  role = gender,
  predictors = communication,
  model_types = "apim"
)

print(prepared_data, n = 4)
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

The prepared data contains the composition indicators and APIM
actor/partner predictor columns used in the model formulas below.

One simple distinguishable APIM formula is:

``` r
simple_apim <- glmmTMB::glmmTMB(
  satisfaction ~ 

    # Gender-specific intercepts
    0 + .dy_is_female_x_male_female + .dy_is_female_x_male_male +

    # Gender-specific actor effects
    .dy_communication_actor:.dy_is_female_x_male_female +
    .dy_communication_actor:.dy_is_female_x_male_male +

    # Gender-specific partner effects
    .dy_communication_partner:.dy_is_female_x_male_female +
    .dy_communication_partner:.dy_is_female_x_male_male +

    # Dyad-level random effects represent the two members'
    # residual covariance structure
    us(0 + .dy_is_female_x_male_female + .dy_is_female_x_male_male | coupleID),

  # With the residual covariance represented by the dyad-level
  # random effects above, the Gaussian residual dispersion is fixed near zero.
  dispformula = ~ 0,
  family = gaussian(),
  data = prepared_data
)
```

## Citation

If you use `dyadMLM`, please cite the package directly:

``` bibtex
@Manual{dyadMLM,
  title = {dyadMLM: Tools for Dyadic Multilevel Models},
  author = {Pascal Küng},
  year = {2026},
  note = {R package version 0.0.1},
  url = {https://github.com/Pascal-Kueng/dyadMLM},
}
```

An archival DOI will be added once the package has a public release
archive.

------------------------------------------------------------------------

**Continue** with the [Getting Started
Vignette](https://pascal-kueng.github.io/dyadMLM/articles/getting-started.html).

Or go directly to a model-specific vignette:

- [Actor-Partner Interdependence Model (APIM)
  vignette](https://pascal-kueng.github.io/dyadMLM/articles/apim.html),
- [Mixed-Composition APIM
  vignette](https://pascal-kueng.github.io/dyadMLM/articles/mixed-apim.html),
- [Dyad-Individual Model
  vignette](https://pascal-kueng.github.io/dyadMLM/articles/dim.html),
  or
- [Dyadic Score Model
  vignette](https://pascal-kueng.github.io/dyadMLM/articles/dsm.html).
