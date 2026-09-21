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


test_that("model-centred statistics use aligned pairs and retain simulation settings", {
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
    calculate_partner_pair_statistics(y[pairs[, 1]], y[pairs[, 2]])
  }))
  statistics <- result$compositions$statistics[[1]]

  expect_s3_class(result, "dyadMLM_partner_check")
  expect_named(result, c("compositions", "n_pairs", "n_simulations",
                        "n_incomplete_dyads", "n_missing_dyad_rows",
                        "n_missing_role_rows", "response"))
  expect_s3_class(result$compositions, "tbl_df")
  expect_named(result$compositions, c("label", "n_pairs", "statistics"))
  expect_s3_class(statistics, "tbl_df")
  expect_identical(statistics$dataset, c("observed", paste0("simulation_", 1:4)))
  expect_equal(as.matrix(statistics[, -1]), expected)
  expect_identical(names(statistics)[-1], c(
    "Common member SD (exchangeable)", "Partner correlation (exchangeable)",
    "Dyad-average SD", "Half-difference RMS (about zero)"
  ))
  expect_identical(result$n_pairs, 5L)
  expect_identical(result$n_simulations, 4L)
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
    statistics <- result$compositions$statistics[[1]]
    expect_equal(unname(as.matrix(statistics[, -1])), expected)
    expect_identical(names(statistics)[-1], c(
      "SD (female)", "SD (male)", "Partner correlation (female and male)",
      "Dyad-average SD", "Half-difference SD (female minus male)",
      "Dyad-average/role-difference correlation (female minus male)"
    ))
    expect_identical(result$response, response)
  }

  # Reversing role levels exchanges the member SDs and reverses only the last sign.
  original <- check_partner_dependence(simulations, "dyad", "role", plot = FALSE)
  simulations$model_frame$role <- relevel(frame$role, "male")
  reversed <- check_partner_dependence(simulations, "dyad", "role", plot = FALSE)
  permutation <- c(2, 1, 3, 4, 5, 6)
  signs <- c(1, 1, 1, 1, 1, -1)
  original_statistics <- as.matrix(original$compositions$statistics[[1]][, -1])
  reversed_statistics <- as.matrix(reversed$compositions$statistics[[1]][, -1])
  expect_equal(unname(reversed_statistics),
               unname(sweep(original_statistics[, permutation], 2, signs, "*")))
  expect_identical(colnames(reversed_statistics), c(
    "SD (male)", "SD (female)", "Partner correlation (male and female)",
    "Dyad-average SD", "Half-difference SD (male minus female)",
    "Dyad-average/role-difference correlation (male minus female)"
  ))
})


test_that("exchangeable moments are unchanged by independent member swaps", {
  first <- c(-2, -0.7, 0.4, 1.3, 2.1)
  second <- c(-1.4, -0.2, 0.8, 0.5, 1.7)
  statistics <- calculate_partner_pair_statistics(first, second)
  # Woody and Sadler's between/within moments give an independent reference.
  between <- 2 * var((first + second) / 2)
  within <- sum((first - second)^2) / (2 * length(first))
  expect_equal(unname(statistics), c(
    sqrt((between + within) / 2), (between - within) / (between + within),
    sqrt(between / 2), sqrt(within / 2)
  ))
  pairs <- cbind(first, second)
  pairs[c(2, 5), ] <- pairs[c(2, 5), 2:1]
  expect_equal(calculate_partner_pair_statistics(pairs[, 1], pairs[, 2]),
               statistics)
})


test_that("identifiers accept bare and quoted columns and tidy injection", {
  simulations <- partner_check_test_simulations()
  expected <- check_partner_dependence(simulations, "dyad", "role", plot = FALSE)
  dyad_column <- "dyad"
  role_column <- "role"
  # Conflicting caller names must not override fitted columns.
  dyad <- role <- rep(NA, 10)
  results <- list(
    check_partner_dependence(simulations, dyad, role, plot = FALSE),
    check_partner_dependence(simulations, !!dyad_column, !!role_column, plot = FALSE),
    check_partner_dependence(simulations, !!rlang::sym(dyad_column),
                             !!rlang::sym(role_column), plot = FALSE)
  )
  fields <- c("compositions", "n_pairs")
  for (result in results) expect_equal(result[fields], expected[fields])
  expect_identical(resolve_fitted_row_argument(rlang::quo(time), "time",
                                               data.frame(time = 1:5)), 1:5)

})


test_that("missing role columns explain how to supply the fitting data", {
  simulations <- partner_check_test_simulations()
  prepared_data <- simulations$model_frame
  prepared_data$gender <- prepared_data$role
  expected <- check_partner_dependence(simulations, "dyad", "role", plot = FALSE)
  simulations$model_frame$role <- NULL

  for (role_expression in rlang::quos(gender, "gender")) {
    error <- tryCatch(
      check_partner_dependence(simulations, "dyad", !!role_expression, plot = FALSE),
      error = identity
    )
    expect_s3_class(error, "error")
    expect_match(conditionMessage(error), "gender", fixed = TRUE)
    expect_match(conditionMessage(error), "not used in the model formula", fixed = TRUE)
    expect_match(conditionMessage(error), "data = your_data", fixed = TRUE)
    expect_match(conditionMessage(error), "automatically", fixed = TRUE)
  }

  actual <- check_partner_dependence(
    simulations, "dyad", role = gender, data = prepared_data, plot = FALSE
  )
  expect_equal(actual, expected)
  expect_error(check_partner_dependence(
    simulations, "dyad", role = absent, data = prepared_data, plot = FALSE
  ), "absent.*model frame.*data")
  expect_error(check_partner_dependence(
    simulations, "dyad", role = prepared_data$gender, plot = FALSE
  ), "column name")
  expect_error(check_partner_dependence(
    simulations, "dyad", role = !!prepared_data$gender, plot = FALSE
  ), "column name")
})


test_that("wrappers preserve identifier expressions and an omitted role", {
  simulations <- partner_check_test_simulations()
  check_from_wrapper <- function(simulations, dyad, role = NULL, data = NULL) {
    check_partner_dependence(simulations, {{ dyad }}, {{ role }},
                             data = data, plot = FALSE)
  }
  simulations$model_frame$dyad[1] <- NA
  expect_warning(expected <- check_partner_dependence(simulations, dyad, plot = FALSE),
                 "Omitted:")
  expect_warning(wrapped <- check_from_wrapper(simulations, dyad), "Omitted:")
  fields <- c("compositions", "n_pairs",
              "n_missing_dyad_rows", "n_missing_role_rows")
  expect_equal(wrapped[fields], expected[fields])
  expect_identical(wrapped$n_missing_dyad_rows, 1L)

  simulations <- partner_check_test_simulations()
  expected <- check_partner_dependence(simulations, "dyad", "role", plot = FALSE)
  expect_equal(check_from_wrapper(simulations, dyad, role)$compositions,
               expected$compositions)
  expect_equal(check_from_wrapper(simulations, "dyad", "role")$compositions,
               expected$compositions)
  fitting_data <- simulations$model_frame
  simulations$model_frame$role <- NULL
  expect_equal(check_from_wrapper(simulations, dyad, role, data = fitting_data), expected)
  # A broken expression must not fall back to the wrapper formal's column name.
  expect_error(check_from_wrapper(simulations, does_not_exist), "does_not_exist")
})


test_that("fitted columns take precedence and identifier columns must be vectors", {
  simulations <- partner_check_test_simulations()
  expected <- check_partner_dependence(simulations, dyad, role, plot = FALSE)
  fitting_data <- simulations$model_frame
  fitting_data$role <- rep("other", nrow(fitting_data))
  expect_equal(check_partner_dependence(
    simulations, dyad, role, data = fitting_data, plot = FALSE
  ), expected)

  for (invalid_column in list(as.list(fitting_data$role), matrix(1, 10, 2))) {
    simulations$model_frame$role <- invalid_column
    expect_error(check_partner_dependence(simulations, dyad, role, plot = FALSE),
                 "one value per fitted row")
    simulations$model_frame$role <- NULL
    fitting_data$role <- invalid_column
    expect_error(check_partner_dependence(
      simulations, dyad, role, data = fitting_data, plot = FALSE
    ), "one value per fitted row")
  }
  expect_error(check_partner_dependence(
    simulations, dyad, role, data = list(role = rep("other", 10)), plot = FALSE
  ), "data frame")
})


test_that("fitting data supplies aligned roles after omissions and subsetting", {
  skip_if_not_installed("glmmTMB")
  withr::local_seed(8170)
  fitting_data <- data.frame(
    dyad = factor(rep(seq_len(30), each = 2), levels = 1:31),
    gender = factor(rep(c("female", "male"), 30)),
    predictor = stats::rnorm(60),
    dispersion_predictor = stats::rnorm(60)
  )
  fitting_data$outcome <- 1 + 0.4 * fitting_data$predictor +
    stats::rnorm(30, sd = 0.8)[as.integer(fitting_data$dyad)] +
    stats::rnorm(60, sd = 0.3 * exp(0.1 * fitting_data$dispersion_predictor))
  fitting_data$outcome[5] <- NA_real_
  fitting_data$dispersion_predictor[12] <- NA_real_
  fitting_data$gender[15] <- NA
  retained_rows <- setdiff(seq_len(nrow(fitting_data)), c(1, 2, 5, 12))

  for (use_tibble in c(FALSE, TRUE)) {
    if (use_tibble) {
      fitting_data <- tibble::as_tibble(fitting_data)
    } else {
      rownames(fitting_data) <- paste0("person_", seq_len(nrow(fitting_data)))
    }
    for (omit_missing in list(stats::na.omit, stats::na.exclude)) {
      model <- glmmTMB::glmmTMB(
        outcome ~ predictor + (1 | dyad), dispformula = ~dispersion_predictor,
        data = fitting_data, subset = dyad != "1", na.action = omit_missing
      )
      expect_identical(model$fit$convergence, 0L)
      expect_true(model$sdr$pdHess)
      simulations <- simulate_dyad_responses(model, nsim = 3, seed = 8171)
      expect_identical(rownames(simulations$model_frame), rownames(fitting_data)[retained_rows])
      expect_false("gender" %in% names(simulations$model_frame))
      expect_false("31" %in% levels(simulations$model_frame$dyad))

      # Select fitted rows independently, without using row-name matching.
      with_fitted_roles <- simulations
      with_fitted_roles$model_frame$gender <- fitting_data$gender[retained_rows]
      expect_warning(expected <- check_partner_dependence(
        with_fitted_roles, dyad, gender, plot = FALSE
      ), "Omitted:")
      expect_warning(actual <- check_partner_dependence(
        simulations, dyad, gender, data = fitting_data, plot = FALSE
      ), "Omitted:")
      expect_equal(actual, expected)
      expect_identical(actual$n_pairs, 26L)
      expect_identical(actual$n_incomplete_dyads, 3L)
      expect_identical(actual$n_missing_role_rows, 1L)

      incomplete_data <- fitting_data[-retained_rows[1], ]
      expect_error(check_partner_dependence(
        simulations, dyad, gender, data = incomplete_data, plot = FALSE
      ), "match.*fitted rows.*data|data.*does not match.*fitted rows")
      changed_data <- fitting_data
      changed_data$outcome[retained_rows[1]] <- changed_data$outcome[retained_rows[1]] + 1
      expect_error(check_partner_dependence(
        simulations, dyad, gender, data = changed_data, plot = FALSE
      ), "outcome.*does not match.*fitted rows")
      if (use_tibble) {
        # Tibbles reset row names after reordering, so names alone cannot detect this.
        reordered_data <- fitting_data[rev(seq_len(nrow(fitting_data))), ]
        expect_error(check_partner_dependence(
          simulations, dyad, gender, data = reordered_data, plot = FALSE
        ), "does not match.*fitted rows")
      }
    }
  }
})


test_that("missing identifiers and incomplete dyads are listed in one warning", {
  simulations <- partner_check_test_simulations()
  ids <- simulations$model_frame$dyad
  roles <- simulations$model_frame$role
  ids[which(ids == "5")[1]] <- NA
  roles[ids == "4"] <- NA
  simulations$model_frame$dyad <- ids
  simulations$model_frame$role <- roles
  warnings <- character()
  withCallingHandlers(
    result <- check_partner_dependence(simulations, dyad, role, plot = FALSE),
    warning = function(warning) {
      warnings <<- c(warnings, conditionMessage(warning))
      invokeRestart("muffleWarning")
    }
  )
  # These are positions in the fitted frame, whose row labels were shuffled.
  expect_identical(warnings, paste0(
    "Omitted: 2 incomplete dyads, with IDs: 4, 5; ",
    "fitted rows with missing dyad IDs (n = 1): 7; ",
    "fitted rows with missing roles (n = 2): 5, 10."
  ))
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
  roles[rows] <- NA
  simulations$model_frame$dyad <- ids
  simulations$model_frame$role <- roles
  # The first row is counted only as a missing ID, even though its role is missing too.
  expect_warning(result <- check_partner_dependence(simulations, dyad, role, plot = FALSE),
                 paste0(
                   "Omitted: 1 incomplete dyad, with ID: 4; ",
                   "fitted rows with missing dyad IDs (n = 1): 5; ",
                   "fitted rows with missing roles (n = 1): 10."
                 ), fixed = TRUE)
  expect_identical(result$n_pairs, 4L)
  expect_identical(result$n_incomplete_dyads, 1L)
  expect_identical(result$n_missing_dyad_rows, 1L)
  expect_identical(result$n_missing_role_rows, 1L)
})


test_that("invalid simulation objects, identifiers, and pair structures fail clearly", {
  simulations <- partner_check_test_simulations()
  expect_error(check_partner_dependence(list(), "dyad"), "must be created by")
  expect_error(check_partner_dependence(simulations), "must identify")
  expect_error(check_partner_dependence(simulations, "unknown"), "unknown.*model frame")
  expect_error(check_partner_dependence(simulations, "dyad", "unknown"),
               "unknown.*model frame")
  expect_error(check_partner_dependence(simulations, 1:3), "column name")
  expect_error(check_partner_dependence(simulations, .data$dyad), "column name")
  expect_error(check_partner_dependence(simulations, .env$dyad), "column name")

  ids <- as.character(simulations$model_frame$dyad)
  roles <- as.character(simulations$model_frame$role)
  # Missing roles must not hide a third fitted response in a dyad.
  extra <- which(ids == "5")[1]
  ids[extra] <- "1"
  roles[extra] <- NA
  simulations$model_frame$dyad <- ids
  simulations$model_frame$role <- roles
  expect_error(check_partner_dependence(simulations, dyad, role),
               "at most two fitted responses")

  simulations <- partner_check_test_simulations()
  ids <- simulations$model_frame$dyad
  ids[ids %in% c("3", "4", "5")] <- NA
  simulations$model_frame$dyad <- ids
  expect_error(check_partner_dependence(simulations, dyad), "At least three complete dyads")

  simulations <- partner_check_test_simulations()
  roles <- as.character(simulations$model_frame$role)
  first_dyad <- which(simulations$model_frame$dyad == "1")
  roles[first_dyad] <- "female"
  simulations$model_frame$role <- roles
  expect_warning(check_partner_dependence(simulations, dyad, role, plot = FALSE),
                 "Not checked.*female - female")
  roles[first_dyad[1]] <- "other"
  simulations$model_frame$role <- roles
  expect_warning(check_partner_dependence(simulations, dyad, role, plot = FALSE),
                 "Not checked.*female - other")
})


test_that("undefined statistics are reported even without plotting", {
  for (response in c("model-centred", "raw")) {
    for (role in list(NULL, "role")) {
      simulations <- partner_check_test_simulations()
      constant_responses <- if (response == "raw") rep(0, 10) else
        simulations$predicted_response
      simulations$simulated_responses[1, ] <- constant_responses
      warnings <- character()
      withCallingHandlers(check_partner_dependence(
        simulations, "dyad", !!role, response = response, plot = FALSE
      ), warning = function(warning) {
        warnings <<- c(warnings, conditionMessage(warning))
        invokeRestart("muffleWarning")
      })
      expect_length(warnings, 1L)
      expect_match(warnings, "Undefined simulated summaries")

      simulations$observed_response <- constant_responses
      expect_error(check_partner_dependence(
        simulations, "dyad", !!role, response = response, plot = FALSE
      ), "[Oo]bserved.*undefined")
      simulations$observed_response <- partner_check_test_simulations()$observed_response
      simulations$simulated_responses[,] <- rep(
        constant_responses, each = nrow(simulations$simulated_responses)
      )
      expect_error(check_partner_dependence(
        simulations, "dyad", !!role, response = response, plot = FALSE
      ), "[Ee]very.*undefined|[Aa]ll.*undefined")
    }
  }
})


test_that("one simulation retains every statistic as a table column", {
  simulations <- partner_check_test_simulations()
  simulations$simulated_responses <- simulations$simulated_responses[1, , drop = FALSE]
  expect_output(print(simulations), "1 complete gaussian response dataset", fixed = TRUE)
  for (role in list(NULL, "role")) {
    result <- check_partner_dependence(simulations, "dyad", !!role, plot = FALSE)
    statistics <- result$compositions$statistics[[1]]
    n_statistics <- if (is.null(role)) 4L else 6L
    expect_identical(statistics$dataset, c("observed", "simulation_1"))
    expect_identical(dim(statistics), c(2L, 1L + n_statistics))
    expect_identical(dim(as.matrix(statistics[-1, -1])), c(1L, n_statistics))
    expect_identical(result$n_simulations, 1L)
    expect_output(print(result), "Reference: 1 plug-in predictive", fixed = TRUE)
  }
})


test_that("checks plot by default, forward plot settings, and return invisibly", {
  simulations <- partner_check_test_simulations()
  plot_calls <- list()
  local_mocked_bindings(plot.dyadMLM_partner_check = function(x, ask, panels, ...) {
    plot_calls[[length(plot_calls) + 1L]] <<- list(ask = ask, panels = panels)
    invisible(x)
  }, .package = "dyadMLM")
  expect_message(default <- withVisible(check_partner_dependence(simulations, "dyad")),
                 "No role supplied: summaries pool partners.", fixed = TRUE)
  expect_false(default$visible)
  expect_s3_class(default$value, "dyadMLM_partner_check")
  expect_identical(plot_calls, list(list(ask = NULL, panels = TRUE)))
  expect_message(no_plot <- withVisible(check_partner_dependence(
    simulations, "dyad", plot = FALSE, ask = TRUE, panels = FALSE
  )), "Use `role = NULL` to pool without this message.", fixed = TRUE)
  expect_message(pooled <- withVisible(check_partner_dependence(
    simulations, "dyad", NULL, FALSE
  )), NA)
  expect_message(roles <- withVisible(check_partner_dependence(
    simulations, "dyad", role = "role", plot = FALSE
  )), NA)
  for (result in list(no_plot, pooled, roles)) expect_false(result$visible)
  expect_identical(no_plot$value, pooled$value)
  expect_identical(plot_calls, list(list(ask = NULL, panels = TRUE)))
  for (ask in c(FALSE, TRUE)) {
    plotted <- withVisible(check_partner_dependence(
      simulations, "dyad", NULL, TRUE, "raw", ask = ask, panels = FALSE
    ))
    expect_false(plotted$visible)
    expect_identical(plotted$value$response, "raw")
  }
  expect_identical(plot_calls, list(
    list(ask = NULL, panels = TRUE), list(ask = FALSE, panels = FALSE),
    list(ask = TRUE, panels = FALSE)
  ))
})


test_that("printing describes the check and plots show empirical limits", {
  simulations <- partner_check_test_simulations()
  exchangeable <- check_partner_dependence(simulations, "dyad", plot = FALSE)
  distinguishable <- check_partner_dependence(simulations, "dyad", "role", plot = FALSE)
  printed <- paste(capture.output(visible <- withVisible(print(distinguishable))),
                   collapse = "\n")
  expect_match(printed, "6 statistics; 5 usable complete pairs", fixed = TRUE)
  expect_match(printed, "model-centred", fixed = TRUE)
  expect_false(visible$visible)
  expect_identical(visible$value, distinguishable)

  # Distinct numeric roles can have identical rounded labels. Plot both SDs.
  simulations$model_frame$role <- 1e15 + as.integer(simulations$model_frame$role)
  numeric_roles_check <- check_partner_dependence(
    simulations, "dyad", "role", plot = FALSE
  )
  numeric_statistics <- numeric_roles_check$compositions$statistics[[1]]
  expect_identical(names(numeric_statistics)[2], names(numeric_statistics)[3])

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mfcol = c(1, 2), plt = c(0.2, 0.8, 0.2, 0.8))
  settings <- graphics::par(c("mfcol", "mar", "plt"))
  original_title <- graphics::title
  local_mocked_bindings(title = function(main = NULL, ...) {
    titles <<- c(titles, main)
    original_title(main = main, ...)
  }, .package = "graphics")
  original_segments <- graphics::segments
  local_mocked_bindings(segments = function(x0, y0, x1, y1, ...) {
    if (identical(list(...)$lty, 2)) limits[[length(limits) + 1L]] <<- x0
    if (identical(list(...)$col, "red")) observed_lines <<- c(observed_lines, x0)
    original_segments(x0, y0, x1, y1, ...)
  }, .package = "graphics")
  for (result in list(exchangeable, distinguishable, numeric_roles_check)) {
    statistics <- result$compositions$statistics[[1]]
    observed_statistics <- unlist(statistics[1, -1], use.names = TRUE)
    titles <- character()
    limits <- list()
    observed_lines <- numeric()
    plotted <- withVisible(plot(result, ask = FALSE))
    expect_false(plotted$visible)
    expect_identical(plotted$value, result)
    expect_identical(gsub("\n", " ", titles, fixed = TRUE), names(observed_statistics))
    expect_equal(observed_lines, unname(observed_statistics))
    expect_equal(unname(do.call(cbind, limits)), unname(apply(
      as.matrix(statistics[-1, -1]), 2, stats::quantile, probs = c(0.025, 0.975)
    )))
    expect_equal(graphics::par(names(settings)), settings)
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
  simulations$model_frame$dyad <- factor(ids, exclude = NULL)
  simulations$model_frame$role <- factor(roles, exclude = NULL)
  expect_warning(result <- check_partner_dependence(
    simulations, dyad, role, plot = FALSE
  ), paste0(
    "Omitted: 1 incomplete dyad, with ID: 4; ",
    "fitted rows with missing dyad IDs (n = 2): 7, 9; ",
    "fitted rows with missing roles (n = 1): 10."
  ), fixed = TRUE)
  expect_identical(result$n_missing_dyad_rows, 2L)
  expect_identical(result$n_missing_role_rows, 1L)
  expect_identical(result$n_incomplete_dyads, 1L)
  expect_identical(result$n_pairs, 3L)
  expect_identical(names(result$compositions$statistics[[1]])[2:3],
                   c("SD (female)", "SD (male)"))
})


test_that("distinct numeric dyad IDs remain separate despite rounded labels", {
  simulations <- partner_check_test_simulations()
  expected <- check_partner_dependence(simulations, "dyad", plot = FALSE)
  simulations$model_frame$dyad <- 1e15 + as.integer(simulations$model_frame$dyad)
  result <- check_partner_dependence(simulations, "dyad", plot = FALSE)
  expect_identical(result$n_pairs, 5L)
  expect_equal(result$compositions, expected$compositions)
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
