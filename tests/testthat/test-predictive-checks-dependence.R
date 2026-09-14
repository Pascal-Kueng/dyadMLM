partner_check_test_simulations <- function() {
  frame <- data.frame(
    dyad = factor(rep(1:5, each = 2)),
    role = factor(rep(c("female", "male"), 5))
  )
  center <- seq(0.5, 5, length.out = 10)
  observed <- c(-2, -1.5, -1, -0.4, 0, 0.2, 1, 0.7, 2, 1.8)
  replicated <- rbind(
    c(-2, -1.7, -1, -0.6, 0, 0.1, 1, 0.8, 2, 1.6),
    c(-2, 1.5, -1, 0.7, 0, -0.2, 1, -0.8, 2, -1.7),
    c(-1, 0.2, 0.5, -0.8, 1.2, 0.4, -0.4, 1, 0.8, -0.5),
    c(-1.5, -1.2, -0.7, -0.3, 0.2, 0.1, 0.9, 0.8, 1.8, 1.4)
  )
  # Mix dyads and role order while keeping every response aligned with its row.
  rows <- c(1, 4, 6, 3, 8, 2, 9, 5, 10, 7)
  structure(list(
    observed_response = (center + observed)[rows],
    simulated_responses = sweep(replicated, 2, center, "+")[, rows],
    predicted_response = center[rows], model_frame = frame[rows, ]
  ), class = c("dyadMLM_response_simulations", "list"), dyadMLM = list(
    backend = "glmmTMB", family = "gaussian", link = "identity",
    reference = "plug-in predictive", random_effects = "new",
    parameter_uncertainty = "excluded", seed = 123L
  ))
}


test_that("model-centred summaries use aligned pairs and empirical references", {
  simulations <- partner_check_test_simulations()
  attr(simulations, "dyadMLM")$reference <- "known-parameter oracle"
  attr(simulations, "dyadMLM")$random_effects <- "known covariance"
  attr(simulations, "dyadMLM")$parameter_uncertainty <- "not applicable"
  result <- check_partner_dependence(simulations, dyad = "dyad", plot = FALSE)
  pairs <- matrix(order(simulations$model_frame$dyad), ncol = 2, byrow = TRUE)
  responses <- sweep(rbind(simulations$observed_response,
                          simulations$simulated_responses),
                     2, simulations$predicted_response, "-")
  expected <- t(apply(responses, 1, function(y) {
    calculate_partner_pair_statistics(y[pairs[, 1]], y[pairs[, 2]], FALSE)
  }))
  table <- result$statistics_table
  draws <- expected[-1, , drop = FALSE]

  expect_s3_class(result, "dyadMLM_partner_check")
  expect_named(result, c("statistics_table", "replicated_statistics", "role_order",
                        "n_pairs", "n_incomplete_dyads", "n_missing_dyad_rows",
                        "n_missing_role_rows", "response"))
  expect_equal(table$observed_value, unname(expected[1, ]))
  expect_equal(result$replicated_statistics, draws)
  expect_identical(table$statistic_name, colnames(draws))
  expect_identical(table$n_defined, rep(4L, ncol(draws)))
  expect_equal(
    unname(t(as.matrix(table[c("replicated_lower", "replicated_median", "replicated_upper")]))),
    unname(apply(draws, 2, stats::quantile, probs = c(0.025, 0.5, 0.975)))
  )
  expect_equal(table$observed_quantile, vapply(seq_len(ncol(draws)), function(i) {
    (1 + sum(draws[, i] <= expected[1, i])) / nrow(expected)
  }, numeric(1)))
  expect_identical(result$role_order, character())
  expect_identical(result$n_pairs, 5L)
  expect_identical(result$response, "model-centred")
  expect_identical(attr(result, "dyadMLM"), attr(simulations, "dyadMLM"))
  expect_output(print(result), "Reference: 4 known-parameter oracle", fixed = TRUE)
})


test_that("role-specific summaries use the requested responses and orientation", {
  simulations <- partner_check_test_simulations()
  frame <- simulations$model_frame
  pairs <- matrix(order(frame$dyad, frame$role), ncol = 2, byrow = TRUE)
  responses <- rbind(simulations$observed_response, simulations$simulated_responses)

  for (response in c("model-centred", "raw")) {
    result <- check_partner_dependence(
      simulations, dyad = "dyad", role = "role", response = response, plot = FALSE
    )
    values <- if (response == "raw") responses else
      sweep(responses, 2, simulations$predicted_response, "-")
    # Independent formulas check all six summaries for observed and simulated data.
    expected <- t(apply(values, 1, function(y) {
      first <- y[pairs[, 1]]
      second <- y[pairs[, 2]]
      average <- (first + second) / 2
      difference <- (first - second) / 2
      c(sd(first), sd(second), cor(first, second), sd(average), sd(difference),
        cor(average, difference))
    }))
    expect_equal(result$statistics_table$observed_value, expected[1, ])
    expect_equal(unname(result$replicated_statistics), expected[-1, ])
    expect_identical(result$response, response)
    expect_identical(result$role_order, c("female", "male"))
  }

  # Reversing role levels exchanges the member SDs and reverses only the last sign.
  original <- check_partner_dependence(simulations, "dyad", "role", plot = FALSE)
  simulations$model_frame$role <- relevel(frame$role, "male")
  reversed <- check_partner_dependence(simulations, "dyad", "role", plot = FALSE)
  permutation <- c(2, 1, 3, 4, 5, 6)
  signs <- c(1, 1, 1, 1, 1, -1)
  expect_identical(reversed$role_order, c("male", "female"))
  expect_equal(reversed$statistics_table$observed_value,
               original$statistics_table$observed_value[permutation] * signs)
  expect_equal(unname(reversed$replicated_statistics),
               unname(sweep(original$replicated_statistics[, permutation], 2, signs, "*")))
  expect_match(reversed$statistics_table$label[5], "male minus female", fixed = TRUE)
})


test_that("exchangeable moments are unchanged by independent member swaps", {
  first <- c(-2, -0.7, 0.4, 1.3, 2.1)
  second <- c(-1.4, -0.2, 0.8, 0.5, 1.7)
  statistics <- calculate_partner_pair_statistics(first, second, FALSE)
  # Woody and Sadler's between/within moments give an independent reference.
  between <- 2 * var((first + second) / 2)
  within <- sum((first - second)^2) / (2 * length(first))
  expect_equal(unname(statistics), c(
    sqrt((between + within) / 2), (between - within) / (between + within),
    sqrt(between / 2), sqrt(within / 2)
  ))
  pairs <- cbind(first, second)
  pairs[c(2, 5), ] <- pairs[c(2, 5), 2:1]
  expect_equal(calculate_partner_pair_statistics(pairs[, 1], pairs[, 2], FALSE),
               statistics)
})


test_that("identifiers accept columns, external vectors, and data-mask selectors", {
  simulations <- partner_check_test_simulations()
  ids <- simulations$model_frame$dyad
  roles <- simulations$model_frame$role
  expected <- check_partner_dependence(simulations, "dyad", "role", plot = FALSE)
  dyad_column <- "dyad"
  role_column <- "role"
  # Conflicting caller names must not override fitted columns.
  dyad <- role <- rep(NA, 10)
  results <- list(
    check_partner_dependence(simulations, dyad, role, plot = FALSE),
    check_partner_dependence(simulations, ids, roles, plot = FALSE),
    check_partner_dependence(simulations, .data$dyad, .data$role, plot = FALSE),
    check_partner_dependence(simulations, .data[[dyad_column]],
                             .data[[role_column]], plot = FALSE)
  )
  fields <- c("statistics_table", "replicated_statistics", "n_pairs")
  for (result in results) expect_equal(result[fields], expected[fields])
  expect_identical(resolve_fitted_row_argument(rlang::quo(time), "time",
                                               data.frame(time = 1:5)), 1:5)

  dyad <- ids
  role <- roles
  dyad[1] <- NA
  role[4] <- NA
  expect_warning(external <- check_partner_dependence(
    simulations, .env$dyad, .env$role, plot = FALSE
  ), "were omitted")
  expect_identical(external$n_pairs, 3L)
  expect_identical(external$n_missing_dyad_rows, 1L)
  expect_identical(external$n_missing_role_rows, 1L)
})


test_that("wrappers preserve identifier expressions and an omitted role", {
  simulations <- partner_check_test_simulations()
  check_from_wrapper <- function(simulations, dyad, role = NULL) {
    check_partner_dependence(simulations, {{ dyad }}, {{ role }}, plot = FALSE)
  }
  ids <- simulations$model_frame$dyad
  ids[1] <- NA
  expect_warning(expected <- check_partner_dependence(simulations, ids, plot = FALSE),
                 "were omitted")
  expect_warning(wrapped <- check_from_wrapper(simulations, ids), "were omitted")
  fields <- c("statistics_table", "replicated_statistics", "n_pairs",
              "n_missing_dyad_rows", "n_missing_role_rows")
  expect_equal(wrapped[fields], expected[fields])
  expect_identical(wrapped$n_missing_dyad_rows, 1L)
  expect_identical(wrapped$role_order, character())

  expected <- check_partner_dependence(simulations, "dyad", "role", plot = FALSE)
  expect_equal(check_from_wrapper(simulations, dyad, role)$statistics_table,
               expected$statistics_table)
  expect_equal(check_from_wrapper(simulations, "dyad", "role")$statistics_table,
               expected$statistics_table)
  # A broken expression must not fall back to the wrapper formal's column name.
  expect_error(check_from_wrapper(simulations, does_not_exist), "does_not_exist")
})


test_that("missing identifiers and incomplete dyads warn and are counted", {
  simulations <- partner_check_test_simulations()
  ids <- simulations$model_frame$dyad
  roles <- simulations$model_frame$role
  ids[which(ids == "5")[1]] <- NA
  roles[ids == "4"] <- NA
  expect_warning(result <- check_partner_dependence(simulations, ids, roles, plot = FALSE),
                 "were omitted. Print the result for counts.", fixed = TRUE)
  expect_identical(result$n_pairs, 3L)
  expect_identical(result$n_missing_dyad_rows, 1L)
  expect_identical(result$n_missing_role_rows, 2L)
  expect_identical(result$n_incomplete_dyads, 2L)
  printed <- paste(capture.output(print(result)), collapse = "\n")
  expect_match(printed, "incomplete dyads: 2", fixed = TRUE)
  expect_match(printed, "missing dyad IDs: 1", fixed = TRUE)
  expect_match(printed, "missing roles: 2", fixed = TRUE)
})


test_that("role omission does not lose an already incomplete dyad", {
  simulations <- partner_check_test_simulations()
  ids <- simulations$model_frame$dyad
  roles <- simulations$model_frame$role
  rows <- which(ids == "4")
  ids[rows[1]] <- NA
  roles[rows[2]] <- NA
  expect_warning(result <- check_partner_dependence(simulations, ids, roles, plot = FALSE),
                 "were omitted")
  expect_identical(result$n_pairs, 4L)
  expect_identical(result$n_incomplete_dyads, 1L)
  expect_identical(result$n_missing_dyad_rows, 1L)
  expect_identical(result$n_missing_role_rows, 1L)
})


test_that("invalid simulation objects, identifiers, and pair structures fail clearly", {
  simulations <- partner_check_test_simulations()
  expect_error(check_partner_dependence(list(), "dyad"), "must be created by")
  expect_error(check_partner_dependence(simulations), "must identify")
  expect_error(check_partner_dependence(simulations, "unknown"), "`dyad` must name a column")
  expect_error(check_partner_dependence(simulations, "dyad", "unknown"),
               "`role` must name a column")
  expect_error(check_partner_dependence(simulations, 1:3), "vector of length 10")

  ids <- as.character(simulations$model_frame$dyad)
  roles <- as.character(simulations$model_frame$role)
  # Missing roles must not hide a third fitted response in a dyad.
  extra <- which(ids == "5")[1]
  ids[extra] <- "1"
  roles[extra] <- NA
  expect_error(check_partner_dependence(simulations, ids, roles),
               "at most two fitted responses")

  ids <- simulations$model_frame$dyad
  ids[ids %in% c("3", "4", "5")] <- NA
  expect_error(check_partner_dependence(simulations, ids), "At least three complete dyads")

  roles <- as.character(simulations$model_frame$role)
  first_dyad <- which(simulations$model_frame$dyad == "1")
  roles[first_dyad] <- "female"
  expect_error(check_partner_dependence(simulations, "dyad", roles),
               "exactly one row for each role")
  roles[first_dyad[1]] <- "other"
  expect_error(check_partner_dependence(simulations, "dyad", roles), "Exactly two role values")
})


test_that("zero-variance draws warn for centred and raw exchangeable checks", {
  for (response in c("model-centred", "raw")) {
    simulations <- partner_check_test_simulations()
    simulations$simulated_responses[1, ] <- if (response == "raw") 1 else
      simulations$predicted_response
    expect_warning(check_partner_dependence(simulations, "dyad", response = response,
                                              plot = FALSE), "Undefined simulated summaries")
  }
})


test_that("one simulation retains every statistic and its reference limits", {
  simulations <- partner_check_test_simulations()
  simulations$simulated_responses <- simulations$simulated_responses[1, , drop = FALSE]
  expect_output(print(simulations), "1 complete gaussian response dataset", fixed = TRUE)
  for (role in list(NULL, "role")) {
    result <- check_partner_dependence(simulations, "dyad", .env$role, plot = FALSE)
    table <- result$statistics_table
    expect_identical(dim(result$replicated_statistics), c(1L, nrow(table)))
    expect_identical(colnames(result$replicated_statistics), table$statistic_name)
    expect_output(print(result), "Reference: 1 plug-in predictive", fixed = TRUE)
    for (column in c("replicated_lower", "replicated_median", "replicated_upper")) {
      expect_equal(table[[column]], unname(result$replicated_statistics[1, ]))
    }
  }
})


test_that("checks plot by default, accept positional plot, and return invisibly", {
  simulations <- partner_check_test_simulations()
  plot_calls <- 0L
  local_mocked_bindings(plot.dyadMLM_partner_check = function(x, ...) {
    plot_calls <<- plot_calls + 1L
    invisible(x)
  }, .package = "dyadMLM")
  default <- withVisible(check_partner_dependence(simulations, "dyad"))
  expect_false(default$visible)
  expect_s3_class(default$value, "dyadMLM_partner_check")
  expect_identical(plot_calls, 1L)
  for (result in list(
    withVisible(check_partner_dependence(simulations, "dyad", plot = FALSE)),
    withVisible(check_partner_dependence(simulations, "dyad", NULL, FALSE))
  )) expect_false(result$visible)
  expect_identical(plot_calls, 1L)
})


test_that("printing shows the result and all panels preserve graphics settings", {
  simulations <- partner_check_test_simulations()
  exchangeable <- check_partner_dependence(simulations, "dyad", plot = FALSE)
  distinguishable <- check_partner_dependence(simulations, "dyad", "role", plot = FALSE)
  for (result in list(exchangeable, distinguishable)) {
    expect_identical(result$statistics_table$parameterization,
                     rep(c("member", "mean_difference"), each = nrow(result$statistics_table) / 2))
  }
  printed <- paste(capture.output(visible <- withVisible(print(distinguishable))),
                   collapse = "\n")
  expect_match(printed, "6 statistics using 5 complete pairs", fixed = TRUE)
  expect_match(printed, "model-centred", fixed = TRUE)
  expect_match(printed, "Position", fixed = TRUE)
  expect_match(printed, as.character(round(distinguishable$statistics_table$observed_value[1], 3)),
               fixed = TRUE)
  expect_false(visible$visible)
  expect_identical(visible$value, distinguishable)

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(plt = c(0.2, 0.8, 0.2, 0.8))
  settings <- graphics::par(c("mar", "plt"))
  original_title <- graphics::title
  local_mocked_bindings(title = function(main = NULL, ...) {
    titles <<- c(titles, main)
    original_title(main = main, ...)
  }, .package = "graphics")
  for (result in list(exchangeable, distinguishable)) {
    titles <- character()
    plotted <- withVisible(plot(result, ask = FALSE))
    expect_false(plotted$visible)
    expect_identical(plotted$value, result)
    expect_identical(titles, result$statistics_table$label)
    expect_equal(graphics::par(c("mar", "plt")), settings)
  }
  ask_values <- logical()
  local_mocked_bindings(devAskNewPage = function(ask = NULL) {
    ask_values <<- c(ask_values, ask)
    TRUE
  }, .package = "grDevices")
  plot(exchangeable, ask = FALSE)
  expect_identical(ask_values, c(FALSE, TRUE))
})


test_that("explicit NA factor levels are missing dyad IDs and roles", {
  simulations <- partner_check_test_simulations()
  ids <- as.character(simulations$model_frame$dyad)
  roles <- as.character(simulations$model_frame$role)
  roles[ids == "4" & roles == "female"] <- NA_character_
  ids[ids == "5"] <- NA_character_
  expect_warning(result <- check_partner_dependence(
    simulations, dyad = factor(ids, exclude = NULL),
    role = factor(roles, exclude = NULL), plot = FALSE
  ), "were omitted")
  expect_identical(result$n_missing_dyad_rows, 2L)
  expect_identical(result$n_missing_role_rows, 1L)
  expect_identical(result$n_incomplete_dyads, 1L)
  expect_identical(result$n_pairs, 3L)
  expect_identical(result$role_order, c("female", "male"))
})


test_that("distinct numeric dyad IDs remain separate despite rounded labels", {
  simulations <- partner_check_test_simulations()
  expected <- check_partner_dependence(simulations, "dyad", plot = FALSE)
  simulations$model_frame$dyad <- 1e15 + as.integer(simulations$model_frame$dyad)
  result <- check_partner_dependence(simulations, "dyad", plot = FALSE)
  expect_identical(result$n_pairs, 5L)
  expect_equal(result$statistics_table, expected$statistics_table)
  expect_equal(result$replicated_statistics, expected$replicated_statistics)
})


test_that("predictive histograms show the full outer bars", {
  # Every pair has half-difference 1; its RMS equals the dataset's scale.
  values <- as.vector(rbind(c(-1, 0, 1), c(-3, -2, -1)))
  scales <- seq(0.300099, 0.301001, length.out = 25)
  simulations <- partner_check_test_simulations()
  simulations$model_frame <- data.frame(dyad = rep(1:3, each = 2))
  simulations$observed_response <- values * 0.30055
  simulations$predicted_response <- rep(0, 6)
  simulations$simulated_responses <- scales %o% values
  result <- check_partner_dependence(simulations, "dyad", plot = FALSE)

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  plot(result, ask = FALSE)
  # The last panel shows half-difference RMS, with breaks beyond data extrema.
  histogram <- graphics::hist(scales, breaks = 20, plot = FALSE)
  visible <- graphics::par("usr")[1:2]
  expect_lte(visible[1], min(histogram$breaks))
  expect_gte(visible[2], max(histogram$breaks))
})
