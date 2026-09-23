# Recorded results

The consolidation preserves the completed sensitivity results and their seeds.
The smaller validation and fitting examples were run separately. These findings
concern the specified scenarios, not every model in a family. Historical flag rates
below count either tail; the current all-family plots count the expected direction.

Fresh runs of two datasets in every sensitivity condition (304 fits) reproduced
all previously saved values exactly. All six statistics were saved in each new
run, without fitting or checking warnings. The full saved plot frequencies and
Monte Carlo intervals are unchanged.

## Gaussian APIM sample-size study

All 22,000 fits and checks succeeded, without model/check warnings: 500 datasets
per sample-size/correlation combination and 499 reference simulations per fit.

| Dyads | Correlation 0.10 | Correlation 0.30 | Correlation 0.50 |
| ---: | ---: | ---: | ---: |
| 20 | 9.0% | 26.0% | 65.4% |
| 40 | 10.6% | 49.2% | 90.4% |
| 100 | 17.6% | 86.8% | 100% |
| 200 | 28.2% | 98.6% | 100% |
| 1,000 | 90.0% | 100% | 100% |

These count observed model-centred partner correlations outside the simulated
reference. With zero residual correlation, 3.6% to 8.6% were flagged across sample
sizes; the highest rate was at 20 dyads. A 95% reference does not guarantee a 5%
false-positive rate. Agreement does not establish negligible omitted dependence.

## Raw versus model-centred APIM checks

The [comparison script](../family-comparison/run.R) uses the same 22,000 datasets, fitted
models, and 499 reference simulations per fit for both methods. All fits and
44,000 checks succeeded without warnings. Every model-centred observed correlation,
reference boundary, and flag matched the original study exactly.

| Dyads | Residual correlation | Model-centred | Raw |
| ---: | ---: | ---: | ---: |
| 40 | 0.10 | 10.6% | 4.8% |
| 40 | 0.30 | 49.2% | 32.6% |
| 40 | 0.50 | 90.4% | 82.6% |
| 100 | 0.10 | 17.6% | 8.0% |
| 100 | 0.30 | 86.8% | 74.8% |
| 100 | 0.50 | 100% | 100% |

Centring was more sensitive in this APIM. Raw checks were also more conservative:
with zero residual correlation, they flagged 0.8% to 3.6% across sample sizes,
compared with 3.6% to 8.6% after centring. These are descriptive flag rates, not
power estimates for tests calibrated to the same false-positive rate. Both plots'
correlation labels refer to the true residual correlation used to generate the data.

## All-family APIM comparison: implementation checks

The extended comparison uses 500 generated datasets per condition and 1,000
reference simulations per fit. Raw and model-centred checks share both datasets
and reference draws. Its correlation labels target the residual correlation after
subtracting the true response mean, including for ordinal and combined zero models.

For positive correlations, the plots now count only observations above the upper
97.5th percentile of the simulated reference. Opposite-direction flags are reported
separately; zero-correlation baselines still count either tail. Recounting the
completed Gaussian results excludes 11 model-centred and one raw opposite-direction
flags across 16,500 positive-correlation checks per method. The largest change at
any point is 1.2 percentage points. No models or simulations needed to be rerun.

[Implementation checks](../family-comparison/check.R) passed for all 20 families plus
zero-inflated Poisson and hurdle NB2. At three predictor values, generated means
and distribution probabilities agreed with native glmmTMB simulations; response
predictions differed by at most 2.20e-14. The study's correlation calculation agreed
with the public check to 4.44e-16 in 12 comparisons with 5,000 reference draws,
including matching reference limits and identical flags. These validate the implementation;
the full repeated study estimates flag rates.

The earlier Gaussian run used 499 reference simulations. In 6,750 matched
correlation checks, increasing this to 5,000 left 98.9% of flags unchanged.
At 500 dyads and residual correlation 0.10, the model-centred flag rate changed
from 63.8% to 63.2%; the raw rate changed from 47.6% to 46.4%.
In a direct comparison of 1,000 with 5,000 draws, 99.4% of 3,200 Gaussian
correlation flags agreed. Flag rates differed by at most 0.5 percentage points
across the checked conditions (500 and 1,000 dyads, 200 datasets per condition).
All six conclusions in both vignette examples were also unchanged. The reports
therefore use the package default of 1,000 reference simulations.

## Intercept-only family study

Of 21,600 attempted fits, 21,572 succeeded. The 28 failures were NB2 fits near the
Poisson boundary. There were no check errors or warnings in successful runs.
The separate SD follow-up completed 3,200 fits and reproduced the original three
statistics exactly. Its additional statistics are now stored with the main results.

At 200 dyads with a second/first SD ratio of 1.25 and independent partners:

| Family | Either role SD flagged | Mean/difference correlation flagged |
| --- | ---: | ---: |
| Gaussian | 66.0% | 90.5% |
| NB2 | 42.5% | 62.5% |
| Ordinal | 91.5% | 97.0% |
| Lognormal | 16.0% | 17.5% |

This is why the consolidated script retains the mean/difference summaries. The
comparison also depends on the chosen means, spreads, and category probabilities.
The [study description](../README.md#earlier-validation-and-fitting-examples) specifies them.

## Compact validation

The default run used 20 datasets per population, 199 simulations, and 200 dyads.
Of 240 runs (220 fitted models and 20 known-parameter controls), 238 checks succeeded.
Two correctly specified zero-inflated Poisson fits had convergence/Hessian problems
and were excluded without retry. There were no check errors, warnings among
successful fits, or undefined reference statistics. All 2,064 saved statistic rows
were finite. This is a behavior check, not a precise frequency estimate.

## Focused fitting examples

Both examples retain the first dataset from their original investigation.
More accurate likelihood integration changes fitted variance components and
brings simulated partner correlation closer to the observed value:

| Example | Observed correlation | Reference median: glmmTMB | More accurate integration |
| --- | ---: | ---: | ---: |
| Ordinal | 0.182 | 0.136 | 0.183 |
| Lognormal | 0.524 | 0.409 | 0.484 |

Neither example's observed correlation lies outside its reference range. These
single datasets illustrate a fitting mechanism, not its frequency. Both reproduce
the original examples' correlation summaries; numerical accuracy checks pass.
The full historical studies and their aggregate findings remain in the local
archive described in [README.md](../README.md#earlier-validation-and-fitting-examples).
