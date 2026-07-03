
<!-- README.md is generated from README.Rmd. Please edit that file -->

# interdep

<!-- badges: start -->

<!-- badges: end -->

`interdep` is being developed for dyadic data analysis. It currently
provides a basic preparation function for validating long-format dyadic
data and deriving dyad-composition metadata.

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
#> # A tibble: 190 × 9
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
#> # ℹ 3 more variables: .i_composition_role <fct>,
#> #   .i_is_female_x_male_x_female <dbl>, .i_is_female_x_male_x_male <dbl>
```

Use `incomplete_dyads` and `missing_role` to choose whether incomplete
dyads or unresolved role information should error, be dropped, or be
kept with unknown composition labels. See the vignette for examples.
