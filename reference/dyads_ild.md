# Example Gaussian intensive longitudinal dyadic data

A simulated long-format dataset containing distinguishable female-male
dyads and exchangeable female-female and male-male dyads. Each dyad has
two members observed on 14 diary days.

## Usage

``` r
dyads_ild
```

## Format

A data frame with 10,080 rows and 7 variables:

- personID:

  Unique person identifier.

- coupleID:

  Dyad identifier.

- diaryday:

  Measurement day, from 0 through 13.

- gender:

  Gender role, with levels `female` and `male`.

- dyad_composition:

  Observed dyad composition, with levels `female_x_male`,
  `female_x_female`, and `male_x_male`.

- closeness:

  Simulated Gaussian closeness outcome.

- provided_support:

  Simulated provided-support score.

## Source

Simulated for `dyadMLM`; design adapted from
<https://github.com/Pascal-Kueng/05DyadicDataAnalysis>. See Küng, P. M.
(2026). *Distinguishable and Exchangeable Dyads: Bayesian Multilevel
Modelling* (v2.0.9). Zenodo.
[doi:10.5281/zenodo.20720321](https://doi.org/10.5281/zenodo.20720321) .

## Details

Prepare with `dyad = coupleID`, `member = personID`, `role = gender`,
and `time = diaryday`. These data contain three compositions. Use
`keep_compositions` in
[`prepare_dyad_data()`](https://pascal-kueng.github.io/dyadMLM/reference/prepare_dyad_data.md)
when an analysis should retain only selected compositions; omit it when
all supplied compositions should remain.
