# APIM covariance decomposition: literature

Master list, 9 October 2026. Topic: splitting the covariance between
partners' outcomes into actor and partner routes plus residual covariance
("explained nonindependence"). Cross-sectional and intensive longitudinal
data (ILD).

This list merges the earlier review on `apim-manuscript`
(`dev/paper-explaining-interdependence-apim/literature-review.md`, 51 sources,
now in git history) with a new search on 8–9 October. Only relevant sources are listed.
Sources marked **new** were not in the earlier review. On 10 October 2026
the list was moved into the repo and merged with the older notes (the
earlier review, its audits and the citation map), which are now in git
history.

## Bottom line

- **Teaching.** The four routes are taught almost only in Kenny's and
  Bolger/Laurenceau's materials. New are Kenny's 2013 webinar slides (route
  diagrams, no formulas), a 2022 course text from Arizona and the FLASHE
  webinar Q&A. Two applied papers cite **Kenny, Kashy & Cook (2006), p. 146**
  for the formula. A Google Books snippet of p. 146 shows a passage on
  "the nonindependence not explained by the APIM", so the printed book has
  at least the idea. The full page is still unchecked.
- **ILD.** No source applies the route decomposition at the within level,
  the between level or both. The closest sources fit a two-level APIM and
  report the partner covariance at both levels, but do not explain it
  (Gistelinck & Loeys 2019, 2020; Cornelius et al. 2022). Others split the
  partner dependence by level without predictors (Bolger & Shrout 2007;
  DiGiovanni et al. 2023; Schönbrodt et al. 2022). Laurenceau, DiGiovanni &
  Bolger (2026) list dyadic ILD models as future work. The final gap check
  rates "nothing at both levels" as well supported (about 85–90%). "Nothing
  even at one level" is less certain (75–85%), mainly because of
  closed-access journals.
- **Applications.** Six papers report the four routes, all cross-sectional.
  New are two friendship papers with a lagged APIM over two or three waves
  that report the total share explained (Popp et al. 2008, the earliest
  application found; Giletta et al. 2011), and two dissertations that report
  the APIM_MM partition. No ILD application was found. No application gives
  CIs for the contributions. Intervals exist only for other quantities:
  paths (Burns 2019; Lee et al. 2021, 5,000 bootstrap resamples), the k
  ratio (APIM_MM, Monte Carlo), mediation (Fu et al. 2025, Sobel), the raw
  residual covariance (the 2025 workshop's Mplus fit) and the level
  covariance parameters (Gistelinck & Loeys 2019), but not their 89%/11%
  level shares. No public study-specific decomposition code was found
  (checked 7 October for the 2a papers, De Padova, Velten & Margraf and
  Cavalcanti); Ferraris et al. (2022) offer code on request.

Columns: **ILD** = yes (intensive longitudinal, within/between levels),
partial (panel or repeated waves, no within/between split) or no.

## List 1: Teaching and methods resources

### 1a. Sources that teach the decomposition

| Source | DOI or link | Summary | ILD | Main contribution |
|:--|:--|:--|:--|:--|
| Kenny, Kashy & Cook (2006). *Dyadic data analysis*, ch. 7, p. 146. Guilford. **New lead.** | No DOI. ISBN 9781572309869 | Snippet only. Popp et al. (2008) and Giletta et al. (2011) cite p. 146 for the formula of the share explained by actor and partner paths. The p. 146 snippet mentions "the nonindependence not explained by the APIM". Ch. 13 (p. 344) uses "explained" only for autocorrelation. | no | Probably the first printed formula (correlation units). Check the full page in the UZH library. |
| Kenny (2013). *Actor-partner interdependence model* [webinar slides], slides 11–15. **New.** | [davidakenny.net](https://davidakenny.net/webinars/powerpoints/Dyad/Standard/APIM.ppt) | Patient–spouse example. One diagram per route; no formulas, numbers or residual share. | no | Earliest dated teaching of the four routes found. |
| Kenny (n.d., online by 2017). *Explained nonindependence* [handout]. | [davidakenny.net](https://davidakenny.net/kkc/c7/Explained_Nonindependence.docx) | Four route diagrams with formulas; worked example (.290 of r = .618 explained). | no | Formulas for distinguishable and exchangeable dyads; covariates. |
| Kenny (2016, 2019). *APIM_MM* [manual]. | [2019](https://davidakenny.net/doc/APIM_MM.pdf); [2016, Wayback](http://web.archive.org/web/20161207212246/http://davidakenny.net/doc/APIM_MM.pdf) | App output splits nonindependence into up to seven grouped parts, including covariates and negative parts. The 2016 version calls this "unique to APIM_MM". | no | Software; multiple predictors and covariates; grouped parts, not four separate routes. |
| Bolger & Laurenceau (2016). FLASHE webinar, with Q&A **(new)** and user guide **(new)**. | [webinar](https://cancercontrol.cancer.gov/sites/default/files/2020-06/flashe-webinar-2.5.2016.pdf); [Q&A](https://cancercontrol.cancer.gov/sites/default/files/2020-06/qanda-flashe.pdf); [guide](https://cancercontrol.cancer.gov/sites/default/files/2022-08/FLASHE%20Dyadic%20Analysis%20Users%20Guide%20_%20PUF%20508C.pdf) | Self-efficacy and fruit/vegetable intake; four standardized routes plus residual. The Q&A says to use the full, untrimmed model and to fit both outcomes together. The SAS/Mplus guide fits the APIM but does not compute the routes. | no | First worked numerical teaching example; practical advice. |
| Bolger & Laurenceau (2025, 2026). Dyadic workshops: UMass 2025 and 2026, Zurich 2–4 June 2026 **(new)**. | [UMass 2026 listing](https://www.umass.edu/family/events/introduction-dyadic-data-analysis-2026-virtual-workshop); Zurich notes in `~/Downloads/Literatur zum Ordnen Stats/` | UMass: same FLASHE example with R/Mplus files; the 2026 listing names "decomposition of interdependence effects in APIM". Zurich Day 2, slide 48: "use path tracing to partition the dyadic covariance" as a next step, not worked through. | no | Current teaching; no CIs for the contributions. |
| Wickham & Knee (2012). *Personality and Social Psychology Review*. | [10.1177/1088868312447897](https://doi.org/10.1177/1088868312447897) | Interdependence theory and the APIM; compare the outcome covariance before and after the predictors. | no | Theoretical reason to report the total explained part. |
| Bonito (2022). *Comm 640 class notes*, section 10.3. University of Arizona. **New.** | [course text](https://commresearch.arizona.edu/classes/comm640/640_Book/docs/the-actor-partner-interdependence-model-apim.html) | Prints the four-term formula in correlation units and the exchangeable case 2ap + r(a² + p²). No numbers. | no | Only course text found outside the Kenny and Bolger/Laurenceau materials. |
| Kenny, Ackerman & Kashy (2024). Handbook chapter 23, section 23.5, pp. 577–580. | [10.1017/9781009170123.024](https://doi.org/10.1017/9781009170123.024); OSF: [partition](https://osf.io/zt9s6/), [longitudinal](https://osf.io/7w3my/) | Four routes plus residual for distinguishable and exchangeable dyads; two-wave example. Tables 23.3–23.4 add multiple predictors, covariates and cross-terms. The partition OSF output gives grouped, signed parts, including covariate and cross-predictor terms, without CIs. | partial | Published methods reference; multiple predictors, covariates. Its ILD section has no partition (23.6.3, pp. 585–588; 103 couples, 14 days; the longitudinal OSF code fits within/between effects and random slopes, with no partition at either level). p. 566 excludes non-normal outcomes (binary, ordinal, count). Errata below. |

**Errata in Kenny, Ackerman & Kashy (2024).** Three errors in the published
chapter, checked against the page images, and one in the draft:

- Figure 23.2 prints the residual correlation as −.184; its inputs imply
  about +.184.
- Table 23.4 puts −5.3% one row too low; it belongs to the −.012
  cross-predictor part.
- Equation 23.33 repeats an earlier outcome-lag equation; the
  within/between equations follow in 23.34–23.35.
- The highlighted draft from J-P has wrong indices for correlated covariates
  (c11·c12 + c21·c22). Published Table 23.3 has the correct
  c11·c22 + c21·c12.

### 1b. General path tracing cited by the applications, and related decompositions

| Source | DOI or link | Summary | ILD | Main contribution |
|:--|:--|:--|:--|:--|
| Kenny (n.d.). *Path tracing* [web page]. | [davidakenny.net](https://davidakenny.net/cm/tracing.htm) | General rules for getting covariances from paths. Figueroa et al. (2019) cite it for their decomposition. | no | Method source used by applications. |
| Kline (2016). *Principles and practice of structural equation modeling* (4th ed.). Guilford. | No DOI. ISBN 9781462523344 | Dwyer et al. (2017) cite it for path tracing. APIM content not checked. | no | Method source used by applications. |
| Boker, McArdle & Neale (2002). *Structural Equation Modeling*. | [10.1207/S15328007SEM0902_2](https://doi.org/10.1207/S15328007SEM0902_2) | Algorithm to list all paths and compute the components of an expected covariance. | no | General version of the decomposition for any SEM. |
| Zhang, Hamagami, Grimm & McArdle (2015). *Structural Equation Modeling*. | [10.1080/10705511.2014.935257](https://doi.org/10.1080/10705511.2014.935257) | R package RAMpath: traces paths and computes covariance components. | no | Software precedent for automatic path tracing. |
| Jones & West (2005). *Biometrika*, 92(4), 779–786. | [10.1093/biomet/92.4.779](https://doi.org/10.1093/biomet/92.4.779) | Signed path-weight decomposition of covariances in undirected Gaussian graphical models. | no | General prior art for signed, additive covariance parts; a different model class. |
| Griffin & Gonzalez (1995). *Psychological Bulletin*. | [10.1037/0033-2909.118.3.430](https://doi.org/10.1037/0033-2909.118.3.430) | Exchangeable dyads. Path-traces correlations into individual-level and dyad-level parts (p. 433). | no | Older decomposition of a different target (individual vs dyad level). |
| Gonzalez & Griffin (1999). *Personal Relationships*. | [10.1111/j.1475-6811.1999.tb00203.x](https://doi.org/10.1111/j.1475-6811.1999.tb00203.x) | Same for distinguishable dyads (Eq. 3, p. 457). | no | As above, distinguishable case. |
| Gonzalez & Siarkiewicz (2006). *Nowiny Psychologiczne* (Polish). | No DOI. [author's PDF](https://websites.umich.edu/~gonzo/papers/Gonzalez-polish.pdf) | 74 couples; trust and marital satisfaction split into individual and dyad correlations. | no | Applied example of the individual/dyad split. |
| Iida, Seidman & Shrout (2018). *Journal of Social and Personal Relationships*. | [10.1177/0265407517725407](https://doi.org/10.1177/0265407517725407) | Where partner correlations come from: influence, common cause, dyadic contrast. APIM vs common fate vs dyadic score model. Cross-sectional data. | no | Conceptual sources of partner correlation. |

### 1c. ILD methods closest to the question (none applies the routes)

| Source | DOI or link | Summary | ILD | Main contribution |
|:--|:--|:--|:--|:--|
| Bolger & Shrout (2007). Chapter in Little, Bovaird & Card (Eds.), *Modeling contextual effects in longitudinal studies*, pp. 285–298. | No DOI. ISBN 9780805850192; [author manuscript](https://www.columbia.edu/~nb2229/docs/Bolger%20and%20Shrout-Accounting%20for%20Statistical%20Dependency%20May%202005.pdf) | Couples' diary data. The modelled same-day partner correlation is 75% daily and 25% person-level (manuscript p. 13). No actor/partner effects. | yes | First level split of partner dependence. |
| Gistelinck & Loeys (2019). *Structural Equation Modeling*. | [10.1080/10705511.2018.1527223](https://doi.org/10.1080/10705511.2018.1527223) | L-APIM with time-averaged and time-specific actor/partner effects. 89% of the modelled same-day dependence is daily, 11% stable. | yes | Level split of residual dependence; ingredients for routes at both levels. |
| Gistelinck & Loeys (2020). *TPM*, 27(3), 433–452. **New.** | [10.4473/TPM27.3.7](https://doi.org/10.4473/TPM27.3.7) (mEDRA, not in Crossref) | Same model as a multilevel autoregressive SEM, with a Shiny app. Partner correlations .51 (stable) and .68 (daily), conditional on the predictors; no explained share. | yes | Closest set-up: a two-level APIM with partner covariance at both levels. |
| Savord, McNeish, Iida, Quiroz & Ha (2023). *Structural Equation Modeling*. | [10.1080/10705511.2022.2065279](https://doi.org/10.1080/10705511.2022.2065279) | L-APIM as a DSEM in Mplus, with random slopes and multiple outcomes; OSF code. No partition. | yes | The DSEM model an ILD extension would build on. |
| Laws et al. (2026). *Biological Psychology*. | [10.1016/j.biopsycho.2026.109259](https://doi.org/10.1016/j.biopsycho.2026.109259) | Two-level DSEM in which the within-dyad residual correlation varies across dyads; dyad traits predict it. No actor/partner routes. | yes | Heterogeneous within-level partner covariance. |
| DiGiovanni, Cornelius & Bolger (2023). *Social Psychological and Personality Science*. **New.** | [10.1177/19485506221116989](https://doi.org/10.1177/19485506221116989) | Co-rumination, 120 couples, 14 days. Couple-shared variance is 13.9% stable and 11.1% daily. No predictors; explaining the shared part is named as future work. | yes | Level split of couple-shared variance. |
| Schönbrodt et al. (2022). *Behavior Research Methods*. **New.** | [10.3758/s13428-021-01701-7](https://doi.org/10.3758/s13428-021-01701-7) | Experience sampling in couples. Couple-shared variance at stable, daily and momentary levels; no predictors. | yes | Level split of couple-shared variance (reliability model). |
| Helm et al. (2018). *Multivariate Behavioral Research*. **New.** | [10.1080/00273171.2018.1459292](https://doi.org/10.1080/00273171.2018.1459292) | Separates between-dyad trend synchrony from within-dyad concurrent and lagged synchrony. Warns that a raw partner correlation mixes them. | yes | Why partner covariance must be split by level. |
| Thorson, West & Mendes (2018). *Psychological Methods*. **New.** | [10.1037/met0000166](https://doi.org/10.1037/met0000166) | Guide to dyadic physiological influence models with within and between terms. No explained covariance. | yes | Within/between partner effects in ILD. |
| Ackerman & Kashy (2018). SPSP workshop slides. **New.** | [spsp.org](https://spsp.org/sites/default/files/Slides-An-Introduction-to-Longitudinal-Dyadic-Analyses.pdf) | Partner similarity in intercepts, slopes and occasion residuals. Calls the residual part similarity "in the part of Y that isn't explained by the predictors". Shows correlations before and after predictors but does not discuss the change. | yes | Teaches level-specific partner similarity. |
| Laurenceau & Bolger (2012). Chapter in Mehl & Conner (Eds.), *Handbook of research methods for studying daily life*, pp. 407–422. **New.** | No DOI. ISBN 9781609187477 | Snippets only: daily APIM with random intercepts and a day-level partner residual covariance (p. 417). p. 408 names shared experiences as a source of partner similarity. No explained share found. | yes | Main ILD dyad chapter by the webinar authors. |
| Sels, Ceulemans & Kuppens (2018). Chapter in *Interpersonal emotion dynamics in close relationships*. **New.** | [10.1017/9781316822944.004](https://doi.org/10.1017/9781316822944.004) | Same-moment covariation can come from partner influence or from shared environments. | yes | Conceptual: two sources of within-level covariation. |
| Laurenceau, DiGiovanni & Bolger (2026). *Annual Review of Psychology*. **New.** | [10.1146/annurev-psych-040325-025418](https://doi.org/10.1146/annurev-psych-040325-025418) | Review of ILD methods; lists dyad-specific ILD models as future work. | yes | Citable statement that the gap exists. |

## List 2: Applications

### 2a. Four routes reported separately (all cross-sectional)

| Source | DOI | Summary | ILD | Main contribution |
|:--|:--|:--|:--|:--|
| Dwyer et al. (2017). *American Journal of Preventive Medicine*. | [10.1016/j.amepre.2017.01.011](https://doi.org/10.1016/j.amepre.2017.01.011) | FLASHE. Autonomous motivation and fruit/vegetable intake; 22.6% of the parent–teen correlation explained. Strictly, the share is of the covariance left after the controls: the denominator is the controls-only model's outcome residual covariance (1.980), and the numerators use the final model's residual motivation moments. | no | First published four-route application; controls; formulas in the supplement. |
| Burns (2019). *Preventive Medicine*. | [10.1016/j.ypmed.2019.105756](https://doi.org/10.1016/j.ypmed.2019.105756) | FLASHE. Enjoyment, self-efficacy and physical activity; routes in correlation units and percent. | no | Two predictors; cross-predictor terms. |
| Figueroa et al. (2019). *Public Health Nutrition*. | [10.1017/S136898001800383X](https://doi.org/10.1017/S136898001800383X) | FLASHE. Motivation and beverage intake; explained shares by parent role. | no | Multigroup comparison of shares. |
| Lee et al. (2021). *Journal of Child and Family Studies*. | [10.1007/s10826-021-01906-6](https://doi.org/10.1007/s10826-021-01906-6) | Mother–daughter mental health and closeness. | no | Outside FLASHE; follows Dwyer. |
| Ferraris et al. (2022). *Journal of Family Psychology*. | [10.1037/fam0001009](https://doi.org/10.1037/fam0001009) | Social support and well-being; appendix prints the four formulas with numbers. The printed values give 29.24%, not the reported 28.76%, so it is not a replication target. | no | Formulas in an appendix. |
| Fu et al. (2025). *International Journal of Physical Activity and Health*. | [10.18122/ijpah.4.1.3.boisestate](https://doi.org/10.18122/ijpah.4.1.3.boisestate) | Parents' perceived health and child movement; four routes plus residual. | no | Mother–father dyads. |

### 2b. Total or grouped share explained

| Source | DOI | Summary | ILD | Main contribution |
|:--|:--|:--|:--|:--|
| Popp, Laursen, Kerr, Stattin & Burk (2008). *Developmental Psychology*. **New.** | [10.1037/0012-1649.44.4.1028](https://doi.org/10.1037/0012-1649.44.4.1028) | Swedish adolescent friends' intoxication, three yearly waves. Lagged APIM: actor = stability, partner = influence. 32–56% of the friends' later correlation explained. Formula in footnote 1, "adapted from Kenny et al., 2006, p. 146". | partial | Earliest application found; panel APIM; shares compared across groups. |
| Giletta et al. (2011). *Developmental Psychology*. **New.** | [10.1037/a0023872](https://doi.org/10.1037/a0023872) | Dutch adolescent friends' depressive symptoms, two waves, exchangeable dyads. Stability and influence explain 23% of later similarity (girls). | partial | Exchangeable dyads; replicates Popp's procedure. |
| Velten & Margraf (2017). *PLOS ONE*. | [10.1371/journal.pone.0172855](https://doi.org/10.1371/journal.pone.0172855) | Sexual satisfaction in couples (APIM_MM). The APIM explains 53.7% of the nonindependence, between-dyad covariates 27.8%. | no | Covariate share. |
| De Padova et al. (2021). *Cancer Medicine*. | [10.1002/cam4.3961](https://doi.org/10.1002/cam4.3961) | Cancer survivors and caregivers; APIM_MM tables in the supplement with grouped and negative parts. In model 3 the main text calls .106 the overall correlation; the supplement gives .137 overall and .106 due to the APIM. | no | Negative and cross-predictor parts. |
| Vadgama (2017). Doctoral dissertation, Syracuse University. **New.** | No DOI. [SURFACE](https://surface.syr.edu/etd/816); ProQuest 10682594 | 127 Asian-Indian immigrant couples; father involvement. APIM_MM partition: 66.75% of r = .54 explained; covariate share split out; pie chart. | no | Three predictors plus a covariate; pie-chart reporting. |
| Riccio (2020). Doctoral dissertation, New York University. **New.** | No DOI. ProQuest 27828980 | 128 roommate dyads (exchangeable); 52.8% of r = .20 explained, including a negative part (−19.8%). | no | Exchangeable dyads; negative component. |
| Jang (2016). Doctoral dissertation, Washington University in St. Louis. | [10.7936/K7B27SKT](https://doi.org/10.7936/K7B27SKT) | Negotiation dyads; 5.4% and 23.7% of the nonindependence explained (Study 5). | no | Total share only. |
| Cavalcanti et al. (2026). Preprint. | [10.21203/rs.3.rs-9910824/v1](https://doi.org/10.21203/rs.3.rs-9910824/v1) | Conversational enjoyment; crossed mixed model; signed contributions of many predictors. The exact share is 24.0% of the partner covariance; the same-predictor rows sum to 15.7%, the rest is cross-predictor terms. | partial | Many predictors; repeated encounters, not within/between levels. |

### 2c. Longitudinal and ILD applications closest to the question

None decomposes the partner covariance into routes at either level.

| Source | DOI | Summary | ILD | Main contribution |
|:--|:--|:--|:--|:--|
| Cornelius, DiGiovanni, Scott & Bolger (2022). *Journal of Social and Personal Relationships*. **New.** | [10.1177/02654075221106391](https://doi.org/10.1177/02654075221106391) | 104 couples, 14-day diary. Partner random-intercept correlations are reported for the empty model and with actor/partner effects of baseline distress (e.g. loneliness .35 vs .27); day-level residual correlations too. The Discussion proposes comparing residual correlations with and without time-varying predictors. | yes | Closest application: partner dependence at both levels, before and after predictors. No explained share is computed. |
| Hou, Chen & Yu (2024). *Journals of Gerontology: Series B*. **New.** | [10.1093/geronb/gbae045](https://doi.org/10.1093/geronb/gbae045) | 1,706 Chinese couples, four waves; Gistelinck–Loeys L-APIM. Partner correlations .34 (stable) and .17 (wave-specific). In the supplement, covariates cut the stable covariance from 2.89 to 0.84; not discussed. | partial | Level-specific partner covariance in a panel. |
| Papp, Pendry & Adam (2009). *Journal of Family Psychology*. **New.** | [10.1037/a0017147](https://doi.org/10.1037/a0017147) | Mother–adolescent cortisol in daily life. Tests whether shared momentary context accounts for the within-dyad synchrony by comparing it before and after adding the context. | yes | Within level: "explained by shared context" test. |
| Papp, Pendry, Simon & Adam (2013; online 2012). *Family Process*. **New.** | [10.1111/j.1545-5300.2012.01413.x](https://doi.org/10.1111/j.1545-5300.2012.01413.x) | Couples' cortisol; shared context did not account for synchrony. | yes | Same test in couples. |
| Cho, Huang, Chow & Martire (2025). *Annals of Behavioral Medicine*. **New.** | [10.1093/abm/kaaf092](https://doi.org/10.1093/abm/kaaf092) | Hourly physical activity in couples. Removes the shared daily rhythm as a source of "spurious" synchrony, then splits synchrony into couple and day levels. | yes | Shared-cause adjustment before the level split. |
| Lee et al. (2018). *Sleep Health*. **New.** | [10.1016/j.sleh.2017.10.009](https://doi.org/10.1016/j.sleh.2017.10.009) | 38 couples, 8 nights. Sleep duration covaries within couples, sleep quality between couples. | yes | Level split of partner covariation. |
| Goldring & Bolger (2022). *Emotion*. **New.** | [10.1037/emo0000938](https://doi.org/10.1037/emo0000938) | Daily diary. Partners' daily judgments covary partly through affect: own affect (infusion) and partner's affect (diffusion). | yes | Route logic in words, at the daily level. |
| Hoppmann, Gerstorf, Willis & Schaie (2011). *Developmental Psychology*. **New.** | [10.1037/a0020788](https://doi.org/10.1037/a0020788) | Spousal correlations in happiness levels and slopes, with and without individual and couple covariates. | partial | Between level: covariates and partner similarity. |

## Citing in Paper 1

- Method: Kenny, Ackerman & Kashy (2024, section 23.5). APIM: Kenny, Kashy
  & Cook (2006), and p. 146 for the formula once the page is checked.
- Teaching and software: Kenny (2013) slides (earliest dated), the
  Bolger–Laurenceau webinar, Kenny's handout and APIM_MM.
- Path algebra: Boker et al. (2002). Framing: Wickham & Knee (2012). Cite
  Kline (2016) only as Dwyer's path-tracing source.
- Applications: Dwyer et al. (2017) and Ferraris et al. (2022); Burns
  (2019), De Padova et al. (2021) and Cavalcanti et al. (2026) for
  reporting, multiple predictors and signed parts.
- Writing models: Laurenceau & Bolger (2005, exposition;
  [10.1037/0893-3200.19.1.86](https://doi.org/10.1037/0893-3200.19.1.86)),
  Ledermann, Macho & Kenny (2011, derived dyadic quantities;
  [10.1080/10705511.2011.607099](https://doi.org/10.1080/10705511.2011.607099)),
  Gistelinck, Loeys, Decuyper & Dewitte (2018, from simulation to
  recommendations; [10.1111/bmsp.12129](https://doi.org/10.1111/bmsp.12129)).

## Covariates in prior work

- Kenny, Ackerman & Kashy (2024, Tables 23.3–23.4) split the full
  correlation, covariates included, and count the predictor–covariate
  cross-terms as covariate parts (total covariate share −2.5%). This
  grouping is a convention.
- Dwyer et al. (2017) and Lee et al. (2021) split the covariance left after
  the controls (Dwyer: 1.980, from a controls-only model).
- Velten & Margraf (2017) and Cavalcanti et al. (2026) treat covariates as
  substantive predictors.
- [explore-sem-mlm.Rmd](explore-sem-mlm.Rmd) (section 6) reports the four
  mixed routes as their own group.

## For Paper 2 and 3 only

A two-level SEM already models the covariance at each level, so applying
the route algebra at both levels is not new by itself. Paper 2 has to state
the target, the random-slope treatment, the scaling and the inference, and
compare them with existing multilevel methods. For Paper 3: no source
splits the covariance of binary or count outcomes into routes under a
nonlinear link.

| Source | DOI | Summary | Paper |
|:--|:--|:--|:--|
| Koch et al. (2025, online). *British Journal of Mathematical and Statistical Psychology*. | [10.1111/bmsp.70022](https://doi.org/10.1111/bmsp.70022) | Self and partner ratings of the same person's affect in ILD (100 couples, 86 occasions). Later author code gives posterior-draw CIs for derived variance ratios. Not APIM routes. Preprint and supplements checked, not the journal version. | 2 |
| Loeys & Molenberghs (2013). *Psychological Methods*, 18(2), 220–236. | [10.1037/a0030640](https://doi.org/10.1037/a0030640) | Binary and count APIM with GLMM and GEE; marginal moments and within-dyad association. No route partition. | 3 |
| Loeys et al. (2014). *Personal Relationships*, 21(2), 225–241. | [10.1111/pere.12028](https://doi.org/10.1111/pere.12028) | Practical guide to logistic and negative-binomial GEE APIMs; 46 ex-couples. Working residual correlations, no route partition. | 3 |
| Leckie et al. (2020). *Psychological Methods*, 25(6), 787–801. | [10.1037/met0000265](https://doi.org/10.1037/met0000265) | Response-scale variance partitions, covariances and ICCs for Poisson and negative-binomial mixed models. Not an APIM route split. | 3 |

## Promising, but no access

These could not be opened (Cloudflare, APA login or print only). Snippets
and full-text index searches of most of them found no "path tracing" or
"explained by the actor" hits, so a positive find is unlikely. All are
worth a quick check through the UZH library.

| Source | DOI or ID | Why |
|:--|:--|:--|
| Kenny, Kashy & Cook (2006), p. 146 | ISBN 9781572309869 | Probably the first printed formula. |
| Laurenceau & Bolger (2012), Mehl & Conner handbook, pp. 407–422 | ISBN 9781609187477 | Main ILD dyad chapter; only snippets seen. |
| Iida, Savord & Ledermann (2023), *Personal Relationships* | [10.1111/pere.12468](https://doi.org/10.1111/pere.12468) | Review of longitudinal dyadic models. Wiley shows a "verify you are human" check. |
| Kenny & Kashy (2011), *Handbook of advanced multilevel analysis* | [10.4324/9780203848852.ch17](https://doi.org/10.4324/9780203848852.ch17) | Kenny's MLM chapter with an over-time example. |
| Kenny (2018), *Personal Relationships*, 25(2), 160–170 | [10.1111/pere.12240](https://doi.org/10.1111/pere.12240) | "Reflections on the actor-partner interdependence model". Only the abstract and references were seen. |
| Kashy & Kenny (2000), *Handbook of research methods in social and personality psychology* (1st ed.), pp. 451–477 | No DOI | Earlier chapter cited by APIM_MM; the text was not found. |
| Westman & Vinokur (1998), *Human Relations* | [10.1177/001872679805100202](https://doi.org/10.1177/001872679805100202) | SEM of why spouses' depression correlates: common stressors vs crossover. May quantify the parts. Free copy on Deep Blue (browser download). |
| Howe, Levy & Caplan (2004), *Journal of Family Psychology* | [10.1037/0893-3200.18.4.639](https://doi.org/10.1037/0893-3200.18.4.639) | Common stressors vs stress transmission in couples. |
| Mehulić (2024), doctoral dissertation, University of Zagreb | [10.17234/diss.2024.266578](https://doi.org/10.17234/diss.2024.266578) | Dyadic diary DSEM APIM, 140 couples. |
| Schatz (2018), doctoral dissertation, University of Duisburg-Essen | Repository blocked | Job-insecurity crossover with longitudinal dyadic data; matched the phrase "explained by the APIM". |
| Iida, Shrout, Laurenceau & Bolger (2023), *APA handbook of research methods in psychology* | [10.1037/0000318-016](https://doi.org/10.1037/0000318-016) | ILD chapter; may include a dyadic example. |

Also worth asking J-P and Niall whether their dyadic ILD workshop slides
("Modeling dyadic intensive longitudinal data") or Laurenceau's talk
"Multilevel DSEM of dyadic data" decompose partner covariance at the daily
level.

## How the search was done

The earlier review (31 August to 7 October) used keyword searches, OpenAlex
and Europe PMC forward citations, and full-text checks through UZH. Its
forward-citation step (13 September) used nine seeds: the six papers in 2a,
Wickham & Knee (2012), Kenny, Ackerman & Kashy (2024) and Cavalcanti et al.
(2026). OpenAlex, Europe PMC and, for three seeds, Semantic Scholar
returned 390 citing records (with duplicates across indexes). These were
screened by title and abstract, and selected ones in full text. The new
search used seven agents, each with a different strategy:

- Kenny's site, workshops and books;
- ILD methods;
- full-text phrase search;
- forward and backward citations via Semantic Scholar and OpenCitations;
- applications by field, including every FLASHE dyadic paper;
- ILD applications;
- dissertations, grey literature, other fields and non-English terms.

Verifier agents checked each new claim in the full text, and a final agent
looked for gaps. All DOIs were checked against Crossref.

**Checked and left out.** These were checked and have no decomposition:

- Expected teaching sources: Kenny (1996); Kenny & Cook (1999); Cook & Kenny
  (2005); Campbell & Kashy (2002); Kenny & Kashy (2014); Ledermann & Kenny
  (2017); Fitzpatrick et al. (2016); Bolger & Laurenceau (2013); Kenny,
  Kashy & Bolger (1998; relevant sections, pp. 244–251 and 262–263).
- More teaching sources: Kashy, Ackerman & Donnellan (2018); Lyons & Rauer
  (2025); del Rosario & West (2025); the 2018 DATIC workshop.
- Neighbouring derived APIM quantities: Kenny & Ledermann (2010, k ratio);
  Ledermann, Macho & Kenny (2011, mediation); Stas et al. (2018, APIM_SEM).
- Nine FLASHE and other applications excluded in the earlier full-text
  audit (6–7 October): Park & Park (2024, 2025); Welch et al. (2019); Lu et
  al. (2022); Niermann et al. (2020/2022); Kim & Chae (2024/2025);
  Damrongsakul (2022); Niu et al. (2026); Jang, Bottom & Elfenbein (2025).
  Vu et al. (2026) was excluded from the abstract only.

Weaker ILD near misses (synchrony and concordance studies without any
explained share) are in the search log, not in these lists.

**Limits.**

- Semantic Scholar's full-text snippet search and part of OpenAlex were
  rate-limited.
- Many Wiley, SAGE and APA articles block automated access, so some were
  judged from abstracts or snippets.
- No Scopus, Web of Science or PsycINFO exports were used.
