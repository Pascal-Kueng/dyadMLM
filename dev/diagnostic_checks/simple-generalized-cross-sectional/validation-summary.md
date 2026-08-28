# Validation summary

## Scope and provenance

This is engineering and directional simulation validation of the simple
generalized implementation. It is not a calibration study and does not turn
observed positions into p-values.

- Date: 2026-08-28
- R: 4.6.1
- `glmmTMB`: 1.1.14
- production implementation: `simple-generalized-checks` commit `022681a`
- PR #18 baseline: `b385774`
- retired complex prototype used for the historical comparison: `b9d2c02`
- outer study: 6 repetitions, 120 dyads, and 199 simulations per fitted model
- families: Poisson, NB1, NB2, Tweedie, Gamma, and beta
- fitted models: correct shared dyad effect versus that effect omitted
- response views: raw and model-centred, reusing one simulation bank

The executable study is self-contained and validates only the selected
implementation. The historical implementation comparison described below was
a one-time promotion check and is deliberately not rerun.

## Historical regression and comparison

All 22 deterministic comparisons executed on 2026-08-28 were exactly true.

- Seven Gaussian comparisons established exact equality with PR #18 for the
  observed response, simulation matrix, centre, raw and model-centred
  statistics, and summary tables.
- Fifteen NB1, NB2, and Tweedie comparisons established exact equality with the
  complex prototype for simulation matrices and raw statistics/summaries.
- For those three generalized families, model-centred observed and simulated
  statistics also equalled independent hand calculations after subtracting
  `predict(type = "response", re.form = NA)`.

This was useful migration evidence, not an enduring dependency. The simple
production patch changed 200 inserted and 63 deleted lines relative to PR #18;
the complex prototype changed 514 inserted and 139 deleted lines. The selected
implementation therefore changed about 60% fewer production lines and avoided
a separate capability module and family-specific diagnostic paths.

## Outer-study behavior

The recorded study produced 72 fitted models and 144 diagnostic results in
`outer-study-results.csv`. There were no fit, simulation, or diagnostic
errors.

- All 36 raw and all 36 model-centred checks from correctly specified models
  placed the observed partner correlation inside the middle 95% of the
  simulated reference.
- With the shared dyad effect omitted, 35 of 36 raw checks and all 36
  model-centred checks placed the observed correlation above the upper
  simulated limit.
- The one raw miss was NB1, with an observed position of 0.955. This is
  compatible with a small directional study and does not define power.
- Seventy-one of 72 fits had convergence code zero and a positive-definite
  Hessian. The correct NB2 fit in repetition 6 had convergence code 1 and a
  non-positive-definite Hessian. It remains in the raw results and is not used
  as inferential evidence.

## Dispersion and sparse outcomes

The NB2 and Tweedie random-dispersion checks both converged with
positive-definite Hessians, exposed one dispersion random-effect term, exactly
matched the backend response prediction, and completed raw and model-centred
checks. Together with package coverage for
`dispformula = ~0 + role + (1 | batch)`, this validates ordinary supported
fixed and random dispersion formulas mechanically; it does not establish
random-dispersion parameter recovery.

The sparse Poisson check retained 198 of 199 defined partner correlations. It
completed with one consolidated warning stating the count and proportion, and
its reference used only those 198 values. Package tests also verify the more
extreme 19-of-21 case. There is intentionally no arbitrary percentage cutoff:
the observed statistic or an entirely undefined simulated reference causes an
error; partial simulated references are reported transparently.

## Lessons retained from the complex prototype

The old prototype's family-capability module, raw-only generalized policy,
duplicated family studies, timing tables, and 95%-defined-reference rule are
not part of the selected design.

Three lasting lessons are retained:

1. Variables used only in `dispformula` must still define fitted-row
   alignment; a focused package test covers this.
2. Dispersion-model random effects require `glmmTMB >= 1.1.10`, the first
   release supporting that model structure.
3. Shared dispersion or zero-pattern dependence can coexist with near-zero raw
   Pearson partner correlation. The simulation bank can support additional
   statistics, but no single selected statistic diagnoses every dependence
   mechanism.

## Interpretation and limits

The validated principle is:

```text
T(y - c) versus T(y_rep - c), using the same c and the same T
```

This is a valid fixed-estimate plug-in replicated-data comparison. For a
non-Gaussian family, the subtraction is not an orthogonal decomposition of
explained and unexplained variance. Pearson SD and correlation summaries do not
exhaust non-Gaussian dependence.

The branch does not support zero-inflated or hurdle models, binomial or
beta-binomial response adapters, intensive-longitudinal pairing or lag rules,
parameter uncertainty, refitting, or cross-validation.

Focused and full package tests and a clean source-package
`R CMD check --no-manual --ignore-vignettes` passed for the implementation.
