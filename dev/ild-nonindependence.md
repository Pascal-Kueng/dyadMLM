# Non-Independence in Intensive Longitudinal Dyadic Models

**Status:** analysis and tutorial design note. The concurrent-model guidance,
observed-person-mean caution, and concise dynamic-model limitations are now
implemented in the DIM vignette. Equivalent review of the APIM and planned DSM
ILD material remains open.

**Scope:** Gaussian and generalized intensive longitudinal dyadic data, with
particular attention to APIM, DIM, and DSM examples fitted outside
`dyadMLM`

This note records how the package documentation should discuss four distinct
sources of non-independence:

1. stable dependence between members of the same dyad;
2. same-occasion dependence between partner innovations;
3. serial dependence within each member over time; and
4. directional carryover from one member to the other over time.

These sources require different model terms. A random dyad effect does not by
itself model serial state dependence, and a lagged outcome does not by itself
model same-occasion partner dependence. Systematic trends and the reliability
of observed person means are additional issues that must be handled separately.

## Executive Recommendations

| Research goal | Recommended approach | Main qualification |
|---|---|---|
| Estimate concurrent within- and between-person actor/partner associations | Decompose substantive time-varying predictors into `cwp` and `cbp` components; include appropriate time trends, stable dyadic covariance, and same-occasion partner covariance | Observed person means may be imprecise estimates of longer-run levels when there are few occasions; serial residual dependence remains unless it is modeled separately |
| Treat serial dependence mainly as nuisance | Prefer a residual dynamic model, such as a dyadic residual VAR(1) or RDSEM | This is not expressed exactly by simply adding the observed lagged outcome to the mean model |
| Estimate average own-outcome carryover | Use a raw-lag parameterization rather than manifest person-mean centering; retain stable and same-occasion dyadic covariance | When $T$ is small, use a model that explicitly handles initial conditions and random-effect endogeneity; a conventional raw-lag MLM does not |
| Estimate partner-to-partner temporal carryover | Use a full dyadic VAR with both own- and partner-outcome lags | This extends the Gistelinck-Loeys LD-APIM, which includes only own-outcome lags |
| Estimate dynamics with very small $T$ | Use a model that explicitly handles the first outcome and its dependence on stable person effects, such as NC-ENDO or a suitable latent-centering SEM | There is no universal safe minimum $T$; ordinary convergence diagnostics do not diagnose this bias |
| Fit generalized outcomes such as negative-binomial counts | Keep the main tutorial concurrent unless a correctly specified generalized or latent dynamic model is available | Lagging the observed response is not generally equivalent to modeling dynamics on the latent or link scale |

The choice between a structural lagged-outcome model and a residual dynamic
model must be driven by the estimand. Adding a lagged outcome changes all other
coefficients into effects conditional on the prior outcome. It should not be
presented as a neutral standard-error correction.

## 1. Decomposing Dyadic Non-Independence

For dyad $j$, member $m$, and occasion $t$, write

```text
y_jmt = mean_jmt + residual_jmt
```

The following components should be considered separately.

### 1.1 Stable dyadic dependence

Partners may have correlated stable outcome levels. For distinguishable dyads,
this can be represented by correlated role-specific random intercepts. For
exchangeable dyads, the equivalent sum-difference representation uses a shared
dyad intercept and an arbitrary member-difference effect, with the constraints
required for label invariance.

This covariance represents stable non-independence. It does not represent
short-lived same-occasion shocks or serial carryover.

### 1.2 Same-occasion partner dependence

After conditioning on the mean model and previous states, partners can still
experience correlated innovations on the same occasion. In a Gaussian model,
the two innovations can be modeled as

```text
epsilon_jt ~ MVN(0, Omega)
```

where `Omega` contains both role-specific innovation variances and their
same-occasion covariance. Reserve "innovation covariance" for a fitted dynamic
model. In the current concurrent long-format Gaussian examples, a role-specific
dyad-occasion covariance block instead represents same-occasion residual
dependence in a working model that omits the serial process. For generalized
outcomes, an occasion-level random-effect block is on the latent/link scale and
is not an ordinary residual covariance matrix.

### 1.3 Own-person serial dependence

An own-outcome lag models state dependence:

```text
y_jmt = ... + rho_m * y_jm,t-1 + epsilon_jmt
```

The coefficient `rho_m` describes carryover conditional on the other model
terms. It is not interchangeable with a random intercept: the random intercept
captures stable heterogeneity, whereas the lag captures dependence on the
immediately preceding state.

### 1.4 Cross-partner serial dependence

A full dyadic transition model also includes the partner's prior outcome:

```text
y_j1t = ... + phi_11 * y_j1,t-1 + phi_12 * y_j2,t-1 + epsilon_j1t
y_j2t = ... + phi_21 * y_j1,t-1 + phi_22 * y_j2,t-1 + epsilon_j2t
```

The diagonal paths are own-person inertia. The off-diagonal paths are
directional partner carryover. Together they form a dyadic VAR(1) transition
matrix. These paths are distinct from same-occasion innovation covariance.

## 2. What the Key Papers Establish

The recommendations below combine three closely related papers rather than
treating any one result as sufficient by itself.

### 2.1 Hamaker and Grasman: centering a lagged outcome is exceptional

Hamaker and Grasman (2015, abstract) conclude that

> "cluster mean centering will in general lead to a downward bias"

when the centered level-1 predictor is the lagged outcome. In their simulations,
person-mean centering underestimated the average autoregressive coefficient,
with more severe bias at smaller $T$. Increasing the number of people did not
remove the bias. The result persisted when centering used the observed person
mean, an empirical-Bayes estimate, or even the true generating equilibrium
(Tables 3-4, pp. 7-9). It is therefore not merely a consequence of an
unreliable observed person mean.

For the population-average autoregressive effect, their uncentered-lag model
performed better. However, when a level-2 variable was used to explain
individual differences in inertia, the centered parameterization performed
better for that cross-level interaction (Table 5, pp. 9-10). They consequently
recommend the centered parameterization when a directly meaningful intercept
representing the person's mean is the target as well. The parameterization
should therefore follow the research target; when several of these targets
matter, they recommend using both analyses for their respective parameters.

Their special advice applies only to an outcome used as its own lagged
predictor. They explicitly retain the conventional within-between decomposition
recommendation for ordinary time-varying predictors (p. 11).

Limits of this evidence:

- the simulation is univariate rather than dyadic;
- it studies own-outcome lags, not partner-outcome lags;
- it assumes an equally spaced stationary Gaussian process;
- it does not evaluate modern DSEM latent centering or explicit initial-condition
  corrections; and
- its main sample-size investigation starts at $T=20$.

### 2.2 Gistelinck, Loeys, and Flamant: raw lags alone do not solve small-T bias

Gistelinck, Loeys, and Flamant (2021) distinguish three problems:

1. manifest centering of a lagged outcome introduces Nickell bias;
2. the lagged outcome is endogenous because the stable random intercept affects
   every outcome, including the lag; and
3. the first observed response depends on an unavailable presample response.

They compare four main implementations of a simple stationary Gaussian
multilevel AR(1):

| Label | Implementation | Key assumption |
|---|---|---|
| `NC-EXO` | Raw lag plus random intercept in an ordinary MLM | The lag, including the first observed outcome, is independent of the random intercept |
| `CMC` | Person-mean-centered lag plus random intercept | The lag is centered by the observed person mean while a random intercept remains |
| `NC-ENDO` | Raw lag in SEM, with the first outcome correlated with the random intercept | The first outcome is predetermined but endogenous |
| `LC-ENDO` | Latent within-between centering, including DSEM variants | The treatment of the first or presample outcome depends on the implementation |

Their abstract states that, when the first outcome is treated as predetermined,

> "the no centering approach assuming endogeneity performs best."

In simulations with $N=50$, $T=4,6,...,20$, a fixed autoregressive
coefficient, no covariates, and no trend (Figures 6 and 8, pp. 22-25):

- `CMC` remained negatively biased through $T=20$;
- naive `NC-EXO` performed especially poorly below about six occasions, often
  collapsing the random-intercept variance toward zero;
- `NC-ENDO` removed the corresponding endogeneity bias in their data-generating
  conditions;
- default Mplus DSEM was biased below about ten occasions and showed substantial
  convergence problems at four occasions; follow-up analyses largely traced
  this behavior to treatment of the auxiliary presample outcome, although the
  Bayesian variance priors also mattered; and
- a maximum-likelihood latent-centering model that began the process at the
  first observed response (`ML-LC-ENDO-1`) also performed well.

Most non-CMC methods met the authors' relative-bias criterion by approximately
$T=10$ in this simulation. This is not a universal threshold. The model had one
Gaussian outcome, homogeneous fixed dynamics, no time-varying predictors, no
missingness, no trends, and no dyadic cross-lags. The authors explicitly warn
that more complex dynamic models may demand more information.

This paper therefore qualifies, rather than contradicts, Hamaker and Grasman:

- both show downward bias from person-mean centering a lagged outcome;
- both show that increasing $N$ does not repair that bias;
- Hamaker and Grasman's raw-lag result applies in the range where Gistelinck et
  al. also find little naive-MLM bias; and
- Gistelinck et al. show why a plain raw lag plus random intercept can still be
  biased when $T$ is very small.

### 2.3 Gistelinck and Loeys: the dyadic LD-APIM

Gistelinck and Loeys (2020, Equations 1-4, pp. 435-438) propose the
lagged-dependent APIM for distinguishable dyads:

```text
Y_1t = alpha_1 + b_1j + rho_1 * Y_1,t-1
        + actor effects of X_1 + partner effects of X_2 + epsilon_1t

Y_2t = alpha_2 + b_2j + rho_2 * Y_2,t-1
        + actor effects of X_2 + partner effects of X_1 + epsilon_2t
```

The model includes:

- raw, role-specific own-outcome lags;
- separate time-averaged and time-specific actor and partner effects of the
  substantive predictor;
- correlated role-specific random intercepts;
- correlated same-occasion partner innovations; and
- fixed autoregressive, actor, and partner slopes.

For ordinary time-varying predictors, the authors state (p. 437):

> "we strongly recommend splitting up the effect of time-varying predictors"

into time-averaged and time-specific components. This directly supports
`dyadMLM`'s `time_2l` decomposition for substantive predictors. In their
discussion, however, they acknowledge that manifest person means introduce
measurement error into time-averaged effects and identify latent centering as a
possible remedy (pp. 449-450).

Despite its name, their LD-APIM is implemented as a wide-format SEM in `lavaan`,
not as an ordinary long-format MLM. They choose SEM because it can give the
first outcome its own mean and variance and correlate it with the corresponding
random intercept. Their proposed small-$T$ dyadic implementation is therefore
an `NC-ENDO` model, not the naive `NC-EXO` model fitted by

```r
y ~ lag(y) + (1 | person)
```

The paper focuses on distinguishable dyads, while its application can impose
constraints for exchangeable dyads. The LD-APIM contains no partner-outcome
lag. Its "partner effects" are effects
of the partner's substantive predictor. Adding the partner's prior outcome
creates a fuller dyadic VAR model and requires additional evidence and model
validation.

The LD-APIM also assumes equal spacing, synchronized observations, stationary
and time-invariant parameters, continuous outcomes, and no time trend by
default. Random dynamic and predictor slopes are omitted to reduce convergence
problems, although omitting real slope heterogeneity can distort standard
errors.

## 3. Decisions by Research Case

### Case A: concurrent actor and partner associations are primary

Use this strategy when the substantive questions concern whether changes in a
predictor coincide with changes in the actor's or partner's outcome, rather
than whether one outcome state carries into the next.

Recommended mean model:

1. decompose each substantive time-varying predictor into `cwp` and `cbp`;
2. include an appropriate function of time;
3. include the required actor/partner, DIM, or DSM terms;
4. represent stable partner dependence with dyad-level random effects; and
5. represent same-occasion partner dependence with a residual dyad-occasion
   covariance block in the concurrent working model.

If serial dependence is primarily nuisance, one coherent complete model is a
residual dynamic model:

```text
y_jt = mu_jt + r_jt
r_jt = A * r_j,t-1 + epsilon_jt
epsilon_jt ~ MVN(0, Omega)
```

This is a dyadic residual VAR(1), conceptually closer to RDSEM than to a DSEM
that regresses the observed outcome directly on its lag. It keeps the
contemporaneous mean model and residual dynamics conceptually separate.

Why this recommendation follows from the evidence:

- Hamaker and Grasman distinguish residual autocorrelation as nuisance from a
  substantively interpreted lagged outcome.
- Asparouhov and Muthen (2020) make the corresponding DSEM-RDSEM distinction:
  DSEM places dynamics in the structural variables, whereas RDSEM places them
  in residuals.
- Adding an observed outcome lag changes the interpretation of every predictor
  coefficient and is therefore not a neutral replacement for residual
  covariance modeling.

Current limitation: the full partner-by-time residual VAR with correlated
innovations is not represented cleanly by the standard high-level R formulas
used in the vignettes. The planned custom Stan model in [`stan.md`](stan.md) is
the intended long-term solution.

### Case B: own-outcome carryover is a substantive parameter

When the target is the average carryover or inertia coefficient, use a raw-lag
parameterization rather than manifest person-mean centering. The outcome may be
included in `predictors` under `time_2l` to create all model-specific columns,
but lag and use the raw columns for this parameterization. Do not describe a
person-mean-centered outcome lag as an unbiased within-person dynamic effect.
When $T$ is small, the estimator must also address initial conditions and
random-effect endogeneity.

Retain all other dependence components:

- stable dyad-member covariance;
- same-occasion innovation covariance;
- within-between decomposition of ordinary predictors; and
- a substantively appropriate time trend.

The resulting actor and partner predictor effects are conditional on the prior
outcome. The raw-lag intercept is also conditional on a prior outcome of zero.
For the simple role-specific AR(1) model, with all other predictors held at
zero, the equilibrium is `intercept / (1 - rho_r)`. With trends, interactions,
or time-varying predictors, an equilibrium interpretation is more complicated
and should not be inferred from that simple formula.

For sufficiently informative series, a standard raw-lag MLM can be presented as
a practical lag-adjusted dynamic model. It must not be described as the
small-$T$ bias-corrected model recommended by Gistelinck et al.

### Case C: cross-partner temporal influence is substantive

Include both own- and partner-outcome lags only when directional partner
carryover is itself a research target. This gives a full 2 by 2 transition
matrix rather than the restricted LD-APIM of Gistelinck and Loeys.

The model should also allow same-occasion innovation covariance unless zero
covariance is substantively justified. This represents remaining
contemporaneous dependence and affects joint uncertainty, but it is distinct
from the lagged transition paths. Temporal precedence does not by itself
justify causal language; omitted time-varying common causes and measurement
timing remain relevant.

For distinguishable roles, the transition matrix can be unrestricted. For
exchangeable dyads, label invariance requires equal own-lag paths and equal
partner-lag paths:

```text
A = [phi  psi]
    [psi  phi]
```

In the sum-difference basis, the shared dyad mode has autoregression
`phi + psi`, while the member-difference mode has autoregression `phi - psi`.
This is the dynamic analogue of APIM-DIM reparameterization.

Gistelinck and Loeys' own-lag-only role model is a restricted special case. If
the two role-specific own-lag coefficients differ, transforming to DSM outcome
mean (M=(Y_1+Y_2)/2) and difference (D=Y_1-Y_2) gives

```text
M_t = ((rho_1 + rho_2) / 2) * M_t-1
      + ((rho_1 - rho_2) / 4) * D_t-1

D_t = (rho_1 - rho_2) * M_t-1
      + ((rho_1 + rho_2) / 2) * D_t-1
```

Thus even role-specific own inertia induces DSM level-difference cross-paths.
A full dyadic VAR adds the remaining directional transition freedom.

### Case D: generalized outcomes

Do not assume that lagging an observed non-Gaussian response models the same
dynamic process as a Gaussian outcome lag or a latent residual AR process. For
example, a lagged observed count is not interchangeable with a dynamic process
on its latent log-mean scale.

Until a validated generalized dynamic model is available, the tutorial should:

- retain concurrent negative-binomial actor/partner examples;
- model stable and same-occasion dependence on the link scale carefully;
- avoid calling a lagged-response GLMM a VAR; and
- state that serial dependence is not fully modeled when that is true.

## 4. Small T: What to Do and What Not to Claim

### 4.1 There is no universal cutoff

The Gistelinck et al. simulation provides useful landmarks, not design rules.
Its approximately six- and ten-occasion findings apply to a simple stationary
Gaussian AR(1) with a fixed autoregressive coefficient and no covariates.

The current example series of 14 occasions should not be declared safe merely
because `14 > 10`. Dyadic covariance, missingness, time trends, multiple
predictors, role differences, cross-lags, and random slopes all require
additional information. Random dynamic parameters generally require many more
occasions than a fixed average dynamic parameter.

### 4.2 Preferred approaches when T is small

If dynamic effects are substantively interpreted and $T$ is small:

1. do not person-mean center the lagged outcome as a default correction;
2. do not assume that a raw lag plus random intercept solves endogeneity;
3. model the first outcome and its relationship with stable person effects;
4. prefer an `NC-ENDO` SEM when the raw-lag parameterization is acceptable;
5. prefer a validated latent-centering SEM when the equilibrium itself is a
   target; and
6. keep dynamic slopes fixed unless the design supports individual or dyad
   variation in them.

In the dyadic `NC-ENDO` model, each role's first outcome receives its own mean
and variance and is allowed to correlate with the corresponding stable random
intercept. A plain `glmmTMB` or `lme4` raw-lag formula does not directly fit that
joint model. A conditional long-format translation may be possible, but it
should be derived and validated by simulation before appearing in the tutorial.

If the tutorial nevertheless shows a standard raw-lag MLM, call it a
"lag-adjusted dynamic multilevel model" and state that short-series estimates
may remain biased because the model does not fully address either the initial
observation or its dependence on stable person effects. Absence of a
convergence warning is not evidence that this bias is absent.

### 4.3 Time and observation spacing

Each ILD model should include a substantively appropriate function of time. In
the current examples, `diaryday` accounts for a common linear trend; interactions
with role indicators allow distinguishable role-specific linear trends.

Describe this as accounting for a specified linear trend, not as completely
"detrending the data." Nonlinear, cyclical, person-specific, and predictor-
specific trends may require richer terms. A time covariate does not fix Nickell
bias, random-effect endogeneity, or the initial-conditions problem.

Discrete-time lags require equally spaced observations or an explicit model for
unequal intervals. Lag construction must not bridge an omitted scheduled
occasion. If the outcome at `t - 1` is missing, its lag at `t` is also missing;
silently using the previous available observation would change the lag length.

## 5. Observed Person Means: A Separate Small-T Problem

For an ordinary time-varying predictor $X$, `time_2l` constructs

```text
X_cwp = X_it - observed_person_mean_i
X_cbp = observed_person_mean_i - grand_mean_of_person_means
```

This remains the recommended manifest decomposition when within-person and
between-person associations may differ. It is supported by the general
centering literature and by Gistelinck and Loeys' LD-APIM.

However, the observed person mean is estimated from a finite number of
occasions. Gottfredson (2019, abstract) summarizes the consequence:

> "Unreliability inherent in person means generated with few observations results in downwardly biased between-person and cross-level interaction effect estimates."

The exact direction and size of bias can be more complicated in a dyadic model
because actor and partner means are correlated and enter together. The safe
user-facing statement is that between-person and cross-level estimates can be
biased, not that every coefficient is attenuated by a known amount.

The observed mean is the exact arithmetic mean of the recorded observations. It
need not equal the mean over all scheduled occasions when observations are
missing or sampled selectively, and it becomes an estimated quantity when
treated as the person's longer-run usual or trait level. Terminology in the
vignettes should therefore prefer "mean across the observed occasions" and
qualify references to a "usual level."

This observed-mean problem is different from Nickell bias:

| Problem | Affected construction | Does larger N solve it? | Main response |
|---|---|---|---|
| Unreliable observed person mean | `cbp` predictor and related between-person/cross-level effects | Not by improving each person's mean | More occasions, reliability adjustment, or latent centering; interpret longer-run level cautiously |
| Nickell bias | Person-mean-centered lagged outcome | No, when T remains fixed | Do not manifest-center the lag as the default average-carryover estimator |
| Random-effect endogeneity | Raw lag correlated with stable person effect | Not automatically | Model the initial outcome/random-intercept relationship or use a validated alternative |
| Initial conditions | Unobserved presample state | Not automatically | Specify how the first observation starts or conditions the process |
| Unmodeled serial residual dependence | Residuals remain correlated after the mean model | No | Use an appropriate residual AR/VAR or clearly acknowledge the limitation |

Person-mean centering also does not remove systematic temporal trends. Bolger
and Laurenceau (2013) treat within-between centering and time trends as separate
parts of an ILD model. The model should therefore include plausible time terms
even when the predictor has already been decomposed into `cwp` and `cbp`.

## 6. Current Package and Example-Data Consequences

### 6.1 Gaussian example data

The current Gaussian ILD generators use a residual dynamic process:

```text
y_t = mu_t + e_t
e_t = A * e_t-1 + innovation_t
```

with role-specific residual AR coefficients and correlated partner innovations,
but no directional partner cross-lag. The fitted counterpart is a residual VAR
or RDSEM-style model.

Adding a raw observed outcome lag instead gives

```text
y_t = mu_t + A * y_t-1 - A * mu_t-1 + innovation_t
```

so a formula containing `y_t-1` and only the current mean predictors omits the
corresponding lagged mean term. It is not the exact model that generated the
data.

The Gaussian `dyads_ild` example uses serially independent occasion effects,
so its concurrent fits align with the simulated residual structure. A future
dynamic recovery example should instead be generated from the structural
LD-APIM or dyadic VAR that it fits, or wait for the residual-VAR implementation.
Such an example should have enough occasions for its intended complexity,
assessed through model-specific simulation.

Simply adding raw outcome lags to every existing Gaussian example is not a clean
correction of the current data-generating process.

### 6.2 Negative-binomial example data

`dyads_nbinom_ild` does not simulate an explicit temporal process. Its tutorial
should remain concurrent unless a generalized dynamic simulation and its
fitted model are designed together. An observed-response lag would specify a
different model from a dynamic process on the latent log-mean scale.

### 6.3 APIM, DIM, and DSM equivalence

APIM-DIM or APIM-DSM equivalence is preserved only when the compared models use
the same:

- time terms;
- own- and partner-lag structure;
- within-between predictor decomposition;
- stable random-effect covariance; and
- same-occasion innovation covariance.

Changing the lag structure while changing parameterization would compare
different models rather than demonstrate an algebraic transformation.

## 7. Recommended Vignette Policy

### 7.1 Shared ILD wording

Every ILD section should include the first two notes below, plus the
lagged-outcome note wherever outcome lags are used.

**Time trend**

> The model includes diary day to account for a systematic linear trend. More
> complex temporal patterns require a correspondingly richer function of time.

**Observed person means**

> These components use each member's mean across the observed occasions. With
> few occasions, that observed mean can be an imprecise estimate of the member's
> longer-run usual level, particularly when measurements contain substantial
> occasion-specific variation. Between-person estimates should therefore be
> interpreted cautiously.

**Lagged outcomes, only where used**

> Outcome lags require different treatment from ordinary time-varying
> predictors. Person-mean centering a lagged outcome can underestimate average
> carryover, especially with few occasions, whereas a raw lag in a conventional
> mixed model does not fully address the initial observation or its dependence
> on stable person effects. The lagged terms here are therefore practical
> conditional adjustments, not bias-free estimates of individual dynamics.

The prose should remain brief in the vignette. The fuller methodological
explanation belongs in one linked advanced section or this development note.

### 7.2 Naming the fitted model accurately

Use these labels consistently:

- **concurrent ILD MLM** when no lagged outcome or residual dynamic structure is
  fitted;
- **lag-adjusted dynamic MLM** for a conventional raw-lag mixed model;
- **LD-APIM** for the Gistelinck-Loeys structure with raw own-outcome lags and
  actor/partner effects of substantive predictors;
- **dyadic VAR(1)** when both own- and partner-outcome lags are included;
- **residual dyadic VAR(1)** or **RDSEM-style model** when the transition process
  is applied to residuals after the mean model; and
- **DSEM** only for a model that actually uses the relevant dynamic structural
  equation framework, not as a generic synonym for any lagged MLM.

### 7.3 Immediate versus longer-term recommendation

For the current high-level R tutorial, this policy is implemented in the DIM
vignette and should guide the remaining APIM and DSM review:

- retain `time_2l` for ordinary predictors;
- include appropriate time trends;
- represent stable and same-occasion dyadic covariance;
- state that concurrent models do not add residual serial dependence and that
  this assumption must be assessed in users' data;
- do not add manifest-centered outcome lags;
- if raw lags are shown, present the model as a practical lag-adjusted MLM and
  include the small-$T$ limitation; and
- do not add observed-response lags to the negative-binomial examples.

For the longer-term modeling API:

- implement the Gaussian residual dyadic VAR described in [`stan.md`](stan.md);
- include both own and partner transitions when the substantive model requires
  them;
- model same-occasion innovation covariance directly;
- make stationarity, initial conditions, observation gaps, and role or
  exchangeability constraints explicit; and
- add non-Gaussian dynamics only after their likelihood and latent scale have
  been designed and validated.

## 8. Citation Strategy

Use citations for specific claims rather than placing the same large citation
cluster in every paragraph.

| Claim or tutorial location | Primary citation | Supporting citation |
|---|---|---|
| General within-between predictor decomposition and time trends | Bolger and Laurenceau (2013) | Gottfredson (2019) for person-mean reliability |
| Observed person means may be unreliable with few occasions | Gottfredson (2019) | Ludtke et al. (2008) for latent covariate bias |
| Manifest-centering a lagged outcome biases average autoregression | Hamaker and Grasman (2015) | Nickell (1981) |
| Small-T endogeneity and initial-condition handling | Gistelinck, Loeys, and Flamant (2021) | Nickell (1981) |
| Dyadic own-lag model with actor/partner predictor effects | Gistelinck and Loeys (2020) | Del Rosario and West (2025) for longitudinal dyadic random effects |
| Stable between-person differences versus within-person dynamics | Hamaker, Kuiper, and Grasman (2015) | Gistelinck et al. (2021) |
| General DSEM framework | Asparouhov, Hamaker, and Muthen (2018) | McNeish and Hamaker (2020), if a didactic source is needed |
| DSEM versus residual DSEM | Asparouhov and Muthen (2020) | The package's [`stan.md`](stan.md) for the intended residual VAR |
| Full partner-outcome transition model | A multivariate DSEM or dyadic VAR source | Do not cite Gistelinck and Loeys (2020) as if their LD-APIM contained partner-outcome lags |

### Recommended minimum citations by vignette section

For a concurrent ILD section:

```text
Bolger and Laurenceau (2013); Gottfredson (2019)
```

For a lag-adjusted own-outcome model, add:

```text
Hamaker and Grasman (2015); Gistelinck, Loeys, and Flamant (2021)
```

For the dyadic LD-APIM specification, add:

```text
Gistelinck and Loeys (2020)
```

For DSEM or residual-DSEM context, add only where that distinction is
discussed:

```text
Asparouhov, Hamaker, and Muthen (2018);
Asparouhov and Muthen (2020)
```

Nickell (1981) is the foundational technical citation. In user-facing prose,
Hamaker and Grasman (2015) and Gistelinck et al. (2021) are more direct guides
to the practical multilevel implications.

## References

- Asparouhov, T., Hamaker, E. L., & Muthen, B. (2018). Dynamic structural
  equation models. *Structural Equation Modeling, 25*(3), 359-388.
  <https://doi.org/10.1080/10705511.2017.1406803>
- Asparouhov, T., & Muthen, B. (2020). Comparison of models for the analysis of
  intensive longitudinal data. *Structural Equation Modeling, 27*(2), 275-297.
  <https://doi.org/10.1080/10705511.2019.1626733>
- Del Rosario, K. S., & West, T. V. (2025). A practical guide to specifying
  random effects in longitudinal dyadic multilevel modeling. *Advances in
  Methods and Practices in Psychological Science, 8*(3).
  <https://doi.org/10.1177/25152459251351286>
- Gistelinck, F., & Loeys, T. (2020). Multilevel autoregressive models for
  longitudinal dyadic data. *TPM - Testing, Psychometrics, Methodology in
  Applied Psychology, 27*(3), 433-452.
  <https://doi.org/10.4473/TPM27.3.7>
- Gistelinck, F., Loeys, T., & Flamant, N. (2021). Multilevel autoregressive
  models when the number of time points is small. *Structural Equation
  Modeling, 28*(1), 15-27.
  <https://doi.org/10.1080/10705511.2020.1753517>
- Gottfredson, N. C. (2019). A straightforward approach for coping with
  unreliability of person means when parsing within-person and between-person
  effects in longitudinal studies. *Addictive Behaviors, 94*, 156-161.
  <https://doi.org/10.1016/j.addbeh.2018.09.031>
- Hamaker, E. L., & Grasman, R. P. P. P. (2015). To center or not to center?
  Investigating inertia with a multilevel autoregressive model. *Frontiers in
  Psychology, 5*, 1492. <https://doi.org/10.3389/fpsyg.2014.01492>
- Hamaker, E. L., Kuiper, R. M., & Grasman, R. P. P. P. (2015). A critique of
  the cross-lagged panel model. *Psychological Methods, 20*(1), 102-116.
  <https://doi.org/10.1037/a0038889>
- Ludtke, O., Marsh, H. W., Robitzsch, A., Trautwein, U., Asparouhov, T., &
  Muthen, B. (2008). The multilevel latent covariate model: A new, more reliable
  approach to group-level effects in contextual studies. *Psychological
  Methods, 13*(3), 203-229. <https://doi.org/10.1037/a0012869>
- Nickell, S. (1981). Biases in dynamic models with fixed effects.
  *Econometrica, 49*(6), 1417-1426. <https://doi.org/10.2307/1911408>
- Bolger, N., & Laurenceau, J.-P. (2013). *Intensive longitudinal methods: An
  introduction to diary and experience sampling research*. Guilford Press.

Local paper copies used for this note are stored in `dev/References/`.
