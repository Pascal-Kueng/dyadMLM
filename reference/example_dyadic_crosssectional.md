# Example cross-sectional dyadic data

A simulated cross-sectional long-format dataset for distinguishable
dyads. Each dyad contributes one row per member.

## Usage

``` r
example_dyadic_crosssectional
```

## Format

A data frame with 190 rows and 5 variables:

- personID:

  Unique person identifier.

- coupleID:

  Dyad identifier.

- gender:

  Gender role, with levels `female` and `male`.

- communication:

  Simulated communication score, with some missing values.

- satisfaction:

  Simulated satisfaction outcome, with some missing values.

## Source

Adapted from <https://github.com/Pascal-Kueng/05DyadicDataAnalysis>. See
Küng, P. M. (2026). *Distinguishable and Exchangeable Dyads: Bayesian
Multilevel Modelling* (v2.0.9). Zenodo.
[doi:10.5281/zenodo.20720321](https://doi.org/10.5281/zenodo.20720321) .

## Details

Prepare with `group = coupleID`, `member = personID`, and
`role = gender`.
