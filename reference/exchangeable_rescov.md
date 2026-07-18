# Recover member-level residual covariance from exchangeable random-effect blocks

Back-transforms paired shared and difference random-effect covariance
matrices to the covariance structure of two exchangeable members.

## Usage

``` r
exchangeable_rescov(model, pairs = NULL)
```

## Arguments

- model:

  A fitted `glmmTMB` or single-response `brmsfit` model.

- pairs:

  `NULL` for automatic matching, or one exact block pair (or an outer
  list of block pairs). Each pair must contain `shared`, `difference`,
  and `idiff`, and may contain `shared_indicator`. Copy `shared` and
  `difference` from the model formula. Either block may be `NULL` only
  when that entire block was omitted from the fitted model. `idiff` is
  the exact difference-indicator column name. `shared_indicator` is the
  exact composition indicator and defaults to `"1"`, meaning an ordinary
  random intercept.

## Value

A named list with one element per matched block pair. Each element
contains the member-level variance-covariance matrix in `varcov` and its
standard-deviation/correlation representation in `sdcor`. Names
reproduce the matched random-effect terms.

## Details

Automatic matching recognizes exact `.i_diff_*_arbitrary` coefficient
names and first looks for the corresponding `.i_is_*` shared block. It
remains deliberately conservative: the two blocks must use the same
grouping factor and contain the same underlying terms.

Use `pairs` when block matching is ambiguous, when custom indicator
names were used, or when terms were omitted to impose constraints. Terms
found in only one selected block are represented as structural zeros in
the other. `shared = NULL` or `difference = NULL` means that the whole
corresponding block was absent—not that an existing fitted block should
be ignored.

    pairs = list(
      shared = "(1 + time | coupleID)",
      difference = "(0 + IDIFF + I(IDIFF * time) || coupleID)",
      idiff = "IDIFF"
    )

A composition-specific pair also names its shared indicator:

    pairs = list(
      shared = "(0 + SAMESEX + SAMESEX:time | coupleID)",
      difference =
        "(0 + IDIFF_SAMESEX + IDIFF_SAMESEX:time | coupleID)",
      idiff = "IDIFF_SAMESEX",
      shared_indicator = "SAMESEX"
    )

Model-style equivalents are recognized across backends, such as
`(1 + time | group)` and `us(1 + time | group)`, or `(0 + x || group)`
and `diag(0 + x | group)`. Difference slopes may be written as
`IDIFF:time`, `time:IDIFF`, `I(IDIFF * time)`, or `I(time * IDIFF)`.
More complex arithmetic inside [`I()`](https://rdrr.io/r/base/AsIs.html)
is not interpreted.

Here “shared” and “difference” describe the random-effect coordinates:
one moves both members together and the other moves them in opposite
directions. They are distinct from dyad-mean and within-dyad
member-deviation predictor columns, even though both use the same
mean/difference logic.

When the fitted model frame retains the indicator columns, `idiff` must
use unnormalised `-1/+1` coding where `shared_indicator` is one and be
zero elsewhere. A column omitted entirely from the fitted formula cannot
be recovered from either supported backend, so its coding cannot be
checked.

In Gaussian `brms` models, cross-sectional and same-occasion partner
residual dependence is usually represented directly with
`unstr(time = member, gr = pair_id)`. The blocks handled here remain
relevant for higher-level shared and difference random effects.
