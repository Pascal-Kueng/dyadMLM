# Extract exchangeable residual blocks from a fitted model

Extracts the fitted random-effect structure and covariance parameters
needed to identify exchangeable shared/difference residual-block pairs.
Model-engine specific information is normalized to a common
representation.

## Usage

``` r
extract_exchangeable_residual_blocks(model)
```

## Arguments

- model:

  A fitted model. Supported classes are `glmmTMB` and `brmsfit`.

## Value

A normalized internal representation containing the model engine,
extracted random-effect blocks, matched shared/difference block pairs,
and their fitted covariance parameters.

## Details

Shared and `.i_diff_*` blocks are matched by dyad composition and
grouping factor. This permits more than one exchangeable composition and
more than one grouping level, such as separate stable dyad and
same-occasion residual structures.

For `glmmTMB` models, the function uses the normalized random-effect
structures stored in `model$modelInfo` together with the fitted
covariance estimates. For `brmsfit` models, it uses the stored
group-level term structure and raw posterior covariance draws.
Distributional and nonlinear `brms` random-effect terms are ignored.
