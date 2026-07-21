# Example intensive longitudinal dyadic data with multiple dyad compositions and a Tweedie outcome

A simulated intensive longitudinal long-format dataset containing
distinguishable female-male dyads and exchangeable female-female and
male-male dyads with a semi-continuous physical activity outcome. Each
dyad contributes one row per member and measurement occasion.

## Usage

``` r
example_dyadic_ILD_mixed_tweedie
```

## Format

A data frame with 5,600 rows and 6 variables:

- personID:

  Unique person identifier.

- coupleID:

  Dyad identifier.

- diaryday:

  Measurement day.

- gender:

  Gender role, with levels `female` and `male`.

- physical_activity:

  Simulated Tweedie-like physical activity outcome, with some missing
  values.

- provided_support:

  Simulated provided support score, with some missing values.

## Source

Adapted from <https://github.com/Pascal-Kueng/05DyadicDataAnalysis>. See
Küng, P. M. (2026). *Distinguishable and Exchangeable Dyads: Bayesian
Multilevel Modelling* (v2.0.9). Zenodo.
[doi:10.5281/zenodo.20720321](https://doi.org/10.5281/zenodo.20720321) .

## Details

Prepare with `dyad = coupleID`, `member = personID`, `role = gender`,
and `time = diaryday`.
