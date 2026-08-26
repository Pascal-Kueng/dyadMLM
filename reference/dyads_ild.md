# Example Gaussian intensive longitudinal dyadic data

A simulated long-format dataset containing distinguishable female-male
dyads and exchangeable female-female and male-male dyads. Each dyad has
two members observed on 14 diary days.

## Usage

``` r
dyads_ild
```

## Format

A data frame with 10,080 rows and 6 variables:

- personID:

  Unique person identifier.

- coupleID:

  Dyad identifier.

- diaryday:

  Measurement day, from 0 through 13.

- gender:

  Gender role, with levels `female` and `male`.

- closeness:

  Simulated Gaussian closeness outcome.

- provided_support:

  Simulated provided-support score.

## Source

Simulated for `dyadMLM`; design adapted from
<https://github.com/Pascal-Kueng/05DyadicDataAnalysis>. See Küng, P. M.
(2026). *Distinguishable and Exchangeable Dyads: Bayesian Multilevel
Modelling*. Zenodo.
[doi:10.5281/zenodo.17400655](https://doi.org/10.5281/zenodo.17400655) .

## Details

The Gaussian outcome includes independent member-specific stationary
AR(1) residual components. Their marginal standard deviation is 0.60 for
both genders, with lag-1 correlations within these components of 0.55
for female members and 0.50 for male members. Separate shared and
difference residuals induce same-occasion partner covariance.

Prepare with `dyad = coupleID`, `member = personID`, `role = gender`,
and `time = diaryday`. These data contain three compositions. Use
`keep_compositions` in
[`prepare_dyad_data()`](https://pascal-kueng.github.io/dyadMLM/reference/prepare_dyad_data.md)
when an analysis should retain only selected compositions; omit it when
all supplied compositions should remain.
