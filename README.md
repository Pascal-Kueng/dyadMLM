
<!-- README.md is generated from README.Rmd. Please edit that file -->

# interdep

<!-- badges: start -->

<!-- badges: end -->

`interdep` helps researchers prepare cross-sectional and intensive
longitudinal dyadic data for statistical models.

It supports dyadic datasets with distinguishable dyads, exchangeable
dyads, or mixed dyad compositions in the same data, such as female-male,
female-female, and male-male couples. Mixed dyad compositions are
supported for Actor-Partner Interdependence Model (APIM) preparation.
Current Dyad-Individual Model (DIM) and undirected Dyadic Score Model
(DSM) helpers require one exchangeable dyad composition.

Start with `vignette("getting-started", package = "interdep")` for the
main data-preparation workflow. The package documentation is organized
around the main modeling tasks:

| Vignette | Focus |
|----|----|
| `vignette("getting-started", package = "interdep")` | Data structure, validation, dyad compositions, generated columns, and basic preparation |
| `vignette("apim", package = "interdep")` | Cross-sectional APIM preparation for distinguishable, exchangeable, and mixed dyad compositions |
| `vignette("intensive-longitudinal-apim", package = "interdep")` | Temporal predictor decomposition and intensive longitudinal APIM preparation |
| `vignette("Dyad-Individual-Model", package = "interdep")` | DIM predictor construction and APIM-DIM equivalence for exchangeable dyads |
| `vignette("undirected-dyadic-score-model", package = "interdep")` | Undirected DSM outcome and predictor construction |

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

## Brief ILD example

For intensive longitudinal data, provide a `time` variable. Predictor
columns are decomposed into within-person and between-person components
before APIM actor and partner columns are created.

``` r
ild_data <- prepare_interdep_data(
  example_dyadic_ILD_unified_tweedie,
  group = coupleID,
  member = personID,
  role = gender,
  time = diaryday,
  predictors = c(provided_support, physical_activity),
  model_type = "apim"
)

print(ild_data)
#> # interdep data
#> # Rows: 5600 | Dyads: 200 | Intensive longitudinal: yes
#> # Structure: group = coupleID, member = personID, role = gender, time = diaryday
#> #
#> # Dyad compositions:
#> # female_x_female exchangeable    60 dyads
#> # female_x_male   distinguishable 80 dyads
#> # male_x_male     exchangeable    60 dyads
#> #
#> # Added columns:
#> #   .i_composition       inferred dyad composition
#> #   .i_composition_role  composition-specific member role
#> #   .i_is_*              composition-role indicator columns
#> #   .i_diff_*            composition-specific sum-diff contrasts; 0 for
#> #                        distinguishable dyads or other exchangeable
#> #                        compositions
#> #   .i_*_cwp             within-person predictor: momentary deviations from
#> #                        each person's usual level
#> #   .i_*_cbp             between-person predictor: stable differences from the
#> #                        average person's usual level
#> #   .i_*_cwp_actor       APIM within-person actor predictor: actor's momentary
#> #                        deviations from their usual level
#> #   .i_*_cwp_partner     APIM within-person partner predictor: partner's
#> #                        momentary deviations from their usual level
#> #   .i_*_cbp_actor       APIM between-person actor predictor: actor's stable
#> #                        difference from the average person's usual level
#> #   .i_*_cbp_partner     APIM between-person partner predictor: partner's
#> #                        stable difference from the average person's usual
#> #                        level
#> #
#> # A tibble: 5,600 × 26
#>    personID coupleID diaryday gender physical_activity provided_support
#>       <int>    <int>    <int> <chr>              <dbl>            <dbl>
#>  1        1        1        0 female             11.4              3.92
#>  2        1        1        1 female              2.24             3.86
#>  3        1        1        2 female              8.14             4.15
#>  4        1        1        3 female              4.48             3.55
#>  5        1        1        4 female              2.39             4.13
#>  6        1        1        5 female             10.1              3.50
#>  7        1        1        6 female              4.95             4.29
#>  8        1        1        7 female             NA               NA   
#>  9        1        1        8 female              0                4.06
#> 10        1        1        9 female              5.59             4.41
#> # ℹ 5,590 more rows
#> # ℹ 20 more variables: .i_composition <fct>, .i_composition_role <fct>,
#> #   .i_is_female_x_female <dbl>, .i_is_female_x_male_female <dbl>,
#> #   .i_is_female_x_male_male <dbl>, .i_is_male_x_male <dbl>,
#> #   .i_diff_female_x_female <dbl>, .i_diff_male_x_male <dbl>,
#> #   .i_provided_support_cwp <dbl>, .i_provided_support_cbp <dbl>,
#> #   .i_physical_activity_cwp <dbl>, .i_physical_activity_cbp <dbl>, …
```

This example dataset contains mixed dyad compositions: female-male dyads
are distinguishable, while female-female and male-male dyads are
exchangeable. `interdep` creates composition-specific indicators and
`.i_diff_*` columns so these dyad types can be modeled together. The
APIM vignette covers these mixed composition models in more detail.

For DIM and undirected DSM preparation, see the dedicated vignettes
listed above.

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
