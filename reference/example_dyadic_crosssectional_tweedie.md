# Example cross-sectional dyadic data with a Tweedie outcome

A simulated cross-sectional long-format dataset for distinguishable
dyads with a semi-continuous physical activity outcome. Each dyad
contributes one row per member.

## Usage

``` r
example_dyadic_crosssectional_tweedie
```

## Format

A data frame with 240 rows and 5 variables:

- personID:

  Unique person identifier.

- coupleID:

  Dyad identifier.

- gender:

  Gender role, with levels `female` and `male`.

- motivation:

  Simulated motivation predictor, with some missing values.

- physical_activity:

  Simulated Tweedie-like physical activity outcome, with some missing
  values.

## Source

Adapted from <https://github.com/Pascal-Kueng/05DyadicDataAnalysis>. See
Küng, P. M. (2026). *Distinguishable and Exchangeable Dyads: Bayesian
Multilevel Modelling* (v2.0.9). Zenodo.
[doi:10.5281/zenodo.20720321](https://doi.org/10.5281/zenodo.20720321) .

## Details

Prepare with `dyad = coupleID`, `member = personID`, and
`role = gender`.
