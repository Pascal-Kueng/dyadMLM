# Recover member-level residual covariance from the shared/difference parameterization of exchangeable APIMs and DIMs

Back-transforms exchangeable shared/difference residual-block pairs from
a fitted model to member-level residual variances, covariance, standard
deviations, and correlation.

## Usage

``` r
exchangeable_rescov(model)
```

## Arguments

- model:

  A fitted `glmmTMB` or `brmsfit` model.

## Value

A named list with one element per matched shared/difference block pair.
Each element contains the member-level variance-covariance matrix in
`varcov` and its standard-deviation/correlation representation in
`sdcor`. Element names reproduce the two matched random-effect terms.

## Details

The function identifies shared and difference residual blocks, matches
them by dyad composition and grouping factor, and back-transforms each
matched pair to the covariance structure of two arbitrarily labelled
members. It supports multiple exchangeable compositions and grouping
levels in the same model. The fitted model is not refitted or modified.

In Gaussian `brms` models, cross-sectional and same-occasion partner
residual dependence is usually represented directly with
`unstr(time = member, gr = pair_id)`. Use `sigma ~ 1` for equal residual
standard deviations in exchangeable dyads and `sigma ~ 0 + role` for
role-specific standard deviations in distinguishable dyads.
Shared/difference group-level blocks remain relevant for stable dyad
effects in intensive longitudinal data and are back-transformed by this
function.
