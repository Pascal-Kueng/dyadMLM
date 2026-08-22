# Validation references for simulation-based dyadic diagnostics

This folder is a local reading library for validating
`simulate_dyad_responses()` and `check_partner_dependence()`. The PDFs are
ignored by `dev/.gitignore`, and all of `dev/` is excluded from package builds.
Some files are open access; others are local reading copies. Check the license
before redistributing any PDF.

## Which source supports which part?

- **Predictive-reference construction:** Gelman et al. (1996) and Gelman
  (2004). Gelman (2007) motivates hierarchical intermediate replication; the
  current fixed-parameter procedure is its plug-in analogue, not the Bayesian
  procedure described there.
- **Centering observed and simulated responses on the same fixed prediction:**
  the closest implementation precedent is Hartig's DHARMa manual, especially
  `testGeneric()` and `testDispersion()`. This is a precedent, not an exact
  derivation of the new dyadic check.
- **Applying a dependence statistic to observed and replicated dyadic data:**
  Hoff (2015) and Levy (2006; journal version 2009).
- **Exchangeable between/within-dyad moment decomposition:** Woody and Sadler
  (2005) is the primary detailed source used here; it credits Kenny (1996) for
  the two-matrix strategy. Kenny and Ackerman (2023) and del Rosario and West
  (2025) apply the related sum/difference basis to random-effects
  parameterization in longitudinal dyadic multilevel models; none of these
  papers describes this predictive check.
- **Validation-study design:** Morris et al. (2019), using the ADEMP framework
  and explicit Monte Carlo uncertainty.
- **Related but different residual approaches:** Dunn and Smyth (1996),
  Schützenmeister and Piepho (2012), and Warton et al. (2017). These should not
  be cited as though they describe the package's exact algorithm.

No single paper specifies the complete combined check. It is a specialized
plug-in predictive diagnostic assembled from these directly identified
precedents; the documentation should not attribute the full algorithm to any
one source.

## Local PDFs

| Local file | Reference and source | Use for validation |
|---|---|---|
| [`1996-gelman-meng-stern-posterior-predictive-assessment.pdf`](1996-gelman-meng-stern-posterior-predictive-assessment.pdf) | Gelman, A., Meng, X.-L., & Stern, H. S. (1996). Posterior predictive assessment of model fitness via realized discrepancies. *Statistica Sinica, 6*, 733–807. [Official PDF, including discussion and rejoinder](https://www3.stat.sinica.edu.tw/statistica/oldpdf/a6n41.pdf). | Core basis for comparing the same discrepancy/statistic in observed and replicated data. |
| [`2004-gelman-exploratory-data-analysis-complex-models.pdf`](2004-gelman-exploratory-data-analysis-complex-models.pdf) | Gelman, A. (2004). Exploratory data analysis for complex models. *Journal of Computational and Graphical Statistics, 13*(4), 755–779. [doi:10.1198/106186004X11435](https://doi.org/10.1198/106186004X11435); [author PDF](https://sites.stat.columbia.edu/gelman/research/published/p755.pdf). | Direct support for the approximate plug-in reference distribution based on simulations from fitted parameter estimates. |
| [`2007-gelman-checking-hierarchical-second-levels.pdf`](2007-gelman-checking-hierarchical-second-levels.pdf) | Gelman, A. (2007). Comment: Bayesian checking of the second levels of hierarchical models. *Statistical Science, 22*(3), 349–352. [doi:10.1214/07-STS235A](https://doi.org/10.1214/07-STS235A); [author PDF](https://sites.stat.columbia.edu/gelman/research/published/STS235A.pdf). | Supports Bayesian intermediate replication, which averages over posterior hyperparameter uncertainty. The package's fixed-estimate simulation is a plug-in analogue. |
| [`2026-hartig-dharma-reference-manual.pdf`](2026-hartig-dharma-reference-manual.pdf) | Hartig, F. (2026). *DHARMa: Residual Diagnostics for Hierarchical (Multi-Level / Mixed) Regression Models*, version 0.5.0. [CRAN manual](https://cran.r-project.org/web/packages/DHARMa/DHARMa.pdf). | Closest code-level precedent for applying a statistic to `response - prediction` and using the same prediction vector for observed and simulated responses. DHARMa's usual PIT residuals are a different construction. |
| [`2015-hoff-dyadic-data-analysis-amen.pdf`](2015-hoff-dyadic-data-analysis-amen.pdf) | Hoff, P. D. (2015). Dyadic data analysis with amen. arXiv:1506.08237. [arXiv PDF](https://arxiv.org/pdf/1506.08237). | Dyadic precedent for comparing observed statistics, including within-dyad association, with statistics from complete replicated dyadic datasets. |
| [`2006-levy-dissertation-posterior-predictive-multidimensionality.pdf`](2006-levy-dissertation-posterior-predictive-multidimensionality.pdf) | Levy, R. (2006). *Posterior Predictive Model Checking for Multidimensionality in Item Response Theory and Bayesian Networks* (doctoral dissertation, University of Maryland). [Institutional PDF](https://api.drum.lib.umd.edu/server/api/core/bitstreams/02308c91-cda7-4ef6-947e-19d1e433ff96/content). | Detailed source for residual-covariance discrepancies that target unmodelled dependence. The peer-reviewed 2009 article is listed below. |
| [`2005-woody-sadler-interchangeable-dyads.pdf`](2005-woody-sadler-interchangeable-dyads.pdf) | Woody, E., & Sadler, P. (2005). Structural equation models for interchangeable dyads: Being the same makes a difference. *Psychological Methods, 10*(2), 139–158. [doi:10.1037/1082-989X.10.2.139](https://doi.org/10.1037/1082-989X.10.2.139). | Primary source for the interchangeable-dyad moment construction. Page 142 defines the centered mean and uncentered difference sample matrices; the Appendix on p. 158 derives their variance/covariance back-transformation. |
| [`2023-kenny-ackerman-sum-difference-random-effects.pdf`](2023-kenny-ackerman-sum-difference-random-effects.pdf) | Kenny, D. A., & Ackerman, R. A. (2023, July 4). *Estimation of Random Effects in Over-Time Dyadic Data Using Multilevel Modeling: The Sum and Difference Method*. [OSF PDF](https://osf.io/download/fju72/). | Direct technical treatment of sum/difference random-effect blocks and covariance back-transformations in longitudinal dyadic MLMs. |
| [`2025-del-rosario-west-random-effects-dyadic-mlm.pdf`](2025-del-rosario-west-random-effects-dyadic-mlm.pdf) | del Rosario, K. S., & West, T. V. (2025). A practical guide to specifying random effects in longitudinal dyadic multilevel modeling. *Advances in Methods and Practices in Psychological Science, 8*(3), 1–36. [doi:10.1177/25152459251351286](https://doi.org/10.1177/25152459251351286). | Peer-reviewed guide to implementing dyadic random effects, including the sum/difference workaround adapted from Kenny and Ackerman. It does not originate the response-summary diagnostic. |
| [`2019-morris-white-crowther-simulation-studies.pdf`](2019-morris-white-crowther-simulation-studies.pdf) | Morris, T. P., White, I. R., & Crowther, M. J. (2019). Using simulation studies to evaluate statistical methods. *Statistics in Medicine, 38*(11), 2074–2102. [doi:10.1002/sim.8086](https://doi.org/10.1002/sim.8086); [UCL PDF](https://discovery.ucl.ac.uk/id/eprint/10066118/1/2019%20-%20Morris%20-%20simulation%20studies%20tutorial%20-%20stat%20med.pdf). | Structure validation with aims, data-generating mechanisms, estimands, methods, and performance measures; report Monte Carlo error. |
| [`2010-schuetzenmeister-dissertation-simulation-residuals.pdf`](2010-schuetzenmeister-dissertation-simulation-residuals.pdf) | Schützenmeister, A. (2010). *Biometrical Tools for Heterosis Research* (doctoral dissertation, University of Hohenheim), Chapter 3. [Institutional PDF](https://hohpublica.uni-hohenheim.de/server/api/core/bitstreams/5a88292d-8c54-41b2-8e33-32dd32f4a4f9/content). | Contains the simulation-based residual method later published with Piepho. Important difference: that procedure refits simulated datasets; the current package check does not. |
| [`2018-harrison-et-al-mixed-effects-modeling.pdf`](2018-harrison-et-al-mixed-effects-modeling.pdf) | Harrison, X. A., et al. (2018). A brief introduction to mixed effects modelling and multi-model inference in ecology. *PeerJ, 6*, e4794. [doi:10.7717/peerj.4794](https://doi.org/10.7717/peerj.4794); [PDF](https://www.sfu.ca/biology/faculty/M%27Gonigle/materials-qm/papers/harrison-2018-4794.pdf). | Accessible mixed-model overview with simulation-based model checking examples. |
| [`2021-auger-methe-et-al-state-space-modeling.pdf`](2021-auger-methe-et-al-state-space-modeling.pdf) | Auger-Méthé, M., et al. (2021). A guide to state–space modeling of ecological time series. *Ecological Monographs, 91*(4), e01470. [doi:10.1002/ecm.1470](https://doi.org/10.1002/ecm.1470); [repository PDF](https://research-repository.st-andrews.ac.uk/bitstream/handle/10023/23371/M_th_2021_A_guide_to_state_space_ECM_1470_CCBYNC.pdf?sequence=2). | Broader guidance on checks in hierarchical latent models and the distinction between conditional and marginal predictions. |
| [`1996-dunn-smyth-randomized-quantile-residuals.pdf`](1996-dunn-smyth-randomized-quantile-residuals.pdf) | Dunn, P. K., & Smyth, G. K. (1996). Randomized quantile residuals. *Journal of Computational and Graphical Statistics, 5*(3), 236–244. [doi:10.1080/10618600.1996.10474708](https://doi.org/10.1080/10618600.1996.10474708); [author PDF](https://gksmyth.github.io/pubs/residual.pdf). | Theoretical background for randomized quantile/PIT residuals. It assumes independent responses and does not justify the dyadic statistic directly. |
| [`2017-warton-thibaut-wang-pit-trap.pdf`](2017-warton-thibaut-wang-pit-trap.pdf) | Warton, D. I., Thibaut, L., & Wang, Y. A. (2017). The PIT-trap—A "model-free" bootstrap procedure for inference about regression models with discrete, multivariate responses. *PLOS ONE, 12*(7), e0181790. [doi:10.1371/journal.pone.0181790](https://doi.org/10.1371/journal.pone.0181790); [PLOS PDF](https://journals.plos.org/plosone/article/file?id=10.1371/journal.pone.0181790&type=printable). | Useful contrast for PIT-based procedures that preserve multivariate dependence; it is not the package's plug-in parametric check. |

## Relevant works without a stored PDF

These exact articles are paywalled or lack a stable, clearly redistributable
open PDF. The library contains an official dissertation substitute where one
exists.
- Levy, R., Mislevy, R. J., & Sinharay, S. (2009). Posterior predictive model
  checking for multidimensionality in item response theory. *Applied
  Psychological Measurement, 33*(7), 519–537.
  [doi:10.1177/0146621608329504](https://doi.org/10.1177/0146621608329504).
  Use the 2006 dissertation above for the underlying residual-covariance work.
- Schützenmeister, A., & Piepho, H.-P. (2012). Residual analysis of linear
  mixed models using a simulation approach. *Computational Statistics & Data
  Analysis, 56*(6), 1405–1416.
  [doi:10.1016/j.csda.2011.11.006](https://doi.org/10.1016/j.csda.2011.11.006).
  Use Chapter 3 of the 2010 dissertation above for the method.
- Robins, J. M., van der Vaart, A. W., & Ventura, V. (2000). Asymptotic
  distribution of p values in composite null models. *Journal of the American
  Statistical Association, 95*(452), 1143–1156.
  [doi:10.1080/01621459.2000.10474310](https://doi.org/10.1080/01621459.2000.10474310).
  Relevant to why plug-in or posterior-predictive tail areas should not be
  labelled automatically as calibrated p-values.
- Breinegaard, N., Rabe-Hesketh, S., & Skrondal, A. (2018). Pairwise residuals
  and diagnostic tests for misspecified dependence structures in models for
  binary longitudinal data. *Statistics in Medicine, 37*(3), 343–356.
  [doi:10.1002/sim.7512](https://doi.org/10.1002/sim.7512). Relevant to targeted
  pairwise dependence diagnostics, but it is neither Gaussian-dyadic nor the
  same predictive-simulation procedure.
- Olsen, J. A., & Kenny, D. A. (2006). Structural equation modeling with
  interchangeable dyads. *Psychological Methods, 11*(2), 127–141.
  [doi:10.1037/1082-989X.11.2.127](https://doi.org/10.1037/1082-989X.11.2.127).
  Useful background on exchangeability constraints and label invariance, but
  secondary for the current implementation.

## Implementation-validation checklist derived from the sources

1. Verify that `simulate_dyad_responses()` holds fitted model parameters fixed,
   generates new random effects and observation errors, and returns complete
   fitted-row-aligned response datasets without refitting.
2. Verify that observed and replicated responses are centered on the identical
   random-effects-excluded prediction vector. This deliberately retains random-
   effect and residual dependence in both.
3. Verify that exactly the same statistic code is applied to the observed data
   and every replicate.
4. Verify the algebra linking member SDs/correlation to dyad-mean and
   half-difference summaries. In the exchangeable case, reconstruct the common
   variance and covariance from the mean-mode sample variance and the
   difference-mode mean square, using their respective `n - 1` and `n`
   denominators; also verify invariance to arbitrary member swaps.
5. Treat the observed quantile and central replicated interval as descriptive,
   not as a calibrated p-value or a binary adequacy decision.
6. In a simulation study, vary at least the number of dyads, partner
   correlation (including negative and zero values), equal versus unequal
   member variances, fixed-effect misspecification, random-effect
   misspecification, and `nsim`. Report Monte Carlo uncertainty.

Sources and access were checked on 2026-08-22.
