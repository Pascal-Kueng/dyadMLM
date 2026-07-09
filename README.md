
<!-- README.md is generated from README.Rmd. Please edit that file -->

# interdep

<!-- badges: start -->

<!-- badges: end -->

`interdep` helps researchers prepare cross-sectional and intensive
longitudinal dyadic data for statistical models.

It supports common dyadic studies with one kind of dyad, and it also
handles studies where different kinds of dyads appear in the same
dataset, such as female-male, female-female, and male-male couples.
Mixed dyad compositions are supported for composition-aware APIM-style
preparation; current DIM and undirected DSM helpers require one
exchangeable dyad composition.

The “Getting Started” vignette demonstrates how prepared data can be
used to estimate dyadic models, including generalized intensive
longitudinal APIMs with multiple dyad types in a single model.

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

## Installation

You can install the development version of `interdep` from GitHub with:

``` r
# install.packages("pak")
pak::pak("Pascal-Kueng/interdep")
```

## Example

``` r
library(interdep)

prepared <- prepare_interdep_data(
  example_dyadic_crosssectional,
  group = coupleID,
  member = personID,
  role = gender
)

prepared
#> # interdep data
#> # Rows: 190 | Dyads: 95 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID, role = gender
#> #
#> # Dyad compositions:
#> # female_x_male distinguishable 95 dyads
#> #
#> # Added columns:
#> #   .i_composition                     inferred dyad composition
#> #   .i_composition_role                composition-specific member role
#> #   .i_is_*                            composition-role indicator columns
#> #   .i_diff                            sum-diff contrast; 0 for distinguishable dyads
#> #
#> # A tibble: 190 × 10
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
#> # ℹ 4 more variables: .i_composition_role <fct>, .i_diff <dbl>,
#> #   .i_is_female_x_male_female <dbl>, .i_is_female_x_male_male <dbl>
```

The prepared data includes `.i_composition_role`, formula-friendly
`.i_is_*` indicators, and `.i_diff` / `.i_diff_*` columns for
exchangeable dyads.

Use `incomplete_dyads` and `missing_role` to choose whether incomplete
dyads or unresolved role information should error or be dropped. See the
vignette for examples.
