# References for simulation-based dyadic checks

This folder is a local reading library for validating
`simulate_dyad_responses()` and `check_partner_dependence()`. The PDFs are
ignored by `dev/.gitignore`, and all of `dev/` is excluded from package builds.
Some files are open access; others are local reading copies. Check the license
before redistributing any PDF. See the [library index](../README.md) for the
organization of all development references.

## Which source supports which part?

- **Predictive-reference construction:** Gelman et al. (1996) and Gelman
  (2004). The exported `glmmTMB` fixed-parameter procedure is a plug-in
  analogue. Gelman (2007) motivates the mixed/intermediate Bayesian replication
  used by the `brms` prototype, where posterior higher-level parameters are
  retained draw-wise and new lower-level effects are generated.
- **Alternative draw-matched Bayesian discrepancies:** Meng (1994) and Gelman
  et al. (1996) define parameter-dependent discrepancies by applying the
  observed and replicated discrepancy under the same posterior draw. This is a
  separate possible later target, not the current single-plot `brms` prototype.
  Levy (2006; journal version 2009) applies this construction to conditional
  residual association after removing draw-specific latent person effects. A
  dyadic analogue would be most useful with repeated outcomes and would not
  validate the population distribution of those effects or new-dyad prediction.
- **Modern graphical workflow:** Gabry et al. (2019) supports targeted,
  graphical posterior-predictive checks within an iterative workflow.
  Säilynoja et al. (2025, updated 2026) discusses current visual encodings and
  their limitations; the prototype's summary-statistic display is an explicit
  encoding rather than a comparison of raw response densities.
- **New-dyad hierarchical target:** Gelman (2007) motivates intermediate
  replication that averages over posterior hyperparameters while generating
  new lower-level effects. Bayarri and Castellanos (2007) provides the broader
  hierarchical checking comparison and important calibration cautions.
- **`brms` software layer:** Bürkner (2017) is the primary package paper. Use
  the current `brms` function documentation, rather than the 2017 article alone,
  to validate exact `posterior_predict()` and `posterior_epred()` arguments and
  new-level behavior. The paper is stored with the
  [model-estimation references](../model_estimation/README.md).
- **Model centring:** the closest code precedent is Hartig's DHARMa
  manual, especially `testGeneric()` and `testDispersion()`. It is not an exact
  derivation of this dyadic check. Under a nonlinear link, setting random effects
  to zero generally does not give the marginal new-dyad mean; a generalized
  implementation must account for that difference.
- **Raw-response dyadic association:** Hoff (2015) compares empirical
  within-dyad association in observed and posterior-predictive sociomatrices.
  The `"raw"` option adapts this comparison to paired responses and new-dyad
  simulations; it is Hoff-style rather than an exact `amen` implementation.
- **Exchangeable between/within-dyad moment decomposition:** Woody and Sadler
  (2005) is the primary detailed source used here; it credits Kenny (1996) for
  the two-matrix strategy. Kenny and Ackerman (2023) and del Rosario and West
  (2025) apply the related sum/difference basis to random-effects
  parameterization in longitudinal dyadic multilevel models; none of these
  papers describes this predictive check. They are stored with the
  [model-estimation references](../model_estimation/README.md).
- **Validation-study design:** Morris et al. (2019), using the ADEMP framework
  and explicit Monte Carlo uncertainty. The paper is stored with the
  [validation-study references](../validation_studies/README.md).
- **Calibration and held-out complements:** Paganin and de Valpine (2025)
  studies calibrated posterior-predictive p-values; Li and Huggins (2026)
  develops split predictive checks. These sources explain why the package must
  not present the prototype's descriptive observed position as a calibrated
  p-value and support a separate held-out workflow. Keeping whole dyads together
  is our consequence of choosing new-dyad prediction as the target, not a
  dyad-specific prescription from Li and Huggins.
- **Related but different residual approaches:** Dunn and Smyth (1996),
  Schützenmeister and Piepho (2012), and Warton et al. (2017). These should not
  be cited as though they describe the package's exact algorithm.

No single paper specifies the complete check. The `glmmTMB` path and `brms`
prototype both offer raw and model-centred summaries, but use plug-in
and posterior-predictive references, respectively.

## Local PDFs

| Local file | Reference and source | Use for validation |
|---|---|---|
| `1994-meng-posterior-predictive-p-values.pdf` | Meng, X.-L. (1994). Posterior predictive p-values. *The Annals of Statistics, 22*(3), 1142–1160. [doi:10.1214/aos/1176325622](https://doi.org/10.1214/aos/1176325622); [author-hosted PDF](https://statistics.fas.harvard.edu/file_url/1054). | Most direct foundation for parameter-dependent discrepancies that compare observed and replicated data under the same posterior draw. This supports a possible draw-matched extension, not either current response option. |
| `1996-gelman-meng-stern-posterior-predictive-assessment.pdf` | Gelman, A., Meng, X.-L., & Stern, H. S. (1996). Posterior predictive assessment of model fitness via realized discrepancies. *Statistica Sinica, 6*, 733–807. [Official PDF, including discussion and rejoinder](https://www3.stat.sinica.edu.tw/statistica/oldpdf/a6n41.pdf). | Core basis for comparing the same discrepancy/statistic in observed and replicated data. |
| `2004-gelman-exploratory-data-analysis-complex-models.pdf` | Gelman, A. (2004). Exploratory data analysis for complex models. *Journal of Computational and Graphical Statistics, 13*(4), 755–779. [doi:10.1198/106186004X11435](https://doi.org/10.1198/106186004X11435); [author PDF](https://sites.stat.columbia.edu/gelman/research/published/p755.pdf). | Direct support for the approximate plug-in reference distribution based on simulations from fitted parameter estimates. |
| `2007-bayarri-castellanos-hierarchical-checking.pdf` | Bayarri, M. J., & Castellanos, M. E. (2007). Bayesian checking of the second levels of hierarchical models. *Statistical Science, 22*(3), 322–343. [doi:10.1214/07-STS235](https://doi.org/10.1214/07-STS235); [arXiv PDF](https://arxiv.org/pdf/0802.0743). | Compares checking references for hierarchical models and documents the double-use and conservatism limitations of ordinary posterior-predictive tail areas. |
| `2007-gelman-checking-hierarchical-second-levels.pdf` | Gelman, A. (2007). Comment: Bayesian checking of the second levels of hierarchical models. *Statistical Science, 22*(3), 349–352. [doi:10.1214/07-STS235A](https://doi.org/10.1214/07-STS235A); [author PDF](https://sites.stat.columbia.edu/gelman/research/published/STS235A.pdf). | Supports Bayesian intermediate replication, which averages over posterior hyperparameter uncertainty while generating new lower-level effects. This describes the `brms` prototype's target; the exported fixed-estimate simulation is its plug-in analogue. |
| `2019-gabry-et-al-visualization-bayesian-workflow.pdf` | Gabry, J., Simpson, D., Vehtari, A., Betancourt, M., & Gelman, A. (2019). Visualization in Bayesian workflow. *Journal of the Royal Statistical Society: Series A, 182*(2), 389–402. [doi:10.1111/rssa.12378](https://doi.org/10.1111/rssa.12378); [arXiv PDF](https://arxiv.org/pdf/1709.01449). | Modern graphical-workflow basis for targeted posterior-predictive summaries; also cautions that checks closely related to fitted parameters may have low sensitivity. |
| `2025-sailynoja-et-al-visual-predictive-checks.pdf` | Säilynoja, T., Johnson, A. R., Martin, O. A., & Vehtari, A. (2025, updated 2026). *Recommendations for visual predictive checks in Bayesian workflow*. Under-review article. [living article](https://www.journalovi.org/2025-sailynoja-visual-predictive-checks/); [PDF](https://www.journalovi.org/2025-sailynoja-visual-predictive-checks/index.pdf). | Current visual guidance. It distinguishes overlay, juxtaposition, and explicit summary-statistic encodings and stresses matching a display to the data and diagnostic question. |
| `2025-paganin-de-valpine-calibrated-posterior-p-values.pdf` | Paganin, S., & de Valpine, P. (2025). Computational methods for fast Bayesian model assessment via calibrated posterior p-values. *Journal of Computational and Graphical Statistics, 34*(2), 462–473. [doi:10.1080/10618600.2024.2374585](https://doi.org/10.1080/10618600.2024.2374585); [arXiv PDF](https://arxiv.org/pdf/2306.04866). | Modern confirmation that ordinary posterior-predictive p-values are not null-uniform and description of a much more expensive calibration procedure. |
| `2026-li-huggins-split-predictive-checks.pdf` | Li, J., & Huggins, J. H. (2026). Calibrated model criticism using split predictive checks. *Journal of the American Statistical Association*. [doi:10.1080/01621459.2026.2649585](https://doi.org/10.1080/01621459.2026.2649585); [author page](https://jhhuggins.org/publication/split-predictive-checks/); local file is the arXiv prepublication version. | Recent support for separating explanatory posterior-predictive checks from calibrated checks of generalization. Given this package's new-dyad target, our implementation must assign whole dyads rather than rows to splits. |
| `2026-hartig-dharma-reference-manual.pdf` | Hartig, F. (2026). *DHARMa: Residual Diagnostics for Hierarchical (Multi-Level / Mixed) Regression Models*, version 0.5.0. [CRAN manual](https://cran.r-project.org/web/packages/DHARMa/DHARMa.pdf). | Closest code-level precedent for applying a statistic to `response - prediction` and using the same prediction vector for observed and simulated responses. DHARMa's usual PIT residuals are a different construction. |
| `2015-hoff-dyadic-data-analysis-amen.pdf` | Hoff, P. D. (2015). Dyadic data analysis with amen. arXiv:1506.08237. [arXiv PDF](https://arxiv.org/pdf/1506.08237). | Dyadic precedent for comparing raw observed and replicated association. Hoff uses sociomatrices for the same actors; this package uses paired new-dyad simulations. His separate residual-reciprocity calculation removes sender and receiver effects and is not the centred option. |
| `2006-levy-dissertation-posterior-predictive-multidimensionality.pdf` | Levy, R. (2006). *Posterior Predictive Model Checking for Multidimensionality in Item Response Theory and Bayesian Networks* (doctoral dissertation, University of Maryland). [Institutional PDF](https://api.drum.lib.umd.edu/server/api/core/bitstreams/02308c91-cda7-4ef6-947e-19d1e433ff96/content). | Source for draw-matched conditional residual-covariance checks after removing latent person effects. This is a separate future check, not either current option. |
| `2010-schuetzenmeister-dissertation-simulation-residuals.pdf` | Schützenmeister, A. (2010). *Biometrical Tools for Heterosis Research* (doctoral dissertation, University of Hohenheim), Chapter 3. [Institutional PDF](https://hohpublica.uni-hohenheim.de/server/api/core/bitstreams/5a88292d-8c54-41b2-8e33-32dd32f4a4f9/content). | Contains the simulation-based residual method later published with Piepho. Important difference: that procedure refits simulated datasets; the current package check does not. |
| `2018-harrison-et-al-mixed-effects-modeling.pdf` | Harrison, X. A., et al. (2018). A brief introduction to mixed effects modelling and multi-model inference in ecology. *PeerJ, 6*, e4794. [doi:10.7717/peerj.4794](https://doi.org/10.7717/peerj.4794); [PDF](https://www.sfu.ca/biology/faculty/M%27Gonigle/materials-qm/papers/harrison-2018-4794.pdf). | Accessible mixed-model overview with simulation-based model checking examples. |
| `2021-auger-methe-et-al-state-space-modeling.pdf` | Auger-Méthé, M., et al. (2021). A guide to state–space modeling of ecological time series. *Ecological Monographs, 91*(4), e01470. [doi:10.1002/ecm.1470](https://doi.org/10.1002/ecm.1470); [repository PDF](https://research-repository.st-andrews.ac.uk/bitstream/handle/10023/23371/M_th_2021_A_guide_to_state_space_ECM_1470_CCBYNC.pdf?sequence=2). | Broader guidance on checks in hierarchical latent models and the distinction between conditional and marginal predictions. |
| `1996-dunn-smyth-randomized-quantile-residuals.pdf` | Dunn, P. K., & Smyth, G. K. (1996). Randomized quantile residuals. *Journal of Computational and Graphical Statistics, 5*(3), 236–244. [doi:10.1080/10618600.1996.10474708](https://doi.org/10.1080/10618600.1996.10474708); [author PDF](https://gksmyth.github.io/pubs/residual.pdf). | Theoretical background for randomized quantile/PIT residuals. It assumes independent responses and does not justify the dyadic statistic directly. |
| `2017-warton-thibaut-wang-pit-trap.pdf` | Warton, D. I., Thibaut, L., & Wang, Y. A. (2017). The PIT-trap—A "model-free" bootstrap procedure for inference about regression models with discrete, multivariate responses. *PLOS ONE, 12*(7), e0181790. [doi:10.1371/journal.pone.0181790](https://doi.org/10.1371/journal.pone.0181790); [PLOS PDF](https://journals.plos.org/plosone/article/file?id=10.1371/journal.pone.0181790&type=printable). | Useful contrast for PIT-based procedures that preserve multivariate dependence; it is not the package's plug-in parametric check. |

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
## Implementation-validation checklist derived from the sources

1. Verify that `simulate_dyad_responses()` holds fitted model parameters fixed,
   generates new random effects and observation errors, and returns complete
   fitted-row-aligned response datasets without refitting.
2. Verify both response representations: `"raw"` changes nothing, while
   `"model-centred"` subtracts the same fixed marginal response centre over new
   random effects from observed and simulated responses. In Gaussian identity
   models this equals the random-effects-excluded prediction. Random-effect and
   residual dependence remain.
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
7. The exploratory `brms` prototype may use every posterior draw once when
   `nsim = NULL`; if fewer simulations are requested, subsample draws without
   replacement and make that selection reproducible. The future public API uses
   the bounded default `nsim = 1000` for both backends. Calculate the fixed
   centre by averaging random-effects-excluded `posterior_epred()` values over
   all posterior draws on the original model frame. Verify agreement with a
   direct design-matrix calculation for a Gaussian identity model with varying
   covariates.
8. For the new-dyad target, relabel once per dyad and generate Gaussian new
   group effects. Never assign one new level per row, reuse learned group
   effects, or subtract a newly sampled dyad effect from the observed response.
9. Plot only the replicated-statistic histogram, the observed statistic as a
   red line, and the replicated middle 95% as dashed lines. Treat the observed
   position and interval as descriptive, not as an acceptance rule.
10. Generalized support should begin with raw checks. Before enabling a
    model-centred generalized family, obtain a fixed new-dyad marginal response
    mean by averaging expected-response draws over posterior or fitted
    parameters and newly generated random effects. Validate its Monte Carlo
    stability and demonstrate when it differs from the response prediction with
    random effects set to zero.
11. For every generalized family, quantify zero-variance or undefined
    statistics and verify that response-scale correlation is sensitive to the
    intended dependence misspecifications. Simulation support alone is not
    sufficient evidence that the statistic is informative.

Sources and access were checked on 2026-08-22.
