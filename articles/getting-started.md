# Getting Started

``` r

library(dyadMLM)
```

## Installation

You can install the development version of `dyadMLM` from GitHub with:

``` r

# install.packages("pak")
pak::pak("Pascal-Kueng/dyadMLM")
```

## About this Vignette

`dyadMLM` helps researchers prepare cross-sectional and intensive
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

The available model-specific vignettes include the [Actor-Partner
Interdependence
Model](https://pascal-kueng.github.io/dyadMLM/articles/apim.md),
[Mixed-Composition
APIM](https://pascal-kueng.github.io/dyadMLM/articles/mixed-apim.md),
[Dyad-Individual
Model](https://pascal-kueng.github.io/dyadMLM/articles/dim.md), and
[Dyadic Score
Model](https://pascal-kueng.github.io/dyadMLM/articles/dsm.md).

The [online package overview](https://pascal-kueng.github.io/dyadMLM/)
provides the current online versions of these vignettes and the complete
function reference.

## Prerequisites

The basic data structure needed for `dyadMLM` is a long data frame where
dyads are stacked on top of each other and both members of a dyad appear
as separate rows.

If your raw data are currently in wide format (for time or dyads or
both), reshape them to this long structure first. See the [tidyr
pivoting vignette](https://tidyr.tidyverse.org/articles/pivot.html) or
the [`pivot_longer()`
reference](https://tidyr.tidyverse.org/reference/pivot_longer.html).

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
time 1 to time 3 for that person. `dyadMLM` accepts this structure
without requiring a placeholder row for the missing occasion.

## Data preparation for distinguishable dyads

`example_dyadic_crosssectional` is a simulated cross-sectional dataset
for distinguishable dyads. Each dyad has two rows: one for each member.

    #>   personID coupleID gender communication satisfaction
    #> 1        1        1 female      4.789772     4.367824
    #> 2        2        1   male      3.803445     2.342890
    #> 3        3        2 female      2.914052     2.442250
    #> 4        4        2   male      6.508207     6.080428
    #> 5        5        3 female      5.696995     5.865494
    #> 6        6        3   male      8.215332     9.661295

We validate and prepare the data with the function
[`dyadMLM::prepare_dyad_data()`](https://pascal-kueng.github.io/dyadMLM/reference/prepare_dyad_data.md).

``` r

cross_distinguishable_data <- dyadMLM::prepare_dyad_data(
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
#> # dyadMLM data
#> # Rows: 190 | Dyads: 95 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID, role = gender
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

The function automatically recognized that in this dataset there are 95
female-male dyads and created APIM-relevant variables (Kenny and Cook
1999). These generated `.dy_*` columns can be used directly in model
formulas.

For fitted APIM examples using these columns, see the [Actor-Partner
Interdependence Model
vignette](https://pascal-kueng.github.io/dyadMLM/articles/apim.md).

## Data preparation for exchangeable dyads

For a dataset with only one type of dyad that should be treated as
exchangeable, omit the `role` argument:

``` r

cross_exchangeable_data <- dyadMLM::prepare_dyad_data(
  data = example_dyadic_crosssectional,
  group = coupleID,
  member = personID,
  seed = 123
)

print(cross_exchangeable_data, n = 4)
#> # dyadMLM data
#> # Rows: 190 | Dyads: 95 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID
#> #
#> # Dyad compositions:
#> # assumed_exchangeable exchangeable 95 dyads
#> #
#> # Added columns:
#> #   .dy_composition       inferred dyad composition
#> #   .dy_composition_role  composition-specific member role
#> #   .dy_is_{comp-role}    composition-role indicator columns
#> #   .dy_diff_{comp}       composition-specific sum-diff contrasts with
#> #                         arbitrary direction; 0 for distinguishable dyads or
#> #                         other exchangeable compositions
#> #
#> # A tibble: 190 × 9
#>   personID coupleID gender communication satisfaction .dy_composition     
#>      <int>    <int> <fct>          <dbl>        <dbl> <fct>               
#> 1        1        1 female          4.79         4.37 assumed_exchangeable
#> 2        2        1 male            3.80         2.34 assumed_exchangeable
#> 3        3        2 female          2.91         2.44 assumed_exchangeable
#> 4        4        2 male            6.51         6.08 assumed_exchangeable
#> # ℹ 186 more rows
#> # ℹ 3 more variables: .dy_composition_role <fct>,
#> #   .dy_is_assumed_exchangeable <dbl>,
#> #   .dy_diff_assumed_exchangeable_arbitrary <dbl>
```

The generated `.dy_diff_assumed_exchangeable_arbitrary` contrast assigns
`-1` and `1` to the two members of each exchangeable dyad (del Rosario
and West 2025). Its direction is arbitrary, and `seed` makes the
assignment reproducible.

Refer to the [exchangeable APIM
section](https://pascal-kueng.github.io/dyadMLM/articles/apim.html#exchangeable-residual-structure)
for how to use these columns to specify an exchangeable dyadic APIM and
recover the constrained actor-partner variance-covariance structure with
[`dyadMLM::exchangeable_rescov()`](https://pascal-kueng.github.io/dyadMLM/reference/exchangeable_rescov.html).

Alternatively, we can explicitly set a dyad composition to exchangeable:

``` r

cross_exchangeable_data <- dyadMLM::prepare_dyad_data(
  data = example_dyadic_crosssectional,
  group = coupleID,
  member = personID,
  role = gender,
  set_exchangeable_compositions = "male-female",
  seed = 123
)

print(cross_exchangeable_data, n = 4)
#> # dyadMLM data
#> # Rows: 190 | Dyads: 95 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID, role = gender
#> #
#> # Dyad compositions:
#> # female_x_male exchangeable (set by user) 95 dyads
#> #
#> # Added columns:
#> #   .dy_composition       inferred dyad composition
#> #   .dy_composition_role  composition-specific member role
#> #   .dy_is_{comp-role}    composition-role indicator columns
#> #   .dy_diff_{comp}       composition-specific sum-diff contrasts with
#> #                         arbitrary direction; 0 for distinguishable dyads or
#> #                         other exchangeable compositions
#> #
#> # A tibble: 190 × 9
#>   personID coupleID gender communication satisfaction .dy_composition
#>      <int>    <int> <fct>          <dbl>        <dbl> <fct>          
#> 1        1        1 female          4.79         4.37 female_x_male  
#> 2        2        1 male            3.80         2.34 female_x_male  
#> 3        3        2 female          2.91         2.44 female_x_male  
#> 4        4        2 male            6.51         6.08 female_x_male  
#> # ℹ 186 more rows
#> # ℹ 3 more variables: .dy_composition_role <fct>, .dy_is_female_x_male <dbl>,
#> #   .dy_diff_female_x_male_arbitrary <dbl>
```

*Note* that whenever you need to refer to a dyad type, the order of
members does not matter (e.g., `male-female` and `female-male` will both
work), and you can use different separators like `male_female`,
`male_x_female`, or `male female`.

## Generating DIM and DSM columns

For exchangeable dyads, we can request DIM predictor columns. This works
here because omitting `role` treats all dyads as a single exchangeable
composition.

``` r

cross_dim_data <- dyadMLM::prepare_dyad_data(
  data = example_dyadic_crosssectional,
  group = coupleID,
  member = personID,
  predictors = communication,
  model_type = "dim",
  seed = 123
)

print(cross_dim_data, n = 4)
#> # dyadMLM data
#> # Rows: 190 | Dyads: 95 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID
#> #
#> # Dyad compositions:
#> # assumed_exchangeable exchangeable 95 dyads
#> #
#> # Added columns:
#> #   .dy_composition             inferred dyad composition
#> #   .dy_composition_role        composition-specific member role
#> #   .dy_is_{comp-role}          composition-role indicator columns
#> #   .dy_diff_{comp}             composition-specific sum-diff contrasts with
#> #                               arbitrary direction; 0 for distinguishable
#> #                               dyads or other exchangeable compositions
#> #   .dy_{pred}_dyad_mean_gmc    dyad-mean predictor: dyad's average predictor
#> #                               level, grand-mean centered
#> #   .dy_{pred}_within_dyad_dev  DIM within-dyad member-deviation predictor:
#> #                               member's difference from the dyad mean
#> #
#> # A tibble: 190 × 11
#>   personID coupleID gender communication satisfaction .dy_composition     
#>      <int>    <int> <fct>          <dbl>        <dbl> <fct>               
#> 1        1        1 female          4.79         4.37 assumed_exchangeable
#> 2        2        1 male            3.80         2.34 assumed_exchangeable
#> 3        3        2 female          2.91         2.44 assumed_exchangeable
#> 4        4        2 male            6.51         6.08 assumed_exchangeable
#> # ℹ 186 more rows
#> # ℹ 5 more variables: .dy_composition_role <fct>,
#> #   .dy_is_assumed_exchangeable <dbl>,
#> #   .dy_diff_assumed_exchangeable_arbitrary <dbl>,
#> #   .dy_communication_dyad_mean_gmc <dbl>,
#> #   .dy_communication_within_dyad_dev <dbl>
```

Generating DSM columns for distinguishable dyads additionally requires
an explicit role order. The role order defines the direction of all DSM
predictor differences and the DSM role contrast (Iida et al. 2018).

``` r

cross_dsm_data <- dyadMLM::prepare_dyad_data(
  data = example_dyadic_crosssectional,
  group = coupleID,
  member = personID,
  role = gender,
  predictors = communication,
  model_type = "dsm",
  dsm_role_order = c("female", "male")
)

print(cross_dsm_data, n = 4)
#> # dyadMLM data
#> # Rows: 190 | Dyads: 95 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID, role = gender
#> # DSM direction: female - male
#> #
#> # Dyad compositions:
#> # female_x_male distinguishable 95 dyads
#> #
#> # Added columns:
#> #   .dy_composition              inferred dyad composition
#> #   .dy_composition_role         composition-specific member role
#> #   .dy_is_{comp-role}           composition-role indicator columns
#> #   .dy_dsm_role_contrast        DSM role contrast: +0.5 for the first declared
#> #                                role and -0.5 for the second declared role
#> #   .dy_{pred}_dyad_mean_gmc     dyad-mean predictor: dyad's average predictor
#> #                                level, grand-mean centered
#> #   .dy_{pred}_within_dyad_diff  DSM signed predictor difference: first
#> #                                declared role minus second declared role
#> #
#> # A tibble: 190 × 12
#>   personID coupleID gender communication satisfaction .dy_composition
#>      <int>    <int> <fct>          <dbl>        <dbl> <fct>          
#> 1        1        1 female          4.79         4.37 female_x_male  
#> 2        2        1 male            3.80         2.34 female_x_male  
#> 3        3        2 female          2.91         2.44 female_x_male  
#> 4        4        2 male            6.51         6.08 female_x_male  
#> # ℹ 186 more rows
#> # ℹ 6 more variables: .dy_composition_role <fct>,
#> #   .dy_is_female_x_male_female <dbl>, .dy_is_female_x_male_male <dbl>,
#> #   .dy_dsm_role_contrast <dbl>, .dy_communication_dyad_mean_gmc <dbl>,
#> #   .dy_communication_within_dyad_diff <dbl>
```

## Intensive longitudinal dyadic data

`example_dyadic_ILD` is a simulated intensive longitudinal dyadic
dataset. Each dyad has repeated observations over `diaryday`, with one
row per person-day.

To prepare intensive longitudinal data, pass the `time` variable to
[`dyadMLM::prepare_dyad_data()`](https://pascal-kueng.github.io/dyadMLM/reference/prepare_dyad_data.md).

``` r

ild_apim_data <- dyadMLM::prepare_dyad_data(
  example_dyadic_ILD,
  group = coupleID,
  member = personID,
  role = gender,
  time = diaryday,
  predictors = provided_support,
  model_type = "apim",
  seed = 123
)

print(ild_apim_data, n = 6)
#> # dyadMLM data
#> # Rows: 1120 | Dyads: 40 | Intensive longitudinal: yes
#> # Structure: group = coupleID, member = personID, role = gender, time =
#> # diaryday
#> #
#> # Dyad compositions:
#> # female_x_male distinguishable 40 dyads
#> #
#> # Added columns:
#> #   .dy_composition         inferred dyad composition
#> #   .dy_composition_role    composition-specific member role
#> #   .dy_is_{comp-role}      composition-role indicator columns
#> #   .dy_{pred}_cwp          within-person predictor: momentary deviations from
#> #                           each person's usual level
#> #   .dy_{pred}_cbp          between-person predictor: stable differences from
#> #                           the average person's usual level
#> #   .dy_{pred}_actor        APIM actor predictor: actor's original predictor
#> #                           values
#> #   .dy_{pred}_partner      APIM partner predictor: partner's original
#> #                           predictor values
#> #   .dy_{pred}_cwp_actor    APIM within-person actor predictor: actor's
#> #                           momentary deviations from their usual level
#> #   .dy_{pred}_cwp_partner  APIM within-person partner predictor: partner's
#> #                           momentary deviations from their usual level
#> #   .dy_{pred}_cbp_actor    APIM between-person actor predictor: actor's stable
#> #                           difference from the average person's usual level
#> #   .dy_{pred}_cbp_partner  APIM between-person partner predictor: partner's
#> #                           stable difference from the average person's usual
#> #                           level
#> #
#> # A tibble: 1,120 × 18
#>   personID coupleID diaryday gender closeness provided_support .dy_composition
#>      <int>    <int>    <int> <fct>      <dbl>            <dbl> <fct>          
#> 1        1        1        0 female      5.03             4.30 female_x_male  
#> 2        2        1        0 male        4.68             4.45 female_x_male  
#> 3        1        1        1 female      5.64             4.24 female_x_male  
#> 4        2        1        1 male        4.52             5.84 female_x_male  
#> 5        1        1        2 female      5.49             3.54 female_x_male  
#> 6        2        1        2 male       NA               NA    female_x_male  
#> # ℹ 1,114 more rows
#> # ℹ 11 more variables: .dy_composition_role <fct>,
#> #   .dy_is_female_x_male_female <dbl>, .dy_is_female_x_male_male <dbl>,
#> #   .dy_provided_support_cwp <dbl>, .dy_provided_support_cbp <dbl>,
#> #   .dy_provided_support_actor <dbl>, .dy_provided_support_partner <dbl>,
#> #   .dy_provided_support_cwp_actor <dbl>,
#> #   .dy_provided_support_cwp_partner <dbl>, …
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

### Preparing lagged predictors

Lagged versions of variables, including an outcome that is also passed
to `predictors`, can be obtained through the `lag_predictors` argument.
[`dyadMLM::prepare_dyad_data()`](https://pascal-kueng.github.io/dyadMLM/reference/prepare_dyad_data.md)
then returns lag-1 raw and within-person-centered actor and partner
columns alongside their contemporaneous versions. Lagging respects the
dyad and member structure, matches observations at exactly `time - 1`,
and does not bridge missing occasions.

For a simpler dynamic model, this example omits `role` and therefore
treats all couples as exchangeable:

``` r

ild_apim_data_dynamic <- dyadMLM::prepare_dyad_data(
  example_dyadic_ILD,
  group = coupleID,
  member = personID,
  time = diaryday,
  predictors = closeness,
  lag_predictors = closeness,
  model_type = "apim",
  seed = 123
)

print(ild_apim_data_dynamic, n = 6)
#> # dyadMLM data
#> # Rows: 1120 | Dyads: 40 | Intensive longitudinal: yes
#> # Structure: group = coupleID, member = personID, time = diaryday
#> #
#> # Dyad compositions:
#> # assumed_exchangeable exchangeable 40 dyads
#> #
#> # Added columns:
#> #   .dy_composition              inferred dyad composition
#> #   .dy_composition_role         composition-specific member role
#> #   .dy_is_{comp-role}           composition-role indicator columns
#> #   .dy_diff_{comp}              composition-specific sum-diff contrasts with
#> #                                arbitrary direction; 0 for distinguishable
#> #                                dyads or other exchangeable compositions
#> #   .dy_{pred}_lag1              lag-1 raw predictor values
#> #   .dy_{pred}_cwp               within-person predictor: momentary deviations
#> #                                from each person's usual level
#> #   .dy_{pred}_cwp_lag1          lag-1 within-person predictor: momentary
#> #                                deviations from each person's usual level
#> #   .dy_{pred}_cbp               between-person predictor: stable differences
#> #                                from the average person's usual level
#> #   .dy_{pred}_actor             APIM actor predictor: actor's original
#> #                                predictor values
#> #   .dy_{pred}_actor_lag1        lag-1 APIM actor predictor: actor's original
#> #                                predictor values
#> #   .dy_{pred}_partner           APIM partner predictor: partner's original
#> #                                predictor values
#> #   .dy_{pred}_partner_lag1      lag-1 APIM partner predictor: partner's
#> #                                original predictor values
#> #   .dy_{pred}_cwp_actor         APIM within-person actor predictor: actor's
#> #                                momentary deviations from their usual level
#> #   .dy_{pred}_cwp_actor_lag1    lag-1 APIM within-person actor predictor:
#> #                                actor's momentary deviations from their usual
#> #                                level
#> #   .dy_{pred}_cwp_partner       APIM within-person partner predictor:
#> #                                partner's momentary deviations from their
#> #                                usual level
#> #   .dy_{pred}_cwp_partner_lag1  lag-1 APIM within-person partner predictor:
#> #                                partner's momentary deviations from their
#> #                                usual level
#> #   .dy_{pred}_cbp_actor         APIM between-person actor predictor: actor's
#> #                                stable difference from the average person's
#> #                                usual level
#> #   .dy_{pred}_cbp_partner       APIM between-person partner predictor:
#> #                                partner's stable difference from the average
#> #                                person's usual level
#> #
#> # A tibble: 1,120 × 24
#>   personID coupleID diaryday gender closeness provided_support .dy_composition  
#>      <int>    <int>    <int> <fct>      <dbl>            <dbl> <fct>            
#> 1        1        1        0 female      5.03             4.30 assumed_exchange…
#> 2        2        1        0 male        4.68             4.45 assumed_exchange…
#> 3        1        1        1 female      5.64             4.24 assumed_exchange…
#> 4        2        1        1 male        4.52             5.84 assumed_exchange…
#> 5        1        1        2 female      5.49             3.54 assumed_exchange…
#> 6        2        1        2 male       NA               NA    assumed_exchange…
#> # ℹ 1,114 more rows
#> # ℹ 17 more variables: .dy_composition_role <fct>,
#> #   .dy_is_assumed_exchangeable <dbl>,
#> #   .dy_diff_assumed_exchangeable_arbitrary <dbl>, .dy_closeness_cwp <dbl>,
#> #   .dy_closeness_cbp <dbl>, .dy_closeness_lag1 <dbl>,
#> #   .dy_closeness_cwp_lag1 <dbl>, .dy_closeness_actor <dbl>,
#> #   .dy_closeness_partner <dbl>, .dy_closeness_cwp_actor <dbl>, …
```

**Note:** Whether to use the raw or within-person-centered lagged
outcome depends on the research question and the data. Including a
lagged **outcome** in dynamic models can introduce bias, especially in
shorter time series (Hamaker and Grasman 2015; Nickell 1981; Gistelinck
et al. 2021). See the [APIM
vignette](https://pascal-kueng.github.io/dyadMLM/articles/apim.md) for a
more detailed discussion and guidance.

## Data with multiple and mixed-composition dyads

`example_dyadic_crosssectional_mixed` contains three dyad compositions
in the same data object: distinguishable female-male dyads and
exchangeable female-female and male-male dyads (Bolger et al. 2025).

Let’s have `dyadMLM` infer the compositions automatically:

``` r

mixed_cross_data <- dyadMLM::prepare_dyad_data(
  example_dyadic_crosssectional_mixed,
  group = coupleID,
  member = personID,
  role = gender,
  seed = 123
)

print(mixed_cross_data, n = 4)
#> # dyadMLM data
#> # Rows: 640 | Dyads: 320 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID, role = gender
#> #
#> # Dyad compositions:
#> # female_x_female exchangeable    100 dyads
#> # female_x_male   distinguishable 120 dyads
#> # male_x_male     exchangeable    100 dyads
#> #
#> # Added columns:
#> #   .dy_composition       inferred dyad composition
#> #   .dy_composition_role  composition-specific member role
#> #   .dy_is_{comp-role}    composition-role indicator columns
#> #   .dy_diff_{comp}       composition-specific sum-diff contrasts with
#> #                         arbitrary direction; 0 for distinguishable dyads or
#> #                         other exchangeable compositions
#> #
#> # A tibble: 640 × 12
#>   personID coupleID gender satisfaction .dy_composition .dy_composition_role
#>      <int>    <int> <fct>         <dbl> <fct>           <fct>               
#> 1        1        1 female         4.95 female_x_male   female_x_male_female
#> 2        2        1 male           5.26 female_x_male   female_x_male_male  
#> 3        3        2 female         5.14 female_x_male   female_x_male_female
#> 4        4        2 male           3.11 female_x_male   female_x_male_male  
#> # ℹ 636 more rows
#> # ℹ 6 more variables: .dy_is_female_x_female <dbl>,
#> #   .dy_is_female_x_male_female <dbl>, .dy_is_female_x_male_male <dbl>,
#> #   .dy_is_male_x_male <dbl>, .dy_diff_female_x_female_arbitrary <dbl>,
#> #   .dy_diff_male_x_male_arbitrary <dbl>
```

Note that when role compositions are available, each exchangeable
composition receives its own difference contrast, such as
`.dy_diff_female_x_female_arbitrary`, which is `0` for all other
compositions (del Rosario and West 2025).

We can use this data to model these dyad types as separate or in the
same model. The [APIMs with Mixed Dyad Compositions
vignette](https://pascal-kueng.github.io/dyadMLM/articles/mixed-apim.md)
shows mixed-composition formulas and practical convergence notes.

### Keeping only selected dyad compositions (filtering)

Sometimes a mixed dataset contains dyad compositions that should not be
part of a given analysis. Use `include_compositions` to keep only dyads
whose *observed* composition matches the requested labels. The filtering
happens before exchangeability constraints and pooling, so
`set_exchangeable_compositions` and `pool_compositions` can only refer
to retained dyad compositions.

``` r

mixed_cross_data_included <- dyadMLM::prepare_dyad_data(
  example_dyadic_crosssectional_mixed,
  group = coupleID,
  member = personID,
  role = gender,
  include_compositions = c("female-female", "male-male"),
  seed = 123
)

print(mixed_cross_data_included, n = 4)
#> # dyadMLM data
#> # Rows: 400 | Dyads: 200 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID, role = gender
#> #
#> # Dyad compositions:
#> # female_x_female exchangeable 100 dyads
#> # male_x_male     exchangeable 100 dyads
#> #
#> # Added columns:
#> #   .dy_composition       inferred dyad composition
#> #   .dy_composition_role  composition-specific member role
#> #   .dy_is_{comp-role}    composition-role indicator columns
#> #   .dy_diff_{comp}       composition-specific sum-diff contrasts with
#> #                         arbitrary direction; 0 for distinguishable dyads or
#> #                         other exchangeable compositions
#> #
#> # A tibble: 400 × 10
#>   personID coupleID gender satisfaction .dy_composition .dy_composition_role
#>      <int>    <int> <fct>         <dbl> <fct>           <fct>               
#> 1      241      121 female         5.32 female_x_female female_x_female     
#> 2      242      121 female         5.37 female_x_female female_x_female     
#> 3      243      122 female         5.99 female_x_female female_x_female     
#> 4      244      122 female         6.93 female_x_female female_x_female     
#> # ℹ 396 more rows
#> # ℹ 4 more variables: .dy_is_female_x_female <dbl>, .dy_is_male_x_male <dbl>,
#> #   .dy_diff_female_x_female_arbitrary <dbl>,
#> #   .dy_diff_male_x_male_arbitrary <dbl>
```

### Setting distinguishable dyads to be treated as exchangeable

As mentioned earlier, a distinguishable dyad composition can be treated
as exchangeable. In a mixed dyad composition dataset, this specification
keeps the differentiation between the kinds of dyads (e.g., `male-male`,
`female-female`, and `male-female`), as opposed to omitting role, which
would pool all dyad compositions into one exchangeable composition.

``` r

mixed_cross_exchangeable_data <- dyadMLM::prepare_dyad_data(
  example_dyadic_crosssectional_mixed,
  group = coupleID,
  member = personID,
  role = gender,
  set_exchangeable_compositions = c("male-female"),
  seed = 123
)

print(mixed_cross_exchangeable_data, n = 4)
#> # dyadMLM data
#> # Rows: 640 | Dyads: 320 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID, role = gender
#> #
#> # Dyad compositions:
#> # female_x_female exchangeable               100 dyads
#> # female_x_male   exchangeable (set by user) 120 dyads
#> # male_x_male     exchangeable               100 dyads
#> #
#> # Added columns:
#> #   .dy_composition       inferred dyad composition
#> #   .dy_composition_role  composition-specific member role
#> #   .dy_is_{comp-role}    composition-role indicator columns
#> #   .dy_diff_{comp}       composition-specific sum-diff contrasts with
#> #                         arbitrary direction; 0 for distinguishable dyads or
#> #                         other exchangeable compositions
#> #
#> # A tibble: 640 × 12
#>   personID coupleID gender satisfaction .dy_composition .dy_composition_role
#>      <int>    <int> <fct>         <dbl> <fct>           <fct>               
#> 1        1        1 female         4.95 female_x_male   female_x_male       
#> 2        2        1 male           5.26 female_x_male   female_x_male       
#> 3        3        2 female         5.14 female_x_male   female_x_male       
#> 4        4        2 male           3.11 female_x_male   female_x_male       
#> # ℹ 636 more rows
#> # ℹ 6 more variables: .dy_is_female_x_female <dbl>, .dy_is_female_x_male <dbl>,
#> #   .dy_is_male_x_male <dbl>, .dy_diff_female_x_female_arbitrary <dbl>,
#> #   .dy_diff_female_x_male_arbitrary <dbl>,
#> #   .dy_diff_male_x_male_arbitrary <dbl>
```

### Pooling different dyad compositions

Sometimes for theoretical or practical reasons, we may want to pool
selected exchangeable dyad compositions and analyze them as if they were
one. Pooling can impose equality constraints among compositions. After
fitting nested pooled and unpooled models to the same observations,
these constraints can be tested with
[`dyadMLM::compare_dyad_models()`](https://pascal-kueng.github.io/dyadMLM/reference/compare_dyad_models.html);
see [Testing distinguishability in the APIM
vignette](https://pascal-kueng.github.io/dyadMLM/articles/apim.html#testing-distinguishability)
for the model-comparison workflow.

For instance, let’s pool `male-male` and `female-female` dyads and name
them `same-sex` dyads:

``` r

mixed_cross_data_pooled <- dyadMLM::prepare_dyad_data(
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
#> # dyadMLM data
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
#> #   .dy_composition       inferred dyad composition
#> #   .dy_composition_role  composition-specific member role
#> #   .dy_is_{comp-role}    composition-role indicator columns
#> #   .dy_diff_{comp}       composition-specific sum-diff contrasts with
#> #                         arbitrary direction; 0 for distinguishable dyads or
#> #                         other exchangeable compositions
#> #
#> # A tibble: 640 × 10
#>    personID coupleID gender satisfaction .dy_composition .dy_composition_role
#>       <int>    <int> <fct>         <dbl> <fct>           <fct>               
#>  1        1        1 female         4.95 female_x_male   female_x_male_female
#>  2        2        1 male           5.26 female_x_male   female_x_male_male  
#>  3        3        2 female         5.14 female_x_male   female_x_male_female
#>  4        4        2 male           3.11 female_x_male   female_x_male_male  
#>  5        5        3 female         6.40 female_x_male   female_x_male_female
#>  6        6        3 male           3.45 female_x_male   female_x_male_male  
#>  7        7        4 female         4.16 female_x_male   female_x_male_female
#>  8        8        4 male           6.47 female_x_male   female_x_male_male  
#>  9        9        5 female         5.97 female_x_male   female_x_male_female
#> 10       10        5 male           5.44 female_x_male   female_x_male_male  
#> # ℹ 630 more rows
#> # ℹ 4 more variables: .dy_is_female_x_male_female <dbl>,
#> #   .dy_is_female_x_male_male <dbl>, .dy_is_same_sex <dbl>,
#> #   .dy_diff_same_sex_arbitrary <dbl>
```

Note that you cannot pool distinguishable dyads. If we wanted to pool
`female-male` with `male-male`, we would first have to treat
`female-male` as exchangeable:

``` r

mixed_cross_data_pooled_constrained <- dyadMLM::prepare_dyad_data(
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
#> # dyadMLM data
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
#> #   .dy_composition       inferred dyad composition
#> #   .dy_composition_role  composition-specific member role
#> #   .dy_is_{comp-role}    composition-role indicator columns
#> #   .dy_diff_{comp}       composition-specific sum-diff contrasts with
#> #                         arbitrary direction; 0 for distinguishable dyads or
#> #                         other exchangeable compositions
#> #
#> # A tibble: 640 × 10
#>    personID coupleID gender satisfaction .dy_composition    .dy_composition_role
#>       <int>    <int> <fct>         <dbl> <fct>              <fct>               
#>  1        1        1 female         4.95 pooled_exchangeab… pooled_exchangeable 
#>  2        2        1 male           5.26 pooled_exchangeab… pooled_exchangeable 
#>  3        3        2 female         5.14 pooled_exchangeab… pooled_exchangeable 
#>  4        4        2 male           3.11 pooled_exchangeab… pooled_exchangeable 
#>  5        5        3 female         6.40 pooled_exchangeab… pooled_exchangeable 
#>  6        6        3 male           3.45 pooled_exchangeab… pooled_exchangeable 
#>  7        7        4 female         4.16 pooled_exchangeab… pooled_exchangeable 
#>  8        8        4 male           6.47 pooled_exchangeab… pooled_exchangeable 
#>  9        9        5 female         5.97 pooled_exchangeab… pooled_exchangeable 
#> 10       10        5 male           5.44 pooled_exchangeab… pooled_exchangeable 
#> # ℹ 630 more rows
#> # ℹ 4 more variables: .dy_is_female_x_female <dbl>,
#> #   .dy_is_pooled_exchangeable <dbl>, .dy_diff_female_x_female_arbitrary <dbl>,
#> #   .dy_diff_pooled_exchangeable_arbitrary <dbl>
```

------------------------------------------------------------------------

**Continue** with the [Actor-Partner Interdependence Model (APIM)
vignette](https://pascal-kueng.github.io/dyadMLM/articles/apim.md).

Related model-specific vignettes:

- [Mixed-Composition APIM
  vignette](https://pascal-kueng.github.io/dyadMLM/articles/mixed-apim.md),
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
