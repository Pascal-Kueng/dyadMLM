# APIM covariance decomposition: annotated literature review

For the main reading list, use the [focused 15-source overview](focused-reading-list.md).
This full 51-source review also retains the other 36 background/related entries
and the source-check record.

Search and source checks: **31 August 2026**.

Forward-citation audit and additions: **13 September 2026**. See the
[dated audit](citation-audit-2026-09-13.md) and its
[citation inventory](citation-audit-2026-09-13.json) for coverage, screening
decisions, and unresolved candidates. Original annotations retain their earlier
verification limits unless explicitly updated below.

Full-text verification through UZH access and public repositories: **6–7 October
2026**. See the [verification and exclusion audit](full-text-verification-2026-10-07.md).
Nine full-text-screened ordinary applications were removed from the focused
list/candidate queue; the repeat Burns (2020) abstract was also removed as a
separate entry. Five retained methods sources now have full-text annotations;
Dwyer's calculation supplement is also retrieved and verified.
Further checks on 7 October verified the relevant 1998 Kenny-Kashy-Bolger
sections, Koch's June 2025 preprint and dated author supplements, both
2024 chapter-linked OSF projects, and Laws's complete publisher PDF/supplement.
Their version and completeness limits are
recorded below; none adds a focal decomposition application.

The main list contains **51 reference entries**, including the grouped
Bolger-Laurenceau (2025) workshop supplied by J-P and Koch et al. (2025, online),
added as adjacent ILD methodology. Perry et al. (2017), added on 7 October,
is longitudinal-APIM visualization context, not a new decomposition application.
The [supplied-materials review](jp-materials-review-2026-09-13.md)
upgrades the 2024 chapter to full-text-verified methodology. **No candidates
remain in the active queue.** Vu et al. (2026) was provisionally excluded after
abstract screening; its full text remains unverified (see below and the audit).
Reference counts include teaching material and background sources; they are
not counts of independent applications.

This records the broad scoping review and the earlier writing-model search.
It is not an exhaustive, database-exported systematic review. Full texts,
author manuscripts, tables, supplements where available, and citation leads
were distinguished from abstract-only records. A missing local PDF does not
mean that the source was not inspected online.

The focal method attributes covariance between dyad members' outcomes to four
APIM predictor-side path products (actor-actor, two member-driven actor-partner
routes, and partner-partner), plus residual covariance. Related decompositions
are retained below, but are not counted as applications of this exact method.

## Presence in J-P's folder: checked 6 October 2026

Compared `/home/pascalkueng/Downloads/Relevant Papers and Resources/` with the
preserved reference folder: all **13 files match by relative path and SHA-256**.
They represent four sources: Dwyer (2017), Kenny's APIM_MM manual (2019), Kenny,
Ackerman, and Kashy (2024), and the grouped Bolger-Laurenceau workshop (2025).
The chapter draft and workshop data/code are supporting files, not extra studies.

Each source below is labelled **IN J-P'S FOLDER** or **NOT IN J-P'S FOLDER**:
**4 of 51 entries are present; 47 are absent**. These labels describe file presence, not J-P's
familiarity with a source. A reference cited inside a supplied document is not
itself included. The method/design annotations retain their stated verification
limits; this folder check was not a new exhaustive literature search.

## Main conclusions and reading order

- Six published applied papers directly use APIM path-tracing decomposition:
  **Dwyer (2017), Burns (2019), Figueroa et al. (2019), Lee et al. (2021),
  Ferraris et al. (2022), and Fu et al. (2025)**.
- The September audit additionally verified **De Padova et al. (2021)**:
  supplementary APIM_MM tables report a grouped partition, including negative
  and cross-predictor contributions. **Velten and Margraf (2017)** report total
  APIM and covariate attribution. Keep these distinct from four separate route
  rows. The repeat Burns (2020) abstract is recorded in the screening audit,
  without a separate reference entry.
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

**NOT IN J-P'S FOLDER**

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

**IN J-P'S FOLDER**

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

**NOT IN J-P'S FOLDER**

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

**IN J-P'S FOLDER**

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

**NOT IN J-P'S FOLDER**

Kenny, D. A. (n.d.). *Path tracing* [Web tutorial].
[Author's website](https://davidakenny.net/cm/tracing.htm).

- **Coverage/use:** General SEM rules for obtaining covariance from paths;
  explicitly cited by Figueroa et al. as part of their decomposition procedure.
  Pair it with the APIM-specific handout, not as evidence that every generic
  tracing tutorial presents the five APIM contributions.

### Kenny, Ackerman, and Kashy (2024): published decomposition methods

**IN J-P'S FOLDER**

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
- **OSF verified 7 October 2026:** all 11 current files in the
  [partition](https://osf.io/zt9s6/) and [longitudinal](https://osf.io/7w3my/)
  projects were retrieved and checked. The ordinary APIM outputs give grouped,
  signed contributions, including covariates. The ILD scripts/output fit
  within/between predictors and random slopes but calculate no temporal
  covariance allocation or predictor-route partition. Their intervals concern
  model parameters and contrasts, not contribution shares. See the
  [file inventory](../references/explaining-interdependence-apim/kenny2024-osf-2026-10-07/inventory.tsv).
- **Versions:** The supplied highlighted DOCX is an undated draft containing
  2022 references, not a verified 2019 publication. Use published Table 23.3;
  it corrects several draft indexes. See the [bundle assessment](jp-materials-review-2026-09-13.md)
  for checked sign/row-placement issues in the published examples.

### Wickham and Knee (2012): theoretical rationale and total explained covariance

**NOT IN J-P'S FOLDER**

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

**IN J-P'S FOLDER**

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
  the controls-only comparison target dependence after adjustment.
- **Supplement verified 7 October 2026:** The two-page appendix divides the
  four products by controls-only outcome residual covariance **1.980**, using
  final-model motivation residual variances .763 (adolescent), .490 (parent),
  and covariance .181. It supplies the formulas and point estimates, without
  contribution intervals. Essential direct precedent for an adjusted partition.
  The supplement is now saved separately; it was not in J-P's folder, whose
  self-efficacy example fits a different model.

### Burns (2019): contribution table in correlation units

**NOT IN J-P'S FOLDER**

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

**NOT IN J-P'S FOLDER**

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

**NOT IN J-P'S FOLDER**

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

**NOT IN J-P'S FOLDER**

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

**NOT IN J-P'S FOLDER**

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

**NOT IN J-P'S FOLDER**

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

## 3. Especially close recent preprint

### Cavalcanti et al. (2026): signed, multi-predictor decomposition

**NOT IN J-P'S FOLDER**

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

**NOT IN J-P'S FOLDER**

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

**NOT IN J-P'S FOLDER**

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

**NOT IN J-P'S FOLDER**

Gonzalez, R., & Siarkiewicz, M. (2006). Jak zbadać związek między stopniem zaufania
a poziomem satysfakcji z małżeństwa? [How can we analyze a relationship between
trust and satisfaction in married couples?]. *Nowiny Psychologiczne, 1*, 15-25.
[Author's PDF](https://websites.umich.edu/~gonzo/papers/Gonzalez-polish.pdf).

- **Application/use:** 74 married couples. Page 21 gives weighted
  individual/dyad-correlation formulas; pp. 22-23 apply them to trust,
  satisfaction, and control preferences. An applied decomposition in another
  dyadic model, not an APIM five-route table. Polish text with English abstract.

### Jang (2016): total explained nonindependence in negotiation

**NOT IN J-P'S FOLDER**

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

**NOT IN J-P'S FOLDER**

Kline, R. B. (2016). *Principles and practice of structural equation modeling*
(4th ed.). Guilford Press.

- **Verified 13 September 2026:** Dwyer's path-tracing methods sentence cites
  this book as reference 39. Retain as the directly cited general SEM
  foundation; APIM-specific partition content in the book was not verified.

### Boker, McArdle, and Neale (2002)

**NOT IN J-P'S FOLDER**

*An algorithm for the hierarchical organization of path diagrams and calculation
of components of expected covariance*. *Structural Equation Modeling, 9*(2),
174-194. [DOI](https://doi.org/10.1207/S15328007SEM0902_2).

- **Borrow:** Diagram-led explanation, path enumeration, and the transition from
  an intuitive graph to an algorithm. It establishes general expected-covariance
  component algebra, not a new APIM-specific procedure. More technical than
  the intended applied-facing exposition.

### Ledermann, Macho, and Kenny (2011)

**NOT IN J-P'S FOLDER**

*Assessing mediation in dyadic data using the actor-partner interdependence
model*. *Structural Equation Modeling, 18*(4), 595-612.
[DOI](https://doi.org/10.1080/10705511.2011.607099).

- **Borrow:** Introduce a substantive dyadic question, define compound path
  products, simplify model variants, then demonstrate estimation and reporting.
  Bootstrap inference is relevant as an analogy for derived effects; mediation
  products are not the covariance components considered here.

### Laurenceau and Bolger (2005)

**NOT IN J-P'S FOLDER**

*Using diary methods to study marital and family processes*.
*Journal of Family Psychology, 19*(1), 86-97.
[DOI](https://doi.org/10.1037/0893-3200.19.1.86).

- **Borrow:** Question-first, accessible prose, compact mathematics tied to
  substantive examples, and clear treatment of within-person/dyadic structure.
  A strong voice/structure model, not a direct four-route paper or a Monte Carlo
  bias-study template.

### Bolger and Shrout (2007)

**NOT IN J-P'S FOLDER**

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

### Perry et al. (2017): longitudinal APIM visualization

**NOT IN J-P'S FOLDER**

*Graphic Methods for Interpreting Longitudinal Dyadic Patterns From
Repeated-Measures Actor–Partner Interdependence Models*.
[DOI](https://doi.org/10.1037/fam0000293)
| [Local author manuscript](../references/visualization/2017-perry-et-al-graphic-methods-longitudinal-apim.pdf).

- **Coverage/use:** Main methods/results, figures and plotting appendix checked
  7 October. Vector fields display predicted dyadic change, stability and
  attractors from actor/partner coefficients. Examples include minute-level
  heart-rate series for three couples and seven repeated observations in 59
  couples. Pages 21–22 explicitly state that the multilevel coefficients combine
  within- and between-couple associations. No outcome-covariance route partition
  at either temporal level is shown. Relevant visualization methods and applied
  examples, not evidence of the focal decomposition.

### Gistelinck, Loeys, Decuyper, and Dewitte (2018)

**NOT IN J-P'S FOLDER**

*Indistinguishability tests in the actor-partner interdependence model*.
*British Journal of Mathematical and Statistical Psychology, 71*(3), 472-498.
[DOI](https://doi.org/10.1111/bmsp.12129).

- **Borrow:** A methods-paper structure linking statistical conditions,
  simulation comparisons, and practical recommendations. Use if making
  finite-sample inference claims; it studies distinguishability tests, not
  the proposed covariance-component estimators.

### Jones and West (2005)

**NOT IN J-P'S FOLDER**

*Covariance decomposition in undirected Gaussian graphical models*.
*Biometrika, 92*(4), 779-786.
[DOI](https://doi.org/10.1093/biomet/92.4.779).

- **Coverage/use:** Signed path-weight covariance decomposition in a different,
  undirected model class. Important generic prior art for additive/signed
  interpretation and rescaling; not a direct dyadic application or necessarily
  the best stylistic template for an applied-facing paper.

### Zhang, Hamagami, Grimm, and McArdle (2015)

**NOT IN J-P'S FOLDER**

*Using R package RAMpath for tracing SEM path diagrams and conducting complex
longitudinal data analysis*. *Structural Equation Modeling, 22*(1), 132-147.
[DOI](https://doi.org/10.1080/10705511.2014.935257).

- **Coverage/use:** Generic SEM path tracing and software-assisted covariance
  calculation. A software/tutorial precedent; do not claim the first automatic
  path-tracing or general covariance-decomposition implementation.

### Kenny and Ledermann (2010)

**NOT IN J-P'S FOLDER**

*Detecting, measuring, and testing dyadic patterns in the actor-partner
interdependence model*. *Journal of Family Psychology, 24*(3), 359-366.
[DOI](https://doi.org/10.1037/a0019651).

- **Coverage/use:** Converts actor/partner coefficients into interpretable
  dyadic-pattern quantities, notably `k`. Useful framing for derived APIM
  estimands; ratio inference is not evidence for covariance-route inference.

### Stas, Kenny, Mayer, and Loeys (2018)

**NOT IN J-P'S FOLDER**

*Giving dyadic data analysis away: A user-friendly app for actor-partner
interdependence models*. *Personal Relationships, 25*, 103-119.
[DOI](https://doi.org/10.1111/pere.12230)
| [Author's PDF](https://davidakenny.net/doc/APIM_SEM.pdf).

- **Coverage/use:** APIM_SEM software, standardized paths, diagrams, and dyadic
  patterns. The main article was screened; no explicit route-partition table
  was located. Appendices/current app were not audited. Keep distinct from
  the directly verified APIM_MM partition in Kenny's manual.

## 6. Foundations, extension context, and screened leads

- **NOT IN J-P'S FOLDER** - **Gistelinck and Loeys (2019).** *The actor-partner interdependence model
  for longitudinal dyadic data: An implementation in the SEM framework*.
  *Structural Equation Modeling, 26*(3), 329-347.
  [DOI](https://doi.org/10.1080/10705511.2018.1527223)
  | [Author dissertation, Chapter 3](https://backoffice.biblio.ugent.be/download/8635510/8635511).
  Added 13 September 2026. Substantial longitudinal APIM methodology, with
  time-averaged/time-specific actor and partner effects, random-intercept
  covariance, daily residual covariance, and serial dependence. The application
  uses three-week diaries from 66 couples. Inspected equations and covariance
  structure in dissertation pp. 87-89. Rechecked 7 October: p. 102 and Table
  3.5.2 (p. 104) explicitly attribute 89% of modeled same-day dependence to
  daily residual covariance and 11% to random-intercept covariance. This is
  remaining dependence after the predictor mean structure, not attribution
  to actor/partner predictor products at either level. Covariance-parameter
  intervals are supplied; intervals for these shares are not. Strong ILD
  methods with an applied level partition, not the focal route partition.
  [Local dissertation](../references/explaining-interdependence-apim/gistelinck-dissertation-l-apim.pdf).
  Published online in 2018, journal issue in 2019.
- **NOT IN J-P'S FOLDER** - **Savord, McNeish, Iida, Quiroz, and Ha (2023).** *Fitting the longitudinal
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
  **Code checked 7 October 2026:** the [author-linked OSF bundle](https://osf.io/vamku/?view_only=4f5b4c39fb294b0281566b94b61198da)
  supplies five fitting scripts: Mplus SEM/DSEM and SAS MLM, including random
  lagged slopes and multiple outcomes. None calculates predictor-route
  contributions or shares at either temporal level. The original scripts and
  provenance are [retained locally](../references/explaining-interdependence-apim/savord2023-code-2026-10-07/README.md).
- **NOT IN J-P'S FOLDER** - **Loeys and Molenberghs (2013).** *Modeling actor and partner effects in
  dyadic data when outcomes are categorical*. *Psychological Methods, 18*(2),
  220-236. [DOI](https://doi.org/10.1037/a0030640)
  | [Author manuscript](https://documentserver.uhasselt.be/bitstream/1942/14740/1/met_loeys_0112.pdf).
  Added 13 September 2026. Substantial binary/count APIM methods, simulations,
  and applications comparing GLMM/GEE approaches. Derives/discusses marginal
  moments and within-dyad association, including logistic ICC approximation.
  Full manuscript inspected; no actor/partner predictor-route covariance
  attribution located. Essential non-Gaussian APIM context, distinct from
  Leckie's general multilevel variance-partition contribution.
- **NOT IN J-P'S FOLDER** - **Loeys, Cook, De Smet, Wietzker, and Buysse (2014).** *The actor-partner
  interdependence model for categorical dyadic data: A user-friendly guide to
  GEE*. *Personal Relationships, 21*(2), 225-241.
  [DOI](https://doi.org/10.1111/pere.12028).
  Full text and SAS appendix verified 6–7 October 2026. Substantial practical
  guide to logistic/negative-binomial GEE, illustrated with 46 ex-couples;
  no temporal ILD panel. Reports robust actor/partner inference and working
  residual correlations (.09 binary, −.07 count), without inference for those
  nuisance correlations or a predictor-route partition. Retain as non-Gaussian
  APIM methods context; the 2013 paper is the stronger technical foundation.
- **NOT IN J-P'S FOLDER** - **Johnson (2014).** *Extension of Nakagawa and Schielzeth's R-squared GLMM
  to random slopes models*. *Methods in Ecology and Evolution, 5*(9), 944-946.
  [DOI](https://doi.org/10.1111/2041-210X.12225)
  | [Institutional record](https://eprints.gla.ac.uk/94906/).
  Extends a mixed-model variance summary to random-slope structures. Useful
  extension context for defining how random-effect variation enters a summary;
  not an APIM covariance-route decomposition or evidence for component inference.
  Full author manuscript checked September 2026: Eq. 11 averages random-effect
  variances using the trace of the implied random-effect covariance matrix.
- **NOT IN J-P'S FOLDER** - **Leckie, Browne, Goldstein, Merlo, and Austin (2020).** *Partitioning
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
- **NOT IN J-P'S FOLDER** - **Kenny (1996).** *Models of non-independence in dyadic research*.
  *Journal of Social and Personal Relationships, 13*, 279-294.
  [DOI](https://doi.org/10.1177/0265407596132007).
  Full article verified 7 October 2026. Substantial foundation for partner
  effects, mutual influence and common fate. Gives actor/partner equations,
  within-/between-dyad slope estimation, covariates and coefficient tests
  (pp. 283–289), without an explicit four-product outcome-covariance partition.
  Within/between refers to members and dyads, not temporal ILD. Its toy-sharing
  count example uses linear analysis, not a generalized response model.
- **NOT IN J-P'S FOLDER** - **Kenny and Cook (1999).** *Partner effects in relationship research:
  Conceptual issues, analytic difficulties, and illustrations*.
  *Personal Relationships, 6*, 433-448.
  [DOI](https://doi.org/10.1111/j.1475-6811.1999.tb00202.x).
  Local full text screened: APIM patterns and residual nonindependence,
  including negative residual dependence; no explicit four-route expansion
  or contribution table located. Adjacent, not a confirmed direct precedent.
- **NOT IN J-P'S FOLDER** - **Cook and Kenny (2005).** *The actor-partner interdependence model: A model
  of bidirectional effects in developmental studies*.
  *International Journal of Behavioral Development, 29*, 101-109.
  [DOI](https://doi.org/10.1080/01650250444000405).
  Author-posted full text screened: actor/partner paths and remaining
  nonindependence, but no explicit four-product decomposition located.
- **NOT IN J-P'S FOLDER** - **Campbell and Kashy (2002).** *Estimating actor, partner, and interaction
  effects for dyadic data using PROC MIXED and HLM: A user-friendly guide*.
  *Personal Relationships, 9*, 327-342.
  [DOI](https://doi.org/10.1111/1475-6811.00023).
  Full article verified 6–7 October 2026. Foundational PROC MIXED/HLM guide
  using fictitious cross-sectional dyads, gender/experimental-condition
  adjustment, and actor/partner interactions. Page 332 reports a partial ICC;
  Tables 2–3 report ordinary coefficients and covariance parameters, without
  allocating outcome covariance to predictor routes. Its member/dyad hierarchy
  is not temporal ILD. Retain for estimation and SEM/MLM context.
- **NOT IN J-P'S FOLDER** - **Kenny, Kashy, and Cook (2006).** *Dyadic data analysis*. Guilford Press.
  [Publisher](https://www.guilford.com/books/Dyadic-Data-Analysis/Kenny-Kashy-Cook/9781572309869).
  Chapter 7, pp. 144-184, is the APIM foundation. The companion handout was
  verified, but a corresponding printed decomposition passage was not.
- **NOT IN J-P'S FOLDER** - **Ledermann and Kenny (2017).** *Analyzing dyadic data with multilevel
  modeling versus structural equation modeling: A tale of two methods*.
  *Journal of Family Psychology, 31*(4), 442-452.
  [DOI](https://doi.org/10.1037/fam0000290).
  Local full text screened: useful for SEM/MLM estimation, standardization,
  missing data, and parameter availability. No explicit route partition found;
  citing APIM_MM alone does not establish use of its decomposition.
- **NOT IN J-P'S FOLDER** - **Kenny and Kashy (2014).** *The design and analysis of data from dyads and
  groups*. In *Handbook of research methods in social and personality psychology*
  (2nd ed., pp. 589-607). [DOI](https://doi.org/10.1017/CBO9780511996481.027).
  Full chapter verified 7 October 2026 through Cambridge/UZH. Substantial
  synthesis of APIM estimation, distinguishability, dyadic patterns, mediation,
  and group models; no focal four-route covariance allocation located.
  The conclusion explicitly excludes over-time dyadic data from its scope.
  Group/SRM variance partitions are different targets. Retain as foundational
  context; cite the 2024 Ackerman chapter for direct decomposition methods.
- **NOT IN J-P'S FOLDER** - **Kashy and Kenny (2000).** *The analysis of data from dyads and groups*.
  In *Handbook of research methods in social and personality psychology*
  (1st ed., pp. 451-477). Earlier chapter cited by APIM_MM; specific
  decomposition content remains unverified.
- **NOT IN J-P'S FOLDER** - **Kenny, Kashy, and Bolger (1998).** *Data analysis in social psychology*.
  In *The handbook of social psychology* (4th ed., Vol. 1, pp. 233-265).
  [Author's PDF](https://www.columbia.edu/~nb2229/docs/KennyKashyBolger1998-Data_analysis.pdf).
  Relevant sections checked 7 October 2026: pp. 244–245 explain actor/partner
  effects and pooled between-/within-group regressions; pp. 246–251 cover
  general multilevel random intercepts/slopes and inference. Pages 262–263
  discuss diary-level mediation/moderation. No focal paired-outcome covariance
  route partition was located in these sections. Retain as methods background,
  not direct decomposition evidence. The author scan is incomplete: printed
  p. 238 is missing, although these relevant sections are present.
- **NOT IN J-P'S FOLDER** - **Gonzalez and Griffin (1999).** *The correlational analysis of dyad-level
  data in the distinguishable case*. *Personal Relationships, 6*, 449-469.
  [DOI](https://doi.org/10.1111/j.1475-6811.1999.tb00203.x).
  Full article and appendix verified 6–7 October 2026. Substantial methods
  treatment with diagrams, equations, SEM syntax, and correlation-inference
  simulations. Equation 3 (p. 457) partitions the role-adjusted own-member X–Y
  correlation into shared-dyad and individual contributions; it does not
  partition Cov(Y1,Y2) into actor/partner routes. Individual/dyad latent levels
  are cross-sectional, not temporal ILD. Pages 454 and 462 address role-mean
  adjustment and an extension to covariates at both latent levels.
- **NOT IN J-P'S FOLDER** - **Gonzalez and Griffin (2004).** *Measuring individuals in a social
  environment: Conceptualizing dyadic and group interaction*.
  [Author's chapter PDF](https://websites.umich.edu/~gonzo/papers/gonzalez-griffin-methodshb.pdf).
  Graphical/conceptual background on individual and group levels; screened as
  adjacent rather than a confirmed four-route APIM application.
- **NOT IN J-P'S FOLDER** - **Gonzalez and Griffin (2023).** *Dyadic data analysis*. In *APA handbook of
  research methods in psychology* (2nd ed., Vol. 3, Chapter 21).
  [DOI](https://doi.org/10.1037/0000320-021)
  | [Author's proof](https://websites.umich.edu/~gonzo/papers/gonzalez-griffin-2023-dyad.pdf).
  General dyadic-analysis chapter screened; no focal route-partition passage
  confirmed. Absence of a search-text match is not proof of absence.
- **NOT IN J-P'S FOLDER** - **Bolger and Laurenceau (2013).** *Intensive longitudinal methods: An
  introduction to diary and experience sampling research*. Guilford Press.
  [Publisher](https://www.guilford.com/books/Intensive-Longitudinal-Methods/Bolger-Laurenceau/9781462506781).
  Background for ILD estimands and accessible exposition. **User check,
  7 October 2026:** the book does not contain the focal decomposition; retain
  as ILD background, not direct decomposition evidence. This is the user's
  source check, not a new independent full-book inspection. Figueroa's
  procedural citation is the webinar, not this book.
- **NOT IN J-P'S FOLDER** - **Laws et al. (2026).** *The random dyadic interdependence model: Modeling
  variability in physiological covariation within dyads*.
  *Biological Psychology, 206*, 109259.
  [DOI](https://doi.org/10.1016/j.biopsycho.2026.109259).
  **Verified 7 October 2026:** complete publisher PDF and supplement, now saved
  locally. Substantial methods exposition/application of Gaussian two-level
  DSEM to 102 parent–adult-child dyads and 47,988 synchronized 10-second bins.
  Pages 6–8/Fig. 1 model latent within/between outcomes, random intercepts,
  time trends, log residual variances and dyad-specific residual correlation
  on the Fisher-z scale. No actor/partner predictor
  routes or covariance-contribution shares at either temporal level are supplied.
  Age/health covariates predict physiological outcomes; dyadic characteristics
  predict heterogeneity in residual association (pp. 9–11/Table 3). These are
  adjustment/moderation, not covariate-route attribution. Bayesian intervals
  concern model parameters, association summaries and predictors; Table 2's
  plausible-value range describes between-dyad heterogeneity. The supplement
  supplies unconditional Mplus code and an autoregressive comparison, not
  contribution inference. Keep as adjacent ILD heterogeneity methods; no
  generalized response link or focal APIM partition at both levels. The NIH
  manuscript's April 2027 embargo no longer blocks verification of this source.
- **NOT IN J-P'S FOLDER** - **Koch, Jaehne, Riediger, Rauers, and Holtmann (2025, online).**
  *Idiographic interrater reliability measures for intensive longitudinal
  multirater data*. *British Journal of Mathematical and Statistical Psychology*.
  Published online 20 December 2025.
  [DOI](https://doi.org/10.1111/bmsp.70022)
  | [June preprint](https://doi.org/10.23668/psycharchives.16498)
  | [Author supplements](https://osf.io/g8hnz/).
  **Verified 7 October 2026:** complete June 30 preprint and later August/September
  supplements; final journal text remains unverified. Substantial ILD methods
  for self/partner ratings of the same person's affect: 100 couples, 86 occasions.
  Pages 6–11/Eqs. 1–8 distinguish shared and rater-specific variance, with random
  loadings, autoregressions and innovation variances. These are rater-consistency
  ratios, not actor/partner routes in paired-outcome covariance. Later code
  computes posterior-draw ratios and credible intervals; some shared loadings
  use plug-in estimates. Supplementary coverage rows concern model parameters,
  not the derived ratios. Covariates predict individual consistency in a
  two-step analysis. Keep as adjacent Gaussian latent time-series methodology,
  not a focal decomposition at both temporal levels.

## 7. Implications for this manuscript

The [methods, design, and citation map](method-scope-and-citation-map.md), updated
7 October 2026, distinguishes substantial methods contributions from applied
precedents and recommends citations for Paper 1. It also records the verified
analysis designs and response models. The eight closest published application
analyses are cross-sectional; Cavalcanti uses repeated encounters with crossed
random effects. Bolger and Shrout, and Gistelinck and Loeys, already partition
ILD dependence across temporal levels. Leckie et al. derive non-Gaussian multilevel covariance and
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

J-P's supplied materials are preserved in the ignored reference folder. Its
[inventory and source links](jp-materials-review-2026-09-13.md#file-inventory-and-roles)
cover the full 2024 chapter, highlighted draft, workshop handouts, R/Mplus files,
and datasets. The supplied APIM_MM manual is byte-identical to the copy below.

| Source | Local file | Provenance/version |
|:--|:--|:--|
| Campbell and Kashy (2002) | [PDF](../references/explaining-interdependence-apim/2002-campbell-kashy-proc-mixed-hlm.pdf) | Licensed Wiley article retrieved through UZH, 6 October 2026; full text screened |
| Gonzalez and Griffin (1999) | [PDF](../references/explaining-interdependence-apim/1999-gonzalez-griffin-distinguishable-correlations.pdf) | Licensed Wiley article retrieved through UZH, 6 October 2026; publication year 1999 despite download filename |
| Kenny (1996) | [PDF](../references/explaining-interdependence-apim/1996-kenny-models-nonindependence.pdf) | Licensed Sage scan retrieved through UZH, 7 October 2026; full text/diagrams screened |
| Kenny, Kashy, and Bolger (1998) | [PDF](../references/explaining-interdependence-apim/1998-kenny-kashy-bolger-data-analysis.pdf) | Author-hosted scan retrieved 7 October 2026; relevant APIM/MLM/diary sections checked; printed p. 238 is missing |
| Kenny et al. (2024), OSF companion files | [Inventory](../references/explaining-interdependence-apim/kenny2024-osf-2026-10-07/inventory.tsv) | All 11 current files in two projects, with versions and SHA-256; checked 7 October 2026; code read, not executed |
| Koch et al. (2025), primary preprint | [PDF](../references/explaining-interdependence-apim/2025-koch-et-al-idiographic-interrater-reliability-psycharchives-preprint-2025-06-30.pdf) | Complete June 30 PsychArchives preprint; checksum verified 7 October 2026; not the final journal version |
| Koch et al. (2025), later author materials | [Supplement PDF](../references/explaining-interdependence-apim/2025-koch-et-al-idiographic-interrater-reliability-osf-supplement-2025-08-28.pdf), [code provenance](../references/explaining-interdependence-apim/koch2025-osf-2026-10-07/koch-code-provenance.json) | August 28 supplement and August/September posterior-processing scripts; checked 7 October 2026; scripts preserved without execution |
| Laws et al. (2026) | [PDF](../references/explaining-interdependence-apim/2026-laws-et-al-random-dyadic-interdependence-model.pdf), [supplement DOCX](../references/explaining-interdependence-apim/2026-laws-et-al-random-dyadic-interdependence-model-supplement.docx) | User-downloaded publisher PDF and publisher supplement retrieved through UZH, 7 October 2026; full text, figure, tables and embedded Mplus code checked; code not executed |
| Dwyer et al. (2017), calculation appendix | [PDF](../references/explaining-interdependence-apim/2017-dwyer-calculation-supplement.pdf) | Two-page PMC supplement retrieved and verified 7 October 2026; controls-adjusted denominator and four formulas |
| Gistelinck and Loeys (2019), dissertation Chapter 3 | [PDF](../references/explaining-interdependence-apim/gistelinck-dissertation-l-apim.pdf) | UGent dissertation containing the paper; pp. 102/104 level-attribution calculation and covariance table rechecked 7 October 2026; author version, not publisher PDF |
| Savord et al. (2023), author code | [Code inventory and scope](../references/explaining-interdependence-apim/savord2023-code-2026-10-07/README.md) | Five original Mplus/SAS scripts from the author-linked OSF, with URLs and hashes; inspected 7 October 2026; code not executed |
| Griffin and Gonzalez (1995) | [PDF](../references/explaining-interdependence-apim/1995-griffin-gonzalez-exchangeable-correlations.pdf) | Author-hosted scanned article; preserved from the review |
| Stas et al. (2018) | [PDF](../references/explaining-interdependence-apim/2018-stas-et-al-apim-sem.pdf) | Author-hosted main article; preserved from the review |
| Kenny (2019), APIM_MM | [PDF](../references/explaining-interdependence-apim/2019-kenny-apim-mm-documentation.pdf) | Author's March 3, 2019 documentation |
| Figueroa et al. (2019) | [PDF](../references/explaining-interdependence-apim/2019-figueroa-et-al-motivation-beverages.pdf) | Cambridge publisher PDF, retrieved August 31, 2026 |
| Ferraris et al. (2022) | [PDF](../references/explaining-interdependence-apim/2022-ferraris-et-al-social-support-well-being.pdf) | Groningen repository version of record with cover sheet, retrieved August 31, 2026 |
| Kenny (n.d.), explained nonindependence | [DOCX](../references/explaining-interdependence-apim/kenny-nd-explained-nonindependence.docx) | Author's handout; preserved from the review |
| De Padova et al. (2021), APIM output | [DOCX](../references/explaining-interdependence-apim/2021-de-padova-et-al-apim-supplement.docx) | Supplement retrieved through Europe PMC, 13 September 2026; four partition tables |
| Velten and Margraf (2017), S2 Table | [DOCX](../references/explaining-interdependence-apim/2017-velten-margraf-s2.docx) | Publisher supplement, checked 13 September 2026; slope estimates only |
| Velten and Margraf (2017), S1 Text | [DOCX](../references/explaining-interdependence-apim/2017-velten-margraf-s1-model.docx) | [Publisher supplement](https://journals.plos.org/plosone/article/file?id=10.1371/journal.pone.0172855.s005&type=supplementary), checked 7 October 2026; model equation/explanation, not executable syntax |

### Shared copies left in their existing locations

- [Kenny and Cook (1999)](../references/model_estimation/1999-kenny-cook-partner-effects.pdf).
- [Ledermann and Kenny (2017)](../references/model_estimation/2017-ledermann-kenny-dyadic-mlm-vs-sem.pdf).
- [Ledermann, Macho, and Kenny (2011)](../references/dyadic_model_extensions/2011-ledermann-macho-kenny-apim-mediation.pdf).

### Priority retrieval gaps

- **Dwyer calculation supplement: closed 7 October 2026.** The genuine
  two-page PDF is saved and verified; see its local link above and annotation.
- **Kenny, Ackerman, and Kashy (2024): closed.** Full chapter supplied by J-P;
  Section 23.5 and relevant longitudinal sections inspected. Both linked OSF
  projects are now checked and retained; see the supplied-materials review.
- **Koch: primary preprint and author supplements retrieved and verified.**
  The exact final journal version remains unchecked.
- **1998 Kenny-Kashy-Bolger chapter: relevant sections verified.** The author
  scan omits printed p. 238; do not treat this as complete chapter retrieval.
- **Laws (2026): closed.** Complete publisher PDF and supplement checked and
  retained, including the annotated Mplus example.
- **Still unresolved:** Kashy-Kenny (2000) chapter;
  the printed Kenny-Kashy-Cook (2006) APIM passage; Kline (2016) book content.
  The user's Bolger-Laurenceau (2013) book check is recorded above.
- **Bolger-Laurenceau webinar:** inspected online, but not saved locally;
  the download host did not resolve during organization. Use the source link
  above. Do not substitute the different July 2017 FLASHE overview slides.
- Other sources without a local link were inspected online or retained as
  explicitly labelled leads; a complete PDF library has not been assembled.

### Abstract-screened lead: provisional exclusion

**Vu et al. (2026) is NOT IN J-P'S FOLDER**, checked against the folder on
6 October 2026. Its [abstract](https://pubmed.ncbi.nlm.nih.gov/42463118/)
describes baseline APIM associations in 126 South Asian mother–daughter dyads,
without mentioning covariance decomposition or explained nonindependence.
Removed from the active queue on 7 October as a **provisional abstract-based
exclusion**; full text remains inaccessible, so absence of the focal method is
unverified. The [October audit](full-text-verification-2026-10-07.md) preserves
this limitation separately from the nine full-text exclusions.

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
