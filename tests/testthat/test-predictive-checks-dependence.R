partner_check_test_simulations <- function() {
  model_frame <- data.frame(
    dyad = factor(rep(seq_len(5), each = 2)),
    role = factor(rep(c("female", "male"), times = 5))
  )
  fixed_effect_prediction <- seq(0.5, 5, length.out = nrow(model_frame))
  observed_residuals <- c(
    -2, -1.5,
    -1, -0.4,
    0, 0.2,
    1, 0.7,
    2, 1.8
  )
  simulated_residuals <- rbind(
    c(-2, -1.7, -1, -0.6, 0, 0.1, 1, 0.8, 2, 1.6),
    c(-2, 1.5, -1, 0.7, 0, -0.2, 1, -0.8, 2, -1.7),
    c(-1.0, 0.2, 0.5, -0.8, 1.2, 0.4, -0.4, 1.0, 0.8, -0.5),
    c(-1.5, -1.2, -0.7, -0.3, 0.2, 0.1, 0.9, 0.8, 1.8, 1.4)
  )

  # Mix dyads and role order while preserving fitted-row alignment.
  row_order <- c(1, 4, 6, 3, 8, 2, 9, 5, 10, 7)
  model_frame <- model_frame[row_order, , drop = FALSE]
  fixed_effect_prediction <- fixed_effect_prediction[row_order]
  observed_residuals <- observed_residuals[row_order]
  simulated_residuals <- simulated_residuals[, row_order, drop = FALSE]

  simulations <- list(
    observed_response = fixed_effect_prediction + observed_residuals,
    simulated_responses = sweep(
      simulated_residuals,
      MARGIN = 2,
      STATS = fixed_effect_prediction,
      FUN = "+"
    ),
    fixed_effect_prediction = fixed_effect_prediction,
    model_frame = model_frame,
    backend = "glmmTMB",
    family = "gaussian",
    link = "identity",
    reference = "plug-in predictive",
    random_effects = "new",
    nsim = nrow(simulated_residuals),
    seed = 123L,
    call = quote(simulate_dyad_responses(model))
  )
  class(simulations) <- c("dyadMLM_response_simulations", "list")

  return(simulations)
}


test_that("exchangeable summaries use aligned centered pairs", {
  simulations <- partner_check_test_simulations()
  result <- check_partner_dependence(
    simulations,
    dyad = "dyad",
    plot = FALSE
  )

  rows_by_dyad <- split(
    seq_len(nrow(simulations$model_frame)),
    simulations$model_frame$dyad
  )
  paired_row_indices <- rows_by_dyad |>
    unlist(use.names = FALSE) |>
    matrix(ncol = 2L, byrow = TRUE)

  centered_responses <- rbind(
    simulations$observed_response - simulations$fixed_effect_prediction,
    sweep(
      simulations$simulated_responses,
      MARGIN = 2,
      STATS = simulations$fixed_effect_prediction,
      FUN = "-"
    )
  )
  expected_statistics <- t(apply(
    centered_responses,
    MARGIN = 1,
    FUN = calculate_partner_residual_statistics,
    paired_row_indices = paired_row_indices,
    role_specific = FALSE
  ))

  expect_s3_class(result, "dyadMLM_partner_check")
  expect_named(
    result,
    c(
      "statistics_table", "replicated_statistics", "role_order", "n_pairs",
      "n_incomplete_dyads", "n_missing_dyad_rows", "n_missing_role_rows",
      "reference", "random_effects", "nsim", "seed", "call"
    )
  )
  expect_named(
    result$statistics_table,
    c(
      "statistic_name", "parameterization", "label", "observed_value",
      "replicated_median", "replicated_lower", "replicated_upper",
      "observed_quantile"
    )
  )
  expect_equal(
    result$statistics_table$observed_value,
    unname(expected_statistics[1L, ])
  )
  expect_equal(
    unname(result$replicated_statistics),
    unname(expected_statistics[-1L, , drop = FALSE])
  )
  expect_equal(
    result$statistics_table$replicated_median,
    unname(apply(expected_statistics[-1L, , drop = FALSE], 2, stats::median))
  )

  expected_intervals <- apply(
    expected_statistics[-1L, , drop = FALSE],
    2,
    stats::quantile,
    probs = c(0.025, 0.975),
    names = FALSE
  )
  expect_equal(
    result$statistics_table$replicated_lower,
    unname(expected_intervals[1L, ])
  )
  expect_equal(
    result$statistics_table$replicated_upper,
    unname(expected_intervals[2L, ])
  )
  expected_quantiles <- vapply(
    seq_len(ncol(expected_statistics)),
    function(statistic_index) {
      (1 + sum(
        expected_statistics[-1L, statistic_index] <=
          expected_statistics[1L, statistic_index]
      )) / nrow(centered_responses)
    },
    numeric(1)
  )
  expect_equal(
    result$statistics_table$observed_quantile,
    expected_quantiles
  )
  expect_identical(result$role_order, character())
  expect_identical(result$n_pairs, 5L)
  expect_identical(result$n_incomplete_dyads, 0L)
  expect_identical(result$reference, simulations$reference)
  expect_identical(result$random_effects, simulations$random_effects)
})


test_that("fitted-row identifiers accept bare, quoted, and external forms", {
  simulations <- partner_check_test_simulations()
  external_dyad_vector <- simulations$model_frame$dyad
  external_role_vector <- simulations$model_frame$role

  bare_result <- check_partner_dependence(
    simulations,
    dyad = dyad,
    role = role,
    plot = FALSE
  )
  quoted_result <- check_partner_dependence(
    simulations,
    dyad = "dyad",
    role = "role",
    plot = FALSE
  )
  external_result <- check_partner_dependence(
    simulations,
    dyad = external_dyad_vector,
    role = external_role_vector,
    plot = FALSE
  )

  comparison_fields <- c(
    "statistics_table",
    "replicated_statistics",
    "n_pairs"
  )
  expect_equal(bare_result[comparison_fields], quoted_result[comparison_fields])
  expect_equal(
    external_result[comparison_fields],
    quoted_result[comparison_fields]
  )

  # The future temporal argument must prefer a fitted `time` column over the
  # inherited stats::time() generic.
  temporal_model_frame <- data.frame(time = seq_len(5))
  expect_identical(
    resolve_fitted_row_argument(
      argument_quo = rlang::quo(time),
      argument_name = "time",
      model_frame = temporal_model_frame
    ),
    temporal_model_frame$time
  )
})


test_that("fitted-row identifiers can be forwarded through wrappers", {
  simulations <- partner_check_test_simulations()
  external_dyad_vector <- simulations$model_frame$dyad
  external_dyad_vector[[1L]] <- NA

  check_from_wrapper <- function(simulations, dyad, role = NULL) {
    check_partner_dependence(
      simulations,
      dyad = dyad,
      role = role,
      plot = FALSE
    )
  }

  direct_result <- check_partner_dependence(
    simulations,
    dyad = external_dyad_vector,
    plot = FALSE
  )
  wrapped_result <- check_from_wrapper(simulations, external_dyad_vector)

  comparison_fields <- c(
    "statistics_table",
    "replicated_statistics",
    "n_pairs",
    "n_missing_dyad_rows",
    "n_missing_role_rows"
  )
  expect_equal(
    wrapped_result[comparison_fields],
    direct_result[comparison_fields]
  )
  expect_identical(wrapped_result$n_missing_dyad_rows, 1L)
  expect_true(
    "exchangeable_partner_correlation" %in%
      wrapped_result$statistics_table$statistic_name
  )

  # A broken wrapper argument must not silently fall back to a model-frame
  # column that happens to have the same name as the wrapper formal.
  expect_error(
    check_from_wrapper(simulations, does_not_exist),
    "`dyad` could not be evaluated",
    fixed = TRUE
  )
})


test_that("exchangeable summaries are member-order invariant", {
  first_member_residual <- c(-2.0, -0.7, 0.4, 1.3, 2.1)
  second_member_residual <- c(-1.4, -0.2, 0.8, 0.5, 1.7)
  centered_response <- as.vector(rbind(
    first_member_residual,
    second_member_residual
  ))
  paired_row_indices <- matrix(
    seq_along(centered_response),
    ncol = 2L,
    byrow = TRUE
  )

  statistics <- calculate_partner_residual_statistics(
    centered_response,
    paired_row_indices,
    role_specific = FALSE
  )
  dyad_mean <- (first_member_residual + second_member_residual) / 2
  dyad_half_difference <-
    (first_member_residual - second_member_residual) / 2
  pooled_residual_mean <- mean(c(
    first_member_residual,
    second_member_residual
  ))
  first_member_deviation <- first_member_residual - pooled_residual_mean
  second_member_deviation <- second_member_residual - pooled_residual_mean
  expected_partner_correlation <-
    2 * sum(first_member_deviation * second_member_deviation) /
    sum(first_member_deviation^2 + second_member_deviation^2)

  expect_equal(
    statistics[["pooled_residual_sd"]],
    stats::sd(c(first_member_residual, second_member_residual))
  )
  expect_equal(
    statistics[["exchangeable_partner_correlation"]],
    expected_partner_correlation
  )
  expect_equal(
    statistics[["dyad_mean_sd"]],
    stats::sd(dyad_mean)
  )
  expect_equal(
    statistics[["half_difference_sd"]],
    sqrt(mean(dyad_half_difference^2))
  )

  # Independently exchanging member positions changes difference signs but
  # cannot change any exchangeable-dyad summary.
  swapped_row_indices <- paired_row_indices
  swapped_row_indices[c(2, 5), ] <- swapped_row_indices[c(2, 5), 2:1]
  expect_equal(
    calculate_partner_residual_statistics(
      centered_response,
      swapped_row_indices,
      role_specific = FALSE
    ),
    statistics
  )
})


test_that("role-specific partner dependence is oriented by role", {
  simulations <- partner_check_test_simulations()
  result <- check_partner_dependence(
    simulations,
    dyad = simulations$model_frame$dyad,
    role = simulations$model_frame$role,
    plot = FALSE
  )

  observed_residuals <-
    simulations$observed_response - simulations$fixed_effect_prediction
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

  observed_statistics <- setNames(
    result$statistics_table$observed_value,
    result$statistics_table$statistic_name
  )
  female_residuals <- observed_residuals[female_rows]
  male_residuals <- observed_residuals[male_rows]
  dyad_mean <- (female_residuals + male_residuals) / 2
  half_difference <- (female_residuals - male_residuals) / 2

  expect_identical(result$role_order, c("female", "male"))
  expect_equal(
    observed_statistics[["role_1_residual_sd"]],
    stats::sd(female_residuals)
  )
  expect_equal(
    observed_statistics[["role_2_residual_sd"]],
    stats::sd(male_residuals)
  )
  expect_equal(
    observed_statistics[["partner_correlation"]],
    stats::cor(female_residuals, male_residuals)
  )
  expect_equal(
    observed_statistics[["dyad_mean_sd"]],
    stats::sd(dyad_mean)
  )
  expect_equal(
    observed_statistics[["half_difference_sd"]],
    stats::sd(half_difference)
  )
  expect_equal(
    observed_statistics[["dyad_mean_half_difference_correlation"]],
    stats::cor(dyad_mean, half_difference)
  )

  member_covariance <-
    observed_statistics[["partner_correlation"]] *
    observed_statistics[["role_1_residual_sd"]] *
    observed_statistics[["role_2_residual_sd"]]
  expect_equal(
    observed_statistics[["dyad_mean_sd"]]^2,
    (
      observed_statistics[["role_1_residual_sd"]]^2 +
        observed_statistics[["role_2_residual_sd"]]^2 +
        2 * member_covariance
    ) / 4
  )
  expect_equal(
    observed_statistics[["half_difference_sd"]]^2,
    (
      observed_statistics[["role_1_residual_sd"]]^2 +
        observed_statistics[["role_2_residual_sd"]]^2 -
        2 * member_covariance
    ) / 4
  )
  mean_difference_covariance <-
    observed_statistics[["dyad_mean_half_difference_correlation"]] *
    observed_statistics[["dyad_mean_sd"]] *
    observed_statistics[["half_difference_sd"]]
  expect_equal(
    mean_difference_covariance,
    (
      observed_statistics[["role_1_residual_sd"]]^2 -
        observed_statistics[["role_2_residual_sd"]]^2
    ) / 4
  )

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
  reordered$fixed_effect_prediction <-
    reordered$fixed_effect_prediction[reordered_rows]
  reordered$simulated_responses <-
    reordered$simulated_responses[, reordered_rows, drop = FALSE]

  reordered_result <- check_partner_dependence(
    reordered,
    dyad = "dyad",
    role = "role",
    plot = FALSE
  )
  expect_equal(reordered_result$statistics_table, result$statistics_table)
  expect_equal(
    reordered_result$replicated_statistics,
    result$replicated_statistics
  )
})


test_that("missing and incomplete pairs are reported", {
  simulations <- partner_check_test_simulations()
  external_dyad_vector <- simulations$model_frame$dyad
  external_role_vector <- simulations$model_frame$role

  external_dyad_vector[
    which(external_dyad_vector == "5")[[1L]]
  ] <- NA
  # Both missing roles must still count the omitted dyad as incomplete.
  external_role_vector[external_dyad_vector == "4"] <- NA

  result <- check_partner_dependence(
    simulations,
    dyad = external_dyad_vector,
    role = external_role_vector,
    plot = FALSE
  )

  expect_identical(result$n_pairs, 3L)
  expect_identical(result$n_missing_dyad_rows, 1L)
  expect_identical(result$n_missing_role_rows, 2L)
  expect_identical(result$n_incomplete_dyads, 2L)

  printed_output <- paste(capture.output(print(result)), collapse = "\n")
  expect_match(
    printed_output,
    paste0(
      "Omitted: incomplete dyads: 2; rows with missing dyad IDs: 1; ",
      "rows with missing roles: 2"
    ),
    fixed = TRUE
  )
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
  no_variation$simulated_responses[1L, ] <-
    no_variation$fixed_effect_prediction
  expect_error(
    check_partner_dependence(no_variation, dyad = "dyad"),
    "insufficient variation",
    fixed = TRUE
  )
})


test_that("pre-existing incomplete dyads remain counted after role omission", {
  simulations <- partner_check_test_simulations()
  external_dyad_vector <- simulations$model_frame$dyad
  external_role_vector <- simulations$model_frame$role

  fourth_dyad_rows <- which(external_dyad_vector == "4")
  external_dyad_vector[fourth_dyad_rows[[1L]]] <- NA
  external_role_vector[fourth_dyad_rows[[2L]]] <- NA

  result <- check_partner_dependence(
    simulations,
    dyad = external_dyad_vector,
    role = external_role_vector,
    plot = FALSE
  )

  expect_identical(result$n_pairs, 4L)
  expect_identical(result$n_incomplete_dyads, 1L)
  expect_identical(result$n_missing_dyad_rows, 1L)
  expect_identical(result$n_missing_role_rows, 1L)
})


test_that("partner check plots by default and returns invisibly", {
  plot_calls <- 0L
  testthat::local_mocked_bindings(
    plot.dyadMLM_partner_check = function(x, ...) {
      plot_calls <<- plot_calls + 1L
      invisible(x)
    },
    .package = "dyadMLM"
  )

  default_result <- withVisible(check_partner_dependence(
    partner_check_test_simulations(),
    dyad = "dyad"
  ))
  expect_false(default_result$visible)
  expect_s3_class(default_result$value, "dyadMLM_partner_check")
  expect_identical(plot_calls, 1L)

  hidden_result <- withVisible(check_partner_dependence(
    partner_check_test_simulations(),
    dyad = "dyad",
    plot = FALSE
  ))
  expect_false(hidden_result$visible)
  expect_s3_class(hidden_result$value, "dyadMLM_partner_check")
  expect_identical(plot_calls, 1L)
})


test_that("partner check has concise print and both plot views", {
  exchangeable_result <- check_partner_dependence(
    partner_check_test_simulations(),
    dyad = "dyad",
    plot = FALSE
  )
  distinguishable_result <- check_partner_dependence(
    partner_check_test_simulations(),
    dyad = "dyad",
    role = "role",
    plot = FALSE
  )

  expect_identical(
    sum(exchangeable_result$statistics_table$parameterization == "member"),
    2L
  )
  expect_identical(
    sum(
      exchangeable_result$statistics_table$parameterization ==
        "mean_difference"
    ),
    2L
  )
  expect_identical(
    sum(distinguishable_result$statistics_table$parameterization == "member"),
    3L
  )
  expect_identical(
    sum(
      distinguishable_result$statistics_table$parameterization ==
        "mean_difference"
    ),
    3L
  )

  printed_output <- capture.output(
    printed_result <- withVisible(print(distinguishable_result))
  )
  expect_match(
    paste(printed_output, collapse = "\n"),
    "<dyadMLM partner-dependence check>",
    fixed = TRUE
  )
  expect_match(
    paste(printed_output, collapse = "\n"),
    "6 statistics from 5 complete pairs",
    fixed = TRUE
  )
  expect_match(
    paste(printed_output, collapse = "\n"),
    "Replicated reference: median and central 95% interval",
    fixed = TRUE
  )
  expect_match(
    paste(printed_output, collapse = "\n"),
    "Observed ",
    fixed = TRUE
  )
  expect_match(
    paste(printed_output, collapse = "\n"),
    " | Median ",
    fixed = TRUE
  )
  expect_match(
    paste(printed_output, collapse = "\n"),
    " | Obs. quantile ",
    fixed = TRUE
  )
  expect_match(
    paste(printed_output, collapse = "\n"),
    sprintf(
      "%.3f",
      distinguishable_result$statistics_table$observed_value[[1L]]
    ),
    fixed = TRUE
  )
  expect_false(printed_result$visible)
  expect_identical(printed_result$value, distinguishable_result)

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(plt = c(0.2, 0.8, 0.2, 0.8))
  previous_margins <- graphics::par("mar")
  previous_plot_region <- graphics::par("plt")
  plotted_result <- withVisible(plot(exchangeable_result, ask = FALSE))
  expect_false(plotted_result$visible)
  expect_identical(plotted_result$value, exchangeable_result)
  expect_equal(graphics::par("mar"), previous_margins)
  expect_equal(graphics::par("plt"), previous_plot_region)
  expect_identical(
    plot(distinguishable_result, parameterization = "member", ask = FALSE),
    distinguishable_result
  )
  expect_identical(
    plot(
      distinguishable_result,
      parameterization = "mean_difference",
      ask = FALSE
    ),
    distinguishable_result
  )
  expect_error(
    plot(exchangeable_result, parameterization = "unknown", ask = FALSE),
    "should be one of",
    fixed = TRUE
  )

  ask_values <- logical()
  testthat::local_mocked_bindings(
    devAskNewPage = function(ask = NULL) {
      ask_values <<- c(ask_values, ask)
      TRUE
    },
    .package = "grDevices"
  )
  expect_identical(
    plot(exchangeable_result, parameterization = "member", ask = FALSE),
    exchangeable_result
  )
  expect_identical(ask_values, c(FALSE, TRUE))
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
    role = "role",
    plot = FALSE
  )

  expect_s3_class(result, "dyadMLM_partner_check")
  expect_identical(result$n_pairs, 20L)
  expect_identical(dim(result$replicated_statistics), c(20L, 6L))
  expect_true(all(is.finite(result$replicated_statistics)))
})
