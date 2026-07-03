
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

attr(prepared, "interdep")$dyad_compositions
#> # A tibble: 1 × 4
#>   raw_composition composition  dyad_type       n_dyads
#>   <chr>           <chr>        <chr>             <int>
#> 1 female_x_male   female_x_male distinguishable      95
```

Use `incomplete_dyads` and `missing_role` to choose whether incomplete
dyads or unresolved role information should error, be dropped, or be
kept with unknown composition labels. See the vignette for examples.
