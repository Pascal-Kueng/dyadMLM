# Example Gaussian cross-sectional dyadic data

A simulated long-format dataset containing distinguishable female-male
dyads and exchangeable female-female and male-male dyads. Each dyad has
two members and each member has one row. `closeness` and
`provided_support` are the member's averages across the 14 observations
in
[dyads_ild](https://pascal-kueng.github.io/dyadMLM/reference/dyads_ild.md).

## Usage

``` r
dyads_cross
```

## Format

A data frame with 720 rows and 6 variables:

- personID:

  Unique person identifier.

- coupleID:

  Dyad identifier.

- gender:

  Gender role, with levels `female` and `male`.

- dyad_composition:

  Observed dyad composition, with levels `female_x_male`,
  `female_x_female`, and `male_x_male`.

- closeness:

  Mean simulated Gaussian closeness score across 14 days.

- provided_support:

  Mean simulated provided-support score across 14 days.

## Source

Simulated for `dyadMLM`; design adapted from
<https://github.com/Pascal-Kueng/05DyadicDataAnalysis>. See Küng, P. M.
(2026). *Distinguishable and Exchangeable Dyads: Bayesian Multilevel
Modelling* (v2.0.9). Zenodo.
[doi:10.5281/zenodo.20720321](https://doi.org/10.5281/zenodo.20720321) .

## Details

Prepare with `dyad = coupleID`, `member = personID`, and
`role = gender`. These data contain three compositions. Use
`keep_compositions` in
[`prepare_dyad_data()`](https://pascal-kueng.github.io/dyadMLM/reference/prepare_dyad_data.md)
when an analysis should retain only selected compositions; omit it when
all supplied compositions should remain.
