# Simple generalized cross-sectional validation

This folder is the compact, self-contained validation record for the selected
generalized partner-dependence implementation.

The production algorithm is the same for every admitted family:

```text
raw:             T(y)       versus T(y_rep)
model-centred:   T(y - c)   versus T(y_rep - c)

c = predict(model, type = "response", re.form = NA)
```

The same response bank, centre, and statistic are used for the observed and
simulated data. There is no family-specific residual definition.

## Files

- `simulation-study.R` runs the six-family correct-versus-omitted-dependence
  study and asserts the random-dispersion and sparse-reference checks.
- `outer-study-results.csv` retains every fitted-model result from the recorded
  run, including convergence information.
- `validation-summary.md` records the environment, conclusions, historical
  prototype comparison, and interpretation limits.
- This `README.md` defines the validation contract and rerun command.

The executable study validates only the chosen implementation. It does not load
or depend on an abandoned prototype branch.

## Run

From the package root:

```r
source("dev/diagnostic_checks/simple-generalized-cross-sectional/simulation-study.R")
```

The recorded run used 6 outer repetitions, 120 dyads, and 199 simulations per
fit. For a shorter smoke run:

```sh
DYADMLM_OUTER_REPS=2 DYADMLM_NSIM=39 Rscript \
  dev/diagnostic_checks/simple-generalized-cross-sectional/simulation-study.R
```

The default recorded configuration overwrites only `outer-study-results.csv`.
Non-default smoke runs leave that file unchanged. Mechanical checks stop with
an error when random-dispersion integration, sparse-reference handling, or
completion of every requested outer diagnostic fails.
