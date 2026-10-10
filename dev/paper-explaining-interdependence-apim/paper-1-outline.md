# Paper 1 (cross-sectional APIM): outline

Draft, 10 October 2026. Replaces plan.md, paper-idea.Rmd and
paper-outline.Rmd (see git history). Paper 2:
[ild-outline.md](ild-outline.md). Software plan: `dev/roadmap.md` (Proposed
Version 0.2.5). Full references with DOIs: [literature.md](literature.md).

## 1. Status

- Done: [explore-sem-mlm.Rmd](explore-sem-mlm.Rmd) reproduces J-P and
  Niall's FLASHE example (1,486 complete parent–teen dyads) in lavaan and
  glmmTMB (differences below 1e-4), with dyad percentile bootstrap CIs
  (1999 resamples), route diagrams and a covariate example.
- Done: [explore-sem-mlm-details.Rmd](explore-sem-mlm-details.Rmd) refits
  lavaan on the same resamples and compares delta, MLR delta and Monte Carlo
  with a sandwich matrix. The last two are close to the bootstrap; the
  default delta CI is too narrow for the residual covariance (non-normal
  intake).
- To do: simulation, missing data, manuscript text, Section 9.

## 2. Scope and estimand

- Independent dyads, cross-sectional, continuous outcomes, linear APIM with
  fixed slopes; Gaussian ML first. One distinguishable predictor pair is the
  running example; covariates, multiple predictors and exchangeable dyads
  are in Paper 1. Out: random slopes, ILD, nonlinear links, interactions,
  causal claims.
- Target: the model-implied marginal outcome covariance across the
  population of dyads, in unstandardized units (a standardized version must
  transform paths, moments, ψ and the denominator alike).

## 3. The decomposition

Y₁ = a₁X₁ + p₁X₂ + ε₁ and Y₂ = a₂X₂ + p₂X₁ + ε₂ (Kenny, Kashy & Cook,
2006). The subscript of a or p names the outcome member; in the notebooks
the teen is member 1. Assume finite second moments and E(ε | X₁, X₂) = 0,
so Cov(Xⱼ, εₖ) = 0 for all j, k; normality is not needed. This exogeneity
is part of the model. Expanding Cov(Y₁, Y₂), the terms a₁Cov(X₁, ε₂),
p₁Cov(X₂, ε₂), a₂Cov(X₂, ε₁) and p₂Cov(X₁, ε₁) then drop out:

```
Cov(Y₁, Y₂) = a₁a₂σ₁₂ + a₁p₂σ₁² + p₁a₂σ₂² + p₁p₂σ₁₂ + ψ₁₂
            =  C_AA   +  C_AP   +  C_PA   +  C_PP   + C_R
```

If also Cov(ε | X₁, X₂) = Ψ, then Cov(Y₁, Y₂ | X₁, X₂) = ψ₁₂: the
predictor routes exist only in the marginal covariance across dyads. This
is path tracing (Wright, 1921; Boker et al., 2002; ild-outline.md, Section
2). The routes add up to the model-implied covariance; for an untrimmed
APIM fitted by ML on complete data, with divisor-n moments, that is the
observed covariance (explore-sem-mlm.Rmd, Section 6; ild-outline.md,
Sections 2–3).

**Routes** (notebook names; old notes: actor–actor, actor–partner, etc.)
- Actor-driven, C_AA: partners are similar on X, and each person's X
  predicts their own Y. Partner-driven, C_PP: the same similarity, but each
  X predicts the other person's Y.
- Teen-driven, C_AP: member 1's X reaches both outcomes, via the actor path
  into Y₁ and the partner path into Y₂. Parent-driven, C_PA: the same for
  member 2. Residual, C_R: what is left after the predictor routes.
- Groups: C_AP + C_PA "predictor transmission", C_AA + C_PP "predictor
  similarity" (dissimilarity if σ₁₂ < 0). The labels name routes, not
  causes. A member's X adds outcome covariance only through its actor path
  and its partner path together.

**Within-model identity:** Cov_model(Y₁, Y₂) − ψ₁₂ = C_AA + C_AP + C_PA +
C_PP. The drop in residual covariance from an intercept-only model to the
APIM equals this sum only if both reproduce the same marginal outcome
covariance (same sample, estimation and moments). Do not compare residual
covariances across separate fits without that check.

**Correlation points** use one model-implied denominator for all terms:

```
c_k = C_k / √(Var(Y₁)·Var(Y₂)),   c_AA + c_AP + c_PA + c_PP + c_R = ρ_model
Var(Y₁) = a₁²σ₁² + p₁²σ₂² + 2a₁p₁σ₁₂ + ψ₁₁
Var(Y₂) = a₂²σ₂² + p₂²σ₁² + 2a₂p₂σ₁₂ + ψ₂₂
```

- Each c_k is signed, not a correlation, proportion or variance share, and
  can lie outside ±1. Percentages can be negative or above 100% when routes
  cancel, and are unstable near a zero total. Report the observed r beside
  ρ_model; do not rescale the c_k to sum to r.
- The residual correlation divides ψ₁₂ by the residual SDs, c_R by the total
  outcome SDs; only c_R is on the routes' scale (Model A below: .286 vs .170).

**Software caution.** State where the predictor moments come from (SEM
parameters, or the dyad-level covariance with divisor n). ψ₁₂ must be the
total covariance left between the members: a shared dyad effect, a
random-effect covariance, a residual covariance or their sum (in the glmmTMB
model of explore-sem-mlm.Rmd, the dyad random-effect covariance).

## 4. Covariates and multiple predictors

In matrix form, Σ_Y = BΣ_X B′ + Ψ with B = [a₁ p₁; p₂ a₂]: each route is a
path into Y₁ × a predictor (co)variance × a path into Y₂. B holds fixed
paths, not random-effect covariances. With covariates Z, Y = α + BX + ΓZ + ε
and Cov(ε, (X, Z)) = 0, Σ_Y = BΣ_XX B′ + ΓΣ_ZZ Γ′ + Ψ + BΣ_XZ Γ′ + ΓΣ_ZX B′.

- Report the focal, covariate, cross-block and residual terms of element
  (1, 2); correlated constructs within a block add cross terms too. Giving a
  cross term to one construct needs a stated convention; it is not a unique
  share. Correlation points use the outcome SDs of the full model.
- Decided in explore-sem-mlm.Rmd, Section 6 (parent gender): name covariates
  by variable, show the ten routes as separate panels, and group the four
  mixed routes as "Efficacy and parent gender together". Interactions would
  need a decomposition per group and are not in Paper 1.
- Covariate-adjusted slopes with marginal moments still give the marginal
  target. A conditional target, Cov(Y | Z = z) = B Cov(X | Z = z) B′ +
  Cov(ε | Z = z), needs conditional moments, and a constant Ψ there needs
  homoscedasticity. Linear residualization is not in general conditioning.

## 5. Exchangeable dyads

With a₁ = a₂ = a, p₁ = p₂ = p and σ₁² = σ₂² = σ², Cov(Y₁, Y₂) =
2apσ² (member-driven) + (a² + p²)σ₁₂ (similarity) + ψ₁₂. The two
member-driven terms are equal and the seats arbitrary, so pool them.
Second-order exchangeability also needs equal predictor means, intercepts
and residual variances; a full claim needs a joint distribution unchanged
by swapping labels. Equality constraints in a distinguishable model test
symmetry; they do not make the dyads exchangeable.

## 6. Inference and simulation plan

- CIs must carry the joint uncertainty of the paths, the predictor and
  covariate moments, the residual parameters and the denominator; the
  7 October pilot found that fixed predictor moments undercover. Keep this
  apart from inference given a fixed design.
- Dyad bootstrap: resample whole dyads, refit, recompute all moments and
  denominators. Fix the interval type, the resamples (1999 now) and
  failed-fit handling in advance. SEM software already gives such CIs for
  defined parameters (lavaan); that alone is not the contribution.
- Simulation factors: number of dyads, predictor correlation, unequal
  variances, symmetry, signs and cancellation, residual dependence, one
  covariate setting, near-zero total. Stress cases: near-zero path products
  (delta CIs degenerate; the bootstrap is not automatically valid), squared
  terms under exchangeability, boundary estimates. Methods: bootstrap,
  delta, MLR delta, Monte Carlo with sandwich. Metrics: bias, empirical SE,
  coverage, width, convergence, Monte Carlo error.
- That the routes add up is an algebra check, not evidence of accuracy.
  Start with complete pairs; with missing data, fit and moments need aligned
  samples.

## 7. Argument and displays

Sections: (1) introduction: precedents, equal-total example, no equations;
(2) model and routes; (3) decomposition and reporting, with the waterfall;
(4) covariates, multiple predictors, exchangeability; (5) estimation and
uncertainty: bootstrap box, short delta formula, R/Mplus workflow; (6)
simulation of estimator and CI behaviour, not the algebra; (7) empirical
example; (8) discussion with a minimum reporting checklist; (9) supplement.

Aim for 6–8 compact equation groups, each with a plain reading. Writing
models: Laurenceau and Bolger (2005), Ledermann et al. (2011), Gistelinck et
al. (2018).

**Equal-total example** (figure code: paper-idea.Rmd, chunks
same-total-calculation and same-total-figure, at commit ce0cb770), with
σ₁² = σ₂² = 1 and σ₁₂ = .40 in both models:
- A: a₁ = .50, a₂ = .40, p₁ = .20, p₂ = .30, ψ₁₁ = .50, ψ₂₂ = .55, ψ₁₂ = .15.
- B: a₁ = .70, a₂ = .60, p₁ = p₂ = .05, ψ₁₂ = .25; ψ₁₁ = .3495 and
  ψ₂₂ = .5095, so that both Var(Y) match A.
- Both give Cov(Y₁, Y₂) = .484 and ρ_model = .548, but A puts more into the
  member-driven routes, B into actor-driven and residual.

## 8. Positioning

- The decomposition, route names, signed reporting, diagrams and APIM
  software have precedents; do not claim priority: Kenny, Kashy and Cook
  (2006, p. 146, full page unchecked); Kenny (2013, webinar); Kenny (n.d.,
  handout); APIM_MM (Kenny, 2016, 2019); Bolger and Laurenceau (2016,
  FLASHE webinar); Kenny, Ackerman and Kashy (2024, Section 23.5, pp.
  577–580). Applications: Popp et al. (2008), Dwyer et al. (2017), Ferraris
  et al. (2022).
- Framing: Wickham and Knee (2012). No application gives CIs for the
  contributions. Contribution: an auditable synthesis with validated
  inference and reproducible software; if it only reproduces existing
  calculations, a tutorial. The attribution is statistical, not causal.

## 9. Open decisions

- Reporting scale: percent of total covariance (both notebooks) or signed
  correlation points (old plan; Kenny's materials). Percentages break down
  under cancellation or a near-zero total.
- p-values: bootstrap p-value stars on paths and routes (explore-sem-mlm.Rmd,
  Section 5) or none, only CIs and a few prespecified contrasts (old plan).
  Tests would need defined nulls and a calibration check.
- With collaborators: target journal (sets the length), empirical example,
  scope, division of work and authorship.
- Missing data: how far beyond complete pairs; decide before the simulation.

## 10. Paper 3 (note)

Generalized outcomes (binary, count), low priority. The total covariance
identity holds, but a four-route split on the response scale needs a stated
rule; keep latent, linear-predictor and observed scales apart. Marginal
regressions alone do not determine the dependence between partners; a full
joint outcome model is needed. Prior art: Leckie et al. (2020); Loeys and
Molenberghs (2013); Loeys et al. (2014).
