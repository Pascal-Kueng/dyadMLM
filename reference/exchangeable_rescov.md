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

  `NULL` (default) for automatic block matching, one named block pair,
  or an outer list of named block pairs. A pair has these fields:

  - `shared`: the exact shared random-effect term from the fitted model
    formula, or `NULL` if the entire shared block was omitted when
    fitting;

  - `difference`: the exact difference random-effect term, or `NULL` if
    the entire difference block was omitted when fitting;

  - `difference_indicator`: the exact name of the difference-indicator
    column used in `difference`, regardless of what the column is
    called. If `difference = NULL`, name the column that defines (or
    would define) the opposite signs for this pair in the original data;

  - `shared_indicator`: optionally, the exact shared
    composition-indicator column. It defaults to `"1"`, meaning that an
    ordinary random intercept is the shared block and every fitted row
    belongs to this pair.

  At least one of `shared` and `difference` must name a fitted block.
  See Details for examples and the meaning of `NULL`.

## Value

A named list with one element per matched block pair. Each element
contains the member-level variance-covariance matrix in `varcov` and its
standard-deviation/correlation representation in `sdcor`. Names
reproduce the matched random-effect terms.

## Details

Automatic matching recognizes exact `.i_diff_*_arbitrary` coefficient
names and first looks for the corresponding `.i_is_*` shared block. It
remains deliberately conservative: the two blocks must use the same
grouping factor and contain the same underlying terms. Supply `pairs`
for custom indicator names, ambiguous matches, or models that
deliberately omit blocks or terms.

Here “shared” and “difference” describe random-effect coordinates. If
`u_shared` moves both members together and `u_difference` moves them in
opposite directions, the member effects are
`u1 = u_shared + u_difference` and `u2 = u_shared - u_difference`. These
coordinates are distinct from dyad-mean and within-dyad member-deviation
predictor columns, even though both use the same mean/difference logic.

The selected shared and difference coordinates must be separate
random-effect blocks, so their covariance is fixed to zero by the fitted
model. On the member scale, that constraint produces equal member
variances while still allowing a nonzero covariance between members.
This is the exchangeable actor-partner covariance structure that the
function recovers; the function does not assume that the members' random
effects are independent.

A custom difference-indicator name is supplied literally. For example,
if the model used a `-1/+1` column named `hallelujah`:

    pairs = list(
      shared = "(1 + time | coupleID)",
      difference =
        "(0 + hallelujah + I(hallelujah * time) || coupleID)",
      difference_indicator = "hallelujah"
    )

A composition-specific pair also names its shared indicator:

    pairs = list(
      shared = "(0 + SAMESEX + SAMESEX:time | coupleID)",
      difference =
        "(0 + IDIFF_SAMESEX + IDIFF_SAMESEX:time | coupleID)",
      difference_indicator = "IDIFF_SAMESEX",
      shared_indicator = "SAMESEX"
    )

For multiple pairs, wrap the pair specifications in an outer list.
Naming the outer elements makes later errors easier to locate:

    pairs = list(
      stable = list(
        shared = "(1 | coupleID)",
        difference = "(0 + hallelujah | coupleID)",
        difference_indicator = "hallelujah"
      ),
      occasion = list(
        shared = "(1 | coupleID:time)",
        difference = "(0 + hallelujah | coupleID:time)",
        difference_indicator = "hallelujah"
      )
    )

Model-style equivalents are recognized across backends, such as
`(1 + time | group)` and `us(1 + time | group)`, or `(0 + x || group)`
and `diag(0 + x | group)`. Difference slopes may be written as
`hallelujah:time`, `time:hallelujah`, `I(hallelujah * time)`, or
`I(time * hallelujah)`. More complex arithmetic inside
[`I()`](https://rdrr.io/r/base/AsIs.html) is not interpreted.

When the fitted model frame retains the indicator columns,
`difference_indicator` must use unnormalised `-1/+1` coding where
`shared_indicator` is one and must be zero elsewhere. A column omitted
entirely from the fitted formula cannot be recovered from either
supported backend, so its coding cannot be checked.

## What omitted blocks and terms mean

`exchangeable_rescov()` only describes constraints that were already
imposed when the model was fitted. It does not remove a block, set a
variance to zero, or otherwise constrain the supplied model.

If a term occurs in only one selected block, the function represents the
missing coordinate as a structural zero:

- A term present only in `shared` has no difference component, so the
  two members have identical random effects for that term.

- A term present only in `difference` has no shared component, so the
  two members have equal-magnitude, opposite-sign random effects for
  that term.

Setting `difference = NULL` or `shared = NULL` makes the corresponding
rule apply to every term in the other block. `NULL` therefore means that
the whole block was absent from the fitted model; it must never be used
merely to ignore an existing block. The function warns whenever `NULL`
is supplied and errors if it can identify a compatible fitted block that
contradicts the claimed omission.

## Backend note

In Gaussian `brms` models, cross-sectional and same-occasion partner
residual dependence is usually represented directly with
`unstr(time = member, gr = pair_id)`. The blocks handled here remain
relevant for higher-level shared and difference random effects.
