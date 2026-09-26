# Checking the change from 20 to 10 PIT bins

The residual histogram now uses 10 equal-width bins. Its global envelope method,
PIT calculation and centring are unchanged. Plot centres come from the saved bin
count, so existing 20-bin results still plot correctly. The x-axis covers 0–1.

## Paired comparison

[histogram-bins.R](histogram-bins.R) compares the previous implementation at
`f222e122` with the updated function. Each pair uses exactly the same fitted model,
simulated responses and PIT seed (123). All four examples use whole-dataset
centring and separate role panels.

| Example | Observations per role | Simulations | Fitted model |
|---|---:|---:|---|
| Existing NB2 data | 250 | 1,000 | Gaussian, role + support, no dyad effect |
| Existing Tweedie data | 120 | 2,000 | Gaussian, predictor + dyad intercept |
| Correct Gaussian | 100 | 1,000 | Gaussian, predictor + dyad intercept |
| Correct NB1 | 100 | 1,000 | NB1, predictor + dyad intercept |

The existing datasets and simulation seeds match their worked examples. The two
new datasets use seeds 20260928 and 20260929, with simulation seed 123. Both have
dyad-intercept SD 0.6. Gaussian means are `1 + 0.4 * predictor`, with residual
SD 1. NB1 log means are `0.7 + 0.3 * predictor`, with dispersion 1. These parameters
are estimated when fitting. Exact formulas, seeds and fit results are in
[fits.csv](results/histogram-bins/fits.csv).

The script verified all of the following:

- The saved results are identical after excluding histogram fields and the
  unused KS distances removed in a later cleanup. This includes PITs, QQ
  envelopes, pattern curves and displayed scalar summaries.
- Every 10-bin density equals the average of its two adjacent 20-bin densities,
  for the observed data and every simulation. Each density integrates to one
  within numerical tolerance (`1e-12`).
- Both saved histogram envelopes equal independently recomputed ERL summaries
  of their density matrices. The new envelope is recomputed after combining bins;
  it is not obtained by averaging the old limits.
- At most 5% of the complete dataset curves cross each envelope within its own
  reference bank. This checks envelope construction, not repeated-sampling
  calibration.
- All four fits converged with positive-definite Hessians and no fit warnings.

## Results

Width is the average of upper minus lower density limits across a panel's bins.
“Outside bins” counts strict departures; touching a limit counts as inside.
The two bin counts use different grids, so outside-bin counts are descriptive.

| Example | Role | Mean width, 20 bins | Mean width, 10 bins | Reduction | Outside bins, 20 → 10 |
|---|---|---:|---:|---:|---:|
| NB2 fitted as Gaussian | Female | 1.536 | 0.984 | 35.9% | 7 → 6 |
| NB2 fitted as Gaussian | Male | 1.508 | 0.976 | 35.3% | 8 → 5 |
| Tweedie fitted as Gaussian | Female | 2.142 | 1.400 | 34.6% | 1 → 3 |
| Tweedie fitted as Gaussian | Male | 2.175 | 1.392 | 36.0% | 1 → 1 |
| Correct Gaussian | A | 2.400 | 1.530 | 36.2% | 0 → 0 |
| Correct Gaussian | B | 2.290 | 1.510 | 34.1% | 0 → 0 |
| Correct NB1 | A | 2.300 | 1.540 | 33.0% | 0 → 0 |
| Correct NB1 | B | 2.250 | 1.530 | 32.0% | 0 → 0 |

Both misspecified examples have histogram departures in both roles under either
binning. Neither correct-model example has a departure. For the NB1 panels with
100 observations per role, the ten-bin lower bounds range from 0.3 to 0.4 and
upper bounds from 1.7 to 2.0. These are the measured limits for this example,
not universal limits. Every ten-bin panel has a positive lower bound in every bin.

Full values are in [summary.csv](results/histogram-bins/summary.csv) and
[bins.csv](results/histogram-bins/bins.csv). Comparison figures use matching axes
within each role: [NB2](results/histogram-bins/nbinom2-gaussian.png),
[Tweedie](results/histogram-bins/tweedie-gaussian.png),
[Gaussian](results/histogram-bins/gaussian-correct.png), and
[NB1](results/histogram-bins/nbinom1-correct.png). Blue rectangles and red horizontal
marks show the limits and observed densities; the public plots use intervals
and dots for these same quantities.

Ten bins reduce the small alternating peaks in these examples. The broad NB2
concentration near PIT 0.3–0.5 remains visible. Finer detail is lost: the Tweedie
male panel's alternating peaks and gaps are largely averaged out. This supports
ten bins for a simpler view of broad shapes, not a claim that no information is lost.

## Checks and reproduction

The full suite passed **2,723 assertions, with no failures, warnings or skips**.
The added renderer test checks centres and the full 0–1 range for both new 10-bin
and older 20-bin saved results. Existing tests check each role's density and ERL
summary. Function help was regenerated.

The NB2 and Tweedie worked examples and all three composition examples were
regenerated. The changed distribution pages were visually inspected, including
pooled and separate-role layouts: all ten points and intervals are correctly
positioned, both PIT endpoints are visible, and labels do not overlap. The bin
change left pattern, outcome and partner figures unchanged; a later cleanup
shortened their shared footer without changing plotted values. A separate reviewer
checked the report's numbers against the CSVs and inspected the composition pages.

Run these commands from the package folder, sequentially:

```sh
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
Rscript -e 'roxygen2::roxygenise()'
Rscript -e 'devtools::test(reporter = "check", stop_on_failure = TRUE)'
Rscript dev/diagnostic_checks/distribution-diagnostics/histogram-bins.R
Rscript dev/diagnostic_checks/distribution-diagnostics/nbinom2-gaussian.R
Rscript dev/diagnostic_checks/distribution-diagnostics/tweedie-gaussian.R
Rscript dev/diagnostic_checks/distribution-diagnostics/composition-layout.R
```

[session-info.txt](results/histogram-bins/session-info.txt) records versions and
source/data hashes. In this sandbox, `sessionInfo()` produced a `timedatectl`
system-bus warning while recording metadata; model fitting and diagnostic checks
produced no warnings.

These are four datasets, not a power or calibration study. The results do not
establish a general false-alarm rate, superiority over 20 bins, or equivalence to
the QQ plot. The envelope still reflects fitting and the specified dependence.
