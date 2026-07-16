# Choosing AR(1) or VAR models for dyadic intensive longitudinal data

**An applied `glmmTMB` guide for Gaussian outcomes**  
**Tested with:** `glmmTMB` 1.1.15  
**Companion technical note:** [Current off-the-shelf options for serial dependence in dyadic ILD](dyadic-ild-current-options.md)

This tutorial gives a practical workflow that works for both distinguishable
and exchangeable dyads. It deliberately uses only released, documented
`glmmTMB` covariance structures. In particular, it does not rely on an
unreleased Kronecker implementation.

The companion note develops the pooled member AR as one structure that can be
used consistently across dyad types. Here it is retained as a practical
working alternative; the recommended starting structures below are richer and
respect the different symmetry assumptions of distinguishable and
exchangeable dyads.

## Recommendation at a glance

| Scientific target | Start here | If that is too rich or unstable |
|---|---|---|
| Concurrent associations; distinguishable dyads | Role-specific individual AR processes plus same-day role covariance | Pool the two AR processes, then drop AR while retaining same-day covariance |
| Concurrent associations; exchangeable dyads | Mean- and difference-mode AR processes **without** an extra same-day block | Set an unsupported mode's $\rho$ to zero; if both are unsupported, retain same-day mean/difference covariance only |
| Own/partner carryover | Put both partners' lagged outcomes in the mean as a dyadic VAR; initially retain same-day innovation covariance but no extra residual AR | Revisit lag order, trends, and other mean structure; add residual AR only if justified by remaining diagnostics |

The pooled member AR is the cleanest **common AR component** across dyad types.
For exchangeable dyads, however, it is not the same hypothesis as a shared
couple AR. The former describes separate person-specific trajectories with
common parameters; the latter describes one persistent state shared by both
partners. Whether a separate same-day covariance is added is another modeling
choice, not an automatic part of pooling.

## 1. First decide what the temporal model is supposed to answer

The first choice is substantive, not computational.

### A. Is serial dependence a nuisance?

Suppose the research question concerns a **concurrent** association, such as:

> Is today's perceived support associated with today's well-being, accounting
> for both partners' predictors?

Keep that concurrent mean model and model the remaining serial dependence in
the covariance structure with `ar1()`. The AR coefficient then describes
residual persistence. It is not an actor or partner carryover effect.

### B. Are own- and partner-outcome carryover the research question?

Suppose the research question is instead:

> Does one person's well-being today predict their own or their partner's
> well-being tomorrow?

Put both prior outcomes in the mean model. This is a dyadic VAR(1), expressed
as a lagged-outcome APIM. The own-outcome lag is an actor carryover and the
partner-outcome lag is a partner carryover.

### Why these are not interchangeable

Even a stripped-down covariance model without stable random effects,

$$
Y_t=X_t\beta+u_t, \qquad u_t=A u_{t-1}+\epsilon_t
$$

implies the conditional mean

$$
E(Y_t\mid Y_{t-1},X_t,X_{t-1})
=X_t\beta+A(Y_{t-1}-X_{t-1}\beta).
$$

That is generally not the same as adding `lag_y` to the original regression.
Lagged outcomes change what the other coefficients condition on. Choose the
VAR route because carryover is scientifically relevant, not merely because it
removes residual autocorrelation.

## 2. Prepare and check the time index

`glmmTMB::ar1()` requires the time variable to be a factor. Its levels encode
equally spaced occasions. Retain the full scheduled sequence so that, for
example, day 5 and day 7 are two units apart when day 6 is missing.

```r
full_days <- 0:54

# Remove stale levels from IDs, roles, and other existing factors first.
d <- droplevels(d)

d$day_f <- factor(
  d$diaryday,
  levels = full_days
)
stopifnot(!anyNA(d$day_f))

# Keep a scheduled level even if it is absent from the entire analysis data.
ild_control <- glmmTMB::glmmTMBControl(
  drop_unused_levels = FALSE
)
```

The control setting matters only when a scheduled occasion is absent
**globally**. Without it, `glmmTMB` drops that unused factor level and treats
the occasions on either side as adjacent. A day missing within only some
member series is already handled correctly as long as that level occurs
elsewhere in the analysis data. Because the control setting is global, remove
stale levels from other factors before recreating `day_f`, as above.

For the examples below, also create indicators for distinguishable roles and a
stable arbitrary contrast for exchangeable members:

```r
d$female <- as.numeric(d$role == "female")
d$male   <- as.numeric(d$role == "male")

# member_no is arbitrary but must remain fixed within a person over time
d$diff <- ifelse(d$member_no == 1, 1, -1)
```

The selectors used to load AR states must be numeric or logical, not factors.
Check both their coding and the arbitrary exchangeable labels:

```r
stopifnot(
  is.numeric(d$female),
  is.numeric(d$male),
  is.numeric(d$diff),
  all(d$female %in% 0:1),
  all(d$male %in% 0:1),
  all(d$diff %in% c(-1, 1)),
  all(d$female + d$male == 1)
)

member_labels <- unique(d[c("coupleID", "personID", "diff")])
labels_ok <- tapply(
  member_labels$diff,
  member_labels$coupleID,
  function(z) length(z) == 2L && setequal(z, c(-1, 1))
)
stopifnot(all(labels_ok))
```

Check that a member has at most one row per scheduled occasion:

```r
stopifnot(
  !anyDuplicated(d[c("coupleID", "personID", "day_f")])
)
```

If `personID` is unique only within couples, `coupleID:personID` identifies a
member series. If `personID` is globally unique, `personID` alone is enough.

### Must all helper variables be precomputed?

No. The grouping interaction can be written directly:

```r
ar1(0 + day_f | coupleID:personID)
```

Role selectors and the exchangeable contrast can also be written inline:

```r
ar1(0 + I(role == "female"):day_f | coupleID)

ar1(
  0 + I(ifelse(member_no == 1, 1, -1)):day_f |
    coupleID
)
```

However, keep `day_f` as a named, explicitly leveled factor. An inline call
such as `factor(diaryday, levels = full_days)` did not work reliably inside a
structured covariance term in the tested version. Named role indicators and
numeric `diff` are also easier to inspect and less error-prone, so the longer
formulas below use them. Do not use `interaction(coupleID, personID)` inline
as the AR grouping expression in the tested version; either use
`coupleID:personID` or precompute the interaction.

## 3. Components used in the examples

The examples combine up to three independent latent components:

1. a stable between-couple/member covariance, denoted by $B$;
2. one or more temporally persistent AR processes; and
3. an additional same-day covariance, denoted by $W$.

These AR structures assume that the residual process is covariance-stationary
after the fixed effects. Include scientifically plausible trends, weekday
patterns, phases, or other systematic time structure in the mean first.

The same-day grouping factor can also be written inline:

```r
coupleID:day_f
```

In all models below, the AR state(s), $W$, or both already supply the intended
member-level residual variances. Therefore use

```r
dispformula = ~ 0
```

Otherwise the default Gaussian dispersion adds another independent residual
variance to every row and blurs the intended decomposition. That extra nugget
may be intentional in a measurement-error model, but it is not part of the
models recommended here.

## 4. Distinguishable dyads: role-specific individual AR processes

For distinguishable dyads, a useful flexible working model gives the two roles
independent AR realizations with different variances and AR coefficients:

```r
fit_d_full <- glmmTMB::glmmTMB(
  y ~
    0 + female + male +
    # role-specific actor/partner predictors and time trends ...

    # Stable role-specific covariance B
    us(0 + female + male | coupleID) +

    # Separate role-specific individual AR processes
    ar1(0 + female:day_f | coupleID) +
    ar1(0 + male:day_f   | coupleID) +

    # Additional same-day role covariance W
    us(0 + female + male | coupleID:day_f),

  dispformula = ~ 0,
  family = gaussian(),
  control = ild_control,
  data = d
)
```

Within the female AR block, male rows have loading zero; the reverse is true
for the male block. Thus the duplicate couple-day rows do not create duplicate
measurements within either latent series.

The two `ar1()` terms estimate four parameters: an AR variance and a correlation
for each role. Conditional on the stable effects, their lag-$h$ covariance is

$$
\Gamma_h=
\begin{cases}
\begin{pmatrix}v_F&0\\0&v_M\end{pmatrix}+W, & h=0,\\[8pt]
\begin{pmatrix}v_F\rho_F^h&0\\0&v_M\rho_M^h\end{pmatrix}, & h>0.
\end{cases}
$$

Thus, each role can have different inertia, while $W$ captures additional
same-day partner covariance. The model does **not** contain decaying
cross-partner covariance. Distinguishability permits different parameters; it
does not prove that the two temporal processes really differ.

### Parameter count

| Component | Covariance parameters |
|---|---:|
| Stable role covariance $B$ | 3 |
| Female and male AR processes | 4 |
| Same-day role covariance $W$ | 3 |
| **Total** | **10** |

Because $W$ is independent of the AR states, this is a latent-AR-plus-nugget
model. It is neither a single Kronecker covariance nor a full dyadic VAR.

## 5. Exchangeable default: AR processes for the dyad mean and difference

For exchangeable dyads, arbitrary labels must not affect the likelihood. A
natural structure decomposes the residual process into:

- a shared dyad-mean process, loading `+1` on both members; and
- a directed member-difference process, loading `+1` and `-1`.

The recommended starting model gives both modes their own AR variance and
correlation. It does **not** add a separate same-day covariance block:

```r
fit_e_two_mode <- glmmTMB::glmmTMB(
  y ~
    1 +
    # pooled actor/partner predictors and time trends ...

    # Stable exchangeable covariance B
    (1 | coupleID) +
    (0 + diff | coupleID) +

    # Persistent dyad-mean and member-difference processes
    ar1(0 + day_f      | coupleID) +
    ar1(0 + diff:day_f | coupleID),

  dispformula = ~ 0,
  family = gaussian(),
  control = ild_control,
  data = d
)
```

Here the two rows at a couple-day are intentional: both load `+1` on the
shared mean state, while they load `+1` and `-1` on the difference state.
There is one latent value per mode, couple, and scheduled occasion.

Changing which member receives `+1` only changes the sign of the difference
process, so the likelihood is unchanged.

Define

$$
J_2=\begin{pmatrix}1&1\\1&1\end{pmatrix}, \qquad
K_2=\begin{pmatrix}1&-1\\-1&1\end{pmatrix}.
$$

Conditional on the stable effects, this model implies

$$
\Gamma_h
=v_+\rho_+^hJ_2+v_-\rho_-^hK_2.
$$

The two AR modes estimate four temporal covariance parameters and already give
an unrestricted exchangeable covariance at lag zero.

| Component | Covariance parameters |
|---|---:|
| Stable exchangeable covariance $B$ | 2 |
| Mean and difference AR processes | 4 |
| **Total** | **6** |

Conditional on $B$, this is the covariance representation of a stationary
exchangeable VAR(1), with

$$
A=
\frac{1}{2}
\begin{pmatrix}
\rho_++\rho_- & \rho_+-\rho_-\\
\rho_+-\rho_- & \rho_++\rho_-
\end{pmatrix}.
$$

Its innovation covariance is

$$
Q
=v_+(1-\rho_+^2)J_2
+v_-(1-\rho_-^2)K_2.
$$

This $Q$ mapping matters: $v_+$ and $v_-$ are stationary state variances, not
innovation variances.

This equivalence concerns the **stationary residual process**. It does not turn
the concurrent fixed effects into lagged actor or partner carryover effects.
A lagged-outcome VAR instead puts $Y_{t-1}$ in the conditional mean, conditions
on or omits initial rows, and changes the estimand.

### Optional extension: two AR modes plus same-day noise

Add a separate exchangeable $W$ only when theory calls for a persistent latent
state plus occasion-specific or measurement noise, and the data can identify
that decomposition:

```r
fit_e_state_space <- update(
  fit_e_two_mode,
  . ~ . + (1 | coupleID:day_f) + (0 + diff | coupleID:day_f)
)
```

This optional maximal model has eight covariance parameters: two in stable
$B$, four in the AR modes, and two in $W$. It implies

$$
\Gamma_h
=v_+\rho_+^hJ_2+v_-\rho_-^hK_2+I(h=0)W.
$$

The observed residual is now a sum of latent AR states and serially independent
noise. It is generally no longer an ordinary VAR(1) or a single Kronecker
covariance. In particular, $W$ contributes at lag zero but does not propagate
to later lags.

## 6. Simplify according to what is unsupported

The exchangeable no-$W$ model has a genuine nested zero-$\rho$ ladder, shown
below. Across all candidate structures, however, there is no universal ladder:
a shared-couple AR and a pooled individual AR make different claims. Use
estimates, diagnostics, and theory to choose a branch.
Setting a supported mode's $\rho$ to zero is an equality restriction, whereas
removing a variance component places the null on a boundary; a nominal
chi-square likelihood-ratio test is not automatically valid for the latter.

### Distinguishable branch

#### D1. Start with role-specific AR processes plus $W$

Use `fit_d_full` when role-specific persistence is plausible and supported by
the amount of data.

#### D2. If role-specific AR parameters are similar or weakly identified, pool them

```r
fit_d_pooled <- glmmTMB::glmmTMB(
  y ~
    0 + female + male +
    # role-specific fixed effects ...
    us(0 + female + male | coupleID) +
    ar1(0 + day_f | coupleID:personID) +
    us(0 + female + male | coupleID:day_f),
  dispformula = ~ 0,
  family = gaussian(),
  control = ild_control,
  data = d
)
```

Every member still receives a separate AR realization. Pooling only constrains
the AR variance and $\rho$ to be equal across roles.

This model has $3+2+3=8$ covariance parameters.

#### D3. If residual persistence is negligible, retain $B+W$ without AR

```r
fit_d_white <- glmmTMB::glmmTMB(
  y ~
    0 + female + male +
    # role-specific fixed effects ...
    us(0 + female + male | coupleID) +
    us(0 + female + male | coupleID:day_f),
  dispformula = ~ 0,
  family = gaussian(),
  control = ild_control,
  data = d
)
```

This has six covariance parameters. Treat couple-clustered inference and a
whole-couple bootstrap as sensitivity analyses for remaining covariance
misspecification.

### Exchangeable dyads: first simplify within the no-$W$ family

The recommended `fit_e_two_mode` model has a genuine nested simplification
path. Setting a mode's $\rho$ to zero retains its occasion-specific variance
while removing its persistence.

#### E1. If difference-mode persistence is unsupported

Keep the mean AR and replace the difference AR with a same-day white effect:

```r
fit_e_mean_ar <- glmmTMB::glmmTMB(
  y ~
    1 +
    # pooled fixed effects ...
    (1 | coupleID) +
    (0 + diff | coupleID) +
    ar1(0 + day_f | coupleID) +
    (0 + diff | coupleID:day_f),
  dispformula = ~ 0,
  family = gaussian(),
  control = ild_control,
  data = d
)
```

This is the $\rho_-=0$ restriction of the two-mode model:

$$
\Gamma_h
=v_+\rho_+^hJ_2+I(h=0)w_-K_2.
$$

It has five covariance parameters including stable $B$: two stable, two for
the mean AR, and one white difference variance.

#### E2. If mean-mode persistence is unsupported

The symmetric alternative keeps the difference AR and makes the mean mode
serially white:

```r
fit_e_difference_ar <- glmmTMB::glmmTMB(
  y ~
    1 +
    # pooled fixed effects ...
    (1 | coupleID) +
    (0 + diff | coupleID) +
    (1 | coupleID:day_f) +
    ar1(0 + diff:day_f | coupleID),
  dispformula = ~ 0,
  family = gaussian(),
  control = ild_control,
  data = d
)
```

This is the $\rho_+=0$ restriction and also has five covariance parameters:

$$
\Gamma_h
=v_-\rho_-^hK_2+I(h=0)w_+J_2.
$$

It permits persistent partner differences and therefore potentially negative
cross-partner lag covariance. Use it only when that pattern is substantively
and empirically plausible.

#### E3. If neither mode is persistent

Retain an exchangeable same-day covariance but no AR process:

```r
fit_e_white <- glmmTMB::glmmTMB(
  y ~
    1 +
    # pooled fixed effects ...
    (1 | coupleID) +
    (0 + diff | coupleID) +
    (1 | coupleID:day_f) +
    (0 + diff | coupleID:day_f),
  dispformula = ~ 0,
  family = gaussian(),
  control = ild_control,
  data = d
)
```

This is the $\rho_+=\rho_-=0$ restriction. It has four covariance parameters:
two in stable $B$ and two in same-day $W$. It estimates no temporal
dependence.

The no-$W$ path is therefore

$$
\text{two AR modes (6)}
\longrightarrow
\text{one AR mode plus one white mode (5)}
\longrightarrow
\text{two white modes (4)},
$$

where totals include stable $B$.

### Alternative exchangeable working structures

The next two models are useful alternatives when a separate same-day nugget is
important. They are **not** lower-dimensional simplifications of the default
six-parameter no-$W$ model: each also has six covariance parameters and makes
a different claim about positive-lag covariance.

#### Shared-couple AR plus a full same-day $W$

```r
fit_e_shared_w <- glmmTMB::glmmTMB(
  y ~
    1 +
    # pooled fixed effects ...
    (1 | coupleID) +
    (0 + diff | coupleID) +
    ar1(0 + day_f | coupleID) +
    (1 | coupleID:day_f) +
    (0 + diff | coupleID:day_f),
  dispformula = ~ 0,
  family = gaussian(),
  control = ild_control,
  data = d
)
```

This implies

$$
\Gamma_h=v_C\rho_C^hJ_2+I(h=0)W.
$$

Only the shared couple state persists. Notice that this differs from the
five-parameter nested `fit_e_mean_ar`: the full $W$ also adds white variation
in the mean direction.

#### Pooled independent-member AR plus a full same-day $W$

```r
fit_e_pooled_w <- glmmTMB::glmmTMB(
  y ~
    1 +
    # pooled fixed effects ...
    (1 | coupleID) +
    (0 + diff | coupleID) +
    ar1(0 + day_f | coupleID:personID) +
    (1 | coupleID:day_f) +
    (0 + diff | coupleID:day_f),
  dispformula = ~ 0,
  family = gaussian(),
  control = ild_control,
  data = d
)
```

This implies

$$
\Gamma_h=v_P\rho_P^hI_2+I(h=0)W.
$$

Each member has an independent AR realization; only its parameters are pooled.
The shared-$W$ and pooled-$W$ models are not nested in one another. Both are
six-parameter reductions of the optional eight-parameter two-mode-AR-plus-$W$
model: the former removes the difference AR, while the latter equates the two
AR modes after accounting for the `+1/-1` loading scale. Variance-zero tests
are boundary cases, and these separate formulas do not automatically impose
the mappings needed for a regular likelihood-ratio test.

### A strict pooled no-$W$ restriction

The pooled member AR can also be used without $W$:

```r
fit_e_pooled_no_w <- glmmTMB::glmmTMB(
  y ~
    1 +
    # pooled fixed effects ...
    (1 | coupleID) +
    (0 + diff | coupleID) +
    ar1(0 + day_f | coupleID:personID),
  dispformula = ~ 0,
  family = gaussian(),
  control = ild_control,
  data = d
)
```

This four-parameter model is nested in the default two-mode model through
$\rho_+=\rho_-$ and equal, appropriately scaled mode variances. It forces

$$
\Gamma_h=v_P\rho_P^hI_2,
$$

so the conditional same-day partner residual covariance is zero. Do not use
this restriction merely for easier convergence if a same-day residual
association is scientifically important.

### Common practical AR component

The same pooled member-series term can be used for both dyad types:

```r
ar1(0 + day_f | coupleID:personID)
```

For distinguishable dyads it naturally replaces two role-specific AR terms.
For exchangeable dyads, use it without $W$ only under the zero same-day partner
covariance restriction, or combine it with exchangeable $W$ as the alternative
working structure above. Pooling never correlates the partners' AR
realizations; it only gives them a common variance and $\rho$.

## 7. How these models compare

The following table describes covariance conditional on stable $B$.

| Structure | Lag-$h$ covariance | Central restriction |
|---|---|---|
| Exchangeable two-mode AR, no $W$ | $v_+\rho_+^hJ_2+v_-\rho_-^hK_2$ | Symmetric mean/difference dynamics; recommended exchangeable default |
| One AR mode plus one white mode | One term above plus $I(h=0)$ times the other mode matrix | One mode has $\rho=0$ |
| Pooled member AR, no $W$ | $v\rho^hI_2$ | Zero conditional partner covariance at every lag |
| Shared couple AR + full $W$ | $v\rho^hJ_2+I(h=0)W$ | All persistence is shared equally |
| Pooled member AR + full $W$ | $v\rho^hI_2+I(h=0)W$ | No cross-partner serial covariance |
| Kronecker AR1@UN | $\rho^h\Sigma_2$ | Every member covariance decays at one common rate |
| Full distinguishable VAR | determined by $A^h$ and innovation covariance | Allows directional partner carryover |

For comparison, the main dynamic/covariance parameter counts are:

| Dyad/model family | Dynamic or residual block | Stable $B$ | Total |
|---|---:|---:|---:|
| Distinguishable role AR + $W$ | 4 AR + 3 $W$ = 7 | 3 | 10 |
| Distinguishable full VAR in the mean | 4 $A$ + 3 $Q$ = 7 | 3 | 10 |
| Distinguishable Kronecker AR1@UN benchmark | 1 $\rho$ + 3 $\Sigma_2$ = 4 | 3 | 7 |
| Exchangeable two-mode AR, no $W$ | 4 | 2 | 6 |
| Exchangeable VAR in the mean | 2 $A$ + 2 $Q$ = 4 | 2 | 6 |
| Exchangeable Kronecker benchmark | 1 $\rho$ + 2 $\Sigma_2$ = 3 | 2 | 5 |

Fixed predictor effects are excluded. Entries of $A$ are fixed lag
coefficients; the other entries in this table are covariance parameters.
Equal counts do not imply equal model families: role AR + $W$ and a full
distinguishable VAR both use seven within-dyad parameters but impose very
different positive-lag covariance.

For a stationary VAR(1), define

$$
u_t=A u_{t-1}+\epsilon_t,
\qquad \operatorname{Var}(\epsilon_t)=Q,
$$

and $\Gamma_h=\operatorname{Cov}(u_t,u_{t-h})$. Then

$$
\Gamma_0=A\Gamma_0A^\mathsf{T}+Q,
\qquad
\Gamma_h=A^h\Gamma_0 \quad (h>0),
\qquad
\Gamma_{-h}=\Gamma_h^\mathsf{T}.
$$

The $A$ and $Q$ shown in Section 5 make the no-$W$ two-mode model obey these
relations exactly.

The exchangeable two-mode model without $W$ is an exchangeable VAR in
covariance form. If $\rho_+=\rho_-$, it becomes an exchangeable Kronecker
AR(1). If the mode variances are also equal after accounting for the `+1/-1`
loading scale, it reduces to independent pooled member AR processes.

Adding $W$ to any AR state creates a **sum** of covariance components. If
$r_t=u_t+w_t$, then

$$
\operatorname{Var}(r_t)=\Gamma_{0,u}+W,
\qquad
\operatorname{Cov}(r_t,r_{t-h})=A^h\Gamma_{0,u} \quad (h>0).
$$

The same-day covariance in $W$ does not propagate. Consequently this observed
process generally fails $\Gamma_h=A^h\Gamma_0$ and is neither an ordinary
VAR(1) nor a single Kronecker product; it is a latent-state-plus-nugget model.

The stable covariance adds

$$
J_T\otimes B
$$

to the full $2T\times2T$ covariance. This constant covariance at every lag can
be difficult to distinguish from an AR process whose $\rho$ is near one.

## 8. Put a dyadic VAR in the mean when carryover matters

Construct exact one-occasion actor and partner lags before fitting. Do not use
the previous observed record as a one-day lag when scheduled days are missing.
For the integer daily index used here, a safe pattern is to shift observed
outcomes to their target day and then join:

```r
library(dplyr)

stopifnot(all(d$member_no %in% 1:2))

actor_lags <- d |>
  transmute(
    coupleID,
    personID,
    diaryday = diaryday + 1,
    lag_actor_y = y
  )

partner_lags <- d |>
  transmute(
    coupleID,
    member_no = 3L - member_no,
    diaryday = diaryday + 1,
    lag_partner_y = y
  )

d_lagged <- d |>
  left_join(
    actor_lags,
    by = c("coupleID", "personID", "diaryday")
  ) |>
  left_join(
    partner_lags,
    by = c("coupleID", "member_no", "diaryday")
  ) |>
  filter(!is.na(lag_actor_y), !is.na(lag_partner_y))
```

The final line makes the conditional/complete-lag analysis explicit; replace
it with the study's planned missing-data model if needed. This construction
never silently treats day 5 as the lag of day 7.

For exchangeable dyads:

```r
fit_var_e <- glmmTMB::glmmTMB(
  y ~
    lag_actor_y + lag_partner_y +
    # concurrent actor/partner predictors ...
    (1 | coupleID) +
    (0 + diff | coupleID) +
    (1 | coupleID:day_f) +
    (0 + diff | coupleID:day_f),
  dispformula = ~ 0,
  family = gaussian(),
  control = ild_control,
  data = d_lagged
)
```

Its transition matrix is

$$
A_E=\begin{pmatrix}a&p\\p&a\end{pmatrix},
$$

where `lag_actor_y` estimates $a$ and `lag_partner_y` estimates $p$. A
stationary VAR requires

$$
|a+p|<1 \quad\text{and}\quad |a-p|<1.
$$

For distinguishable dyads:

```r
fit_var_d <- glmmTMB::glmmTMB(
  y ~
    0 + female + male +
    female:(lag_actor_y + lag_partner_y) +
    male:(lag_actor_y + lag_partner_y) +
    # concurrent role-specific predictors ...
    us(0 + female + male | coupleID) +
    us(0 + female + male | coupleID:day_f),
  dispformula = ~ 0,
  family = gaussian(),
  control = ild_control,
  data = d_lagged
)
```

This estimates

$$
A_D=
\begin{pmatrix}
a_F&p_F\\
p_M&a_M
\end{pmatrix}.
$$

Check that every eigenvalue of $A_D$ has modulus below one; `glmmTMB` does not
enforce VAR stationarity.

The exchangeable VAR has two lag coefficients, two stable covariance
parameters, and two same-day innovation parameters. The distinguishable VAR
has four lag coefficients, three stable covariance parameters, and three
same-day innovation parameters. Lag coefficients are fixed effects, not
covariance parameters.

### VAR cautions

- The first observation in each series has no lag and requires an explicit
  missing-data/initial-condition decision.
- Lagged outcomes are generally associated with stable person effects.
  Ordinary random-effects assumptions can therefore be problematic, especially
  in short panels.
- Adding a lagged outcome does not guarantee white innovations. Inspect the
  residual ACF and cross-partner lag correlations.
- Do not automatically combine a VAR mean and residual AR terms. Remaining
  serial correlation may indicate a missing lag, trend, seasonality, or other
  mean structure.
- Neither temporal precedence nor a fitted VAR establishes a causal effect.

## 9. Diagnose before simplifying

At minimum, check:

```r
fit$sdr$pdHess
glmmTMB::diagnose(fit)
VarCorr(fit)
```

Also inspect:

- whether an AR variance is close to zero;
- whether $\rho$ is close to zero or one;
- member-specific residual ACFs;
- residual ACFs of the couple mean and member difference;
- residual cross-partner correlations at positive and negative lags;
- whether conclusions about fixed effects and their standard errors change
  across defensible neighboring structures; and
- whether missing days were encoded as actual gaps.

Interpret common boundary patterns:

- $\rho\approx0$: AR variance is hard to separate from same-day variance;
- $|\rho|\approx1$: AR variance is hard to separate from stable random effects;
- tiny mode variance: that dynamic mode may not be supported; and
- a non-positive-definite Hessian: do not interpret the nominal estimates and
  standard errors as a successful fit.

ACF and PACF plots are diagnostics, not automatic selectors of the correct
dyadic process.

## 10. Clustered inference is a sensitivity analysis, not a temporal model

For an ML fit, current `glmmTMB` versions can calculate a couple-clustered HC0
covariance matrix:

```r
fit_ml <- update(fit, REML = FALSE)

V_HC0 <- glmmTMB::vcovHC(
  fit_ml,
  cluster = factor(d_used$coupleID)
)
```

All random-effect groups must be nested within the couple cluster, and
`d_used` must have exactly the rows used in the fit.

Clustered inference can protect fixed-effect standard errors asymptotically
against remaining within-couple covariance misspecification when the mean is
correct and predictors are exogenous. It does not estimate AR or VAR dynamics,
repair biased coefficients from omitted dynamics or confounding, make AIC
robust, or improve temporal predictions.

With roughly 40 couples and only HC0 available, use clustered standard errors
beside model-based results rather than as the sole guarantee. A nonparametric
bootstrap that resamples and reindexes whole couples is a useful additional
check.

## 11. Recommended workflow in one page

1. **Choose the estimand.** Use residual AR covariance for a concurrent
   question; use a lagged-outcome dyadic VAR for carryover questions.
2. **Create `day_f` explicitly** with every scheduled occasion retained.
3. **Fit a role-compatible temporal structure.** Start with role-specific
   individual AR processes plus $W$ for distinguishable dyads. Start with
   mean/difference AR processes without $W$ for exchangeable dyads.
4. **Treat extra same-day noise as an extension.** Adding $W$ to both
   exchangeable AR modes creates an eight-parameter latent-state-plus-nugget
   model; use it only when that decomposition is meaningful and identifiable.
5. **Use the true exchangeable nested path first.** Set an unsupported mode's
   $\rho$ to zero while retaining its white variance; if neither mode persists,
   retain same-day mean/difference covariance only.
6. **Treat shared-plus-$W$ and pooled-plus-$W$ as alternative branches.** They
   are different six-parameter working structures, not smaller rungs below the
   six-parameter no-$W$ default.
7. **Use pooled member AR as a common component, with care.** Without $W$ it
   forces zero conditional same-day partner covariance; with $W$ it becomes a
   latent-AR-plus-nugget working model.
8. **If AR is unsupported, retain same-day dyadic covariance** and use
   couple-clustered and whole-couple bootstrap inference as sensitivity checks.
9. **Check residual dynamics after every model.** Neither `ar1()` nor lagged
   outcomes automatically finish the temporal specification.

## Primary documentation and further reading

- [`glmmTMB` covariance-structure vignette](https://glmmtmb.github.io/glmmTMB/articles/covstruct.html): documented `ar1()` and `us()` syntax, explicit factor levels, parameterization, and dispersion.
- [`glmmTMB` model reference](https://glmmtmb.github.io/glmmTMB/reference/glmmTMB.html): model formulas, `dispformula`, ML, and REML.
- [CRAN `glmmTMB` reference manual](https://cran.r-project.org/web/packages/glmmTMB/glmmTMB.pdf): complete function documentation, including post-fit covariance methods available in the installed release.
- [`glmmTMB::diagnose()` reference](https://glmmtmb.github.io/glmmTMB/reference/diagnose.html) and [troubleshooting vignette](https://glmmtmb.github.io/glmmTMB/articles/troubleshooting.html): Hessian and boundary diagnostics.
- [Brooks et al. (2017), *glmmTMB Balances Speed and Flexibility Among Packages for Zero-inflated Generalized Linear Mixed Modeling*](https://doi.org/10.32614/RJ-2017-066).
- [Zeileis (2006), *Object-Oriented Computation of Sandwich Estimators*](https://doi.org/10.18637/jss.v016.i09): sandwich covariance principles.
- [Gistelinck and Loeys (2020), *Multilevel autoregressive models for longitudinal dyadic data*](https://doi.org/10.4473/TPM27.3.7): the lagged-dependent APIM.
- [Gistelinck, Loeys, and Flamant (2021), *Multilevel autoregressive models when the number of time points is small*](https://doi.org/10.1080/10705511.2020.1753517): small-$T$, endogeneity, and initial-condition cautions.
- [Asparouhov and Muthen (2020), *Comparison of models for the analysis of intensive longitudinal data*](https://doi.org/10.1080/10705511.2019.1626733): the distinction between dynamics in the mean and residual dynamics.
- [Local literature review of ILD non-independence](ild-nonindependence.md): paper-by-paper support for centering, initial-condition, and dyadic dynamic-model cautions.
- [Technical companion report](dyadic-ild-current-options.md): parameter audits, simulations, full covariance matrices, and software limitations.
