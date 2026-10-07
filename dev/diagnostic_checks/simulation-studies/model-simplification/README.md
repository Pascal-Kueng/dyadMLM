# Consequences of model simplification

These follow-ups ask whether a model-selection rule preserves inference for the
scientific effects. They do not turn descriptive checks into significance tests
or establish equivalence after a nonsignificant comparison.

## Gaussian selection study

The 24 completed ILD consequence conditions are refitted from their saved seeds
to obtain likelihood comparisons. Saved diagnostic references are reused only
after checking that estimates and SEs reproduce. Six new conditions use 50/200
dyads, 14 occasions, and independent member-specific actor-within random-slope
SDs of 0, 0.2 or 0.5. These conditions estimate actor and partner effects
separately between and within members.

Compare always-full, always-restricted, likelihood-ratio selection at 0.05 and
0.20, and check-guided selection. A flag retains the full model. For covariance
restrictions the primary check targets the affected summary; using any row is
a sensitivity analysis. There is no random-slope-specific row, so the slope
conditions use any row to assess this limitation of the check.

If only one candidate is usable, selection procedures use that candidate. If
neither is usable, they return no inference. Report all attempts, failures,
fallbacks and returned intervals, alongside bias, empirical SD, SE accuracy,
coverage and rejection rates. Paired usable-model comparisons are secondary.
Do not assess a selection rule only among datasets with no flag.

Optimizer convergence is necessary but insufficient. If both fits pass those
checks but the full model's log-likelihood is more than 0.000001 below the
nested restricted model's, the full fit is ineligible. Preserve its original
status and estimates; apply the same failure/fallback rule to every dataset.

In these Gaussian models, subtracting the true fixed-effect mean from the
response shifts coefficient estimates but leaves the covariance likelihood,
SEs and centred checks unchanged. This gives matched true-zero effects without
another full simulation grid. The pilot must verify this using actual shifted
responses and refits. This argument does not apply to generalized models.

The covariance restrictions use an interior one-parameter likelihood-ratio
comparison. Removing the independent slope variance uses the asymptotic equal
mixture of a point mass at zero and chi-square with one degree of freedom;
the zero-slope conditions check its finite-sample behavior. This mixture is not
a general rule for deleting several correlated random effects.

The threshold comparison follows the question studied by
[Matuschek et al. (2017)](https://doi.org/10.1016/j.jml.2017.01.001), without
assuming their results transfer to dyadic models. The boundary reference follows
[Self and Liang (1987)](https://doi.org/10.1080/01621459.1987.10478472).

## Generalized fallback review

`fallback-review.R` reaggregates all 45,000 completed generalized covariance
datasets, separating simpler-model checks by whether the full fit was usable.
It verifies the original exports and keeps full-fit failures in the attempted
denominators. These availability groups are descriptive subsets, not randomized
comparisons. They contain no coefficient estimates and cannot establish safe
inference when the full model fails.

The companion NB2 study adds coefficient inference and fallback rules.
`nb2-paired-inference.R` summarizes its saved `dataset-tables.rds` without
refitting; pass the NB2 results directory as its first command-line argument.
It writes `paired-inference.csv` for the secondary comparison where both fits
were eligible. Primary summaries retain all available estimates.

## Reproducibility

Keep original checkpoints and source snapshots unchanged. New runs have separate
checkpoints and source/software fingerprints. Pilot results validate the runner,
not error rates. Use 500 datasets per condition and 1,000 reference simulations
for full runs, at most ten fitting workers across jobs, with
`OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1`.
