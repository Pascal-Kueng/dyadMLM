# Literature notes: mixed compositions and singletons

Focused search and comparison, 1–2 October 2026. This is a starting evidence map,
not an exhaustive systematic review. Bibliographic records for the 11 sources
below are in [references.bib](references.bib).

## Findings and originality boundary

Joint analysis of multiple dyad compositions, retention of incomplete dyads,
exchangeable covariance parameterizations and two-part predictors all have
precedents. Composition-specific slopes can be obtained using ordinary
interactions. The focused search did not identify an exact published workflow
combining all our examples, but that does not establish that none exists.

For cross-sectional Gaussian models, our random terms with near-zero remaining
dispersion encode the marginal residual covariance. When the mean, covariance
constraints, analysis sample and estimation settings match, different software
syntax can describe the same statistical model.

If means, slopes and covariance parameters are all separate by composition, the
Gaussian likelihood factorizes by composition. A joint fit then provides no
automatic borrowing of information; shared parameters or equality constraints
create that pooling. This distinction matters when motivating a joint model.

## Closest methodological precedents

### West, Popp and Kenny (2008): multiple compositions

*A Guide for the Estimation of Gender and Sexual Orientation Effects in Dyadic
Data: An Actor-Partner Interdependence Model Approach.*
[Paper](https://doi.org/10.1177/0146167207311199),
[author-hosted full text](https://tessawestlab.com/documents/West_2008_A%20guide%20for%20the%20estimation%20of%20gender%20and%20sexual%20orientation%20effects%20in%20dyadic%20data%20an%20actor%20partner%20interdependence%20model%20approach.pdf).

- Jointly analyzes female–female, female–male and male–male couples using actor
  gender, partner gender and their interaction. This factorial coding is
  equivalent to four composition/role mean indicators.
- Includes interactions with actor and partner age, so composition/role-specific
  actor and partner slopes are already possible.
- Uses SPSS `MIXED` and provides SAS `PROC MIXED` syntax. The demonstrated models
  impose one common compound-symmetric residual covariance across compositions.
- Our unpooled cross-sectional example instead has seven covariance parameters:
  three for FM, two for FF and two for MM. It permits unequal role variances in
  FM and different variances/correlations across compositions. This changes the
  assumptions; indicator coding alone does not.

### Knafl et al. (2009): incomplete distinguishable dyads

*Analysis of Cross-Sectional Univariate Measurements for Family Dyads Using Linear
Mixed Modeling.* [Full text](https://pmc.ncbi.nlm.nih.gov/articles/PMC2848874/).

- Analyzes 145 complete mother/father pairs and 179 families with only the mother
  participating, all from two-parent families. Single mothers were collected but
  excluded from the example analyses.
- Uses SAS `PROC MIXED`, role-specific residual SDs and an intrafamilial
  correlation. With two members, this heterogeneous compound-symmetry structure
  permits an unrestricted 2×2 covariance matrix. Mother variances are pooled
  across complete and incomplete families, matching our pooled distinguishable
  covariance option.
- Includes participation-pattern mean differences; explicitly discusses adding
  a single-versus-partnered indicator. An absent respondent is not an absent
  partner.
- Available-outcome likelihood handles incomplete outcome vectors, not missing
  predictors. Their worked regressions do not demonstrate our two-part partner
  predictor or the mixed-composition framework.

### del Rosario and West (2025): longitudinal covariance and sum/difference terms

*A Practical Guide to Specifying Random Effects in Longitudinal Dyadic Multilevel
Modeling.* [Paper](https://doi.org/10.1177/25152459251351286).

Provides SAS and R `nlme` examples, including sum-and-difference random-effect
structures for indistinguishable dyads and guidance on convergence. This is a
direct precedent for that parameterization. Our exchangeable shared/contrast
terms are not a new covariance principle. Cite it for longitudinal random
effects and fitting choices, rather than as an empirical demonstration of all
compositions and singleton statuses together.

### Dziak and Henry (2017): a predictor undefined when no partner exists

*Two-Part Predictors in Regression Models.*
[Full text](https://pmc.ncbi.nlm.nih.gov/articles/PMC5764087/).

Method 1 includes a presence/status indicator and a continuous predictor coded
zero when structurally absent. Its empirical examples include partner drug use
and relationship satisfaction for participants with and without qualifying
relationships. This directly supports our partner-status/partner-score coding.
It is not a joint model of both dyad members' outcomes. An existing partner's
unknown predictor remains a missing-data problem. Adding a status-by-actor-score
interaction is a standard way to allow different actor slopes.

### Du and Wang (2016): finite-sample behavior with singletons

*The Impact of the Number of Dyads on Estimation of Dyadic Data Analysis Using
Multilevel Modeling.* [Paper](https://doi.org/10.1027/1614-2241/a000105),
[author's publication list](https://dulab.psych.ucla.edu/publications/).

Simulation varies dyad sample size, intradyad correlation, singleton prevalence
and missingness conditions. It motivates reporting covariance recovery and
uncertainty alongside fixed effects and checking small samples with many
singletons. Publication and abstract/full-text preview were checked; detailed
conditions and estimator settings should be extracted from the full paper
before selecting benchmarks. Its results do not validate our particular model.

## Applied examples and related tutorials

### Spahr and Robbins (2025): a recent mixed-composition application

*Spill the tea, honey: Gossiping predicts well-being in same- and different-gender
couples.* [Full text](https://doi.org/10.1177/02654075251375147).

Uses SPSS APIMs for 76 couples spanning same- and different-gender compositions,
following West's factorial approach. Useful evidence that the joint analysis is
used in current applied research. It does not establish that our separate
composition covariance blocks were used.

### Henry et al. (2022): structural presence and relationship quality

*Two-Part Models for Father–Child Relationship Variables: Presence in the Child's
Life and Quality of the Relationship Conditional on Some Presence.*
[Paper](https://doi.org/10.1086/714016).

Provides real-data examples and R/Mplus syntax for two-part relationship variables
in longitudinal models. Useful for explaining why no contact/presence is not
equivalent to a low relationship-quality score. It is related two-part modeling,
not an exact mixed-composition joint APIM precedent. Use the final 2022 citation,
rather than the 2021 date appearing in some earlier lists.

## Background and implementation references

| Reference | Role in the paper |
|:--|:--|
| [Kenny, Kashy and Cook (2006), *Dyadic Data Analysis*](https://www.guilford.com/books/Dyadic-Data-Analysis/Kenny-Kashy-Cook/9781462546138) | APIM foundations, distinguishability and dyadic dependence. |
| [Campbell and Kashy (2002)](https://doi.org/10.1111/1475-6811.00023) | Earlier APIM implementation and interaction tutorial using SAS `PROC MIXED` and HLM. |
| [Curran and Bauer (2011)](https://doi.org/10.1146/annurev.psych.093008.100356) | Separating within-person and between-person effects if longitudinal models are included. |
| [Brooks et al. (2017)](https://journal.r-project.org/articles/RJ-2017-066/) | Cite the `glmmTMB` implementation; this software paper does not establish our dyadic model's novelty or calibration. |

## Remaining literature work

Follow references and forward citations from West, Knafl, Dziak and del Rosario;
inspect actual model specifications rather than counting APIM citations. Search
for composition-specific residual covariance, incomplete exchangeable dyads,
unpartnered participants, participation-pattern effects and combined longitudinal
examples. Check SEM and direct residual-covariance implementations too.

Terminology can mislead: “mixed dyadic” sometimes means a predictor with both
within- and between-dyad variation, rather than multiple dyad compositions.
Treat such titles as screening leads until their methods establish relevance.
