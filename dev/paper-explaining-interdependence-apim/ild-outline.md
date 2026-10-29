# Paper 2 (ILD): talking points and references

Draft, 9 October 2026. These are the main points for decomposing partner
covariance in daily diary data, with references. Paper 1 is in
[paper-1-outline.md](paper-1-outline.md). The worked example goes in
[explore-ild.Rmd](explore-ild.Rmd). The literature on the decomposition itself
(teaching sources, applications, closest ILD studies) is in the master list,
[literature.md](literature.md).

On 9 October, agents checked every reference here against Crossref and, where
possible, against the text. Sources marked *[abstract]* were checked against
the abstract only. Sources marked *[not seen]* were checked for metadata only:
read them before citing a specific point. Points marked *our derivation* were
checked by algebra or simulation but have no source.

## 1. Question and gap

- In diary data, the covariance between partners' outcomes mixes a stable,
  couple-level part and a daily part (Bolger & Shrout, 2007; Helm et al.,
  2018).
- Earlier ILD work splits partner dependence by level or fits two-level APIMs.
  No source found splits it into actor and partner routes at either level
  (master list: Gistelinck & Loeys, 2019, 2020; Cornelius et al., 2022).
  Laurenceau, DiGiovanni and Bolger (2026) list dyadic ILD models as future
  work.
- Contribution: the route decomposition at each level; observed vs latent
  person means; a covariance analog of the ICC; couple-bootstrap CIs.

## 2. The decomposition

- Path tracing: Wright (1921, p. 568) gives the four routes in correlation
  units for two outcomes with correlated causes. Kenny (1979, ch. 3) adds
  correlated disturbances, which is our residual route. Loehlin and Beaujean
  (2017, pp. 27, 46) give the unstandardized rule: each route is path ×
  variance or covariance × path. Matrix form: Bollen (1989, p. 85, Eq. 4.7);
  for the APIM, Kenny, Ackerman and Kashy (2024, Section 23.5).
- The simple form needs outcomes that do not affect each other: no mutual
  influence, mediation or lagged outcomes. Otherwise the general form
  (I − B)⁻¹(ΓΦΓ′ + Ψ)(I − B)⁻¹′ applies (Bollen, 1989; Kenny, 1979, ch. 3).
- *Our derivation:* the sum reproduces the sample covariance only when both
  outcome equations have the same predictors (untrimmed APIM).

## 3. Implied vs observed covariance

- The routes always add up to the **model-implied** covariance. ML reproduces
  the sample covariance (divisor N) only for a saturated model (Bollen, 1989,
  pp. 107, 133, 281; Kline, 2023, pp. 133, 145).
- The likelihood must also use only means and covariances and weight all
  observations equally. Each of these breaks that:
  - missing data;
  - unequal numbers of days;
  - random slopes. *Our simulation:* a random-intercept model reproduced the
    total variance exactly; a random-slope model did not (0.7% off in one
    simulated run; ML, equal days, complete data).
- With missing data, a saturated model reproduces the unrestricted FIML
  estimates, not a sample covariance; FIML uses a likelihood for each case, so
  there is no single sample covariance (Kline, 2023, p. 135). Under MAR, that
  is the better target (Rubin, 1976; Arbuckle, 1996, p. 246; Enders &
  Bandalos, 2001; Enders, 2022; Little & Rubin, 2019, p. 134).
- Complete-case regression is still unbiased when missingness depends only on
  the predictors, not on the outcome (Enders, 2022, p. 35; Little & Rubin,
  2019, p. 49).
- Report the implied covariance next to the observed one where data are
  complete, as a check of fit.

## 4. Splitting the levels

- Person-mean centre the predictor and add the person mean at level 2. The two
  coefficients then estimate the within and between effects (Curran & Bauer,
  2011; Hoffman & Stawski, 2009; Wang & Maxwell, 2015; for cross-sectional
  data, Enders & Tofighi, 2007, pp. 127–128).
- If predictors or outcomes trend over the diary days, detrend first. The
  deviation from the person mean would otherwise mix trend and daily change
  (Curran & Bauer, 2011; Wang & Maxwell, 2015; Hamaker et al., 2018, p. 836).
- Dyadic diary model: two intercepts, correlated couple-level random
  intercepts and a same-day residual covariance (Laurenceau & Bolger, 2005,
  pp. 94–95, adapting the growth-curve model of Raudenbush et al., 1995; Kenny
  et al., 2006, chs. 4 and 13; Bolger & Laurenceau, 2013, ch. 8).

**Separate fits per level**

- Each level's routes plus its residual add up exactly to that level's
  covariance.
- Within + between = raw covariance, exactly only with equal days. With
  unequal days, the identity needs the between covariance weighted by days
  (Robinson, 1950, p. 355; Bliese, 2022, Section 3.4.1).

**One joint model**

- The within paths equal the fixed-effects estimator (Mundlak, 1978 [not
  seen]; Bell & Jones, 2015; Hamaker & Muthén, 2020). Equal days are not
  needed, but the person means must be computed over the analysed days
  (Wooldridge, 2019 [abstract]; Wooldridge, 2025).
- *Our check:* in dyads this is exact only when both partners have the same
  analysed days.
- *Our derivation and simulation:* the outcome's between part is a random
  intercept, so it is latent. About 1/T of the within residual covariance
  moves from between to within, and the total stays the same.
- Random slopes break this equivalence: the centred and Mundlak models are
  then different models (Hamaker & Muthén, 2020, p. 374).

## 5. Observed vs latent person means

**Reliability of person means**

- An observed person mean contains day-to-day noise. Its reliability is
  λ = τ / (τ + σ²/T), the Spearman–Brown step-up of the ICC (Lüdtke et al.,
  2008, Eq. 6; Gottfredson, 2019). It is called ICC(1,k) in Shrout and Fleiss (1979,
  p. 426) and ICC(2) in Bliese (2000) [not seen].
- Positive autocorrelation makes the mean noisier than σ²/T, so λ is
  overstated; Gottfredson (2019, Limitations) names no autocorrelation as an
  assumption. Use an effective T* < T (Asparouhov & Muthén, 2019, Eqs. 81–83).
- With MAR missing days, the bias of observed means does not shrink with more
  days (Asparouhov & Muthén, 2019, pp. 2, 21–22).

**Bias of the between paths**

- In the person-mean-centred model, the observed-mean between path is
  λ·b_between + (1 − λ)·b_within. So it is pulled toward the within path, not
  toward zero, and the contextual effect shrinks by λ (Lüdtke et al., 2008,
  Eqs. 7–8; Asparouhov & Muthén, 2019, Eqs. 51–53; Grilli & Rampichini, 2011
  [abstract]). This is a large-sample result.
- *Our derivation:* for the routes this means:
  - the explained between covariance shrinks by λ only when the within paths
    are zero (one predictor);
  - with equal within and between paths, observed means explain more (much
    more with few days, little with many), because the noise in the means
    carries the within-level explained covariance divided by T;
  - with actor and partner means together, the slopes are
    (Σ_B + Σ_W/T)⁻¹(Σ_B b_B + Σ_W/T · b_W). The bias can then move
    covariance between actor and partner routes. Example (T = 5,
    between-level actor and partner predictors correlated .8, uncorrelated
    within parts, no within effects): a true between partner path of 0 came
    out as 0.24. Correlated mean errors (from the same-day partner covariance)
    add to this.

**The latent alternative**

- Two-level SEM splits each variable into latent within and between parts
  (Muthén, 1994; Preacher et al., 2010, p. 215; Asparouhov & Muthén, 2019). In
  lavaan this is available with missing data (Rosseel, 2021).
- Latent means are less biased but more variable. With few couples, few days
  per person and a low ICC together, observed means can be more accurate
  (Lüdtke et al., 2008). With limited level-2 information, partial correction
  can also beat full correction (Lüdtke et al., 2011 [abstract]).
- In diary data, the advantage of latent centring was clear at T = 4 and gone
  at T = 40 (Hamaker & Muthén, 2020, pp. 373, 376). T&T has a median of 50
  days, so expect small differences, except for predictors with a low ICC.

**Correcting by hand**

- With equal days, Σ_B = Cov(observed means) − S_PW / T, where S_PW is the
  pooled within covariance matrix (Muthén, 1994, Eqs. 16–19; Muthén, 1989, Eq.
  39). Decompose that matrix. Snijders and Bosker (2012, Example 3.7) do the
  same for a covariance [not seen].
- With unequal days, use the size-weighted S_B and Muthén's c (Muthén, 1994,
  Eqs. 16–19); MUML inference is then only approximate (Yuan & Hayashi, 2005
  [abstract]). It can give a non-positive-definite Σ_B with few clusters or a
  low ICC (Muthén, 1994, p. 389; Hox & Maas, 2001 [abstract]). It also assumes
  no autocorrelation.

## 6. A covariance analog of the ICC

- The between share is Cov_between / (Cov_between + Cov_within). It equals the
  between share of the correlation:
  r_total = √(ICC₁ICC₂)·r_between + √((1 − ICC₁)(1 − ICC₂))·r_within.
  - Population (latent) version: Tu et al. (2025, Eq. 2); Muthén (1994, Eq.
    7).
  - Sample version, with observed correlation ratios η and a between
    correlation weighted by group size: Robinson (1950, p. 355). Also the WABA
    "covariance theorem" (Bliese, 2022, Section 3.4.1; Dansereau et al., 1984
    [not seen]).
- Use the latent parts: observed η² is not the ICC (Bliese & Halverson, 1998).
- The share is not a proportion. With opposite signs at the two levels, one
  share is negative and the other above 1, and near a zero total it is
  unstable. Examples: Robinson (1950, p. 354, nativity example); Kievit et al.
  (2013); Bakdash and Marusich (2017).
- No established name was found. The closest analog is "bivariate
  heritability", the genetic share of a covariance, which differs from the
  genetic correlation (de Vries et al., 2021). Shares above 100% are reported
  there too (Arpegård et al., 2015).
- Related dyadic work splits correlations into individual and dyad levels
  (Griffin & Gonzalez, 1995; Gonzalez & Griffin, 1999, 2002; Kenny & La Voie,
  1985 [not seen]).
- With random slopes there is no single ICC; the partition depends on the
  predictor values (Goldstein et al., 2002).
- Optional: standardize the routes within each level, as Kenny does, and apply
  the weights above. The routes then add up to r_total.

## 7. Random slopes (extension)

- Each route becomes (path₁·path₂ + Cov(path₁ᵢ, path₂ᵢ)) × variance or
  covariance. E(aᵢbᵢ) = ab + σ_ab needs no distributional assumption (Bauer et
  al., 2006, Eq. 5; Kenny et al., 2003 [abstract]; Goodman, 1960 [not seen]).
  A diary example is in Bolger and Laurenceau (2013, ch. 9, pp. 190, 224).
- Conditions:
  - Fit both outcomes jointly, or the slope covariance cannot be estimated
    (Bauer et al., 2006, Eq. 4).
  - Centre on the person means. Then the slope part is purely within (Rights &
    Sterba, 2019, Eqs. 10, 13, 16), and intercept–slope covariances drop out
    (*our simulation*).
  - *Our derivation:* the slopes must be unrelated to each couple's predictor
    variances and covariances.
- The variance analog is the "v" component tr(TΣ) (Rights & Sterba, 2019;
  Johnson, 2014).
- The partner covariance then depends on the day's predictor values (Goldstein
  et al., 2002). So the model no longer reproduces the observed covariance
  exactly.
- Put random slopes on the within part only (Mplus User's Guide, Example 9.2,
  p. 276). Conflated slopes distort the slope variance (Rights & Sterba, 2023
  [abstract]). Note: Kenny et al. (2006, p. 357) grand-mean centre in their
  over-time APIM.
- Cross-partner slope covariances already appear in dyadic diary models (Kenny
  et al., 2006, ch. 13, pp. 343, 346; Bolger & Laurenceau, 2013, Eq. 8.10,
  slope r = .52; Laurenceau & Bolger, 2005, Table 3; Savord et al., 2023,
  master list, random slopes in a DSEM L-APIM). Cross-sectional dyads cannot
  have random slopes (Kenny et al., 2006, p. 89).
- Software:
  - lavaan has random slopes since 0.7-2 via `rv()`. An observed predictor
    with a random slope must be within-only, which means observed person
    means; latent within predictors use quadrature (lavaan tutorial; Rockwood,
    2020 [abstract]).
  - With latent centring and random slopes there is no closed-form likelihood
    (Asparouhov & Muthén, 2019). Mplus uses Bayes for this.
  - The full random-effect covariance matrix is needed (Asparouhov & Muthén,
    2024).
  - Six random effects per couple means 21 variances and covariances, so
    convergence is a risk with 158 couples.

## 8. Inference

- Couple bootstrap: resample couples with all their days, refit, and take
  percentile CIs.
  - Sources: Field and Welsh (2007 [abstract]; theory for one level of
    clustering); Ren et al. (2010 [abstract]); Loy and Korobova (2023, pp.
    104–105).
  - Validity grows with the number of couples, not days. The bootstrap needs
    no model of day-to-day dependence (Cameron & Miller, 2015).
  - In 2012 there was "no agreed-upon best way" to bootstrap multilevel models
    (Preacher & Selig, 2012, p. 94).
- Use percentile, not bias-corrected, intervals. Bias-corrected and BCa
  intervals inflate Type I error in small samples (Fritz et al., 2012
  [abstract]).
- Products of estimates are not normal (MacKinnon et al., 2004 [abstract];
  Preacher & Selig, 2012, p. 79).
- Monte Carlo CIs extend to any function of estimates (Tofighi & MacKinnon,
  2016 [abstract]). In glmmTMB, though, the predictor moments are not model
  parameters, so their sampling distribution must come from elsewhere.

## 9. Day-to-day dependence

- Diary days are autocorrelated and can trend. Residual DSEM puts the
  autocorrelation into the residuals and keeps the meaning of the same-day
  paths (Asparouhov et al., 2018, p. 364). A model with lagged outcomes
  changes what the same-day residual covariance means.
- Ignoring trends can change results "starkly" (Hamaker et al., 2018, p. 836).
  For dyadic detrending see Xiao and Liu (2025 [abstract]).
- A misspecified within-person error structure can inflate random-effect
  variances (Kwok et al., 2007 [abstract]).
- Observed centring with lagged outcomes adds Nickell's bias (Asparouhov et
  al., 2018, p. 368; Hamaker & Grasman, 2015 [abstract]; McNeish & Hamaker,
  2020).
- For a same-day decomposition: point estimates are fine, the couple bootstrap
  handles inference, and autocorrelation matters for the reliability of person
  means (Section 5).

## 10. Software and measurement notes

**glmmTMB** (Brooks et al., 2017)
- `us()` plus `dispformula = ~0` moves the residual covariance into the random
  effects. The residual variance is fixed at about 1.5e-8. This works for the
  Gaussian family only (covstruct vignette; `?glmmTMB`).
- Rows with a missing predictor are dropped. In long format, a missing partner
  predictor drops that day for both partners (Kenny et al., 2006, p. 158;
  Enders, 2022, p. 343).
- Alternatives for missing predictors: multilevel multiple imputation (Grund
  et al., 2018; Enders et al., 2020).

**lavaan** (Rosseel, 2012; package: Rosseel et al., 2026)
- Two-level SEM since 0.6-1. FIML with missing data since 0.6-9 (Rosseel,
  2021).
- With the default `fixed.x = TRUE`, cases with a missing predictor are
  dropped even with `missing = "ml"`. Use `fixed.x = FALSE` (named `fixed_x`
  from 0.7-2) or `"ml.x"`.
- For bootstrapping, `cluster =` resamples whole clusters.

**MLM vs SEM**
- Same APIM estimates with ML, given the same cases, separate variances and a
  free residual covariance (Kenny et al., 2006, p. 169, shown for
  indistinguishable dyads; Hong & Kim, 2019 [abstract], 'virtually identical'
  in one example). Ledermann and Kenny (2017) compare the two methods, but the
  equality statement was not seen there.

**Measurement error**
- With correlated predictors, error in one predictor can bias other paths in
  either direction (Bollen, 1989, pp. 165–166; Kline, 2023, pp. 27, 107; Cole
  & Preacher, 2014).
- Error only in the outcome does not bias unstandardized paths (Kline, 2023,
  p. 25). Shared-method error between partners would inflate the residual
  covariance ψ.
- See also Westfall and Yarkoni (2016).

## 11. Steps in explore-ild.Rmd

1. Choose the outcome and predictor, and how to tell partners apart. Check
   trends and missing days.
2. Centre by hand on days both partners answered.
3. glmmTMB, one model per level: decompose, check the sums against the
   observed covariances.
4. glmmTMB, joint model: compare with step 3 (paths, the 1/T shift).
5. Covariance share by level, and routes as shares of each level and of the
   total.
6. lavaan two-level with latent means. Compare:
   - the between paths with λ·b_between + (1 − λ)·b_within, and the
     two-predictor (matrix) version;
   - with the by-hand corrected Σ_B;
   - λ with and without autocorrelation.
7. Couple bootstrap CIs.
8. Optional: random slopes, glmmTMB and lavaan `rv()`.

## 12. To check in the library

- Snijders and Bosker (2012), Section 3.6 and Example 3.7.
- Raudenbush and Bryk (2002), p. 143 and the reliability formula.
- Kenny and La Voie (1985).
- Ledermann and Kenny (2017), on MLM–SEM equality.
- Bliese (2000).
- Mundlak (1978).
- Dansereau et al. (1984).

## References

Arbuckle, J. L. (1996). Full information estimation in the presence of incomplete data. In G. A. Marcoulides & R. E. Schumacker (Eds.), *Advanced structural equation modeling: Issues and techniques* (pp. 243–277). Erlbaum.

Arpegård, J., Viktorin, A., Chang, Z., de Faire, U., Magnusson, P. K. E., & Svensson, P. (2015). Comparison of heritability of cystatin C- and creatinine-based estimates of kidney function and their relation to heritability of cardiovascular disease. *Journal of the American Heart Association, 4*(1), e001467. https://doi.org/10.1161/JAHA.114.001467

Asparouhov, T., & Muthén, B. (2019). Latent variable centering of predictors and mediators in multilevel and time-series models. *Structural Equation Modeling, 26*(1), 119–142. https://doi.org/10.1080/10705511.2018.1511375 (page and equation numbers from the online-first PDF)

Asparouhov, T., & Muthén, B. (2024). *Covariance of random effects in multilevel modeling* (Mplus Web Note No. 24, Version 1, October 17, 2024). Muthén & Muthén.

Asparouhov, T., Hamaker, E. L., & Muthén, B. (2018). Dynamic structural equation models. *Structural Equation Modeling, 25*(3), 359–388. https://doi.org/10.1080/10705511.2017.1406803

Bakdash, J. Z., & Marusich, L. R. (2017). Repeated measures correlation. *Frontiers in Psychology, 8*, 456. https://doi.org/10.3389/fpsyg.2017.00456

Bauer, D. J., Preacher, K. J., & Gil, K. M. (2006). Conceptualizing and testing random indirect effects and moderated mediation in multilevel models: New procedures and recommendations. *Psychological Methods, 11*(2), 142–163. https://doi.org/10.1037/1082-989X.11.2.142

Bell, A., & Jones, K. (2015). Explaining fixed effects: Random effects modeling of time-series cross-sectional and panel data. *Political Science Research and Methods, 3*(1), 133–153. https://doi.org/10.1017/psrm.2014.7

Bliese, P. D. (2000). Within-group agreement, non-independence, and reliability: Implications for data aggregation and analysis. In K. J. Klein & S. W. J. Kozlowski (Eds.), *Multilevel theory, research, and methods in organizations: Foundations, extensions, and new directions* (pp. 349–381). Jossey-Bass. *[not seen]*

Bliese, P. D. (2022). *Multilevel modeling in R (2.7): A brief introduction to R, the multilevel package and the nlme package*. https://cran.r-project.org/doc/contrib/Bliese_Multilevel.pdf

Bliese, P. D., & Halverson, R. R. (1998). Group size and measures of group-level properties: An examination of eta-squared and ICC values. *Journal of Management, 24*(2), 157–172. https://doi.org/10.1177/014920639802400202 *[abstract]*

Bolger, N., & Laurenceau, J.-P. (2013). *Intensive longitudinal methods: An introduction to diary and experience sampling research*. Guilford Press.

Bollen, K. A. (1989). *Structural equations with latent variables*. Wiley. https://doi.org/10.1002/9781118619179

Brooks, M. E., Kristensen, K., van Benthem, K. J., Magnusson, A., Berg, C. W., Nielsen, A., Skaug, H. J., Mächler, M., & Bolker, B. M. (2017). glmmTMB balances speed and flexibility among packages for zero-inflated generalized linear mixed modeling. *The R Journal, 9*(2), 378–400. https://doi.org/10.32614/RJ-2017-066

Cameron, A. C., & Miller, D. L. (2015). A practitioner's guide to cluster-robust inference. *Journal of Human Resources, 50*(2), 317–372. https://doi.org/10.3368/jhr.50.2.317

Cole, D. A., & Preacher, K. J. (2014). Manifest variable path analysis: Potentially serious and misleading consequences due to uncorrected measurement error. *Psychological Methods, 19*(2), 300–315. https://doi.org/10.1037/a0033805 *[abstract]*

Curran, P. J., & Bauer, D. J. (2011). The disaggregation of within-person and between-person effects in longitudinal models of change. *Annual Review of Psychology, 62*, 583–619. https://doi.org/10.1146/annurev.psych.093008.100356

Dansereau, F., Alutto, J. A., & Yammarino, F. J. (1984). *Theory testing in organizational behavior: The varient approach*. Prentice-Hall. *[not seen]*

de Vries, L. P., van Beijsterveldt, T. C. E. M., Maes, H., Colodro-Conde, L., & Bartels, M. (2021). Genetic influences on the covariance and genetic correlations in a bivariate twin model: An application to well-being. *Behavior Genetics, 51*(3), 191–203. https://doi.org/10.1007/s10519-021-10046-y

Enders, C. K. (2022). *Applied missing data analysis* (2nd ed.). Guilford Press.

Enders, C. K., & Bandalos, D. L. (2001). The relative performance of full information maximum likelihood estimation for missing data in structural equation models. *Structural Equation Modeling, 8*(3), 430–457. https://doi.org/10.1207/S15328007SEM0803_5 *[abstract]*

Enders, C. K., Du, H., & Keller, B. T. (2020). A model-based imputation procedure for multilevel regression models with random coefficients, interaction effects, and nonlinear terms. *Psychological Methods, 25*(1), 88–112. https://doi.org/10.1037/met0000228 *[abstract]*

Enders, C. K., & Tofighi, D. (2007). Centering predictor variables in cross-sectional multilevel models: A new look at an old issue. *Psychological Methods, 12*(2), 121–138. https://doi.org/10.1037/1082-989X.12.2.121

Field, C. A., & Welsh, A. H. (2007). Bootstrapping clustered data. *Journal of the Royal Statistical Society: Series B (Statistical Methodology), 69*(3), 369–390. https://doi.org/10.1111/j.1467-9868.2007.00593.x *[abstract]*

Fritz, M. S., Taylor, A. B., & MacKinnon, D. P. (2012). Explanation of two anomalous results in statistical mediation analysis. *Multivariate Behavioral Research, 47*(1), 61–87. https://doi.org/10.1080/00273171.2012.640596 *[abstract]*

Goldstein, H., Browne, W., & Rasbash, J. (2002). Partitioning variation in multilevel models. *Understanding Statistics, 1*(4), 223–231. https://doi.org/10.1207/S15328031US0104_02

Gonzalez, R., & Griffin, D. (2002). Modeling the personality of dyads and groups. *Journal of Personality, 70*(6), 901–924. https://doi.org/10.1111/1467-6494.05027 *[abstract]*

Goodman, L. A. (1960). On the exact variance of products. *Journal of the American Statistical Association, 55*(292), 708–713. https://doi.org/10.1080/01621459.1960.10483369 *[not seen]*

Gottfredson, N. C. (2019). A straightforward approach for coping with unreliability of person means when parsing within-person and between-person effects in longitudinal studies. *Addictive Behaviors, 94*, 156–161. https://doi.org/10.1016/j.addbeh.2018.09.031

Grilli, L., & Rampichini, C. (2011). The role of sample cluster means in multilevel models. *Methodology, 7*(4), 121–133. https://doi.org/10.1027/1614-2241/a000030 *[abstract]*

Grund, S., Lüdtke, O., & Robitzsch, A. (2018). Multiple imputation of missing data for multilevel models: Simulations and recommendations. *Organizational Research Methods, 21*(1), 111–149. https://doi.org/10.1177/1094428117703686 *[abstract]*

Hamaker, E. L., & Grasman, R. P. P. P. (2015). To center or not to center? Investigating inertia with a multilevel autoregressive model. *Frontiers in Psychology, 5*, 1492. https://doi.org/10.3389/fpsyg.2014.01492 *[abstract]*

Hamaker, E. L., & Muthén, B. (2020). The fixed versus random effects debate and how it relates to centering in multilevel modeling. *Psychological Methods, 25*(3), 365–379. https://doi.org/10.1037/met0000239

Hamaker, E. L., Asparouhov, T., Brose, A., Schmiedek, F., & Muthén, B. (2018). At the frontiers of modeling intensive longitudinal data: Dynamic structural equation models for the affective measurements from the COGITO study. *Multivariate Behavioral Research, 53*(6), 820–841. https://doi.org/10.1080/00273171.2018.1446819

Hoffman, L., & Stawski, R. S. (2009). Persons as contexts: Evaluating between-person and within-person effects in longitudinal analysis. *Research in Human Development, 6*(2–3), 97–120. https://doi.org/10.1080/15427600902911189 *[abstract]*

Hong, S., & Kim, S. (2019). Comparisons of multilevel modeling and structural equation modeling approaches to actor-partner interdependence model. *Psychological Reports, 122*(2), 558–574. https://doi.org/10.1177/0033294118766608 *[abstract]*

Hox, J. J., & Maas, C. J. M. (2001). The accuracy of multilevel structural equation modeling with pseudobalanced groups and small samples. *Structural Equation Modeling, 8*(2), 157–174. https://doi.org/10.1207/S15328007SEM0802_1 *[abstract]*

Johnson, P. C. D. (2014). Extension of Nakagawa & Schielzeth's R²GLMM to random slopes models. *Methods in Ecology and Evolution, 5*(9), 944–946. https://doi.org/10.1111/2041-210X.12225

Kenny, D. A. (1979). *Correlation and causality*. Wiley.

Kenny, D. A., Kashy, D. A., & Cook, W. L. (2006). *Dyadic data analysis*. Guilford Press.

Kenny, D. A., Korchmaros, J. D., & Bolger, N. (2003). Lower level mediation in multilevel models. *Psychological Methods, 8*(2), 115–128. https://doi.org/10.1037/1082-989X.8.2.115 *[abstract]*

Kenny, D. A., & La Voie, L. (1985). Separating individual and group effects. *Journal of Personality and Social Psychology, 48*(2), 339–348. https://doi.org/10.1037/0022-3514.48.2.339 *[not seen]*

Kievit, R. A., Frankenhuis, W. E., Waldorp, L. J., & Borsboom, D. (2013). Simpson's paradox in psychological science: A practical guide. *Frontiers in Psychology, 4*, 513. https://doi.org/10.3389/fpsyg.2013.00513

Kline, R. B. (2023). *Principles and practice of structural equation modeling* (5th ed.). Guilford Press.

Kristensen, K., McGillycuddy, M., & Williams, C. (2026). *Covariance structures with glmmTMB* [Vignette, glmmTMB 1.1.15.2]. https://cran.r-project.org/web/packages/glmmTMB/vignettes/covstruct.html

Kwok, O., West, S. G., & Green, S. B. (2007). The impact of misspecifying the within-subject covariance structure in multiwave longitudinal multilevel models: A Monte Carlo study. *Multivariate Behavioral Research, 42*(3), 557–592. https://doi.org/10.1080/00273170701540537 *[abstract]*

lavaan project. (n.d.). *Multilevel SEM* [Tutorial]. Retrieved October 9, 2026, from https://lavaan.ugent.be/tutorial/multilevel.html

Laurenceau, J.-P., & Bolger, N. (2005). Using diary methods to study marital and family processes. *Journal of Family Psychology, 19*(1), 86–97. https://doi.org/10.1037/0893-3200.19.1.86

Ledermann, T., & Kenny, D. A. (2017). Analyzing dyadic data with multilevel modeling versus structural equation modeling: A tale of two methods. *Journal of Family Psychology, 31*(4), 442–452. https://doi.org/10.1037/fam0000290 *[abstract]*

Little, R. J. A., & Rubin, D. B. (2019). *Statistical analysis with missing data* (3rd ed.). Wiley. https://doi.org/10.1002/9781119482260

Loehlin, J. C., & Beaujean, A. A. (2017). *Latent variable models: An introduction to factor, path, and structural equation analysis* (5th ed.). Routledge. https://doi.org/10.4324/9781315643199

Loy, A., & Korobova, J. (2023). Bootstrapping clustered data in R using lmeresampler. *The R Journal, 14*(4), 103–120. https://doi.org/10.32614/RJ-2023-015

Lüdtke, O., Marsh, H. W., Robitzsch, A., & Trautwein, U. (2011). A 2 × 2 taxonomy of multilevel latent contextual models: Accuracy–bias trade-offs in full and partial error correction models. *Psychological Methods, 16*(4), 444–467. https://doi.org/10.1037/a0024376 *[abstract]*

Lüdtke, O., Marsh, H. W., Robitzsch, A., Trautwein, U., Asparouhov, T., & Muthén, B. (2008). The multilevel latent covariate model: A new, more reliable approach to group-level effects in contextual studies. *Psychological Methods, 13*(3), 203–229. https://doi.org/10.1037/a0012869 (equation numbers from the 2007 author draft)

MacKinnon, D. P., Lockwood, C. M., & Williams, J. (2004). Confidence limits for the indirect effect: Distribution of the product and resampling methods. *Multivariate Behavioral Research, 39*(1), 99–128. https://doi.org/10.1207/s15327906mbr3901_4 *[abstract]*

Marsh, H. W., Lüdtke, O., Robitzsch, A., Trautwein, U., Asparouhov, T., Muthén, B., & Nagengast, B. (2009). Doubly-latent models of school contextual effects: Integrating multilevel and structural equation approaches to control measurement and sampling error. *Multivariate Behavioral Research, 44*(6), 764–802. https://doi.org/10.1080/00273170903333665 *[abstract]*

McNeish, D., & Hamaker, E. L. (2020). A primer on two-level dynamic structural equation models for intensive longitudinal data in Mplus. *Psychological Methods, 25*(5), 610–635. https://doi.org/10.1037/met0000250

Mundlak, Y. (1978). On the pooling of time series and cross section data. *Econometrica, 46*(1), 69–85. https://doi.org/10.2307/1913646 *[not seen]*

Muthén, B. O. (1989). Latent variable modeling in heterogeneous populations. *Psychometrika, 54*(4), 557–585. https://doi.org/10.1007/BF02296397

Muthén, B. O. (1994). Multilevel covariance structure analysis. *Sociological Methods & Research, 22*(3), 376–398. https://doi.org/10.1177/0049124194022003006

Muthén, L. K., & Muthén, B. O. (1998–2017). *Mplus user's guide* (8th ed.). Muthén & Muthén.

Preacher, K. J., & Selig, J. P. (2012). Advantages of Monte Carlo confidence intervals for indirect effects. *Communication Methods and Measures, 6*(2), 77–98. https://doi.org/10.1080/19312458.2012.679848

Preacher, K. J., Zyphur, M. J., & Zhang, Z. (2010). A general multilevel SEM framework for assessing multilevel mediation. *Psychological Methods, 15*(3), 209–233. https://doi.org/10.1037/a0020141

Raudenbush, S. W., Brennan, R. T., & Barnett, R. C. (1995). A multivariate hierarchical model for studying psychological change within married couples. *Journal of Family Psychology, 9*(2), 161–174. https://doi.org/10.1037/0893-3200.9.2.161 *[abstract]*

Raudenbush, S. W., & Bryk, A. S. (2002). *Hierarchical linear models: Applications and data analysis methods* (2nd ed.). Sage. *[not seen]*

Ren, S., Lai, H., Tong, W., Aminzadeh, M., Hou, X., & Lai, S. (2010). Nonparametric bootstrapping for hierarchical data. *Journal of Applied Statistics, 37*(9), 1487–1498. https://doi.org/10.1080/02664760903046102 *[abstract]*

Rights, J. D., & Sterba, S. K. (2019). Quantifying explained variance in multilevel models: An integrative framework for defining R-squared measures. *Psychological Methods, 24*(3), 309–338. https://doi.org/10.1037/met0000184

Rights, J. D., & Sterba, S. K. (2023). On the common but problematic specification of conflated random slopes in multilevel models. *Multivariate Behavioral Research, 58*(6), 1106–1133. https://doi.org/10.1080/00273171.2023.2174490 *[abstract]*

Robinson, W. S. (1950). Ecological correlations and the behavior of individuals. *American Sociological Review, 15*(3), 351–357. https://doi.org/10.2307/2087176

Rockwood, N. J. (2020). Maximum likelihood estimation of multilevel structural equation models with random slopes for latent covariates. *Psychometrika, 85*(2), 275–300. https://doi.org/10.1007/s11336-020-09702-9 *[abstract]*

Rosseel, Y. (2012). lavaan: An R package for structural equation modeling. *Journal of Statistical Software, 48*(2), 1–36. https://doi.org/10.18637/jss.v048.i02

Rosseel, Y. (2021). Evaluating the observed log-likelihood function in two-level structural equation modeling with missing data: From formulas to R code. *Psych, 3*(2), 197–232. https://doi.org/10.3390/psych3020017

Rosseel, Y., Jorgensen, T. D., & De Wilde, L. (2026). *lavaan: Latent variable analysis* (Version 0.7-3) [R package]. https://doi.org/10.32614/CRAN.package.lavaan

Rubin, D. B. (1976). Inference and missing data. *Biometrika, 63*(3), 581–592. https://doi.org/10.1093/biomet/63.3.581 *[abstract]*

Shrout, P. E., & Fleiss, J. L. (1979). Intraclass correlations: Uses in assessing rater reliability. *Psychological Bulletin, 86*(2), 420–428. https://doi.org/10.1037/0033-2909.86.2.420

Snijders, T. A. B., & Bosker, R. J. (2012). *Multilevel analysis: An introduction to basic and advanced multilevel modeling* (2nd ed.). Sage. *[not seen]*

Tofighi, D., & MacKinnon, D. P. (2016). Monte Carlo confidence intervals for complex functions of indirect effects. *Structural Equation Modeling, 23*(2), 194–205. https://doi.org/10.1080/10705511.2015.1057284 *[abstract]*

Tu, S., Li, C., & Shepherd, B. E. (2025). Between- and within-cluster Spearman rank correlations. *Statistics in Medicine, 44*(3–4), e10326. https://doi.org/10.1002/sim.10326 (equation number from arXiv:2402.11341v2)

Wang, L. P., & Maxwell, S. E. (2015). On disaggregating between-person and within-person effects with longitudinal data using multilevel models. *Psychological Methods, 20*(1), 63–83. https://doi.org/10.1037/met0000030 *[abstract]*

Westfall, J., & Yarkoni, T. (2016). Statistically controlling for confounding constructs is harder than you think. *PLOS ONE, 11*(3), e0152719. https://doi.org/10.1371/journal.pone.0152719 *[abstract]*

Wooldridge, J. M. (2019). Correlated random effects models with unbalanced panels. *Journal of Econometrics, 211*(1), 137–150. https://doi.org/10.1016/j.jeconom.2018.12.010 *[abstract]*

Wooldridge, J. M. (2025). Two-way fixed effects, the two-way Mundlak regression, and difference-in-differences estimators. *Empirical Economics, 69*(5), 2545–2587. https://doi.org/10.1007/s00181-025-02807-z (read as the 2021 preprint)

Wright, S. (1921). Correlation and causation. *Journal of Agricultural Research, 20*(7), 557–585.

Xiao, Y., & Liu, H. (2025). Detrending for intensive longitudinal dyadic data analysis using DSEM. *Structural Equation Modeling, 32*(3), 450–459. https://doi.org/10.1080/10705511.2024.2442980 *[abstract]*

Yuan, K.-H., & Hayashi, K. (2005). On Muthén's maximum likelihood for two-level covariance structure models. *Psychometrika, 70*(1), 147–167. https://doi.org/10.1007/s11336-003-1070-8 *[abstract]*

From the master list (checked there): Bolger and Shrout (2007);
Cornelius et al. (2022); Gistelinck and Loeys (2019, 2020); Gonzalez and
Griffin (1999); Griffin and Gonzalez (1995); Helm et al. (2018); Kenny,
Ackerman and Kashy (2024); Laurenceau, DiGiovanni and Bolger (2026); Savord
et al. (2023).
