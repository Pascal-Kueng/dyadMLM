# Run from the repository root. GET is a development reference, not a package
# dependency. Example with a temporary installation:
# R_LIBS=/tmp/dyadmlm-envelope-library Rscript dev/diagnostic_checks/distribution-diagnostics/validate-envelopes.R
if (!requireNamespace("GET", quietly = TRUE)) stop("Install GET to run this comparison.")
source("R/predictive_checks_envelopes.R")
set.seed(9926)

get_bounds <- function(values) {
  curves <- GET::curve_set(obs = values[, 1], sim = values[, -1, drop = FALSE],
                           r = seq_len(nrow(values)))
  GET::global_envelope_test(curves, type = "erl", alpha = .05)
}

# Multiples of twenty align the 5% cutoff with a whole number of curves.
# Check both coordinate ties and complete ERL ties, including their permutations.
comparisons <- 0L
for (number_of_curves in c(20L, 40L, 200L)) {
  cases <- list(
    continuous = matrix(rnorm(35 * number_of_curves), 35),
    discrete = matrix(rpois(35 * number_of_curves, 1), 35),
    constant = matrix(3, 4, number_of_curves),
    boundary_ties = matrix(seq_len(number_of_curves), 1)
  )
  for (values in cases) {
    for (permutation in list(seq_len(number_of_curves), sample(number_of_curves))) {
      current <- values[, permutation, drop = FALSE]
      actual <- residual_curve_summary(current)
      reference <- get_bounds(current)
      stopifnot(isTRUE(all.equal(actual$lower, reference$lo)),
                isTRUE(all.equal(actual$upper, reference$hi)))
      comparisons <- comparisons + 1L
    }
  }
}

# GET 1.0-9 may exclude ceil(.05 * m) curves when .05 * m is noninteger.
# Our floor cutoff deliberately permits no more than 5%, retaining boundary
# ties. Its envelope must therefore contain GET's at both recommended draw counts.
for (number_of_curves in c(201L, 1001L)) {
  values <- matrix(rnorm(35 * number_of_curves), 35)
  actual <- residual_curve_summary(values)
  reference <- get_bounds(values)
  stopifnot(all(actual$lower <= reference$lo), all(actual$upper >= reference$hi))
  outside <- colSums(values < actual$lower | values > actual$upper) > 0L
  stopifnot(mean(outside) <= .05)
}
cat(comparisons, "exact GET comparisons passed; conservative rounding checked.\n")
