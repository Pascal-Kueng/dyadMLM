# Recover member-level residual covariance from exchangeable random-effect blocks

Back-transforms covariance matrices from paired shared and
member-difference random-effect blocks to the covariance structure of
two exchangeable members. The result is on the fitted random effects'
linear-predictor scale. In non-Gaussian models, it therefore describes a
Gaussian latent covariance, not response-scale residual covariance. For
the model specification, derivation, and interpretation, see the
[exchangeable APIM
vignette](https://pascal-kueng.github.io/dyadMLM/articles/apim.html#exchangeable-residual-structure).

## Usage

``` r
recover_exchangeable_covariance(model, block_pairings = NULL)
```

## Arguments

- model:

  A fitted `glmmTMB` or single-response `brmsfit` model. For `glmmTMB`,
  only conditional-model random effects are processed.

- block_pairings:

  `NULL` (default) for automatic block matching. Otherwise, supply one
  block-pair specification or a list of block-pair specifications. Each
  pair contains:

  - `shared_block`: a single string naming the shared random-effect term
    copied from the fitted model formula or an equivalent selector (see
    Details), or `NULL` if the entire shared block was omitted when
    fitting;

  - `difference_block`: a single string naming the member-difference
    random-effect term or an equivalent selector, or `NULL` if the
    entire difference block was omitted;

  - `difference_indicator`: the exact name of the difference-indicator
    column used in `difference_block`. It is required when
    `difference_block` selects a block and optional when
    `difference_block = NULL`;

  - `shared_indicator`: the exact shared composition-indicator column,
    needed only for composition-specific blocks in mixed-dyad models. It
    defaults to `"1"`, meaning that every fitted row belongs to the pair
    and an ordinary intercept is the shared intercept coordinate.

## Value

An `exchangeable_rescov` object: a named list with one element per
matched block pairing. Each element contains `shared_term` and
`difference_term` (each a fitted term string or `NULL`), plus the
member-level variance-covariance matrix in `varcov` and its
standard-deviation/correlation representation in `sdcor`, with standard
deviations on the diagonal and correlations off the diagonal. Covariance
dimension labels `member_1` and `member_2` denote arbitrary exchangeable
positions, not substantive roles or encodings. Caller-supplied outer
names are preserved; unnamed pairings receive stable names `pair_1`,
`pair_2`, and so on in resolved order. For `glmmTMB`, `varcov` and
`sdcor` are matrices. For `brms`, they are posterior-draw by coefficient
by coefficient arrays.

## Details

Automatic matching recognizes exact `.dy_member_contrast_*_arbitrary`
and legacy `.dy_diff_*_arbitrary` coefficient names and first looks for
the corresponding `.dy_is_*` shared block. It requires the two blocks to
use the same grouping factor and the same underlying terms. Most models
fitted with `dyadMLM`-generated columns therefore need only:

    result <- dyadMLM::recover_exchangeable_covariance(model)
    print(result)

Supply `block_pairings` when automatic matching is ambiguous or when a
model uses custom indicators, multiple covariance levels, or
deliberately omitted blocks or terms. To specify one pair with a custom
difference indicator:

    result <- dyadMLM::recover_exchangeable_covariance(
      model,
      block_pairings = list(
        shared_block = "(1 + time | coupleID)",
        difference_block = "(0 + my_diff + I(my_diff * time) | coupleID)",
        difference_indicator = "my_diff"
      )
    )

For multiple covariance levels, wrap the pairings in an outer list. For
example, in a Gaussian `glmmTMB` model fitted with `dispformula = ~ 0`,
this call recovers both a stable dyad-level covariance with an omitted
difference time slope and the same-occasion partner residual covariance:

    result <- dyadMLM::recover_exchangeable_covariance(
      model,
      block_pairings = list(
        dyad = list(
          shared_block = "(1 + diaryday | coupleID)",
          difference_block = "(0 + .dy_member_contrast_assumed_exchangeable_arbitrary | coupleID)",
          difference_indicator =
            ".dy_member_contrast_assumed_exchangeable_arbitrary"
        ),
        same_occasion = list(
          shared_block = "(1 | coupleID:diaryday)",
          difference_block = "(0 + .dy_member_contrast_assumed_exchangeable_arbitrary | coupleID:diaryday)",
          difference_indicator =
            ".dy_member_contrast_assumed_exchangeable_arbitrary"
        )
      )
    )

At the dyad level, the fitted model includes a shared time slope but no
difference time slope. Thus, the two members' time random effects are
identical at this level, with correlation `+1` whenever the shared slope
variance is non-zero; at zero variance, the correlation is undefined.
Covariances involving the diary-day slope are therefore supplied
entirely by the shared block.

The random-effect terms may be copied exactly from the model formula.
Equivalent backend syntax is also recognized, such as
`(1 + time | group)` and `us(1 + time | group)`, or `(0 + x || group)`
and `diag(0 + x | group)`. A custom difference-indicator name is
supplied literally. Difference slopes may be written in either
interaction order or as a simple product inside
[`I()`](https://rdrr.io/r/base/AsIs.html).

When a difference block is supplied and the fitted model frame retains
the indicator columns, `difference_indicator` must assign `-1` and `+1`
to the two arbitrary member positions consistently within each dyad. For
composition-specific blocks, it must be zero where `shared_indicator` is
zero.

For custom difference indicators supplied through `block_pairings`, the
function checks whether both positions occur within each supported
fitted grouping unit. It rejects coding when no group contains both
positions, and warns when only some groups are one-sided, which can
result from fitted-row filtering. It also warns when stable member
assignments cannot be verified across repeated rows without a member
identifier.

## What omitted blocks and terms mean

`recover_exchangeable_covariance()` only describes constraints that were
already imposed when the model was fitted. It does not remove a block,
set a variance to zero, or otherwise constrain the supplied model.
Describe only the structure that was actually fitted.

If a term occurs in only one selected block, the function represents the
missing coordinate as a structural zero:

- A term present only in the shared block has no difference component,
  so the two members have identical random effects for that term.

- A term present only in the difference block has no shared component,
  so the two members have equal-magnitude, opposite-sign random effects
  for that term.

Setting `difference_block = NULL` or `shared_block = NULL` applies the
corresponding rule to the entire omitted block. This is valid only when
that block is truly absent from the fitted model. Do not use `NULL`
merely to ignore an existing block; the resulting back-transformation
would be incorrect.

See the constrained-block example in the [exchangeable APIM
vignette](https://pascal-kueng.github.io/dyadMLM/articles/apim.html#fitted-constraints-and-omitted-blocks).

## Backend note

For `glmmTMB`, random effects in non-conditional components are ignored
with a warning. See the vignette's [extension to exchangeable random
slopes](https://pascal-kueng.github.io/dyadMLM/articles/apim.html#exchangeable-random-slope-back-transformation)
section for the manual calculation.

In `brms`, cross-sectional and same-occasion partner dependence can be
represented directly with
`unstr(time = member_position, gr = residual_group)`. With Gaussian
outcomes, `sigma ~ 1` supplies the common residual scale. Non-Gaussian
families have no `sigma` parameter here; `unstr()` instead estimates a
common latent residual scale and correlation on the linear-predictor
scale. Here, `member_position` identifies the same two arbitrary
positions within every group, and `residual_group` identifies dyads in
cross-sectional data or dyad-occasions in longitudinal data. This direct
specification applies when one covariance structure is sufficient.
Separate composition-specific `unstr()` structures for mixed dyad types
are not currently supported in a standard single-response `brms` model.
For Gaussian mixed-dyad residual covariance, use `glmmTMB`.
Shared/difference blocks remain relevant for higher-level random effects
and can represent latent link-scale covariance in non-Gaussian models.

## See also

The [exchangeable APIM
vignette](https://pascal-kueng.github.io/dyadMLM/articles/apim.html#exchangeable-residual-structure)
for the model specification, covariance derivation, and
constrained-block example. Run
[`vignette("apim", package = "dyadMLM")`](https://pascal-kueng.github.io/dyadMLM/articles/apim.md)
to open the installed version.

## Examples

``` r
if (requireNamespace("glmmTMB", quietly = TRUE)) {
  example_data <- prepare_dyad_data(
    dyads_cross,
    dyad = coupleID,
    member = personID,
    role = gender,
    model_types = "none",
    # All three observed compositions in `dyads_cross` are detected and retained
    # by default. This example focuses on `female-female` dyads, so we restrict
    # the analysis here.
    keep_compositions = "female-female",
    seed = 123
  )

  model <- glmmTMB::glmmTMB(
    closeness ~ 1 +
      us(1 | coupleID) +
      us(0 + .dy_member_contrast_female_x_female_arbitrary | coupleID),
    dispformula = ~ 0,
    data = example_data
  )

  recover_exchangeable_covariance(model)
}
#> Exchangeable residual covariance
#> 
#> Pair `pair_1`
#> Shared:     us(1 | coupleID)
#> Difference: us(0 + .dy_member_contrast_female_x_female_arbitrary | coupleID)
#> 
#> Variance-covariance:
#>                        1     2    
#> 1 member1: (Intercept) 2.217 1.366
#> 2 member2: (Intercept) 1.366 2.217
#> 
#> Standard deviations and correlations:
#>                        1     2    
#> 1 member1: (Intercept) 1.489 0.616
#> 2 member2: (Intercept) 0.616 1.489
```
