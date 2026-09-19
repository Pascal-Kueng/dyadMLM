composition_check_test_simulations <- function(include_parent_child = FALSE) {
  roles <- c(rep("female", 10), rep(c("female", "male"), 5), rep("male", 10))
  if (include_parent_child) roles <- c(roles, rep(c("mother", "child"), 5))
  number_of_rows <- length(roles)
  model_frame <- data.frame(
    dyad = rep(seq_len(number_of_rows / 2), each = 2),
    role = factor(roles, levels = c("female", "male", "mother", "child"))
  )
  predicted_response <- seq(0.5, 5, length.out = number_of_rows)
  observed_residuals <- rep(
    c(-2, -1.4, -0.7, -0.2, 0.4, 0.8, 1.3, 0.5, 2.1, 1.7),
    length.out = number_of_rows
  ) + sin(seq_len(number_of_rows)) / 4
  simulated_residuals <- rbind(
    observed_residuals * 0.9 + sin(seq_len(number_of_rows)),
    observed_residuals * 0.4 + cos(seq_len(number_of_rows)),
    observed_residuals * 1.2 + sin(seq_len(number_of_rows) / 2)
  )
  structure(list(
    observed_response = predicted_response + observed_residuals,
    simulated_responses = sweep(simulated_residuals, 2, predicted_response, "+"),
    predicted_response = predicted_response,
    model_frame = model_frame
  ), class = c("dyadMLM_response_simulations", "list"), dyadMLM = list(
    backend = "glmmTMB", family = "gaussian", link = "identity",
    reference = "plug-in predictive", random_effects = "new",
    parameter_uncertainty = "excluded", seed = 123L
  ))
}


test_that("mixed compositions match independent raw and centred calculations", {
  simulations <- composition_check_test_simulations()
  responses <- rbind(simulations$observed_response, simulations$simulated_responses)
  for (response in c("model-centred", "raw")) {
    result <- check_partner_dependence(
      simulations, "dyad", "role", response = response, plot = FALSE
    )
    values <- if (response == "raw") responses else
      sweep(responses, 2, simulations$predicted_response, "-")
    expected <- t(apply(values, 1, function(dataset_responses) {
      # Each ten-row block contains five dyads of one composition.
      female_pairs <- matrix(dataset_responses[1:10], ncol = 2, byrow = TRUE)
      mixed_pairs <- matrix(dataset_responses[11:20], ncol = 2, byrow = TRUE)
      male_pairs <- matrix(dataset_responses[21:30], ncol = 2, byrow = TRUE)
      exchangeable_moments <- function(pairs) {
        between_dyad_variance <- 2 * var(rowMeans(pairs))
        within_dyad_variance <- sum((pairs[, 1] - pairs[, 2])^2) / (2 * nrow(pairs))
        c(sqrt((between_dyad_variance + within_dyad_variance) / 2),
          (between_dyad_variance - within_dyad_variance) /
            (between_dyad_variance + within_dyad_variance),
          sqrt(between_dyad_variance / 2), sqrt(within_dyad_variance / 2))
      }
      dyad_average <- rowMeans(mixed_pairs)
      half_difference <- (mixed_pairs[, 1] - mixed_pairs[, 2]) / 2
      c(exchangeable_moments(female_pairs),
        sd(mixed_pairs[, 1]), sd(mixed_pairs[, 2]),
        cor(mixed_pairs[, 1], mixed_pairs[, 2]),
        sd(dyad_average), sd(half_difference), cor(dyad_average, half_difference),
        exchangeable_moments(male_pairs))
    }))
    expect_equal(unname(result$observed_statistics), expected[1, ])
    expect_equal(unname(result$replicated_statistics), expected[-1, ])
    expect_identical(names(result$observed_statistics),
                     colnames(result$replicated_statistics))
    expect_identical(result$compositions$label,
                     c("female - female", "female - male", "male - male"))
    expect_equal(result$compositions$n_pairs, c(5, 5, 5))
    expect_equal(result$compositions$first_statistic, c(1, 5, 11))
    expect_equal(result$compositions$last_statistic, c(4, 10, 14))
    expect_identical(result$n_pairs, 15L)
  }
})


test_that("composition checks retain fitted rows and respect factor role order", {
  simulations <- composition_check_test_simulations()
  original <- check_partner_dependence(simulations, "dyad", "role", plot = FALSE)
  withr::local_seed(124)
  fitted_row_order <- sample(nrow(simulations$model_frame))
  simulations$model_frame <- simulations$model_frame[fitted_row_order, ]
  simulations$observed_response <- simulations$observed_response[fitted_row_order]
  simulations$predicted_response <- simulations$predicted_response[fitted_row_order]
  simulations$simulated_responses <- simulations$simulated_responses[, fitted_row_order]
  shuffled <- check_partner_dependence(simulations, "dyad", "role", plot = FALSE)
  expect_equal(shuffled, original)

  simulations$model_frame$role <- relevel(simulations$model_frame$role, "male")
  reversed <- check_partner_dependence(simulations, "dyad", "role", plot = FALSE)
  expect_identical(reversed$compositions$label,
                   c("male - male", "male - female", "female - female"))
  # Swapping distinct roles exchanges their SDs and reverses the final correlation.
  expected_column_order <- c(11:14, 6, 5, 7:10, 1:4)
  expected_signs <- c(rep(1, 9), -1, rep(1, 4))
  expect_equal(unname(reversed$observed_statistics),
               unname(original$observed_statistics[expected_column_order]) * expected_signs)
  expect_equal(unname(reversed$replicated_statistics), unname(sweep(
    original$replicated_statistics[, expected_column_order], 2, expected_signs, "*"
  )))
})


test_that("additional roles form another distinguishable composition", {
  simulations <- composition_check_test_simulations(include_parent_child = TRUE)
  result <- check_partner_dependence(simulations, "dyad", "role", plot = FALSE)
  expect_identical(result$compositions$label, c(
    "female - female", "female - male", "male - male", "mother - child"
  ))
  expect_equal(result$compositions$n_pairs, rep(5, 4))
  expect_identical(dim(result$replicated_statistics), c(3L, 20L))
  parent_child_columns <- 15:20
  parent_child_rows <- 31:40
  centred_response <- simulations$observed_response - simulations$predicted_response
  pairs <- matrix(centred_response[parent_child_rows], ncol = 2, byrow = TRUE)
  dyad_average <- rowMeans(pairs)
  half_difference <- (pairs[, 1] - pairs[, 2]) / 2
  expect_equal(unname(result$observed_statistics[parent_child_columns]), c(
    sd(pairs[, 1]), sd(pairs[, 2]), cor(pairs[, 1], pairs[, 2]),
    sd(dyad_average), sd(half_difference), cor(dyad_average, half_difference)
  ))
  expect_identical(names(result$observed_statistics)[15:16],
                   c("SD (mother)", "SD (child)"))
})


test_that("rounded role labels cannot merge distinct compositions", {
  simulations <- composition_check_test_simulations()
  expected <- check_partner_dependence(simulations, "dyad", "role", plot = FALSE)
  simulations$model_frame$role <- 1e15 + as.integer(simulations$model_frame$role)
  expect_length(unique(as.character(simulations$model_frame$role)), 1L)
  result <- check_partner_dependence(simulations, "dyad", "role", plot = FALSE)
  expect_equal(unname(result$observed_statistics), unname(expected$observed_statistics))
  expect_equal(unname(result$replicated_statistics), unname(expected$replicated_statistics))
  expect_equal(result$compositions[c("n_pairs", "first_statistic", "last_statistic")],
               expected$compositions[c("n_pairs", "first_statistic", "last_statistic")])
  expect_identical(result$n_pairs, 15L)
})


test_that("small compositions and incomplete dyads have separate counts", {
  simulations <- composition_check_test_simulations()
  # Leave two female-female dyads, then omit one member from each other composition.
  fitted_rows <- which(!simulations$model_frame$dyad %in% 3:5)
  simulations$model_frame <- simulations$model_frame[fitted_rows, ]
  simulations$observed_response <- simulations$observed_response[fitted_rows]
  simulations$predicted_response <- simulations$predicted_response[fitted_rows]
  simulations$simulated_responses <- simulations$simulated_responses[, fitted_rows]
  simulations$model_frame$role[which(simulations$model_frame$dyad == 11)[1]] <- NA
  simulations$model_frame$dyad[which(simulations$model_frame$dyad == 6)[1]] <- NA
  warnings <- character()
  withCallingHandlers(
    result <- check_partner_dependence(simulations, "dyad", "role", plot = FALSE),
    warning = function(warning) {
      warnings <<- c(warnings, conditionMessage(warning))
      invokeRestart("muffleWarning")
    }
  )
  expect_length(warnings, 2L)
  expect_true(any(grepl("Omitted:", warnings, fixed = TRUE)))
  expect_true(any(grepl("female - female", warnings, fixed = TRUE)))
  expect_identical(result$n_pairs, 10L)
  expect_identical(result$n_incomplete_dyads, 2L)
  expect_identical(result$n_missing_dyad_rows, 1L)
  expect_identical(result$n_missing_role_rows, 1L)
  expect_equal(result$compositions$n_pairs, c(2, 4, 4))
  expect_equal(result$compositions$first_statistic, c(NA, 1, 7))
  expect_equal(result$compositions$last_statistic, c(NA, 6, 10))
  expect_length(result$observed_statistics, 10L)
  expect_identical(ncol(result$replicated_statistics), 10L)
  expect_output(print(result), "female - female", fixed = TRUE)

  simulations <- composition_check_test_simulations()
  # Six complete dyads still cannot support three separate two-dyad checks.
  small_group_ids <- simulations$model_frame$dyad
  small_group_ids[!small_group_ids %in% c(1, 2, 6, 7, 11, 12)] <- NA
  expect_error(suppressWarnings(check_partner_dependence(
    simulations, small_group_ids, "role", plot = FALSE
  )), "three complete dyads")
})


test_that("explicit pooling ignores composition and keeps the original moments", {
  simulations <- composition_check_test_simulations()
  result <- check_partner_dependence(simulations, "dyad", role = NULL, plot = FALSE)
  values <- sweep(rbind(simulations$observed_response, simulations$simulated_responses),
                  2, simulations$predicted_response, "-")
  expected <- t(apply(values, 1, function(dataset_responses) {
    pairs <- matrix(dataset_responses, ncol = 2, byrow = TRUE)
    between_dyad_variance <- 2 * var(rowMeans(pairs))
    within_dyad_variance <- sum((pairs[, 1] - pairs[, 2])^2) / (2 * nrow(pairs))
    c(sqrt((between_dyad_variance + within_dyad_variance) / 2),
      (between_dyad_variance - within_dyad_variance) /
        (between_dyad_variance + within_dyad_variance),
      sqrt(between_dyad_variance / 2), sqrt(within_dyad_variance / 2))
  }))
  expect_equal(unname(result$observed_statistics), expected[1, ])
  expect_equal(unname(result$replicated_statistics), expected[-1, ])
  expect_identical(result$compositions$label, "All dyads")
  expect_identical(result$n_pairs, 15L)
  expect_equal(result$compositions$n_pairs, 15)
})


test_that("undefined summaries identify their composition", {
  simulations <- composition_check_test_simulations()
  female_pair_rows <- 1:10
  simulations$simulated_responses[1, female_pair_rows] <-
    simulations$predicted_response[female_pair_rows]
  expect_warning(check_partner_dependence(
    simulations, "dyad", "role", plot = FALSE
  ), "Undefined simulated summaries.*female - female")
  simulations$observed_response[female_pair_rows] <-
    simulations$predicted_response[female_pair_rows]
  expect_error(check_partner_dependence(
    simulations, "dyad", "role", plot = FALSE
  ), "Observed.*undefined.*female - female")
})


test_that("one fitted model checks all 360 dyads within their compositions", {
  skip_if_not_installed("glmmTMB")
  withr::local_seed(451)
  model_data <- data.frame(
    dyad = factor(rep(seq_len(360), each = 2)),
    role = factor(c(rep("female", 240), rep(c("female", "male"), 120),
                    rep("male", 240)))
  )
  model_data$outcome <- 0.4 * (model_data$role == "male") +
    rep(stats::rnorm(360, sd = 0.6), each = 2) + stats::rnorm(720, sd = 0.8)
  model <- glmmTMB::glmmTMB(outcome ~ role + (1 | dyad), data = model_data)
  expect_identical(model$fit$convergence, 0L)
  expect_true(model$sdr$pdHess)
  simulations <- simulate_dyad_responses(model, nsim = 5, seed = 452)
  result <- check_partner_dependence(simulations, "dyad", "role", plot = FALSE)
  expect_identical(result$n_pairs, 360L)
  expect_equal(result$compositions$n_pairs, rep(120, 3))
  expect_identical(dim(result$replicated_statistics), c(5L, 14L))
  expect_true(all(is.finite(result$observed_statistics)))
  expect_true(all(is.finite(result$replicated_statistics)))
})
