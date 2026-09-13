# APIM covariance decomposition: annotated literature review

Search and source checks: **31 August 2026**.

Forward-citation audit and additions: **13 September 2026**. See the
[dated audit](citation-audit-2026-09-13.md) and its
[citation inventory](citation-audit-2026-09-13.json) for coverage, screening
decisions, and unresolved candidates. Original annotations retain their earlier
verification limits unless explicitly updated below.

The main list contains **51 reference entries**: the original 42 plus
De Padova et al. (2021), Velten and Margraf (2017), Burns (2020), and Kline
(2016) from the forward-citation audit, and Gistelinck and Loeys (2019), Savord
et al. (2023), Loeys and Molenberghs (2013), and Loeys et al. (2014) from the
subsequent design/model scope check, plus the grouped Bolger-Laurenceau (2025)
workshop materials supplied by J-P. The [supplied-materials review](jp-materials-review-2026-09-13.md)
also upgrades the 2024 chapter to full-text-verified methodology. **Nine additional citing papers remain candidates awaiting full-text
verification** and are listed with the retrieval gaps below. Reference counts
include teaching material, background sources, and repeat reports; they are not
counts of independent applications.

This records the broad scoping review and the earlier writing-model search.
It is not an exhaustive, database-exported systematic review. Full texts,
author manuscripts, tables, supplements where available, and citation leads
were distinguished from abstract-only records. A missing local PDF does not
mean that the source was not inspected online.

The focal method attributes covariance between dyad members' outcomes to four
APIM predictor-side path products (actor-actor, two member-driven actor-partner
routes, and partner-partner), plus residual covariance. Related decompositions
are retained below, but are not counted as applications of this exact method.

## Main conclusions and reading order

- Six published applied papers directly use APIM path-tracing decomposition:
  **Dwyer (2017), Burns (2019), Figueroa et al. (2019), Lee et al. (2021),
  Ferraris et al. (2022), and Fu et al. (2025)**.
- The September audit additionally verified **De Padova et al. (2021)**:
  supplementary APIM_MM tables report a grouped partition, including negative
  and cross-predictor contributions. **Velten and Margraf (2017)** report total
  APIM and covariate attribution. Keep these distinct from four separate route
  rows. **Burns (2020)** is an additional abstract of the existing analysis.
- The **Bolger-Laurenceau webinar**, **Kenny handout**, and **APIM_MM manual**
  already show the decomposition, route interpretation, and correlation-unit
  reporting. Signed contributions and software are not unoccupied territory.
- **Cavalcanti et al. (2026)** is an especially close, explicitly descriptive
  preprint, including multiple predictors and negative contributions.
- The 2024 handbook chapter is now verified: **Section 23.5, pp. 577-580**, is
  direct methods treatment, including multiple predictors and covariates. Its
  ordinary APIM example uses two waves; the ILD section separately models
  within/between effects but does not supply a route partition at each level.
- The strongest immediate reading sequence is: **2024 chapter Section 23.5**;
  2025 workshop Day 2 slides 10-15 and its matched R/Mplus files;
  Dwyer; Ferraris Appendix A; APIM_MM tables; De Padova's supplement;
  Cavalcanti's decomposition. The 2016 webinar remains earlier teaching evidence.
- No intervals for the **four product-derived contributions or their normalized
  shares** were located in the inspected contribution tables/materials. The raw
  residual covariance does receive ordinary model-based inference in J-P's
  supplied fit. This bounded finding does not prove absence of contribution
  inference elsewhere; slope, mediation, or dyadic-pattern intervals are different targets.

## 1. Direct methodological, teaching, and software sources

### Bolger and Laurenceau (2016): the closest teaching example

Bolger, N., & Laurenceau, J.-P. (2016, February 5). *Family Life, Activity, Sun,
Health and Eating (FLASHE) Study webinar: An introduction to dyadic data
analysis*. National Cancer Institute.
[Slides](https://cancercontrol.cancer.gov/sites/default/files/2020-06/flashe-webinar-2.5.2016.pdf)
| [Official listing](https://cancercontrol.cancer.gov/brp/hbrb/flashe-study/flashe-webinars).

- **Coverage:** Slides 32-35 trace the four standardized contributions. Slide 36
  adds residual dependence and reports correlation-unit amounts and percentages:
  .053, .034, .027, .003, and .371 sum to .488. No component intervals are shown.
- **Use:** The clearest precedent for a diagram-first explanation and five-part
  reporting. Its example uses self-efficacy, not the autonomous-motivation
  predictor in Dwyer. Use 2016, despite a later paper citing the webinar as 2017.

### Bolger and Laurenceau (2025): matched workshop and analysis materials

Bolger, N., & Laurenceau, J.-P. (2025, July 7-11). *Introduction to dyadic data
analysis* [Day 1 and Day 2 workshop handouts]. UMass Amherst.
[Day 1](../references/explaining-interdependence-apim/jp-materials-2026-09-13/J-P&Niall-FLASHE-example/UMass-Dyadic-Data-Analysis-Workshop-July2025-Day1-handout.pdf)
| [Day 2](../references/explaining-interdependence-apim/jp-materials-2026-09-13/J-P&Niall-FLASHE-example/UMass-Dyadic-Data-Analysis-Workshop-July2025-Day2-handout.pdf)
| [Bundle assessment](jp-materials-review-2026-09-13.md).

- **Coverage:** Day 2 slides 10-15 (PDF pp. 5-8) explicitly trace the four
  predictor products plus residual covariance. The denominator is total outcome
  covariance 1.366; shares are 5.3%, .6%, 10.7%, 6.8%, and 76.6%. Day 1 supplies
  model specification, R/Mplus, and ordinary parameter/contrast inference.
- **Use/caution:** Self-efficacy and fruit/vegetable intake, N = 1,486, as in
  the earlier webinar. The approximate 23.4% versus 24% summaries are consistent
  with different teaching rounding; this is not Dwyer's motivation model (22.6%). Supplied
  R/Mplus files fit the APIM but do not define the four derived contributions or
  their intervals. The raw residual covariance has ordinary model-based SE/CI.
  No ILD or nonlinear-link route partition is demonstrated. One grouped teaching
  resource, not an additional independent study.

### Kenny (n.d.): Explained nonindependence

Kenny, D. A. (n.d.). *Explained nonindependence* [Handout].
[Author's DOCX](https://davidakenny.net/kkc/c7/Explained_Nonindependence.docx)
| [Chapter 7 companion page](https://davidakenny.net/kkc/c7/c7.htm).

- **Coverage:** Four route diagrams, distinguishable and exchangeable cases,
  residual scaling, an example, negative contributions, and covariate terms.
  Explicitly says the computations are implemented in APIM_MM.
- **Use/caution:** Direct algebraic and visual prior art. Check the printed
  distinguishable formula against our outcome-member indexing before copying it.
  DOCX/page dates in March 2017 do not establish its original publication date;
  do not attribute this later handout automatically to the 2006 book.

### Kenny (2019): APIM_MM documentation

Kenny, D. A. (2019, March 3). *APIM_MM: A web-based package for estimating the
Actor-Partner Interdependence Model by multilevel modeling*.
[Author's manual](https://davidakenny.net/doc/APIM_MM.pdf).

- **Coverage:** Pages 3-4 describe the partition of nonindependence and additional
  sources with covariates/multiple predictors. Table 3 (pp. 10-11) reports
  correlation-unit amounts; Table 5 (p. 25, discussed on p. 23) includes negative
  contributions. Tables show amounts/percentages, not contribution intervals.
- **Use/caution:** Direct APIM software precedent. Monte Carlo intervals in the
  manual concern the `k` ratio, not this partition. Current app behavior and
  implementation code were not audited; the manual's priority claims should
  not be adopted without independent evidence.

### Kenny (n.d.): general path-tracing rules

Kenny, D. A. (n.d.). *Path tracing* [Web tutorial].
[Author's website](https://davidakenny.net/cm/tracing.htm).

- **Coverage/use:** General SEM rules for obtaining covariance from paths;
  explicitly cited by Figueroa et al. as part of their decomposition procedure.
  Pair it with the APIM-specific handout, not as evidence that every generic
  tracing tutorial presents the five APIM contributions.

### Kenny, Ackerman, and Kashy (2024): published decomposition methods

Kenny, D. A., Ackerman, R. A., & Kashy, D. A. (2024). The design and analysis of
data from dyads and groups. In H. T. Reis, T. West, & C. M. Judd (Eds.),
*Handbook of research methods in social and personality psychology*
(3rd ed., Chapter 23, pp. 565-601). Cambridge University Press.
[DOI](https://doi.org/10.1017/9781009170123.024)
| [Supplied published chapter](../references/explaining-interdependence-apim/jp-materials-2026-09-13/Kenny-et-al-2024-Ch23-The-design-and-analysis-of-data-from-dyads-and-groups.pdf).

- **Full-text verification, September 2026:** Section 23.5, pp. 577-580,
  explicitly develops basic distinguishable/indistinguishable partitions and
  signed contributions. Section 23.5.2/Table 23.3 expands to two mixed predictors
  and two shared covariates, including their cross-correlation terms. Table 23.4
  gives numerical attribution. This is a central direct methods citation.
- **Lineage/design:** Credits Kenny (2015, APIM_MM software) and Dwyer (2017).
  The basic example predicts attachment from commitment measured 18 months
  earlier; it is a two-wave ordinary APIM, not ILD route attribution at both
  levels. Do not count the original data source as an earlier decomposition use.
- **Limits:** No product-contribution SEs/intervals/inference recipe in Section
  23.5. Section 23.6.3, pp. 585-588, separately specifies within/between APIM
  effects and random slopes, without a route partition at each level. Page 566
  explicitly excludes nonnormal outcome errors, including binary/ordinal/count.
- **Versions:** The supplied highlighted DOCX is an undated draft containing
  2022 references, not a verified 2019 publication. Use published Table 23.3;
  it corrects several draft indexes. See the [bundle assessment](jp-materials-review-2026-09-13.md)
  for checked sign/row-placement issues in the published examples.

### Wickham and Knee (2012): theoretical rationale and total explained covariance

Wickham, R. E., & Knee, C. R. (2012). Interdependence theory and the actor-partner
interdependence model: Where theory and method converge.
*Personality and Social Psychology Review, 16*(4), 375-393.
[DOI](https://doi.org/10.1177/1088868312447897)
| [Author manuscript](https://www.researchgate.net/publication/225042099_Interdependence_Theory_and_the_Actor-Partner_Interdependence_Model_Where_Theory_and_Method_Converge).

- **Coverage:** Manuscript pp. 23-24 discuss path tracing/covariance algebra for
  actor, partner, and interaction contributions. The worked example's
  `(Co)Variance Explained` section (manuscript pp. 37-38) compares unexplained
  covariance across models. No four/five-route contribution table was verified.
- **Use/caution:** Earlier explicit methodological acknowledgement. Keep total
  covariance reduction distinct from within-model route attribution; intervals
  for dyadic-pattern ratios are not component intervals.

## 2. Published applied uses of the APIM decomposition

### Dwyer et al. (2017): the paper J-P mentioned

Dwyer, L. A., Bolger, N., Laurenceau, J.-P., Patrick, H., Oh, A. Y., Nebeling,
L. C., & Hennessy, E. (2017). Autonomous motivation and fruit/vegetable intake in
parent-adolescent dyads. *American Journal of Preventive Medicine, 52*(6),
863-871. [DOI](https://doi.org/10.1016/j.amepre.2017.01.011)
| [Full text](https://pmc.ncbi.nlm.nih.gov/articles/PMC5512865/).

- **Application:** 1,443 dyads. Statistical Analysis explicitly path traces
  unstandardized final and control-only APIM estimates. Results report
  actor-driven 6.4%, partner-driven 0.7%, adolescent-driven 10.4%, and
  parent-driven 5.1%, totaling 22.6% of interdependence.
- **Citation check, September 2026:** The path-tracing methods sentence cites
  reference 39, **Kline (2016)**, as its general SEM source. This does not
  establish an APIM-specific partition in Kline's textbook.
- **Covariates:** Both motivation predictors and both intake outcomes are
  regressed on parent sex, adolescent sex/age, and parent education. This and
  the controls-only comparison support an adjusted-dependence interpretation;
  exact residual moments/denominator remain unverified without the supplement.
- **Use/caution:** Essential direct precedent and substantive writing example.
  The calculation supplement (`NIHMS868627-supplement.pdf`) was inaccessible;
  its precise denominator, equations, and possible inference are unverified.
  J-P's supplied PDF is the main nine-page article only; the accompanying
  self-efficacy example is not this missing motivation-model supplement.

### Burns (2019): contribution table in correlation units

Burns, R. D. (2019). Enjoyment, self-efficacy, and physical activity within
parent-adolescent dyads: Application of the actor-partner interdependence model.
*Preventive Medicine, 126*, 105756.
[DOI](https://doi.org/10.1016/j.ypmed.2019.105756)
| [Full text](https://pmc.ncbi.nlm.nih.gov/articles/PMC6697559/).

- **Application:** Statistical Analysis specifies four standardized path-product
  contributions per predictor. Table 1 reports amounts and percentages for
  enjoyment/self-efficacy, APIM total (.0397; 27%), residual (.1073; 73%), and
  total correlation (.147). Supplementary Table 2 reports results within sex groups.
- **Use/caution:** Strong published reporting precedent. Path coefficients have
  intervals, contribution rows do not. With two predictors, cross-predictor
  covariance terms must be checked before treating the reported row sum as an
  exact multivariate model-implied decomposition.

### Figueroa et al. (2019): another parent-adolescent application

Figueroa, R., Kalyoncu, Z. B., Saltzman, J. A., & Davison, K. K. (2019).
Autonomous motivation, sugar-sweetened beverage consumption and healthy beverage
intake in US families: Differences between mother-adolescent and
father-adolescent dyads. *Public Health Nutrition, 22*(6), 1010-1018.
[DOI](https://doi.org/10.1017/S136898001800383X)
| [Full text](https://pmc.ncbi.nlm.nih.gov/articles/PMC7676308/).

- **Application:** 1,649 dyads. Methods (pp. 1012-1013) explicitly cite the
  Bolger-Laurenceau webinar and Kenny's tracing rules. Healthy-beverage results
  report 12.78% and 17.46% covariance explained in mother- and father-adolescent
  dyads; the discussion identifies adolescent-driven contributions as largest.
- **Use/caution:** Confirms substantive uptake. No complete calculation table or
  component intervals located; the exact denominator should not be inferred
  from the percentages alone.

### Lee et al. (2021): mental health and relationship closeness

Lee, H., Henry, K. L., Buller, D. B., Pagoto, S., Baker, K., Walkosz, B.,
Hillhouse, J., Berteletti, J., & Bibeau, J. (2021). Mutual influences of mother's
and daughter's mental health on the closeness of their relationship: An
actor-partner interdependence model. *Journal of Child and Family Studies, 30*,
676-686. [DOI](https://doi.org/10.1007/s10826-021-01906-6)
| [Full text](https://pmc.ncbi.nlm.nih.gov/articles/PMC13166139/).

- **Application:** Follows Dwyer's unstandardized path-tracing procedure.
  `Direct Effect Analysis` reports actor-driven 1.5%, partner-driven below 1%,
  daughter-driven 6.6%, and mother-driven 1% of closeness interdependence.
- **Use/caution:** A psychologically focused example outside health behaviors.
  Models use 5,000 bootstrap resamples for confidence intervals, but the route
  percentages are presented without intervals. This is not verified evidence
  of contribution-specific bootstrap inference or a simulation study.
- **Covariates:** Both predictors and both outcomes are regressed on maternal
  age, daughter age, and maternal non-Hispanic-White indicator. Uses the fitted
  APIM and a model without actor/partner paths; this supports an adjusted
  dependence target, although full numerical reconstruction is unavailable.

### Ferraris et al. (2022): explicit formulas in an appendix

Ferraris, G., Fisher, O., Lamura, G., Fabbietti, P., Gagliardi, C., & Hagedoorn,
M. (2022). Dyadic associations between perceived social support and psychological
well-being in caregivers and older care recipients.
*Journal of Family Psychology, 36*(8), 1397-1406.
[DOI](https://doi.org/10.1037/fam0001009)
| [Institutional PDF](https://pure.rug.nl/ws/files/589396899/ContentServer_1_.pdf).

- **Application:** 215 dyads. Methods p. 1400 cites Dwyer; results p. 1401 and
  Appendix A p. 1406 give four contributions (24.20%, 2.31%, 1.17%, 1.08%),
  totaling 28.76%. Appendix A prints formulas and numerical substitutions.
- **Use/caution:** Best immediate example of moving calculations out of the main
  applied narrative. The denominator 62.28 is labelled residual well-being
  covariance, not raw unconditional covariance. Check rounded substitutions
  independently; no component intervals are reported.
- **Covariate check:** Outcomes have role-specific adjustment sets, but controls
  predicting social support and a controls-only model are not explicitly
  documented. The origin of the appendix's residual moments is unclear. Its
  printed calculations yield about 29.24%, versus 28.76% reported; a precise
  correction cannot be established from rounded and incompletely documented
  inputs. Treat as direct prior use, not a verified numerical replication target.

### Fu et al. (2025): four routes plus residual in a later application

Fu, Y., Almes, H., Constantino, N., Schmidt, D., & Burns, R. D. (2025).
Associations of parental perceived health with child movement behaviors within
two-parent households. *International Journal of Physical Activity and Health,
4*(1), Article 3. [DOI](https://doi.org/10.18122/ijpah.4.1.3.boisestate)
| [Publisher record](https://scholarworks.boisestate.edu/ijpah/vol4/iss1/3/)
| [Author-uploaded full text](https://www.researchgate.net/publication/389330862_Associations_of_Parental_Perceived_Health_with_Child_Movement_Behaviors_within_Two-Parent_Households).

- **Application:** Methods p. 5 defines four contributions; Table 3 p. 9 reports
  those plus residual in correlation units and percentages. The decomposition
  concerns parental health outcomes, not dyadic child outcomes.
- **Use/caution:** Further evidence that five-part reporting is already applied.
  No component intervals appear in the table. Sobel inference is for mediation,
  not this partition; apparent outcome-label inconsistencies warrant checking.

### De Padova et al. (2021): grouped partition with signed and cross-predictor contributions

De Padova, S., et al. (2021). Post-traumatic stress symptoms in long-term
disease-free cancer survivors and their family caregivers.
*Cancer Medicine, 10*(12), 3974-3985.
[DOI](https://doi.org/10.1002/cam4.3961)
| [Supplementary package](https://www.ebi.ac.uk/europepmc/webservices/rest/PMC8209622/supplementaryFiles)
| [Local APIM output](../references/explaining-interdependence-apim/2021-de-padova-et-al-apim-supplement.docx).

- **Verified 13 September 2026:** The supplement *Output of APIM models*
  contains four model sections, each with **Table 5: Partition of
  Nonindependence**. It groups actor/partner-effect and predictor-correlation
  contributions and reports unexplained correlation, in correlation units and
  percentages. Negative contributions occur in sections 1 and 3; section 4
  additionally reports **Correlation between the Mixed Variables** of -.006
  (-2.12%).
- **Use/caution:** A published applied precedent for grouped signed and
  cross-predictor attribution, rather than four separately printed elementary
  routes. No contribution intervals are shown. In model 3, the main text and
  supplement differ in labelling the overall correlation; see the dated audit
  before reproducing numbers. Reporting was verified, not every calculation.

### Burns (2020): conference abstract of the already-listed application

Burns, R. D. (2020). Enjoyment, Self-Efficacy, and Physical Activity Within
Parent-Adolescent Dyads. In *Peer-Reviewed Abstracts*, *Research Quarterly for
Exercise and Sport, 91*(sup1).
[Publisher collection](https://www.tandfonline.com/doi/full/10.1080/02701367.2020.1761754).

- **Verified 13 September 2026:** Indexed publisher text identifies the author,
  1,854 FLASHE dyads, and member-/actor-driven covariance contributions matching
  Burns (2019). Count as an additional report of the same analysis, not an
  independent application. The individual abstract page remains unverified.

## 3. Especially close recent preprint

### Cavalcanti et al. (2026): signed, multi-predictor decomposition

Cavalcanti, J. C., Lachmann, T., Cooney, G., Madureira, S., & Skantze, G. (2026,
June 5). *Individual and shared components of conversational enjoyment: The role
of demographics and personality* [Preprint, version 1].
[DOI](https://doi.org/10.21203/rs.3.rs-9910824/v1)
| [Author-uploaded manuscript](https://www.researchgate.net/publication/406075027_Individual_and_Shared_Components_of_Conversational_Enjoyment_The_Role_of_Demographics_and_Personality).

- **Application:** 1,602 conversations and 1,456 speakers, with crossed person
  and conversation random intercepts. Methods pp. 11-12 split fixed-prediction
  covariance into additive and assortment components. Table 2/Figure 3 p. 6
  show signed predictor contributions, including negative values.
- **Important detail:** Exact multi-predictor fixed-effect covariance accounts
  for 24.0% of observed partner covariance. Same-predictor rows sum to 15.7%; the
  authors explicitly attribute the difference to omitted cross-predictor terms.
- **Use/caution:** Very close novelty check, but a preprint, not a verified
  peer-reviewed publication. The estimand is sample covariance of fixed-only
  predictions, not automatically full marginal covariance including random
  effects. Explicitly descriptive; no contribution intervals located.

## 4. Earlier or broader dyadic decomposition precedents

### Velten and Margraf (2017): total APIM and covariate attribution

Velten, J., & Margraf, J. (2017). Satisfaction guaranteed? How individual,
partner, and relationship factors impact sexual satisfaction within partnerships.
*PLOS ONE, 12*(2), e0172855.
[Primary full text](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0172855).

- **Verified 13 September 2026:** Methods identify APIM_MM. The Results,
  *Actor-partner-interdependence model* section, reports 53.7% of total
  nonindependence explained by the APIM and 27.8% by between-dyad covariates.
- **Use/caution:** Applied total/grouped attribution. Supplement S2 Table was
  checked and contains slope estimates, not four route contributions. Do not
  infer the precise decomposition denominator from the percentages alone.

### Griffin and Gonzalez (1995): exchangeable dyadic correlations

Griffin, D., & Gonzalez, R. (1995). The correlational analysis of dyad-level data:
Models for the exchangeable case. *Psychological Bulletin, 118*(3), 430-439.
[DOI](https://doi.org/10.1037/0033-2909.118.3.430)
| [Author's PDF](https://websites.umich.edu/~gonzo/papers/exch.pdf).

- **Coverage/use:** Page 433 explicitly path traces correlations into individual
  and latent dyad-level components; Figure 2 p. 434 illustrates the model.
  Important older lineage, but not the same four APIM predictor routes.
  Table 2's bias/Type I error simulations concern correlation estimators, not
  validation of the focal APIM covariance products.

### Gonzalez and Siarkiewicz (2006): applied individual/dyad decomposition

Gonzalez, R., & Siarkiewicz, M. (2006). Jak zbadać związek między stopniem zaufania
a poziomem satysfakcji z małżeństwa? [How can we analyze a relationship between
trust and satisfaction in married couples?]. *Nowiny Psychologiczne, 1*, 15-25.
[Author's PDF](https://websites.umich.edu/~gonzo/papers/Gonzalez-polish.pdf).

- **Application/use:** 74 married couples. Page 21 gives weighted
  individual/dyad-correlation formulas; pp. 22-23 apply them to trust,
  satisfaction, and control preferences. An applied decomposition in another
  dyadic model, not an APIM five-route table. Polish text with English abstract.

### Jang (2016): total explained nonindependence in negotiation

Jang, D. (2016). *Negotiation in all its phases: Theory and data on behavior
before, during, and after bargaining* [Doctoral dissertation, Washington
University in St. Louis]. [DOI](https://doi.org/10.7936/K7B27SKT)
| [Institutional record](https://openscholarship.wustl.edu/art_sci_etds/817/).

- **Application/use:** Study 5, pp. 95-96, reports 5.44% and 23.68% of total
  nonindependence explained alongside APIM estimates and `k` intervals.
  Retain as gray-literature evidence for total explanation, not a confirmed
  four-route application; the exact denominator and component inference are
  not established.

## 5. Writing examples, path algebra, and neighboring methods

These are useful for building the paper, but should not be conflated with
direct applications of the focal decomposition.

### Kline (2016): general path-tracing source directly cited by Dwyer

Kline, R. B. (2016). *Principles and practice of structural equation modeling*
(4th ed.). Guilford Press.

- **Verified 13 September 2026:** Dwyer's path-tracing methods sentence cites
  this book as reference 39. Retain as the directly cited general SEM
  foundation; APIM-specific partition content in the book was not verified.

### Boker, McArdle, and Neale (2002)

*An algorithm for the hierarchical organization of path diagrams and calculation
of components of expected covariance*. *Structural Equation Modeling, 9*(2),
174-194. [DOI](https://doi.org/10.1207/S15328007SEM0902_2).

- **Borrow:** Diagram-led explanation, path enumeration, and the transition from
  an intuitive graph to an algorithm. It establishes general expected-covariance
  component algebra, not a new APIM-specific procedure. More technical than
  the intended applied-facing exposition.

### Ledermann, Macho, and Kenny (2011)

*Assessing mediation in dyadic data using the actor-partner interdependence
model*. *Structural Equation Modeling, 18*(4), 595-612.
[DOI](https://doi.org/10.1080/10705511.2011.607099).

- **Borrow:** Introduce a substantive dyadic question, define compound path
  products, simplify model variants, then demonstrate estimation and reporting.
  Bootstrap inference is relevant as an analogy for derived effects; mediation
  products are not the covariance components considered here.

### Laurenceau and Bolger (2005)

*Using diary methods to study marital and family processes*.
*Journal of Family Psychology, 19*(1), 86-97.
[DOI](https://doi.org/10.1037/0893-3200.19.1.86).

- **Borrow:** Question-first, accessible prose, compact mathematics tied to
  substantive examples, and clear treatment of within-person/dyadic structure.
  A strong voice/structure model, not a direct four-route paper or a Monte Carlo
  bias-study template.

### Bolger and Shrout (2007)

*Accounting for statistical dependency in longitudinal data on dyads*. In
T. D. Little, J. A. Bovaird, & N. A. Card (Eds.), *Modeling contextual effects in
longitudinal studies* (pp. 285-298). Lawrence Erlbaum Associates.
[Author manuscript](https://www.columbia.edu/~nb2229/docs/Bolger%20and%20Shrout-Accounting%20for%20Statistical%20Dependency%20May%202005.pdf).

- **Borrow:** Start from dependence as substantive information, explain the
  covariance structure, and connect it to shared events/interpersonal influence.
  Useful ILD framing and exposition; not confirmed as the focal APIM partition
  or a Monte Carlo bias-study template. The manuscript filename says 2005;
  the published chapter is 2007.
- **Scope check, September 2026:** Author manuscript p. 4 explicitly excludes
  estimating actor/partner effects. Page 13 partitions modeled same-day
  correlation into daily (75%) and person-level (25%) components. This is a real
  ILD level partition, but not four APIM predictor routes at each level.

### Gistelinck, Loeys, Decuyper, and Dewitte (2018)

*Indistinguishability tests in the actor-partner interdependence model*.
*British Journal of Mathematical and Statistical Psychology, 71*(3), 472-498.
[DOI](https://doi.org/10.1111/bmsp.12129).

- **Borrow:** A methods-paper structure linking statistical conditions,
  simulation comparisons, and practical recommendations. Use if making
  finite-sample inference claims; it studies distinguishability tests, not
  the proposed covariance-component estimators.

### Jones and West (2005)

*Covariance decomposition in undirected Gaussian graphical models*.
*Biometrika, 92*(4), 779-786.
[DOI](https://doi.org/10.1093/biomet/92.4.779).

- **Coverage/use:** Signed path-weight covariance decomposition in a different,
  undirected model class. Important generic prior art for additive/signed
  interpretation and rescaling; not a direct dyadic application or necessarily
  the best stylistic template for an applied-facing paper.

### Zhang, Hamagami, Grimm, and McArdle (2015)

*Using R package RAMpath for tracing SEM path diagrams and conducting complex
longitudinal data analysis*. *Structural Equation Modeling, 22*(1), 132-147.
[DOI](https://doi.org/10.1080/10705511.2014.935257).

- **Coverage/use:** Generic SEM path tracing and software-assisted covariance
  calculation. A software/tutorial precedent; do not claim the first automatic
  path-tracing or general covariance-decomposition implementation.

### Kenny and Ledermann (2010)

*Detecting, measuring, and testing dyadic patterns in the actor-partner
interdependence model*. *Journal of Family Psychology, 24*(3), 359-366.
[DOI](https://doi.org/10.1037/a0019651).

- **Coverage/use:** Converts actor/partner coefficients into interpretable
  dyadic-pattern quantities, notably `k`. Useful framing for derived APIM
  estimands; ratio inference is not evidence for covariance-route inference.

### Stas, Kenny, Mayer, and Loeys (2018)

*Giving dyadic data analysis away: A user-friendly app for actor-partner
interdependence models*. *Personal Relationships, 25*, 103-119.
[DOI](https://doi.org/10.1111/pere.12230)
| [Author's PDF](https://davidakenny.net/doc/APIM_SEM.pdf).

- **Coverage/use:** APIM_SEM software, standardized paths, diagrams, and dyadic
  patterns. The main article was screened; no explicit route-partition table
  was located. Appendices/current app were not audited. Keep distinct from
  the directly verified APIM_MM partition in Kenny's manual.

## 6. Foundations, extension context, and screened leads

- **Gistelinck and Loeys (2019).** *The actor-partner interdependence model
  for longitudinal dyadic data: An implementation in the SEM framework*.
  *Structural Equation Modeling, 26*(3), 329-347.
  [DOI](https://doi.org/10.1080/10705511.2018.1527223)
  | [Author dissertation, Chapter 3](https://backoffice.biblio.ugent.be/download/8635510/8635511).
  Added 13 September 2026. Substantial longitudinal APIM methodology, with
  time-averaged/time-specific actor and partner effects, random-intercept
  covariance, daily residual covariance, and serial dependence. The application
  uses three-week diaries from 66 couples. Inspected equations and covariance
  structure in dissertation pp. 87-89; no focal predictor-route covariance
  partition at both levels established. Strong ILD foundation, not a direct
  decomposition application. Published online in 2018, journal issue in 2019.
- **Savord, McNeish, Iida, Quiroz, and Ha (2023).** *Fitting the longitudinal
  actor-partner interdependence model as a dynamic structural equation model in
  Mplus*. *Structural Equation Modeling, 30*(2), 296-314.
  [DOI](https://doi.org/10.1080/10705511.2022.2065279)
  | [Author-uploaded manuscript](https://www.researchgate.net/publication/360704986_Fitting_the_Longitudinal_Actor-Partner_Interdependence_Model_as_a_Dynamic_Structural_Equation_Model_in_M_plus).
  Added 13 September 2026. Substantial ILD/DSEM methodology. Equations 5-8 and
  Figures 7-9 cover random slopes, heterogeneous residual variances, and multiple
  outcomes. No focal within/between predictor-route covariance partition located.
  Between-dyad covariance of log-residual variances concerns correlated
  volatility, not itself covariance between outcomes. Published online in 2022,
  journal issue in 2023. Important random-slope extension context.
- **Loeys and Molenberghs (2013).** *Modeling actor and partner effects in
  dyadic data when outcomes are categorical*. *Psychological Methods, 18*(2),
  220-236. [DOI](https://doi.org/10.1037/a0030640)
  | [Author manuscript](https://documentserver.uhasselt.be/bitstream/1942/14740/1/met_loeys_0112.pdf).
  Added 13 September 2026. Substantial binary/count APIM methods, simulations,
  and applications comparing GLMM/GEE approaches. Derives/discusses marginal
  moments and within-dyad association, including logistic ICC approximation.
  Full manuscript inspected; no actor/partner predictor-route covariance
  attribution located. Essential non-Gaussian APIM context, distinct from
  Leckie's general multilevel variance-partition contribution.
- **Loeys, Cook, De Smet, Wietzker, and Buysse (2014).** *The actor-partner
  interdependence model for categorical dyadic data: A user-friendly guide to
  GEE*. *Personal Relationships, 21*(2), 225-241.
  [DOI](https://doi.org/10.1111/pere.12028).
  Added 13 September 2026. Practical methodological guide to binary/count APIM
  with SPSS/SAS examples. Publisher abstract verified; exact covariance-route
  decomposition not verified. The 2013 paper above is the stronger technical
  citation for the generalized-model extension.
- **Johnson (2014).** *Extension of Nakagawa and Schielzeth's R-squared GLMM
  to random slopes models*. *Methods in Ecology and Evolution, 5*(9), 944-946.
  [DOI](https://doi.org/10.1111/2041-210X.12225)
  | [Institutional record](https://eprints.gla.ac.uk/94906/).
  Extends a mixed-model variance summary to random-slope structures. Useful
  extension context for defining how random-effect variation enters a summary;
  not an APIM covariance-route decomposition or evidence for component inference.
  Full author manuscript checked September 2026: Eq. 11 averages random-effect
  variances using the trace of the implied random-effect covariance matrix.
- **Leckie, Browne, Goldstein, Merlo, and Austin (2020).** *Partitioning
  variation in multilevel models for count data*. *Psychological Methods,
  25*(6), 787-801. [DOI](https://doi.org/10.1037/met0000265)
  | [Institutional record](https://portal.research.lu.se/en/publications/partitioning-variation-in-multilevel-models-for-count-data/).
  Derives exact variance-partition/intraclass-correlation expressions for
  negative-binomial models and three-level/random-coefficient extensions,
  illustrated with student absenteeism. Supports treating count-outcome
  dependence as a model- and scale-specific problem, not automatic reuse of
  linear APIM slope products. Full paper and supplement checked September 2026:
  [Supplement S4.3](https://www.bristol.ac.uk/cmm/media/leckie/articles/leckie2020.pdf),
  p. 31/PDF page 46, derives cross-unit covariance by total covariance, conditional
  on covariates and averaging over random effects. Not a direct APIM route-inference precedent.
- **Kenny (1996).** *Models of non-independence in dyadic research*.
  *Journal of Social and Personal Relationships, 13*, 279-294.
  [DOI](https://doi.org/10.1177/0265407596132007).
  Foundation for alternative dyadic dependence models. Abstract verified;
  specific decomposition content not verified in full text.
- **Kenny and Cook (1999).** *Partner effects in relationship research:
  Conceptual issues, analytic difficulties, and illustrations*.
  *Personal Relationships, 6*, 433-448.
  [DOI](https://doi.org/10.1111/j.1475-6811.1999.tb00202.x).
  Local full text screened: APIM patterns and residual nonindependence,
  including negative residual dependence; no explicit four-route expansion
  or contribution table located. Adjacent, not a confirmed direct precedent.
- **Cook and Kenny (2005).** *The actor-partner interdependence model: A model
  of bidirectional effects in developmental studies*.
  *International Journal of Behavioral Development, 29*, 101-109.
  [DOI](https://doi.org/10.1080/01650250444000405).
  Author-posted full text screened: actor/partner paths and remaining
  nonindependence, but no explicit four-product decomposition located.
- **Campbell and Kashy (2002).** *Estimating actor, partner, and interaction
  effects for dyadic data using PROC MIXED and HLM: A user-friendly guide*.
  *Personal Relationships, 9*, 327-342.
  [DOI](https://doi.org/10.1111/1475-6811.00023).
  Foundational applied estimation guide; specific partition content remains
  unverified because the full relevant text was not obtained.
- **Kenny, Kashy, and Cook (2006).** *Dyadic data analysis*. Guilford Press.
  [Publisher](https://www.guilford.com/books/Dyadic-Data-Analysis/Kenny-Kashy-Cook/9781572309869).
  Chapter 7, pp. 144-184, is the APIM foundation. The companion handout was
  verified, but a corresponding printed decomposition passage was not.
- **Ledermann and Kenny (2017).** *Analyzing dyadic data with multilevel
  modeling versus structural equation modeling: A tale of two methods*.
  *Journal of Family Psychology, 31*(4), 442-452.
  [DOI](https://doi.org/10.1037/fam0000290).
  Local full text screened: useful for SEM/MLM estimation, standardization,
  missing data, and parameter availability. No explicit route partition found;
  citing APIM_MM alone does not establish use of its decomposition.
- **Kenny and Kashy (2014).** *The design and analysis of data from dyads and
  groups*. In *Handbook of research methods in social and personality psychology*
  (2nd ed., pp. 589-607). [DOI](https://doi.org/10.1017/CBO9780511996481.027).
  Older two-author chapter, not the Ackerman chapter. Metadata verified;
  relevant full-text subsection unverified.
- **Kashy and Kenny (2000).** *The analysis of data from dyads and groups*.
  In *Handbook of research methods in social and personality psychology*
  (1st ed., pp. 451-477). Earlier chapter cited by APIM_MM; specific
  decomposition content remains unverified.
- **Kenny, Kashy, and Bolger (1998).** *Data analysis in social psychology*.
  In *The handbook of social psychology* (4th ed., Vol. 1, pp. 233-265).
  [Author's PDF](https://www.columbia.edu/~nb2229/docs/KennyKashyBolger1998-Data_analysis.pdf).
  A different handbook and author team. Related dependence-analysis background;
  no focal four-route passage verified in this review.
- **Gonzalez and Griffin (1999).** *The correlational analysis of dyad-level
  data in the distinguishable case*. *Personal Relationships, 6*, 449-469.
  [DOI](https://doi.org/10.1111/j.1475-6811.1999.tb00203.x).
  Related correlational-model lineage; the relevant full text was not verified
  for the focal APIM partition.
- **Gonzalez and Griffin (2004).** *Measuring individuals in a social
  environment: Conceptualizing dyadic and group interaction*.
  [Author's chapter PDF](https://websites.umich.edu/~gonzo/papers/gonzalez-griffin-methodshb.pdf).
  Graphical/conceptual background on individual and group levels; screened as
  adjacent rather than a confirmed four-route APIM application.
- **Gonzalez and Griffin (2023).** *Dyadic data analysis*. In *APA handbook of
  research methods in psychology* (2nd ed., Vol. 3, Chapter 21).
  [DOI](https://doi.org/10.1037/0000320-021)
  | [Author's proof](https://websites.umich.edu/~gonzo/papers/gonzalez-griffin-2023-dyad.pdf).
  General dyadic-analysis chapter screened; no focal route-partition passage
  confirmed. Absence of a search-text match is not proof of absence.
- **Bolger and Laurenceau (2013).** *Intensive longitudinal methods: An
  introduction to diary and experience sampling research*. Guilford Press.
  [Publisher](https://www.guilford.com/books/Intensive-Longitudinal-Methods/Bolger-Laurenceau/9781462506781).
  Background for ILD estimands and accessible exposition; not verified here
  as presenting the focal decomposition. Figueroa's procedural citation is
  the webinar, not this book.
- **Laws et al. (2026).** *The random dyadic interdependence model: Modeling
  variability in physiological covariation within dyads*.
  *Biological Psychology, 206*, 109259.
  [DOI](https://doi.org/10.1016/j.biopsycho.2026.109259).
  Related Bolger-coauthored extension context for dyad-varying covariation.
  September screening additionally inspected the publisher introduction, which
  distinguishes concurrent covariance from directional APIM effects. Full
  methods remain inaccessible; not verified as an APIM path partition or as
  validation of inference for our components.
- **Jang, Bottom, and Elfenbein (2025).** *From preparation to performance:
  Conscientiousness predicts negotiation planning and value claiming*.
  *Journal of Behavioral Decision Making, 38*(2), e70015.
  [DOI](https://doi.org/10.1002/bdm.70015).
  Related published negotiation study; no decomposition passage located.
  Do not count it merely because it uses an APIM application.

## 7. Implications for this manuscript

The [methods, design, and citation map](method-scope-and-citation-map.md), checked
13 September 2026, distinguishes substantial methods contributions from applied
precedents and recommends citations for Paper 1. It also records the verified
analysis designs and response models. The eight closest published application
analyses are cross-sectional; Cavalcanti uses repeated encounters with crossed
random effects. Bolger and Shrout already partition ILD dependence across
temporal levels, and Leckie et al. derive non-Gaussian multilevel covariance and
ICC expressions. Neither establishes the focal APIM predictor-route partition
at both temporal levels or under nonlinear response links.

Its [covariate comparison](method-scope-and-citation-map.md#covariates-full-attribution-versus-adjusted-dependence)
distinguishes full partitions that include covariate/cross-term contributions
from adjustment-oriented analyses such as Dwyer and Lee. Calling a predictor a
covariate does not by itself specify which covariance is being partitioned.

The [manuscript plan](plan.md) consolidates the proposed contribution,
estimand and denominator choices, inference-validation work, and staged
extensions. The evidence above constrains novelty: decomposition, signed
correlation-scale reporting, diagrams, and APIM software already have direct
precedents. Contribution-specific inference remains a bounded evidence gap,
not an established claim of priority.

## 8. Local reference copies and remaining retrieval

Reference copies are stored under `dev/references/`, which is entirely
Git-ignored. The following links work only in a checkout with the local files;
the public source/DOI links above remain the portable way to retrieve them.
Source checks do not establish permission to redistribute the files.

### Manuscript-specific local copies

J-P's supplied archive is also available in the ignored reference folder. Its
[inventory and source links](jp-materials-review-2026-09-13.md#file-inventory-and-roles)
cover the full 2024 chapter, highlighted draft, workshop handouts, R/Mplus files,
and datasets. The supplied APIM_MM manual is byte-identical to the copy below.

| Source | Local file | Provenance/version |
|:--|:--|:--|
| Griffin and Gonzalez (1995) | [PDF](../references/explaining-interdependence-apim/1995-griffin-gonzalez-exchangeable-correlations.pdf) | Author-hosted scanned article; preserved from the review |
| Stas et al. (2018) | [PDF](../references/explaining-interdependence-apim/2018-stas-et-al-apim-sem.pdf) | Author-hosted main article; preserved from the review |
| Kenny (2019), APIM_MM | [PDF](../references/explaining-interdependence-apim/2019-kenny-apim-mm-documentation.pdf) | Author's March 3, 2019 documentation |
| Figueroa et al. (2019) | [PDF](../references/explaining-interdependence-apim/2019-figueroa-et-al-motivation-beverages.pdf) | Cambridge publisher PDF, retrieved August 31, 2026 |
| Ferraris et al. (2022) | [PDF](../references/explaining-interdependence-apim/2022-ferraris-et-al-social-support-well-being.pdf) | Groningen repository version of record with cover sheet, retrieved August 31, 2026 |
| Kenny (n.d.), explained nonindependence | [DOCX](../references/explaining-interdependence-apim/kenny-nd-explained-nonindependence.docx) | Author's handout; preserved from the review |
| De Padova et al. (2021), APIM output | [DOCX](../references/explaining-interdependence-apim/2021-de-padova-et-al-apim-supplement.docx) | Supplement retrieved through Europe PMC, 13 September 2026; four partition tables |
| Velten and Margraf (2017), S2 Table | [DOCX](../references/explaining-interdependence-apim/2017-velten-margraf-s2.docx) | Publisher supplement, checked 13 September 2026; slope estimates only |

### Shared copies left in their existing locations

- [Kenny and Cook (1999)](../references/model_estimation/1999-kenny-cook-partner-effects.pdf).
- [Ledermann and Kenny (2017)](../references/model_estimation/2017-ledermann-kenny-dyadic-mlm-vs-sem.pdf).
- [Ledermann, Macho, and Kenny (2011)](../references/dyadic_model_extensions/2011-ledermann-macho-kenny-apim-mediation.pdf).

### Priority retrieval gaps

- **Dwyer calculation supplement:** not retrieved; ask the authors for
  `NIHMS868627-supplement.pdf` or an equivalent calculation document.
- **Kenny, Ackerman, and Kashy (2024): closed.** Full chapter supplied by J-P;
  Section 23.5 and relevant longitudinal sections inspected. Chapter-linked
  OSF example files remain unchecked; see the supplied-materials review.
- **Bolger-Laurenceau webinar:** inspected online, but not saved locally;
  the download host did not resolve during organization. Use the source link
  above. Do not substitute the different July 2017 FLASHE overview slides.
- Other sources without a local link were inspected online or retained as
  explicitly labelled leads; a complete PDF library has not been assembled.

### Additional citing papers awaiting full-text verification

These nine candidates were retained by the 13 September citation audit. Their
titles, abstracts, previews, or citation records do not establish use of the
focal partition. They are additional retrieval leads, not confirmed additions
to the applied-use count. Titles below are shortened descriptions; see the
[dated audit](citation-audit-2026-09-13.md#unresolved-candidates-and-retrieval-priorities)
for the search context and access limits.

| Candidate | Topic | Citation route |
|:--|:--|:--|
| [Park and Park (2024)](https://doi.org/10.1111/ijpo.13153) | Motivation and dietary behaviours in parent-adolescent dyads | Cites Dwyer |
| [Park and Park (2025)](https://doi.org/10.1016/j.appet.2025.107872) | Self-efficacy, motivation, dietary behaviors, and APIM mediation | Cites Dwyer |
| [Niu et al. (2026)](https://doi.org/10.1016/j.jadohealth.2026.01.016) | Motivational factors, dietary behaviors, and family meal structure | Cites Dwyer |
| [Welch et al. (2019)](https://doi.org/10.1007/s10865-019-00041-4) | Social support, loneliness, eating, and activity | Cites Dwyer |
| [Vu et al. (2026)](https://doi.org/10.1123/jpah.2025-0490) | Acculturation and physical activity in South Asian mother-daughter dyads | Cites Burns |
| [Lu et al. (2022)](https://doi.org/10.1007/s10826-022-02241-0) | Mobile media use and food consumption in parent-child dyads | Cites Dwyer |
| [Niermann et al. (2020 online; 2022 issue)](https://doi.org/10.1080/13229400.2020.1773901) | Parent/child self-efficacy, support, and physical activity | Cites Dwyer |
| [Kim and Chae (2024 online; 2025 issue)](https://doi.org/10.1111/jan.16474) | Family strengths, depression, and life satisfaction in disabled-child/parent-caregiver dyads | Cites Ferraris |
| [Thai thesis (2022)](https://doi.org/10.58837/chula.the.2022.540) | Social support, positive experience, and well-being in older cancer patient-caregiver dyads | Cites Ferraris |

## 9. Search trail and limits

- Searches combined `APIM` / `actor-partner` / `dyadic` with `path tracing`,
  `path-tracing`, `explained nonindependence`, `partition of nonindependence`,
  `covariance explained`, `decomposition`, and actor-/partner-/member-driven terms.
- Followed the Dwyer, webinar, Kenny, Burns, Lee, and Ferraris citation chains,
  plus older correlational models and related methods/software papers.
- Included applied and gray literature. Kept preprints, direct route
  partitions, total-only explanations, and neighboring models separate.
- No authenticated Scopus, Web of Science, or PsycINFO citation exports were
  screened. Access failures and sparse indexing can conceal additional uses.
- Source/page checks refer to the inspected versions. Manuscript page numbers
  can differ from published pagination; repository cover pages also shift the
  PDF viewer's page counter.
