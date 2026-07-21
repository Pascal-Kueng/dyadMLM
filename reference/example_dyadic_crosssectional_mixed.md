# Example cross-sectional dyadic data with multiple dyad compositions

A simulated cross-sectional long-format dataset containing
distinguishable female-male dyads and exchangeable female-female and
male-male dyads. Each dyad contributes one row per member.

## Usage

``` r
example_dyadic_crosssectional_mixed
```

## Format

A data frame with 640 rows and 4 variables:

- personID:

  Unique person identifier.

- coupleID:

  Dyad identifier.

- gender:

  Gender role, with levels `female` and `male`.

- satisfaction:

  Simulated Gaussian satisfaction outcome.

## Source

Adapted from <https://github.com/Pascal-Kueng/05DyadicDataAnalysis>. See
Küng, P. M. (2026). *Distinguishable and Exchangeable Dyads: Bayesian
Multilevel Modelling* (v2.0.9). Zenodo.
[doi:10.5281/zenodo.20720321](https://doi.org/10.5281/zenodo.20720321) .

## Details

Prepare with `dyad = coupleID`, `member = personID`, and
`role = gender`.
