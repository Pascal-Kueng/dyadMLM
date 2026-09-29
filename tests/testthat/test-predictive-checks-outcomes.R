test_that("outcome summaries use all simulations and each role's fitted rows", {
  simulations <- distribution_check_fixture()
  result <- withVisible(check_dyad_outcomes(simulations, dyad = "dyad", role = "role", plot = FALSE))
  expect_false(result$visible)
  expect_s3_class(result$value, "dyadMLM_outcome_check")
  expect_identical(result$value$compositions[[1]]$label, "A - B")
  expect_named(result$value$compositions[[1]]$statistics, c("A", "B"))
  rows_by_role <- split(seq_len(12), simulations$model_frame$role)
  for (i in seq_along(rows_by_role)) {
    rows <- rows_by_role[[i]]
    responses <- rbind(simulations$observed_response[rows], simulations$simulated_responses[, rows])
    deviations <- sweep(responses, 2, simulations$predicted_response[rows])
    expected <- rbind(`Response SD` = apply(deviations, 1, sd),
                      `Largest absolute deviation` = apply(abs(deviations), 1, max))
    expect_equal(unname(result$value$compositions[[1]]$statistics[[i]]), unname(expected))
    expect_identical(rownames(result$value$compositions[[1]]$statistics[[i]]), rownames(expected))
  }
})


test_that("outcome SDs match partner role SDs for complete distinct-role dyads", {
  simulations <- distribution_check_fixture()
  simulations$observed_response[1] <- simulations$observed_response[1] + 1
  outcomes <- check_dyad_outcomes(simulations, dyad = "dyad", role = "role", plot = FALSE)
  partners <- check_partner_dependence(simulations, dyad = "dyad", role = "role", plot = FALSE)
  for (role in c("A", "B")) {
    expect_equal(unname(outcomes$compositions[[1]]$statistics[[role]]["Response SD", ]),
                 partners$compositions$statistics[[1]][[paste0("SD (", role, ")")]])
  }
})


test_that("zero counts appear for every role of a composition where zeros can occur", {
  simulations <- distribution_check_fixture()
  simulations$model_frame$role <- rep(c("A", "A", "A", "B", "B", "B"), 2)
  nsim <- nrow(simulations$simulated_responses)
  check <- function(simulations) {
    check_dyad_outcomes(simulations, "dyad", "role", plot = FALSE)$compositions
  }
  has_zeros <- function(compositions) vapply(compositions, function(composition)
    all(vapply(composition$statistics, function(role)
      "Number of zeros" %in% rownames(role), logical(1))), logical(1))
  expect_identical(has_zeros(check(simulations)), rep(FALSE, 3))

  # A Gaussian model never simulates an exact zero, so an observed zero alone
  # (e.g. on a rating scale) does not add the row; count and Tweedie families,
  # which can produce zeros, compare it.
  observed_zero <- simulations
  observed_zero$observed_response[3] <- 0
  expect_identical(has_zeros(check(observed_zero)), rep(FALSE, 3))
  for (family in c("poisson", "tweedie")) {
    attr(observed_zero, "dyadMLM")$family <- family
    compositions <- check(observed_zero)
    expect_identical(has_zeros(compositions), c(FALSE, TRUE, FALSE))
    expect_equal(unname(compositions[[2]]$statistics$A["Number of zeros", ]), c(1, rep(0, nsim)))
  }

  # Simulated zeros count in every dataset.
  simulations$simulated_responses[c(1, 21:23), 3] <- 0
  compositions <- check(simulations)
  expect_identical(has_zeros(compositions), c(FALSE, TRUE, FALSE))
  expect_equal(unname(compositions[[2]]$statistics$A["Number of zeros", ]),
               c(0, as.numeric(seq_len(nsim) %in% c(1, 21:23))))
  expect_equal(unname(compositions[[2]]$statistics$B["Number of zeros", ]), rep(0, nsim + 1))
})


test_that("ECDFs keep tied steps, and axes ignore extreme simulations", {
  simulations <- distribution_check_fixture()
  simulations$observed_response <- rep(c(-2, 1, 4), c(3, 6, 3))
  simulations$simulated_responses[1, 1] <- 1e6
  distribution <- check_dyad_outcomes(simulations, role = NULL,
                                      plot = FALSE)$compositions[[1]]$distribution
  expect_null(distribution$labels)
  expect_length(distribution$roles[[1]], 31)
  expect_equal(distribution$roles[[1]][[1]], list(x = c(-2, 1, 4), y = c(.25, .75, 1)))
  expect_equal(distribution$limits,
               range(-2, 4, quantile(simulations$simulated_responses, c(.01, .99))))
  # Counts also use the ECDF rather than category bars.
  attr(simulations, "dyadMLM")$family <- "poisson"
  expect_null(check_dyad_outcomes(simulations, role = NULL,
                                  plot = FALSE)$compositions[[1]]$distribution$labels)
})


test_that("ordinal outcomes use role proportions and all declared categories", {
  simulations <- distribution_check_fixture()
  # No dataset uses category 3, which is still shown.
  simulations$observed_response <- c(1, 1, 2, 1, 2, 4, 4, 4, 1, 2, 4, 4)
  simulations$simulated_responses <- matrix(c(1, 2, 4, 4)[abs(sin(seq_len(40 * 12))) * 4 + 1], 40)
  attr(simulations, "dyadMLM") <- list(family = "ordinal")
  distribution <- check_dyad_outcomes(simulations, "dyad", "role",
                                      plot = FALSE)$compositions[[1]]$distribution
  expect_equal(as.numeric(distribution$labels), 1:4)
  for (role in c("A", "B")) {
    rows <- which(simulations$model_frame$role == role)
    expect_equal(distribution$roles[[role]]$observed,
                 tabulate(simulations$observed_response[rows], nbins = 4) / 6)
    proportions <- apply(simulations$simulated_responses[, rows], 1, tabulate, nbins = 4) / 6
    expect_equal(unname(distribution$roles[[role]]$bounds),
                 unname(apply(proportions, 1, simulated_rank_limits)))
  }

  # Declared categories are retained even when no dataset uses them.
  categories <- c("Low", "Middle", "High", "Very high", "Unused")
  simulations$model_frame <- data.frame(
    response = ordered(categories[simulations$observed_response], levels = categories),
    simulations$model_frame
  )
  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  distribution <- check_dyad_outcomes(simulations, role = NULL,
                                      ask = FALSE)$compositions[[1]]$distribution
  expect_identical(distribution$labels, categories)
  expect_equal(distribution$roles[[1]]$observed[5], 0)
})
