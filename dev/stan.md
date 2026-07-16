# Roadmap for Package-Quality Dyadic VAR-Style Models in Stan

**Status:** implementation roadmap  
**Target:** future inclusion in an R package for dyadic longitudinal models  
**Model class:** Gaussian two-person dyadic residual VAR(1) models  
**Last updated:** 2026-07-16

---

## 0. Executive summary

This document specifies a staged implementation plan for custom Stan models for two-person dyadic longitudinal data. The goal is to build a robust statistical and software foundation that can eventually be wrapped in an R package.

The target model family is a **Gaussian dyadic residual VAR(1)** model. It combines:

- a flexible mean model for repeated dyadic outcomes;
- dyad-level and member-level random effects;
- actor and partner temporal carryover through a residual VAR(1) process;
- same-day **innovation covariance** between partners;
- exchangeability constraints for indistinguishable dyads;
- role-specific dynamics for distinguishable dyads;
- eventually, mixed-composition models with several dyad types in one likelihood.

The recommended development order is:

1. Build simulators and validation tools.
2. Implement the exchangeable Gaussian balanced model.
3. Add predictors and random slopes for exchangeable dyads.
4. Implement the distinguishable Gaussian balanced model.
5. Build a transition-record data layer for ragged complete dyad-days and full dyad-day gaps.
6. Implement mixed-composition models with multiple dyad types but no partial pooling.
7. Add partial pooling across dyad types only after the separate-parameter mixed-composition model is validated.
8. Add one-partner missingness and DSEM-style extensions only after the core package is stable.

The central corrections and design choices are:

- Treat `rho` as an **innovation correlation**, not as the total marginal same-day residual correlation.
- Report marginal residual correlations separately as derived quantities.
- Treat the dyad-occasion and its two-member vector as the canonical dynamic unit, while retaining stacked member rows for flexible mean-model design matrices.
- Use the **orthonormal sum--difference transform** as an exact exchangeable Gaussian parameterization and computational specialization, not as a separate univariate model architecture.
- Treat any later non-Gaussian dynamic model as a new observation/state design decision, not as a mechanical family substitution.
- Enforce exchangeable label invariance in both the residual VAR and the random-effect structure.
- For exchangeable dyads, do **not** freely estimate covariance between shared and arbitrary difference random effects by default.
- Use stationary initial likelihoods for exchangeable models.
- Use regularizing priors plus posterior stationarity diagnostics for distinguishable models first; do not hard-constrain the free distinguishable VAR matrix in the first implementation.
- Design the R package around validated metadata, design matrices, Stan templates, and transition records rather than arbitrary pasted variable names.

This roadmap intentionally starts with a specialized and constrained model. It is not intended to become a fully general DSEM engine immediately. The first objective is a reliable, validated, Gaussian dyadic VAR residual model.

---

## 1. Purpose and scope

### 1.1 Purpose

The purpose of this roadmap is to define how to implement dyadic VAR-style residual models in Stan in a way that is statistically coherent, computationally stable, and eventually package-ready.

The package should cover combinations of residual dynamics, exchangeability constraints, mixed dyad compositions, and state or missingness handling that high-level interfaces such as `brms`, `glmmTMB`, `lme4`, and `nlme` do not currently express together cleanly:

- exchangeable or indistinguishable dyads, such as same-gender couples, friends, siblings, or same-role pairs;
- distinguishable dyads, such as female--male couples, mother--child dyads, therapist--client dyads, or patient--caregiver dyads;
- mixed-composition datasets containing several dyad types in one likelihood;
- actor inertia and partner carryover in a residual VAR(1) process;
- same-day innovation correlation between partners;
- role-specific or exchangeability-constrained random effects;
- metadata-driven Stan-code generation from an R package.

### 1.2 Intended model family

For dyad \(c\), member \(m \in \{1,2\}\), and time \(t\), the observed outcome is:

$$
y_{cmt} = \mu_{cmt} + r_{cmt}.
$$

The mean model \(\mu_{cmt}\) captures fixed effects, predictors, role differences, and hierarchical random effects. The residual vector is:

$$
\mathbf r_{ct}
=
\begin{pmatrix}
r_{c1t} \\
r_{c2t}
\end{pmatrix}.
$$

The dynamic model is:

$$
\mathbf r_{ct}
=
A_{g(c)}\mathbf r_{c,t-1}
+
\boldsymbol\epsilon_{ct},
$$

$$
\boldsymbol\epsilon_{ct}
\sim
MVN(0, \Sigma_{\epsilon,g(c)}),
$$

where \(g(c)\) indexes dyad type.

This is best described as a **dyadic residual VAR(1)** model. It is not merely an AR(1) correction. The entries of \(A\) have substantive interpretations:

- diagonal entries: actor inertia;
- off-diagonal entries: partner carryover.

The innovation covariance \(\Sigma_\epsilon\) captures same-day coupling in shocks after conditioning on the previous residual state.

### 1.3 Scope for the first full implementation

The first full implementation should be restricted to:

- Gaussian outcomes;
- two-person dyads;
- lag-1 residual dynamics;
- complete balanced data initially;
- later: ragged complete dyad-days and full dyad-day gaps;
- no one-partner missingness at first;
- no non-Gaussian likelihoods at first;
- no random VAR parameters at first;
- no measurement models at first;
- no latent centering at first.

This restricted scope is deliberate. The statistical core must be validated before adding DSEM extensions.

### 1.4 Relation to DSEM, RDSEM, and manifest lagged models

The proposed model is closest to a multivariate **residual DSEM (RDSEM)**. Its
mean model contains time trends and concurrent actor, partner, DIM, or DSM
associations, while the VAR process is applied to the remaining residuals. This
is different from a structural lagged-outcome MLM or ordinary DSEM, where the
observed outcome is directly regressed on its own and possibly its partner's
prior outcome. Adding observed outcome lags changes the interpretation of all
other coefficients and is not a neutral substitute for residual dynamics.

The following DSEM considerations should inform later design stages without
expanding the first Stan implementation:

- Mplus DSEM creates lags from the observed series but uses latent person-mean
  centering by default. This is not equivalent to either a raw manifest lag or
  an observed person-mean-centered lag. The latent decomposition is intended to
  avoid Nickell bias in autoregressive paths and bias from unreliable observed
  person means in between-person effects.
- Latent centering is not automatically reliable with very short series.
  Simulations by Gistelinck, Loeys, and Flamant show that default DSEM can still
  be biased or unstable at small `T`, partly because of initial-condition and
  presample-state handling. The first-outcome likelihood and its relationship
  with stable member effects must therefore remain explicit design decisions.
- A time covariate in a structural lagged-outcome equation is not identical to
  separating the trend from residual autoregression. The planned residual VAR
  should keep the mean trend and residual transition equations distinct.
- A full multivariate dynamic model should estimate own- and cross-partner
  transitions jointly with same-occasion innovation covariance. Conditionally
  independent scalar observation equations do not themselves supply innovation
  covariance, although a joint hierarchical model can still correlate group
  effects across equations. These levels of dependence must not be conflated.
- Discrete lag coefficients are tied to a specific elapsed-time unit. Ragged
  records and omitted occasions must not silently turn the previous available
  observation into a lag-1 observation. Gap-aware transitions, and eventually
  state-space or Kalman-style handling, should be evaluated against Mplus's
  `TINTERVAL` and missing-data behavior.
- Contemporaneous predictors may be included in a dynamic mean model, but their
  coefficients remain conditional associations unless temporal ordering and
  stronger identifying assumptions justify a causal interpretation.

This note has not yet been systematically reconciled with the methodological
papers stored in [`References/`](References/). Before any Stan implementation,
revise the plan against that local collection, especially the work on DSEM and
RDSEM, latent centering, small-`T` autoregressive bias, dyadic longitudinal
models, and random-effect specification. The McNeish and Hamaker DSEM primer,
the Asparouhov papers, the Hamaker and Grasman centering paper, the Gistelinck
papers, Nickell, and del Rosario and West should be treated as required starting
points rather than relying on this roadmap alone.

---

## 2. Statistical foundation

## 2.1 Mean model

The general decomposition is:

$$
y_{cmt} = \mu_{cmt} + r_{cmt}.
$$

The mean model should eventually support:

- intercept-only models;
- role-specific intercepts;
- time trends;
- actor predictors;
- partner predictors;
- within-person predictors;
- between-person predictors;
- interactions;
- shared dyad-level random effects;
- arbitrary difference random effects for exchangeable dyads;
- role-specific random effects for distinguishable dyads;
- random slopes.

However, the implementation should begin with simple mean models, because dynamic residual parameters can be hard to identify when the mean model is too rich.

Within the current Gaussian RDSEM target, the dynamic process is applied to residuals:

$$
r_{cmt} = y_{cmt} - \mu_{cmt}.
$$

This separation is important because it makes the model modular:

- the mean model explains stable differences and covariate effects;
- the residual VAR explains temporal dependence and cross-partner temporal dependence.

## 2.2 Residual VAR(1)

For each dyad:

$$
\mathbf r_{ct}
=
A_{g(c)}\mathbf r_{c,t-1}
+
\boldsymbol\epsilon_{ct}.
$$

The form of \(A_g\) depends on whether the dyad type is distinguishable or exchangeable.

### 2.2.1 Distinguishable dyads

For distinguishable dyads, the transition matrix can be fully directional:

$$
A_g
=
\begin{pmatrix}
\phi_{1 \leftarrow 1,g} & \phi_{1 \leftarrow 2,g} \\
\phi_{2 \leftarrow 1,g} & \phi_{2 \leftarrow 2,g}
\end{pmatrix}.
$$

Interpretation:

- \(\phi_{1 \leftarrow 1,g}\): actor inertia for role 1;
- \(\phi_{2 \leftarrow 2,g}\): actor inertia for role 2;
- \(\phi_{1 \leftarrow 2,g}\): partner carryover from role 2 to role 1;
- \(\phi_{2 \leftarrow 1,g}\): partner carryover from role 1 to role 2.

### 2.2.2 Exchangeable dyads

For exchangeable dyads, member labels are arbitrary. Therefore, the residual transition matrix must be invariant under swapping labels:

$$
A_g
=
\begin{pmatrix}
\phi_{A,g} & \phi_{P,g} \\
\phi_{P,g} & \phi_{A,g}
\end{pmatrix}.
$$

Interpretation:

- \(\phi_{A,g}\): actor inertia;
- \(\phi_{P,g}\): partner carryover.

This constrained form is required for label invariance. If the labels are swapped, the likelihood and all label-invariant posterior summaries should remain unchanged.

## 2.3 Innovation covariance versus marginal residual covariance

This is a key conceptual point.

The covariance matrix \(\Sigma_\epsilon\) describes the covariance of **innovations**, not the total marginal covariance of residuals.

For distinguishable dyads:

$$
\Sigma_\epsilon
=
\begin{pmatrix}
\sigma_1^2 & \rho_\epsilon\sigma_1\sigma_2 \\
\rho_\epsilon\sigma_1\sigma_2 & \sigma_2^2
\end{pmatrix}.
$$

For exchangeable dyads:

$$
\Sigma_\epsilon
=
\sigma^2
\begin{pmatrix}
1 & \rho_\epsilon \\
\rho_\epsilon & 1
\end{pmatrix}.
$$

The parameter \(\rho_\epsilon\) should be called:

```text
rho_innov
```

or:

```text
innovation correlation
```

It should not simply be called the residual correlation. In a stationary VAR model, the marginal residual covariance is affected by both \(\Sigma_\epsilon\) and the transition matrix \(A\):

$$
\Gamma_0
=
A\Gamma_0 A^\top + \Sigma_\epsilon.
$$

Therefore, the package should distinguish:

```text
rho_innov      = correlation of innovation shocks epsilon_t
rho_marginal   = stationary marginal same-day correlation of residuals r_t
Sigma_epsilon  = innovation covariance matrix
Gamma_0        = stationary marginal residual covariance matrix
```

This distinction should appear in documentation, printed summaries, tidy output, and generated quantities.

## 2.4 Likelihood architecture and future extensibility

"Univariate" versus "multivariate" Stan can refer to several different things:

- whether the input data contain one member row or one paired dyad-occasion row;
- whether the mean model is written as one stacked equation or as two response-specific equations;
- whether Stan evaluates independent scalar likelihood contributions or one joint density for the member pair.

These choices should not be conflated. A long scalar-response design and two
response-specific formulas can encode the same Gaussian VAR mean. The important
statistical distinction is whether the two member innovations at a dyad-occasion
are modeled jointly. Merely stacking two scalar likelihood contributions implies
conditional independence unless dependence is introduced elsewhere.

The package should therefore use a hybrid architecture:

1. Build the mean model from stacked member or equation design rows. This keeps
   actor and partner terms, role interactions, random slopes, and parameter
   sharing manageable in R.
2. Pair those rows by dyad-occasion and assemble the raw observations and, as
   required by the model class, Gaussian residuals or latent states into vectors.
3. Apply the dyad-vector transition and observation kernels appropriate to the
   model class, with the correct parameter map for the dyad type. In the initial
   Gaussian residual VAR, these reduce to one joint residual transition density.

For the initial Gaussian residual VAR, the canonical raw-space transition is:

$$
\mathbf r_{ct}
\mid
\mathbf r_{c,t-1}
\sim
MVN(A_g\mathbf r_{c,t-1}, \Sigma_{\epsilon,g}).
$$

Distinguishable dyads use a free role-ordered \(A_g\) and
\(\Sigma_{\epsilon,g}\). Exchangeable dyads use swap-invariant parameter maps
for those same objects. The \(U/V\) representation is an exact diagonalization
of this constrained Gaussian vector likelihood. It may be used internally for
stationarity, sampling efficiency, and validation, but it should not define a
different public model family or require transformed outcomes in the package
interface.

Multivariate `brms` Gaussian models are useful reference implementations where
their manifest or residual specification matches the target likelihood. Their
multiple-response syntax illustrates equation-specific design matrices and
correlated group effects. It does not settle the package architecture: in
`brms`, residual correlations are currently available only for multivariate
Gaussian and Student models. See the official
[`brms` multivariate documentation](https://paulbuerkner.com/brms/articles/brms_multivariate.html)
and [`mvbrmsformula` reference](https://paulbuerkner.com/brms/reference/mvbrmsformula.html).

### Non-Gaussian boundary

Non-Gaussian outcomes must not be treated as a drop-in family replacement for
the Gaussian residual VAR. Binary and count outcomes do not have a freely
estimated additive residual covariance on their observed scale, and transforming
their observed values to \(U/V\) does not preserve Bernoulli, Poisson, or related
families.

A later non-Gaussian design review should distinguish at least:

1. an observation-driven or manifest generalized VAR that conditions each
   outcome on the observed lagged outcome vector;
2. a latent vector-state model in which a Gaussian dyadic state follows a VAR
   and each observed member outcome has a family-specific observation model;
3. a purpose-built joint model, such as multivariate probit or a justified
   copula construction.

If retaining correlated dynamic innovations is the priority, the latent
vector-state route is the leading candidate. In that case \(U/V\) may still
diagonalize an exchangeable latent Gaussian state, while the observation model
remains in the original member basis. This is a later model-class decision, not
part of the first Gaussian implementation.

A generic form to evaluate later is:

$$
\mathbf h_{ct}
\mid
\mathbf h_{c,t-1}
\sim
MVN(A_g\mathbf h_{c,t-1}, Q_g),
\qquad
y_{cmt}
\mid
h_{cmt}
\sim
F_m\!\left(g_m^{-1}(\mu_{cmt}+h_{cmt})\right).
$$

Here dynamic innovation covariance lives on the latent or link scale, not as a
free residual correlation between the observed non-Gaussian outcomes. For
exchangeable dyads, the observation family, link, dispersion parameters, and
loadings would also have to be swap-invariant.

### Interactions and later multiple-process models

Interactions among exogenous predictors in the conditional mean belong in the
stacked design matrices and do not require a different dynamic kernel. For
exchangeable dyads, however, the complete generated mean must remain equivariant
to swapping members; arbitrary member-label interactions are not allowed.
Interactions involving latent processes, observation parameters, mediated paths,
or entries of \(A_g\) belong to their respective future model layers. In
particular, moderation of \(A_g\) makes stationarity predictor-dependent.

If \(P\) swaps the two members, the required mean-model condition is:

$$
\mu(Px)=P\mu(x).
$$

Keep the member index and the outcome or process index distinct in internal
metadata, even though the first implementation has two members and one outcome
per member. With \(K\) substantive processes, a later joint dynamic model could
use a \(2K\)-dimensional state without redefining what a member is. This only
preserves an extension path. Longitudinal mediation would still require its own
temporal ordering, structural assumptions, and identification review.

---

## 3. Technical implementation principles

The Stan implementation should rely on standard robust Stan strategies:

- non-centered hierarchical random effects;
- Cholesky-factor covariance parameterizations;
- LKJ priors for correlation matrices;
- explicit recursive time-series likelihoods;
- careful stationarity handling;
- simulation-based validation;
- generated quantities designed for post-processing rather than overloading the sampling model.

Relevant Stan resources:

- Stan User's Guide: multivariate hierarchical priors and Cholesky/non-centered parameterizations  
  <https://mc-stan.org/docs/2_31/stan-users-guide/multivariate-hierarchical-priors.html>
- Stan User's Guide: [multivariate outcomes and joint error structures](https://mc-stan.org/docs/stan-users-guide/regression.html#multivariate-outcomes)
- Stan User's Guide: time-series models and autoregressive likelihoods  
  <https://mc-stan.org/docs/stan-users-guide/time-series.html>
- Stan User's Guide: missing data  
  <https://mc-stan.org/docs/stan-users-guide/missing-data.html>
- Stan User's Guide: within-chain parallelization with `reduce_sum`  
  <https://mc-stan.org/docs/stan-users-guide/parallelization.html>
- CmdStanR package documentation  
  <https://mc-stan.org/cmdstanr/reference/cmdstanr-package.html>
- CmdStanR standalone generated quantities  
  <https://mc-stan.org/cmdstanr/reference/model-method-generate-quantities.html>
- `loo` workflow for pointwise log likelihoods  
  <https://mc-stan.org/loo/articles/loo2-with-rstan.html>

The first implementation should prioritize:

1. mathematical correctness;
2. label invariance;
3. stationarity handling;
4. simulation recovery;
5. transparent post-processing;
6. package-safe code generation.

Do not try to implement arbitrary high-order formula syntax, non-Gaussian families, random VAR parameters, one-partner missingness, partial pooling, and mixed dyad types all at once.

---

# 4. Exchangeable dyad model

## 4.1 Purpose

The exchangeable model should be the first implementation target.

Examples:

- female--female dyads;
- male--male dyads;
- same-role friends;
- same-role siblings;
- arbitrary same-role dyads;
- dyads where member order has no substantive meaning.

The model must be invariant to swapping member labels. If person 1 and person 2 are exchanged within a dyad:

- the likelihood should be unchanged;
- all label-invariant posterior summaries should be unchanged;
- arbitrary difference-coded quantities should only change sign.

The exchangeable model is the best first target because the residual VAR diagonalizes cleanly into sum and difference processes, and stationarity can be enforced with simple scalar constraints.

## 4.2 Required input data

At minimum, the R preprocessing layer should require:

```text
dyad_id
person_id
time
outcome y
dyad_type
exchangeable flag
idiff
```

For exchangeable dyads:

```text
exchangeable = TRUE
idiff ∈ {-1, +1} within each dyad
```

For distinguishable dyads:

```text
exchangeable = FALSE
idiff = 0
```

Useful optional inputs:

```text
role
role_pair
actor predictors
partner predictors
within-person predictors
between-person predictors
time-varying covariates
```

Your existing package already seems to provide the most important ingredients:

- a role-pair column such as `male_x_female_female`, `male_x_female_male`, or `male_x_male`;
- metadata indicating whether a dyad type is exchangeable;
- an `idiff` column coded as nonzero for exchangeable dyads and zero for distinguishable dyads.

For the first Stan prototype, a balanced wide representation is acceptable:

```text
C_exchangeable dyads
T time points per dyad
y[c, t, 1]
y[c, t, 2]
```

Later versions should use transition records rather than relying on rectangular arrays.

## 4.3 Orthonormal sum--difference parameterization

For the exchangeable Gaussian kernel, use the orthonormal transform internally
while retaining the raw member vector as the canonical model interface:

$$
U_{ct}
=
\frac{r_{c1t}+r_{c2t}}{\sqrt{2}},
$$

$$
V_{ct}
=
\frac{r_{c1t}-r_{c2t}}{\sqrt{2}}.
$$

This is preferable to the half-scaled transform:

$$
S_{ct}=\frac{r_{c1t}+r_{c2t}}{2},
\quad
D_{ct}=\frac{r_{c1t}-r_{c2t}}{2},
$$

because the orthonormal transform has determinant 1 and avoids constant-Jacobian bookkeeping in exact log-likelihood calculations.

The exchangeable transition matrix diagonalizes under this transform:

$$
U_{ct}
=
\phi_S U_{c,t-1}
+
\epsilon_{U,ct},
$$

$$
V_{ct}
=
\phi_D V_{c,t-1}
+
\epsilon_{V,ct}.
$$

The sum and difference dynamics are:

$$
\phi_S = \phi_A + \phi_P,
$$

$$
\phi_D = \phi_A - \phi_P.
$$

The actor and partner parameters are recovered as:

$$
\phi_A = \frac{\phi_S+\phi_D}{2},
$$

$$
\phi_P = \frac{\phi_S-\phi_D}{2}.
$$

Stationarity is simple:

$$
|\phi_S| < 1,
$$

$$
|\phi_D| < 1.
$$

## 4.4 Exchangeable innovation covariance

In raw member space:

$$
\Sigma_\epsilon
=
\sigma^2
\begin{pmatrix}
1 & \rho_\epsilon \\
\rho_\epsilon & 1
\end{pmatrix}.
$$

Under the orthonormal transform:

$$
Var(\epsilon_U)
=
\sigma^2(1+\rho_\epsilon),
$$

$$
Var(\epsilon_V)
=
\sigma^2(1-\rho_\epsilon),
$$

$$
Cov(\epsilon_U,\epsilon_V)=0.
$$

Thus:

$$
\sigma_U = \sigma\sqrt{1+\rho_\epsilon},
$$

$$
\sigma_V = \sigma\sqrt{1-\rho_\epsilon}.
$$

The exchangeable likelihood can be implemented as two independent AR(1) likelihoods for \(U\) and \(V\):

$$
U_t \mid U_{t-1}
\sim
N(\phi_S U_{t-1}, \sigma_U),
$$

$$
V_t \mid V_{t-1}
\sim
N(\phi_D V_{t-1}, \sigma_V).
$$

This independence holds in the transformed Gaussian basis under the
exchangeability constraints. The resulting density is algebraically identical
to the constrained bivariate normal transition in raw member space. Both forms
should be retained in validation code even if the \(U/V\) form is used for
sampling.

## 4.5 Exchangeable marginal residual correlation

The package should report the marginal residual correlation implied by the stationary process.

For the exchangeable model:

$$
Var(U)
=
\frac{\sigma^2(1+\rho_\epsilon)}{1-\phi_S^2},
$$

$$
Var(V)
=
\frac{\sigma^2(1-\rho_\epsilon)}{1-\phi_D^2}.
$$

Because:

$$
r_1 = \frac{U+V}{\sqrt{2}},
$$

$$
r_2 = \frac{U-V}{\sqrt{2}},
$$

the stationary marginal covariance is:

$$
Cov(r_1,r_2)
=
\frac{Var(U)-Var(V)}{2}.
$$

The stationary marginal variance is:

$$
Var(r_1)=Var(r_2)
=
\frac{Var(U)+Var(V)}{2}.
$$

Therefore:

$$
\rho_{marginal}
=
\frac{Var(U)-Var(V)}{Var(U)+Var(V)}.
$$

Generated quantities should include:

```text
rho_innov
rho_marginal
sigma_innov
sigma_marginal
phi_sum
phi_diff
phi_actor
phi_partner
```

This prevents users from interpreting the innovation correlation as the total same-day residual association.

## 4.6 Exchangeable mean model

A minimal exchangeable mean model is:

$$
y_{cmt}
=
\beta_0
+
b^{(S)}_{0,c}
+
idiff_{cm} b^{(D)}_{0,c}
+
r_{cmt}.
$$

Here:

- \(b^{(S)}_{0,c}\) is a shared dyad-level intercept deviation;
- \(b^{(D)}_{0,c}\) is an arbitrary within-dyad difference deviation;
- `idiff` flips sign when member labels are swapped.

With one predictor:

$$
y_{cmt}
=
\beta_0
+
\beta_1 x_{cmt}
+
b^{(S)}_{0,c}
+
b^{(S)}_{1,c}x_{cmt}
+
idiff_{cm} b^{(D)}_{0,c}
+
idiff_{cm} b^{(D)}_{1,c}x_{cmt}
+
r_{cmt}.
$$

Actor and partner predictors can be allowed, but their fixed effects must not depend on arbitrary member labels:

$$
\mu_{cmt}
=
\beta_0
+
\beta_A x_{cmt}
+
\beta_P x_{cj t}
+
\ldots,
$$

where \(j\) is the partner of member \(m\).

## 4.7 Exchangeable random-effect covariance structure

For truly exchangeable dyads, the random-effect covariance structure must preserve label invariance.

A shared effect is invariant under label swapping:

$$
b^{(S)} \rightarrow b^{(S)}.
$$

A difference effect changes sign:

$$
b^{(D)} \rightarrow -b^{(D)}.
$$

Therefore, a covariance such as:

$$
Cov(b^{(S)}, b^{(D)})
$$

also changes sign under label swapping. The only label-invariant value is zero.

So the recommended random-effect structure is block diagonal:

$$
\mathbf b^{(S)}_c \sim MVN(0, \Sigma_S),
$$

$$
\mathbf b^{(D)}_c \sim MVN(0, \Sigma_D),
$$

$$
Cov(\mathbf b^{(S)}_c, \mathbf b^{(D)}_c) = 0.
$$

Allowed:

```text
covariance among shared effects
covariance among difference effects
```

Not allowed by default:

```text
covariance between shared and difference effects
```

A package interface could encode this as:

```r
random = shared_diff(
  shared = ~ 1 + x_actor,
  diff   = ~ 1 + x_actor,
  group  = dyad_id,
  cov    = "block"
)
```

A full shared--difference covariance should require an explicit advanced option and should warn users that it breaks pure exchangeability unless the difference direction has substantive meaning.

## 4.8 Exchangeable initial state

For the exchangeable model, use the stationary initial distribution by default:

$$
U_{c1}
\sim
N\left(
0,
\frac{\sigma_U}{\sqrt{1-\phi_S^2}}
\right),
$$

$$
V_{c1}
\sim
N\left(
0,
\frac{\sigma_V}{\sqrt{1-\phi_D^2}}
\right).
$$

A conditional likelihood starting at \(t=2\) is acceptable for early debugging, but the package default should be stationary because the stationary initial distribution is simple and exact in the exchangeable case.

Recommended Stan helper functions:

```stan
functions {
  real ar1_stationary_lpdf(real z, real phi, real sigma) {
    return normal_lpdf(z | 0, sigma / sqrt(1 - square(phi)));
  }

  real ar1_transition_lpdf(real z, real z_prev, real phi, real sigma) {
    return normal_lpdf(z | phi * z_prev, sigma);
  }
}
```

For gap handling later:

```stan
functions {
  real ar1_gap_lpdf(real z, real z_prev, real phi, real sigma, int delta) {
    real phi_delta = pow(phi, delta);
    real var_mult;

    if (fabs(phi) < 0.999) {
      var_mult = (1 - pow(square(phi), delta)) / (1 - square(phi));
    } else {
      var_mult = delta;
    }

    return normal_lpdf(
      z | phi_delta * z_prev,
      sigma * sqrt(var_mult)
    );
  }
}
```

## 4.9 Exchangeable parameter constraints and priors

Prefer raw unconstrained parameters transformed through `tanh`:

```stan
parameters {
  real phi_sum_raw;
  real phi_diff_raw;
}

transformed parameters {
  real phi_sum  = tanh(phi_sum_raw);
  real phi_diff = tanh(phi_diff_raw);
}
```

This guarantees stationarity while keeping the sampler away from hard boundaries.

Default priors for standardized outcomes:

```stan
phi_sum_raw  ~ normal(0, 0.4);
phi_diff_raw ~ normal(0, 0.4);
```

Innovation SD and correlation can be represented as:

```stan
real<lower=0> sigma;
real rho_raw;
real rho_innov = tanh(rho_raw);
```

with priors such as:

```stan
sigma   ~ exponential(1);
rho_raw ~ normal(0, 0.75);
```

For a mixed-composition covariance implementation, a Cholesky correlation parameterization can also be used.

---

# 5. Distinguishable dyad model

## 5.1 Purpose

The distinguishable model applies when the two dyad members have meaningful, stable roles.

Examples:

- female--male romantic couples;
- mother--child dyads;
- therapist--client dyads;
- supervisor--employee dyads;
- patient--caregiver dyads.

The two members must be ordered by role, not by arbitrary label. The R preprocessing layer should enforce this role ordering before data are passed to Stan.

## 5.2 Required input data

At minimum:

```text
dyad_id
person_id
time
outcome y
role
dyad_type
exchangeable = FALSE
idiff = 0
```

The dyad registry should specify role order:

```r
dyad_types <- tibble::tribble(
  ~dyad_type,      ~exchangeable, ~role1,    ~role2,
  "female_male",   FALSE,         "female",  "male",
  "mother_child",  FALSE,         "mother",  "child"
)
```

The wide internal representation for a balanced prototype is:

```text
y[c, t, 1] = role 1 outcome
y[c, t, 2] = role 2 outcome
```

## 5.3 Distinguishable mean model

A simple role-specific mean model:

$$
\mu_{1,ct}
=
\beta_{0,1}
+
b_{0,1,c}
+
(\beta_{1,1}+b_{1,1,c})x_{1,ct},
$$

$$
\mu_{2,ct}
=
\beta_{0,2}
+
b_{0,2,c}
+
(\beta_{1,2}+b_{1,2,c})x_{2,ct}.
$$

With actor and partner predictors:

$$
\mu_{1,ct}
=
\beta_{0,1}
+
\beta_{A,1}x_{1,ct}
+
\beta_{P,1}x_{2,ct}
+
b_{0,1,c},
$$

$$
\mu_{2,ct}
=
\beta_{0,2}
+
\beta_{A,2}x_{2,ct}
+
\beta_{P,2}x_{1,ct}
+
b_{0,2,c}.
$$

For one random slope, the random-effect vector is:

$$
\mathbf b_c
=
\begin{pmatrix}
b_{0,1,c} \\
b_{0,2,c} \\
b_{1,1,c} \\
b_{1,2,c}
\end{pmatrix}
\sim
MVN(0,\Sigma_b).
$$

This maps to the design-matrix idea:

```r
(0 + is_role1 + is_role2 + slope:is_role1 + slope:is_role2 | dyad_id)
```

For multiple slopes, the dimension is:

```text
2 roles × (intercept + K random slopes)
```

Use a non-centered Cholesky parameterization for these role-specific random effects.

## 5.4 Distinguishable residual VAR(1)

The distinguishable transition matrix is:

$$
A
=
\begin{pmatrix}
\phi_{1 \leftarrow 1} & \phi_{1 \leftarrow 2} \\
\phi_{2 \leftarrow 1} & \phi_{2 \leftarrow 2}
\end{pmatrix}.
$$

Interpretation:

```text
phi_1_from_1 = actor inertia for role 1
phi_2_from_2 = actor inertia for role 2
phi_1_from_2 = partner carryover from role 2 to role 1
phi_2_from_1 = partner carryover from role 1 to role 2
```

Innovation covariance:

$$
\Sigma_\epsilon
=
\begin{pmatrix}
\sigma_1^2 & \rho_\epsilon\sigma_1\sigma_2 \\
\rho_\epsilon\sigma_1\sigma_2 & \sigma_2^2
\end{pmatrix}.
$$

Again, the package should label \(\rho_\epsilon\) as an innovation correlation.

## 5.5 Distinguishable stationarity

For a free \(2 \times 2\) matrix \(A\), stationarity requires all eigenvalues to lie inside the unit circle:

$$
\rho(A) < 1.
$$

For:

$$
A =
\begin{pmatrix}
a & b \\
c & d
\end{pmatrix},
$$

define:

$$
tr = a+d,
$$

$$
det = ad-bc.
$$

The VAR is stable if the Jury conditions hold:

$$
1 - det > 0,
$$

$$
1 - tr + det > 0,
$$

$$
1 + tr + det > 0.
$$

For the first distinguishable implementation, use regularizing priors and posterior stationarity checks rather than a hard stationarity constraint. Hard rejection or exact stable parameterization can create sampling pathologies and should not be the first implementation.

Generated quantities:

```stan
generated quantities {
  real tr_A;
  real det_A;
  int is_stationary;

  tr_A = A[1, 1] + A[2, 2];
  det_A = A[1, 1] * A[2, 2] - A[1, 2] * A[2, 1];

  is_stationary =
    (1 - det_A > 0) &&
    (1 - tr_A + det_A > 0) &&
    (1 + tr_A + det_A > 0);
}
```

Optional spectral radius:

```stan
generated quantities {
  real tr_A = A[1, 1] + A[2, 2];
  real det_A = A[1, 1] * A[2, 2] - A[1, 2] * A[2, 1];
  real disc = square(tr_A) - 4 * det_A;
  real spectral_radius;

  if (disc >= 0) {
    real lambda1 = 0.5 * (tr_A + sqrt(disc));
    real lambda2 = 0.5 * (tr_A - sqrt(disc));
    spectral_radius = fmax(fabs(lambda1), fabs(lambda2));
  } else {
    spectral_radius = sqrt(det_A);
  }
}
```

The package should summarize:

```r
posterior_stationarity(fit)
# dyad_type, draw, spectral_radius, is_stationary
```

If a meaningful proportion of posterior draws is nonstationary, print a diagnostic warning.

## 5.6 Distinguishable initial state

Start with a conditional likelihood:

$$
\mathbf r_{ct}
\mid
\mathbf r_{c,t-1}
\sim
MVN(A\mathbf r_{c,t-1}, \Sigma_\epsilon),
\qquad t \ge 2.
$$

This is easiest and avoids needing an exact stationary covariance before the distinguishable model is stable.

Later, add the stationary initial distribution:

$$
\mathbf r_{c1}
\sim
MVN(0,\Gamma_0),
$$

where:

$$
\Gamma_0
=
A\Gamma_0 A^\top + \Sigma_\epsilon.
$$

Equivalently:

$$
vec(\Gamma_0)
=
(I - A \otimes A)^{-1} vec(\Sigma_\epsilon).
$$

This should only be used when the draw is stationary.

## 5.7 Distinguishable priors

For standardized outcomes and predictors:

```text
role-specific fixed effects:
  normal(0, 1)

actor inertia entries:
  normal(0, 0.3)

partner carryover entries:
  normal(0, 0.2) or normal(0, 0.25)

innovation SDs:
  exponential(1)

innovation correlation:
  LKJ(2) if using Cholesky factor
  or rho_raw ~ normal(0, 0.75), rho = tanh(rho_raw)

random-effect SDs:
  exponential(1)

random-effect correlations:
  LKJ(2)
```

Partner carryover should usually be shrunk more strongly than actor inertia because it is often harder to identify.

---

# 6. Mixed-composition dyad model

## 6.1 Purpose

The mixed-composition model combines exchangeable and distinguishable dyad types in one likelihood.

Example:

```text
distinguishable dyad types:
  female_male
  mother_child

exchangeable dyad types:
  female_female
  male_male
  sibling_sibling
```

The model should allow each dyad type to have the appropriate constraints while still being fit as one coherent model.

## 6.2 Dyad-type registry

The R package should build a dyad-type registry before creating Stan data:

```r
dyad_types <- tibble::tribble(
  ~dyad_type,          ~exchangeable, ~role1,     ~role2,
  "female_male",       FALSE,         "female",   "male",
  "mother_child",      FALSE,         "mother",   "child",
  "female_female",     TRUE,          "female",   "female",
  "male_male",         TRUE,          "male",     "male",
  "sibling_sibling",   TRUE,          "sibling",  "sibling"
)
```

The registry should be converted into integer arrays for Stan:

```text
G                         number of dyad types
dyad_type[c]              type index for dyad c
is_exchangeable_type[g]   0/1 flag
role1_type[g]             role-class index for member position 1
role2_type[g]             role-class index for member position 2
```

For distinguishable dyads, the registry defines role order.

For exchangeable dyads, the registry defines role class but not a meaningful member order.

## 6.3 Mixed-composition likelihood structure

For the first mixed-composition model, keep type-specific parameters separate.

Stan-like pseudocode:

```stan
for (c in 1:C) {
  int g = dyad_type[c];

  if (is_exchangeable_type[g]) {
    // orthonormal sum-difference likelihood
  } else {
    // role-ordered distinguishable VAR likelihood
  }
}
```

For performance and cleaner future parallelization, it may be better to sort dyads by type in R and then run separate loops:

```stan
for (i in 1:N_exchangeable_dyads) {
  // exchangeable likelihood
}

for (i in 1:N_distinguishable_dyads) {
  // distinguishable likelihood
}
```

The likelihood factors by dyad conditional on global parameters and dyad-level random effects, so later versions can parallelize across dyads using Stan's `reduce_sum`.

## 6.4 Mixed-composition dynamic parameters

For each exchangeable dyad type \(g\):

$$
\phi_{S,g},
\quad
\phi_{D,g},
\quad
\sigma_g,
\quad
\rho_{\epsilon,g}.
$$

Derived:

$$
\phi_{A,g}
=
\frac{\phi_{S,g}+\phi_{D,g}}{2},
$$

$$
\phi_{P,g}
=
\frac{\phi_{S,g}-\phi_{D,g}}{2}.
$$

For each distinguishable dyad type \(g\):

$$
A_g
=
\begin{pmatrix}
\phi_{1 \leftarrow 1,g} & \phi_{1 \leftarrow 2,g} \\
\phi_{2 \leftarrow 1,g} & \phi_{2 \leftarrow 2,g}
\end{pmatrix},
$$

$$
\Sigma_{\epsilon,g}
=
\begin{pmatrix}
\sigma_{1,g}^2 & \rho_{\epsilon,g}\sigma_{1,g}\sigma_{2,g} \\
\rho_{\epsilon,g}\sigma_{1,g}\sigma_{2,g} & \sigma_{2,g}^2
\end{pmatrix}.
$$

## 6.5 Partial pooling across dyad types

Do not include partial pooling in the first mixed-composition model.

The first mixed-composition model should prove that:

```text
multiple dyad types can be fit in one Stan likelihood
exchangeable types remain label invariant
distinguishable types remain role ordered
type-specific parameters are recovered in simulation
post-processing returns a coherent common output format
```

After that, add partial pooling where substantively defensible.

Possible pooling dimensions:

```text
role class:
  female
  male
  mother
  child
  sibling

dyad type:
  female_male
  female_female
  male_male
  mother_child

parameter class:
  actor inertia
  partner carryover
  innovation SD
  innovation correlation
  actor fixed effect
  partner fixed effect
```

Examples:

```text
female actor inertia in female_male dyads
female actor inertia in female_female dyads
```

could share a hyperprior.

```text
male innovation SD in female_male dyads
male innovation SD in male_male dyads
```

could share a hyperprior.

Partner carryover should usually remain more type-specific because directional partner effects may differ strongly by dyad type.

---

# 7. Data representation

The public R data contract should remain one long row per member-occasion. The
mean-model builder can therefore construct stacked member-level design matrices,
while the transition table pairs the two rows and connects each dyad-occasion to
its predecessor. Stan may receive `vector[2]` outcomes or states even though the
user never reshapes the data to a wide multivariate response.

Input shape does not determine likelihood independence. The transition table is
the indexing bridge between the long observation and design layer and the joint
dyad-vector dynamic layer.

The two internal axes should be named separately:

```text
member index:   the two people in a dyad
process index:  the substantive outcome, initially one
```

For exchangeable dyads, member slots are arbitrary but must remain stable for the
entire observed trajectory. Label invariance means that the two complete member
trajectories may be swapped without changing the likelihood; it does not mean
that member slots may be reassigned independently at each occasion.

## 7.1 Balanced arrays for early prototypes

For version 0.1, balanced arrays are acceptable:

```stan
data {
  int<lower=1> C;
  int<lower=1> T;
  array[C, T] vector[2] y;
}
```

This is simple and ideal for proving the first exchangeable model.

## 7.2 Transition records for the package data layer

The package should retain the long member table and build a separate paired
occasion/transition index. Give that index one row per current complete
dyad-occasion. The two member-row indices identify the current pair, and
`prev_obs_index` identifies the preceding paired occasion and therefore the
transition edge. Initial occasions have no preceding edge.

A robust transition table should include:

```text
obs_index
dyad_index
dyad_type_index
time_index
member1_row
member2_row
prev_obs_index
delta_from_prev
is_initial_for_dyad
y1
y2
role1_index
role2_index
```

For balanced complete data:

```text
delta_from_prev = 1
prev_obs_index = previous dyad-day within dyad
```

For full dyad-day gaps:

```text
delta_from_prev = number of elapsed time steps since previous complete dyad-day
```

This representation allows the package to grow from:

```text
balanced complete data
```

to:

```text
ragged complete dyad-days
```

to:

```text
full dyad-day gaps
```

without redesigning the public API.

## 7.3 Missingness staging

The missingness roadmap should be:

```text
stage 1:
  complete balanced dyad-days only

stage 2:
  ragged complete dyad-days

stage 3:
  full dyad-day gaps

stage 4:
  one-partner missingness as latent outcomes

stage 5:
  optional state-space or Kalman-style marginalization
```

For full dyad-day gaps in exchangeable models:

$$
z_t
\mid
z_{t-\Delta}
\sim
N
\left(
\phi^\Delta z_{t-\Delta},
\sigma^2
\sum_{k=0}^{\Delta-1}\phi^{2k}
\right),
$$

where \(z\) is either \(U\) or \(V\).

For distinguishable models:

$$
\mathbf r_t
\mid
\mathbf r_{t-\Delta}
\sim
MVN
\left(
A^\Delta \mathbf r_{t-\Delta},
\Sigma_\Delta
\right),
$$

where:

$$
\Sigma_\Delta
=
\sum_{k=0}^{\Delta-1}
A^k\Sigma_\epsilon(A^k)^\top.
$$

One-partner missingness should not be included early. In a dynamic dyadic VAR, a missing partner outcome is not merely an omitted outcome; it is part of the latent state that predicts later observations.

---

# 8. Stan implementation architecture

The exchangeable and distinguishable templates implement one canonical
dyad-vector model through different parameter maps and, where useful, different
Gaussian factorizations. A raw-member-space multivariate normal transition should
serve as the common reference density. The exchangeable \(U/V\) implementation
is an exact specialized kernel whose stationarity and sampling advantages can be
retained without making transformed outcomes the package architecture.

## 8.1 Exchangeable Stan skeleton

The first exchangeable skeleton uses orthonormal \(U,V\) internally.

```stan
data {
  int<lower=1> C;
  int<lower=2> T;
  array[C, T] vector[2] y;
}

parameters {
  real beta0;

  vector[C] z_b_shared;
  vector[C] z_b_diff;
  real<lower=0> sd_b_shared;
  real<lower=0> sd_b_diff;

  real phi_sum_raw;
  real phi_diff_raw;

  real<lower=0> sigma;
  real rho_raw;
}

transformed parameters {
  real phi_sum = tanh(phi_sum_raw);
  real phi_diff = tanh(phi_diff_raw);

  real phi_actor = 0.5 * (phi_sum + phi_diff);
  real phi_partner = 0.5 * (phi_sum - phi_diff);

  real rho_innov = tanh(rho_raw);

  real sigma_U = sigma * sqrt(1 + rho_innov);
  real sigma_V = sigma * sqrt(1 - rho_innov);
}

model {
  beta0 ~ normal(0, 1);

  z_b_shared ~ std_normal();
  z_b_diff ~ std_normal();

  sd_b_shared ~ exponential(1);
  sd_b_diff ~ exponential(1);

  phi_sum_raw ~ normal(0, 0.4);
  phi_diff_raw ~ normal(0, 0.4);

  sigma ~ exponential(1);
  rho_raw ~ normal(0, 0.75);

  for (c in 1:C) {
    vector[T] U;
    vector[T] V;

    real b_shared = sd_b_shared * z_b_shared[c];
    real b_diff = sd_b_diff * z_b_diff[c];

    for (t in 1:T) {
      vector[2] r;
      real mu1 = beta0 + b_shared - b_diff;
      real mu2 = beta0 + b_shared + b_diff;

      r[1] = y[c, t, 1] - mu1;
      r[2] = y[c, t, 2] - mu2;

      U[t] = (r[1] + r[2]) / sqrt(2);
      V[t] = (r[1] - r[2]) / sqrt(2);
    }

    U[1] ~ normal(0, sigma_U / sqrt(1 - square(phi_sum)));
    V[1] ~ normal(0, sigma_V / sqrt(1 - square(phi_diff)));

    for (t in 2:T) {
      U[t] ~ normal(phi_sum * U[t - 1], sigma_U);
      V[t] ~ normal(phi_diff * V[t - 1], sigma_V);
    }
  }
}
```

This skeleton uses independent shared and difference random-intercept blocks. Later, each block can be multivariate with its own Cholesky factor, but the cross-block covariance should remain zero for pure exchangeable dyads.

## 8.2 Distinguishable Stan skeleton

```stan
data {
  int<lower=1> C;
  int<lower=2> T;
  array[C, T] vector[2] y;
}

parameters {
  vector[2] beta0;

  matrix[2, C] z_b0;
  vector<lower=0>[2] sd_b0;
  cholesky_factor_corr[2] Lcor_b0;

  matrix[2, 2] A;

  vector<lower=0>[2] sigma_eps;
  cholesky_factor_corr[2] Lcor_eps;
}

model {
  matrix[2, 2] L_b0 = diag_pre_multiply(sd_b0, Lcor_b0);
  matrix[2, 2] L_eps = diag_pre_multiply(sigma_eps, Lcor_eps);

  beta0 ~ normal(0, 1);

  to_vector(z_b0) ~ std_normal();
  sd_b0 ~ exponential(1);
  Lcor_b0 ~ lkj_corr_cholesky(2);

  to_vector(A) ~ normal(0, 0.25);

  sigma_eps ~ exponential(1);
  Lcor_eps ~ lkj_corr_cholesky(2);

  for (c in 1:C) {
    vector[2] b0_c = L_b0 * z_b0[, c];
    array[T] vector[2] r;

    for (t in 1:T) {
      vector[2] mu = beta0 + b0_c;
      r[t] = y[c, t] - mu;
    }

    // Conditional likelihood prototype:
    for (t in 2:T) {
      r[t] ~ multi_normal_cholesky(A * r[t - 1], L_eps);
    }
  }
}
```

Generated quantities should compute:

```text
actor inertia by role
partner carryover by direction
innovation SD by role
innovation correlation
stationarity indicators
spectral radius
```

## 8.3 Log likelihood

Do not treat every individual row as independent for LOO by default. The time series creates dependence.

Expose multiple log-likelihood granularities:

```r
log_lik(fit, unit = "dyad")
log_lik(fit, unit = "transition")
```

Recommended defaults:

```text
unit = "dyad":
  safer for leave-one-dyad-out model comparison

unit = "transition":
  useful for one-step-ahead predictive comparisons
```

The package should explicitly compute log-likelihood quantities in generated quantities or through standalone generated quantities.

## 8.4 Generated quantities strategy

Keep the main sampling program lean.

Always generate lightweight quantities:

```text
phi_actor
phi_partner
phi_sum
phi_diff
rho_innov
rho_marginal
stationarity diagnostics
```

Make heavier generated quantities optional:

```text
posterior predictive replicated data
pointwise log likelihood
full implied residual covariance matrices
latent missing outcome draws
long-format residual summaries
```

CmdStanR supports standalone generated quantities, which means additional quantities can be generated from already fitted draws without rerunning the sampler. This is ideal for a package because users should not pay the sampling cost for posterior predictive draws, LOO arrays, or large residual summaries unless they request them.

---

# 9. R package architecture

## 9.1 Core package objects

Use explicit internal objects rather than one opaque mega-function.

Recommended object classes:

```text
dyadvar_spec
dyadvar_registry
dyadvar_data
dyadvar_stancode
dyadvar_fit
```

Responsibilities:

```text
dyadvar_spec:
  parsed model request, formulas, priors, dynamic structure

dyadvar_registry:
  dyad types, role order, exchangeability status, pooling metadata

dyadvar_data:
  validated data, design matrices, transition records, Stan data

dyadvar_stancode:
  generated Stan code, template metadata, model hash

dyadvar_fit:
  CmdStan fit object plus all metadata needed for post-processing
```

The fit object should store:

```r
fit$cmdstan_fit
fit$spec
fit$registry
fit$standata
fit$stancode
fit$preprocessing_report
fit$prior
fit$model_hash
fit$stan_version
fit$package_version
```

## 9.2 User-facing API

A high-level convenience wrapper is useful, but lower-level steps should also be available.

```r
spec <- dyad_var_spec(
  formula = y ~ x_actor + x_partner,
  structure = "exchangeable",
  dynamic = var1(),
  random = shared_diff(
    shared = ~ 1 + x_actor,
    diff   = ~ 1,
    group  = dyad_id
  )
)

prep <- prepare_dyad_data(
  spec,
  data = dat,
  dyad_id = "coupleID",
  person_id = "personID",
  time = "day",
  role = "role",
  dyad_type = "dyad_type",
  exchangeable = "exchangeable",
  idiff = "idiff"
)

code <- generate_stan(prep)

fit <- sample_dyad_var(code, prep, backend = "cmdstanr")
```

Then `dyad_var()` can wrap the full workflow:

```r
fit <- dyad_var(
  formula = y ~ x_actor + x_partner,
  data = dat,
  dyad_id = "coupleID",
  person_id = "personID",
  time = "day",
  role = "role",
  dyad_type = "dyad_type",
  exchangeable = "exchangeable",
  idiff = "idiff",
  structure = "exchangeable",
  dynamic = var1(),
  random = shared_diff(
    shared = ~ 1 + x_actor,
    diff   = ~ 1,
    group  = dyad_id
  ),
  backend = "cmdstanr"
)
```

## 9.3 Code generation principles

Do not paste arbitrary user column names into Stan code.

Instead:

1. Parse formulas in R.
2. Build numeric design matrices in R.
3. Pass numeric matrices and integer indices to Stan.
4. Use stable Stan variable names.
5. Store mappings from matrix columns back to user-facing names in R.

Stan should see:

```stan
matrix[N, K_fixed] X;
vector[K_fixed] beta;
```

not:

```stan
real beta_depression_centered_partner_male_x_day3;
```

This makes code safer, easier to test, and much easier to debug.

Use a small number of templates early:

```text
exchangeable_intercept_only.stan
exchangeable_fixed_x.stan
exchangeable_random_intercept.stan
exchangeable_random_slope.stan
distinguishable_basic.stan
mixed_composition_basic.stan
```

Avoid building a fully general Stan-code generator before the statistical core has been validated.

## 9.4 Package modules

### Module 1: metadata validation

Functions:

```r
validate_dyad_metadata()
check_exchangeable_labels()
check_idiff()
check_role_ordering()
check_time_spacing()
check_dyad_registry()
```

Checks:

```text
exactly two members per complete dyad-day
exchangeable dyads have idiff values -1 and +1
distinguishable dyads have idiff = 0
distinguishable roles match registry order
exchangeable dyads do not imply meaningful member order
time is sorted within dyad
time gaps are known and integer-valued if gap handling is requested
```

### Module 2: data transformation

Functions:

```r
make_dyad_day_table()
make_transition_table()
build_partner_variables()
build_design_matrices()
build_standata()
```

Outputs:

```text
Stan data list
mapping object
dropped-row report
missingness report
role-order report
label-swap map
```

### Module 3: formula parsing

Start simple.

Supported initially:

```r
y ~ 1 + x1 + x2
```

Random effects should be specified through package-specific helpers rather than trying to clone the full `lme4` or `brms` formula language immediately.

Later helpers:

```r
actor(x)
partner(x)
within_person(x)
between_person(x)
role_specific(x)
shared_diff(...)
```

### Module 4: Stan code generation

Functions:

```r
generate_stan_exchangeable()
generate_stan_distinguishable()
generate_stan_mixed_composition()
write_stan_file()
```

Components:

```text
data block
transformed data block
parameters block
transformed parameters block
model block
generated quantities block
```

### Module 5: priors

Functions:

```r
default_priors()
set_prior_dyadvar()
validate_priors()
prior_summary()
prior_predict()
```

Default priors should depend on whether outcomes and predictors are standardized.

For standardized data:

```text
fixed effects:
  normal(0, 1)

random-effect SDs:
  exponential(1)

random-effect correlations:
  LKJ(2)

exchangeable phi raw parameters:
  normal(0, 0.4), transformed with tanh

distinguishable actor entries:
  normal(0, 0.3)

distinguishable partner entries:
  normal(0, 0.2) or normal(0, 0.25)

innovation SDs:
  exponential(1)

innovation correlations:
  LKJ(2) or tanh-transformed normal raw parameter
```

### Module 6: fitting wrapper

Use CmdStanR as the primary backend.

Functions:

```r
fit_dyad_var()
sample_dyad_var()
optimize_dyad_var()
variational_dyad_var()
```

`optimize_dyad_var()` and variational inference should be treated as debugging or approximation tools, not primary inference defaults.

### Module 7: post-processing

Functions:

```r
tidy_dyadvar()
summarise_dynamics()
extract_A_matrices()
extract_innovation_covariances()
posterior_stationarity()
posterior_actor_partner()
posterior_residual_cor()
posterior_predict_dyadvar()
pp_check_dyadvar()
```

For exchangeable dyads, always return:

```text
dyad_type
phi_sum
phi_diff
phi_actor
phi_partner
sigma_innov
rho_innov
rho_marginal
```

For distinguishable dyads, return:

```text
dyad_type
role_from
role_to
parameter_class
estimate/draw
```

For mixed-composition models, use long tidy output:

```text
draw
dyad_type
exchangeable
parameter_class
role_from
role_to
parameter
value
```

### Module 8: diagnostics

Functions:

```r
check_label_invariance()
check_stationarity()
check_var_identifiability()
check_missingness_pattern()
check_time_gaps()
check_prior_predictive()
check_recovery()
```

Diagnostics:

```text
Rhat
ESS
divergences
treedepth
BFMI
posterior stationarity
posterior predictive checks
simulation recovery
label invariance
prior predictive stability
```

---

# 10. Validation gates

These should become hard release gates, not just informal checks.

## Gate 1: simulator and likelihood agreement

For tiny datasets, compare:

```text
R simulator log density
Stan model log density
```

They should agree up to numerical tolerance.

This catches mistakes in:

```text
orthonormal transform scaling
innovation covariance
initial-state likelihood
gap-adjusted AR variance
role ordering
idiff signs
log-likelihood pointwise units
```

## Gate 2: exchangeable label invariance

For exchangeable dyads:

1. Evaluate the likelihood with original labels.
2. Swap member labels within dyads.
3. Re-evaluate the likelihood.
4. Confirm invariant quantities match.
5. Confirm arbitrary difference quantities flip sign.

This should be a unit test.

## Gate 3: simulation recovery

For every model stage:

```text
simulate known parameters
fit model
check posterior recovery
check posterior predictive behavior
check diagnostics
```

Test regimes:

```text
weak dynamics
moderate actor inertia
moderate partner carryover
high innovation correlation
short T
long T
small number of dyads
large number of dyads
high random-intercept variance
near-boundary dynamics
```

## Gate 4: stationarity diagnostics

For exchangeable models:

```text
|phi_sum| < 1
|phi_diff| < 1
```

This is guaranteed by construction.

For distinguishable models:

```text
spectral_radius
is_stationary
posterior Pr(stationary)
```

Warn if posterior stationarity is weak.

Example warning:

```text
Only 76% of posterior draws imply a stationary VAR process.
Interpret marginal residual correlations and stationary covariance summaries with caution.
Consider stronger priors or a stationary parameterization.
```

## Gate 5: prior predictive stability

Before fitting real data, simulate from priors and check:

```text
trajectories do not explode
residual variance is plausible
actor and partner effects are plausible
innovation correlations are not concentrated near ±1
```

This is especially important for VAR models because weak priors can produce nearly nonstationary trajectories.

## Gate 6: identifiability stress tests

Warn users when designs are risky:

```text
small T with random slopes
high missingness
near-boundary VAR parameters
large random-intercept variance
low within-person variation
actor and partner predictors highly collinear
same-day innovation correlation and partner carryover both weakly identified
```

The package should not forbid these models, but it should surface the risk.

---

# 11. Revised implementation milestones

## Stage 0: simulation and infrastructure

Deliverables:

```r
simulate_exchangeable_var()
simulate_distinguishable_var()
simulate_mixed_composition_var()
check_parameter_recovery()
check_label_invariance()
check_stationarity()
check_basis_likelihood_equivalence()
```

Tasks:

```text
build R simulators
store true parameters in structured objects
write log-density checkers
write simple plotting helpers
create tiny deterministic test datasets
build long-to-paired transition indexing
verify raw dyad-vector and exchangeable U/V log-density equivalence
compare against an independent multivariate Gaussian reference where the likelihoods coincide
```

No real-data modeling should happen before this stage works.

## Version 0.1: exchangeable balanced model

Features:

```text
Gaussian outcome
exchangeable dyads only
complete balanced data
fixed intercept
shared random intercept
difference random intercept
orthonormal sum-difference residual VAR
stationary initial distribution
phi_sum and phi_diff stationary by construction
rho_innov and rho_marginal generated quantities
CmdStanR backend
```

Random-effect covariance:

```text
shared block independent of difference block
```

Validation:

```text
simulation recovery
label-invariance test
stationary initial likelihood test
log-density agreement test
```

## Version 0.2: exchangeable predictors and random slopes

Features:

```text
fixed actor predictors
fixed partner predictors
shared random slopes
optional difference random slopes
block-diagonal shared/difference covariance
posterior predictive checks
prior predictive checks
```

Do not add missingness yet unless the balanced model is fully validated.

## Version 0.3: distinguishable balanced model

Features:

```text
one distinguishable dyad type
role-specific intercepts
role-specific random intercepts
optional role-specific slopes
free 2-by-2 A matrix
role-specific innovation SDs
innovation correlation
conditional likelihood from t = 2
posterior stationarity diagnostics
```

Do not enforce exact stationarity yet.

Validation:

```text
recover stable A matrices
report spectral radius
detect nonstationary posterior mass
recover role-specific innovation covariance
```

## Version 0.4: transition-record data layer and full dyad-day gaps

Features:

```text
transition-table preprocessing
ragged complete dyad-days
full dyad-day gaps
gap-adjusted exchangeable AR likelihood
gap-adjusted distinguishable VAR likelihood
missingness reports
```

Still exclude one-partner missingness.

## Version 0.5: mixed-composition model without partial pooling

Features:

```text
multiple dyad types
mix of exchangeable and distinguishable dyads
separate type-specific parameters
single Stan model
mixed-composition post-processing
common actor/partner output format
```

Validation:

```text
recover all dyad-type-specific parameters
exchangeable label invariance still holds
distinguishable role ordering still holds
```

## Version 0.6: optional stationary distinguishable initial state

Features:

```text
stationary initial covariance for distinguishable VAR
Lyapunov-equation solution
stationarity-dependent generated quantities
clear warnings for nonstationary draws
```

This should be added only after the distinguishable conditional model works reliably.

## Version 0.7: partial pooling across dyad types

Features:

```text
role-class pooling
dyad-type pooling
hierarchical priors for selected dynamic parameters
hierarchical priors for innovation SDs
optional pooling of fixed actor/partner effects
```

Start with conservative pooling structures. Do not partially pool everything.

## Version 0.8: one-partner missingness

Features:

```text
latent missing outcomes
or state-space marginalization
diagnostics for latent-state dimension
sensitivity checks against complete dyad-day analysis
```

This is a major modeling extension, not a small convenience feature.

## Version 1.0: stable applied package

Features:

```text
stable user API
tested Stan templates
simulation-based validation
prior predictive tools
posterior predictive tools
LOO/log-likelihood support with documented units
vignettes
clear model assumptions
clear limitations
```

---

# 12. What to avoid initially

Do not include the following in the first implementation:

```text
random VAR parameters
random innovation correlations
random innovation variances
non-Gaussian outcomes
latent centering of predictors
one-partner missingness
exact stationary parameterization for free distinguishable VAR
higher-order lags
arbitrary brms-style formula syntax
state-space marginalization
measurement models
```

These are valid future extensions, but including them early would make it much harder to know whether failures are caused by the core VAR model, random effects, missingness, code generation, or identifiability.

Before adding any non-Gaussian family, require a separate architecture gate that
defines whether the target is manifest and observation-driven, latent-state, or
a purpose-built joint observation model. Document the scale on which dynamics
and same-occasion dependence live. Do not advertise non-Gaussian support through
a mechanical `family` substitution.

---

# 13. Practical implementation notes

## 13.1 First proof of concept

Start with:

```text
exchangeable dyads
Gaussian outcome
balanced complete data
random intercepts only
orthonormal sum-difference residual VAR
stationary phi_sum and phi_diff
rho_innov and rho_marginal generated quantities
```

This is the cleanest and most likely to work.

## 13.2 Second proof of concept

Then build:

```text
distinguishable dyads
Gaussian outcome
balanced complete data
role-specific random intercepts
free 2-by-2 residual VAR matrix
weak stationarity priors
posterior stationarity diagnostics
```

## 13.3 Third proof of concept

Then combine:

```text
one exchangeable type + one distinguishable type
separate type-specific parameters
single Stan model
mixed-composition post-processing
```

## 13.4 Package-safety principle

Every generated model should be reproducible and inspectable.

The package should always allow users to inspect:

```r
stancode(fit)
standata(fit)
prior_summary(fit)
preprocessing_report(fit)
dyad_registry(fit)
```

Do not hide generated code. This is especially important because the models are specialized and users will need to understand assumptions.

---

# 14. Minimal package directory sketch

A possible package organization:

```text
R/
  dyad_var.R
  spec.R
  registry.R
  validate.R
  data-prep.R
  design-matrices.R
  stan-generate.R
  priors.R
  fit.R
  postprocess.R
  diagnostics.R
  simulate.R
  plot.R
  print.R

inst/stan/templates/
  exchangeable_intercept_only.stan
  exchangeable_fixed_x.stan
  exchangeable_random_intercept.stan
  exchangeable_random_slope.stan
  distinguishable_basic.stan
  mixed_composition_basic.stan

inst/stan/functions/
  ar1_helpers.stan
  var_helpers.stan
  covariance_helpers.stan
  loglik_helpers.stan

tests/testthat/
  test-metadata-validation.R
  test-idiff-label-invariance.R
  test-design-matrices.R
  test-stancode-compiles.R
  test-exchangeable-recovery.R
  test-distinguishable-recovery.R
  test-stationarity-diagnostics.R
  test-loglik-agreement.R

vignettes/
  exchangeable-dyads.Rmd
  distinguishable-dyads.Rmd
  mixed-dyad-types.Rmd
  simulation-recovery.Rmd
  priors-and-diagnostics.Rmd
```

---

# 15. Final roadmap summary

The project is feasible and sensible if implemented as a staged Gaussian dyadic residual VAR package.

The core implementation path is:

```text
1. Build simulators and validation tools.
2. Implement exchangeable Gaussian balanced models.
3. Use a joint two-member transition as the canonical dynamic kernel.
4. Use orthonormal sum-difference coordinates as the exact exchangeable Gaussian specialization.
5. Treat rho as rho_innov, not marginal residual correlation.
6. Report rho_marginal separately.
7. Use stationary initial likelihood for exchangeable models.
8. Use block-diagonal shared/difference random-effect covariance for exchangeable dyads.
9. Implement distinguishable role-ordered VAR with regularizing priors and posterior stationarity checks.
10. Build transition-record preprocessing before serious missing-data support.
11. Implement mixed-composition models without partial pooling.
12. Add partial pooling only after separate type-specific mixed-composition models are validated.
13. Add one-partner missingness and DSEM-style extensions only after the core package is stable.
14. Treat non-Gaussian dynamics as a separate model-class design gate rather than a family substitution.
```

The central conceptual distinction is:

```text
shared architecture:
  stacked long member/equation mean-model layer
  paired two-member transition or state layer
  separate transition and observation kernels
  distinct member and substantive-process indices

exchangeable dyads:
  label-invariant actor/partner dynamics
  sum-difference diagonalization
  shared/difference random effects
  no arbitrary role ordering

distinguishable dyads:
  role-specific actor inertia
  directional partner carryover
  role-specific random effects
  role-ordered data representation

mixed-composition models:
  dyad-type registry determines which constraints apply
  type-specific parameters first
  partial pooling later
```

Custom Stan should reuse the equation-design and parameter-sharing ideas
demonstrated by multivariate interfaces such as `brms`. Its justification is the
explicit joint residual transition process, exchangeability-safe parameter maps,
mixed-composition support, and later state or missingness extensions—not the use
of different surface syntax.
