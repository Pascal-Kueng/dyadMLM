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
    for (composition_index in seq_len(3)) {
      # Each ten-row block contains five dyads of one composition.
      fitted_rows <- seq_len(10) + (composition_index - 1L) * 10L
      expected <- t(apply(values[, fitted_rows], 1, function(dataset_responses) {
        pairs <- matrix(dataset_responses, ncol = 2, byrow = TRUE)
        if (composition_index == 2L) {
          dyad_average <- rowMeans(pairs)
          half_difference <- (pairs[, 1] - pairs[, 2]) / 2
          return(c(sd(pairs[, 1]), sd(pairs[, 2]), cor(pairs[, 1], pairs[, 2]),
                   sd(dyad_average), sd(half_difference),
                   cor(dyad_average, half_difference)))
        }
        between_dyad_variance <- 2 * var(rowMeans(pairs))
        within_dyad_variance <- sum((pairs[, 1] - pairs[, 2])^2) / (2 * nrow(pairs))
        c(sqrt((between_dyad_variance + within_dyad_variance) / 2),
          (between_dyad_variance - within_dyad_variance) /
            (between_dyad_variance + within_dyad_variance),
          sqrt(between_dyad_variance / 2), sqrt(within_dyad_variance / 2))
      }))
      composition_statistics <- result$compositions$statistics[[composition_index]]
      expect_s3_class(composition_statistics, "tbl_df")
      expect_identical(composition_statistics$dataset,
                       c("observed", paste0("simulation_", 1:3)))
      expect_equal(unname(as.matrix(composition_statistics[-1])), expected)
    }
    expect_s3_class(result$compositions, "tbl_df")
    expect_identical(names(result$compositions), c("label", "n_pairs", "statistics"))
    expect_identical(result$compositions$label,
                     c("female - female", "female - male", "male - male"))
    expect_equal(result$compositions$n_pairs, c(5, 5, 5))
    expect_identical(result$n_pairs, 15L)
    expect_identical(result$n_simulations, 3L)
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
  expect_equal(reversed$compositions$statistics[[1]], original$compositions$statistics[[3]])
  expect_equal(reversed$compositions$statistics[[3]], original$compositions$statistics[[1]])
  expected_mixed_statistics <- as.matrix(original$compositions$statistics[[2]][-1])
  expected_mixed_statistics <- expected_mixed_statistics[, c(2, 1, 3:6)]
  expected_mixed_statistics[, 6] <- -expected_mixed_statistics[, 6]
  expect_equal(unname(as.matrix(reversed$compositions$statistics[[2]][-1])),
               unname(expected_mixed_statistics))
  expect_identical(names(reversed$compositions$statistics[[2]])[2:3],
                   c("SD (male)", "SD (female)"))
})


test_that("additional roles form another distinguishable composition", {
  simulations <- composition_check_test_simulations(include_parent_child = TRUE)
  result <- check_partner_dependence(simulations, "dyad", "role", plot = FALSE)
  expect_identical(result$compositions$label, c(
    "female - female", "female - male", "male - male", "mother - child"
  ))
  expect_equal(result$compositions$n_pairs, rep(5, 4))
  parent_child_statistics <- result$compositions$statistics[[4]]
  expect_identical(dim(parent_child_statistics), c(4L, 7L))
  parent_child_rows <- 31:40
  centred_response <- simulations$observed_response - simulations$predicted_response
  pairs <- matrix(centred_response[parent_child_rows], ncol = 2, byrow = TRUE)
  dyad_average <- rowMeans(pairs)
  half_difference <- (pairs[, 1] - pairs[, 2]) / 2
  expect_equal(unname(unlist(parent_child_statistics[1, -1])), c(
    sd(pairs[, 1]), sd(pairs[, 2]), cor(pairs[, 1], pairs[, 2]),
    sd(dyad_average), sd(half_difference), cor(dyad_average, half_difference)
  ))
  expect_identical(names(parent_child_statistics)[2:3],
                   c("SD (mother)", "SD (child)"))
})


test_that("rounded role labels cannot merge distinct compositions", {
  simulations <- composition_check_test_simulations()
  expected <- check_partner_dependence(simulations, "dyad", "role", plot = FALSE)
  simulations$model_frame$role <- 1e15 + as.integer(simulations$model_frame$role)
  expect_length(unique(as.character(simulations$model_frame$role)), 1L)
  result <- check_partner_dependence(simulations, "dyad", "role", plot = FALSE)
  for (composition_index in seq_len(3)) {
    expect_equal(unname(as.matrix(result$compositions$statistics[[composition_index]][-1])),
                 unname(as.matrix(expected$compositions$statistics[[composition_index]][-1])))
  }
  mixed_statistic_names <- names(result$compositions$statistics[[2]])
  expect_identical(mixed_statistic_names[2], mixed_statistic_names[3])
  expect_equal(result$compositions$n_pairs, expected$compositions$n_pairs)
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
  expect_null(result$compositions$statistics[[1]])
  expect_identical(dim(result$compositions$statistics[[2]]), c(4L, 7L))
  expect_identical(dim(result$compositions$statistics[[3]]), c(4L, 5L))
  expect_output(print(result), "female - female", fixed = TRUE)

  simulations <- composition_check_test_simulations()
  # Six complete dyads still cannot support three separate two-dyad checks.
  small_group_ids <- simulations$model_frame$dyad
  small_group_ids[!small_group_ids %in% c(1, 2, 6, 7, 11, 12)] <- NA
  simulations$model_frame$dyad <- small_group_ids
  expect_error(suppressWarnings(check_partner_dependence(
    simulations, "dyad", "role", plot = FALSE
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
  expect_equal(unname(as.matrix(result$compositions$statistics[[1]][-1])), expected)
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
  expect_identical(result$n_simulations, 5L)
  expect_identical(lapply(result$compositions$statistics, dim),
                   list(c(6L, 5L), c(6L, 7L), c(6L, 5L)))
  for (composition_statistics in result$compositions$statistics) {
    expect_true(all(is.finite(as.matrix(composition_statistics[-1]))))
  }
})
