# APIM decomposition: forward-citation audit, 13 September 2026

## Result

The earlier 42-reference scoping review missed a substantive applied source:
**De Padova et al. (2021)**. Its supplementary APIM_MM output explicitly partitions
nonindependence, including negative and cross-predictor contributions. It groups
the elementary routes instead of printing four separate route rows. Also add
**Velten and Margraf (2017)** for total/grouped explained nonindependence,
**Burns (2020)** as a conference abstract of the already-listed analysis, and
**Kline (2016)** as the general path-tracing source directly cited by Dwyer.

No additional independent application printing the four elementary APIM routes
was confirmed in this pass. This is a bounded search result, not evidence of
exhaustiveness. Most citing records were screened by title and available abstract;
selected plausible candidates were inspected in full text. Paywalled candidates
remain unresolved.

## What the original search established

The 31 August review documented keyword searches, reference-list checks, and
citation chains around Dwyer, the Bolger-Laurenceau webinar, Kenny, Burns, Lee,
and Ferraris. It did not preserve a complete citing-paper inventory or a
record-by-record systematic screening log. The original parent task's retained
search calls did not establish a complete citation-index harvest; its subagent
work should not be assumed to supply undocumented coverage.

The method needs two kinds of tracing:

1. **Backward reference checking:** which source does the actual methods
   sentence cite for the calculation?
2. **Forward citation checking:** which later papers cite a seed, and do their
   methods/results actually use or discuss the partition?

A citation to Dwyer, Kenny, or APIM_MM alone is insufficient. Papers often cite
them for substantive associations, ordinary APIM estimation, or dyadic patterns.

## Citation inventories retrieved

Counts below are returned database records on 13 September 2026, not independent
studies or applications. A dash means not queried; unavailable means the seed was
not indexed, not zero citations.

| Seed | DOI | OpenAlex | Europe PMC | Semantic Scholar |
|:--|:--|--:|--:|--:|
| Dwyer (2017) | 10.1016/j.amepre.2017.01.011 | 71 | 47 | 63 |
| Burns (2019) | 10.1016/j.ypmed.2019.105756 | 18 | 15 | - |
| Figueroa et al. (2019) | 10.1017/S136898001800383X | 17 | 13 | - |
| Lee et al. (2021) | 10.1007/s10826-021-01906-6 | 2 | 1 | 2 |
| Ferraris et al. (2022) | 10.1037/fam0001009 | 19 | 13 | 16 |
| Fu et al. (2025) | 10.18122/ijpah.4.1.3.boisestate | 0 | unavailable | - |
| Wickham and Knee (2012) | 10.1177/1088868312447897 | 93 | - | - |
| Kenny, Ackerman, and Kashy (2024) | 10.1017/9781009170123.024 | 0 | - | - |
| Cavalcanti et al. (2026), v1 | 10.21203/rs.3.rs-9910824/v1 | 0 | - | - |

The six applied seeds returned **127 OpenAlex citation links, representing 120
distinct OpenAlex IDs**. These IDs still include publication/preprint versions
and metadata anomalies, so 120 is not a deduplicated study count. Wickham and Knee
had a seed-level cited-by count of 95, but paging returned 93 records (73 with
abstracts); the retrieved count is reported. Dwyer's list includes an anomalous
2007 cardiology record. Index discrepancies and zero results do not establish
absence of citations.

The [metadata inventory](citation-audit-2026-09-13.json) preserves 390 citation
links across the queried indexes, seed relationships, rerun URLs/recipes,
record-level screening where available, and finding-level decisions. It omits
abstracts and third-party full texts.

### Reproducible lookup recipes

- OpenAlex: resolve `https://api.openalex.org/works/https://doi.org/<DOI>`, then
  query `https://api.openalex.org/works?filter=cites:<work-ID>&per-page=200`.
  Page through results if required; compare the returned count with the seed's
  cited-by metadata. Dwyer's work ID is `W2614813112`, Lee's `W3128399583`,
  Ferraris's `W4283017880`, and Wickham and Knee's `W2148498945`.
- Europe PMC: resolve DOI to PMID, then query
  `https://www.ebi.ac.uk/europepmc/webservices/rest/MED/<PMID>/citations?page=1&pageSize=1000&format=json`.
  PMIDs were Dwyer `28526363`, Burns `31226343`, Figueroa `30741132`,
  Lee `42131382`, and Ferraris `35708955`.
- Semantic Scholar: query
  `https://api.semanticscholar.org/graph/v1/paper/DOI:<DOI>/citations?fields=title,year,externalIds&limit=1000`.
  The Dwyer, Lee, and Ferraris responses had no next page.
- Supplement with exact-title and distinctive-phrase searches combining
  APIM/actor-partner/dyadic with `path tracing`, `path-tracing`,
  `partition of nonindependence`, `explained nonindependence`,
  `percent of interdependence`, `actor-driven`, `partner-driven`,
  `caregiver-driven`, `covariance explained`, and `covariance decomposition`.

## Verified citation paths

- **Kline (2016) -> Dwyer (2017):** Dwyer's path-tracing sentence cites reference
  39, Kline's *Principles and Practice of Structural Equation Modeling*, fourth
  edition. The APIM calculation uses unstandardized estimates from the final
  model and a controls-only model. This verifies a general methods citation;
  it does not establish that Kline contains the APIM-specific partition.
  [Dwyer full text](https://pmc.ncbi.nlm.nih.gov/articles/PMC5512865/).
- **Dwyer (2017) -> Lee (2021):** the methods explicitly attribute the
  percent-interdependence/path-tracing calculation to Dwyer.
  [Lee full text](https://pmc.ncbi.nlm.nih.gov/articles/PMC13166139/).
- **Dwyer (2017) -> Ferraris (2022):** the methods explicitly cite Dwyer for the
  four contributions; Appendix A supplies calculations.
  [Ferraris primary PDF](https://pure.rug.nl/ws/files/589396899/ContentServer_1_.pdf).
- **Bolger-Laurenceau webinar and Kenny tracing rules -> Figueroa (2019):**
  these are the procedural citations in the decomposition paragraph. Figueroa
  also cites Dwyer, but that bibliographic link should not replace the actual
  attribution in its methods.
  [Figueroa publisher text](https://www.cambridge.org/core/journals/public-health-nutrition/article/autonomous-motivation-sugarsweetened-beverage-consumption-and-healthy-beverage-intake-in-us-families-differences-between-motheradolescent-and-fatheradolescent-dyads/996911DB9DB7DDBFD8EE95590F8FF06D).

## Additions and what they establish

### De Padova et al. (2021): applied grouped partition, signed and cross-predictor terms

*Post-traumatic stress symptoms in long-term disease-free cancer survivors and
their family caregivers*. **Cancer Medicine, 10**(12), 3974-3985.
[DOI](https://doi.org/10.1002/cam4.3961).

Discovered through the Kenny/APIM_MM method-phrase search, then verified in the
article and the supplementary **Output of APIM models**. Each of its four model
sections contains **Table 5: Partition of Nonindependence**. The rows below are
transcribed as reported; rounding can prevent displayed amounts from summing
exactly.

| Model | Grouped A&P effects | Predictor-correlation component | Cross-predictor component |
|:--|--:|--:|--:|
| Depression -> avoidance | -.007 (-2.15%) | .013 (3.84%) | - |
| Depression -> intrusion | .037 (11.02%) | .014 (4.15%) | - |
| Depression -> anxiety/arousal | -.013 (-9.47%) | .119 (87.40%) | - |
| Intrusion and anxiety -> avoidance | .052 (18.16%) | .134 (46.77%) | -.006 (-2.12%) |

The -.006 cross-predictor component is labelled **Correlation between the Mixed
Variables** in the source. These tables establish published grouped attribution, signed quantities,
and a reported cross-predictor component. They do not provide four elementary
route rows or contribution confidence intervals. Other tables contain slope and
`k` intervals. This inspection verifies reporting, not the correctness of every
calculation or current APIM_MM code.

For the third model, the main text calls .106 the overall correlation, whereas
the supplement gives .137 overall and .106 due to the APIM. Use the table's
labels explicitly if reproducing it; do not silently reconcile the discrepancy.

[Public supplementary package](https://www.ebi.ac.uk/europepmc/webservices/rest/PMC8209622/supplementaryFiles)
| [Local supplement](../references/explaining-interdependence-apim/2021-de-padova-et-al-apim-supplement.docx).

### Velten and Margraf (2017): total APIM and covariate attribution

*Satisfaction guaranteed? How individual, partner, and relationship factors
impact sexual satisfaction within partnerships*. **PLOS ONE, 12**(2), e0172855.
[Primary full text](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0172855).

Discovered through searches for APIM nonindependence explained. The Results,
Actor-partner-interdependence model section, reports 53.7% explained by the APIM
and 27.8% by between-dyad covariates. Methods identify APIM_MM. The supplement
S2 Table contains slope estimates, not the elementary partition. Retain as
total/grouped explanation, without inferring the precise denominator from the
reported percentages.
[Local S2 Table](../references/explaining-interdependence-apim/2017-velten-margraf-s2.docx).

### Burns (2020): additional abstract, same analysis

*Enjoyment, Self-Efficacy, and Physical Activity Within Parent-Adolescent Dyads*,
in **Peer-Reviewed Abstracts**, *Research Quarterly for Exercise and Sport,
91*(sup1). [Publisher abstract collection](https://www.tandfonline.com/doi/full/10.1080/02701367.2020.1761754).

Exact-title/term searching located indexed publisher text naming Ryan D. Burns
and reporting 1,854 FLASHE dyads and the same member-/actor-driven contribution
ranges as Burns (2019). Treat as another report of that analysis, not an
independent application. The individual page was not verified because direct
PDF downloads failed. The full-issue DOI 10.1080/02701367.2020.1773156 is a
duplicate container, not another study.

### Kline (2016): omitted general methods reference

Kline, R. B. (2016). *Principles and practice of structural equation modeling*
(4th ed.). Guilford Press. Dwyer's reference 39 directly supports the attribution
above; no APIM-specific content in the book was newly verified.

## Selected full-text screening and exclusions

These decisions concern the inspected versions and passages. They should not be
expanded into claims that a source never mentions the method anywhere.

| Candidate | Route to candidate | Decision from inspected text |
|:--|:--|:--|
| [Fleary and Joseph, health literacy](https://pmc.ncbi.nlm.nih.gov/articles/PMC10013691/) | Dwyer cited-by | Ordinary APIM; no focal partition located |
| [Lwin et al. (2025), sugar-sweetened beverages](https://pmc.ncbi.nlm.nih.gov/articles/PMC12332451/) | Dwyer cited-by | APIM/MEDYAD path effects; no focal partition located |
| [Supapannachart et al., tanning](https://pmc.ncbi.nlm.nih.gov/articles/PMC8483562/) | Dwyer cited-by | APIM coefficients/correlations; no focal partition located |
| [Endrighi et al. (2024), tooth brushing](https://pmc.ncbi.nlm.nih.gov/articles/PMC13016679/) | Dwyer cited-by | Random-intercept cross-lagged within/between decomposition has a different target |
| [Joyal-Desmarais et al. (2019)](https://eprints.whiterose.ac.uk/id/eprint/204140/1/dyadicTPB.preprint.pdf) | Dwyer cited-by | Dyadic TPB/direct/indirect effects; no focal partition located |
| [Lenne et al. (2019)](https://eprints.whiterose.ac.uk/204141/1/moderation.dyadicTPB.preprint%20.pdf) | Dwyer cited-by | Parenting moderation/interpersonal effects; no focal partition located |
| [Holding et al. (2024)](https://selfdeterminationtheory.org/wp-content/uploads/2024/05/2024_HoldingLavigneEtAl_Appetite.pdf) | Dwyer cited-by | Dyadic mediation; no focal partition located |
| [Lucas et al. (2021)](https://pmc.ncbi.nlm.nih.gov/articles/PMC8595559/) | Burns cited-by | Latent-variable SEM coefficients and R-squared; no focal partition located |
| [Dog and Guardian Relationships (2025)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12109308/) | Burns cited-by | APIM paths/outcome correlations; no focal partition located |
| [Farina et al. (2024)](https://pure.plymouth.ac.uk/ws/portalfiles/portal/49382062/2024_Farina_et_al._JAPA_Physical_activity_patterns_AC_.pdf) | Burns cited-by | Dyadic physical-activity correlations/general APIM citation |
| [Chen et al. (2023)](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2023.1238924/full) | Ferraris cited-by | APIM mediation; inspected methods/results do not give the focal partition |
| [Yang et al. (2023)](https://www.frontiersin.org/journals/psychiatry/articles/10.3389/fpsyt.2023.1242611/full) | Ferraris cited-by | Latent classes plus ordinary APIM coefficients; no focal partition located |
| [Together, but Isolated (2025)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12593241/) | Ferraris cited-by | Longitudinal APIM actor/partner effects; no focal partition located |
| [Andrews (2022), Trust in Common Ground](https://escholarship.org/uc/item/2gd656zz) | Actor-actor/partner-partner phrase search | Printed p. 10 uses these terms for moderation; results pp. 17-19 concern regression/repeated-measures APIM. Terminology false positive |

Lee's two forward citations were screened at title/abstract level: Jones et al.
(2023), DOI 10.1111/jmft.12662, uses latent mediation involving adolescent
outcomes; Esparza et al. (2024), DOI 10.1177/21676968241277235, uses surveys of
869 emerging adults. Neither abstract establishes use of the partition. Their
full texts were not available for blanket exclusion.

## Unresolved candidates and retrieval priorities

The following are leads, not additional confirmed applications:

1. [Park and Park (2024)](https://doi.org/10.1111/ijpo.13153), motivations and
   dietary behaviours within parent-adolescent dyads. Dwyer forward citation;
   relevant full text unavailable.
2. [Park and Park (2025)](https://doi.org/10.1016/j.appet.2025.107872),
   self-efficacy, motivation, and dietary behaviors with APIM mediation.
   Dwyer forward citation; publisher preview only.
3. [Niu et al. (2026)](https://doi.org/10.1016/j.jadohealth.2026.01.016),
   motivational factors/dietary behaviors and family meal structure.
   Dwyer forward citation; abstract/preview only.
4. [Welch et al. (2019)](https://doi.org/10.1007/s10865-019-00041-4),
   social support, loneliness, eating, and activity. Dwyer forward citation;
   relevant full text unavailable.
5. [Vu et al. (2026)](https://doi.org/10.1123/jpah.2025-0490), acculturation and
   physical activity among South Asian mother-daughter dyads. Burns forward
   citation; abstract establishes APIM in 126 dyads, full text unavailable.
6. [Lu et al. (2022)](https://doi.org/10.1007/s10826-022-02241-0), mobile media
   and food consumption. Dwyer forward citation; publisher preview only.
7. [Niermann et al.](https://doi.org/10.1080/13229400.2020.1773901),
   parent/child self-efficacy and support. Dwyer forward citation; preview only.
8. [Kim and Chae](https://doi.org/10.1111/jan.16474), family strengths,
   depression, and life satisfaction. Ferraris forward citation; abstract
   supports APIM mediation, full text unavailable.
9. [Thai thesis, 2022](https://doi.org/10.58837/chula.the.2022.540), social
   support/positive experience/well-being in older cancer patient-caregiver
   dyads. Ferraris forward citation; abstract screened, relevant full-text
   calculation unverified.

Also still needed: Dwyer's calculation supplement
`NIHMS868627-supplement.pdf` and the full Kenny-Ackerman-Kashy (2024) chapter.
The current Dwyer link returns a browser challenge, not a valid PDF. The 2006
Kenny-Kashy-Cook book's printed p. 146 is a targeted lead for a four-term formula
seen in third-party indexed text, but that page was not verified from a primary
copy and is not counted as new confirmed evidence.

Kenny's [official PowerPoint index](https://davidakenny.net/webinars/listpp.htm)
links the [standard APIM deck](https://davidakenny.net/webinars/powerpoints/Dyad/Standard/APIM.ppt).
A third-party mirror shows four highlighted nonindependence routes, but the
primary PPT download failed. Its content/date remain a provenance check, not
evidence of a verified publication date.

## Implications for the manuscript

De Padova provides applied evidence that grouped signed and cross-predictor
attribution predates the proposed paper. These should be treated as established
reporting precedents. The defensible contribution remains clearer estimands,
explicit elementary-route mapping, validated uncertainty, and reproducible
implementation. No contribution-specific intervals were found in the new
partition tables, but that remains a bounded observation rather than a claim
that such inference has never been proposed.

The audit covers public indexes and accessible primary texts. It is not a
Scopus/Web of Science/PsycINFO systematic review, and incidental mentions hidden
in unavailable full texts or supplements can still have been missed. Newly found
sources received narrow follow-up searches, not complete recursive citation
harvests. The next useful step is targeted full-text/supplement retrieval for the
unresolved candidates above, rather than another undifferentiated APIM search.
