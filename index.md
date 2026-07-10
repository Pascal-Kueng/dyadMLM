# interdep

`interdep` helps researchers prepare cross-sectional and intensive
longitudinal dyadic data for statistical models.

It supports dyadic datasets with distinguishable dyads, exchangeable
dyads, or mixed dyad types in the same data, such as female-male,
female-female, and male-male couples. Mixed dyad types are supported for
Actor-Partner Interdependence Model (APIM) preparation. Current
Dyad-Individual Model (DIM) and undirected Dyadic Score Model (DSM)
helpers require one exchangeable dyad composition.

Start with the [Getting
Started](https://pascal-kueng.github.io/interdep/articles/getting-started.html)
vignette for the main data-preparation workflow. The [documentation
site](https://pascal-kueng.github.io/interdep/) also includes the
[function
reference](https://pascal-kueng.github.io/interdep/reference/index.html).
The package documentation is organized around the main modeling tasks:

| Vignette | Focus |
|----|----|
| [Getting Started](https://pascal-kueng.github.io/interdep/articles/getting-started.html) | Data structure, validation, dyad compositions, generated columns, and basic preparation |
| APIM | Cross-sectional APIM preparation for distinguishable, exchangeable, and mixed dyad types |
| Intensive Longitudinal APIM | Temporal predictor decomposition and intensive longitudinal APIM preparation |
| [Dyad-Individual Model](https://pascal-kueng.github.io/interdep/articles/Dyad-Individual-Model.html) | DIM predictor construction and APIM-DIM equivalence for exchangeable dyads |
| Undirected Dyadic Score Model | Undirected DSM outcome and predictor construction |

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
#>       <int>    <int> <chr>          <dbl>        <dbl> <fct>         
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
  title = {interdep: Tools for Cross-Sectional and Intensive Longitudinal Dyadic Data},
  author = {Pascal Küng},
  year = {2026},
  note = {R package version 0.0.0.9000},
  url = {https://github.com/Pascal-Kueng/interdep},
}
```

An archival DOI will be added once the package has a public release
archive.
