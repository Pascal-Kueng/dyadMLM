# Directional Dyadic Score Model

## Purpose

This document records how the directional Dyadic Score Model (DSM) described
by Iida et al. (2017) can be represented in `interdep`'s long, one-row-per-member
data structure. It also distinguishes that model from the package's current
Dyad-Individual Model (DIM), explains why the current "undirected DSM" is a
reduced DIM-equivalent model, and proposes a package implementation.

The relevant source is:

> Iida, M., Seidman, G., Shrout, P. E., Fujita, K., & Bolger, N. (2017).
> Models of interdependent individuals versus dyadic processes in relationship
> research. *Journal of Social and Personal Relationships, 35*(1), 59-88.

The paper is stored in
`dev/iida-et-al-2017-models-of-interdependent-individuals-versus-dyadic-processes-in-relationship-research.pdf`.

## What Iida's DSM estimates

Iida's DSM is directional and therefore requires distinguishable partners. Let
members 1 and 2 have predictor values `X1` and `X2` and outcome values `Y1` and
`Y2`. Define the level and full signed difference scores as

```text
XLevel = (X1 + X2) / 2
XDiff  = X1 - X2

YLevel = (Y1 + Y2) / 2
YDiff  = Y1 - Y2
```

The direction of every difference must be defined substantively and used
consistently. For example, if role 1 is `female` and role 2 is `male`, all
differences are `female - male`. Positive `XDiff` then means that the female
partner has the higher predictor value, and positive `YDiff` means that the
female partner has the higher outcome value.

Iida's full DSM (their Model 7) is

```text
YLevel = a10 + a11 * XLevel + a12 * XDiff + rYL
YDiff  = a20 + a21 * XLevel + a22 * XDiff + rYD
```

The six regression parameters have the following meanings:

| Parameter | Meaning |
|---|---|
| `a10` | Expected outcome level when both predictor scores are zero |
| `a11` | Predictor level -> outcome level |
| `a12` | Predictor difference -> outcome level |
| `a20` | Expected outcome difference when both predictor scores are zero |
| `a21` | Predictor level -> outcome difference |
| `a22` | Predictor difference -> outcome difference |

The `a12` and `a21` coefficients are the cross-paths. Omitting them gives the
reduced DSM used in Iida's Model 8. The residuals `rYL` and `rYD` may covary;
that covariance indicates that unexplained outcome level and unexplained
outcome difference are associated.

Iida's `Diff` variables are full member-1-minus-member-2 differences. They are
not the member-specific deviations from the dyad mean currently generated for
the DIM.

## Exact representation in long format

The full DSM does not require changing the package's primary data structure to
one row per dyad. It can be written exactly using the original member-level
outcome and a signed role contrast.

Define

```text
C1 = +0.5
C2 = -0.5
```

where the positive role is the first role in the declared difference order.
The member outcomes can then be reconstructed from the dyad scores:

```text
Y1 = YLevel + 0.5 * YDiff
Y2 = YLevel - 0.5 * YDiff
```

or, for either member `i`,

```text
Yi = YLevel + Ci * YDiff
```

Substituting the two DSM equations gives

```text
Yi = a10
   + a11 * XLevel
   + a12 * XDiff
   + Ci * a20
   + Ci * a21 * XLevel
   + Ci * a22 * XDiff
   + rYL
   + Ci * rYD
```

Consequently, the fixed-effects part of the exact long-format model is

```r
outcome ~
  1 +
  x_level +
  x_difference +
  role_contrast +
  x_level:role_contrast +
  x_difference:role_contrast
```

The coefficients map directly to Iida's parameters:

| Long-format term | DSM parameter |
|---|---|
| `(Intercept)` | `a10` |
| `x_level` | `a11`: level -> level |
| `x_difference` | `a12`: difference -> level |
| `role_contrast` | `a20`: outcome-difference intercept |
| `x_level:role_contrast` | `a21`: level -> difference |
| `x_difference:role_contrast` | `a22`: difference -> difference |

The role contrast is separate from `XDiff`: `XDiff` contains the substantive
partner difference, while the contrast reconstructs each member's outcome
from `YLevel` and `YDiff`. With `+0.5/-0.5`, a role-related coefficient equals
the full `Y1 - Y2` contrast used by Iida. With `+1/-1`, the same predictions
are obtained after rescaling, but the fitted coefficient is half the full
outcome-difference parameter.

### Where the cross-paths come from

The predictor-difference main effect is constant across both member rows. It
therefore shifts their expected outcomes equally and estimates
`XDiff -> YLevel` (`a12`).

The `XLevel * role_contrast` interaction changes sign between the two member
rows. It therefore changes their expected difference without changing their
mean and estimates `XLevel -> YDiff` (`a21`).

The `XDiff * role_contrast` interaction estimates `XDiff -> YDiff` (`a22`).
The existing row-specific DIM deviation is algebraically this product:

```text
Xi - XLevel = Ci * XDiff
```

Thus the existing DIM includes the level-to-level and difference-to-difference
paths, but not the two cross-paths. Its within-dyad coefficient can equivalently
be read as the change in a member's outcome deviation per unit of their
predictor deviation, or as the change in the full outcome difference per unit
of the full predictor difference.

## Residual covariance in the long model

For cross-sectional data, the two DSM residuals can be represented by a
correlated random intercept and random role-contrast slope:

```r
(1 + role_contrast | dyad_id)
```

The random intercept is `rYL`, the random slope is `rYD`, and their covariance
is the residual covariance between outcome level and outcome difference.
For member `i`, the residual is

```text
r_i = rYL + Ci * rYD
```

This produces

```text
Var(Y1 residual) = Var(rYL) + 0.25 * Var(rYD) + Cov(rYL, rYD)
Var(Y2 residual) = Var(rYL) + 0.25 * Var(rYD) - Cov(rYL, rYD)
Cov(Y1, Y2)      = Var(rYL) - 0.25 * Var(rYD)
```

These three DSM covariance parameters span the three unique elements of an
unstructured two-member outcome covariance matrix.

There must not also be a freely estimated member-level Gaussian residual
variance in the cross-sectional model. It would add a fourth covariance
parameter to a covariance matrix with only three unique elements and would not
generally be separately identifiable. With `glmmTMB`, the intended model is
therefore approximately

```r
glmmTMB::glmmTMB(
  outcome ~
    1 +
    x_level +
    x_difference +
    role_contrast +
    x_level:role_contrast +
    x_difference:role_contrast +
    (1 + role_contrast | dyad_id),
  dispformula = ~0,
  family = gaussian(),
  data = prepared
)
```

`glmmTMB` implements `dispformula = ~0` using a very small fixed dispersion,
not a mathematically literal zero. We should verify numerical equivalence to a
direct bivariate DSM in tests rather than assume that every optimizer and data
scale behaves identically.

Iida estimates the model as an SEM and also represents the covariance between
`XLevel` and `XDiff`. A conditional mixed model need not model the predictor
covariance to estimate the outcome regressions with fully observed, error-free
predictors. The approaches can differ when predictors are missing, measured
with error, or themselves treated as stochastic outcomes.

## Which variables must be generated

### Predictor scores

The package must generate a signed dyad-level predictor difference. For an
order `c("female", "male")`, for example:

```text
.i_communication_dyad_mean_gmc
.i_communication_dyad_difference
```

Both values must be repeated on both member rows of a dyad. The difference
column must contain `communication_female - communication_male` on both rows.
This constant column is necessary for the `XDiff -> YLevel` main effect.

The existing column

```text
.i_communication_within_dyad_deviation
```

is not a DSM difference score. It contains `Xi - XLevel`, so its two values are
`+XDiff/2` and `-XDiff/2` after adopting the same role orientation. It can
represent `role_contrast * x_difference`, but it cannot represent the
predictor-difference main effect.

### Outcome scores

A materialized signed outcome difference is not required to fit the exact long
model. The original outcome plus `role_contrast` implicitly represents both
`YLevel` and `YDiff` through an invertible linear transformation.

DSM preparation should therefore retain the original outcome unchanged and
should not require an `outcomes` argument. A future explicit multivariate or
SEM workflow would need a separate dyad-score preparation design rather than
adding unused outcome transformations to the MLM-focused API.

### Role contrast

The package needs a DSM-specific contrast such as

```text
.i_dsm_role_contrast
```

with `+0.5` for the first declared role and `-0.5` for the second. Existing
`.i_diff_{comp}` columns are not suitable: they are arbitrary contrasts for
exchangeable dyads and are currently zero for distinguishable dyads. DSM
direction must instead be stable and substantively interpretable. Their
different scaling is intentional: a `-1/+1` exchangeable contrast makes its
random slope a member deviation, or half-difference, whereas the DSM contrast
makes its random slope the full directional difference.

## Relation to the DIM and current undirected DSM

For an exchangeable Gaussian dyad, direction-specific terms cannot be
identified substantively because reversing arbitrary member labels reverses
the signed differences. Exchangeability therefore requires the following
constraints:

```text
a20 = 0   # no directional outcome-difference intercept
a12 = 0   # no predictor-difference -> outcome-level path
a21 = 0   # no predictor-level -> outcome-difference path
Cov(rYL, rYD) = 0
```

The remaining equations are

```text
YLevel = a10 + a11 * XLevel + rYL
YDiff  =             a22 * XDiff  + rYD
```

This is the reduced, label-invariant DSM and is algebraically the exchangeable
Gaussian DIM already implemented by the package. The current
`model_type = "undirected_dsm"` therefore does not add a distinct statistical
model. Its separately fitted mean/deviation examples also fail to represent
the complete joint likelihood and its covariance correctly.

The clean conceptual division is:

- `dim`: exchangeable member-level model, equivalently a reduced undirected DSM;
- `dsm`: Iida's full directional model for distinguishable partners.

## Why the preliminary separate models are problematic

Fitting the repeated `.i_*_dyad_mean` and
`.i_*_within_dyad_deviation` columns as two ordinary univariate mixed models is
not Iida's full DSM:

- the cross-paths are omitted;
- the residual covariance between outcome level and difference is omitted;
- repeating a dyad-level score on both rows can create pseudo-replication;
- within-dyad deviations are exact opposites, so some random-effect and
  near-zero-dispersion specifications are degenerate;
- a random intercept in the deviation model does not represent the signed
  difference residual correctly.

These structural degeneracies explain why a model may produce apparently
reasonable point estimates but `NaN`, nearly zero, or otherwise meaningless
standard errors and p-values without an explicit convergence warning. An
optimizer can report convergence to the boundary even when the likelihood
does not support conventional inference.

The preliminary separate-model examples in `vignettes/dsm.Rmd` should be
removed or clearly replaced when directional DSM support is implemented.

## Proposed package API

Because the package has no adoption constraints yet, replace the misleading
internal and public `undirected_dsm` model family rather than maintaining both
names:

```r
prepare_interdep_data(
  data,
  group = coupleID,
  member = personID,
  role = gender,
  predictors = communication,
  model_type = "dsm",
  dsm_role_order = c("female", "male")
)
```

`dsm_role_order` defines all differences as first role minus second role and
defines the role contrast as `+0.5` for the first role and `-0.5` for the
second. Requiring this argument initially is safer than silently using
alphabetical order or row order. If a default is later added, the resolved
order must be stored in metadata and printed prominently.

The initial DSM implementation should deliberately support a narrow, clear
case:

- `role` is required;
- exactly two stable roles are required;
- initially, require exactly one distinguishable dyad composition;
- exchangeable compositions are rejected for `model_type = "dsm"`;
- both roles must be present in every structurally complete dyad;
- each difference direction is recorded in `attr(data, "interdep")`;
- multiple predictors use the same declared role order.

Mixed compositions and multiple distinguishable compositions can be designed
later. Supporting them immediately would require composition-specific role
contrasts, reference directions, fixed effects, and covariance structures and
would obscure the core implementation.

## Proposed implementation steps

1. Replace `"undirected_dsm"` with `"dsm"` in argument validation, metadata,
   generated-column specifications, documentation, and tests.
2. Replace `validate_undirected_dyad_compatibility()` for the DSM path with a
   directional DSM validator that requires the declared two-role ordering.
3. Keep DIM validation and construction separate; DIM remains the supported
   exchangeable model.
4. Add and validate `dsm_role_order`. It must contain exactly the two observed
   roles in the supported composition, without duplicates or missing values.
5. Generate `.i_dsm_role_contrast` as `+0.5/-0.5` from the declared order.
6. Generate each predictor's dyad level and full signed dyad difference,
   repeating both on the two member rows.
7. Retain outcome variables unchanged; users select the outcome in the model
   formula.
8. Record source predictors, generated columns, score type, centering, and role
   order in the `interdep` metadata and generated-column registry.
9. Update `print.interdep_data()` so it states the resolved difference
   direction and describes the generated patterns without printing every
   predictor name.
10. Replace the preliminary DSM vignette models with the exact interaction
    formulation and coefficient interpretations.
11. Retain the DIM vignette's secondary reduced-DSM interpretation, while
    making clear that a full directional DSM additionally estimates both
    cross-paths, a directional intercept, and a level-difference residual
    covariance.

Likely generated-column patterns are:

```text
.i_dsm_role_contrast
.i_{pred}_dyad_mean_gmc
.i_{pred}_dyad_difference
.i_{out}_dyad_mean
.i_{out}_dyad_difference
```

The exact use of `_gmc` should continue to reflect actual centering. Signed
differences generally require no grand-mean centering because the common
location cancels, although optional centering of `XDiff` changes intercept
interpretation and could be considered separately.

## Testing plan

### Score construction

- Verify dyad means against hand-calculated values.
- Verify every signed difference is first declared role minus second declared
  role, independent of input row order.
- Verify the same mean and difference are repeated on both member rows.
- Verify the role contrast is `+0.5/-0.5` and stable over longitudinal rows.
- Verify missing member values produce missing score pairs.
- Verify character and factor role inputs resolve identically when the same
  explicit order is supplied.

### Validation

- Reject a missing `role` argument.
- Reject exchangeable dyads.
- Reject one-role or more-than-two-role DSM compositions.
- Reject a role order that is incomplete, duplicated, or inconsistent with
  observed roles.
- Reject mixed compositions in the initial implementation with an actionable
  message.

### Algebraic equivalence

- Simulate data from known `YLevel` and `YDiff` regressions.
- Reconstruct `Y1` and `Y2` using the `+0.5/-0.5` contrast.
- Fit the direct two-equation DSM and the long interaction model.
- Verify all six fixed coefficients agree within numerical tolerance.
- Verify the random intercept variance, random slope variance, and covariance
  recover the level variance, difference variance, and their covariance.
- Verify fitted member outcomes imply the fitted `YLevel` and `YDiff`.

### Direction reversal

Fit the same data after reversing `dsm_role_order`. Expected behavior:

- `XLevel` and `YLevel` do not change;
- `XDiff`, `YDiff`, and `role_contrast` all reverse sign;
- substantive fitted values do not change;
- parameters involving exactly one directional quantity change sign as
  dictated by the algebra;
- parameters involving two directional quantities, such as
  `XDiff -> YDiff`, retain their sign.

This test is important because it distinguishes harmless reparameterization
from accidental dependence on row order.

### Regression protection

- Verify DIM and APIM generated columns remain unchanged when DSM is not
  requested.
- Verify requesting APIM and DSM columns together does not overwrite shared
  source columns.
- Verify generated-column print patterns and metadata remain concise with
  multiple predictors.

## Explicit multivariate alternative

A direct multivariate Gaussian model can instead use one row per dyad:

```r
bf(y_level ~ 1 + x_level + x_difference) +
bf(y_difference ~ 1 + x_level + x_difference) +
set_rescor(TRUE)
```

This is especially natural in `brms`, where `set_rescor(TRUE)` estimates the
residual level-difference correlation directly. It requires one likelihood
contribution per dyad rather than two duplicated member rows. The package can
make all necessary score columns available in the primary long data, but a
user must select one row per dyad or use a future helper returning a dyad-score
view.

The long interaction formulation is preferable as the primary package path
because it remains model-ready while APIM and DIM columns coexist in the same
prepared member-level data. The explicit multivariate formulation should be
documented as an alternative, not used as a reason to change the package's
main data representation.

## Longitudinal extension

Iida's paper develops the cross-sectional DSM. A longitudinal DSM is an
extension and its assumptions must be documented as such.

At dyad `d` and occasion `t`, define

```text
XLevel_dt = (X1_dt + X2_dt) / 2
XDiff_dt  = X1_dt - X2_dt

YLevel_dt = (Y1_dt + Y2_dt) / 2
YDiff_dt  = Y1_dt - Y2_dt
```

The same identity holds at every occasion:

```text
Y_idt = YLevel_dt + C_i * YDiff_dt
```

Therefore, the same main effects and role interactions represent the four DSM
paths. A dyad-occasion random intercept and role slope can represent the joint
level/difference residual at each occasion:

```r
(1 + role_contrast | dyad_id:time)
```

Stable dyad-level heterogeneity could additionally be represented by

```r
(1 + role_contrast | dyad_id)
```

This initial formulation assumes that occasion-level residual pairs are
conditionally independent after the included effects. Serial correlation,
unequal spacing, trends, and lagged effects require further model design.

For the existing two-level temporal predictor decomposition, both level and
signed-difference DSM scores should be constructed separately for each
temporal component. Conceptually:

```text
CWP XLevel_dt = mean of the partners' within-person deviations at time t
CWP XDiff_dt  = role-1 within-person deviation minus role-2 deviation at time t

CBP XLevel_d  = mean of the partners' person means
CBP XDiff_d   = role-1 person mean minus role-2 person mean
```

Each component can have all four paths by including its level and difference
as main effects and interacting both with `role_contrast`. The resulting model
separates momentary and stable DSM processes, but this interpretation goes
beyond Iida's cross-sectional specification and needs its own derivation,
simulation tests, and vignette section.

For longitudinal score construction, `dyad_id:time` must identify a unique
paired occasion. The role orientation must remain stable across all occasions.

## Decisions to settle during implementation

1. Whether `dsm_role_order` is always required or may default to an explicitly
   printed factor-level order.
2. Whether the first implementation supports only cross-sectional data and
   adds longitudinal support in a second step.
3. Whether predictor level columns are grand-mean centered by default, and how
   that centering is described in DSM-specific output.
4. Whether `glmmTMB` is the documented primary engine for the exact long model
   and `brms` is documented primarily through the explicit multivariate form.
5. How missing paired outcomes should be handled by the long model.

The core mathematical decision is already settled: the full directional DSM
is representable without abandoning the long member-row structure, provided
the package supplies a stable `+0.5/-0.5` role contrast and a dyad-level signed
predictor difference. The member-level outcome remains the response in the
exact long interaction model.
