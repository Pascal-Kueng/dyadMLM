# Exploratory `brms` Partner-Dependence Path

Status: development prototype, not package support.

The prototype asks the same observable question as the current `glmmTMB`
check: does the fitted model generate complete datasets with partner spread and
association like those observed? The backend differs only in its reference.
`glmmTMB` conditions on fitted point estimates; `brms` draws parameters from the
posterior and generates new dyad effects and response noise.

## Current prototype

The implementation is in
[`brms-partner-prototype.R`](brms-partner-prototype.R). It supports only a plain
univariate Gaussian identity-link model with one ordinary dyad random
intercept and cross-sectional pairs. It rejects random slopes, other grouping
structures, autocorrelation, ILD, multivariate responses, response additions,
and generalized families.

The simulation object follows the package's normalized contract and is passed
directly to `check_partner_dependence()`. Pairing, response selection,
statistics, results, printing, and plotting are shared with `glmmTMB`; a second
package check wrapper is unnecessary.

For each posterior-predictive dataset, `posterior_predict()` uses one posterior
draw and generates a new effect for every dyad. The model-centred check
subtracts one fixed posterior-mean population-level expectation from observed
and replicated responses. For this Gaussian identity model, that centre is also
the marginal response mean for a new dyad. The raw check skips the subtraction.
Both use the same histogram contract as the current package check.

The prototype mirrors `brms` by using all retained posterior draws when
`nsim = NULL`; smaller requests are sampled without replacement. This is a
prototype convenience. The eventual public `simulate_dyad_responses()` method
should use the backend-neutral default `nsim = 1000`, with any all-draw option
made explicit.

## Evidence and remaining validation

Run [`brms-partner-prototype-smoke.R`](brms-partner-prototype-smoke.R) for the
small mechanics check. It verifies draw selection, fitted-row alignment,
new-dyad grouping, reproducibility, the covariate-varying fixed centre, both
response representations, and identity with the shared check machinery.

Run
[`brms-glmmtmb-partner-validation.R`](brms-glmmtmb-partner-validation.R) for the
fixed-seed substantive comparison. It uses 4,000 datasets per backend and now
asserts the 24 documented tail classifications before printing success. That is
implementation evidence, not a calibration study or evidence that the two
predictive references are identical.

Before package integration, add Gaussian validation for the structures taught
by `dyadMLM`:

- role-specific distinguishable covariance;
- exchangeable shared/difference covariance, including negative association;
- repeated same-occasion pairs; and
- clear rejection of unsupported nested, crossed, special, and temporal
  structures.

Promote only the validated Gaussian slice through the existing public
constructor. Preserve `reference = "posterior predictive"` and included
parameter uncertainty in the simulation object, then reuse the package checker
unchanged.

Generalized `brms` checks should start with `response = "raw"`. A centred path
requires a separately validated posterior marginal response mean over new
random effects under the nonlinear link. Draw-matched conditional centring,
such as a dyadic adaptation of
[Levy's approach](https://api.drum.lib.umd.edu/server/api/core/bitstreams/02308c91-cda7-4ef6-947e-19d1e433ff96/content),
asks a different question and has no current milestone.

Supporting and contrasting sources are indexed in the
[simulation-check reference library](../references/simulation_checks/README.md).
