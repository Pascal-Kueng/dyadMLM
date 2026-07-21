# Example intensive longitudinal dyadic data

A simulated intensive longitudinal long-format dataset for
distinguishable dyads. Each dyad contributes one row per member and
measurement occasion.

## Usage

``` r
example_dyadic_ILD
```

## Format

A data frame with 1,120 rows and 6 variables:

- personID:

  Unique person identifier.

- coupleID:

  Dyad identifier.

- diaryday:

  Measurement day.

- gender:

  Gender role, with levels `female` and `male`.

- closeness:

  Simulated closeness outcome, with some missing values.

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
