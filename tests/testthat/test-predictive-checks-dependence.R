partner_check_test_simulations <- function() {
  model_frame <- data.frame(
    dyad = factor(rep(seq_len(5), each = 2)),
    role = factor(rep(c("female", "male"), times = 5))
  )
  fitted_response <- seq(0.5, 5, length.out = nrow(model_frame))
  observed_centered <- c(
    -2, -1.5,
    -1, -0.4,
    0, 0.2,
    1, 0.7,
    2, 1.8
  )
  simulated_centered <- rbind(
    c(-2, -1.7, -1, -0.6, 0, 0.1, 1, 0.8, 2, 1.6),
    c(-2, 1.5, -1, 0.7, 0, -0.2, 1, -0.8, 2, -1.7),
    c(-1.0, 0.2, 0.5, -0.8, 1.2, 0.4, -0.4, 1.0, 0.8, -0.5),
    c(-1.5, -1.2, -0.7, -0.3, 0.2, 0.1, 0.9, 0.8, 1.8, 1.4)
  )

  # Mix dyads and role order while preserving fitted-row alignment.
  row_order <- c(1, 4, 6, 3, 8, 2, 9, 5, 10, 7)
  model_frame <- model_frame[row_order, , drop = FALSE]
  fitted_response <- fitted_response[row_order]
  observed_centered <- observed_centered[row_order]
  simulated_centered <- simulated_centered[, row_order, drop = FALSE]

  simulations <- list(
    observed_response = fitted_response + observed_centered,
    simulated_responses = sweep(
      simulated_centered,
      MARGIN = 2,
      STATS = fitted_response,
      FUN = "+"
    ),
    fitted_response = fitted_response,
    model_frame = model_frame,
    backend = "glmmTMB",
    family = "gaussian",
    link = "identity",
    reference = "plug-in predictive",
    random_effects = "new",
    nsim = nrow(simulated_centered),
    seed = 123L,
    call = quote(simulate_dyad_responses(model))
  )
  class(simulations) <- c("dyadMLM_response_simulations", "list")

  return(simulations)
}


test_that("symmetric partner dependence uses aligned centered pairs", {
  simulations <- partner_check_test_simulations()
  result <- check_partner_dependence(simulations, dyad = "dyad")

  rows_by_dyad <- split(
    seq_len(nrow(simulations$model_frame)),
    simulations$model_frame$dyad
  )
  pair_rows <- rows_by_dyad |>
    unlist(use.names = FALSE) |>
    matrix(ncol = 2L, byrow = TRUE)

  centered_responses <- rbind(
    simulations$observed_response - simulations$fitted_response,
    sweep(
      simulations$simulated_responses,
      MARGIN = 2,
      STATS = simulations$fitted_response,
      FUN = "-"
    )
  )
  expected_statistics <- apply(
    centered_responses,
    MARGIN = 1,
    FUN = calculate_partner_dependence,
    pair_rows = pair_rows,
    role_oriented = FALSE
  )

  expect_s3_class(result, "dyadMLM_partner_check")
  expect_named(
    result,
    c(
      "statistic", "observed_statistic", "replicated_statistics",
      "replicated_median", "replicated_interval", "observed_percentile",
      "n_pairs", "n_incomplete_dyads", "n_missing_id_rows",
      "n_missing_role_rows", "reference", "random_effects", "nsim",
      "seed", "call"
    )
  )
  expect_equal(result$observed_statistic, expected_statistics[[1L]])
  expect_equal(result$replicated_statistics, expected_statistics[-1L])
  expect_equal(
    result$replicated_median,
    stats::median(expected_statistics[-1L])
  )
  expect_equal(
    result$replicated_interval,
    stats::quantile(expected_statistics[-1L], c(0.025, 0.975))
  )
  expect_equal(
    result$observed_percentile,
    (1 + sum(expected_statistics[-1L] <= expected_statistics[[1L]])) /
      nrow(centered_responses)
  )
  expect_identical(result$n_pairs, 5L)
  expect_identical(result$n_incomplete_dyads, 0L)
  expect_identical(result$reference, simulations$reference)
  expect_identical(result$random_effects, simulations$random_effects)
})


test_that("symmetric coefficient equals the mean-difference representation", {
  member_1 <- c(-2.0, -0.7, 0.4, 1.3, 2.1)
  member_2 <- c(-1.4, -0.2, 0.8, 0.5, 1.7)
  response <- as.vector(rbind(member_1, member_2))
  pair_rows <- matrix(seq_along(response), ncol = 2L, byrow = TRUE)

  direct_statistic <- calculate_partner_dependence(
    response,
    pair_rows,
    role_oriented = FALSE
  )
  dyad_mean <- (member_1 + member_2) / 2
  dyad_half_difference <- (member_1 - member_2) / 2
  mean_difference_statistic <-
    (sum(dyad_mean^2) - sum(dyad_half_difference^2)) /
    (sum(dyad_mean^2) + sum(dyad_half_difference^2))

  expect_equal(direct_statistic, mean_difference_statistic)

  # Independently exchanging member positions within selected dyads must not
  # change an exchangeable-dyad statistic.
  swapped_pair_rows <- pair_rows
  swapped_pair_rows[c(2, 5), ] <- swapped_pair_rows[c(2, 5), 2:1]
  expect_equal(
    calculate_partner_dependence(
      response,
      swapped_pair_rows,
      role_oriented = FALSE
    ),
    direct_statistic
  )
})


test_that("role-specific partner dependence is oriented by role", {
  simulations <- partner_check_test_simulations()
  result <- check_partner_dependence(
    simulations,
    dyad = simulations$model_frame$dyad,
    role = simulations$model_frame$role
  )

  observed_centered <-
    simulations$observed_response - simulations$fitted_response
  dyad_levels <- levels(simulations$model_frame$dyad)
  female_rows <- vapply(
    dyad_levels,
    function(dyad) {
      which(
        simulations$model_frame$dyad == dyad &
          simulations$model_frame$role == "female"
      )
    },
    integer(1)
  )
  male_rows <- vapply(
    dyad_levels,
    function(dyad) {
      which(
        simulations$model_frame$dyad == dyad &
          simulations$model_frame$role == "male"
      )
    },
    integer(1)
  )

  expect_equal(
    result$observed_statistic,
    stats::cor(observed_centered[female_rows], observed_centered[male_rows])
  )
  expect_identical(result$statistic, "Pearson correlation between roles")

  # Independently reverse selected dyads, rather than swapping every pair in
  # the same way. Row order still cannot determine the role-specific result.
  reordered <- simulations
  reordered_rows <- seq_len(nrow(simulations$model_frame))
  for (dyad in c("2", "4")) {
    dyad_rows <- which(simulations$model_frame$dyad == dyad)
    reordered_rows[dyad_rows] <- rev(reordered_rows[dyad_rows])
  }
  reordered$model_frame <- reordered$model_frame[reordered_rows, , drop = FALSE]
  reordered$observed_response <- reordered$observed_response[reordered_rows]
  reordered$fitted_response <- reordered$fitted_response[reordered_rows]
  reordered$simulated_responses <-
    reordered$simulated_responses[, reordered_rows, drop = FALSE]

  reordered_result <- check_partner_dependence(
    reordered,
    dyad = "dyad",
    role = "role"
  )
  expect_equal(reordered_result$observed_statistic, result$observed_statistic)
  expect_equal(
    reordered_result$replicated_statistics,
    result$replicated_statistics
  )
})


test_that("missing and incomplete pairs are reported", {
  simulations <- partner_check_test_simulations()
  dyad <- simulations$model_frame$dyad
  role <- simulations$model_frame$role

  dyad[which(dyad == "5")[[1L]]] <- NA
  role[which(dyad == "4")[[1L]]] <- NA

  result <- check_partner_dependence(simulations, dyad = dyad, role = role)

  expect_identical(result$n_pairs, 3L)
  expect_identical(result$n_missing_id_rows, 1L)
  expect_identical(result$n_missing_role_rows, 1L)
  expect_identical(result$n_incomplete_dyads, 2L)
})


test_that("invalid partner structures fail clearly", {
  simulations <- partner_check_test_simulations()

  expect_error(
    check_partner_dependence(simulations),
    "`dyad` must identify",
    fixed = TRUE
  )
  expect_error(
    check_partner_dependence(simulations, dyad = "unknown"),
    "does not name a column",
    fixed = TRUE
  )
  expect_error(
    check_partner_dependence(simulations, dyad = 1:3),
    "vector of length 10",
    fixed = TRUE
  )

  too_many_rows <- as.character(simulations$model_frame$dyad)
  too_many_rows[too_many_rows == "5"] <- "1"
  expect_error(
    check_partner_dependence(simulations, dyad = too_many_rows),
    "at most two fitted responses",
    fixed = TRUE
  )

  # A missing role must not hide a third fitted response in a dyad.
  three_row_dyad <- as.character(simulations$model_frame$dyad)
  extra_dyad_row <- which(three_row_dyad == "5")[[1L]]
  three_row_dyad[[extra_dyad_row]] <- "1"
  extra_row_missing_role <- as.character(simulations$model_frame$role)
  extra_row_missing_role[[extra_dyad_row]] <- NA_character_
  expect_error(
    check_partner_dependence(
      simulations,
      dyad = three_row_dyad,
      role = extra_row_missing_role
    ),
    "at most two fitted responses",
    fixed = TRUE
  )

  too_few_pairs <- simulations$model_frame$dyad
  for (dyad in c("3", "4", "5")) {
    too_few_pairs[which(too_few_pairs == dyad)[[1L]]] <- NA
  }
  expect_error(
    check_partner_dependence(simulations, dyad = too_few_pairs),
    "At least three complete dyads",
    fixed = TRUE
  )

  duplicate_role <- as.character(simulations$model_frame$role)
  first_dyad_rows <- which(simulations$model_frame$dyad == "1")
  duplicate_role[first_dyad_rows] <- "female"
  expect_error(
    check_partner_dependence(
      simulations,
      dyad = "dyad",
      role = duplicate_role
    ),
    "exactly one row for each role value",
    fixed = TRUE
  )

  third_role <- as.character(simulations$model_frame$role)
  third_role[first_dyad_rows[[1L]]] <- "other"
  expect_error(
    check_partner_dependence(simulations, dyad = "dyad", role = third_role),
    "Exactly two role values",
    fixed = TRUE
  )

  no_variation <- simulations
  no_variation$simulated_responses[1L, ] <- no_variation$fitted_response
  expect_error(
    check_partner_dependence(no_variation, dyad = "dyad"),
    "insufficient variation",
    fixed = TRUE
  )
})


test_that("pre-existing incomplete dyads remain counted after role omission", {
  simulations <- partner_check_test_simulations()
  dyad <- simulations$model_frame$dyad
  role <- simulations$model_frame$role

  fourth_dyad_rows <- which(dyad == "4")
  dyad[fourth_dyad_rows[[1L]]] <- NA
  role[fourth_dyad_rows[[2L]]] <- NA

  result <- check_partner_dependence(simulations, dyad = dyad, role = role)

  expect_identical(result$n_pairs, 4L)
  expect_identical(result$n_incomplete_dyads, 1L)
  expect_identical(result$n_missing_id_rows, 1L)
  expect_identical(result$n_missing_role_rows, 1L)
})


test_that("partner check prints and plots compactly", {
  result <- check_partner_dependence(
    partner_check_test_simulations(),
    dyad = "dyad"
  )

  expect_output(
    printed_result <- print(result),
    "Partner-dependence predictive check",
    fixed = TRUE
  )
  expect_identical(printed_result, result)

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  plotted_result <- plot(result)
  expect_identical(plotted_result, result)
})


test_that("partner check works with simulated glmmTMB responses", {
  skip_if_not_installed("glmmTMB")

  set.seed(9124)
  test_data <- data.frame(
    dyad = factor(rep(seq_len(20), each = 2)),
    role = factor(rep(c("female", "male"), times = 20))
  )
  dyad_effect <- stats::rnorm(20, sd = 0.8)
  test_data$outcome <-
    1 +
    0.3 * (test_data$role == "male") +
    dyad_effect[as.integer(test_data$dyad)] +
    stats::rnorm(nrow(test_data), sd = 0.4)

  model <- glmmTMB::glmmTMB(
    outcome ~ role + (1 | dyad),
    data = test_data
  )
  simulations <- simulate_dyad_responses(model, nsim = 20, seed = 9125)
  result <- check_partner_dependence(
    simulations,
    dyad = "dyad",
    role = "role"
  )

  expect_s3_class(result, "dyadMLM_partner_check")
  expect_identical(result$n_pairs, 20L)
  expect_length(result$replicated_statistics, 20L)
  expect_true(all(is.finite(result$replicated_statistics)))
})
