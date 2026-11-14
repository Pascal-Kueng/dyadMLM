# Paper 1 (cross-sectional APIM tutorial): outline

Draft, 10 October 2026, revised 1, 13 and 14 November 2026. Paper 1 is a tutorial: why
to split the covariance between partners' outcomes into routes, how to do
it, and how to read the result, with one or two examples and code.

Replaces plan.md, paper-idea.Rmd and
paper-outline.Rmd (see git history). Paper 2:
[ild-outline.md](ild-outline.md). Software plan: milestone
[APIM covariance decomposition](https://github.com/Pascal-Kueng/dyadMLM/milestone/5). Full references with DOIs: [literature.md](literature.md).

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
- To do: the housework simulation, blavaan and brms code, a formal test of
  the FLASHE pairing differences (Section 9), a FLASHE covariate check (teen
  age, parent education: does a covariate add a negative part?), the
  coverage check, missing data, manuscript text, Section 9.

## 2. Scope and estimand

- Independent dyads, cross-sectional, continuous outcomes, linear APIM with
  fixed slopes; Gaussian ML first. One distinguishable predictor pair is the
  running example; covariates, multiple predictors and exchangeable dyads
  are short extensions. Out: random slopes, ILD, nonlinear links,
  interactions (except the optional dyad-types example, Section 9), causal
  claims.
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

**Negative routes.** A route is negative when its paths and its predictor
moment multiply to a negative number, for example a positive actor path and
a negative partner path. The tutorial shows how to report them.
- In everyday couple and family data, interdependence seems almost always
  positive. A screen of about 35 open datasets (16–17 October 2026) found no
  negative partner correlation from a real process.
- Negative routes do occur, but they are small or need replication
  (correlation points):
  - FLASHE reactive parenting (NCI public-use files), 1,587 dyads. X: own "I don't like exercise".
    Y: "the parent makes sure the teen gets enough physical activity",
    rated by both. Actor-driven −.004 and partner-driven −.005, together about 2%
    of r = .45. Both ratings describe the same parenting.
  - MEPS 2017–2022, female–male couples (n = 9,388): wife's poor health →
    husband's doctor visits. Wife-driven route −.011 [−.014, −.008], about
    3% of r = .42. Holds for couple means, not within couples over time.
  - MEPS female couples (n = 86): work hours → low energy. Member-driven
    routes −.19 [−.32, −.09], about 70% of r = .27. Picked from about 1,900
    models, so it needs replication.
- Not used: MEPS wage → work hours (dull and almost definitional) and
  Zygar-Hoffmann et al. (2020) time alone ~ time with others (a time
  budget, ild-outline.md Section 11).
- A simulated example shows mixed signs and a total near zero.
- The screen's scripts are lost, so recompute a number before citing it.

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
  need a decomposition per group and are not in Paper 1, except the
  optional dyad-types example (Section 9).
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

## 6. Inference

- CIs must carry the joint uncertainty of the paths, the predictor and
  covariate moments, the residual parameters and the denominator; the
  7 October pilot found that fixed predictor moments undercover. Keep this
  apart from inference given a fixed design.
- Dyad bootstrap: resample whole dyads, refit, recompute all moments and
  denominators. Fix the interval type, the resamples (1999 now) and
  failed-fit handling in advance. SEM software already gives such CIs for
  defined parameters (lavaan); that alone is not the contribution.
- The tutorial recommends the dyad bootstrap and shows the code. A full
  simulation study is not its aim. A small coverage check goes in the
  supplement (size open, Section 9). The full design below is for the
  software check in #135.
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

## 7. Manuscript outline

Working title: *A guide to explaining interdependence in the actor-partner
interdependence model (APIM): Where does the partner correlation come
from?*

Structure: Introduction, a body organised by concept (no Methods section,
and each example gets a short "data and model" paragraph), Discussion, a
printed appendix and an online supplement.

### 1. Introduction (agreed 13 November 2026)

- Partners’ outcomes tend to be related. This nonindependence is the defining feature of dyadic data and presents an analytical challenge (Kenny, Kashy & Cook, 2006).
- The actor-partner interdependence model (APIM) is the most popular statistical model to address this challenge and answer dyadic questions (Kenny, 2018). Yet reports focus almost exclusively on actor and partner effects and treat the covariance or correlation between partners' outcomes as a nuisance that needs to be accounted for in the model simply to make the inference for the actor and partner effects correct (see Kenny, Ackerman & Kashy, 2024, pp. 566, 577). However, that covariance can be of substantive interest. One can ask: Why are partners similar, and how much of that similarity does the model explain?
- Consider this other angle: every researcher is familiar with R squared, which is used as an indication of how well a model explains variance in an outcome. When it comes to dyadic models, however, we have two outcomes whose variances need to be explained, alongside their covariance.
- However, how much covariance the model explains is not the most interesting part. Instead, how the model explains this covariance can be of substantive interest.
- Path-tracing principles (Wright, 1921) can be applied to the APIM to figure out through which paths the predictors' variances and covariances explain the outcomes' covariance.
- The different covariance contributions can be grouped into four distinct routes plus a residual (unexplained) part: ....
- This method has been previously developed and described by:
  - Kenny, Kashy & Cook (2006, p. 146) [check the page in print: four routes or only the total share?];
  - Bolger & Laurenceau's FLASHE webinar (2016);
  - Dwyer et al. (2017, appendix), also an application;
  - Kenny, Ackerman & Kashy (2024);
  - Kenny's handout (n.d.) and his APIM_MM web app (Kenny, 2015).
- Yet, to this day, very few publications use this method. A brief non-systematic review of the literature, through keyword and full-text searches and forward citations of known applications and method sources, revealed only 14 applications, 10 of them in journals (e.g., Popp et al., 2008; Dwyer et al., 2017; Ferraris et al., 2022; full list in Table S1).
- One reason might be that the method sources above are scattered. Although together they provide the formulas, route diagrams, worked examples and a web app that computes grouped contributions, no single source yet guides readers from fitting the model to reporting, plotting and confidence intervals for the contributions. To our knowledge, none of the sources or applications reports such intervals. Beyond route diagrams, we also found little guidance on how to plot the contributions, especially when routes with opposite signs partly cancel out. Finally, the applications differ in how they report the contributions, for example as covariances, percentages or correlation points, and for each route or only as a total share (Table S1).
- Thus, the aims of the current paper are to introduce the concept to a wider audience and the growing community of dyadic and relationship scientists, and to provide an applied conceptual guide with real-world and simulated data examples. It demonstrates how to describe, interpret and visualize covariance contributions, and how to obtain confidence intervals for them.
- Code is provided for structural equation modelling (SEM) with lavaan, for frequentist multilevel modelling (MLM) with glmmTMB, for Bayesian MLM via brms, and Bayesian SEM via blavaan. Advantages and disadvantages of each approach are briefly discussed.
- While the logic extends, with additional choices, to (intensive) longitudinal data and to binary, ordinal or count outcomes, the current paper focuses on the simpler case of cross-sectional data and continuous outcomes analysed with linear models. It will cover distinguishable and indistinguishable dyads and also demonstrate the case of multiple APIM predictors and covariates.
- Optionally include:
  - code about 50 recent APIM papers and report how many say how much of the partner correlation their model explains.
  - mention that we will include an example where different dyad-types have different variance-covariance components? And then run this with multigroup in SEM in one model (does lavaan support that), and in glmmTMB with the dyadMLM workflow (unreleased vignette)? Or too much for this first paper?
    - maybe as a Short extension, optional example. lavaan supports multigroup models (`group =`), with routes defined per group and differences tested by constraints. In glmmTMB, dyadMLM’s composition blocks give the same tests. A cheap example: FLASHE mother–teen vs father–teen. NCI’s FLASHE user guide already tests mother/father differences, and Figueroa et al. (2019) already compared the explained shares by parent role, so it could even be the second example, without new data. Otherwise one paragraph plus supplement code.
  - mention that we show how to deal with random effects? maybe even with an example of school clustering? Does this work in SEM too or only MLM?

Sections 2–9 are a draft (13 November 2026).

### 2. The routes

- Goal: name the five routes, show how each is built and what they add up to.
- Running example: FLASHE, teen and parent self-efficacy → fruit and vegetable intake (Bolger & Laurenceau, 2016).
    - Data and model in one paragraph: 1,486 complete parent–teen dyads, measures, missing data, estimation.
    - The FLASHE terms do not allow sharing the data, so the supplement has code only.
- The APIM equations and a route diagram, one panel per route.
- The five routes, each in one plain sentence:
    - Actor-driven: partners are similar on X, and each person's X predicts their own Y.
    - Partner-driven: the same similarity, but each X predicts the other person's Y.
    - Teen-driven: the teen's X reaches both outcomes, through the actor path into the teen's Y and the partner path into the parent's Y.
    - Parent-driven: the same for the parent's X.
    - Residual: the residual covariance, what the predictors leave unexplained.
- The first four are the predictor routes. The teen- and parent-driven routes are the member-driven routes.
- Name the routes once in Kenny's terms too. Kenny et al. (2024, p. 577) call the member-driven routes "spurious", with X as a common cause.
- Each predictor route is a path into one outcome × a predictor variance or covariance (a predictor moment) × a path into the other outcome. Its sign follows from these three.
- The routes always add up to the model-implied covariance. This rests on two APIM assumptions: the residuals are uncorrelated with both partners' predictors, and the outcomes do not affect each other. Normality is not needed.
- Figure: two models with the same partner correlation but different routes. The total alone does not show how the model explains the covariance (placement open).

### 3. Reading the routes

- Goal: which total the routes split, which scale to report, how much the model explains, and common misreadings.
- Which total: the routes split the model-implied covariance. It equals the observed covariance for the untrimmed APIM fitted by ML on complete data (with divisor-n predictor moments). Report the observed and the model-implied r.
- Opposite signs: routes can cancel, so a small total can hide large routes.
- Three scales, side by side. Recommend one (open decision).
    - Covariance: the route in unstandardized units.
    - Correlation points: the route divided by the product of the model-implied outcome SDs. The routes then add up to the model-implied r.
    - Percent of the total covariance: can be negative or above 100% when routes cancel, and is unstable near a zero total.
- How much is explained: the predictor routes' share of the total covariance. Like R², but it can be negative or above 100%.
    - Compute it within one model. The drop in residual covariance between two separate fits gives the same share only if both fits reproduce the same outcome covariance.
- The residual route is not the residual correlation. In correlation points, the residual route divides the residual covariance by the total outcome SDs, the residual correlation divides it by the residual SDs.
- Box "what the routes are not": not causal shares (the split is statistical), not variance explained, not correlations or proportions (they are signed, and correlation points can lie outside ±1).

### 4. Confidence intervals

- Goal: intervals that carry all sources of uncertainty, with the dyad bootstrap as the main method.
- Paths, predictor moments, residual variances and covariance, and the denominator are all estimated and vary together. Treating the predictor moments as fixed gives intervals that are too narrow for the population of dyads.
- Main method: the dyad bootstrap. Resample whole dyads, refit, and recompute all moments, routes and denominators (percentile intervals, 1999 resamples in FLASHE).
- Why not the default delta (Wald) interval: it is symmetric and assumes normal data, but products of estimates can have skewed sampling distributions. In FLASHE it was narrower than the bootstrap for the residual covariance.
- Alternatives:
    - MLR delta: the same interval with robust standard errors. Close to the bootstrap in FLASHE.
    - Monte Carlo: draws from the joint robust covariance matrix plus draws of the predictor moments. Close to the bootstrap in FLASHE.
    - Bayesian: credible intervals from the routes per posterior draw.
- Hard case: near-zero path products. Delta intervals break down there, and the bootstrap is not automatically valid either.
- Supplement: a small coverage check, how often the 95% intervals contain the true value (size open, or none).

### 5. FLASHE results: plotting and reporting

- Goal: a complete report of the running example, with intervals.
- Figure: route diagram with the estimates and 95% dyad bootstrap CIs.
- Figure: waterfall with 95% dyad bootstrap CIs. Each bar starts where the previous route ended, so the last bar ends at the total, even when routes cancel.
- Observed and model-implied r.
- A results paragraph readers can adapt.

### 6. Simulated example: routes with opposite signs

- Goal: how to read, plot and report routes that cancel.
- Constructed example, e.g. housework hours predicted by paid work hours.
    - Own paid work lowers own housework, and the partner's raises it, so the member-driven routes are negative.
    - If partners' paid hours correlate positively, the actor- and partner-driven routes are positive, and the routes cancel in part.
- Waterfall and results paragraph, as for FLASHE.
- One paragraph on real data: sizeable negative routes seem rare. Small real ones: FLASHE reactive parenting and MEPS health → doctor visits (Negative routes, outline Section 3).

### 7. Extensions

- Goal: what changes for indistinguishable dyads, covariates, several predictors and, optionally, dyad types.
- Indistinguishable dyads: the two member-driven routes are equal, so they are pooled into one.
- Covariates, shown with FLASHE plus parent gender (ten routes). Routes are named by variable.
    - Mixed routes link self-efficacy and parent gender through their covariance. A mixed route has no unique owner, so the four are reported together.
- Several predictor pairs: the same logic, with more routes and mixed routes (worked example open).
- Optional: dyad types with different routes (multigroup), e.g. FLASHE mother–teen vs father–teen (credit Figueroa et al., 2019). Test whether a route differs between groups, not whether the paths are equal.

### 8. Software

- Goal: the same routes from lavaan, glmmTMB, blavaan and brms, and what each package needs.
- lavaan and glmmTMB agree on FLASHE (differences below 1e-4). blavaan and brms are still to do.
- lavaan: routes as defined parameters (`:=`), free predictor moments (`fixed.x = FALSE`), bootstrap built in.
- blavaan: the same syntax, routes per posterior draw (blavaan 0.6-1 or later, otherwise compute them from the draws).
- glmmTMB: the predictor moments come from the data (divisor n), so the bootstrap wraps the whole computation. The residual route is all covariance left between the members, in our model the dyad random-effect covariance.
- brms: the predictor moments must be modelled too, or the intervals miss their uncertainty.
- Table: pros and cons of the four packages (ease, speed, missing data, intervals, extensions).
- Code: lavaan in Appendix A, the rest in the supplement. Show `decompose_apim_covariance()` only if released by submission.

### 9. Discussion

- What the routes add: how the model explains the partner covariance, not only how much. What they cannot say: causes, unmeasured shared influences.
- Limits and outlook: missing data beyond complete pairs, longitudinal data, intensive longitudinal data (Paper 2), binary, ordinal or count outcomes, further clustering such as schools.
- Reporting checklist: observed and model-implied r, all routes with CIs, the scale and its denominator, the software settings (source of the predictor moments, interval type, resamples, failed-fit handling).

### Appendix and supplement

- Appendix A: annotated lavaan listing (about 15–20 lines). Optional Appendix B: the algebra, otherwise in the supplement.
- Supplement (Zenodo): code for all four packages, the coverage check, figure code, Table S1 (applications) and the 50-paper coding if done.

Keep equations few, each with a plain reading. Writing models: Laurenceau
and Bolger (2005), Ledermann et al. (2011), Gistelinck et al. (2018).

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
  handout); APIM_MM (Kenny, 2015); Bolger and Laurenceau (2016,
  FLASHE webinar); Dwyer et al. (2017, appendix); Kenny, Ackerman and Kashy
  (2024, Section 23.5, pp. 577–580). Applications: Popp et al. (2008), Dwyer et al. (2017), Ferraris
  et al. (2022).
- Framing: Wickham and Knee (2012). No application gives CIs for the
  contributions. Contribution: a tutorial that brings the scattered
  precedents together, with rules for reading the routes, CIs and code. The
  attribution is statistical, not causal.

## 9. Open decisions

- Reporting scale: percent of total covariance (both exploration notebooks) or signed correlation points (old plan, and Kenny's materials). Percentages break down under cancellation or a near-zero total.
- p-values: bootstrap p-value stars on paths and routes (explore-sem-mlm.Rmd, Section 5) or none, only CIs and a few prespecified contrasts (old plan). Tests would need defined nulls and a calibration check.
- With collaborators: target journal (sets the length), scope, division of work and authorship.
- Target journal: scan of 13 November 2026, in this order. Free open access assumes a UZH corresponding author.
    1. Personal Relationships: Original Article, 9,000 words including references and tables. Free OA through the Wiley deal (ends 31 December 2027). Core APIM readers. About 14% accepted, median 306 days to acceptance.
    2. Multivariate Behavioral Research: Tutorial, 40 pages including references, appendices printed. OA likely free (T&F deal). Best fit of type and length, but reviewers may ask for a coverage simulation.
    3. Journal of Family Psychology: regular article, about 5,000–6,000 words. USD 3,500, or free green OA in ZORA. Home of Kenny's and Ledermann's APIM papers.
    4. Health Psychology: methods tutorial, about 5,000–6,000 words. USD 3,500 or green OA. Needs a health framing.
    5. SEM, Teacher's Corner: 25 pages, appendices printed. OA likely free (T&F deal). SEM methodologists as readers.
    6. Behavior Research Methods (tutorial, no word limit found, free OA), then the free diamond-OA journals The Quantitative Methods for Psychology (no limit stated) and Methodology (6,000 words including everything).
    - Not verified: JFP's page limits and the APA fee (USD 3,500), whether the T&F deal covers MBR tutorials and Teacher's Corner papers (ask the UZH OA team), whether Personal Relationships prints appendices.
- Running example (decided for now, 14 November 2026): FLASHE, because its four parent–teen pairings allow a dyad-types example. Keep Time and Ties and American Couples in mind. The 9 October meeting had suggested a different example.
- Missing data: how far beyond complete pairs.
- Second example. The draft uses a simulated one. Real-data alternatives (none has sizeable negative routes, outline Section 3):
    - FLASHE split by parent–teen pairing. One APIM per pairing (16 October 2026, NCI public-use files, 1,437 complete pairs, scripts lost): the teen-driven route is .116 [.062, .173] correlation points for fathers with daughters (n = 179), against .026, .033 and .051 for father–son, mother–daughter and mother–son. Explained share 32% against 9–20%. Not tested yet: fit one joint model (lavaan `group =` or dyadMLM composition blocks) and bootstrap the route differences.
    - American Couples: application submitted (form filled in 20 October 2026), no answer by 14 November. Only the applicant may work with the data, J-P and Niall see aggregated results. Analysis with an AI tool probably needs the archive's written OK (ask mra@help.hmdc.harvard.edu).
    - Time and Ties couples (aggregated baseline data).
- An example with two predictor pairs (the introduction promises multiple predictors, but only the covariate example exists).
- The optional introduction items: the 50-paper coding, the dyad-types (multigroup) example (would bring dyad-type interactions into scope), school clustering.
- Equal-total figure: Figure 1 in the introduction or in the routes section.
- Size of the coverage check in the supplement, or none.
- 9 October meeting (minutes outside the repo): R and Mplus code wanted (Mplus is not yet in Section 7). Ask J-P whether to invite David Kenny as a co-author. Still open: the writing platform.

## 10. Paper 3 (note)

Generalized outcomes (binary, count), low priority. The total covariance
identity holds, but a four-route split on the response scale needs a stated
rule; keep latent, linear-predictor and observed scales apart. Marginal
regressions alone do not determine the dependence between partners; a full
joint outcome model is needed. Prior art: Leckie et al. (2020); Loeys and
Molenberghs (2013); Loeys et al. (2014).
