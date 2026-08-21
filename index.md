# dyadMLM

`dyadMLM` provides tools for dyadic multilevel modeling with linear and
generalized linear mixed-effects models.

It provides supporting functions for:

1.  [Data preparation and validation of dyadic
    data](#id_1-data-preparation-and-validation)
2.  [Post-estimation tools](#id_2-post-estimation-tools)

You can install the development version with:

``` r

install.packages("dyadMLM", repos = c(
  "https://pascal-kueng.r-universe.dev",
  "https://cloud.r-project.org"
  )
)
```

## 1. Data preparation and validation

The core feature of this package is data preparation and validation for
various types of dyadic data. It creates model-ready columns for dyadic
multilevel models, including the Actor-Partner Interdependence Model
(APIM), Dyad-Individual Model (DIM), and the Dyadic Score Model (DSM).

The package currently supports:

- cross-sectional and intensive longitudinal dyadic data (e.g., daily
  diary data)
- distinguishable and exchangeable (indistinguishable) dyads
- datasets containing multiple dyad compositions (e.g., opposite-sex
  partners and same-sex partners)

See the [Getting Started
vignette](https://pascal-kueng.github.io/dyadMLM/articles/getting-started.html).

## 2. Post-estimation tools

Selected post-estimation tools currently include:

- a function to compare compatible nested models
- a function to back-transform exchangeable random-effect covariance
  structures into interpretable member-level quantities, as described in
  the [APIM
  vignette](https://pascal-kueng.github.io/dyadMLM/articles/apim.html)

## Vignettes and examples

Start with the vignettes, or scroll down for a quick example.

| Vignette | Focus |
|----|----|
| [Getting Started](https://pascal-kueng.github.io/dyadMLM/articles/getting-started.html) | Data structure, validation, dyad compositions, generated columns, and basic preparation |
| [Actor-Partner Interdependence Model](https://pascal-kueng.github.io/dyadMLM/articles/apim.html) | APIM preparation and formulas for distinguishable and exchangeable dyads in cross-sectional and intensive longitudinal data |
| [Dyad-Individual Model](https://pascal-kueng.github.io/dyadMLM/articles/dim.html) | DIM predictor construction, formulas, and an interactive demonstration of APIM-DIM equivalence for exchangeable dyads |
| [Dyadic Score Model](https://pascal-kueng.github.io/dyadMLM/articles/dsm.html) | DSM predictor-score and contrast construction, formulas, and the relationship between the DSM and APIM for distinguishable dyads |

For theoretical foundations and a practical walkthrough of dyadic data
analysis, from data preparation and model fitting to interpretation and
diagnostics using `dyadMLM` with `glmmTMB`, see the [Dyadic Data
Analysis Workshop](https://pascal-kueng.github.io/dyadMLM/workshop/).
For a Bayesian workflow using `dyadMLM` and `brms`, refer to
[Distinguishable and Exchangeable Dyads: Bayesian Multilevel
Modelling](https://pascal-kueng.github.io/05DyadicDataAnalysis/)
([source](https://github.com/Pascal-Kueng/05DyadicDataAnalysis),
[DOI](https://doi.org/10.5281/zenodo.17400655)).

### Simple Cross-Sectional Example

Prepare distinguishable dyads for a cross-sectional APIM:

``` r

library(dyadMLM)

prepared_data <- prepare_dyad_data(
  dyads_cross,
  dyad = coupleID,
  member = personID,
  role = gender,
  predictors = provided_support,
  model_types = "apim",
  # All three observed compositions in `dyads_cross` are detected and retained by
  # default. This example focuses on `female-male` dyads, so we restrict the
  # analysis here.
  keep_compositions = "female-male"
)

print(prepared_data, n = 4)
#> # dyadMLM data
#> # Rows: 240 | Dyads: 120 | Intensive longitudinal: no
#> # Structure: dyad = coupleID, member = personID, role = gender
#> #
#> # Dyad compositions:
#> # female_x_male distinguishable 120 dyads
#> #
#> # Added columns:
#> #   .composition       inferred dyad composition
#> #   .composition_role  composition-specific member role
#> #   .is_{role}         composition-role indicator columns
#> #   .{pred}_actor      APIM actor predictor: actor's original predictor values
#> #   .{pred}_partner    APIM partner predictor: partner's original predictor
#> #                      values
#> #
#> # A tibble: 240 × 11
#>   personID coupleID gender closeness provided_support .composition
#>      <int>    <int> <fct>      <dbl>            <dbl> <fct>
#> 1        1        1 female      4.71             4.49 female_x_male
#> 2        2        1 male        4.61             4.76 female_x_male
#> 3        3        2 female      6.69             4.09 female_x_male
#> 4        4        2 male        5.98             6.20 female_x_male
#> # ℹ 236 more rows
#> # ℹ 5 more variables: .composition_role <fct>, .is_female <dbl>,
#> #   .is_male <dbl>, .provided_support_actor <dbl>,
#> #   .provided_support_partner <dbl>
```

The prepared data contains the composition indicators and APIM
actor/partner predictor columns used in the model formulas below.

One simple distinguishable APIM formula is:

``` r

simple_apim <- glmmTMB::glmmTMB(
  closeness ~

    # Gender-specific intercepts
    0 + .is_female + .is_male +

    # Gender-specific actor effects
    .provided_support_actor:.is_female +
    .provided_support_actor:.is_male +

    # Gender-specific partner effects
    .provided_support_partner:.is_female +
    .provided_support_partner:.is_male +

    # Dyad-level random effects represent the two members'
    # residual covariance structure
    us(0 + .is_female + .is_male | coupleID),

  # With the residual covariance represented by the dyad-level
  # random effects above, the Gaussian residual dispersion is fixed near zero.
  dispformula = ~ 0,
  family = gaussian(),
  data = prepared_data
)
```

## Citation

If you use `dyadMLM`, please cite the installed package version. Run:

``` r

citation("dyadMLM")
#> To cite package 'dyadMLM' in publications use:
#>
#>   Küng P (2026). _dyadMLM: Tools for Dyadic Multilevel Models_.
#>   doi:10.5281/zenodo.21481720
#>   <https://doi.org/10.5281/zenodo.21481720>. R package version
#>   0.2.0.9000, <https://pascal-kueng.github.io/dyadMLM/>.
#>
#> A BibTeX entry for LaTeX users is
#>
#>   @Manual{,
#>     title = {dyadMLM: Tools for Dyadic Multilevel Models},
#>     author = {Pascal Küng},
#>     year = {2026},
#>     note = {R package version 0.2.0.9000},
#>     url = {https://pascal-kueng.github.io/dyadMLM/},
#>     doi = {10.5281/zenodo.21481720},
#>   }
```

------------------------------------------------------------------------

**Continue** with the [Getting Started
Vignette](https://pascal-kueng.github.io/dyadMLM/articles/getting-started.html).

Or go directly to a model-specific vignette:

- [Actor-Partner Interdependence Model (APIM)
  vignette](https://pascal-kueng.github.io/dyadMLM/articles/apim.html),
- [Dyad-Individual Model
  vignette](https://pascal-kueng.github.io/dyadMLM/articles/dim.html),
  or
- [Dyadic Score Model
  vignette](https://pascal-kueng.github.io/dyadMLM/articles/dsm.html).
