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
supports common dyadic designs with one type of exchangeable or
distinguishable dyad, and it also handles studies where different kinds
of dyads appear in the same dataset, such as female-male, female-female,
and male-male couples.

It automatically creates model-ready columns for dyadic multilevel model
parameterizations such as Actor-Partner Interdependence Models (APIM),
Dyad-Individual Models (DIM), and undirected Dyadic Score Models (DSM).
Current DIM and undirected DSM helpers require a single type of
exchangeable dyad composition.

This vignette focuses on the automatic data preparation step.

For guidance and examples on how to use the prepared data to estimate
cross-sectional, generalized, and intensive longitudinal APIMs, see the
[Actor-Partner Interdependence Model
vignette](https://pascal-kueng.github.io/interdep/articles/apim.md). For
models that combine distinguishable and exchangeable dyad compositions,
see the [Mixed-Composition APIM
vignette](https://pascal-kueng.github.io/interdep/articles/mixed-apim.md).

For guidance on how to use the Dyad-Individual Model (DIM)
parameterization, including dyad-mean and within-dyad-deviation
predictors and their equivalence to APIM effects in exchangeable dyads,
see the [Dyad-Individual Model
vignette](https://pascal-kueng.github.io/interdep/articles/dim.md).

For undirected dyadic score outcomes, see the [Undirected Dyadic Score
Model
vignette](https://pascal-kueng.github.io/interdep/articles/undirected-dsm.md).

## Prerequisites

The basic data structure needed for `interdep` is a long data frame
where dyads are stacked on top of each other and both members of a dyad
appear as separate rows. Roughly, the expected structure is:

If your raw data are currently in wide format (for time or dyads or
both), reshape them to this long structure before using
[`prepare_interdep_data()`](https://pascal-kueng.github.io/interdep/reference/prepare_interdep_data.md).
See the [tidyr pivoting
vignette](https://tidyr.tidyverse.org/articles/pivot.html) or the
[`pivot_longer()`
reference](https://tidyr.tidyverse.org/reference/pivot_longer.html).

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

knitr::kable(
  head(example_dyadic_crosssectional),
  digits = 2,
  caption = "First six observations."
)
```

| personID | coupleID | gender | communication | satisfaction |
|---------:|---------:|:-------|--------------:|-------------:|
|        1 |        1 | female |          4.79 |         4.37 |
|        2 |        1 | male   |          3.80 |         2.34 |
|        3 |        2 | female |          2.91 |         2.44 |
|        4 |        2 | male   |          6.51 |         6.08 |
|        5 |        3 | female |          5.70 |         5.87 |
|        6 |        3 | male   |          8.22 |         9.66 |

First six observations. {.table}

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
#> #   .i_is_*              composition-role indicator columns
#> #   .i_*_raw_actor       APIM actor predictor: actor's original predictor
#> #                        values
#> #   .i_*_raw_partner     APIM partner predictor: partner's original predictor
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
#> #   .i_communication_raw_actor <dbl>, .i_communication_raw_partner <dbl>
```

The function automatically recognized that in this dataset there are 95
female-male dyads and created APIM-relevant variables. These generated
`.i_*` columns can be used directly in model formulas.

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
    .i_is_female_x_male_female:.i_communication_raw_actor +
    .i_is_female_x_male_male:.i_communication_raw_actor +

    # Gender-specific partner effects
    .i_is_female_x_male_female:.i_communication_raw_partner +
    .i_is_female_x_male_male:.i_communication_raw_partner +

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
#> #   .i_is_*              composition-role indicator columns
#> #   .i_diff_*            composition-specific sum-diff contrasts with arbitrary
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
for all other compositions. We use a fixed seed in the examples below
for consistent results.

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
#> #   .i_is_*              composition-role indicator columns
#> #   .i_diff_*            composition-specific sum-diff contrasts with arbitrary
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

For exchangeable dyads, we can also request DIM and undirected DSM
columns. This works here because omitting `role` treats all dyads as a
single type of exchangeable dyads, and DIM and undirected DSM currently
require exchangeable dyads. Undirected DSM preparation additionally
needs `outcomes`, because it creates dyad-mean and within-dyad-deviation
columns for both the predictor and the outcome.

``` r

cross_dim_dsm_data <- prepare_interdep_data(
  data = example_dyadic_crosssectional,
  group = coupleID,
  member = personID,
  predictors = communication,
  outcomes = satisfaction,
  model_type = c("dim", "undirected_dsm"),
  seed = 123
)

print(cross_dim_dsm_data, n = 4)
#> # interdep data
#> # Rows: 190 | Dyads: 95 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID
#> #
#> # Dyad compositions:
#> # assumed_exchangeable exchangeable 95 dyads
#> #
#> # Added columns:
#> #   .i_composition                  inferred dyad composition
#> #   .i_composition_role             composition-specific member role
#> #   .i_is_*                         composition-role indicator columns
#> #   .i_diff_*                       composition-specific sum-diff contrasts
#> #                                   with arbitrary direction; 0 for
#> #                                   distinguishable dyads or other exchangeable
#> #                                   compositions
#> #   .i_*_raw_dyad_mean_gmc          DIM dyad-mean predictor: dyad's average
#> #                                   predictor level, grand-mean centered
#> #   .i_*_raw_within_dyad_deviation  DIM within-dyad predictor deviation:
#> #                                   person's difference from the dyad average
#> #   .i_*_raw_dyad_mean              DSM dyad-mean outcome: dyad's average
#> #                                   outcome level
#> #   .i_*_raw_within_dyad_deviation  DSM within-dyad outcome deviation: person's
#> #                                   difference from the dyad average
#> #
#> # A tibble: 190 × 13
#>   personID coupleID gender communication satisfaction .i_composition      
#>      <int>    <int> <fct>          <dbl>        <dbl> <fct>               
#> 1        1        1 female          4.79         4.37 assumed_exchangeable
#> 2        2        1 male            3.80         2.34 assumed_exchangeable
#> 3        3        2 female          2.91         2.44 assumed_exchangeable
#> 4        4        2 male            6.51         6.08 assumed_exchangeable
#> # ℹ 186 more rows
#> # ℹ 7 more variables: .i_composition_role <fct>,
#> #   .i_is_assumed_exchangeable <dbl>,
#> #   .i_diff_assumed_exchangeable_arbitrary <dbl>,
#> #   .i_communication_raw_dyad_mean_gmc <dbl>,
#> #   .i_communication_raw_within_dyad_deviation <dbl>,
#> #   .i_satisfaction_raw_dyad_mean <dbl>, …
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
#> #   .i_is_*              composition-role indicator columns
#> #   .i_diff_*            composition-specific sum-diff contrasts with arbitrary
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

knitr::kable(
  head(example_dyadic_ILD, n = 8),
  digits = 2,
  caption = "First eight person-day observations."
)
```

| personID | coupleID | diaryday | gender | closeness | provided_support |
|---------:|---------:|---------:|:-------|----------:|-----------------:|
|        1 |        1 |        0 | female |      5.03 |             4.30 |
|        1 |        1 |        1 | female |      5.64 |             4.24 |
|        1 |        1 |        2 | female |      5.49 |             3.54 |
|        1 |        1 |        3 | female |      6.71 |             5.04 |
|        1 |        1 |        4 | female |      5.61 |             4.74 |
|        1 |        1 |        5 | female |      6.11 |             4.72 |
|        1 |        1 |        6 | female |      6.96 |             5.12 |
|        1 |        1 |        7 | female |      7.03 |             5.21 |

First eight person-day observations. {.table}

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
#> #   .i_composition       inferred dyad composition
#> #   .i_composition_role  composition-specific member role
#> #   .i_is_*              composition-role indicator columns
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
#> # A tibble: 1,120 × 16
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
#> # ℹ 9 more variables: .i_composition_role <fct>,
#> #   .i_is_female_x_male_female <dbl>, .i_is_female_x_male_male <dbl>,
#> #   .i_provided_support_cwp <dbl>, .i_provided_support_cbp <dbl>,
#> #   .i_provided_support_cwp_actor <dbl>, .i_provided_support_cwp_partner <dbl>,
#> #   .i_provided_support_cbp_actor <dbl>, .i_provided_support_cbp_partner <dbl>
```

By default, numeric predictors in longitudinal APIM preparation are
decomposed into within-person and between-person components. This
temporal predictor decomposition can be controlled via the
`temporal_predictor_decomposition` argument. Use `time_2l` when
within-person and between-person associations should be estimated
separately.

## Data with multiple and mixed-composition dyads

`example_dyadic_crosssectional_mixed` contains three dyad compositions
in the same data object: distinguishable female-male dyads and
exchangeable female-female and male-male dyads.

Let `interdep` infer the compositions automatically:

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
#> #   .i_is_*              composition-role indicator columns
#> #   .i_diff_*            composition-specific sum-diff contrasts with arbitrary
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
same model. The [Actor-Partner Interdependence Model
vignette](https://pascal-kueng.github.io/interdep/articles/apim.md)
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
#> #   .i_is_*              composition-role indicator columns
#> #   .i_diff_*            composition-specific sum-diff contrasts with arbitrary
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
#> #   .i_is_*              composition-role indicator columns
#> #   .i_diff_*            composition-specific sum-diff contrasts with arbitrary
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

Sometimes for theoretical or practical reasons, we may want to **pool
different exchangeable dyads** and analyze them as if they were one.
This also allows testing various constraints via model comparisons
later.

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
#> #   .i_is_*              composition-role indicator columns
#> #   .i_diff_*            composition-specific sum-diff contrasts with arbitrary
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
  set_exchangeable_compositions = "male_x_female",
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
#> #   .i_is_*              composition-role indicator columns
#> #   .i_diff_*            composition-specific sum-diff contrasts with arbitrary
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

For model formulas and interpretation, continue with the [Actor-Partner
Interdependence Model
vignette](https://pascal-kueng.github.io/interdep/articles/apim.md),
[Mixed-Composition APIM
vignette](https://pascal-kueng.github.io/interdep/articles/mixed-apim.md),
[Dyad-Individual Model
vignette](https://pascal-kueng.github.io/interdep/articles/dim.md), or
[Undirected Dyadic Score Model
vignette](https://pascal-kueng.github.io/interdep/articles/undirected-dsm.md).

For an in-depth tutorial covering data preparation, model fitting,
diagnostics, and assumption checks, see [Distinguishable and
Exchangeable Dyads: Bayesian Multilevel
Modelling](https://pascal-kueng.github.io/05DyadicDataAnalysis/). It
uses `interdep` for cross-sectional and intensive longitudinal APIM and
DIM workflows, with models fitted primarily using `brms`
([source](https://github.com/Pascal-Kueng/05DyadicDataAnalysis),
[DOI](https://doi.org/10.5281/zenodo.17400655)).
