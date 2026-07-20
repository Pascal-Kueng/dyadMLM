# Back-transforming Exchangeable Residual Covariances

## Status

This is the implementation specification for the first public covariance
back-transformation helper in `interdep`. It records the decisions made for
v0.0.1 and the intended path to later model engines and more complex covariance
structures.

Public function name:

```r
exchangeable_rescov(model)
```

Extraction, matching, structural-zero alignment, and the numerical
back-transformation are implemented for `glmmTMB` and single-response
`brmsfit` models. `exchangeable_rescov()` returns one named member-level
covariance result per matched shared/difference block pair.

## Purpose

Exchangeable DIMs and APIMs represent the two members' residuals through two
independent random-effect blocks:

- a **shared residual block**, which moves both members in the same direction;
- a **difference residual block**, identified by an `interdep` `.i_diff_*`
  column, which moves them in opposite directions.

The fitted variances of these blocks are useful computationally but are not the
usual member-level residual variance and covariance. The helper converts every
valid fitted shared/difference pair back to:

- the residual variance of member 1;
- the residual variance of member 2;
- the covariance between the members' residuals;
- the corresponding residual correlation and standard deviations.

The function does not refit the model or alter its data.

Use **shared residual block**, not *mean block*, in the API and documentation.
The latter is easily confused with a dyad-mean predictor. Use
**back-transformation**, not *rotation*, because the unnormalised `+1/-1`
transformation is not a pure orthonormal rotation.

## Mathematical definition

For a supported scalar pair, let $u_{S,j}$ be the shared residual and
$u_{D,j}$ the difference residual for dyad $j$. The arbitrary member labels
are defined by

$$
u_{1j} = u_{S,j} + u_{D,j},
\qquad
u_{2j} = u_{S,j} - u_{D,j}.
$$

The standard exchangeable parameterization fits the shared and difference
blocks separately, so

$$
\boldsymbol{\Sigma}_{SD}
=
\begin{bmatrix}
\sigma_S^2 & 0 \\
0 & \sigma_D^2
\end{bmatrix}.
$$

With

$$
\mathbf{T}
=
\begin{bmatrix}
1 & 1 \\
1 & -1
\end{bmatrix},
$$

the member-level covariance matrix is

$$
\boldsymbol{\Sigma}_{12}
=
\mathbf{T}
\boldsymbol{\Sigma}_{SD}
\mathbf{T}^{\mathsf T}
=
\begin{bmatrix}
\sigma_S^2 + \sigma_D^2 & \sigma_S^2 - \sigma_D^2 \\
\sigma_S^2 - \sigma_D^2 & \sigma_S^2 + \sigma_D^2
\end{bmatrix}.
$$

Therefore,

$$
\operatorname{Var}(u_1)
=
\operatorname{Var}(u_2)
=
\sigma_S^2 + \sigma_D^2,
$$

$$
\operatorname{Cov}(u_1,u_2)
=
\sigma_S^2 - \sigma_D^2,
$$

and

$$
\rho_{12}
=
\frac{\sigma_S^2 - \sigma_D^2}
{\sigma_S^2 + \sigma_D^2}.
$$

The internal mathematical helper should implement the general matrix operation

```r
Sigma_member <- T %*% Sigma_score %*% t(T)
```

independently of any model engine. The model-facing code is responsible only
for discovering blocks and extracting `Sigma_score`.

## Public scope for v0.0.1

The function supports fitted `glmmTMB` and single-response `brmsfit` models
containing one or more shared/difference random-effect pairs. The common block
representation already supports:

- one or multiple exchangeable compositions;
- the same composition at several grouping levels;
- random intercepts and random slopes;
- correlated (`|`/`us`) and uncorrelated (`||`/`diag`/`homdiag`) blocks;
- posterior covariance draws for `brms` and point estimates for `glmmTMB`;
- unrelated or distinguishable-composition blocks, which are left alone;
- explicit partial pairs and wholly omitted components, represented by
  structural zeros.

### Deliberate v0.0.1 restrictions

The first version does not support:

- a shared and difference coordinate placed in the same correlated block;
- multivariate `brms` models;
- separate composition-specific `unstr()` structures for mixed dyad types in a
  standard single-response `brms` model;
- linked multi-term `brms` blocks, `gr(..., by = ...)` blocks, or random
  effects for distributional/nonlinear parameters;
- DSM `+0.5/-0.5` score transformations;
- uncertainty intervals for `glmmTMB` transformations;
- transforming ordinary dispersion or `brms`
  `unstr(time = member, gr = pair_id)` residual structures that are already on
  the member scale.

Automatic matching requires untouched `interdep` `.i_diff_*` names and complete,
unambiguous pairs. Exact supplied pairs support custom indicator names and
constrained structures.

## Source of structural information

The fitted model is authoritative: the helper must transform what was actually
fitted, not what the original preparation metadata suggests was intended.

Do not require the original named data object to remain in the calling
environment. Saved and reloaded models should continue to work. In particular:

- neither backend retains unused original data columns in its model frame;
- `glmmTMB` does not retain `attr(data, "interdep")` on `model$frame`;
- package metadata therefore cannot be the primary discovery mechanism;
- recovering the original data would make the helper fragile across sessions.

Two small backend adapters normalize the information already stored by each
model:

1. The `glmmTMB` adapter aligns
   `model$modelInfo$reTrms$cond`,
   `model$modelInfo$reStruc$condReStruc`, and
   `glmmTMB::VarCorr(model)$cond`.
2. The `brms` adapter aligns `model$ranef` with raw draws from
   `brms::VarCorr(model, summary = FALSE)`. It keeps stored coefficient names
   for draw lookup and restores readable formula names separately.
3. Both return `group`, `coefficients`, `correlated`, `term`, and an
   `estimate/draw x coefficients x coefficients` covariance array.
4. `stats::model.frame(model)` validates indicator coding on fitted rows when
   the raw columns remain available.

The engine-specific internals stay confined to these tested adapters. From that
point onward, matching and transformation are backend-independent.

## Parsing random-effect terms

No `reformulas` dependency is needed for the current implementation. The
backend adapters already expose normalized fitted blocks, and exact supplied
selectors are resolved by a small canonicalizer:

- bare `(1 + time | group)` is equivalent to `us(1 + time | group)`;
- bare `(0 + x || group)` is equivalent to `diag(0 + x | group)`;
- `homdiag` remains distinct;
- coefficient and interaction order do not affect selection;
- simple literal products are canonicalized without evaluating them.

Coefficient interpretation is separate from block selection. A narrow
expression-tree parser recognizes `idiff`, `idiff:time`, `time:idiff`,
`I(idiff * time)`, and `I(time * idiff)`. It rejects more complex arithmetic
rather than guessing.

## Automatic discovery and matching

### Difference candidates

Automatic matching starts from a canonical column matching

```text
.i_diff_{composition}_arbitrary
```

The `{composition}` substring becomes the composition key. Every coefficient in
that block must contain the same indicator, either alone or in one supported
interaction.

### Shared candidates

For a composition-specific or mixed-composition model, the corresponding shared
block contains exactly

```text
.i_is_{composition}
```

For a single exchangeable composition, a generic intercept-and-slope block may
serve as the shared block.

Call this the *shared block* even when its model term is an intercept.

### Pairing rules

A difference and shared block form a valid pair only when all applicable rules
hold:

1. They have the same grouping expression.
2. Their canonical composition keys agree, unless the shared term is the
   permitted single-composition intercept.
3. They are separate random-effect terms, and are therefore fitted as
   independent blocks.
4. After removing the shared/difference indicator, their term sets are
   identical. Formula order may differ.
5. On `model$frame`, the support agrees when both raw columns are retained:

   ```r
   abs(difference_column) == shared_indicator
   ```

   for a composition indicator.
6. A generic shared block may match only when there is one exchangeable
   composition, and `abs(difference_column) == 1` throughout its fitted rows.

Grouping expressions are part of the pair key. Thus the same composition may
produce separate results for `coupleID` and `coupleID:diaryday`.

Every discovered `.i_diff_*` block must match exactly one shared block. Stop on
zero or multiple candidates; never silently drop or guess an ambiguous block.
If the model contains no supported `.i_diff_*` block, explain that no
exchangeable shared/difference residual structure was found.

### Renaming policy

Users may freely name their original variables, grouping variables, outcomes,
and predictors. Automatic discovery requires the `interdep`-generated
`.i_is_*` and `.i_diff_*` columns to retain their generated names. Explicit
matching also supports user-created indicator names because the user declares
their meaning:

```r
pairs = list(
  shared = "(1 + time | coupleID)",
  difference = "(0 + IDIFF + I(IDIFF * time) || coupleID)",
  difference_indicator = "IDIFF"
)
```

Here `shared_indicator = "1"` is implied: an ordinary random intercept is the
shared coordinate. A composition-specific block instead supplies its indicator,
for example `shared_indicator = "SAMESEX"`. The term strings select fitted
blocks; the two indicators define how their coefficients map to common
intercept and slope terms.

`difference_indicator` is required when `difference` selects a fitted block.
When `difference = NULL`, it may be omitted because no difference coordinate
needs to be parsed or validated. Supplying it remains useful for checking
whether a compatible difference block was fitted despite the claimed omission.

Automatic matching accepts only identical term sets. Exact supplied pairs may
have terms on only one side; missing positions are stored as `NA` term indices
and later padded with zeros. Setting `shared = NULL` or `difference = NULL` is
reserved for a whole block that was absent from the fitted formula. Unlisted
blocks are otherwise ignored. The function warns whenever a whole block is set
to `NULL`. This reports a constraint already imposed by the fitted model; the
back-transformation does not impose it. An omitted difference block means that
both members have identical random effects for those terms, whereas an omitted
shared block means that they have equal-magnitude, opposite-sign random effects.

## Model and estimate validation

The implemented extraction and matching layer validates:

- a supported `glmmTMB` or single-response `brmsfit` model;
- backend block/covariance alignment;
- supported `brms` random-effect structures;
- one unambiguous shared block per automatically discovered difference block;
- exact block selection, grouping-factor agreement, and non-reuse for supplied
  pairs;
- valid indicators in every selected coefficient;
- unnormalised `-1/+1` contrast coding and composition support whenever those
  columns remain in the fitted model frame.

The numerical layer validates matching dimensions, finite values, symmetric
component covariance arrays, and nonnegative transformed variances. Positive
semidefiniteness follows from transforming the two positive-semidefinite fitted
component matrices and is protected by mathematical tests rather than an
eigendecomposition of every `brms` draw. Optimizer and Hessian diagnostics
remain part of the separate diagnostics workflow.

Boundary variance estimates are valid mathematical inputs and should not be
rejected solely for being zero. If needed, warn that interpretation may be
unstable rather than preventing the transformation.

## Return value

Return a named list with one element per matched block pair. The element name
reproduces the recognizable shared and difference terms so users can connect
the result to their formula. Use an explicit `<omitted>` label for an absent
side.

Each element contains:

- `varcov`: the member-level variance-covariance representation;
- `sdcor`: the same result represented by standard deviations and
  correlations.

For `glmmTMB`, both fields are point-estimate matrices. For `brms`, both are
posterior-draw by coefficient by coefficient arrays. The transformation is
applied to every posterior draw; raw draw-wise transformations must not be
replaced by transforming posterior means.

The print method shows both representations by default. Users can request one
with `print(x, what = "varcov")` or `print(x, what = "sdcor")`. For `brms`, it
reports the retained draw-array dimensions rather than dumping every posterior
matrix; posterior summaries remain a separate future concern.

Use arbitrary `member_1`/`member_2` labels, never female/male labels. With
random slopes, names must also retain the underlying coefficient term.

## Architecture

Keep formula discovery, estimate extraction, and mathematics separate:

```text
fitted model
  -> engine-specific formula and covariance adapter
  -> common normalized random-term table
  -> common shared/difference matcher
  -> common matrix back-transformation
  -> common result formatter
```

Suggested internal layers:

1. A pure matrix helper that knows nothing about model classes.
2. Thin `glmmTMB` and `brms` adapters returning the same block records.
3. A matcher operating only on normalized records and fitted-frame columns.
4. A common covariance-array aligner that inserts structural zeros according to
   each pair's term-order vectors.
5. A common result formatter and exported orchestration function.

This separation allows later engines to reuse the parser, matcher, mathematics,
and output while replacing only formula access and covariance extraction.

## Implementation sequence

The v0.0.1 numerical path is implemented: normalized extraction, automatic and
supplied matching, mixed compositions and grouping levels, partial and omitted
components, structural-zero alignment, draw-wise back-transformation,
`varcov`/`sdcor` construction, deterministic names, and boundary tests. The
remaining work is release-facing example and vignette polish; posterior summary
and print methods can be considered later without changing the draw-wise
result.

## Test specification

### Mathematical tests

- With $\sigma_S^2 = 1.2$ and $\sigma_D^2 = 0.3$, obtain member variances
  `1.5`, member covariance `0.9`, and member correlation `0.6`.
- Equal shared and difference variances produce zero member covariance.
- A larger shared variance produces positive member correlation.
- A larger difference variance produces negative member correlation.
- Zero shared or difference variance is handled as a valid boundary case.
- The matrix is symmetric and positive semidefinite.
- Reversing the arbitrary sign of `.i_diff_*` leaves the covariance result
  unchanged.
- Forward and inverse transformations round-trip within numerical tolerance.

### Discovery and extraction tests

- Single-composition model with an intercept shared block.
- Single-composition model with a `.i_is_*` shared block.
- Mixed model with two exchangeable compositions.
- Mixed model containing both distinguishable and exchangeable blocks.
- Pooled composition with a generated pool name.
- One composition at both stable and same-occasion grouping levels.
- Missing outcome rows, ensuring support validation uses fitted rows.
- Formula terms appearing in a different valid order.
- Correlated and uncorrelated random slopes in both backends.
- Exact formula selectors across normalized `us`/`diag` syntax.
- Partial term sets and wholly omitted blocks.
- `idiff:time` and narrow literal `I(idiff * time)` products in both backends.

### Failure tests

- No `.i_diff_*` block.
- Unmatched `.i_diff_*` block.
- Multiple possible shared matches.
- Shared and difference columns with inconsistent row support.
- Renamed generated columns.
- Shared and difference coefficients placed in one correlated block.
- Unsupported model class.
- Unsupported linked, multivariate, distributional, or `gr(..., by = ...)`
  `brms` structures.
- Invalid exact selectors, cross-group pairs, reused blocks, or false `NULL`
  declarations.
- Unsupported arithmetic involving the difference indicator.
- Non-finite or invalid covariance estimates.

Use small fitted models and `skip_if_not_installed()` for engine-facing tests.
Test the pure mathematical layer without optional model engines.

## `brms` behavior

The `brms` adapter is implemented. Its engine boundary remains important:

- a `brmsfit` stores a `brmsformula`, potentially containing multiple response,
  distributional, or nonlinear formulas;
- bare `(terms | group)` syntax is usual, with additional ID and `gr()` forms;
- covariance estimates are posterior distributions, not one fitted matrix;
- the transformation must be applied draw by draw before posterior summaries
  and intervals are calculated.

Some `brms` ILD specifications estimate the desired member-level residual
covariance directly. Those structures are already on the target scale and must
not be sent through the shared/difference back-transformation. Supporting them
means recognizing and returning or explaining the direct parameterization, not
transforming it again.

Both adapters now retain one grouping-level ID per fitted row. When every
grouping unit has at most two fitted observations, the public function warns
that the structure may represent residual-level dependence. This deliberately
uses only row counts—not `idiff` or member-position checks—so the warning stays
cautious. It highlights `brms` shared/difference effects, omitted components,
and non-intercept terms.

Distributional and nonlinear random effects are ignored with a warning.
Multivariate models, linked multi-term blocks, and `gr(..., by = ...)` remain
explicitly unsupported.

## Documentation requirements

The function documentation and vignette should:

- explain the shared/elevator and difference/seesaw intuition briefly;
- show the expanded scalar equations, not only matrix notation;
- state that member 1 and member 2 are arbitrary labels;
- show one single-composition example;
- show one mixed or stable/same-occasion example;
- distinguish covariance, correlation, and the computational
  shared/difference variances;
- explain automatic generated-name matching versus exact supplied pairs;
- show partial terms, structural-zero padding, and one wholly omitted block;
- document supported `I(idiff * time)` products and coding-validation limits;
- distinguish transformed group-level blocks from `brms` residual structures
  that are already on the member scale.
