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

The v0.0.1 function takes a fitted model, discovers all supported
shared/difference residual-block pairs, and returns their member-level
covariance structures.

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

The public function supports fitted `glmmTMB` models containing at least one
valid scalar shared/difference pair. It should support:

- a single exchangeable composition;
- exchangeable DIMs and exchangeable APIMs;
- multiple exchangeable compositions in one mixed-composition APIM;
- pooled exchangeable compositions;
- the same composition at multiple grouping levels, such as stable
  `coupleID` and same-occasion `coupleID:diaryday` blocks;
- models that also contain distinguishable-composition covariance blocks,
  which are left unchanged and omitted from the result.

Mixed-composition support is part of the intended v0.0.1 public contract, but
implementation and validation should proceed from one pair to many pairs.

### Deliberate v0.0.1 restrictions

The first version supports one scalar coefficient in each shared and difference
block. It does not support:

- random-slope covariance matrices;
- a shared and difference term placed in the same correlated block;
- DSM `+0.5/-0.5` score transformations;
- uncertainty intervals for `glmmTMB` transformations;
- automatically renamed `interdep`-generated columns;
- arbitrary user-created contrast columns that merely resemble `.i_diff_*`;
- `brmsfit` objects;
- transforming ordinary model dispersion or unrelated residual structures.

Unsupported structures should produce specific errors rather than partial or
guessed results.

## Source of structural information

The fitted model is authoritative: the helper must transform what was actually
fitted, not what the original preparation metadata suggests was intended.

Do not require the original named data object to remain in the calling
environment. Saved and reloaded models should continue to work. In particular:

- `glmmTMB` does not retain `attr(data, "interdep")` on `model$frame`;
- package metadata therefore cannot be the primary discovery mechanism;
- recovering the original data would make the helper fragile across sessions.

Use these sources for distinct purposes:

1. `stats::formula(model, component = "cond")` supplies the fitted conditional
   formula.
2. `reformulas` parses the random-effect terms and their covariance wrappers.
3. Canonical `.i_is_*` and `.i_diff_*` names identify semantic candidates.
4. `model$frame` validates the observed support of proposed pairs on the rows
   actually used for fitting.
5. `glmmTMB::VarCorr(model)$cond` supplies fitted covariance estimates.

Do not build the parser directly around undocumented
`model$modelInfo$reTrms` internals. Engine-specific internals may be used only
behind a small, well-tested adapter if no public alternative can establish a
necessary mapping.

## Parsing random-effect terms

Add `reformulas` to `Suggests` beside `glmmTMB`, declare its direct use, and
check it with `requireNamespace()` in the model-facing function.

Parse the fitted formula rather than `model$call$formula`:

```r
formula <- stats::formula(model, component = "cond")
parts <- reformulas::splitForm(formula)
```

`reformulas::findbars_x()` may be used where the complete structured expression
is useful. Unlike ordinary `findbars()`, it retains or normalizes covariance
wrappers such as `us()`.

Normalize each random-effect term to one internal record containing at least:

- its index in the fitted formula;
- covariance-structure class;
- coefficient expression and expanded coefficient names;
- grouping expression;
- candidate composition;
- candidate role: `shared`, `difference`, or `other`;
- the corresponding `VarCorr()` block.

Do not use the `.1`, `.2`, and similar suffixes that `VarCorr()` adds to repeated
group names as semantic composition identifiers. Align parsed terms with
covariance blocks by fitted term order, then verify the grouping expression and
coefficient names before extracting an estimate.

## Automatic discovery and matching

### Difference candidates

A v0.0.1 difference block must contain exactly one unmodified canonical column
matching

```text
.i_diff_{composition}_arbitrary
```

The `{composition}` substring becomes the composition key.

### Shared candidates

For a composition-specific or mixed-composition model, the corresponding shared
block contains exactly

```text
.i_is_{composition}
```

For a single-composition DIM or APIM, an intercept-only random-effect block may
serve as the shared block.

Call this the *shared block* even when its model term is an intercept.

### Pairing rules

A difference and shared block form a valid pair only when all applicable rules
hold:

1. They occur in the same model component.
2. They have the same grouping expression.
3. Their canonical composition keys agree, unless the shared term is the
   permitted single-composition intercept.
4. They are separate random-effect terms, and are therefore fitted as
   independent blocks.
5. Each block has exactly one coefficient in v0.0.1.
6. On `model$frame`, the support agrees:

   ```r
   abs(difference_column) == shared_indicator
   ```

   for a composition indicator.
7. An intercept may match only when there is one exchangeable composition on
   all fitted rows and `abs(difference_column) == 1` throughout.

Grouping expressions are part of the pair key. Thus the same composition may
produce separate results for `coupleID` and `coupleID:diaryday`.

Every discovered `.i_diff_*` block must match exactly one shared block. Stop on
zero or multiple candidates; never silently drop or guess an ambiguous block.
If the model contains no supported `.i_diff_*` block, explain that no
exchangeable shared/difference residual structure was found.

### Renaming policy

Users may freely name their original variables, grouping variables, outcomes,
and predictors. Automatic discovery requires the `interdep`-generated
`.i_is_*` and `.i_diff_*` columns to retain their generated names.

Arbitrary renaming is not safely inferable from the fitted formula alone. A
future explicit escape hatch may accept user-supplied pairs, for example:

```r
pairs = list(
  list(shared = "my_shared", difference = "my_difference")
)
```

This is not part of v0.0.1.

## Model and estimate validation

Before transformation, validate that:

- `model` inherits from `glmmTMB`;
- the required optional packages are installed;
- the optimizer reports convergence;
- the Hessian is positive definite when that information is available;
- the conditional random-effect formula can be parsed;
- every difference block has one unambiguous shared partner;
- all paired terms are scalar and structurally supported;
- the fitted covariance blocks are finite, symmetric, and positive
  semidefinite within numerical tolerance;
- the resulting member covariance matrix is finite, symmetric, and positive
  semidefinite within numerical tolerance.

Boundary variance estimates are valid mathematical inputs and should not be
rejected solely for being zero. If needed, warn that interpretation may be
unstable rather than preventing the transformation.

## Return value

Return one row per matched `composition × grouping expression` pair. A tibble is
the simplest initial public value. It should contain at least:

- `composition`;
- `grouping`;
- `shared_term`;
- `difference_term`;
- `shared_variance`;
- `difference_variance`;
- `member_1_variance`;
- `member_2_variance`;
- `member_covariance`;
- `member_correlation`;
- `member_1_sd`;
- `member_2_sd`;
- `covariance_matrix`, as a list-column containing the named $2 \times 2$
  matrix.

Use the labels `member_1` and `member_2`, never female/male labels, because the
exchangeable members' `+1/-1` assignment is arbitrary. Give rows a deterministic
order based on fitted term order, with grouping and composition retained
explicitly rather than encoded only in row names.

The returned covariance matrix should be named:

```text
         member_1  member_2
member_1
member_2
```

A custom print class is optional and should be added only if the raw tibble is
not sufficiently clear.

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
2. A `reformulas`-based parser returning normalized random-term records.
3. A matcher operating only on normalized records and fitted-frame columns.
4. A `glmmTMB` covariance adapter.
5. The exported orchestration function.

This separation allows later engines to reuse the parser, matcher, mathematics,
and output while replacing only formula access and covariance extraction.

## Implementation sequence

Implement and test in this order:

1. Pure scalar and matrix back-transformation.
2. Normalized parsing of `glmmTMB` random-effect terms with `reformulas`.
3. Discovery, validation, and transformation of one pair.
4. Generalize the internal representation to a list of pairs.
5. Add mixed compositions and repeated grouping levels.
6. Connect the public result to the vignette diagrams where practical.
7. Export and document only after the multi-pair return structure is stable.

The implementation should internally use a list of pairs even when only one
pair exists. This avoids redesigning the public function when mixed-composition
support is added.

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
- Repeated grouping-factor names in `VarCorr()` with synthetic `.1` suffixes.
- Formula terms appearing in a different valid order.

### Failure tests

- No `.i_diff_*` block.
- Unmatched `.i_diff_*` block.
- Multiple possible shared matches.
- Shared and difference columns with inconsistent row support.
- Renamed generated columns.
- Random slopes or multi-coefficient blocks.
- Shared and difference coefficients placed in one correlated block.
- Unsupported model class.
- Non-converged model or non-positive-definite Hessian.
- Non-finite or invalid covariance estimates.

Use small fitted models and `skip_if_not_installed("glmmTMB")` for
engine-facing tests. Test the pure mathematical layer without optional model
engines.

## Future `brms` adapter

Ordinary `brms` group-level terms share the basic bar syntax, so the common
`reformulas` parser and matcher should remain usable. The engine boundary is
nevertheless real:

- a `brmsfit` stores a `brmsformula`, potentially containing multiple response,
  distributional, or nonlinear formulas;
- bare `(terms | group)` syntax is usual, with additional ID and `gr()` forms;
- covariance estimates are posterior distributions, not one fitted matrix;
- any required transformation must be applied draw by draw before posterior
  summaries and intervals are calculated.

A future adapter should obtain the relevant formula from `model$formula`, use
`brms::brmsterms()` when necessary, and extract raw covariance draws with
`brms::VarCorr(model, summary = FALSE)`.

Some `brms` ILD specifications estimate the desired member-level residual
covariance directly. Those structures are already on the target scale and must
not be sent through the shared/difference back-transformation. Supporting them
means recognizing and returning or explaining the direct parameterization, not
transforming it again.

Do not add `brms` support to v0.0.1 merely because its simplest formulas can be
parsed. Add it when there is a concrete model whose extracted covariance needs
this transformation and can be validated draw by draw.

## Documentation requirements

The function documentation and vignette should:

- explain the shared/elevator and difference/seesaw intuition briefly;
- show the expanded scalar equations, not only matrix notation;
- state that member 1 and member 2 are arbitrary labels;
- show one single-composition example;
- show one mixed or stable/same-occasion example;
- distinguish covariance, correlation, and the computational
  shared/difference variances;
- explain why generated-column renaming is unsupported;
- state the scalar-block and `glmmTMB` limits prominently.
