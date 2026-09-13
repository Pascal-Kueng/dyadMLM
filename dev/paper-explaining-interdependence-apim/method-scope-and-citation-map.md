# APIM decomposition: methods, applications, and citation priorities

Checked **13 September 2026**. Companion to the [51-entry annotated review](literature-review.md)
and [forward-citation audit](citation-audit-2026-09-13.md). This classifies the
earlier 46 references and adds four adjacent methods sources identified during
the design/model check: Gistelinck and Loeys (2019), Savord et al. (2023), Loeys
and Molenberghs (2013), and Loeys et al. (2014). J-P's subsequently supplied
[materials](jp-materials-review-2026-09-13.md) add one grouped 2025 workshop
reference and close the 2024 chapter retrieval gap. These additions do not
increase the count of independent direct application studies.
Citation priorities below are recommendations for the current cross-sectional
linear-APIM manuscript in [plan.md](plan.md), not statements about the overall
importance of the papers.

## What is methodological, and what should we cite?

An applied article can be essential prior art. Classification by article type
must not hide a prior calculation, table, or implementation. Conversely, a
substantial methods article can address a different statistical quantity.

| Role | Sources in the existing review | Implication for the manuscript |
|:--|:--|:--|
| Direct APIM decomposition teaching and software documentation | Bolger and Laurenceau (2016, 2025); Kenny's explained-nonindependence handout; Kenny's APIM_MM manual (2019) | Core attribution for the routes, signed contributions, correlation-unit reporting, and existing software. The 2025 materials add a matched numerical example and model files. |
| Direct published decomposition methodology | Kenny, Ackerman, and Kashy (2024) | Now verified in full: Section 23.5 supplies basic and multiple-predictor/covariate partitions. Central methods citation, with a two-wave example. Its separate ILD section does not partition predictor routes at each level. |
| Direct conceptual methods contribution | Wickham and Knee (2012) | Cite for connecting interdependence theory to APIM quantities and explicitly discussing covariance explanation/path tracing. Its worked calculation compares covariance across fitted models; it is not a verified four-route table. |
| Substantial general covariance/path methods | Boker et al. (2002); Jones and West (2005); Zhang et al. (2015), RAMpath | Boker is the closest algorithmic/path-algebra foundation. Jones-West concerns undirected Gaussian graphs. RAMpath supplies general SEM software and covariance-route output. Cite the latter two where those broader claims are discussed. |
| Direct applied precedents | Dwyer (2017); Burns (2019); Figueroa et al. (2019); Lee et al. (2021); Ferraris et al. (2022); Fu et al. (2025) | Dwyer and Ferraris should be cited for direct prior use and published calculations. Burns is particularly useful for contribution-table reporting. The others document uptake; a compact application paragraph or supplementary table is sufficient. |
| Applied grouped or total attribution | De Padova et al. (2021); Velten and Margraf (2017); Jang (2016 dissertation) | De Padova deserves specific citation when discussing negative and cross-predictor components. Velten and Jang concern broader total explanation; do not equate them with four separately reported routes. |
| Close applied preprint with an explicit analytic treatment | Cavalcanti et al. (2026), v1 | Cite as a preprint when positioning signed/multiple-predictor decomposition. Its repeated-encounter mixed model and fixed-prediction covariance target require explicit distinctions from our target. |
| Substantial adjacent dyadic methods | Griffin and Gonzalez (1995); Gonzalez and Griffin (1999); Kenny and Ledermann (2010); Ledermann et al. (2011); Gistelinck et al. (2018); Ledermann and Kenny (2017); Stas et al. (2018) | Different targets: individual/dyad correlations, dyadic-pattern ratios, mediation, distinguishability, estimation, and software. Cite where used, rather than treating them as focal route-decomposition articles. Some full-text coverage remains incomplete in the review. |
| Longitudinal/heterogeneity methods and exposition | Laurenceau and Bolger (2005); Bolger and Shrout (2007); Bolger and Laurenceau (2013); Gistelinck and Loeys (2019); Savord et al. (2023); Laws et al. (2026) | Important for ILD context and a subsequent ILD paper. Bolger-Shrout actually partitions dependence across temporal levels; Gistelinck-Loeys and Savord model longitudinal actor/partner effects. None establishes the focal route partition at both levels. Laws concerns heterogeneity of physiological covariation. |
| Non-Gaussian APIM methods | Loeys and Molenberghs (2013); Loeys et al. (2014) | The 2013 paper is a substantial technical study of binary/count APIM; the 2014 paper is a practical GEE guide. Essential generalized-APIM context, with no focal predictor-route partition verified. |
| General multilevel extensions | Johnson (2014); Leckie et al. (2020) | Substantial methods contributions to random-slope variance summaries and count-model variance/covariance/ICC. Especially relevant to later extensions; not direct APIM predictor-route partitions. |
| General foundations and syntheses | Kline (2016); Kenny's path-tracing web tutorial; Kenny (1996); Kenny and Cook (1999); Cook and Kenny (2005); Campbell and Kashy (2002); Kenny, Kashy, and Cook (2006); handbook chapters by Kashy/Kenny (2000), Kenny/Kashy (2014), Kenny/Kashy/Bolger (1998), and Gonzalez/Griffin (2004, 2023) | Use a standard APIM foundation and appropriate general tracing source. Preserve the earlier chapters' verification limits; the now-inspected 2024 chapter is classified separately above. |
| Other applied or duplicate records | Gonzalez and Siarkiewicz (2006); Jang et al. (2025); Burns (2020 abstract) | Respectively, another dyadic correlation decomposition; a related negotiation application without a verified focal passage; and a repeat report of Burns (2019). None adds an independent four-route precedent. |

For Paper 1, the recommended citation backbone is **Kenny, Ackerman, and Kashy
(2024), Section 23.5**, for published decomposition methods; **Kenny, Kashy,
and Cook (2006)** for the APIM; **Boker et al. (2002)** for path algebra; **Wickham and Knee
(2012)** for earlier covariance-explanation framing; the **Bolger-Laurenceau
webinar and Kenny handout/manual** for direct methodology; and **Dwyer and
Ferraris** for published application precedents. Add **Burns, De Padova, and
Cavalcanti** where discussing existing reporting, multiple predictors, and signed
contributions. They need not all occur in one citation cluster. Kline is the
general SEM source actually cited in Dwyer's tracing sentence; this establishes
citation lineage, not APIM-specific content in Kline.

## Designs and response models of the closest applications

The classification concerns the analysis that produced the partition, not every
analysis in the article. Here, “linear” describes the response model; it does not
assert that the observed scores are normally distributed.

| Source | Design and model used for the focal analysis | What is partitioned / qualification |
|:--|:--|:--|
| [Dwyer (2017)](https://pmc.ncbi.nlm.nih.gov/articles/PMC5512865/) | Cross-sectional FLASHE; 1,443 parent-adolescent dyads; linear observed-variable APIM | Fruit/vegetable intake interdependence. Paths from final and controls-only models; calculation supplement remains unavailable. |
| [Burns (2019)](https://pmc.ncbi.nlm.nih.gov/articles/PMC6697559/) | Cross-sectional FLASHE; 1,854 dyads; Stata SEM, ML with missing data | Physical-activity covariance; four products per predictor. No nonlinear response link specified. |
| [Figueroa et al. (2019)](https://pmc.ncbi.nlm.nih.gov/articles/PMC7676308/) | Cross-sectional FLASHE; 1,649 dyads; multiple-group observed-variable SEM | Parent/adolescent beverage-intake covariance; mother/father groups. No generalized count link specified. |
| [Lee et al. (2021)](https://pmc.ncbi.nlm.nih.gov/articles/PMC13166139/) | Baseline surveys from an intervention trial; 467 dyads; Mplus ML linear APIM | Closeness covariance. The article explicitly calls this analysis cross-sectional. Closeness is a 1-7 score; poor-mental-health days are transformed by log(1+x). Neither establishes ordinal/count-link decomposition. |
| [Ferraris et al. (2022)](https://pure.rug.nl/ws/files/589396899/ContentServer_1_.pdf) | Cross-sectional caregiver/care-recipient analysis; 215 dyads; linear SEM | Well-being covariance; Appendix A prints four formulas. Its denominator is labelled residual well-being covariance, so do not silently substitute an unconditional target. |
| [Fu et al. (2025)](https://www.researchgate.net/publication/389330862_Associations_of_Parental_Perceived_Health_with_Child_Movement_Behaviors_within_Two-Parent_Households) | Cross-sectional 2022 NSCH; 20,156 households; weighted Stata SEM/FIML for the partition | Covariance of parental health ratings, which are mediators. Logistic/Poisson regressions occur in a separate aim; the partition uses the linear SEM, not those links. Health ratings are ordinal but treated numerically. Its “cross-lagged” wording does not establish longitudinal data. |
| [De Padova et al. (2021)](https://pmc.ncbi.nlm.nih.gov/articles/PMC8209622/) | Cross-sectional; 212 survivor-caregiver dyads, 184 complete APIM dyads; APIM_MM linear models | Continuous symptom-score nonindependence. Binary PTSD classifications are descriptive, not the outcomes of the partition. Supplement tables include signed/grouped and cross-predictor terms. |
| [Velten and Margraf (2017)](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0172855) | Cross-sectional survey; 964 couples, 731 complete dyads; GLS/REML | Sexual-satisfaction nonindependence attributed to APIM and between-dyad covariates. Generalized least squares is a linear model with correlated errors, not a generalized response link. |
| [Cavalcanti et al. (2026), v1](https://www.researchsquare.com/article/rs-9910824/v1.pdf) | 1,602 conversations, 1,456 speakers; repeated encounters with crossed person/partner/conversation random intercepts; linear mixed model, REML | Exact covariance of fixed-effect-only predictions, normalized by observed paired-outcome covariance. Separately reports random-effect variance components. Does not partition temporal within-person and between-person APIM routes separately. |

The first eight are cross-sectional analyses. Cavalcanti provides a repeated-
encounter mixed-model precedent; it should not be described as an independent-
dyad cross-sectional analysis or as an ILD decomposition at both temporal levels.
The 2024 chapter's separate worked example predicts attachment from commitment
measured 18 months earlier: a two-wave ordinary APIM partition, not an ILD
partition at both levels. Thus not all existing decomposition illustrations
use contemporaneously measured predictors and outcomes.
The three FLASHE applications also share their underlying survey resource; they
are distinct analyses, not three independent cohorts.

## What already exists for ILD, levels, and non-Gaussian outcomes?

**Bolger and Shrout (2007) is a substantive ILD dependence-decomposition
precedent.** The [author manuscript](https://www.columbia.edu/~nb2229/docs/Bolger%20and%20Shrout-Accounting%20for%20Statistical%20Dependency%20May%202005.pdf)
p. 4 explicitly distinguishes its covariance model from estimation of actor and
partner effects. It separates stable and time-varying covariance. Page 13
attributes 75% of a modeled same-day correlation to daily shared variation and
25% to person-level shared variation. Thus, a partition across temporal levels
already exists; four actor/partner predictor routes at each level were not
presented there. This deserves citation if we discuss an ILD extension.

**Laurenceau and Bolger (2005)** is a substantial diary-methods tutorial, not
merely an applied example. Published pp. 89-95 cover daily residual covariance
and between-person random intercept/slope covariances, with daily conflict and
intervention predictors. No focal APIM route partition was located in the full
text. **Bolger and Laurenceau (2013)** is broader ILD methodology; its exact
decomposition coverage has not been checked here.

**Gistelinck and Loeys (2019)** is a direct longitudinal-APIM methods reference.
The [paper reproduced in the author's dissertation, Chapter 3](https://backoffice.biblio.ugent.be/download/8635510/8635511)
separates time-averaged/time-specific actor and partner effects and models
stable, contemporaneous, and serial dependence (pp. 87-89). Its example uses
three-week diaries from 66 couples. Modeling effects and covariance at both
levels does not itself establish four predictor-route contributions at both
levels; such a partition was not verified here.

**Savord et al. (2023)** extends the longitudinal APIM in DSEM to random slopes,
heterogeneous residual variances, and multiple outcomes. The
[author-uploaded manuscript](https://www.researchgate.net/publication/360704986_Fitting_the_Longitudinal_Actor-Partner_Interdependence_Model_as_a_Dynamic_Structural_Equation_Model_in_M_plus),
Equations 5-8/Figures 7-9, was inspected. It is strong ILD extension context but
does not provide a verified predictor-route covariance partition. Its covariance
between random log-residual variances describes correlated volatility, a
different quantity from covariance between the outcomes themselves.

**Laws et al. (2026)** develops a model of varying physiological interdependence.
The [publisher introduction](https://www.sciencedirect.com/science/article/pii/S0301051126000724)
distinguishes concurrent covariance from directional APIM effects; it describes
DSEM estimation of average interdependence, variation between dyads, and
predictors of that variation. Full methods were not obtained. It is relevant
heterogeneity methodology, but currently not verified evidence of separate
within/between APIM predictor-route partitions or non-Gaussian response links.

**RAMpath (Zhang et al., 2015)** provides general linear SEM covariance-path
calculation, including signed percentages, and longitudinal examples. This
establishes general software/methodological prior art, not a verified dyadic
within/between route-partition example. **Griffin and Gonzalez (1995)** separates
individual and dyad associations in a different correlational model; those
levels must not be confused with repeated-measurement temporal levels.

**Leckie et al. (2020)** is the strongest substantial non-Gaussian methods work
on level partitions in the current list. The [full paper and supplement](https://www.bristol.ac.uk/cmm/media/leckie/articles/leckie2020.pdf)
derive response-scale variance partitions, cross-unit covariance, and ICCs for
Poisson/negative-binomial mixed models, including higher-level/random-coefficient
extensions. Supplement S4.3 (p. 31; PDF page 46) uses total covariance,
conditional on covariates and averaging over random effects. This is not an
APIM predictor-route allocation. **Johnson (2014)** concerns R-squared for
random-slope GLMMs: averaging random-effect variance contributions is a different
quantity from covariance between two dyad members' outcomes.

**Loeys and Molenberghs (2013)** is the stronger direct non-Gaussian APIM
foundation. The [author manuscript](https://documentserver.uhasselt.be/bitstream/1942/14740/1/met_loeys_0112.pdf)
examines binary/count GLMM and GEE estimation, positive/negative within-dyad
association, and marginal moments/ICC. It does not supply a verified allocation
to actor/partner predictor routes. **Loeys et al. (2014)** supplies practical
GEE implementation guidance; its publisher abstract was verified. Non-Gaussian
APIM itself is therefore firmly established, separately from our proposed
observed-outcome route-attribution question.

These distinctions delimit the current evidence:

- **Verified:** cross-sectional linear APIM route partitions; signed and
  multiple-predictor contributions; a crossed mixed-model fixed-prediction
  covariance partition; ILD dependence partitions across levels; and
  non-Gaussian multilevel covariance/ICC derivations.
- **Not verified in the inspected sources:** an APIM predictor-route partition
  separately at both temporal within- and between-person/dyad levels; a complete
  marginal route partition incorporating heterogeneous actor/partner slopes;
  or a focal APIM route allocation of binary/count observed-outcome covariance
  under nonlinear links.
- **Also not located:** intervals for the four product-derived APIM covariance
  contributions or their normalized shares in the inspected materials. The raw
  residual covariance has ordinary SEM uncertainty in J-P's fit. Intervals for
  slopes, indirect effects, or dyadic-pattern ratios are different quantities.

“Not verified” is a bounded literature finding, not a priority claim. In
particular, a multilevel SEM can already represent covariance at each level;
simply applying linear covariance algebra twice is not, by itself, evidence of
a new general statistical principle. An extension must specify its target,
random-slope treatment, scaling, and inference, and compare those to existing
multilevel methods.

## Covariates: full attribution versus adjusted dependence

Targeted source check, **13 September 2026**. These are distinct reporting
questions: attributing the full outcome covariance, including covariates, and
attributing the covariance remaining after adjustment for covariates.

| Source | Covariate handling | What can be concluded |
|:--|:--|:--|
| Kenny, Ackerman, and Kashy (2024), pp. 578-579 | The same two shared covariates enter both outcome equations, with role-specific coefficients in the distinguishable case. Example: married/not and children/not. Table 23.3 includes individual-covariate terms, correlations between covariates, and covariate/focal-predictor cross-terms. | Full partition of the overall outcome correlation, including covariate pathways. Table 23.4 groups predictor-covariate cross-terms under covariates and reports total covariate contribution -2.5%; this grouping is a convention, not a uniquely identified causal share. |
| Kenny (2019), APIM_MM manual pp. 3-4 | Allows between-dyad, within-dyad and mixed covariates, plus optional interactions with member role. Lists six explained groups and unexplained covariance as the seventh. | Broader input support than the chapter's shared-covariate example. The prose does not establish a complete formula/mapping for arbitrary member-specific controls or automatic partner-covariate inclusion. |
| [Dwyer et al. (2017)](https://pmc.ncbi.nlm.nih.gov/articles/PMC5512865/) | Both motivation predictors and both intake outcomes are regressed on parent sex, adolescent sex/age, and parent education. Uses final APIM and controls-only APIM estimates. | The specification supports an adjustment-oriented interpretation: motivation routes explaining dependence after controls. Exact residual moments and denominator remain unverified without the calculation supplement. No full covariate-route allocation is reported. |
| [Lee et al. (2021)](https://pmc.ncbi.nlm.nih.gov/articles/PMC13166139/) | All four core predictor/outcome variables are regressed on mother's age, daughter's age, and maternal non-Hispanic-White indicator. Compares fitted APIM with a model excluding actor/partner effects. | Similar adjustment-oriented interpretation to Dwyer; the main text does not provide all moments needed to reproduce the route percentages. |
| Ferraris et al. (2022), pp. 1400, 1402, 1406 | Caregiver well-being adjusted for caregiver gender, age and care hours; recipient well-being for recipient gender and ADL. Controls predicting support variables and a controls-only fit are not explicitly documented. | Appendix labels predictor variances and outcome denominator as residual quantities, but their model of origin is unclear. Do not assume an identical adjustment procedure to Dwyer. |
| [Velten and Margraf (2017)](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0172855) | Shared predictors include sexual frequency, initiative, communication, relationship duration and household income; other variables have actor/partner effects. Reports 53.7% attributed to APIM and 27.8% to between-dyad covariates. | Applied total/grouped attribution; the covariates include substantive relationship characteristics, not only demographic controls. Exact cross-term grouping behind the percentage is not supplied. |
| De Padova et al. (2021) | Demographic/clinical multiple regressions are separate analyses. Supplementary APIMs contain depression alone or intrusion/anxiety symptom predictors, without those adjustment covariates. | The cross-predictor contribution demonstrates multiple focal predictors, not demographic-control attribution. |
| Cavalcanti et al. (2026) | Demographics and personality enter the fixed mean as substantive APIM predictors and appear in the contribution table. | Demographics are included in fixed-prediction covariance attribution rather than residualized away as a separate control block. |
| Bolger-Laurenceau workshop / supplied self-efficacy fit | Basic model has the two efficacy predictors and two intake outcomes, no demographic controls. | A benchmark for the basic identity; not a worked covariate-adjustment example. |

The interpretation of Dwyer/Lee as targeting adjusted dependence is our
statistical reading of the documented specifications, not an independently
reproduced computation from complete fitted moments. It should not be described
as an exact conditional covariance at a particular covariate value without
additional assumptions.

To show why full attribution needs more terms, let P1 and P2 denote the
actor/partner linear predictions from one focal predictor pair, and let C be a
shared scalar covariate:

    Y1 = P1 + c1*C + e1
    Y2 = P2 + c2*C + e2

With residuals orthogonal to all predictors, covariance bilinearity gives:

    Cov(Y1,Y2) = Cov(P1,P2) + c1*c2*Var(C)
                + c2*Cov(P1,C) + c1*Cov(P2,C) + Cov(e1,e2)

The first term contains the familiar four APIM products; the next term is the
shared-covariate contribution; the next two are focal/covariate cross-terms.
The corresponding vector identity is already in the [technical notes](paper-idea.Rmd#covariates-and-cross-predictor-terms).
Adjusted slopes with raw predictor moments do not remove these cross-terms.
With multiple covariates there are also covariate-covariate terms.

For a linear-adjustment target instead, residualize both the focal predictors
and outcomes against the same controls and define the partition using the
adjusted moments and a matching denominator. This targets residualized outcome
covariance; linear residualization is not generally equivalent to conditioning.
Different samples, missing-data treatments, or separately fitted models require
additional compatibility checks before equating a between-model covariance
reduction with a within-model path sum.

Paper 1's current primary target remains the full model-implied covariance.
Report focal, covariate, focal/covariate cross-terms and residual separately;
state any regrouping convention. A supplementary adjusted partition, if
developed, must name its adjusted target and denominator explicitly. Handling
covariates itself is established prior work; clarification and validation of
these choices are the relevant contribution.

Ferraris reconstruction check: its four printed Appendix A products divided by
62.28 give approximately 24.60%, 2.36%, 1.19%, 1.10% (29.24% total), versus
24.20%, 2.31%, 1.17%, 1.08% (28.76%) reported. Their summed numerators plus
the final plotted residual covariance 42.81 give 61.0212, not 62.28. Rounded
output, undocumented moment sources, or other discrepancies cannot be resolved
from the published material alone; do not silently replace its reported result
with a purported correction.

## Normality and other reporting distinctions

The linear identity Cov(Y) = B Cov(X) B' + Cov(e) requires finite second moments
and Cov(X, e) = 0; normality is not needed for that algebra. Distributional
assumptions still matter for estimation and interval performance. A skewed,
bounded, ordinal, or count-like score analyzed with a linear APIM does not
demonstrate a logistic, ordinal-probit, Poisson, or negative-binomial extension.
Likewise, an APIM's member-within-dyad data layout is not an ILD level partition.

Keep distinct: total-model covariance versus residual-covariance reduction;
fixed-prediction covariance versus covariance including random effects;
variance partitions versus cross-member covariance partitions; and temporal
within-person effects versus paired observations within an encounter. These
differences explain why the papers cannot be treated as interchangeable precedents.

The full 2024 Kenny-Ackerman-Kashy chapter is now supplied and inspected.
Section 23.5 gives the partition, while Section 23.6.3 separately covers
within/between effects and random slopes; no levelwise predictor-route partition
is shown. Page 566 excludes nonnormal outcome errors. Dwyer's calculation
supplement remains missing: the supplied self-efficacy code is a different
analysis. Chapter-linked OSF files remain unchecked. The nine pending citing
papers remain unclassified for direct use.
