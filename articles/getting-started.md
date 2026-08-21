# Getting Started

``` r

library(dyadMLM)
```

## Installation

You can install the development version with:

``` r

install.packages("dyadMLM", repos = c(
  "https://pascal-kueng.r-universe.dev",
  "https://cloud.r-project.org"
  )
)
```

## About this vignette

`dyadMLM` helps researchers prepare cross-sectional and intensive
longitudinal dyadic data for (generalized) multilevel models.

**This vignette focuses on automatic data preparation for multilevel
models (MLMs).** For a comparison of MLM and structural equation
modeling (SEM) approaches to dyadic data, see Ledermann and Kenny
(2017).

The model-fitting examples in the model-specific vignettes use the
`glmmTMB` package.

Post-processing functions in `dyadMLM`, including model comparison and
back-transformation of exchangeable random-effect covariance structures,
are described in the [Actor-Partner Interdependence Model
vignette](https://pascal-kueng.github.io/dyadMLM/articles/apim.html).

Other vignettes cover the [Dyad-Individual
Model](https://pascal-kueng.github.io/dyadMLM/articles/dim.md) and its
equivalence and back-transformation to the *exchangeable APIM*, and the
[Dyadic Score
Model](https://pascal-kueng.github.io/dyadMLM/articles/dsm.md) with its
equivalence and back-transformation to the *distinguishable APIM*.

The [online package overview](https://pascal-kueng.github.io/dyadMLM/)
provides the current online versions of these vignettes and the complete
function reference.

## Prerequisites

The basic data structure needed for `dyadMLM` is a long data frame where
dyads are stacked on top of each other and both members of a dyad appear
as separate rows.

Roughly, the expected structure for `dyadMLM` is:

- For cross-sectional data: one row per `dyad x member`

| dyad | member |   x |   y |
|-----:|-------:|----:|----:|
|    1 |      1 | 4.2 | 7.1 |
|    1 |      2 | 5.0 | 6.4 |
|    2 |      1 | 3.8 | 5.9 |
|    2 |      2 | 4.5 | 6.8 |

- For intensive longitudinal data: at most one row per
  `dyad x time x member`

| dyad | time | member |   x |   y |
|-----:|-----:|-------:|----:|----:|
|    1 |    1 |      1 | 4.2 | 7.1 |
|    1 |    1 |      2 | 5.0 | 6.4 |
|    1 |    2 |      1 | 4.0 | 6.9 |
|    1 |    2 |      2 | 5.3 | 6.6 |

Measured variables may contain missing values, but `dyad`, `member`, and
optional `time` must be complete; missing measurement occasions may
instead be represented by absent rows.

If your raw data are currently in wide format (for time or dyads or
both), reshape them to this long structure first. See the [tidyr
pivoting vignette](https://tidyr.tidyverse.org/articles/pivot.html) or
the [`pivot_longer()`
reference](https://tidyr.tidyverse.org/reference/pivot_longer.html).

## Data preparation for distinguishable dyads

`dyads_cross` is a simulated cross-sectional dataset that contains three
dyad compositions.

Because these example data contain multiple compositions,
`keep_compositions` selects the composition modeled below. It can be
omitted when the supplied data already contain only the intended
composition.

    #>   personID coupleID gender closeness provided_support
    #> 1        1        1 female  4.705258         4.494570
    #> 2        2        1   male  4.608436         4.757241
    #> 3        3        2 female  6.690937         4.092390
    #> 4        4        2   male  5.976549         6.199226
    #> 5        5        3 female  5.272910         4.223651
    #> 6        6        3   male  4.366967         5.029079

We validate and prepare the data with the function
[`dyadMLM::prepare_dyad_data()`](https://pascal-kueng.github.io/dyadMLM/reference/prepare_dyad_data.md).

``` r

cross_distinguishable_data <- dyadMLM::prepare_dyad_data(
  data = dyads_cross,
  dyad = coupleID,
  member = personID,
  role = gender,
  predictors = provided_support,
  model_types = "apim",
  add_apim_gmc_predictors = TRUE, # Optional grand-mean centering

  # All three observed compositions in `dyads_cross` are detected and retained by
  # default. This example focuses on `female-male` dyads, so we restrict the
  # analysis here.
  keep_compositions = "female-male"
)

print(cross_distinguishable_data, n = 4)
#> # dyadMLM data
#> # Rows: 240 | Dyads: 120 | Intensive longitudinal: no
#> # Structure: dyad = coupleID, member = personID, role = gender
#> #
#> # Dyad compositions:
#> # female_x_male distinguishable 120 dyads
#> #
#> # Added columns:
#> #   .composition         inferred dyad composition
#> #   .composition_role    composition-specific member role
#> #   .is_{role}           composition-role indicator columns
#> #   .{pred}_actor        APIM actor predictor: actor's original predictor
#> #                        values
#> #   .{pred}_partner      APIM partner predictor: partner's original predictor
#> #                        values
#> #   .{pred}_gmc          APIM grand-mean-centered predictor source: original
#> #                        values minus the mean across all retained non-missing
#> #                        observations
#> #   .{pred}_gmc_actor    APIM grand-mean-centered actor predictor: actor's
#> #                        value relative to the mean across all retained
#> #                        non-missing observations
#> #   .{pred}_gmc_partner  APIM grand-mean-centered partner predictor: partner's
#> #                        value relative to the mean across all retained
#> #                        non-missing observations
#> #
#> # A tibble: 240 × 14
#>   personID coupleID gender closeness provided_support .composition 
#>      <int>    <int> <fct>      <dbl>            <dbl> <fct>        
#> 1        1        1 female      4.71             4.49 female_x_male
#> 2        2        1 male        4.61             4.76 female_x_male
#> 3        3        2 female      6.69             4.09 female_x_male
#> 4        4        2 male        5.98             6.20 female_x_male
#> # ℹ 236 more rows
#> # ℹ 8 more variables: .composition_role <fct>, .is_female <dbl>,
#> #   .is_male <dbl>, .provided_support_gmc <dbl>, .provided_support_actor <dbl>,
#> #   .provided_support_partner <dbl>, .provided_support_gmc_actor <dbl>,
#> #   .provided_support_gmc_partner <dbl>
```

The function retained 120 female-male dyads and created raw and
grand-mean centered APIM variables (Kenny and Cook 1999).

For fitted APIM examples using these columns, see the [Actor-Partner
Interdependence Model
vignette](https://pascal-kueng.github.io/dyadMLM/articles/apim.md).

## Data preparation for exchangeable dyads

For this example, we pretend that we have a dataset with no
distinguishable variable (e.g., same-sex friend dyads). Then, we simply
omit the `role` argument:

``` r

cross_exchangeable_data <- dyadMLM::prepare_dyad_data(
  data = dyads_cross,
  dyad = coupleID,
  member = personID,
  predictors = provided_support,
  model_types = "apim",
  add_apim_gmc_predictors = TRUE,
  seed = 123
)

print(cross_exchangeable_data, n = 4)
#> # dyadMLM data
#> # Rows: 720 | Dyads: 360 | Intensive longitudinal: no
#> # Structure: dyad = coupleID, member = personID
#> #
#> # Dyad compositions:
#> # assumed_exchangeable exchangeable 360 dyads
#> #
#> # Added columns:
#> #   .composition                inferred dyad composition
#> #   .composition_role           composition-specific member role
#> #   .is_exchangeable            composition-role indicator columns
#> #   .member_contrast_arbitrary  composition-specific member contrasts coded
#> #                               -1/+1 in arbitrary direction for
#> #                               exchangeability-constrained random effects.
#> #                               Values are 0 for other compositions
#> #   .{pred}_actor               APIM actor predictor: actor's original
#> #                               predictor values
#> #   .{pred}_partner             APIM partner predictor: partner's original
#> #                               predictor values
#> #   .{pred}_gmc                 APIM grand-mean-centered predictor source:
#> #                               original values minus the mean across all
#> #                               retained non-missing observations
#> #   .{pred}_gmc_actor           APIM grand-mean-centered actor predictor:
#> #                               actor's value relative to the mean across all
#> #                               retained non-missing observations
#> #   .{pred}_gmc_partner         APIM grand-mean-centered partner predictor:
#> #                               partner's value relative to the mean across all
#> #                               retained non-missing observations
#> #
#> # A tibble: 720 × 14
#>   personID coupleID gender closeness provided_support .composition        
#>      <int>    <int> <fct>      <dbl>            <dbl> <fct>               
#> 1        1        1 female      4.71             4.49 assumed_exchangeable
#> 2        2        1 male        4.61             4.76 assumed_exchangeable
#> 3        3        2 female      6.69             4.09 assumed_exchangeable
#> 4        4        2 male        5.98             6.20 assumed_exchangeable
#> # ℹ 716 more rows
#> # ℹ 8 more variables: .composition_role <fct>, .is_exchangeable <dbl>,
#> #   .member_contrast_arbitrary <dbl>, .provided_support_gmc <dbl>,
#> #   .provided_support_actor <dbl>, .provided_support_partner <dbl>,
#> #   .provided_support_gmc_actor <dbl>, .provided_support_gmc_partner <dbl>
```

The generated `.member_contrast_arbitrary` contrast assigns `-1` and `1`
to the two members of each exchangeable dyad (del Rosario and West
2025). Its direction is arbitrary, and `seed` makes the assignment
reproducible.

Refer to the APIM vignette’s [exchangeable APIM
section](https://pascal-kueng.github.io/dyadMLM/articles/apim.html#exchangeable-residual-structure)
for how to use these columns to specify an exchangeable dyadic APIM and
recover the constrained actor-partner variance-covariance structure with
[`dyadMLM::recover_exchangeable_covariance()`](https://pascal-kueng.github.io/dyadMLM/reference/recover_exchangeable_covariance.html).

## Generating DIM and DSM columns

For exchangeable dyads, we can request DIM predictor columns. **DIM
preparation requires exactly one exchangeable composition**. This can be
achieved by omitting `role`. For more control over compositions, see
[Working with multiple dyad
compositions](#working-with-multiple-dyad-compositions).

``` r

cross_dim_data <- dyadMLM::prepare_dyad_data(
  data = dyads_cross,
  dyad = coupleID,
  member = personID,
  predictors = provided_support,
  model_types = "dim",
  seed = 123
)

print(cross_dim_data, n = 4)
#> # dyadMLM data
#> # Rows: 720 | Dyads: 360 | Intensive longitudinal: no
#> # Structure: dyad = coupleID, member = personID
#> #
#> # Dyad compositions:
#> # assumed_exchangeable exchangeable 360 dyads
#> #
#> # Added columns:
#> #   .composition                inferred dyad composition
#> #   .composition_role           composition-specific member role
#> #   .is_exchangeable            composition-role indicator columns
#> #   .member_contrast_arbitrary  composition-specific member contrasts coded
#> #                               -1/+1 in arbitrary direction for
#> #                               exchangeability-constrained random effects.
#> #                               Values are 0 for other compositions
#> #   .{pred}_dyad_mean_gmc       dyad-mean predictor: dyad's average predictor
#> #                               level, grand-mean centered
#> #   .{pred}_within_dyad_dev     DIM within-dyad member-deviation predictor:
#> #                               member's difference from the dyad mean
#> #
#> # A tibble: 720 × 11
#>   personID coupleID gender closeness provided_support .composition        
#>      <int>    <int> <fct>      <dbl>            <dbl> <fct>               
#> 1        1        1 female      4.71             4.49 assumed_exchangeable
#> 2        2        1 male        4.61             4.76 assumed_exchangeable
#> 3        3        2 female      6.69             4.09 assumed_exchangeable
#> 4        4        2 male        5.98             6.20 assumed_exchangeable
#> # ℹ 716 more rows
#> # ℹ 5 more variables: .composition_role <fct>, .is_exchangeable <dbl>,
#> #   .member_contrast_arbitrary <dbl>, .provided_support_dyad_mean_gmc <dbl>,
#> #   .provided_support_within_dyad_dev <dbl>
```

For distinguishable dyads, we can request DSM columns. **DSM preparation
currently requires exactly one distinguishable composition**. To compute
these columns, an explicit role order is required. The role order
defines the direction of all DSM predictor differences and the DSM role
contrast (Iida et al. 2018).

``` r

cross_dsm_data <- dyadMLM::prepare_dyad_data(
  data = dyads_cross,
  dyad = coupleID,
  member = personID,
  role = gender,
  predictors = provided_support,
  model_types = "dsm",
  dsm_role_order = c("female", "male"),
  keep_compositions = "female-male"
)

print(cross_dsm_data, n = 4)
#> # dyadMLM data
#> # Rows: 240 | Dyads: 120 | Intensive longitudinal: no
#> # Structure: dyad = coupleID, member = personID, role = gender
#> # DSM direction: female - male
#> #
#> # Dyad compositions:
#> # female_x_male distinguishable 120 dyads
#> #
#> # Added columns:
#> #   .composition              inferred dyad composition
#> #   .composition_role         composition-specific member role
#> #   .is_{role}                composition-role indicator columns
#> #   .dsm_role_contrast        DSM role contrast: +0.5 for the first declared
#> #                             role and -0.5 for the second declared role
#> #   .{pred}_dyad_mean_gmc     dyad-mean predictor: dyad's average predictor
#> #                             level, grand-mean centered
#> #   .{pred}_within_dyad_diff  DSM signed predictor difference: first declared
#> #                             role minus second declared role
#> #
#> # A tibble: 240 × 12
#>   personID coupleID gender closeness provided_support .composition 
#>      <int>    <int> <fct>      <dbl>            <dbl> <fct>        
#> 1        1        1 female      4.71             4.49 female_x_male
#> 2        2        1 male        4.61             4.76 female_x_male
#> 3        3        2 female      6.69             4.09 female_x_male
#> 4        4        2 male        5.98             6.20 female_x_male
#> # ℹ 236 more rows
#> # ℹ 6 more variables: .composition_role <fct>, .is_female <dbl>,
#> #   .is_male <dbl>, .dsm_role_contrast <dbl>,
#> #   .provided_support_dyad_mean_gmc <dbl>,
#> #   .provided_support_within_dyad_diff <dbl>
```

APIM GMC uses all retained non-missing values. DIM and DSM center
complete-pair dyad means. The constants may differ with one-sided
missingness.

In DIM and DSM, mean predictors are grand-mean centered by convention;
thus, no additional argument is required to request them.

## Intensive longitudinal dyadic data

`dyads_ild` is a simulated intensive longitudinal dyadic dataset. Each
dyad has repeated observations over `diaryday`, with one row per
person-day.

    #> # A tibble: 6 × 6
    #>   personID coupleID diaryday gender closeness provided_support
    #>      <int>    <int>    <int> <fct>      <dbl>            <dbl>
    #> 1        1        1        0 female      3.74             4.93
    #> 2        2        1        0 male        5.91             5.59
    #> 3        1        1        1 female      3.72             4.89
    #> 4        2        1        1 male        6.32             5.18
    #> 5        1        1        2 female      2.45             4.38
    #> 6        2        1        2 male        3.44             4.99

To prepare intensive longitudinal data, pass the `time` variable to
[`dyadMLM::prepare_dyad_data()`](https://pascal-kueng.github.io/dyadMLM/reference/prepare_dyad_data.md).

``` r

ild_apim_data <- dyadMLM::prepare_dyad_data(
  dyads_ild,
  dyad = coupleID,
  member = personID,
  role = gender,
  time = diaryday,
  predictors = provided_support,
  model_types = "apim",
  keep_compositions = "female-male",
  seed = 123
)

print(ild_apim_data, n = 6)
#> # dyadMLM data
#> # Rows: 3360 | Dyads: 120 | Intensive longitudinal: yes
#> # Structure: dyad = coupleID, member = personID, role = gender, time = diaryday
#> #
#> # Dyad compositions:
#> # female_x_male distinguishable 120 dyads
#> #
#> # Added columns:
#> #   .composition         inferred dyad composition
#> #   .composition_role    composition-specific member role
#> #   .is_{role}           composition-role indicator columns
#> #   .{pred}_cwp          within-person predictor: momentary deviations from
#> #                        each person's usual level
#> #   .{pred}_cbp          between-person predictor: stable differences from the
#> #                        average person's usual level
#> #   .{pred}_actor        APIM actor predictor: actor's original predictor
#> #                        values
#> #   .{pred}_partner      APIM partner predictor: partner's original predictor
#> #                        values
#> #   .{pred}_cwp_actor    APIM within-person actor predictor: actor's momentary
#> #                        deviations from their usual level
#> #   .{pred}_cwp_partner  APIM within-person partner predictor: partner's
#> #                        momentary deviations from their usual level
#> #   .{pred}_cbp_actor    APIM between-person actor predictor: actor's stable
#> #                        difference from the average person's usual level
#> #   .{pred}_cbp_partner  APIM between-person partner predictor: partner's
#> #                        stable difference from the average person's usual
#> #                        level
#> #
#> # A tibble: 3,360 × 18
#>   personID coupleID diaryday gender closeness provided_support .composition 
#>      <int>    <int>    <int> <fct>      <dbl>            <dbl> <fct>        
#> 1        1        1        0 female      3.74             4.93 female_x_male
#> 2        2        1        0 male        5.91             5.59 female_x_male
#> 3        1        1        1 female      3.72             4.89 female_x_male
#> 4        2        1        1 male        6.32             5.18 female_x_male
#> 5        1        1        2 female      2.45             4.38 female_x_male
#> 6        2        1        2 male        3.44             4.99 female_x_male
#> # ℹ 3,354 more rows
#> # ℹ 11 more variables: .composition_role <fct>, .is_female <dbl>,
#> #   .is_male <dbl>, .provided_support_cwp <dbl>, .provided_support_cbp <dbl>,
#> #   .provided_support_actor <dbl>, .provided_support_partner <dbl>,
#> #   .provided_support_cwp_actor <dbl>, .provided_support_cwp_partner <dbl>,
#> #   .provided_support_cbp_actor <dbl>, .provided_support_cbp_partner <dbl>
```

By default, numeric predictors in longitudinal APIM preparation are
decomposed into within-person and between-person components (Bolger and
Laurenceau 2013). This temporal predictor decomposition is controlled by
`temporal_decomposition`. The default `"auto"` setting selects `"2l"`
(2-level temporal decomposition).

`add_apim_gmc_predictors = TRUE` requires resolved
`temporal_decomposition = "none"`, since the between-person component is
always already grand-mean centered by convention.

Note that observed person means used to construct the between-person
(`cbp`) predictors can be unreliable when each member contributes few
occasions, which can bias between-person estimates (Gottfredson 2019).

For fitted concurrent examples and AR(1) specifications for
distinguishable and exchangeable dyads, refer to the [intensive
longitudinal APIM
section](https://pascal-kueng.github.io/dyadMLM/articles/apim.html#intensive-longitudinal-apims).

### Preparing lagged predictors

Lagged versions of variables, including an outcome that is also passed
to `predictors` for dynamic models, can be obtained through the
`lag1_predictors` argument.

Lagging respects the dyad and member structure, matches observations at
exactly `time - 1`, and does not bridge missing occasions when rows are
missing in the dataset.

``` r

ild_apim_data_dynamic <- dyadMLM::prepare_dyad_data(
  dyads_ild,
  dyad = coupleID,
  member = personID,
  role = gender,
  time = diaryday,
  predictors = closeness,
  lag1_predictors = closeness,
  model_types = "apim",
  keep_compositions = "female-female",
  seed = 123
)

print(ild_apim_data_dynamic, n = 6)
#> # dyadMLM data
#> # Rows: 3360 | Dyads: 120 | Intensive longitudinal: yes
#> # Structure: dyad = coupleID, member = personID, role = gender, time = diaryday
#> #
#> # Dyad compositions:
#> # female_x_female exchangeable 120 dyads
#> #
#> # Added columns:
#> #   .composition                inferred dyad composition
#> #   .composition_role           composition-specific member role
#> #   .is_exchangeable            composition-role indicator columns
#> #   .member_contrast_arbitrary  composition-specific member contrasts coded
#> #                               -1/+1 in arbitrary direction for
#> #                               exchangeability-constrained random effects.
#> #                               Values are 0 for other compositions
#> #   .{pred}_lag1                lag-1 raw predictor values
#> #   .{pred}_cwp                 within-person predictor: momentary deviations
#> #                               from each person's usual level
#> #   .{pred}_cwp_lag1            lag-1 within-person predictor: momentary
#> #                               deviations from each person's usual level
#> #   .{pred}_cbp                 between-person predictor: stable differences
#> #                               from the average person's usual level
#> #   .{pred}_actor               APIM actor predictor: actor's original
#> #                               predictor values
#> #   .{pred}_actor_lag1          lag-1 APIM actor predictor: actor's original
#> #                               predictor values
#> #   .{pred}_partner             APIM partner predictor: partner's original
#> #                               predictor values
#> #   .{pred}_partner_lag1        lag-1 APIM partner predictor: partner's
#> #                               original predictor values
#> #   .{pred}_cwp_actor           APIM within-person actor predictor: actor's
#> #                               momentary deviations from their usual level
#> #   .{pred}_cwp_actor_lag1      lag-1 APIM within-person actor predictor:
#> #                               actor's momentary deviations from their usual
#> #                               level
#> #   .{pred}_cwp_partner         APIM within-person partner predictor: partner's
#> #                               momentary deviations from their usual level
#> #   .{pred}_cwp_partner_lag1    lag-1 APIM within-person partner predictor:
#> #                               partner's momentary deviations from their usual
#> #                               level
#> #   .{pred}_cbp_actor           APIM between-person actor predictor: actor's
#> #                               stable difference from the average person's
#> #                               usual level
#> #   .{pred}_cbp_partner         APIM between-person partner predictor:
#> #                               partner's stable difference from the average
#> #                               person's usual level
#> #
#> # A tibble: 3,360 × 24
#>   personID coupleID diaryday gender closeness provided_support .composition   
#>      <int>    <int>    <int> <fct>      <dbl>            <dbl> <fct>          
#> 1      241      121        0 female      6.60             6.18 female_x_female
#> 2      242      121        0 female      5.22             5.70 female_x_female
#> 3      241      121        1 female      8.33             4.57 female_x_female
#> 4      242      121        1 female      5.24             5.30 female_x_female
#> 5      241      121        2 female      6.55             5.19 female_x_female
#> 6      242      121        2 female      6.85             3.89 female_x_female
#> # ℹ 3,354 more rows
#> # ℹ 17 more variables: .composition_role <fct>, .is_exchangeable <dbl>,
#> #   .member_contrast_arbitrary <dbl>, .closeness_cwp <dbl>,
#> #   .closeness_cbp <dbl>, .closeness_lag1 <dbl>, .closeness_cwp_lag1 <dbl>,
#> #   .closeness_actor <dbl>, .closeness_partner <dbl>,
#> #   .closeness_cwp_actor <dbl>, .closeness_cwp_partner <dbl>,
#> #   .closeness_cbp_actor <dbl>, .closeness_cbp_partner <dbl>, …
```

**Note:** Whether to use the prepared raw or within-person-centered
lagged outcome depends on the research question and the data. See the
[dynamic ILD APIM
example](https://pascal-kueng.github.io/dyadMLM/articles/apim.html#dynamic-models)
for a more detailed discussion and guidance.

## Working with multiple dyad compositions

`dyads_cross` contains three dyad compositions: distinguishable
female-male dyads and exchangeable female-female and male-male dyads
(Bolger et al. 2025).

Let’s have `dyadMLM` infer the compositions automatically:

``` r

mixed_cross_data <- dyadMLM::prepare_dyad_data(
  dyads_cross,
  dyad = coupleID,
  member = personID,
  role = gender,
  seed = 123
)

print(mixed_cross_data, n = 4)
#> # dyadMLM data
#> # Rows: 720 | Dyads: 360 | Intensive longitudinal: no
#> # Structure: dyad = coupleID, member = personID, role = gender
#> #
#> # Dyad compositions:
#> # female_x_female exchangeable    120 dyads
#> # female_x_male   distinguishable 120 dyads
#> # male_x_male     exchangeable    120 dyads
#> #
#> # Added columns:
#> #   .composition                       inferred dyad composition
#> #   .composition_role                  composition-specific member role
#> #   .is_{comp-role}                    composition-role indicator columns
#> #   .member_contrast_{comp}_arbitrary  composition-specific member contrasts
#> #                                      coded -1/+1 in arbitrary direction for
#> #                                      exchangeability-constrained random
#> #                                      effects. Values are 0 for other
#> #                                      compositions
#> #
#> # A tibble: 720 × 13
#>   personID coupleID gender closeness provided_support .composition 
#>      <int>    <int> <fct>      <dbl>            <dbl> <fct>        
#> 1        1        1 female      4.71             4.49 female_x_male
#> 2        2        1 male        4.61             4.76 female_x_male
#> 3        3        2 female      6.69             4.09 female_x_male
#> 4        4        2 male        5.98             6.20 female_x_male
#> # ℹ 716 more rows
#> # ℹ 7 more variables: .composition_role <fct>, .is_female_x_female <dbl>,
#> #   .is_female_x_male_female <dbl>, .is_female_x_male_male <dbl>,
#> #   .is_male_x_male <dbl>, .member_contrast_female_x_female_arbitrary <dbl>,
#> #   .member_contrast_male_x_male_arbitrary <dbl>
```

Note that when role compositions are available, each *exchangeable*
composition receives its own difference contrast, such as
`.member_contrast_female_x_female_arbitrary`, which is `0` for all other
compositions.

We can use this data to model these dyad types as separate or in the
same model.

### Keeping only selected dyad compositions (filtering)

Sometimes a mixed dataset contains dyad compositions that should not be
part of a given analysis. Use `keep_compositions` to keep only dyads
whose *observed* composition matches the requested labels. The filtering
happens before exchangeability constraints and pooling, so
`set_exchangeable_compositions` and `pool_compositions` (described
later) can only refer to retained dyad compositions.

``` r

mixed_cross_data_included <- dyadMLM::prepare_dyad_data(
  dyads_cross,
  dyad = coupleID,
  member = personID,
  role = gender,
  keep_compositions = c("female-female", "male-male"),
  seed = 123
)

print(mixed_cross_data_included, n = 4)
#> # dyadMLM data
#> # Rows: 480 | Dyads: 240 | Intensive longitudinal: no
#> # Structure: dyad = coupleID, member = personID, role = gender
#> #
#> # Dyad compositions:
#> # female_x_female exchangeable 120 dyads
#> # male_x_male     exchangeable 120 dyads
#> #
#> # Added columns:
#> #   .composition                       inferred dyad composition
#> #   .composition_role                  composition-specific member role
#> #   .is_{comp-role}                    composition-role indicator columns
#> #   .member_contrast_{comp}_arbitrary  composition-specific member contrasts
#> #                                      coded -1/+1 in arbitrary direction for
#> #                                      exchangeability-constrained random
#> #                                      effects. Values are 0 for other
#> #                                      compositions
#> #
#> # A tibble: 480 × 11
#>   personID coupleID gender closeness provided_support .composition   
#>      <int>    <int> <fct>      <dbl>            <dbl> <fct>          
#> 1      241      121 female      7.34             5.41 female_x_female
#> 2      242      121 female      6.43             5.19 female_x_female
#> 3      243      122 female      8.18             5.89 female_x_female
#> 4      244      122 female      8.48             5.57 female_x_female
#> # ℹ 476 more rows
#> # ℹ 5 more variables: .composition_role <fct>, .is_female_x_female <dbl>,
#> #   .is_male_x_male <dbl>, .member_contrast_female_x_female_arbitrary <dbl>,
#> #   .member_contrast_male_x_male_arbitrary <dbl>
```

*Note* that whenever you need to refer to a dyad type, the order of
members does not matter (e.g., `male-female` and `female-male` will both
work), and you can use different separators like `male_female`,
`male_x_female`, or `male female`.

### Setting distinguishable dyads to be treated as exchangeable

`set_exchangeable_compositions` changes how selected role-defined
compositions are modeled while preserving their composition labels. By
contrast, omitting `role` indicates that no distinguishing variable is
available, so all dyads are treated as one exchangeable composition with
a single global arbitrary-member contrast.

``` r

mixed_cross_exchangeable_data <- dyadMLM::prepare_dyad_data(
  dyads_cross,
  dyad = coupleID,
  member = personID,
  role = gender,
  set_exchangeable_compositions = c("male-female"),
  seed = 123
)

print(mixed_cross_exchangeable_data, n = 4)
#> # dyadMLM data
#> # Rows: 720 | Dyads: 360 | Intensive longitudinal: no
#> # Structure: dyad = coupleID, member = personID, role = gender
#> #
#> # Dyad compositions:
#> # female_x_female exchangeable               120 dyads
#> # female_x_male   exchangeable (set by user) 120 dyads
#> # male_x_male     exchangeable               120 dyads
#> #
#> # Added columns:
#> #   .composition                       inferred dyad composition
#> #   .composition_role                  composition-specific member role
#> #   .is_{comp-role}                    composition-role indicator columns
#> #   .member_contrast_{comp}_arbitrary  composition-specific member contrasts
#> #                                      coded -1/+1 in arbitrary direction for
#> #                                      exchangeability-constrained random
#> #                                      effects. Values are 0 for other
#> #                                      compositions
#> #
#> # A tibble: 720 × 13
#>   personID coupleID gender closeness provided_support .composition 
#>      <int>    <int> <fct>      <dbl>            <dbl> <fct>        
#> 1        1        1 female      4.71             4.49 female_x_male
#> 2        2        1 male        4.61             4.76 female_x_male
#> 3        3        2 female      6.69             4.09 female_x_male
#> 4        4        2 male        5.98             6.20 female_x_male
#> # ℹ 716 more rows
#> # ℹ 7 more variables: .composition_role <fct>, .is_female_x_female <dbl>,
#> #   .is_female_x_male <dbl>, .is_male_x_male <dbl>,
#> #   .member_contrast_female_x_female_arbitrary <dbl>,
#> #   .member_contrast_female_x_male_arbitrary <dbl>,
#> #   .member_contrast_male_x_male_arbitrary <dbl>
```

### Pooling different dyad compositions

Sometimes, we may want to pool selected *exchangeable* dyad compositions
and analyze them as if they were one. Pooling can impose equality
constraints among compositions. After fitting nested pooled and unpooled
models to the same observations, these constraints can be tested with
[`dyadMLM::compare_nested_models()`](https://pascal-kueng.github.io/dyadMLM/reference/compare_nested_models.md);
see [testing distinguishability in the APIM
vignette](https://pascal-kueng.github.io/dyadMLM/articles/apim.html#testing-distinguishability)
for the model-comparison workflow.

For instance, let’s pool `male-male` and `female-female` dyads and name
them `same-sex` dyads:

``` r

mixed_cross_data_pooled <- dyadMLM::prepare_dyad_data(
  dyads_cross,
  dyad = coupleID,
  member = personID,
  role = gender,
  pool_compositions = list(
    "same-sex" = c("male-male", "female_female")
  ),
  seed = 123
)

print(mixed_cross_data_pooled)
#> # dyadMLM data
#> # Rows: 720 | Dyads: 360 | Intensive longitudinal: no
#> # Structure: dyad = coupleID, member = personID, role = gender
#> #
#> # Dyad compositions:
#> # female_x_male          distinguishable 120 dyads
#> # same-sex (pooled)      exchangeable    240 dyads
#> #   female_x_female
#> #   male_x_male
#> #
#> # Added columns:
#> #   .composition                       inferred dyad composition
#> #   .composition_role                  composition-specific member role
#> #   .is_{comp-role}                    composition-role indicator columns
#> #   .member_contrast_{comp}_arbitrary  composition-specific member contrasts
#> #                                      coded -1/+1 in arbitrary direction for
#> #                                      exchangeability-constrained random
#> #                                      effects. Values are 0 for other
#> #                                      compositions
#> #
#> # A tibble: 720 × 11
#>    personID coupleID gender closeness provided_support .composition 
#>       <int>    <int> <fct>      <dbl>            <dbl> <fct>        
#>  1        1        1 female      4.71             4.49 female_x_male
#>  2        2        1 male        4.61             4.76 female_x_male
#>  3        3        2 female      6.69             4.09 female_x_male
#>  4        4        2 male        5.98             6.20 female_x_male
#>  5        5        3 female      5.27             4.22 female_x_male
#>  6        6        3 male        4.37             5.03 female_x_male
#>  7        7        4 female      7.85             5.36 female_x_male
#>  8        8        4 male        5.42             5.25 female_x_male
#>  9        9        5 female      7.54             5.78 female_x_male
#> 10       10        5 male        5.19             4.98 female_x_male
#> # ℹ 710 more rows
#> # ℹ 5 more variables: .composition_role <fct>, .is_female_x_male_female <dbl>,
#> #   .is_female_x_male_male <dbl>, .is_same_sex <dbl>,
#> #   .member_contrast_same_sex_arbitrary <dbl>
```

Note that you cannot pool distinguishable dyads. If we wanted to pool
`female-male` with `male-male`, we would first have to treat
`female-male` as exchangeable:

``` r

mixed_cross_data_pooled_constrained <- dyadMLM::prepare_dyad_data(
  dyads_cross,
  dyad = coupleID,
  member = personID,
  role = gender,
  set_exchangeable_compositions = "male female",
  pool_compositions = list(
    "pooled_exchangeable" = c("male-male", "male_female")
  ),
  seed = 123
)

print(mixed_cross_data_pooled_constrained)
#> # dyadMLM data
#> # Rows: 720 | Dyads: 360 | Intensive longitudinal: no
#> # Structure: dyad = coupleID, member = personID, role = gender
#> #
#> # Dyad compositions:
#> # female_x_female              exchangeable 120 dyads
#> # pooled_exchangeable (pooled) exchangeable 240 dyads
#> #   female_x_male
#> #   male_x_male
#> #
#> # Added columns:
#> #   .composition                       inferred dyad composition
#> #   .composition_role                  composition-specific member role
#> #   .is_{comp-role}                    composition-role indicator columns
#> #   .member_contrast_{comp}_arbitrary  composition-specific member contrasts
#> #                                      coded -1/+1 in arbitrary direction for
#> #                                      exchangeability-constrained random
#> #                                      effects. Values are 0 for other
#> #                                      compositions
#> #
#> # A tibble: 720 × 11
#>    personID coupleID gender closeness provided_support .composition       
#>       <int>    <int> <fct>      <dbl>            <dbl> <fct>              
#>  1        1        1 female      4.71             4.49 pooled_exchangeable
#>  2        2        1 male        4.61             4.76 pooled_exchangeable
#>  3        3        2 female      6.69             4.09 pooled_exchangeable
#>  4        4        2 male        5.98             6.20 pooled_exchangeable
#>  5        5        3 female      5.27             4.22 pooled_exchangeable
#>  6        6        3 male        4.37             5.03 pooled_exchangeable
#>  7        7        4 female      7.85             5.36 pooled_exchangeable
#>  8        8        4 male        5.42             5.25 pooled_exchangeable
#>  9        9        5 female      7.54             5.78 pooled_exchangeable
#> 10       10        5 male        5.19             4.98 pooled_exchangeable
#> # ℹ 710 more rows
#> # ℹ 5 more variables: .composition_role <fct>, .is_female_x_female <dbl>,
#> #   .is_pooled_exchangeable <dbl>,
#> #   .member_contrast_female_x_female_arbitrary <dbl>,
#> #   .member_contrast_pooled_exchangeable_arbitrary <dbl>
```

## Citation

If you use `dyadMLM`, please cite the version of the package you use.
Obtain the citation via:

``` r

citation("dyadMLM")
#> To cite package 'dyadMLM' in publications use:
#> 
#>   Küng P (2026). _dyadMLM: Tools for Dyadic Multilevel Models_.
#>   doi:10.5281/zenodo.22047083
#>   <https://doi.org/10.5281/zenodo.22047083>. R package version
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
#>     doi = {10.5281/zenodo.22047083},
#>   }
```

------------------------------------------------------------------------

**Continue** with the [Actor-Partner Interdependence Model (APIM)
vignette](https://pascal-kueng.github.io/dyadMLM/articles/apim.md).

Related model-specific vignettes:

- [Dyad-Individual Model
  vignette](https://pascal-kueng.github.io/dyadMLM/articles/dim.md),
- [Dyadic Score Model
  vignette](https://pascal-kueng.github.io/dyadMLM/articles/dsm.md),

or return to [About this vignette](#about-this-vignette).

## References

Bolger, Niall, and Jean-Philippe Laurenceau. 2013. *Intensive
Longitudinal Methods: An Introduction to Diary and Experience Sampling
Research*. Guilford Press.
<https://www.guilford.com/books/Intensive-Longitudinal-Methods/Bolger-Laurenceau/9781462506781>.

Bolger, Niall, Jean-Philippe Laurenceau, and Ana DiGiovanni. 2025.
“Unified Analysis Model for Indistinguishable and Distinguishable
Dyads.” *Innovations in Interpersonal Relationships and Health Research:
Advancing the Integration of Interdisciplinary Approaches to Dyadic
Behavior Change*. <https://doi.org/10.17605/OSF.IO/WYDCJ>.

Gottfredson, Nisha C. 2019. “A Straightforward Approach for Coping with
Unreliability of Person Means When Parsing Within-Person and
Between-Person Effects in Longitudinal Studies.” *Addictive Behaviors*
94: 156–61. <https://doi.org/10.1016/j.addbeh.2018.09.031>.

Iida, Masumi, Gwendolyn Seidman, and Patrick E. Shrout. 2018. “Models of
Interdependent Individuals Versus Dyadic Processes in Relationship
Research.” *Journal of Social and Personal Relationships* 35 (1): 59–88.
<https://doi.org/10.1177/0265407517725407>.

Kenny, David A., and William Cook. 1999. “Partner Effects in
Relationship Research: Conceptual Issues, Analytic Difficulties, and
Illustrations.” *Personal Relationships* 6 (4): 433–48.
<https://doi.org/10.1111/j.1475-6811.1999.tb00202.x>.

Ledermann, Thomas, and David A. Kenny. 2017. “Analyzing Dyadic Data with
Multilevel Modeling Versus Structural Equation Modeling: A Tale of Two
Methods.” *Journal of Family Psychology* 31 (4): 442–52.
<https://doi.org/10.1037/fam0000290>.

Rosario, Kareena S. del, and Tessa V. West. 2025. “A Practical Guide to
Specifying Random Effects in Longitudinal Dyadic Multilevel Modeling.”
*Advances in Methods and Practices in Psychological Science* 8 (3):
25152459251351286. <https://doi.org/10.1177/25152459251351286>.
