# Validation summary

## Scope and executed configuration

This is an engineering and directional simulation validation of the simple
generalized implementation. It is not a calibration study and does not turn
the observed positions into p-values.

- Date: 2026-08-28
- R: 4.6.1
- `glmmTMB`: 1.1.14
- branch: `simple-generalized-checks`, based on PR #18 SHA `b3857749`
- outer study: 6 repetitions, 120 dyads, 199 simulations per fitted model
- families: Poisson, NB1, NB2, Tweedie, Gamma, and beta
- fitted models: correct shared dyad effect versus the same effect omitted
- response views: raw and model-centred, reusing one simulation bank

Because the worktree is intentionally uncommitted, `session-record.txt` records
the baseline HEAD plus MD5 hashes of both production R files and the executed
study script.

The non-Poisson outer-study models used `dispformula = ~ 0 + role`. Separate
NB2 and Tweedie checks used `dispformula = ~ 0 + role + (1 | batch)`.

## Exact regression and parity

All 22 deterministic comparisons in `parity-results.csv` are `TRUE`.

- The Gaussian observed response, simulation matrix, centre, raw and centred
  replicated statistics, and complete summary tables are exactly identical to
  the implementation at PR #18 SHA `b3857749`.
- For NB1, NB2, and Tweedie, the simulation matrices, raw replicated
  statistics, and raw summary fields are exactly identical to the more complex
  `nbinom2-partner-prototype` branch.
- For those three non-Gaussian families, the simple branch's observed and
  simulated model-centred statistics are exactly equal to independent hand
  calculations after subtracting
  `predict(type = "response", re.form = NA)`.

This establishes that the simpler implementation changes neither the existing
Gaussian calculations nor the common raw generalized calculations.

## Outer-study behavior

The study produced 72 fitted models and 144 diagnostic results. There were no
fit errors, simulation errors, or diagnostic errors.

- All 36 raw and all 36 model-centred checks from the correctly specified
  models placed the observed partner correlation inside the middle 95% of the
  simulated reference.
- When the shared dyad effect was omitted, 35 of 36 raw checks and all 36
  model-centred checks placed the observed partner correlation above the upper
  simulated limit.
- The one raw miss was NB1; its observed position was still 0.955. This is
  compatible with a small directional study and does not define a power claim.
- Median observed positions for correctly specified models ranged from 0.325
  to 0.663 in the raw view and from 0.315 to 0.680 in the model-centred view.

Seventy-one of 72 fits had convergence code zero and a positive-definite
Hessian. The correct NB2 fit in repetition 6 had convergence code 1 and a
non-positive-definite Hessian; the warning is retained in the CSV. Diagnostic
computation still completed, but that fit should not be used as inferential
evidence. Excluding it does not change the directional conclusions above.

## Dispersion and sparse outcomes

The NB2 and Tweedie random-dispersion fits both had convergence code zero,
positive-definite Hessians, one detected dispersion random-effect term, and
successful raw and model-centred checks. Their stored centres exactly matched
the backend prediction. Together with the fixed role-specific dispersion cells
and package test using `~ 0 + role + (1 | batch)`, this confirms that the
diagnostic passes arbitrary supported dispersion formulas through to
`glmmTMB`; it does not need to parse or reproduce their terms.

In the real sparse Poisson check, 198 of 199 partner correlations were defined.
The diagnostic completed, omitted the one undefined replicate only for that
statistic, and emitted one explicit warning with the count and proportion.
Deterministic package tests verify that 19 of 21 defined values remain usable.
Printed and plotted references clearly state that they are conditional on
those 19 values. No arbitrary percentage cutoff is applied; an error occurs
only when the observed statistic or its entire simulated reference is
undefined.

## Comparison with the complex prototype

Across the production R files, this branch changes 200 inserted and 63 deleted
lines relative to PR #18. The complex prototype changes 514 inserted and 139
deleted production lines, including a separate 149-line family-capability
module. Thus the simple production patch changes about 60% fewer lines while
matching the common numerical results.

The simple version deliberately omits the prototype's separate family
capability module, response-domain metadata, family-parameter printing,
family-specific raw-only policy, and separate family implementations. A short
inline guard admits only the seven family/link pairs validated here, followed
by the common structural requirement of one finite numeric response per fitted
row and per simulation. Binomial and beta-binomial response formats are
explicitly deferred because they need an adapter; additional scalar families
can be added after backend prediction/simulation validation.

The simple implementation preserves the existing output schema and omits
undefined simulated values statistic by statistic. One warning reports the
number and proportion of affected datasets and statistics, and the printed and
plotted references state how many simulations were defined. It stops only when
the observed statistic or an entire simulated reference is undefined.

## Interpretation and remaining limits

The validation supports one general computational principle:

```text
T(y - c) versus T(y_rep - c), using the same c and the same T
```

This is a valid plug-in replicated-data comparison for the fitted model. For a
non-Gaussian family, it is not an orthogonal decomposition of explained and
unexplained variance. Pearson SD/correlation summaries also do not exhaust all
forms of non-Gaussian dependence; other statistics can be applied to the same
simulation bank later.

This branch does not support zero-inflated or hurdle models, binomial or
beta-binomial response adapters, intensive-longitudinal pairing/lag rules,
parameter uncertainty, refitting, or cross-validation.
