# Current off-the-shelf options for serial dependence in dyadic ILD

**Date:** 2026-07-16  
**Scope:** Gaussian, two-member intensive longitudinal APIM/DIM models  
**Software checked:** `glmmTMB` 1.1.15 and `brms` 2.23.0

This note deliberately excludes the unmerged `separable()`/Kronecker code. It
uses only released, documented `glmmTMB` structures (`us`, `ar1`) and public
`brms` functionality.

## Short answer

A pooled AR(1) is possible despite having two observations per couple and
occasion. The AR grouping unit must be the **member series**, not the couple:

```r
d$day_f <- factor(d$diaryday, levels = full_day_sequence)
d$member_series <- interaction(d$coupleID, d$personID, drop = TRUE)

ar1(0 + day_f | member_series)
```

There is only one observation per `day_f` within each `member_series`.
`glmmTMB` gives every member series an independent latent AR process while
pooling the same stationary variance and the same AR coefficient over all
series. The two partner rows at a couple-occasion therefore cause no duplicate
time problem.

The inline grouping expression
`ar1(0 + day_f | coupleID:personID)` defines the same grouping partition and
therefore the same statistical model. Precomputing `member_series` only makes
the factor explicit and easier to inspect, reuse, and validate. If `personID`
is already globally unique and each person belongs to exactly one couple,
`ar1(0 + day_f | personID)` is sufficient.

My recommended common strategy is:

1. For a **concurrent APIM/DIM**, retain the stable and same-day dyadic
   covariance blocks and add this pooled member-series AR(1). Use
   couple-clustered robust standard errors as a sensitivity analysis.
2. If own- and partner-outcome carryover are substantive, fit the existing
   **lagged-outcome APIM/VAR** with both members' prior outcomes instead.
3. If the goal is a concurrent mean model plus a **full residual dyadic VAR**,
   neither released `glmmTMB` nor an ordinary `brms` formula supplies the full
   distinguishable and exchangeable model family. That still requires custom
   Stan/TMB or software such as Mplus.

The pooled member AR is a useful working covariance, but it is not a hidden
full VAR: it contains no decaying cross-partner residual covariance.

## Recommended concurrent `glmmTMB` models

### Distinguishable dyads

Using generic `female` and `male` 0/1 indicators:

```r
fit_d <- glmmTMB::glmmTMB(
  y ~ 0 + female + male +
    # actor/partner predictors and time terms ...

    # Stable role-specific covariance
    us(0 + female + male | coupleID) +

    # Pooled within-member AR(1)
    ar1(0 + day_f | member_series) +

    # Unrestricted same-day role covariance
    us(0 + female + male | coupleID:diaryday),

  dispformula = ~ 0,
  family = gaussian(),
  data = d
)
```

This estimates eight covariance parameters:

| Component | Parameters |
|---|---:|
| Stable role-specific `us` | 3 |
| Pooled member AR(1): variance and rho | 2 |
| Same-day role-specific `us` | 3 |
| **Total** | **8** |

Separate female and male AR terms would estimate four rather than two AR
parameters, for ten covariance parameters in total. That may be a useful
distinguishable-dyad extension, but the pooled term is the clean common
restriction shared with the exchangeable model.

### Exchangeable dyads

Let `diff` be the existing stable arbitrary member sign, coded `-1/+1` within
each couple (for example,
`.i_diff_assumed_exchangeable_arbitrary`). Then use the current independent
mean-and-difference blocks:

```r
fit_e <- glmmTMB::glmmTMB(
  y ~ 1 +
    # pooled actor/partner predictors and time terms ...

    # Stable exchangeable covariance
    us(1 | coupleID) +
    us(0 + diff | coupleID) +

    # The same pooled within-member AR(1)
    ar1(0 + day_f | member_series) +

    # Exchangeable same-day covariance
    us(1 | coupleID:diaryday) +
    us(0 + diff | coupleID:diaryday),

  dispformula = ~ 0,
  family = gaussian(),
  data = d
)
```

This estimates six covariance parameters:

| Component | Parameters |
|---|---:|
| Stable mean and difference variances | 2 |
| Pooled member AR(1): variance and rho | 2 |
| Same-day mean and difference variances | 2 |
| **Total** | **6** |

Flipping the arbitrary member labels flips `diff` and permutes two identically
distributed member AR processes. The likelihood is unchanged, so this remains
an exchangeable model.

### Covariance that these models actually imply

Let `B` be the stable member covariance, `W` the same-day covariance, and let
the pooled member AR process have stationary variance `v_AR` and coefficient
`rho`. For members `j` and `k` and occasions `t` and `u`, the model implies

$$
\operatorname{Cov}(Y_{jt},Y_{ku})
= B_{jk}
+ I(j=k)v_{AR}\rho^{|t-u|}
+ I(t=u)W_{jk}.
$$

The `ar1()` term itself estimates only `v_AR` and `rho`; it does **not** contain
its own additional white-noise variance. A Gaussian `glmmTMB` model normally
also estimates an independent dispersion variance, but `dispformula = ~0`
turns that component off (up to the package's negligible numerical constant).

Computationally, the member AR effect and the same-day `us` effect are two
independent latent random-effect blocks. The total within-dyad residual is their
sum. For the time-major ordering

$$
(Y_{1,1},Y_{2,1},Y_{1,2},Y_{2,2},\ldots,Y_{1,T},Y_{2,T})',
$$

the complete marginal covariance is one `2T` by `2T` matrix,

$$
\Sigma
= J_T \otimes B
+ v_{AR}R_T(\rho) \otimes I_2
+ I_T \otimes W,
$$

where `J_T` is an all-ones matrix and `R_T(rho)` is the AR(1) correlation
matrix. Conditional on the stable couple effects, omit the first term. Thus the
working covariance is a **sum of Kronecker products**, not the single product
`R_T(rho) %x% W`.

Equivalently, excluding the stable component, its lag-`h` covariance block is

$$
\Gamma_h = v_{AR}\rho^h I_2 + I(h=0)W.
$$

Pooling means that all member series share `v_AR` and `rho`; it does not
correlate the two partners' AR realizations.

Thus:

- the same member has a stable component plus decaying AR dependence;
- partners have the stable covariance at every lag;
- partners have an additional covariance on the same day; and
- there is **no decaying cross-partner residual covariance** after the stable
  component is removed.

This last restriction is the price of the simple common formulation. A true
bivariate VAR with correlated innovations generally propagates a partner shock
into later cross-partner covariance.

### Why `dispformula = ~ 0` is retained

The same-day `us` or mean/difference block already supplies the remaining
occasion-specific member variances as well as their covariance. A separate
Gaussian dispersion variance would add another diagonal-only component and
make the decomposition less identifiable. With `dispformula = ~0`, total
same-day member variance is the AR variance plus the diagonal of `W`.

Identification can nevertheless be weak:

- if `rho` is near zero, AR variance is hard to distinguish from the same-day
  diagonal variance;
- if `rho` is near one, AR variance is hard to distinguish from stable member
  intercept variance; and
- short series or a rich random-slope structure can make both problems worse.

The time variable must be a factor with the full scheduled sequence explicitly
retained. Otherwise missing days can be treated as adjacent factor levels.

### Small simulation check

I tested the released formula on Gaussian data with 120 dyads and 14
occasions, using an unrestricted same-day covariance and independent member AR
processes. The Hessian was positive definite. For an AR standard deviation of
0.72 and `rho = 0.52`, the fitted values were 0.695 and 0.532. The same-day
covariance components were also recovered reasonably. This establishes that
the proposed five-parameter AR-plus-same-day block is estimable under favorable
conditions; it does not remove the boundary-identification cautions above.

## Two useful additions, neither a full solution

### A shared couple AR process

This released syntax is also valid:

```r
ar1(0 + day_f | coupleID)
```

Here the duplicate couple-day rows are intentional: both partners load on the
same latent value. This is a serial **common shock**, not a pooled member AR.
Combining it with the member-series AR gives

$$
\Gamma_h = v_C\rho_C^h J + v_P\rho_P^h I,
$$

where `J` is a 2 by 2 matrix of ones. It adds two parameters and provides
positive, symmetric cross-partner serial covariance. It is a plausible
sensitivity model when a common-shock interpretation is defensible, but its
equal loadings and rank-one partner process are restrictive. Combining stable,
same-day, shared-AR, and person-AR components may also be difficult to identify.

### Couple-clustered robust inference

Current released `glmmTMB` provides cluster-robust HC0 covariance estimates for
ML fits:

```r
fit_ml <- update(fit_d, REML = FALSE)

V_CR0 <- glmmTMB::vcovHC(
  fit_ml,
  cluster = factor(d_used$coupleID)
)
```

All random-effect groups must be nested within the couple cluster, and
`d_used` must contain exactly the rows used in the model. Under independent
couples, a correct Gaussian conditional mean, and exogenous predictors, these
standard errors are asymptotically robust to remaining within-couple serial and
cross-partner covariance misspecification.

They do not repair endogeneity, omitted temporal dynamics, covariance
estimates, likelihood comparisons, or predictions. Only HC0 is currently
available. With about 38-40 couples, it should be reported beside the
model-based result as a sensitivity analysis, not used as the only inferential
guarantee. A whole-couple bootstrap is a useful further sensitivity check.

#### Is clustered inference an alternative to modeling AR(1)?

For one narrow target, yes. In a Gaussian model with a correctly specified
conditional mean, exogenous predictors, and independent couples, a
couple-clustered sandwich estimator permits arbitrary remaining correlation
among all observations from the same couple. It can therefore provide
asymptotically valid fixed-effect standard errors without correctly specifying
whether that dependence is AR(1), a partner cross-lag process, or something
more complicated. It uses the empirical variation of the couple-level score
vectors; it does not estimate the within-couple covariance itself.

It is not a general replacement for an AR or VAR model. In particular, it does
not:

- estimate serial or cross-partner dependence;
- improve longitudinal predictions or estimate their uncertainty correctly;
- make likelihoods, AIC, covariance parameters, or random-effect predictions
  robust;
- recover efficiency that a reasonably correct covariance model can provide;
  or
- remove fixed-effect bias when an omitted dynamic process belongs in the mean
  or is associated with the predictors.

The two approaches can be combined. Fit the most defensible working covariance
(here, pooled member AR plus same-day covariance), then compute
couple-clustered SEs from that same ML fit. Agreement between the model-based
and clustered results is reassuring; disagreement indicates that inferential
conclusions depend on the working covariance and should be investigated.

For the present workshop design, with only about 40 independent couples, the
recommended hierarchy is:

1. Use the pooled-member AR plus same-day covariance as the primary concurrent
   Gaussian model when it is identifiable and converges cleanly.
2. Show couple-clustered HC0 SEs beside its model-based SEs as a sensitivity
   analysis.
3. If the AR component is weakly identified or prevents convergence, a simpler
   concurrent model with couple-clustered SEs is a defensible fallback for
   fixed-effect inference, but not a fitted model of temporal dependence.
4. For confirmatory inference, supplement HC0 with a nonparametric bootstrap
   that resamples and reindexes whole couples; a parametric bootstrap from the
   misspecified covariance model would not provide the same robustness.
5. If temporal carryover is substantively relevant, specify the lagged mean or
   residual process. Neither clustered SEs nor a nuisance AR term answers that
   question.

## When temporal carryover is the research question

Use a lagged-outcome APIM rather than hiding dynamics inside an AR covariance.
In long format, include both the actor's and partner's prior outcomes and retain
the same-day covariance block.

For distinguishable dyads, role-specific lag terms estimate

$$
A_D =
\begin{pmatrix}
a_F & p_F \\
p_M & a_M
\end{pmatrix},
$$

with four transition coefficients. The same-day innovation covariance has
three parameters and the stable covariance has three, for ten
dynamic/covariance parameters in total.

For exchangeable dyads, pooled actor and partner lags estimate

$$
A_E =
\begin{pmatrix}
a & p \\
p & a
\end{pmatrix}.
$$

There are two transition, two same-day innovation, and two stable covariance
parameters, again six in total. This is the full VAR(1) within the relevant
exchangeability class.

This solution works in the existing `glmmTMB` APIM/DIM framework, but it answers
a different question: every concurrent predictor coefficient is conditional
on both partners' prior outcomes. It also retains the initial-condition,
random-intercept endogeneity, and small-`T` cautions documented in
[`ild-nonindependence.md`](ild-nonindependence.md). Check stationarity explicitly;
`glmmTMB` does not enforce it. For the exchangeable model, both
`abs(a + p) < 1` and `abs(a - p) < 1` are required.

## What `brms` can and cannot improve

The ordinary wide two-response `brms` model is not a satisfactory
exchangeable solution. `mvbind()` creates response-specific coefficients and
standard deviations; giving terms the same names correlates effects but does
not equate them. Moreover, covariance-form residual AR and an estimated
cross-response residual correlation cannot be combined directly.

Two other `brms` routes are possible:

1. A **long-format pooled person AR**,
   `ar(time = day, gr = member_series, p = 1, cov = TRUE)`, can be combined
   with long-format stable and couple-day random effects. It is the Bayesian
   analogue of the working covariance above, not a fuller dyadic AR. A simple
   shared couple-day intercept also restricts same-day partner covariance to be
   nonnegative. More flexible role or mean/difference occasion effects recreate
   the weak variance-decomposition problem and need informative priors.
2. For Gaussian complete pairs, transform each couple-day to an outcome mean
   and directed difference. Exchangeability then becomes independence of the
   mean and arbitrary-difference equations rather than equality constraints
   across named partner responses. This can fit a symmetric exchangeable
   residual dynamic model, and explicit mean/difference outcome lags can fit a
   full dynamic VAR for distinguishable dyads. The costs are a second data
   layout, Gaussian-only interpretation, loss of both transformed outcomes
   when one partner is missing, and more back-transformation.

`brms` also uses the supplied time variable primarily to order AR observations;
gaps are treated as the next observed occasion unless the complete time grid is
retained and missing responses are modeled. The explicit factor levels used by
`glmmTMB` are more convenient for the current daily examples.

The mean/difference `brms` route is worth keeping as an advanced Gaussian
option, especially given the APIM-DIM equivalence focus, but it is not a simpler
common workshop default than the long `glmmTMB` model.

## Decision for the workshop

| Goal | Recommended model | Qualification |
|---|---|---|
| Concurrent APIM/DIM; serial dependence is nuisance | `glmmTMB`: stable covariance + pooled member AR(1) + same-day covariance | Working covariance; no decaying partner residual covariance |
| Check sensitivity to covariance misspecification | Couple-clustered `vcovHC` beside model-based SEs | ML and HC0 only; about 40 couples is a modest cluster count |
| Own and partner carryover are substantive | Lagged-outcome APIM/VAR in `glmmTMB` | Changes concurrent estimands; dynamic-panel cautions remain |
| Full residual dyadic VAR while retaining the concurrent estimand | Custom Stan/TMB or Mplus | Not available as one released high-level `glmmTMB`/ordinary `brms` formula |
| Advanced Gaussian exchangeable dynamics | Mean/difference model in `brms` | Additional preprocessing, missing-pair and interpretation costs |

For the workshop I would therefore teach the pooled member-series AR as the
practical extension, show clustered SEs as a sensitivity analysis, and present
the lagged-outcome VAR only when introducing dynamics. I would state explicitly
that a full residual VAR/RDSEM is a future extension, already scoped in
[`stan.md`](stan.md).

## Appendix: implied residual covariance matrices

Use the time-major ordering

$$
\mathbf r =
(r_{1,1},r_{2,1},r_{1,2},r_{2,2},\ldots,r_{1,T},r_{2,T})'.
$$

Let the same-day member covariance be

$$
W=
\begin{pmatrix}
w_1 & w_{12} \\
w_{12} & w_2
\end{pmatrix},
$$

and let $R_T(\rho)$ denote the AR(1) correlation matrix whose $(t,u)$
entry is $\rho^{|t-u|}$. The formulas below assume
`dispformula = ~0` and initially condition on the stable couple effects.

### A. Pooled member-specific AR(1)

The latent representation is

$$
\mathbf r_t=\mathbf a_t+\mathbf w_t,
$$

where the two members' AR processes are independent but share the stationary
variance $v_A$ and coefficient $\rho_A$:

$$
\operatorname{Cov}(\mathbf a_t,\mathbf a_u)
=v_A\rho_A^{|t-u|}I_2,
$$

$$
\operatorname{Cov}(\mathbf w_t,\mathbf w_u)
=I(t=u)W.
$$

The compact covariance matrix is

$$
\boxed{
\Sigma_{\text{member AR}}
=v_A R_T(\rho_A)\otimes I_2
+I_T\otimes W
}.
$$

Its lag-zero block is

$$
\Gamma_0=v_AI_2+W
=
\begin{pmatrix}
v_A+w_1 & w_{12} \\
w_{12} & v_A+w_2
\end{pmatrix},
$$

whereas, for $h>0$,

$$
\Gamma_h=v_A\rho_A^hI_2
=
\begin{pmatrix}
v_A\rho_A^h & 0 \\
0 & v_A\rho_A^h
\end{pmatrix}.
$$

Thus, pooling gives both member series the same variance and AR coefficient; it
does not correlate their AR realizations. Cross-partner residual covariance
from $W$ occurs only on the same occasion.

For three occasions, writing $a=v_A$ and $r=\rho_A$ gives

$$
\Sigma_{\text{member AR}}=
\begin{pmatrix}
a+w_1 & w_{12} & ar & 0 & ar^2 & 0 \\
w_{12} & a+w_2 & 0 & ar & 0 & ar^2 \\
ar & 0 & a+w_1 & w_{12} & ar & 0 \\
0 & ar & w_{12} & a+w_2 & 0 & ar \\
ar^2 & 0 & ar & 0 & a+w_1 & w_{12} \\
0 & ar^2 & 0 & ar & w_{12} & a+w_2
\end{pmatrix}.
$$

### B. Shared dyadic/couple AR(1) process

For the shared process fitted by `ar1(0 + day_f | coupleID)`, write

$$
\mathbf r_t=\mathbf 1_2c_t+\mathbf w_t,
$$

where

$$
\operatorname{Cov}(c_t,c_u)=v_C\rho_C^{|t-u|}.
$$

With

$$
J_2=\mathbf 1_2\mathbf 1_2'
=
\begin{pmatrix}
1&1\\
1&1
\end{pmatrix},
$$

the compact covariance matrix is

$$
\boxed{
\Sigma_{\text{couple AR}}
=v_C R_T(\rho_C)\otimes J_2
+I_T\otimes W
}.
$$

The lag-zero block is

$$
\Gamma_0=v_CJ_2+W
=
\begin{pmatrix}
v_C+w_1 & v_C+w_{12} \\
v_C+w_{12} & v_C+w_2
\end{pmatrix},
$$

and, for $h>0$,

$$
\Gamma_h=v_C\rho_C^hJ_2
=
\begin{pmatrix}
v_C\rho_C^h & v_C\rho_C^h \\
v_C\rho_C^h & v_C\rho_C^h
\end{pmatrix}.
$$

This is a serial common-shock component: both partners load identically on the
same latent process, producing equal covariance for every member pairing at a
given lag.

For three occasions, writing $c=v_C$ and $q=\rho_C$ gives

$$
\Sigma_{\text{couple AR}}=
\begin{pmatrix}
c+w_1 & c+w_{12} & cq & cq & cq^2 & cq^2 \\
c+w_{12} & c+w_2 & cq & cq & cq^2 & cq^2 \\
cq & cq & c+w_1 & c+w_{12} & cq & cq \\
cq & cq & c+w_{12} & c+w_2 & cq & cq \\
cq^2 & cq^2 & cq & cq & c+w_1 & c+w_{12} \\
cq^2 & cq^2 & cq & cq & c+w_{12} & c+w_2
\end{pmatrix}.
$$

### C. Member and couple AR processes together

If both processes are included, the latent residual is

$$
\mathbf r_t=\mathbf a_t+\mathbf 1_2c_t+\mathbf w_t,
$$

and the compact covariance is

$$
\boxed{
\Sigma_{\text{combined}}
=v_A R_T(\rho_A)\otimes I_2
+v_C R_T(\rho_C)\otimes J_2
+I_T\otimes W
}.
$$

Its lag blocks are

$$
\Gamma_0=v_AI_2+v_CJ_2+W
$$

and

$$
\Gamma_h
=v_A\rho_A^hI_2+v_C\rho_C^hJ_2,
\qquad h>0.
$$

This combines independent within-member persistence, a persistent shared
couple shock, and additional same-day partner dependence. It is still a sum of
separable components rather than a general bivariate VAR covariance.

### D. Stable covariance and ordinary dispersion

If the role-specific stable random-intercept covariance is $B$, integrating
over those stable effects adds

$$
J_T\otimes B,
$$

where $J_T$ is the $T$ by $T$ all-ones matrix. Thus, for example,

$$
\Sigma_{\text{fully marginal}}
=J_T\otimes B+\Sigma_{\text{combined}}.
$$

If the Gaussian dispersion is estimated instead of setting
`dispformula = ~0`, it additionally contributes

$$
\sigma_e^2I_{2T}.
$$

## Sources

- [`glmmTMB` covariance vignette](https://glmmtmb.github.io/glmmTMB/articles/covstruct.html)
- [`glmmTMB` reference manual, including `vcovHC`](https://stat.ethz.ch/CRAN/web/packages/glmmTMB/refman/glmmTMB.html)
- [`brms` AR documentation](https://paulbuerkner.com/brms/reference/ar.html)
- [`brms` formula documentation](https://paulbuerkner.com/brms/reference/brmsformula.html)
- [Gistelinck and Loeys (2020), dyadic autoregressive models](https://doi.org/10.4473/TPM27.3.7)
- [Gistelinck, Loeys, and Flamant (2021), small-`T` autoregressive bias](https://doi.org/10.1080/10705511.2020.1753517)
- [Asparouhov and Muthen (2020), DSEM versus RDSEM](https://doi.org/10.1080/10705511.2019.1626733)
- [Del Rosario and West (2025), longitudinal dyadic random effects](https://doi.org/10.1177/25152459251351286)
