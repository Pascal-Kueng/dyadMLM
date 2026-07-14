# Getting Started

``` r

library(interdep)
```

## Installation

You can install the development version of `interdep` from GitHub with:

``` r

# install.packages("pak")
pak::pak("Pascal-Kueng/interdep")
```

## About this Vignette

`interdep` helps researchers prepare cross-sectional and intensive
longitudinal dyadic data for (generalized) multilevel models. It
automatically creates model-ready columns for dyadic multilevel model
parameterizations such as Actor-Partner Interdependence Models (APIM),
Dyad-Individual Models (DIM), and Dyadic Score Models (DSM). DIM
currently supports one exchangeable dyad composition, whereas DSM
supports one distinguishable dyad composition.

**This vignette focuses on automatic data preparation for multilevel
models (MLMs).** For a comparison of MLM and structural equation
modeling (SEM) approaches to dyadic data, see Ledermann and Kenny
(2017).

For guidance and examples on how to use the prepared data to estimate
cross-sectional and intensive longitudinal APIMs, see the [Actor-Partner
Interdependence Model
vignette](https://pascal-kueng.github.io/interdep/articles/apim.md). For
models that combine distinguishable and exchangeable dyad compositions,
see the [Mixed-Composition APIM
vignette](https://pascal-kueng.github.io/interdep/articles/mixed-apim.md).

For guidance on how to use the Dyad-Individual Model (DIM)
parameterization, including dyad-mean and within-dyad-deviation
predictors and their equivalence to APIM effects (via an interactive
example) in exchangeable dyads, see the [Dyad-Individual Model
vignette](https://pascal-kueng.github.io/interdep/articles/dim.md).

For the dyadic score parameterization and its relationship to the APIM
for distinguishable dyads, see the [Dyadic Score Model
vignette](https://pascal-kueng.github.io/interdep/articles/dsm.md).

For an in-depth tutorial covering data preparation and model fitting,
but also additional steps like diagnostics and assumption checks, see
[Distinguishable and Exchangeable Dyads: Bayesian Multilevel
Modelling](https://pascal-kueng.github.io/05DyadicDataAnalysis/).

## Prerequisites

The basic data structure needed for `interdep` is a long data frame
where dyads are stacked on top of each other and both members of a dyad
appear as separate rows.

If your raw data are currently in wide format (for time or dyads or
both), reshape them to this long structure before using
[`prepare_interdep_data()`](https://pascal-kueng.github.io/interdep/reference/prepare_interdep_data.md).
See the [tidyr pivoting
vignette](https://tidyr.tidyverse.org/articles/pivot.html) or the
[`pivot_longer()`
reference](https://tidyr.tidyverse.org/reference/pivot_longer.html).

Roughly, the expected structure for `interdep` is:

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

Measured variables may contain missing values. The structural `group`,
`member`, and optional `time` variables must not contain missing values.

In intensive longitudinal data, missing measurement occasions can be
represented by absent rows, as long as the time variable preserves the
observed measurement occasions. For example:

| dyad | personID | time |   x |   y |
|-----:|---------:|-----:|----:|----:|
|    1 |        1 |    1 | 4.2 | 7.1 |
|    1 |        1 |    3 | 4.0 | 6.9 |
|    1 |        2 |    1 | 5.3 | 6.6 |
|    1 |        2 |    2 | 4.7 | 6.1 |
|    1 |        2 |    3 | 5.1 | 6.4 |

In this example, the row for person 1 at time 2 is absent. The time
variable preserves the observed measurement occasions and skips from
time 1 to time 3 for that person. `interdep` accepts this structure
without requiring a placeholder row for the missing occasion.

## Data preparation for distinguishable dyads

`example_dyadic_crosssectional` is a simulated cross-sectional dataset
for distinguishable dyads. Each dyad has two rows: one for each member.

``` r

print(head(example_dyadic_crosssectional))
#>   personID coupleID gender communication satisfaction
#> 1        1        1 female      4.789772     4.367824
#> 2        2        1   male      3.803445     2.342890
#> 3        3        2 female      2.914052     2.442250
#> 4        4        2   male      6.508207     6.080428
#> 5        5        3 female      5.696995     5.865494
#> 6        6        3   male      8.215332     9.661295
```

We validate and prepare the data with the function
[`prepare_interdep_data()`](https://pascal-kueng.github.io/interdep/reference/prepare_interdep_data.md)

``` r

cross_distinguishable_data <- prepare_interdep_data(
  data = example_dyadic_crosssectional,
  group = coupleID,
  member = personID,
  role = gender,

  # In this example, we optionally specify a predictor variable
  # and a model type to generate the columns needed for that model type.
  predictors = communication,
  model_type = "apim"
)

print(cross_distinguishable_data, n = 4)
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
#> #   .i_is_{comp-role}    composition-role indicator columns
#> #   .i_{pred}_actor      APIM actor predictor: actor's original predictor
#> #                        values
#> #   .i_{pred}_partner    APIM partner predictor: partner's original predictor
#> #                        values
#> #
#> # A tibble: 190 × 11
#>   personID coupleID gender communication satisfaction .i_composition
#>      <int>    <int> <fct>          <dbl>        <dbl> <fct>         
#> 1        1        1 female          4.79         4.37 female_x_male 
#> 2        2        1 male            3.80         2.34 female_x_male 
#> 3        3        2 female          2.91         2.44 female_x_male 
#> 4        4        2 male            6.51         6.08 female_x_male 
#> # ℹ 186 more rows
#> # ℹ 5 more variables: .i_composition_role <fct>,
#> #   .i_is_female_x_male_female <dbl>, .i_is_female_x_male_male <dbl>,
#> #   .i_communication_actor <dbl>, .i_communication_partner <dbl>
```

The function automatically recognized that in this dataset there are 95
female-male dyads and created APIM-relevant variables (Kenny and Cook
1999). These generated `.i_*` columns can be used directly in model
formulas.

Here is a simple example:

``` r

library(glmmTMB)

cross_distinguishable_model <- glmmTMB(
  satisfaction ~

    # Gender-specific intercepts
    0 +
    .i_is_female_x_male_female +
    .i_is_female_x_male_male +

    # Gender-specific actor effects
    .i_is_female_x_male_female:.i_communication_actor +
    .i_is_female_x_male_male:.i_communication_actor +

    # Gender-specific partner effects
    .i_is_female_x_male_female:.i_communication_partner +
    .i_is_female_x_male_male:.i_communication_partner +

    # Dyad-level unstructured random effects represent the two partner
    # residual variances and their covariance when dispformula = ~ 0.
    # This is glmmTMB-specific syntax! lme4 and brms use different syntax.
    us(0 +
         .i_is_female_x_male_female +
         .i_is_female_x_male_male
       | coupleID)

  , dispformula = ~ 0
  , family = gaussian()
  , data = cross_distinguishable_data
)
```

The model is fitted when `glmmTMB` is installed, but its output is
omitted here to keep the focus on data preparation. For fitted APIM
examples, see the [Actor-Partner Interdependence Model
vignette](https://pascal-kueng.github.io/interdep/articles/apim.md).

## Data preparation for exchangeable dyads

For a dataset with only one type of dyad that should be treated as
exchangeable, omit the `role` argument:

``` r

cross_exchangeable_data <- prepare_interdep_data(
  data = example_dyadic_crosssectional,
  group = coupleID,
  member = personID,
  seed = 123
)

print(cross_exchangeable_data, n = 4)
#> # interdep data
#> # Rows: 190 | Dyads: 95 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID
#> #
#> # Dyad compositions:
#> # assumed_exchangeable exchangeable 95 dyads
#> #
#> # Added columns:
#> #   .i_composition       inferred dyad composition
#> #   .i_composition_role  composition-specific member role
#> #   .i_is_{comp-role}    composition-role indicator columns
#> #   .i_diff_{comp}       composition-specific sum-diff contrasts with arbitrary
#> #                        direction; 0 for distinguishable dyads or other
#> #                        exchangeable compositions
#> #
#> # A tibble: 190 × 9
#>   personID coupleID gender communication satisfaction .i_composition      
#>      <int>    <int> <fct>          <dbl>        <dbl> <fct>               
#> 1        1        1 female          4.79         4.37 assumed_exchangeable
#> 2        2        1 male            3.80         2.34 assumed_exchangeable
#> 3        3        2 female          2.91         2.44 assumed_exchangeable
#> 4        4        2 male            6.51         6.08 assumed_exchangeable
#> # ℹ 186 more rows
#> # ℹ 3 more variables: .i_composition_role <fct>,
#> #   .i_is_assumed_exchangeable <dbl>,
#> #   .i_diff_assumed_exchangeable_arbitrary <dbl>
```

The generated `.i_diff_assumed_exchangeable_arbitrary` contrast assigns
`-1` and `1` to the two members of each exchangeable dyad. Its direction
is arbitrary, and `seed` makes the assignment reproducible. When role
compositions are available, each exchangeable composition receives its
own contrast, such as `.i_diff_female_x_female_arbitrary`, which is `0`
for all other compositions (del Rosario and West 2025). We use a fixed
seed in the examples below for consistent results.

Alternatively, for more control, we can explicitly set dyad types to
exchangeable:

``` r

cross_exchangeable_data <- prepare_interdep_data(
  data = example_dyadic_crosssectional,
  group = coupleID,
  member = personID,
  role = gender,
  set_exchangeable_compositions = "male-female",
  seed = 123
)

print(cross_exchangeable_data, n = 4)
#> # interdep data
#> # Rows: 190 | Dyads: 95 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID, role = gender
#> #
#> # Dyad compositions:
#> # female_x_male exchangeable (set by user) 95 dyads
#> #
#> # Added columns:
#> #   .i_composition       inferred dyad composition
#> #   .i_composition_role  composition-specific member role
#> #   .i_is_{comp-role}    composition-role indicator columns
#> #   .i_diff_{comp}       composition-specific sum-diff contrasts with arbitrary
#> #                        direction; 0 for distinguishable dyads or other
#> #                        exchangeable compositions
#> #
#> # A tibble: 190 × 9
#>   personID coupleID gender communication satisfaction .i_composition
#>      <int>    <int> <fct>          <dbl>        <dbl> <fct>         
#> 1        1        1 female          4.79         4.37 female_x_male 
#> 2        2        1 male            3.80         2.34 female_x_male 
#> 3        3        2 female          2.91         2.44 female_x_male 
#> 4        4        2 male            6.51         6.08 female_x_male 
#> # ℹ 186 more rows
#> # ℹ 3 more variables: .i_composition_role <fct>, .i_is_female_x_male <dbl>,
#> #   .i_diff_female_x_male_arbitrary <dbl>
```

*Note* that whenever you need to refer to a dyad type, the order of
members does not matter (e.g., `male-female` and `female-male` will both
work), and you can use different separators like `male_female`,
`male_x_female`, or `male female`.

For exchangeable dyads, we can request DIM predictor columns. This works
here because omitting `role` treats all dyads as a single exchangeable
composition.

``` r

cross_dim_data <- prepare_interdep_data(
  data = example_dyadic_crosssectional,
  group = coupleID,
  member = personID,
  predictors = communication,
  model_type = "dim",
  seed = 123
)

print(cross_dim_data, n = 4)
#> # interdep data
#> # Rows: 190 | Dyads: 95 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID
#> #
#> # Dyad compositions:
#> # assumed_exchangeable exchangeable 95 dyads
#> #
#> # Added columns:
#> #   .i_composition             inferred dyad composition
#> #   .i_composition_role        composition-specific member role
#> #   .i_is_{comp-role}          composition-role indicator columns
#> #   .i_diff_{comp}             composition-specific sum-diff contrasts with
#> #                              arbitrary direction; 0 for distinguishable dyads
#> #                              or other exchangeable compositions
#> #   .i_{pred}_dyad_mean_gmc    dyad-mean predictor: dyad's average predictor
#> #                              level, grand-mean centered
#> #   .i_{pred}_within_dyad_dev  DIM within-dyad predictor deviation: person's
#> #                              difference from the dyad average
#> #
#> # A tibble: 190 × 11
#>   personID coupleID gender communication satisfaction .i_composition      
#>      <int>    <int> <fct>          <dbl>        <dbl> <fct>               
#> 1        1        1 female          4.79         4.37 assumed_exchangeable
#> 2        2        1 male            3.80         2.34 assumed_exchangeable
#> 3        3        2 female          2.91         2.44 assumed_exchangeable
#> 4        4        2 male            6.51         6.08 assumed_exchangeable
#> # ℹ 186 more rows
#> # ℹ 5 more variables: .i_composition_role <fct>,
#> #   .i_is_assumed_exchangeable <dbl>,
#> #   .i_diff_assumed_exchangeable_arbitrary <dbl>,
#> #   .i_communication_dyad_mean_gmc <dbl>,
#> #   .i_communication_within_dyad_dev <dbl>
```

For distinguishable dyads, DSM preparation additionally requires a
stable role variable and an explicit role order. The role order defines
the direction of all DSM predictor differences and the DSM role contrast
(Iida et al. 2018). Outcomes remain unchanged and are selected later in
the fitted-model formula.

``` r

cross_dsm_data <- prepare_interdep_data(
  data = example_dyadic_crosssectional,
  group = coupleID,
  member = personID,
  role = gender,
  predictors = communication,
  model_type = "dsm",
  dsm_role_order = c("female", "male")
)

print(cross_dsm_data, n = 4)
#> # interdep data
#> # Rows: 190 | Dyads: 95 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID, role = gender
#> # DSM direction: female - male
#> #
#> # Dyad compositions:
#> # female_x_male distinguishable 95 dyads
#> #
#> # Added columns:
#> #   .i_composition              inferred dyad composition
#> #   .i_composition_role         composition-specific member role
#> #   .i_is_{comp-role}           composition-role indicator columns
#> #   .i_dsm_role_contrast        DSM role contrast: +0.5 for the first declared
#> #                               role and -0.5 for the second declared role
#> #   .i_{pred}_dyad_mean_gmc     dyad-mean predictor: dyad's average predictor
#> #                               level, grand-mean centered
#> #   .i_{pred}_within_dyad_diff  DSM signed predictor difference: first declared
#> #                               role minus second declared role
#> #
#> # A tibble: 190 × 12
#>   personID coupleID gender communication satisfaction .i_composition
#>      <int>    <int> <fct>          <dbl>        <dbl> <fct>         
#> 1        1        1 female          4.79         4.37 female_x_male 
#> 2        2        1 male            3.80         2.34 female_x_male 
#> 3        3        2 female          2.91         2.44 female_x_male 
#> 4        4        2 male            6.51         6.08 female_x_male 
#> # ℹ 186 more rows
#> # ℹ 6 more variables: .i_composition_role <fct>,
#> #   .i_is_female_x_male_female <dbl>, .i_is_female_x_male_male <dbl>,
#> #   .i_dsm_role_contrast <dbl>, .i_communication_dyad_mean_gmc <dbl>,
#> #   .i_communication_within_dyad_diff <dbl>
```

## Incomplete dyads and missing roles

By default,
[`prepare_interdep_data()`](https://pascal-kueng.github.io/interdep/reference/prepare_interdep_data.md)
stops when a dyad has only one observed member or when a member’s role
cannot be resolved from the observed rows. These cases can also be
dropped before validation continues.

``` r

incomplete_data <- data.frame(
  coupleID = c(1, 2, 2, 3, 3, 4, 4, 5),
  personID = c(1, 3, 4, 5, 6, 7, 8, 10),
  gender = c("female", "female", NA, "female", "female", "female", "male", NA),
  satisfaction = c(5.2, 4.8, 4.9, 5.1, 5.0, 4.7, 4.6, 3.0)
)

incomplete_dropped_data <- prepare_interdep_data(
  incomplete_data,
  group = coupleID,
  member = personID,
  role = gender,
  incomplete_dyads = "drop",
  missing_role = "drop",
  seed = 123
)
#> Dropped 2 incomplete dyads, with IDs: 1, 5.
#> Dropped 1 dyad with incomplete role information, with ID: 2.

print(incomplete_dropped_data)
#> # interdep data
#> # Rows: 4 | Dyads: 2 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID, role = gender
#> #
#> # Dropped incomplete dyads: 2 dyads, with IDs: 1, 5
#> #
#> # Dropped dyads with incomplete role information: 1 dyad, with ID: 2
#> #
#> # Dyad compositions:
#> # female_x_female exchangeable    1 dyad
#> # female_x_male   distinguishable 1 dyad
#> #
#> # Added columns:
#> #   .i_composition       inferred dyad composition
#> #   .i_composition_role  composition-specific member role
#> #   .i_is_{comp-role}    composition-role indicator columns
#> #   .i_diff_{comp}       composition-specific sum-diff contrasts with arbitrary
#> #                        direction; 0 for distinguishable dyads or other
#> #                        exchangeable compositions
#> #
#> # A tibble: 4 × 10
#>   coupleID personID gender satisfaction .i_composition  .i_composition_role 
#>      <dbl>    <dbl> <chr>         <dbl> <fct>           <fct>               
#> 1        3        5 female          5.1 female_x_female female_x_female     
#> 2        3        6 female          5   female_x_female female_x_female     
#> 3        4        7 female          4.7 female_x_male   female_x_male_female
#> 4        4        8 male            4.6 female_x_male   female_x_male_male  
#> # ℹ 4 more variables: .i_is_female_x_female <dbl>,
#> #   .i_is_female_x_male_female <dbl>, .i_is_female_x_male_male <dbl>,
#> #   .i_diff_female_x_female_arbitrary <dbl>
```

## Intensive longitudinal dyadic data

`example_dyadic_ILD` is a simulated intensive longitudinal dyadic
dataset. Each dyad has repeated observations over `diaryday`, with one
row per person-day.

The first rows look like this:

``` r

print(example_dyadic_ILD, n = 26)
#> # A tibble: 1,120 × 6
#>    personID coupleID diaryday gender closeness provided_support
#>       <int>    <int>    <int> <fct>      <dbl>            <dbl>
#>  1        1        1        0 female      5.03             4.30
#>  2        1        1        1 female      5.64             4.24
#>  3        1        1        2 female      5.49             3.54
#>  4        1        1        3 female      6.71             5.04
#>  5        1        1        4 female      5.61             4.74
#>  6        1        1        5 female      6.11             4.72
#>  7        1        1        6 female      6.96             5.12
#>  8        1        1        7 female      7.03             5.21
#>  9        1        1        8 female      8.07             5.20
#> 10        1        1        9 female      4.87             4.69
#> 11        1        1       10 female      5.53             5.67
#> 12        1        1       11 female      6.54             4.28
#> 13        1        1       12 female      5.31             3.86
#> 14        1        1       13 female      5.16             4.85
#> 15        2        1        0 male        4.68             4.45
#> 16        2        1        1 male        4.52             5.84
#> 17        2        1        2 male       NA               NA   
#> 18        2        1        3 male        4.42             6.07
#> 19        2        1        4 male        5.07             4.19
#> 20        2        1        5 male        3.84             4.87
#> 21        2        1        6 male        2.22             5.25
#> 22        2        1        7 male        3.52             5.52
#> 23        2        1        8 male        5.26             4.64
#> 24        2        1        9 male        5.57             5.24
#> 25        2        1       10 male        2.92             5.33
#> 26        2        1       11 male        3.18             4.30
#> # ℹ 1,094 more rows
```

To prepare intensive longitudinal data, pass the `time` variable to
[`prepare_interdep_data()`](https://pascal-kueng.github.io/interdep/reference/prepare_interdep_data.md).

### ILD APIM preparation

``` r

ild_apim_data <- prepare_interdep_data(
  example_dyadic_ILD,
  group = coupleID,
  member = personID,
  role = gender,
  time = diaryday,
  predictors = provided_support,
  model_type = "apim",
  seed = 123
)

print(ild_apim_data)
#> # interdep data
#> # Rows: 1120 | Dyads: 40 | Intensive longitudinal: yes
#> # Structure: group = coupleID, member = personID, role = gender, time =
#> # diaryday
#> #
#> # Dyad compositions:
#> # female_x_male distinguishable 40 dyads
#> #
#> # Added columns:
#> #   .i_composition         inferred dyad composition
#> #   .i_composition_role    composition-specific member role
#> #   .i_is_{comp-role}      composition-role indicator columns
#> #   .i_{pred}_cwp          within-person predictor: momentary deviations from
#> #                          each person's usual level
#> #   .i_{pred}_cbp          between-person predictor: stable differences from
#> #                          the average person's usual level
#> #   .i_{pred}_actor        APIM actor predictor: actor's original predictor
#> #                          values
#> #   .i_{pred}_partner      APIM partner predictor: partner's original predictor
#> #                          values
#> #   .i_{pred}_cwp_actor    APIM within-person actor predictor: actor's
#> #                          momentary deviations from their usual level
#> #   .i_{pred}_cwp_partner  APIM within-person partner predictor: partner's
#> #                          momentary deviations from their usual level
#> #   .i_{pred}_cbp_actor    APIM between-person actor predictor: actor's stable
#> #                          difference from the average person's usual level
#> #   .i_{pred}_cbp_partner  APIM between-person partner predictor: partner's
#> #                          stable difference from the average person's usual
#> #                          level
#> #
#> # A tibble: 1,120 × 18
#>    personID coupleID diaryday gender closeness provided_support .i_composition
#>       <int>    <int>    <int> <fct>      <dbl>            <dbl> <fct>         
#>  1        1        1        0 female      5.03             4.30 female_x_male 
#>  2        1        1        1 female      5.64             4.24 female_x_male 
#>  3        1        1        2 female      5.49             3.54 female_x_male 
#>  4        1        1        3 female      6.71             5.04 female_x_male 
#>  5        1        1        4 female      5.61             4.74 female_x_male 
#>  6        1        1        5 female      6.11             4.72 female_x_male 
#>  7        1        1        6 female      6.96             5.12 female_x_male 
#>  8        1        1        7 female      7.03             5.21 female_x_male 
#>  9        1        1        8 female      8.07             5.20 female_x_male 
#> 10        1        1        9 female      4.87             4.69 female_x_male 
#> # ℹ 1,110 more rows
#> # ℹ 11 more variables: .i_composition_role <fct>,
#> #   .i_is_female_x_male_female <dbl>, .i_is_female_x_male_male <dbl>,
#> #   .i_provided_support_cwp <dbl>, .i_provided_support_cbp <dbl>,
#> #   .i_provided_support_actor <dbl>, .i_provided_support_partner <dbl>,
#> #   .i_provided_support_cwp_actor <dbl>, .i_provided_support_cwp_partner <dbl>,
#> #   .i_provided_support_cbp_actor <dbl>, …
```

By default, numeric predictors in longitudinal APIM preparation are
decomposed into within-person and between-person components (Bolger and
Laurenceau 2013). This temporal predictor decomposition is controlled by
`temporal_predictor_decomposition`. The default `"auto"` setting selects
`"time_2l"` for this longitudinal setup and retains raw actor and
partner columns alongside both components.

Note that observed person means used to construct the between-person
(`cbp`) predictors can be unreliable when each member contributes few
occasions, which can bias between-person estimates (Gottfredson 2019).

### Dynamic Models

The preparation above supports contemporaneous models, but observations
can also remain dependent over time. Currently, commonly used
open-source MLM interfaces in R do not provide the full dyadic residual
VAR structure needed to model serial dependence across both partners.
Within open-source R, such a model generally requires custom TMB or Stan
code.

One practical alternative, especially when carryover and temporal
dynamics are part of the research question, is to create a dynamic model
by including lagged versions of the outcome as predictors.

Lagged versions of variables, including an outcome that is also passed
to `predictors`, can be obtained through the `lag_predictors` argument.
[`prepare_interdep_data()`](https://pascal-kueng.github.io/interdep/reference/prepare_interdep_data.md)
then returns lag-1 raw and within-person-centered actor and partner
columns alongside their contemporaneous versions. Lagging respects the
dyad and member structure, matches observations at exactly `time - 1`,
and does not bridge missing occasions.

Whether raw or within-person-centered lagged outcomes should be used
depends on the research question and the data. For guidance on this
choice, refer to Hamaker and Grasman (2015) and Gistelinck et al.
(2021).

Brief exchangeable example:

``` r

ild_apim_data_dynamic <- prepare_interdep_data(
  example_dyadic_ILD,
  group = coupleID,
  member = personID,
  time = diaryday,
  predictors = closeness,
  lag_predictors = closeness,
  model_type = "apim",
  seed = 123
)

print(ild_apim_data_dynamic)
#> # interdep data
#> # Rows: 1120 | Dyads: 40 | Intensive longitudinal: yes
#> # Structure: group = coupleID, member = personID, time = diaryday
#> #
#> # Dyad compositions:
#> # assumed_exchangeable exchangeable 40 dyads
#> #
#> # Added columns:
#> #   .i_composition              inferred dyad composition
#> #   .i_composition_role         composition-specific member role
#> #   .i_is_{comp-role}           composition-role indicator columns
#> #   .i_diff_{comp}              composition-specific sum-diff contrasts with
#> #                               arbitrary direction; 0 for distinguishable
#> #                               dyads or other exchangeable compositions
#> #   .i_{pred}_lag1              lag-1 raw predictor values
#> #   .i_{pred}_cwp               within-person predictor: momentary deviations
#> #                               from each person's usual level
#> #   .i_{pred}_cwp_lag1          lag-1 within-person predictor: momentary
#> #                               deviations from each person's usual level
#> #   .i_{pred}_cbp               between-person predictor: stable differences
#> #                               from the average person's usual level
#> #   .i_{pred}_actor             APIM actor predictor: actor's original
#> #                               predictor values
#> #   .i_{pred}_actor_lag1        lag-1 APIM actor predictor: actor's original
#> #                               predictor values
#> #   .i_{pred}_partner           APIM partner predictor: partner's original
#> #                               predictor values
#> #   .i_{pred}_partner_lag1      lag-1 APIM partner predictor: partner's
#> #                               original predictor values
#> #   .i_{pred}_cwp_actor         APIM within-person actor predictor: actor's
#> #                               momentary deviations from their usual level
#> #   .i_{pred}_cwp_actor_lag1    lag-1 APIM within-person actor predictor:
#> #                               actor's momentary deviations from their usual
#> #                               level
#> #   .i_{pred}_cwp_partner       APIM within-person partner predictor: partner's
#> #                               momentary deviations from their usual level
#> #   .i_{pred}_cwp_partner_lag1  lag-1 APIM within-person partner predictor:
#> #                               partner's momentary deviations from their usual
#> #                               level
#> #   .i_{pred}_cbp_actor         APIM between-person actor predictor: actor's
#> #                               stable difference from the average person's
#> #                               usual level
#> #   .i_{pred}_cbp_partner       APIM between-person partner predictor:
#> #                               partner's stable difference from the average
#> #                               person's usual level
#> #
#> # A tibble: 1,120 × 24
#>    personID coupleID diaryday gender closeness provided_support .i_composition  
#>       <int>    <int>    <int> <fct>      <dbl>            <dbl> <fct>           
#>  1        1        1        0 female      5.03             4.30 assumed_exchang…
#>  2        1        1        1 female      5.64             4.24 assumed_exchang…
#>  3        1        1        2 female      5.49             3.54 assumed_exchang…
#>  4        1        1        3 female      6.71             5.04 assumed_exchang…
#>  5        1        1        4 female      5.61             4.74 assumed_exchang…
#>  6        1        1        5 female      6.11             4.72 assumed_exchang…
#>  7        1        1        6 female      6.96             5.12 assumed_exchang…
#>  8        1        1        7 female      7.03             5.21 assumed_exchang…
#>  9        1        1        8 female      8.07             5.20 assumed_exchang…
#> 10        1        1        9 female      4.87             4.69 assumed_exchang…
#> # ℹ 1,110 more rows
#> # ℹ 17 more variables: .i_composition_role <fct>,
#> #   .i_is_assumed_exchangeable <dbl>,
#> #   .i_diff_assumed_exchangeable_arbitrary <dbl>, .i_closeness_cwp <dbl>,
#> #   .i_closeness_cbp <dbl>, .i_closeness_lag1 <dbl>,
#> #   .i_closeness_cwp_lag1 <dbl>, .i_closeness_actor <dbl>,
#> #   .i_closeness_partner <dbl>, .i_closeness_cwp_actor <dbl>, …
```

A simple fixed-slope dyadic stability and influence model (del Rosario
and West 2025):

``` r


stability_influence <- glmmTMB::glmmTMB(
  closeness ~ 1 +

    # Stability (actor effect across time)
    .i_closeness_actor_lag1 +

    # Influence (partner effect across time)
    .i_closeness_partner_lag1 +

    # Linear time trend
    diaryday +

    # Stable exchangeable dyad-level covariance
    (1 | coupleID) +
    (0 + .i_diff_assumed_exchangeable_arbitrary | coupleID) +

    # Same-day exchangeable dyad-level covariance
    (1 | coupleID:diaryday) +
    (0 + .i_diff_assumed_exchangeable_arbitrary | coupleID:diaryday)

  , dispformula = ~ 0
  , family = gaussian()
  , data = ild_apim_data_dynamic
)

summary(stability_influence)
#>  Family: gaussian  ( identity )
#> Formula:          
#> closeness ~ 1 + .i_closeness_actor_lag1 + .i_closeness_partner_lag1 +  
#>     diaryday + (1 | coupleID) + (0 + .i_diff_assumed_exchangeable_arbitrary |  
#>     coupleID) + (1 | coupleID:diaryday) + (0 + .i_diff_assumed_exchangeable_arbitrary |  
#>     coupleID:diaryday)
#> Dispersion:                 ~0
#> Data: ild_apim_data_dynamic
#> 
#>       AIC       BIC    logLik -2*log(L)  df.resid 
#>    2929.0    2968.0   -1456.5    2913.0       967 
#> 
#> Random effects:
#> 
#> Conditional model:
#>  Groups              Name                                   Variance Std.Dev.
#>  coupleID            (Intercept)                            0.9161   0.9571  
#>  coupleID.1          .i_diff_assumed_exchangeable_arbitrary 0.5742   0.7578  
#>  coupleID.diaryday   (Intercept)                            0.3925   0.6265  
#>  coupleID.diaryday.1 .i_diff_assumed_exchangeable_arbitrary 0.5234   0.7235  
#> Number of obs: 975, groups:  coupleID, 40; coupleID:diaryday, 497
#> 
#> Conditional model:
#>                            Estimate Std. Error z value Pr(>|z|)    
#> (Intercept)                4.213120   0.300184  14.035  < 2e-16 ***
#> .i_closeness_actor_lag1    0.143973   0.035326   4.076 4.59e-05 ***
#> .i_closeness_partner_lag1  0.028758   0.035386   0.813    0.416    
#> diaryday                  -0.005281   0.007643  -0.691    0.490    
#> ---
#> Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
```

This model can be extended with contemporaneous actor and partner
predictor associations and other lagged predictors. Time-varying
predictors should usually be separated into within-person and
between-person components. Their contemporaneous coefficients are then
conditional on both partners’ prior outcomes.

**Note:** Person-mean centering a lagged outcome can introduce Nickell
bias, especially in shorter time series (Hamaker and Grasman 2015;
Nickell 1981; Gistelinck et al. 2021). Refer to the [DIM
vignette](https://pascal-kueng.github.io/interdep/articles/dim.md) and
[APIM
vignette](https://pascal-kueng.github.io/interdep/articles/apim.md) for
fuller discussions and fitted dynamic examples.

## Data with multiple and mixed-composition dyads

`example_dyadic_crosssectional_mixed` contains three dyad compositions
in the same data object: distinguishable female-male dyads and
exchangeable female-female and male-male dyads (Bolger et al. 2025).

Let’s have `interdep` infer the compositions automatically:

``` r

mixed_cross_data <- prepare_interdep_data(
  example_dyadic_crosssectional_mixed,
  group = coupleID,
  member = personID,
  role = gender,
  seed = 123
)

print(mixed_cross_data, n = 4)
#> # interdep data
#> # Rows: 640 | Dyads: 320 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID, role = gender
#> #
#> # Dyad compositions:
#> # female_x_female exchangeable    100 dyads
#> # female_x_male   distinguishable 120 dyads
#> # male_x_male     exchangeable    100 dyads
#> #
#> # Added columns:
#> #   .i_composition       inferred dyad composition
#> #   .i_composition_role  composition-specific member role
#> #   .i_is_{comp-role}    composition-role indicator columns
#> #   .i_diff_{comp}       composition-specific sum-diff contrasts with arbitrary
#> #                        direction; 0 for distinguishable dyads or other
#> #                        exchangeable compositions
#> #
#> # A tibble: 640 × 12
#>   personID coupleID gender satisfaction .i_composition .i_composition_role 
#>      <int>    <int> <fct>         <dbl> <fct>          <fct>               
#> 1        1        1 female         4.95 female_x_male  female_x_male_female
#> 2        2        1 male           5.26 female_x_male  female_x_male_male  
#> 3        3        2 female         5.14 female_x_male  female_x_male_female
#> 4        4        2 male           3.11 female_x_male  female_x_male_male  
#> # ℹ 636 more rows
#> # ℹ 6 more variables: .i_is_female_x_female <dbl>,
#> #   .i_is_female_x_male_female <dbl>, .i_is_female_x_male_male <dbl>,
#> #   .i_is_male_x_male <dbl>, .i_diff_female_x_female_arbitrary <dbl>,
#> #   .i_diff_male_x_male_arbitrary <dbl>
```

We can use this data to model these dyad types as separate or in the
same model. The [APIMs with Mixed Dyad Compositions
vignette](https://pascal-kueng.github.io/interdep/articles/mixed-apim.md)
shows both mixed-composition formulas and practical convergence notes.

### Keeping only selected dyad compositions (filtering)

Sometimes a mixed dataset contains dyad compositions that should not be
part of a given analysis. Use `include_compositions` to keep only dyads
whose *observed* composition matches the requested labels. The filtering
happens before exchangeability constraints and pooling, so
`set_exchangeable_compositions` and `pool_compositions` arguments can
only refer to retained types of dyads.

``` r

mixed_cross_data_included <- prepare_interdep_data(
  example_dyadic_crosssectional_mixed,
  group = coupleID,
  member = personID,
  role = gender,
  include_compositions = c("female-female", "male-male"),
  seed = 123
)

print(mixed_cross_data_included, n = 4)
#> # interdep data
#> # Rows: 400 | Dyads: 200 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID, role = gender
#> #
#> # Dyad compositions:
#> # female_x_female exchangeable 100 dyads
#> # male_x_male     exchangeable 100 dyads
#> #
#> # Added columns:
#> #   .i_composition       inferred dyad composition
#> #   .i_composition_role  composition-specific member role
#> #   .i_is_{comp-role}    composition-role indicator columns
#> #   .i_diff_{comp}       composition-specific sum-diff contrasts with arbitrary
#> #                        direction; 0 for distinguishable dyads or other
#> #                        exchangeable compositions
#> #
#> # A tibble: 400 × 10
#>   personID coupleID gender satisfaction .i_composition  .i_composition_role
#>      <int>    <int> <fct>         <dbl> <fct>           <fct>              
#> 1      241      121 female         5.32 female_x_female female_x_female    
#> 2      242      121 female         5.37 female_x_female female_x_female    
#> 3      243      122 female         5.99 female_x_female female_x_female    
#> 4      244      122 female         6.93 female_x_female female_x_female    
#> # ℹ 396 more rows
#> # ℹ 4 more variables: .i_is_female_x_female <dbl>, .i_is_male_x_male <dbl>,
#> #   .i_diff_female_x_female_arbitrary <dbl>,
#> #   .i_diff_male_x_male_arbitrary <dbl>
```

### Setting distinguishable dyads to be treated as exchangeable

As mentioned earlier, omitting the `role` argument treated all dyads as
one exchangeable composition, effectively pooling them.

For more control, a distinguishable dyad composition in a mixed dataset
can be treated as exchangeable. This specification keeps the
differentiation between the kinds of dyads (e.g., `male-male`,
`female-female`, and `male-female`).

``` r

mixed_cross_exchangeable_data <- prepare_interdep_data(
  example_dyadic_crosssectional_mixed,
  group = coupleID,
  member = personID,
  role = gender,
  set_exchangeable_compositions = c("male-female"),
  seed = 123
)

print(mixed_cross_exchangeable_data, n = 4)
#> # interdep data
#> # Rows: 640 | Dyads: 320 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID, role = gender
#> #
#> # Dyad compositions:
#> # female_x_female exchangeable               100 dyads
#> # female_x_male   exchangeable (set by user) 120 dyads
#> # male_x_male     exchangeable               100 dyads
#> #
#> # Added columns:
#> #   .i_composition       inferred dyad composition
#> #   .i_composition_role  composition-specific member role
#> #   .i_is_{comp-role}    composition-role indicator columns
#> #   .i_diff_{comp}       composition-specific sum-diff contrasts with arbitrary
#> #                        direction; 0 for distinguishable dyads or other
#> #                        exchangeable compositions
#> #
#> # A tibble: 640 × 12
#>   personID coupleID gender satisfaction .i_composition .i_composition_role
#>      <int>    <int> <fct>         <dbl> <fct>          <fct>              
#> 1        1        1 female         4.95 female_x_male  female_x_male      
#> 2        2        1 male           5.26 female_x_male  female_x_male      
#> 3        3        2 female         5.14 female_x_male  female_x_male      
#> 4        4        2 male           3.11 female_x_male  female_x_male      
#> # ℹ 636 more rows
#> # ℹ 6 more variables: .i_is_female_x_female <dbl>, .i_is_female_x_male <dbl>,
#> #   .i_is_male_x_male <dbl>, .i_diff_female_x_female_arbitrary <dbl>,
#> #   .i_diff_female_x_male_arbitrary <dbl>, .i_diff_male_x_male_arbitrary <dbl>
```

### Pooling different dyad compositions

Sometimes for theoretical or practical reasons, we may want to pool
different exchangeable dyad compositions and analyze them as if they
were one. This also allows testing various constraints via model
comparisons.

For instance, let’s pool `male-male` and `female-female` dyads and name
them `same-sex` dyads:

``` r

mixed_cross_data_pooled <- prepare_interdep_data(
  example_dyadic_crosssectional_mixed,
  group = coupleID,
  member = personID,
  role = gender,
  pool_compositions = list(
    "same-sex" = c("male-male", "female_female")
  ),
  seed = 123
)

print(mixed_cross_data_pooled)
#> # interdep data
#> # Rows: 640 | Dyads: 320 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID, role = gender
#> #
#> # Dyad compositions:
#> # female_x_male          distinguishable 120 dyads
#> # same-sex (pooled)      exchangeable    200 dyads
#> #   female_x_female
#> #   male_x_male
#> #
#> # Added columns:
#> #   .i_composition       inferred dyad composition
#> #   .i_composition_role  composition-specific member role
#> #   .i_is_{comp-role}    composition-role indicator columns
#> #   .i_diff_{comp}       composition-specific sum-diff contrasts with arbitrary
#> #                        direction; 0 for distinguishable dyads or other
#> #                        exchangeable compositions
#> #
#> # A tibble: 640 × 10
#>    personID coupleID gender satisfaction .i_composition .i_composition_role 
#>       <int>    <int> <fct>         <dbl> <fct>          <fct>               
#>  1        1        1 female         4.95 female_x_male  female_x_male_female
#>  2        2        1 male           5.26 female_x_male  female_x_male_male  
#>  3        3        2 female         5.14 female_x_male  female_x_male_female
#>  4        4        2 male           3.11 female_x_male  female_x_male_male  
#>  5        5        3 female         6.40 female_x_male  female_x_male_female
#>  6        6        3 male           3.45 female_x_male  female_x_male_male  
#>  7        7        4 female         4.16 female_x_male  female_x_male_female
#>  8        8        4 male           6.47 female_x_male  female_x_male_male  
#>  9        9        5 female         5.97 female_x_male  female_x_male_female
#> 10       10        5 male           5.44 female_x_male  female_x_male_male  
#> # ℹ 630 more rows
#> # ℹ 4 more variables: .i_is_female_x_male_female <dbl>,
#> #   .i_is_female_x_male_male <dbl>, .i_is_same_sex <dbl>,
#> #   .i_diff_same_sex_arbitrary <dbl>
```

Note that you cannot pool distinguishable dyads. To pool `female-male`
with `male-male`, we first have to treat `female-male` as exchangeable:

``` r

mixed_cross_data_pooled_constrained <- prepare_interdep_data(
  example_dyadic_crosssectional_mixed,
  group = coupleID,
  member = personID,
  role = gender,
  set_exchangeable_compositions = "male female",
  pool_compositions = list(
    "pooled_exchangeable" = c("male-male", "male_female")
  ),
  seed = 123
)

print(mixed_cross_data_pooled_constrained)
#> # interdep data
#> # Rows: 640 | Dyads: 320 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID, role = gender
#> #
#> # Dyad compositions:
#> # female_x_female              exchangeable 100 dyads
#> # pooled_exchangeable (pooled) exchangeable 220 dyads
#> #   female_x_male
#> #   male_x_male
#> #
#> # Added columns:
#> #   .i_composition       inferred dyad composition
#> #   .i_composition_role  composition-specific member role
#> #   .i_is_{comp-role}    composition-role indicator columns
#> #   .i_diff_{comp}       composition-specific sum-diff contrasts with arbitrary
#> #                        direction; 0 for distinguishable dyads or other
#> #                        exchangeable compositions
#> #
#> # A tibble: 640 × 10
#>    personID coupleID gender satisfaction .i_composition      .i_composition_role
#>       <int>    <int> <fct>         <dbl> <fct>               <fct>              
#>  1        1        1 female         4.95 pooled_exchangeable pooled_exchangeable
#>  2        2        1 male           5.26 pooled_exchangeable pooled_exchangeable
#>  3        3        2 female         5.14 pooled_exchangeable pooled_exchangeable
#>  4        4        2 male           3.11 pooled_exchangeable pooled_exchangeable
#>  5        5        3 female         6.40 pooled_exchangeable pooled_exchangeable
#>  6        6        3 male           3.45 pooled_exchangeable pooled_exchangeable
#>  7        7        4 female         4.16 pooled_exchangeable pooled_exchangeable
#>  8        8        4 male           6.47 pooled_exchangeable pooled_exchangeable
#>  9        9        5 female         5.97 pooled_exchangeable pooled_exchangeable
#> 10       10        5 male           5.44 pooled_exchangeable pooled_exchangeable
#> # ℹ 630 more rows
#> # ℹ 4 more variables: .i_is_female_x_female <dbl>,
#> #   .i_is_pooled_exchangeable <dbl>, .i_diff_female_x_female_arbitrary <dbl>,
#> #   .i_diff_pooled_exchangeable_arbitrary <dbl>
```

------------------------------------------------------------------------

**Continue** with the [Actor-Partner Interdependence Model (APIM)
vignette](https://pascal-kueng.github.io/interdep/articles/apim.md).

Related model-specific vignettes:

- [Mixed-Composition APIM
  vignette](https://pascal-kueng.github.io/interdep/articles/mixed-apim.md),
- [Dyad-Individual Model
  vignette](https://pascal-kueng.github.io/interdep/articles/dim.md),
- [Dyadic Score Model
  vignette](https://pascal-kueng.github.io/interdep/articles/dsm.md),

or return to the
[Overview](https://pascal-kueng.github.io/interdep/articles/index.md).

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

Gistelinck, Fien, Tom Loeys, and Nele Flamant. 2021. “Multilevel
Autoregressive Models When the Number of Time Points Is Small.”
*Structural Equation Modeling: A Multidisciplinary Journal* 28 (1):
15–27. <https://doi.org/10.1080/10705511.2020.1753517>.

Gottfredson, Nisha C. 2019. “A Straightforward Approach for Coping with
Unreliability of Person Means When Parsing Within-Person and
Between-Person Effects in Longitudinal Studies.” *Addictive Behaviors*
94: 156–61. <https://doi.org/10.1016/j.addbeh.2018.09.031>.

Hamaker, Ellen L., and Raoul P. P. P. Grasman. 2015. “To Center or Not
to Center? Investigating Inertia with a Multilevel Autoregressive
Model.” *Frontiers in Psychology* 5: 1492.
<https://doi.org/10.3389/fpsyg.2014.01492>.

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

Nickell, Stephen. 1981. “Biases in Dynamic Models with Fixed Effects.”
*Econometrica* 49 (6): 1417–26. <https://doi.org/10.2307/1911408>.

Rosario, Kareena S. del, and Tessa V. West. 2025. “A Practical Guide to
Specifying Random Effects in Longitudinal Dyadic Multilevel Modeling.”
*Advances in Methods and Practices in Psychological Science* 8 (3):
25152459251351286. <https://doi.org/10.1177/25152459251351286>.
