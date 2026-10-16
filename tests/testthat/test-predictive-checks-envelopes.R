test_that("scalar reference limits respect finite-simulation tail probabilities", {
  expect_identical(simulated_rank_limits(1:38), c(-Inf, Inf))
  expect_identical(simulated_rank_limits(1:39), c(1, 39))
  expect_identical(simulated_rank_limits(1:99), c(2, 98))
  expect_identical(simulated_rank_limits(1:39, level = .5), c(10, 30))
  expect_identical(simulated_rank_limits(c(NA, Inf, -Inf)), c(NA_real_, NA_real_))
  expect_identical(simulated_rank_limits(c(1:39, NA, Inf)), c(1, 39))
  expect_identical(simulated_rank_limits(setNames(1:39, paste0("s", 1:39))), c(1, 39))

  # Each possible observed rank is equally likely under exchangeability.
  for (number_of_datasets in c(2L, 39L, 40L, 41L, 100L, 200L)) {
    values <- seq_len(number_of_datasets)
    outside <- vapply(values, function(observed) {
      bounds <- simulated_rank_limits(values[-observed])
      observed < bounds[1] || observed > bounds[2]
    }, logical(1))
    expect_lte(mean(outside), .05)
  }
})

test_that("global envelopes retain full ERL boundary ties", {
  # With one coordinate, the two extremes have the same ERL ordering.
  # Twenty datasets permit one exclusion, so neither tied extreme is removed.
  values <- matrix(1:20, nrow = 1)
  expect_equal(residual_curve_summary(values),
               list(observed = 1L, lower = 1, upper = 20))
  # Forty datasets permit both extremes to be removed.
  expect_equal(residual_curve_summary(matrix(1:40, nrow = 1)),
               list(observed = 1L, lower = 2, upper = 39))
  expect_equal(residual_curve_summary(matrix(3, nrow = 4, ncol = 40)),
               list(observed = rep(3, 4), lower = rep(3, 4), upper = rep(3, 4)))
  expect_equal(residual_curve_summary(matrix(c(0, 1, 2, 3), nrow = 2)),
               list(observed = c(0, 1), lower = c(0, 1), upper = c(2, 3)))
})

test_that("global envelopes are symmetric across datasets and respect coverage", {
  withr::local_seed(9926)
  for (values in list(matrix(rnorm(17 * 201), 17), matrix(rpois(17 * 1001, 1), 17))) {
    random_state <- .Random.seed
    result <- residual_curve_summary(values)
    expect_identical(.Random.seed, random_state)
    outside <- colSums(values < result$lower | values > result$upper) > 0L
    expect_lte(mean(outside), .05)
    order <- sample(ncol(values))
    reordered <- residual_curve_summary(values[, order])
    expect_identical(reordered$observed, values[, order[1]])
    expect_identical(reordered$lower, result$lower)
    expect_identical(reordered$upper, result$upper)
    coordinate_order <- sample(nrow(values))
    reordered <- residual_curve_summary(values[coordinate_order, ])
    expect_identical(reordered$lower, result$lower[coordinate_order])
    expect_identical(reordered$upper, result$upper[coordinate_order])
    transformed <- residual_curve_summary(exp(values))
    expect_equal(transformed$lower, exp(result$lower))
    expect_equal(transformed$upper, exp(result$upper))
  }
})

test_that("missing predictor coordinates do not change the envelope", {
  values <- rbind(1:40, rep(NA_real_, 40), 40:1)
  result <- residual_curve_summary(values)
  complete <- residual_curve_summary(values[c(1, 3), ])
  expect_identical(result$observed, values[, 1])
  expect_identical(result$lower[c(1, 3)], complete$lower)
  expect_identical(result$upper[c(1, 3)], complete$upper)
  expect_true(is.na(result$lower[2]) && is.na(result$upper[2]))
  expect_equal(residual_curve_summary(values[2, , drop = FALSE]),
               list(observed = NA_real_, lower = NA_real_, upper = NA_real_))
  values[1, 2] <- NA_real_
  expect_error(residual_curve_summary(values), "whole missing rows")
})
