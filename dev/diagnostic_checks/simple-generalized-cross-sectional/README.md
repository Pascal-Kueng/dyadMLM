# Simple generalized cross-sectional validation

This folder validates the deliberately small generalization of the
cross-sectional partner-dependence check. The production algorithm remains:

```text
raw:             T(y)       versus T(y_rep)
model-centred:   T(y - c)   versus T(y_rep - c)

c = predict(model, type = "response", re.form = NA)
```

The same simulated response bank and the same statistic are used on both sides.
There is no family-specific residual definition, analytic integration, or
family-specific implementation. The public spike is allow-listed to the seven
family/link pairs exercised by package or development validation.

`simulation-study.R` performs four checks:

1. exact numerical regression against PR #18 for Gaussian identity models;
2. exact raw-response parity with the more elaborate NB1/NB2/Tweedie
   prototype, plus an independent hand calculation of model-centred results;
3. a paired outer study for Poisson, NB1, NB2, Tweedie, Gamma, and beta models,
   comparing correctly modeled with omitted shared dyad dependence; and
4. mechanical fixed/random dispersion-formula and sparse-reference checks.

Run from the worktree root:

```r
source("dev/diagnostic_checks/simple-generalized-cross-sectional/simulation-study.R")
```

The defaults use 6 outer repetitions, 120 dyads, and 199 simulations per fit.
For a quick smoke run, set `DYADMLM_OUTER_REPS=2` and `DYADMLM_NSIM=39`.
`DYADMLM_COMPLEX_PROTOTYPE` may point to a different checkout of the elaborate
prototype.

Generated CSV files contain the complete numerical record. The concise
`validation-summary.md` reports the executed configuration and conclusions.
