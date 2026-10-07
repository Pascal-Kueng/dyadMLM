# Focused APIM decomposition reading list

Updated **7 October 2026**. These **15 sources** cover the main methodological
and applied precedents for explaining paired-outcome covariance through APIM
predictor paths. They include teaching materials and a preprint, not 15
independent published studies. The [full 51-source review](literature-review.md)
retains the other 36 entries as background and the search record.

**J-P folder:** four sources are included and 11 are absent. “Yes” means the
source occurs in his supplied `Relevant Papers and Resources` folder, whose
13 files still match the preserved bundle by path and SHA-256 on 7 October.
Later-retrieved supplements and OSF files are not automatically part of that
bundle.

**ILD** means intensive longitudinal data, with repeated occasions separated
from stable person/dyad differences. An ordinary dyadic MLM does not itself
provide these temporal levels. None of the 15 sources demonstrates separate
actor/partner predictor-route partitions at both temporal levels. The eight
published application analyses below are cross-sectional.

## Methods and teaching resources

| Source | In J-P folder? | Method and contribution | ILD and temporal level decomposition |
|:--|:--|:--|:--|
| [Kenny, Ackerman and Kashy (2024)](https://doi.org/10.1017/9781009170123.024), handbook chapter | **Yes** | Section 23.5 derives four predictor routes plus residual covariance for distinguishable/exchangeable dyads; extends to multiple predictors, covariates and cross-terms. Numerical examples and OSF outputs. | Partition example uses predictors/outcomes 18 months apart: an ordinary two-wave APIM. Separate ILD sections/scripts fit within/between predictors and random slopes, without route partitions at either temporal level. |
| [Kenny (n.d.)](https://davidakenny.net/kkc/c7/Explained_Nonindependence.docx), *Explained nonindependence* handout | No | Direct path algebra and diagrams, distinguishable/exchangeable cases, signed contributions, scaling and covariates. Undated; do not attribute it automatically to the 2006 book. | Ordinary dyadic APIM treatment; no temporal ILD partition shown. |
| [Kenny (2019)](https://davidakenny.net/doc/APIM_MM.pdf), APIM_MM manual | **Yes** | Existing MLM/linear-model implementation and tables of grouped correlation contributions, including covariates, multiple predictors and negative values. | Ordinary dyadic models. Its within/between-dyad covariate categories concern dyad members, not repeated-measurement temporal levels. |
| [Bolger and Laurenceau (2016)](https://cancercontrol.cancer.gov/sites/default/files/2020-06/flashe-webinar-2.5.2016.pdf), FLASHE webinar | No | Worked linear APIM: diagrams trace four standardized predictor products plus residual dependence; reports amounts and percentages. | Cross-sectional teaching example; no temporal level partition. |
| [Bolger and Laurenceau (2025)](jp-materials-review-2026-09-13.md), workshop bundle | **Yes** | Matched self-efficacy/intake example with four routes plus residual, and R/Mplus fitting files. Supplied scripts fit the APIM but do not calculate the derived contributions or their intervals. | One row per dyad; cross-sectional example, no temporal level partition. |
| [Wickham and Knee (2012)](https://doi.org/10.1177/1088868312447897) | No | Earlier methodological discussion of APIM covariance/path tracing. Worked example compares unexplained covariance across models; no four-route contribution table established. | No temporal ILD route partition in the inspected treatment. |

## Published applications reporting four routes

| Source | In J-P folder? | Method and contribution | ILD and temporal level decomposition |
|:--|:--|:--|:--|
| [Dwyer et al. (2017)](https://doi.org/10.1016/j.amepre.2017.01.011) | **Yes** | Linear SEM of motivation/intake; four products use adjusted predictor moments and controls-only outcome covariance as denominator. Calculation supplement supplies formulas, but was not in J-P's bundle. | Cross-sectional; no temporal level partition. |
| [Burns (2019)](https://doi.org/10.1016/j.ypmed.2019.105756) | No | Linear SEM of enjoyment/self-efficacy and physical activity; four products per predictor in correlation units/percentages. Cross-predictor terms require care when interpreting the combined sum. | Cross-sectional; no temporal level partition. |
| [Figueroa et al. (2019)](https://doi.org/10.1017/S136898001800383X) | No | Multiple-group linear SEM of motivation/beverage intake; explicit path tracing and explained-covariance percentages by parent role. Complete numerical reconstruction is unavailable. | Cross-sectional; no temporal level partition. |
| [Lee et al. (2021)](https://doi.org/10.1007/s10826-021-01906-6) | No | Linear SEM of mental health/closeness; adjusted path attribution following Dwyer. Bootstrap model intervals do not establish intervals for the reported contributions. | Cross-sectional baseline analysis of a trial; no temporal level partition. |
| [Ferraris et al. (2022)](https://doi.org/10.1037/fam0001009) | No | Linear SEM of social support/well-being; appendix prints four formulas and substitutions. Residual-moment provenance and a numerical discrepancy limit replication. | Cross-sectional; no temporal level partition. |
| [Fu et al. (2025)](https://doi.org/10.18122/ijpah.4.1.3.boisestate) | No | Linear SEM partitions parental-health covariance into four routes plus residual. Logistic/Poisson models belong to a separate analysis, not this partition. | Cross-sectional; no temporal level partition. “Cross-lagged” wording does not establish longitudinal data. |

## Grouped attribution and a close preprint

| Source | In J-P folder? | Method and contribution | ILD and temporal level decomposition |
|:--|:--|:--|:--|
| [De Padova et al. (2021)](https://doi.org/10.1002/cam4.3961) | No | APIM_MM symptom models; supplementary tables report grouped actor/partner and predictor-correlation contributions, negative values and a cross-predictor term. Not four separately printed elementary routes. | Cross-sectional; no temporal level partition. |
| [Velten and Margraf (2017)](https://doi.org/10.1371/journal.pone.0172855) | No | GLS/REML APIM of sexual satisfaction; reports total APIM and between-dyad covariate attribution. Exact cross-term grouping is not supplied. | Cross-sectional; no temporal level partition. |
| [Cavalcanti et al. (2026), v1 preprint](https://doi.org/10.21203/rs.3.rs-9910824/v1) | No | Crossed mixed model of conversational enjoyment; partitions covariance of fixed-only predictions into signed, multiple-predictor components. Full marginal covariance including random effects is a different target. | Repeated encounters with crossed person/partner/conversation effects; no separate temporal within/between APIM route partition. |

## Related ILD methods and citation priorities

Keep these outside the focused 15, in the
[methods and citation map](method-scope-and-citation-map.md): **Bolger and
Shrout (2007)** and **Gistelinck and Loeys (2019)** allocate modeled dependence
to stable/daily levels; **Savord et al. (2023)** covers longitudinal APIM/DSEM
and random slopes; **Laws et al. (2026)** models heterogeneous residual
correlations; **Koch et al. (2025)** develops rater-consistency ratios and
posterior-draw uncertainty. These are relevant ILD precedents, with different
targets from actor/partner route attribution at both levels. All five are
absent from J-P's supplied folder.

For Paper 1, start with the **2024 chapter, Kenny handout/manual and
Bolger–Laurenceau examples**, then **Dwyer, Ferraris and Burns** for applied
calculations/reporting. Wickham–Knee, De Padova and Cavalcanti help position
theory, signed contributions and multiple predictors. The other applications
document uptake; inclusion here does not require citing every source.

The inspected route tables/materials do not supply intervals for the four
derived contributions or their normalized shares. This is a bounded evidence
gap, not proof of novelty. Source-specific verification and numerical limits
remain in the full review and the [October audit](full-text-verification-2026-10-07.md).
