test_that("continuous PIT occupies each rank interval and preserves outcome ordering", {
  responses <- rbind(c(-6, -4, -2, 0, 2, 4), c(13, 10, 12, 14, 16, 18),
                     c(200, 100, 101, 102, 103, 104))
  withr::local_seed(81)
  pit <- randomized_pit(responses)
  expect_identical(dim(pit), dim(responses))
  expect_true(all(pit > 0 & pit < 1))
  for (row in seq_len(nrow(responses))) {
    expect_identical(order(pit[row, ]), order(responses[row, ]))
    expect_equal(sort(ceiling(pit[row, ] * ncol(responses))), seq_len(ncol(responses)))
  }
  set.seed(81)
  expect_identical(randomized_pit(responses), pit)
})


test_that("tied outcomes occupy their full rank block without favouring a dataset", {
  responses <- rbind(c(0, 0, 0, 1, 2, 3), c(-2, -1, 0, 0, 1, 2), rep(.3, 6))
  withr::local_seed(143)
  pit <- randomized_pit(responses)
  for (row in seq_len(nrow(responses))) {
    expect_equal(sort(ceiling(pit[row, ] * ncol(responses))), seq_len(ncol(responses)))
    for (column in seq_len(ncol(responses))) {
      lower <- sum(responses[row, ] < responses[row, column]) / ncol(responses)
      upper <- sum(responses[row, ] <= responses[row, column]) / ncol(responses)
      expect_gt(pit[row, column], lower)
      expect_lt(pit[row, column], upper)
    }
  }
  # For entirely tied data, no column is systematically the first or last rank.
  ranks <- ceiling(randomized_pit(matrix(1, 1000, 6)) * 6)
  expect_true(all(colMeans(ranks) > 3.2 & colMeans(ranks) < 3.8))
})


test_that("a single observation retains a matrix with every dataset", {
  responses <- matrix(c(-1, -1, 0, 2, 2), nrow = 1)
  withr::local_seed(29)
  pit <- randomized_pit(responses)
  expect_identical(dim(pit), c(1L, 5L))
  expect_true(all(pit[1, 1:2] > 0 & pit[1, 1:2] < .4))
  expect_true(pit[1, 3] > .4 & pit[1, 3] < .6)
  expect_true(all(pit[1, 4:5] > .6 & pit[1, 4:5] < 1))
})
