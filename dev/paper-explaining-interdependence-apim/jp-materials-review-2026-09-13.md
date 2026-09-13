# J-P's supplied materials: fit with the APIM decomposition review

Inspected **13 September 2026**. Source: the user-supplied
`Relevant Papers and Resources.zip` (13 files). Extracted copies are under
`dev/references/explaining-interdependence-apim/jp-materials-2026-09-13/`, which
is Git-ignored. Source programs were read as evidence, not executed or modified.
Numerical reconstruction below uses the stored Mplus output, not a new model fit.

## Main implications

1. **The full 2024 Kenny-Ackerman-Kashy chapter closes a major retrieval gap.**
   It is a direct, substantial published methods treatment, including several
   predictors and covariates, and belongs among Paper 1's central citations.
2. **The highlighted DOCX is a draft of the chapter, not an independent 2019
   methods publication.** Prefer the published chapter for citations and formulas.
3. **The 2025 workshop handouts and analysis files form a matched teaching
   example.** They are useful for an initial replication/calculation example.
   They use self-efficacy, whereas Dwyer uses autonomous motivation.
4. **No four-product contribution-inference procedure is supplied.** Parameter
   intervals, residual-covariance intervals, and coefficient contrasts are
   present, but no intervals for the four derived routes or their percentages.
5. **The chapter teaches ILD separately; no partition of actor/partner routes at
   both temporal levels is demonstrated.** It explicitly excludes nonnormal
   outcome errors. The basic chapter partition example is two-wave, so the
   method's existing illustrations are not confined to strictly cross-sectional data.

## File inventory and roles

| Supplied material | Fit with the existing review |
|:--|:--|
| [2024 published chapter](../references/explaining-interdependence-apim/jp-materials-2026-09-13/Kenny-et-al-2024-Ch23-The-design-and-analysis-of-data-from-dyads-and-groups.pdf) | Previously abstract-only; now direct full-text evidence. Promote to core methods citation. |
| [Highlighted chapter draft](../references/explaining-interdependence-apim/jp-materials-2026-09-13/Kenny-AnalysisOfDyads&GroupsSept19-highlighted.docx) | Highlights identify the basic partition section. Version differs from the published chapter; do not count twice. |
| [APIM_MM manual](../references/explaining-interdependence-apim/jp-materials-2026-09-13/Kenny-2019-APIM_MM.pdf) | Byte-identical to the manual already in our reference folder. Confirms the same software precedent. |
| [Dwyer PDF](../references/explaining-interdependence-apim/jp-materials-2026-09-13/dwyer-et-al-2017.pdf) | Nine-page published article, pp. 863-871; matches the existing application. The separate calculation supplement is not included. |
| [Workshop Day 1](../references/explaining-interdependence-apim/jp-materials-2026-09-13/J-P&Niall-FLASHE-example/UMass-Dyadic-Data-Analysis-Workshop-July2025-Day1-handout.pdf) | Model specification, data, R/Mplus, Monte Carlo power, and ordinary parameter/contrast inference. |
| [Workshop Day 2](../references/explaining-interdependence-apim/jp-materials-2026-09-13/J-P&Niall-FLASHE-example/UMass-Dyadic-Data-Analysis-Workshop-July2025-Day2-handout.pdf) | Explicit path tracing, covariance products, denominator, and percentage table. |
| [R script](../references/explaining-interdependence-apim/jp-materials-2026-09-13/J-P&Niall-FLASHE-example/apm-eff-fv.R), [Mplus input](../references/explaining-interdependence-apim/jp-materials-2026-09-13/J-P&Niall-FLASHE-example/apim-eff-fv.inp), [stored output](../references/explaining-interdependence-apim/jp-materials-2026-09-13/J-P&Niall-FLASHE-example/apim-eff-fv.out) | Fit the teaching APIM and contrasts. They provide inputs for the four-product calculation but do not implement it as derived parameters. |
| `flashesmall.csv`, `flashe-lavaan.csv` | Identical numeric 1,486-by-8 matrices, with header/name differences for the two programs. One row per dyad, no temporal panel. |
| `apim-eff-fv.dgm`, `apim-eff-fv.gh5` | Mplus diagram and plot/data artifacts, not additional studies or statistical methods. GH5 signature/readable metadata inspected; no full binary-data audit. |

Count the two workshop handouts together as one resource entry, bringing the
main annotated list from 50 to **51**. Do not count the draft, duplicate manual,
code, or two data formats as independent publications or applications.

## Published chapter: what is now verified

**Kenny, Ackerman, and Kashy (2024), Section 23.5, pp. 577-580** explicitly
presents the partition of nonindependence. It credits **Kenny (2015, APIM_MM)**
and **Dwyer et al. (2017)**. The 2015 reference is to software, not a new journal
paper; our 2019 manual is a later documentation version.

- **Basic case, Equations 23.15-23.18:** standardized distinguishable and
  indistinguishable APIMs. Four explained-correlation products are grouped into
  common-cause/spuriousness and correlated-predictor contributions. Negative
  contributions are explicitly acknowledged.
- **Complex case, Section 23.5.2 and Table 23.3:** two mixed predictors measured
  for both members and two shared covariates. Six groups include same-construct,
  cross-predictor, covariate, and predictor-covariate covariance terms.
- **Table 23.4:** a numerical example with negative cross-predictor and covariate
  contributions. Multiple-predictor and covariate partitioning are therefore
  already explicitly treated in published methods work.
- **No four-product contribution-inference recipe:** Section 23.5 gives no
  contribution SEs, intervals, bootstrap procedure, or calibrated testing method.

The basic numerical illustration uses commitment at Time 1 to predict anxious
attachment **18 months later**, with reported outcome correlation .231 and
explained part .058 (25%). This is an ordinary APIM with temporally separated
predictors/outcomes, not intensive longitudinal within/between route attribution.
Its use of Acitelli et al.'s earlier data does not establish that the original
data source performed this partition. Chapter-linked partition materials:
[OSF zt9s6](https://osf.io/zt9s6); linked files not inspected in this pass.

**Section 23.6.3, pp. 585-588**, separately specifies longitudinal APIMs with
within-/between-person effects, random intercepts/slopes, and residual
covariance. The example uses 103 couples and 14 diary days. It reports covariance
parameters at different levels, but does not apply the Section 23.5 route
partition at each level. The separate ILD materials are linked at
[OSF 7w3my](https://osf.io/7w3my); linked files not inspected here.

**Page 566 excludes nonnormal outcome errors**, including dichotomous, ordinal,
and count outcomes. Thus this chapter does not establish a generalized-link
response-scale partition.

### Draft and transcription details

The DOCX's `Sept19` filename does not establish 2019: the draft cites 2022 work.
The supplied copy has August 2026 metadata; original drafting date is unknown.
Its author order differs from the publication. Cyan highlights cover the basic
partition, and no comments or tracked insertions/deletions were found. The draft
excludes over-time analyses; the published chapter adds the longitudinal section.

Several complex-case indexes were corrected between draft Table 3 and published
Table 23.3. For example, correlated-covariate products are
`c11*c22 + c21*c12` in the publication, versus the draft's erroneous
`c11*c12 + c21*c22`. Use published formulas, checking the member/variable indexing.

Three issues in the published chapter were also checked against the page images:

- Figure 23.2 prints residual correlation **-.184**. Its displayed inputs and
  positive total correlation imply approximately **+.18421**; the sign appears
  erroneous.
- Table 23.4 places **-5.3%** one row too low. It belongs with the **-.012
  cross-predictor** component, as confirmed by the draft table and arithmetic.
- Equation 23.33 repeats an earlier outcome-lag equation; the within/between-X
  specification follows in Equations 23.34-23.35.

These are reasons to check a transcription, not reasons to discount the methods
precedent. Preserve the source originals; no corrections were made to them.

## Workshop and supplied fit: what can be reproduced from the materials

Citation: **Bolger, N., & Laurenceau, J.-P. (2025, July 7-11). Introduction to
dyadic data analysis [Day 1 and Day 2 workshop handouts]. UMass Amherst.**

Day 1 slide 5 (PDF p. 3) identifies the cross-sectional design; slide 15 (p. 8)
gives 1,486 complete dyads. Day 2 slides 10-14 (pp. 5-7) trace all four products
and residual covariance. Slide 15 (p. 8) reports the percentages below. Day 1
slide 63 (p. 32) lists extension to longitudinal data as a possible next step;
these handouts do not demonstrate an ILD or non-Gaussian route partition.

The supplied `.out` is a September 12, 2026 Mplus 9.1 run of the **self-efficacy
to fruit/vegetable intake** APIM, N = 1,486, ML, four continuous modeled
variables, no demographic controls. The two outcomes' observed covariance is
1.366 and correlation .488. The 14-parameter model is saturated (df = 0).

Using rounded unstandardized output coefficients and predictor moments:

| Route | Product | Covariance contribution | % of displayed covariance 1.366 |
|:--|:--|--:|--:|
| Actor-driven | .258 x .168 x 1.672 | .072471 | 5.31 |
| Partner-driven | .063 x .076 x 1.672 | .008006 | .59 |
| Teen-driven | .258 x .076 x 7.437 | .145825 | 10.68 |
| Parent-driven | .168 x .063 x 8.795 | .093086 | 6.81 |
| Four-route total | Sum | .319388 | 23.38 |
| Residual | Stored fitted covariance | 1.047 | 76.65 |

The sum is 1.366388 rather than 1.366 because output parameters are rounded.
Day 2 reports 5.3%, .6%, 10.7%, 6.8%, and 76.6%. The denominator is total outcome
covariance, not the residual covariance or residual correlation.

The 2016 webinar uses the same self-efficacy teaching example and N = 1,486,
but computes from coarser rounded standardized coefficients, reporting about
24%. This is consistent with rounding/presentation differences from 23.4%; it
does not establish a different analysis population. **Dwyer's 22.6% concerns
autonomous motivation, N = 1,443, with demographic controls.** Keep those analyses
and their numeric results separate.

### Inference already supplied, and what is still missing

Mplus `MODEL CONSTRAINT` defines actor-effect, partner-effect, and intercept
differences only (`.inp` lines 29-33); there are no four-route definitions.
The R script similarly has no covariance-route `:=` quantities. The stored
output provides intervals for ordinary fitted parameters, including raw residual
covariance, and the three contrasts. It does not provide SEs/CIs for the four
product-derived contributions or the normalized percentages. The Day 1 Monte
Carlo exercise concerns those model parameters/contrasts, not the four products.

Two differences matter if these scripts later become a replication baseline:
Mplus's `MEANTEST` tests an intercept difference; the R script's corresponding
third Wald test instead tests the average intercept against zero. Also, no full
parameter covariance matrix (`TECH3`) is requested in the stored output, so
marginal coefficient intervals alone cannot reconstruct a joint delta-method
interval for each product. These observations do not require changes to the
source programs for the present literature-review task.

## Consequences for the manuscript

- Put **Kenny, Ackerman, and Kashy (2024)** alongside Dwyer as a central
  published citation, with the workshop/manual supplying implementation and
  teaching provenance.
- Use the **2025 self-efficacy example** as a candidate initial calculation
  benchmark; extending its R/Mplus model to define contributions and assess
  their uncertainty would be new work here, not something already delivered.
- The planned contribution should emphasize target/denominator clarity,
  inferential validation and reproducible reporting. Basic, signed,
  multiple-predictor and covariate partitions already have substantive prior art.
- Keep the distinction between ordinary cross-sectional/two-wave APIM,
  level-specific ILD models, and generalized observed-outcome attribution. The
  supplied bundle does not resolve the latter two route-attribution questions.
- **Still missing:** Dwyer's separate calculation supplement, checks of the two
  chapter-linked OSF projects, and the unresolved citing papers in the main review.
