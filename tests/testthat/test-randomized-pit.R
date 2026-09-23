test_that("continuous PIT is the empirical rank within each observation's reference", {
  reference <- rbind(c(-4, -2, 0, 2, 4), c(10, 12, 14, 16, 18),
                     c(100, 101, 102, 103, 104), c(-5, -3, -1, 1, 3))
  rownames(reference) <- letters[1:4]
  observed <- c(-6, 13, 200, 0)
  expected <- c(0, 2 / 5, 1, 3 / 5)
  withr::local_seed(81)
  random_state <- .Random.seed

  expect_identical(randomized_pit(reference, observed), expected)
  expect_identical(randomized_pit(reference[, c(5, 1, 3, 2, 4)], observed), expected)
  expect_identical(.Random.seed, random_state)
})


test_that("mixed PIT residuals randomize exactly the probability mass of ties", {
  reference <- rbind(c(0, 1, 2, 3), c(0, 0, 0, 1), c(-2, -1, 1, 2),
                     c(0, 1, 1, 2), c(0, 1, 2, 3), rep(.3, 4))
  observed <- c(-1, 0, 0, 1, 5, .3)
  withr::local_seed(143)
  uniform <- runif(3)
  # Below range; 3/4 tied at zero; untied median; 1/2 tied at one;
  # above range; and a fully tied non-integer response.
  expected <- c(0, .75 * uniform[1], .5, .25 + .5 * uniform[2], 1, uniform[3])
  expected_state <- .Random.seed

  set.seed(143)
  expect_identical(randomized_pit(reference, observed), expected)
  expect_identical(.Random.seed, expected_state)
  set.seed(143)
  expect_identical(randomized_pit(reference, observed), expected)
})


test_that("a single-observation reference keeps the same tie probability", {
  reference <- matrix(c(-1, -1, 0, 2, 2), nrow = 1)
  withr::local_seed(29)
  expected <- .6 + .4 * runif(1)
  set.seed(29)
  expect_identical(randomized_pit(reference, 2), expected)
})
