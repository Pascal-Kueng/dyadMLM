# Undirected Dyadic Score Model (DSM)

``` r

library(interdep)
```

This vignette focuses on undirected Dyadic Score Model (DSM)
preparation. For the main data requirements and validation workflow,
start with the [Getting Started
vignette](https://pascal-kueng.github.io/interdep/articles/getting-started.md).
For actor-partner predictor preparation, see the [Actor-Partner
Interdependence Model
vignette](https://pascal-kueng.github.io/interdep/articles/apim.md). For
APIMs that combine distinguishable and exchangeable dyad compositions,
see the [Mixed-Composition APIM
vignette](https://pascal-kueng.github.io/interdep/articles/mixed-apim.md).
For dyad-mean and within-dyad-deviation predictors, see the
[Dyad-Individual Model
vignette](https://pascal-kueng.github.io/interdep/articles/dim.md).

This vignette is under construction. It is included now so the
documentation site already reflects the intended structure; fuller DSM
preparation examples will be added before the alpha feedback round.

For the main data-preparation workflow, return to the [Getting Started
vignette](https://pascal-kueng.github.io/interdep/articles/getting-started.md).
For actor-partner models, see the [Actor-Partner Interdependence Model
vignette](https://pascal-kueng.github.io/interdep/articles/apim.md) and
the advanced [Mixed-Composition APIM
vignette](https://pascal-kueng.github.io/interdep/articles/mixed-apim.md).
For the DIM parameterization, see the [Dyad-Individual Model
vignette](https://pascal-kueng.github.io/interdep/articles/dim.md).

For an in-depth tutorial covering data preparation, model fitting,
diagnostics, and assumption checks, see [Distinguishable and
Exchangeable Dyads: Bayesian Multilevel
Modelling](https://pascal-kueng.github.io/05DyadicDataAnalysis/). It
uses `interdep` for cross-sectional and intensive longitudinal APIM and
DIM workflows, with models fitted primarily using `brms`
([source](https://github.com/Pascal-Kueng/05DyadicDataAnalysis),
[DOI](https://doi.org/10.5281/zenodo.17400655)).
