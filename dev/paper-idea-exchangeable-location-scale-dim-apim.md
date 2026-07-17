# Beyond the Standard DIM: Exchangeable Dyadic Models with Mean-Dependent Discrepancy

**Status:** paper concept note

> Exchangeability says that the seesaw has no preferred side. It does not say
> that every dyad's seesaw must swing equally far.

## The idea in one paragraph

The standard Dyad-Individual Model (DIM) is the exchangeability-constrained
version of the linear Gaussian Dyadic Score Model (DSM). Swapping two arbitrary
member labels leaves the dyad mean unchanged but reverses the signed within-dyad
difference. In the standard linear model, this removes directional DSM paths
and forces the covariance between the mean residual and the **signed**
difference residual to zero. However, the **size** of the difference may still
depend on the dyad's observed mean—or on how far its outcome mean lies above or
below prediction. For example, couples farther above their predicted outcome
mean could have partners who are farther apart than predicted, while either
arbitrary member is equally likely to be the higher one. The standard Gaussian
DIM does not model this symmetric form of dependence. In APIM coordinates, the
same omission is present but hidden inside one constant residual variance and
correlation.

## Notation: elevator and seesaw coordinates

For dyad $j$, use the dyad mean and **half-difference**:

$$
M_{Xj}=\frac{X_{1j}+X_{2j}}{2},
\qquad
D_{Xj}=\frac{X_{1j}-X_{2j}}{2},
$$

and analogously for $M_{Yj}$ and $D_{Yj}$. Therefore,

$$
X_{1j}=M_{Xj}+D_{Xj},
\qquad
X_{2j}=M_{Xj}-D_{Xj}.
$$

- **Elevator:** $M$ moves both partners together.
- **Seesaw:** $D$ moves one partner up and the other down.

Swapping the arbitrary member labels gives

$$
(M_X,D_X,M_Y,D_Y)
\longmapsto
(M_X,-D_X,M_Y,-D_Y).
$$

Here $D$ is the half-difference, which equals a member's deviation from the dyad
mean. The package DSM uses the full difference $\Delta=2D$; this changes
scaling, not substance.

## The standard DIM is a constrained DSM

Using the notation above, the full linear DSM is

$$
M_Y
=a_{10}+a_{11}M_X+a_{12}D_X+r_M,
$$

$$
D_Y
=a_{20}+a_{21}M_X+a_{22}D_X+r_D.
$$

For arbitrary member labels, the model must be identical after a swap. A linear
term involving $D_X$ cannot predict $M_Y$, because its sign would change while
$M_Y$ would not. Likewise, an intercept or a term involving only $M_X$ cannot
predict the signed $D_Y$. For the usual linear Gaussian DSM with a constant
residual covariance, exchangeability therefore requires

$$
a_{12}=0,
\qquad
a_{20}=0,
\qquad
a_{21}=0,
\qquad
\operatorname{Cov}(r_M,r_D)=0.
$$

What remains is the standard DIM in score coordinates:

$$
M_Y=\beta_0+\beta_BM_X+r_M,
$$

$$
D_Y=\beta_WD_X+r_D.
$$

Here, $\beta_B$ is the between-dyad effect and $\beta_W$ is the within-dyad
effect. These constraints are correct for a linear directional model. They do
**not** imply that every possible relationship between a dyad mean and a
difference magnitude is forbidden.

## What the standard Gaussian DIM additionally assumes

Write the signed seesaw residual as

$$
r_{Dj}=S_jA_j,
\qquad
S_j\in\{-1,+1\},
\qquad
A_j\geq 0.
$$

$A_j$ is how far the seesaw tilts, and $S_j$ records its arbitrary direction.
Under random seating—or, equivalently, under exchangeability of the joint
distribution—both directions are equally likely conditional on $r_{Mj}$ and
$A_j$:

$$
P(S_j=1\mid r_{Mj},A_j)
=P(S_j=-1\mid r_{Mj},A_j)
=\frac{1}{2}.
$$

Therefore,

$$
E(r_{Dj}\mid r_{Mj},A_j)=0.
$$

Consequently, step by step,

$$
\begin{aligned}
E(r_D\mid r_M)
&=E\!\left[E(r_D\mid r_M,A)\mid r_M\right]=0, \\
\operatorname{Cov}(r_M,r_D)
&=E\!\left[r_ME(r_D\mid r_M)\right]
-E(r_M)E\!\left[E(r_D\mid r_M)\right] \\
&=0.
\end{aligned}
$$

Thus, random seating cancels **direction**; it does not erase **magnitude**.

The usual Gaussian DIM goes further. It assumes

$$
\begin{pmatrix}
r_M\\
r_D
\end{pmatrix}
\sim
\mathcal{N}
\left[
\begin{pmatrix}
0\\
0
\end{pmatrix},
\begin{pmatrix}
\sigma_M^2 & 0\\
0 & \sigma_D^2
\end{pmatrix}
\right].
$$

Under joint normality, zero covariance makes $r_M$ and $r_D$ independent, so
$\operatorname{Var}(r_D\mid r_M)=\sigma_D^2$. Exchangeability alone does not
require this constant conditional variance. More generally, conditional
exchangeability requires

$$
f(r_M,r_D\mid M_X,D_X)
=f(r_M,-r_D\mid M_X,-D_X).
$$

The residual-driven model below does not otherwise depend on $D_X$, so this
reduces to the simpler symmetry $f(r_M,r_D)=f(r_M,-r_D)$.

## Proposed extension: an exchangeable location–scale DIM

Standardize the elevator residual as

$$
z_{Mj}=\frac{r_{Mj}}{\sigma_M},
\qquad
r_{Mj}\sim\mathcal{N}(0,\sigma_M^2).
$$

Retain a zero-centered, symmetric seesaw residual but allow its variance to
depend on the elevator position:

$$
r_{Dj}\mid r_{Mj}
\sim
\mathcal{N}\!\left(0,v_D(z_{Mj})\right),
$$

$$
\log v_D(z_{Mj})
=\alpha_D+\lambda z_{Mj}.
$$

Interpretation:

- $\lambda=0$: the standard Gaussian DIM;
- $\lambda>0$: the seesaw spreads out as the residual elevator moves upward;
- $\lambda<0$: the seesaw tightens as the residual elevator moves upward.

A one-standard-deviation increase in the elevator residual multiplies the
seesaw variance by $\exp(\lambda)$ and its standard deviation by
$\exp(\lambda/2)$. If the substantive idea concerns dyads that are farther from
prediction in **either** direction, $|z_M|$ or $z_M^2$ should replace $z_M$.

This model remains exchangeable because the conditional distribution of $r_D$
is symmetric around zero. It models dependence between $r_M$ and $|r_D|$ or
$r_D^2$, not a forbidden signed correlation between $r_M$ and $r_D$.

Equivalently,

$$
E(r_D^2\mid z_M)=v_D(z_M),
$$

while $E(r_D\mid z_M)=0$.

### Easier observed-predictor version

A related, easier model lets an observed dyad-level variable predict seesaw
variability. For example, with standardized predictor mean $z_{Xj}$,

$$
\log v_D(z_{Xj})
=\alpha_D+\lambda_Xz_{Xj}.
$$

$\lambda_X$ asks whether dyads with a higher average $X$ show larger or smaller
unexplained outcome differences, without predicting which member will be
higher. This version is an ordinary distributional regression. The
residual-driven version is more novel—and harder to estimate—because the
elevator residual must be estimated jointly with the seesaw variance.

## Why this could matter

Possible questions include:

- Do couples with higher average emotional support show more similar physical
  activity, even after accounting for the ordinary mean effects?
- Are couples who are more stressed on average also more unequal in distress,
  regardless of which partner is more distressed?
- Among couples doing better than predicted in average relationship
  satisfaction, do partners converge or polarize?

These questions connect a dyad's overall level with how unequal its members
are. A single signed difference coefficient or residual correlation does not
answer them.

Omitting the scale relationship does **not automatically bias** $\beta_B$,
$\beta_W$, or the corresponding actor and partner point estimates when the
conditional mean model is correct and predictors are exogenous. More defensible
consequences are:

- a substantively meaningful form of dyadic heterogeneity is missed;
- one global covariance matrix hides how the seesaw spread changes across
  dyads;
- model-based uncertainty, prediction intervals, and dyad-specific shrinkage
  may be poorly calibrated.

Bias in mean slopes becomes a clearer possibility only when the omitted term
also changes the conditional mean. One example appears below: if $D_X^2$
predicts $M_Y$ and $D_X^2$ is associated with $M_X$, omitting $D_X^2$ creates
ordinary omitted-variable bias in the estimated between-dyad effect. That is a
different claim from heteroskedasticity alone causing bias.

## What the extension means for the APIM

The DIM does not contain information absent from the APIM. It rotates the same
two-member data into coordinates aligned with exchangeability. This makes the
missing structure visible. The DIM makes the elevator and seesaw directions
explicit; the APIM rotates them back into two partner residuals, where the same
pattern is easy to mistake for one ordinary residual correlation.

### Ordinary fixed-effect transformation

For member $i$ and partner $k$, the member-level DIM is

$$
Y_i
=\beta_0+\beta_BM_X+\beta_W(X_i-M_X)+e_i.
$$

Substitute

$$
M_X=\frac{X_i+X_k}{2},
\qquad
X_i-M_X=\frac{X_i-X_k}{2}.
$$

Then

$$
\begin{aligned}
E(Y_i\mid X_i,X_k)
&=\beta_0
+\frac{\beta_B}{2}(X_i+X_k)
+\frac{\beta_W}{2}(X_i-X_k) \\
&=\beta_0
+\frac{\beta_B+\beta_W}{2}X_i
+\frac{\beta_B-\beta_W}{2}X_k.
\end{aligned}
$$

Therefore, the exchangeable APIM actor and partner effects are

$$
a=\frac{\beta_B+\beta_W}{2},
\qquad
p=\frac{\beta_B-\beta_W}{2},
$$

or, in the other direction,

$$
\beta_B=a+p,
\qquad
\beta_W=a-p.
$$

The location–scale extension does not change this fixed-effect mapping.

### Ordinary residual transformation

The member residuals are

$$
e_1=r_M+r_D,
\qquad
e_2=r_M-r_D,
$$

or in matrix form,

$$
\begin{pmatrix}
e_1\\
e_2
\end{pmatrix}
=
\begin{pmatrix}
1 & 1\\
1 & -1
\end{pmatrix}
\begin{pmatrix}
r_M\\
r_D
\end{pmatrix}.
$$

With constant component variances $v_M$ and $v_D$ and
$\operatorname{Cov}(r_M,r_D)=0$, the expanded member-level
variance–covariance matrix is

$$
\boldsymbol{\Sigma}_e
=
\begin{pmatrix}
v_M+v_D & v_M-v_D\\
v_M-v_D & v_M+v_D
\end{pmatrix}.
$$

Thus both members have residual variance $v_M+v_D$, their covariance is
$v_M-v_D$, and their residual correlation is

$$
\rho_e
=\frac{v_M-v_D}{v_M+v_D}.
$$

This is the familiar exchangeable APIM covariance structure.

### APIM form of the residual-driven extension

The inverse transformation is

$$
r_M=\frac{e_1+e_2}{2},
\qquad
r_D=\frac{e_1-e_2}{2}.
$$

Therefore, the extended APIM can be written directly as

$$
\log
\operatorname{Var}
\left(
\frac{e_1-e_2}{2}
\ \middle|\
\frac{e_1+e_2}{2}=m
\right)
=\alpha_D+\lambda\frac{m}{\sigma_M}.
$$

In words: the residual **average** is associated with the residual **gap
magnitude**.

With an independent $z_D\sim\mathcal{N}(0,1)$, the exact member-level APIM
residuals are

$$
e_1
=\sigma_Mz_M+\sqrt{v_D(z_M)}z_D,
$$

$$
e_2
=\sigma_Mz_M-\sqrt{v_D(z_M)}z_D.
$$

Here,

$$
\sqrt{v_D(z_M)}
=\exp\!\left(\frac{\alpha_D+\lambda z_M}{2}\right).
$$

Let

$$
\bar v_D=E\!\left[v_D(z_M)\right]
$$

be the average seesaw variance. A standard exchangeable APIM can reproduce the
extension's expanded marginal covariance matrix,

$$
\boldsymbol{\Sigma}_e
=
\begin{pmatrix}
\sigma_M^2+\bar v_D & \sigma_M^2-\bar v_D\\
\sigma_M^2-\bar v_D & \sigma_M^2+\bar v_D
\end{pmatrix}.
$$

It cannot reproduce the underlying shape: the anti-diagonal seesaw width
changes with position along the diagonal elevator. The residual cloud fans out
or tightens instead of forming one constant ellipse.

$\lambda$ is therefore not identified from the covariance matrix alone. It is
identified by the association between elevator position and the squared or
absolute seesaw residual. A covariance-only Gaussian APIM absorbs $\bar v_D$
into one average matrix and cannot estimate $\lambda$.

### APIM form of the observed-predictor extension

Suppose $z_X$ is observed before the outcomes,
$r_M\mid z_X\sim\mathcal{N}(0,v_M)$, and
$r_D\mid z_X\sim\mathcal{N}(0,v_D(z_X))$, with the two components conditionally
independent. The expanded APIM covariance conditional on $z_X$ is then

$$
\boldsymbol{\Sigma}_e(z_X)
=
\begin{pmatrix}
v_M+v_D(z_X) & v_M-v_D(z_X)\\
v_M-v_D(z_X) & v_M+v_D(z_X)
\end{pmatrix},
$$

and

$$
\rho_e(z_X)
=\frac{v_M-v_D(z_X)}{v_M+v_D(z_X)}.
$$

At every $z_X$, the conditional residual distribution is invariant to swapping
members: the two variances are equal and the covariance structure is unchanged.
Together with the pooled mean model, this remains exchangeable. However, the
common residual variance and residual correlation vary across the predictor
range. The ordinary APIM hides this by estimating only one covariance matrix.

## Optional broader extension: directionless cross-paths

Beyond the location–scale model, exchangeability also permits nonlinear mean
relationships with no preferred member direction:

$$
M_Y
=\beta_0+\beta_BM_X+qD_X^2+r_M,
$$

$$
D_Y
=\left(\beta_W+hM_X\right)D_X+r_D.
$$

- $q$: do dyads who differ more on $X$ have a different average $Y$?
- $h$: does the within-dyad $X$–$Y$ association change with average $X$?

$D_X^2$ is unchanged by a label swap, whereas $M_XD_X$ changes sign together
with $D_Y$. Both terms are therefore exchangeable.

For member $i$ with partner $k$, let

$$
M_X=\frac{X_i+X_k}{2},
\qquad
d_i=X_i-M_X=\frac{X_i-X_k}{2}.
$$

The extended member-level DIM is

$$
E(Y_i\mid X_i,X_k)
=\beta_0+\beta_BM_X+\beta_Wd_i+qd_i^2+hM_Xd_i.
$$

Substitute the actor and partner values step by step:

$$
\begin{aligned}
E(Y_i\mid X_i,X_k)
&=\beta_0
+\frac{\beta_B}{2}(X_i+X_k)
+\frac{\beta_W}{2}(X_i-X_k) \\
&\quad
+\frac{q}{4}(X_i-X_k)^2
+\frac{h}{4}(X_i^2-X_k^2).
\end{aligned}
$$

After fully expanding the squared difference,

$$
\begin{aligned}
E(Y_i\mid X_i,X_k)
&=\beta_0
+\frac{\beta_B+\beta_W}{2}X_i
+\frac{\beta_B-\beta_W}{2}X_k \\
&\quad
+\frac{q+h}{4}X_i^2
+\frac{q-h}{4}X_k^2
-\frac{q}{2}X_iX_k.
\end{aligned}
$$

Thus, one discrepancy term and one moderation term in DIM coordinates become
actor-squared, partner-squared, and actor-by-partner terms in APIM coordinates.
The extended DIM is not more informative than an appropriately extended APIM;
it makes the exchangeable structure easier to see and describe. It is no
longer equivalent to the **standard linear** APIM, but it remains equivalent to
this nonlinear exchangeable APIM.

## Minimal R prototype

The following simulation creates a residual elevator–seesaw association while
keeping the signed residual correlation near zero.

```r
simulate_extended_dim <- function(
    J = 2000,
    beta_0 = 0,
    beta_between = 0.6,
    beta_within = 0.3,
    sigma_mean = 1,
    sigma_dev = 0.7,
    lambda = 0.9,
    seed = 42
) {
  set.seed(seed)

  # Predictor elevator and seesaw coordinates
  m_x <- rnorm(J)
  d_x <- rnorm(J)
  x1 <- m_x + d_x
  x2 <- m_x - d_x

  # Exchangeable residual extension
  z_mean <- rnorm(J)
  r_mean <- sigma_mean * z_mean
  log_var_dev <- 2 * log(sigma_dev) + lambda * z_mean
  sd_dev <- exp(0.5 * log_var_dev)
  r_dev <- rnorm(J, mean = 0, sd = sd_dev)

  m_y <- beta_0 + beta_between * m_x + r_mean
  d_y <- beta_within * d_x + r_dev
  y1 <- m_y + d_y
  y2 <- m_y - d_y

  data.frame(
    x1, x2, y1, y2,
    m_x, d_x, m_y, d_y,
    r_mean, r_dev, sd_dev
  )
}

dat <- simulate_extended_dim()

with(dat, c(
  signed_correlation = cor(r_mean, r_dev),
  magnitude_association = cor(r_mean, abs(r_dev))
))
```

The first correlation should fluctuate around zero. The second should be
positive when $\lambda>0$.

In an application, `m_x`, `d_x`, `m_y`, and `d_y` must first be constructed
from one consistently ordered pair of member rows per dyad. A compact joint
negative log-likelihood is:

```r
nll <- function(par, data) {
  b0 <- par[["b0"]]
  b_between <- par[["b_between"]]
  b_within <- par[["b_within"]]
  sd_mean <- exp(par[["log_sd_mean"]])
  alpha_dev <- par[["alpha_dev"]]
  lambda <- par[["lambda"]]

  r_mean <- data$m_y - (b0 + b_between * data$m_x)
  r_dev <- data$d_y - b_within * data$d_x
  z_mean <- r_mean / sd_mean
  log_var_dev <- alpha_dev + lambda * z_mean

  -sum(
    dnorm(r_mean, 0, sd_mean, log = TRUE) +
      dnorm(r_dev, 0, exp(0.5 * log_var_dev), log = TRUE)
  )
}

start <- c(
  b0 = 0,
  b_between = 0,
  b_within = 0,
  log_sd_mean = 0,
  alpha_dev = 0,
  lambda = 0
)

fit <- optim(start, nll, data = dat)
fit$par
```

This is a mathematical prototype, not a production estimator. A paper should
use a joint Stan or TMB implementation with regularizing priors or appropriate
constraints, diagnostics, uncertainty propagation, and simulation-based
calibration. Regressing $|\hat r_D|$ on an estimated $\hat r_M$ in two stages may
be a useful plot, but it understates uncertainty and should not be the primary
inferential method.

## A focused paper plan

1. Establish the exchangeability symmetry and its standard DIM/DSM
   implications.
2. Develop the residual-driven location–scale DIM and its APIM representation.
3. Present the observed-predictor version as a simpler special case.
4. Evaluate identification, inference, and prediction through simulations and
   one empirical example, supported by open-source software.
5. Treat nonlinear directionless cross-paths as a broader extension unless
   they fit without obscuring the main contribution.

The central paper claim would be:

> Mean–difference coordinates reveal symmetry-compatible heterogeneity and
> nonlinearity that are present, but difficult to recognize, in the conventional
> exchangeable APIM.

## Important cautions and open questions

- The first paper should focus on continuous approximately Gaussian outcomes.
  Bounded scales can produce mechanical mean–variance relationships through
  floor or ceiling effects.
- One signed difference per dyad makes scale effects data-hungry. Simulation is
  needed to establish useful sample sizes and the value of regularization.
- "Mean predicts variability" is an association, not necessarily a causal
  process: the residual mean and residual difference come from the same
  cross-sectional outcomes.
- Exchangeability is stronger than zero covariance. The proposed conditional
  distribution is exchangeable because it is symmetric in $r_D$, not merely
  because its covariance happens to be zero.
- Both predictor and outcome differences must use the same arbitrary member
  ordering. Reversing both signs must leave every likelihood contribution
  unchanged.
- The residual-driven and observed-predictor scale models answer different
  questions and should not be presented as interchangeable.

## Closest existing ideas to distinguish from the contribution

- Iida, Seidman, and Shrout's DSM provides the full directional score model and
  the linear DIM relationship:
  [doi:10.1177/0265407517725407](https://doi.org/10.1177/0265407517725407).
- Rast and Ferrer's dyadic mixed-effects location–scale model predicts
  within-person variability in repeated dyadic measurements. The proposed model
  instead concerns one cross-sectional elevator and seesaw coordinate per dyad:
  [doi:10.1080/00273171.2018.1477577](https://doi.org/10.1080/00273171.2018.1477577).
- Mean–difference plots make heteroskedastic differences visible in measurement
  agreement. The proposed contribution would connect that geometric pattern to
  exchangeability, DIM/DSM constraints, and APIM back-transformations:
  [Bland and Altman (1986)](https://pubmed.ncbi.nlm.nih.gov/2868172/).

A systematic literature review would still be needed before making a strong
novelty claim.
