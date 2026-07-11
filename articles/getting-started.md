# Getting Started

``` r

library(interdep)
has_glmmTMB <- requireNamespace("glmmTMB", quietly = TRUE)
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
Dyad-Individual Modles (DIM), and undirected Dyadic Score Models (DSM).
Current DIM and undirected DSM helpers require a single type of
exchangeable dyad composition.

This vignette focuses on the automatic data preparation step.

For guidance and examples on how to use the prepared data to estimate
various APIM models from simple Gaussian cross-sectional to generalized
intensive longitudinal (ILD) models with mutliple dyad types, see the
[Actor-Partner Interdependence Model
vignette](https://pascal-kueng.github.io/interdep/articles/apim.md).

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
appear as separate rows. Roughtly, the expected structure is:

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
`member`, and optional `time` variables must be complete, or not
observed (e.g., no NA values are allowed).

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

In this example, note that the row for person 1 at time 2 is absent. The
time variable still uses the observed measurement occasions and skips
from time 1 to time 3 for that person, which is fine and gives the
models all the information they need.

## Data preparation for cross-sectional dyadic data

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

This is the minimal call:

``` r

cross_exchangeable_data <- prepare_interdep_data(
  data = example_dyadic_crosssectional,
  group = coupleID,
  member = personID,
  seed = 123
)

print(cross_exchangeable_data, n = 20)
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
#> #   .i_diff_*            composition-specific sum-diff contrasts; 0 for
#> #                        distinguishable dyads or other exchangeable
#> #                        compositions
#> #
#> # A tibble: 190 × 9
#>    personID coupleID gender communication satisfaction .i_composition      
#>       <int>    <int> <fct>          <dbl>        <dbl> <fct>               
#>  1        1        1 female          4.79        4.37  assumed_exchangeable
#>  2        2        1 male            3.80        2.34  assumed_exchangeable
#>  3        3        2 female          2.91        2.44  assumed_exchangeable
#>  4        4        2 male            6.51        6.08  assumed_exchangeable
#>  5        5        3 female          5.70        5.87  assumed_exchangeable
#>  6        6        3 male            8.22        9.66  assumed_exchangeable
#>  7        7        4 female          5.28        6.50  assumed_exchangeable
#>  8        8        4 male            4.89        3.08  assumed_exchangeable
#>  9        9        5 female          6.01        7.41  assumed_exchangeable
#> 10       10        5 male            4.32        1.47  assumed_exchangeable
#> 11       11        6 female          7.74        7.85  assumed_exchangeable
#> 12       12        6 male            6.57        9.84  assumed_exchangeable
#> 13       13        7 female          5.37        4.82  assumed_exchangeable
#> 14       14        7 male            5.79        6.15  assumed_exchangeable
#> 15       15        8 female          3.62        2.33  assumed_exchangeable
#> 16       16        8 male            3.21       -1.35  assumed_exchangeable
#> 17       17        9 female          4.42        4.96  assumed_exchangeable
#> 18       18        9 male            3.85        1.56  assumed_exchangeable
#> 19       19       10 female          5.22        4.23  assumed_exchangeable
#> 20       20       10 male            3.66       -0.496 assumed_exchangeable
#> # ℹ 170 more rows
#> # ℹ 3 more variables: .i_composition_role <fct>,
#> #   .i_is_assumed_exchangeable <dbl>, .i_diff_assumed_exchangeable <dbl>
```

Note that by not providing a `role` variable, we get a single type of
exchangeable dyads. If we want to distinguish by gender, we do:

``` r

cross_distinguishable_data <- prepare_interdep_data(
  data = example_dyadic_crosssectional,
  group = coupleID,
  member = personID,
  role = gender,
  
  # In this example, we also add predictors and a model-type to get 
  # model-ready columns for this model-type
  predictors = communication,
  model_type = "apim",
  seed = 123
)

print(cross_distinguishable_data, n = 20)
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
#>  1        1        1 female          4.79        4.37  female_x_male 
#>  2        2        1 male            3.80        2.34  female_x_male 
#>  3        3        2 female          2.91        2.44  female_x_male 
#>  4        4        2 male            6.51        6.08  female_x_male 
#>  5        5        3 female          5.70        5.87  female_x_male 
#>  6        6        3 male            8.22        9.66  female_x_male 
#>  7        7        4 female          5.28        6.50  female_x_male 
#>  8        8        4 male            4.89        3.08  female_x_male 
#>  9        9        5 female          6.01        7.41  female_x_male 
#> 10       10        5 male            4.32        1.47  female_x_male 
#> 11       11        6 female          7.74        7.85  female_x_male 
#> 12       12        6 male            6.57        9.84  female_x_male 
#> 13       13        7 female          5.37        4.82  female_x_male 
#> 14       14        7 male            5.79        6.15  female_x_male 
#> 15       15        8 female          3.62        2.33  female_x_male 
#> 16       16        8 male            3.21       -1.35  female_x_male 
#> 17       17        9 female          4.42        4.96  female_x_male 
#> 18       18        9 male            3.85        1.56  female_x_male 
#> 19       19       10 female          5.22        4.23  female_x_male 
#> 20       20       10 male            3.66       -0.496 female_x_male 
#> # ℹ 170 more rows
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
    # remove standard intercept and model separate intercepts for male and female
    0 + 
    .i_is_female_x_male_female + 
    .i_is_female_x_male_male + 
    
    # gender-specific slopes for communication actor effect (no main effect)
    .i_is_female_x_male_female:.i_communication_raw_actor + 
    .i_is_female_x_male_male:.i_communication_raw_actor +
    
    # gender-specific slopes for communication partner effect (no main effect)
    .i_is_female_x_male_female:.i_communication_raw_partner + 
    .i_is_female_x_male_male:.i_communication_raw_partner +
    
    # residual covariance in glmmTMB can be modeled with random intercepts
    # when dispformula ~ 0. We model gender-specific residual variances and 
    # a correlation between the partners' residuals. 
    us(0 + 
         .i_is_female_x_male_female + 
         .i_is_female_x_male_male 
       | coupleID)
  
  , dispformula = ~ 0 
  , family = gaussian()
  , data = cross_distinguishable_data
)

summary(cross_distinguishable_model)
```

Models are not run and summarized in this vignette. For fitted APIM
examples, see the [Actor-Partner Interdependence Model
vignette](https://pascal-kueng.github.io/interdep/articles/apim.md).

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
#> #   .i_diff_*            composition-specific sum-diff contrasts; 0 for
#> #                        distinguishable dyads or other exchangeable
#> #                        compositions
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
#> #   .i_diff_female_x_female <dbl>
```

## Intensive longitudinal dyadic data

`example_dyadic_ILD` is a simulated intensive longitudinal dyadic
dataset. Each dyad has repeated observations over `diaryday`, with one
row per person-day.

``` r

print(head(example_dyadic_ILD, n = 26), n = 26)
#> # A tibble: 26 × 6
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
```

For longitudinal data, simply pass the `time` variable as well.

### Exchangeable ILD preparation

``` r

ild_exchangeable_data <- prepare_interdep_data(
  example_dyadic_ILD,
  group = coupleID,
  member = personID,
  time = diaryday,
  predictors = provided_support,
  
  # This time we request DIM-style variables. This only works
  # for exchangeable dyads, which is why we omit the `role` variable here. 
  model_type = 'dim',
  seed = 123
)

print(ild_exchangeable_data)
#> # interdep data
#> # Rows: 1120 | Dyads: 40 | Intensive longitudinal: yes
#> # Structure: group = coupleID, member = personID, time = diaryday
#> #
#> # Dyad compositions:
#> # assumed_exchangeable exchangeable 40 dyads
#> #
#> # Added columns:
#> #   .i_composition                  inferred dyad composition
#> #   .i_composition_role             composition-specific member role
#> #   .i_is_*                         composition-role indicator columns
#> #   .i_diff_*                       composition-specific sum-diff contrasts; 0
#> #                                   for distinguishable dyads or other
#> #                                   exchangeable compositions
#> #   .i_*_cwp                        within-person predictor: momentary
#> #                                   deviations from each person's usual level
#> #   .i_*_cbp                        between-person predictor: stable
#> #                                   differences from the average person's usual
#> #                                   level
#> #   .i_*_cwp_dyad_mean              DIM within-person dyad-mean predictor:
#> #                                   shared momentary deviations in the dyad
#> #   .i_*_cwp_within_dyad_deviation  DIM within-person within-dyad predictor
#> #                                   deviation: person's momentary deviation
#> #                                   from the dyad average
#> #   .i_*_cbp_dyad_mean              DIM between-person dyad-mean predictor:
#> #                                   dyad's stable usual level, grand-mean
#> #                                   centered
#> #   .i_*_cbp_within_dyad_deviation  DIM between-person within-dyad predictor
#> #                                   deviation: person's stable difference from
#> #                                   the dyad's usual level
#> #
#> # A tibble: 1,120 × 16
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
#> # ℹ 9 more variables: .i_composition_role <fct>,
#> #   .i_is_assumed_exchangeable <dbl>, .i_diff_assumed_exchangeable <dbl>,
#> #   .i_provided_support_cwp <dbl>, .i_provided_support_cbp <dbl>,
#> #   .i_provided_support_cwp_dyad_mean <dbl>,
#> #   .i_provided_support_cwp_within_dyad_deviation <dbl>,
#> #   .i_provided_support_cbp_dyad_mean <dbl>, …
```

By default, numeric predictors in longitudinal model-ready preparation
are decomposed into within-person and between-person components. This
temporal predictor decomposition can be controlled via the
`temporal_predictor_decomposition` argument. Usually for ILD, the
`time_2l` option is the correct one.

## Data with multiple and mixed-composition dyads

`example_dyadic_crosssectional_mixed` contains three dyad compositions
in the same data object: distinguishable female-male dyads and
exchangeable female-female and male-male dyads.

``` r

print(example_dyadic_crosssectional_mixed)
#> # A tibble: 640 × 4
#>    personID coupleID gender satisfaction
#>       <int>    <int> <fct>         <dbl>
#>  1        1        1 female         4.95
#>  2        2        1 male           5.26
#>  3        3        2 female         5.14
#>  4        4        2 male           3.11
#>  5        5        3 female         6.40
#>  6        6        3 male           3.45
#>  7        7        4 female         4.16
#>  8        8        4 male           6.47
#>  9        9        5 female         5.97
#> 10       10        5 male           5.44
#> # ℹ 630 more rows
```

Letting the `interdep` package just infer the compositions
automatically:

``` r

mixed_cross_data <- prepare_interdep_data(
  example_dyadic_crosssectional_mixed,
  group = coupleID,
  member = personID,
  role = gender,
  seed = 123
)

print(mixed_cross_data)
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
#> #   .i_diff_*            composition-specific sum-diff contrasts; 0 for
#> #                        distinguishable dyads or other exchangeable
#> #                        compositions
#> #
#> # A tibble: 640 × 12
#>    personID coupleID gender satisfaction .i_composition .i_composition_role 
#>       <int>    <int> <chr>         <dbl> <fct>          <fct>               
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
#> # ℹ 6 more variables: .i_is_female_x_female <dbl>,
#> #   .i_is_female_x_male_female <dbl>, .i_is_female_x_male_male <dbl>,
#> #   .i_is_male_x_male <dbl>, .i_diff_female_x_female <dbl>,
#> #   .i_diff_male_x_male <dbl>
```

We can use this data to model these dyad types as separate or in the
same model; the [Actor-Partner Interdependence Model
vignette](https://pascal-kueng.github.io/interdep/articles/apim.md)
shows both mixed-composition formulas and practical convergence notes.

### Setting distinguishable dyads to be treated as exchangeable

Previously we treated all dyads in the same dataset as the same type of
indistinguishable by omitting the `role` argument. If you need more
control, you can separately set each distinguishable dyad composition in
the dataset to be treated as exchangeable.

Note that whenever you need to refer to a dyad-type, the order of
members does not matter (e.g., ‘male-female’ and ‘female-male’ will both
work), and you can use different separators like ‘male_female’,
‘male_x_female’ or even ‘male female’.

``` r

mixed_cross_exchangeable_data <- prepare_interdep_data(
  example_dyadic_crosssectional_mixed,
  group = coupleID,
  member = personID,
  role = gender,
  set_exchangeable_compositions = c('male-female'),
  seed = 123
)

print(mixed_cross_exchangeable_data)
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
#> #   .i_diff_*            composition-specific sum-diff contrasts; 0 for
#> #                        distinguishable dyads or other exchangeable
#> #                        compositions
#> #
#> # A tibble: 640 × 12
#>    personID coupleID gender satisfaction .i_composition .i_composition_role
#>       <int>    <int> <chr>         <dbl> <fct>          <fct>              
#>  1        1        1 female         4.95 female_x_male  female_x_male      
#>  2        2        1 male           5.26 female_x_male  female_x_male      
#>  3        3        2 female         5.14 female_x_male  female_x_male      
#>  4        4        2 male           3.11 female_x_male  female_x_male      
#>  5        5        3 female         6.40 female_x_male  female_x_male      
#>  6        6        3 male           3.45 female_x_male  female_x_male      
#>  7        7        4 female         4.16 female_x_male  female_x_male      
#>  8        8        4 male           6.47 female_x_male  female_x_male      
#>  9        9        5 female         5.97 female_x_male  female_x_male      
#> 10       10        5 male           5.44 female_x_male  female_x_male      
#> # ℹ 630 more rows
#> # ℹ 6 more variables: .i_is_female_x_female <dbl>, .i_is_female_x_male <dbl>,
#> #   .i_is_male_x_male <dbl>, .i_diff_female_x_female <dbl>,
#> #   .i_diff_female_x_male <dbl>, .i_diff_male_x_male <dbl>
```

This specification keeps the differentiation between the kinds of dyads
(`male-male`, `female-female`, and `male-female`), while treating the
`male-female` composition as exchangeable.

### Pooling different dyad-compositions

Sometimes for theoretical or practical reasons, we may want to **pool
different exchangeable dyads** and analyze them as if they were one.
This also allows to test various constraints via model comparisons.

For instance, let’s pool `male-male` and `female-female` dyads and name
them `same-sex` dyads:

``` r

mixed_cross_data_pooled <- prepare_interdep_data(
  example_dyadic_crosssectional_mixed,
  group = coupleID,
  member = personID,
  role = gender,
  pool_compositions = list(
    'same-sex' = c('male-male', 'female_female')
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
#> #   .i_diff_*            composition-specific sum-diff contrasts; 0 for
#> #                        distinguishable dyads or other exchangeable
#> #                        compositions
#> #
#> # A tibble: 640 × 10
#>    personID coupleID gender satisfaction .i_composition .i_composition_role 
#>       <int>    <int> <chr>         <dbl> <fct>          <fct>               
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
#> #   .i_diff_same_sex <dbl>
```

Note that you cannot pool distinguishable dyads. If you would want to
pool female-male with male-male you could treat female-male as
exchangeable:

``` r

mixed_cross_data_pooled_constrained <- prepare_interdep_data(
  example_dyadic_crosssectional_mixed,
  group = coupleID,
  member = personID,
  role = gender,
  set_exchangeable_compositions = 'male_x_female',
  pool_compositions = list(
    'same-sex' = c('male-male', 'male_female')
  ),
  seed = 123
)

print(mixed_cross_data_pooled_constrained)
#> # interdep data
#> # Rows: 640 | Dyads: 320 | Intensive longitudinal: no
#> # Structure: group = coupleID, member = personID, role = gender
#> #
#> # Dyad compositions:
#> # female_x_female          exchangeable 100 dyads
#> # same-sex (pooled)        exchangeable 220 dyads
#> #   female_x_male
#> #   male_x_male
#> #
#> # Added columns:
#> #   .i_composition       inferred dyad composition
#> #   .i_composition_role  composition-specific member role
#> #   .i_is_*              composition-role indicator columns
#> #   .i_diff_*            composition-specific sum-diff contrasts; 0 for
#> #                        distinguishable dyads or other exchangeable
#> #                        compositions
#> #
#> # A tibble: 640 × 10
#>    personID coupleID gender satisfaction .i_composition .i_composition_role
#>       <int>    <int> <chr>         <dbl> <fct>          <fct>              
#>  1        1        1 female         4.95 same-sex       same-sex           
#>  2        2        1 male           5.26 same-sex       same-sex           
#>  3        3        2 female         5.14 same-sex       same-sex           
#>  4        4        2 male           3.11 same-sex       same-sex           
#>  5        5        3 female         6.40 same-sex       same-sex           
#>  6        6        3 male           3.45 same-sex       same-sex           
#>  7        7        4 female         4.16 same-sex       same-sex           
#>  8        8        4 male           6.47 same-sex       same-sex           
#>  9        9        5 female         5.97 same-sex       same-sex           
#> 10       10        5 male           5.44 same-sex       same-sex           
#> # ℹ 630 more rows
#> # ℹ 4 more variables: .i_is_female_x_female <dbl>, .i_is_same_sex <dbl>,
#> #   .i_diff_female_x_female <dbl>, .i_diff_same_sex <dbl>
```

If you want to exclude some dyad compositions completely, filter them
before preparation. A dedicated composition-inclusion argument is
planned.
