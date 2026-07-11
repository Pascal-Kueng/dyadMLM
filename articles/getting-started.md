# Getting Started

``` r

library(interdep)
has_glmmTMB <- requireNamespace("glmmTMB", quietly = TRUE)
```

`interdep` helps researchers prepare cross-sectional and intensive
longitudinal dyadic data for multilevel models, including generalized
multilevel models. It supports common dyadic studies with one kind of
dyad, and it also handles studies where different kinds of dyads appear
in the same dataset, such as female-male, female-female, and male-male
couples. It creates composition-aware, model-ready columns for dyadic
multilevel model parameterizations such as APIM, DIM, and undirected
DSM. Current DIM and undirected DSM helpers require one exchangeable
dyad composition.

This vignette focuses mainly on APIM-style actor and partner effects in
multilevel model formulas, especially models with multiple dyad types,
intensive longitudinal data, and generalized outcomes. For more detailed
APIM model formulas, see the [Actor-Partner Interdependence Model
vignette](https://pascal-kueng.github.io/interdep/articles/apim.md). For
the Dyad-Individual Model (DIM) parameterization, including dyad-mean
and within-dyad-deviation predictors and their equivalence to APIM
effects in exchangeable dyads, see the [Dyad-Individual Model
vignette](https://pascal-kueng.github.io/interdep/articles/dim.md). For
undirected dyadic score outcomes, see the [Undirected Dyadic Score Model
vignette](https://pascal-kueng.github.io/interdep/articles/undirected-dsm.md).

The basic data structure is a long data frame where dyads are stacked on
top of each other and both members of a dyad appear as separate rows.
For cross-sectional data, each complete dyad contributes one row per
member. For intensive longitudinal data, each observed member-occasion
has at most one row. Dyads must contain two unique members overall, but
member-occasion rows may be absent.

The expected structure is:

- cross-sectional: one row per `dyad x member`

| dyad | member |   x |   y |
|-----:|-------:|----:|----:|
|    1 |      1 | 4.2 | 7.1 |
|    1 |      2 | 5.0 | 6.4 |
|    2 |      1 | 3.8 | 5.9 |
|    2 |      2 | 4.5 | 6.8 |

- intensive longitudinal: at most one row per `dyad x time x member`

| dyad | time | member |   x |   y |
|-----:|-----:|-------:|----:|----:|
|    1 |    1 |      1 | 4.2 | 7.1 |
|    1 |    1 |      2 | 5.0 | 6.4 |
|    1 |    2 |      1 | 4.0 | 6.9 |
|    1 |    2 |      2 | 5.3 | 6.6 |

Measured variables may contain missing values. The structural `group`,
`member`, and optional `time` variables must be complete. Missing or
incomplete role and dyad information can be handled with the function
arguments `missing_role` and `incomplete_dyads`.

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

*Note* that the row for person 1 at time 2 is absent. The time variable
still uses the observed measurement occasions and skips from time 1 to
time 3 for that person, which is fine.

[`prepare_interdep_data()`](https://pascal-kueng.github.io/interdep/reference/prepare_interdep_data.md)
validates the expected structure, returns a tibble with class
`interdep_data`, and adds the dyad-composition labels and model-ready
columns needed for dyadic multilevel model formulas.

Omit `role` only when all partners should be treated as exchangeable.

The examples build up from simple dyadic structures to composition-aware
models:

- distinguishable dyads, where member roles are modeled separately;
- exchangeable dyads, where arbitrary member labels are handled with
  sum-diff columns;
- semi-continuous and intensive longitudinal outcomes;
- mixed-composition dyadic MLMs that combine distinguishable and
  exchangeable dyads in one model, illustrated in the [mixed-composition
  cross-sectional](#mixed-cross-sectional-gaussian-model) and
  [mixed-composition intensive
  longitudinal](#mixed-intensive-longitudinal-gaussian-model) examples.

## Cross-sectional dyadic data

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
  example_dyadic_crosssectional,
  group = coupleID,
  member = personID,
  role = gender,
  
  # if we specify a predictor and a model type, we get transformed variables. 
  # here, .i_communication_raw_actor and .i_communication_raw_partner
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

The generated `.i_*` columns can be used directly in model formulas.

### Distinguishable Gaussian APIM

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

### Exchangeable Gaussian APIM

We can treat **all dyads** as the same type of exchangeable dyads by
simply omitting the `role` argument. The prepared data contains a
composition indicator and a sum-diff contrast for the assumed
exchangeable dyads.

``` r

cross_exchangeable_data <- prepare_interdep_data(
  example_dyadic_crosssectional,
  group = coupleID,
  member = personID,
  predictors = communication,
  model_type = "apim",
  seed = 123
)

print(cross_exchangeable_data)
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
#> #   .i_*_raw_actor       APIM actor predictor: actor's original predictor
#> #                        values
#> #   .i_*_raw_partner     APIM partner predictor: partner's original predictor
#> #                        values
#> #
#> # A tibble: 190 × 11
#>    personID coupleID gender communication satisfaction .i_composition      
#>       <int>    <int> <fct>          <dbl>        <dbl> <fct>               
#>  1        1        1 female          4.79         4.37 assumed_exchangeable
#>  2        2        1 male            3.80         2.34 assumed_exchangeable
#>  3        3        2 female          2.91         2.44 assumed_exchangeable
#>  4        4        2 male            6.51         6.08 assumed_exchangeable
#>  5        5        3 female          5.70         5.87 assumed_exchangeable
#>  6        6        3 male            8.22         9.66 assumed_exchangeable
#>  7        7        4 female          5.28         6.50 assumed_exchangeable
#>  8        8        4 male            4.89         3.08 assumed_exchangeable
#>  9        9        5 female          6.01         7.41 assumed_exchangeable
#> 10       10        5 male            4.32         1.47 assumed_exchangeable
#> # ℹ 180 more rows
#> # ℹ 5 more variables: .i_composition_role <fct>,
#> #   .i_is_assumed_exchangeable <dbl>, .i_diff_assumed_exchangeable <dbl>,
#> #   .i_communication_raw_actor <dbl>, .i_communication_raw_partner <dbl>
```

``` r


cross_exchangeable_diff_model <- glmmTMB(
  satisfaction ~ 
    # pooled intercept 
    1 + 
    
    # pooled actor slope for communication
    .i_communication_raw_actor +
    
    # pooled partner slope for communication
    .i_communication_raw_partner +
    
    # exchangeable residual covariance via sum-diff
    us(1 | coupleID) + 
    us(0 + .i_diff_assumed_exchangeable | coupleID)
    
  , dispformula = ~ 0
  , family = gaussian()
  , data = cross_exchangeable_data
)

summary(cross_exchangeable_diff_model)
```

Helper functions to rotate these structures back to partner-level
interpretations are planned for v.0.0.1.500

## Incomplete dyads and missing roles

By default,
[`prepare_interdep_data()`](https://pascal-kueng.github.io/interdep/reference/prepare_interdep_data.md)
stops when a dyad has only one observed member or when a member’s role
cannot be resolved from the observed rows. These cases can also be
dropped before validation continues.

The package example datasets are kept structurally complete, so this
section uses a small artificial example instead. With `"drop"`, dyads
with incomplete structure or unresolved role information are removed as
whole dyads. The printed header records which dyads were removed.

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

### Distinguishable ILD APIM

``` r

ild_distinguishable_data <- prepare_interdep_data(
  example_dyadic_ILD,
  group = coupleID,
  member = personID,
  role = gender,
  time = diaryday,
  predictors = provided_support,
  seed = 123
)

print(ild_distinguishable_data)
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
#>       <int>    <int>    <int> <chr>      <dbl>            <dbl> <fct>         
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
`temporal_predictor_decomposition` argument. Usually for ILD, the
`time_2l` option is the correct one.

Example of an exchangeable ILD APIM. Note that *instead of omitting the
role variable here*, we use a different method and set the dyad-type
explicitly to exchangeable.

``` r

ild_exchangeable_data <- prepare_interdep_data(
  example_dyadic_ILD,
  group = coupleID,
  member = personID,
  role = gender,
  set_exchangeable_compositions = c('male-female'), 
  time = diaryday,
  predictors = provided_support,
  seed = 123
)

print(ild_exchangeable_data)
#> # interdep data
#> # Rows: 1120 | Dyads: 40 | Intensive longitudinal: yes
#> # Structure: group = coupleID, member = personID, role = gender, time =
#> # diaryday
#> #
#> # Dyad compositions:
#> # female_x_male exchangeable (set by user) 40 dyads
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
#> # A tibble: 1,120 × 16
#>    personID coupleID diaryday gender closeness provided_support .i_composition
#>       <int>    <int>    <int> <chr>      <dbl>            <dbl> <fct>         
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
#> # ℹ 9 more variables: .i_composition_role <fct>, .i_is_female_x_male <dbl>,
#> #   .i_diff_female_x_male <dbl>, .i_provided_support_cwp <dbl>,
#> #   .i_provided_support_cbp <dbl>, .i_provided_support_cwp_actor <dbl>,
#> #   .i_provided_support_cwp_partner <dbl>, .i_provided_support_cbp_actor <dbl>,
#> #   .i_provided_support_cbp_partner <dbl>
```

Note that whenever you need to refer to a dyad-type, the order of
members does not matter (e.g., ‘male-female’ and ‘female-male’ will both
work), and you can use different separators like ‘male_female’,
‘male_x_female’ or even ‘male female’.

``` r


ild_exchangeable_model <- glmmTMB(
  closeness ~ 
    1 + 
    
    diaryday +

    # Pooled within-person actor and partner effects
    .i_provided_support_cwp_actor +
    .i_provided_support_cwp_partner +

    # Pooled between-person actor and partner effects
    .i_provided_support_cbp_actor +
    .i_provided_support_cbp_partner +

    # random effects for stable non-independence (means)
    us(1 | coupleID)  + us(0 + .i_diff_female_x_male | coupleID) +

    # Same-day residual covariance
    us(1 | coupleID:diaryday) + us(0 + .i_diff_female_x_male  | coupleID:diaryday)

  , dispformula = ~ 0
  , family = gaussian()
  , data = ild_exchangeable_data
)

summary(ild_exchangeable_model)
```

## Mixed-composition dyads

`example_dyadic_crosssectional_mixed` contains three dyad compositions
in the same data object: distinguishable female-male dyads and
exchangeable female-female and male-male dyads.

Here, we focus on the preparation steps that are possible with
`interdep`. For model formulas that combine distinguishable and
exchangeable dyads in the same analysis, see the [Actor-Partner
Interdependence Model
vignette](https://pascal-kueng.github.io/interdep/articles/apim.md).

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

However, sometimes for theoretical or practical reasons, we may want to
pool different exchangeable dyads and analyze them as if they were one.
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
pool female-male with male-male, you could treat female-male as
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
