test_that("PIT ranks use every dataset symmetrically", {
  simulations <- distribution_check_fixture()
  simulations$model_frame$X <- seq_len(12)
  result <- withVisible(check_dyad_residuals(simulations, role = NULL, plot = FALSE))
  responses <- cbind(simulations$observed_response, t(simulations$simulated_responses))
  expect_false(result$visible)
  # One PIT in every rank interval, with ordering preserved for untied outcomes.
  expect_equal(unname(ceiling(result$value$pit * ncol(responses))),
               unname(t(apply(responses, 1, rank))))
  expect_true(all(result$value$pit > 0 & result$value$pit < 1))
  # Grouping and predictor choices must not change the residuals being checked.
  expect_identical(check_dyad_residuals(simulations, "dyad", "role", "member",
                                        predictors = "X", plot = FALSE)$pit, result$value$pit)
})


test_that("tied PIT stays within its rank block and seeds are reproducible", {
  simulations <- distribution_check_fixture()
  simulations$observed_response <- round(simulations$observed_response)
  simulations$simulated_responses[] <- round(simulations$simulated_responses)
  withr::local_seed(392)
  random_state <- .Random.seed
  pit <- check_dyad_residuals(simulations, role = NULL, plot = FALSE)$pit
  expect_identical(.Random.seed, random_state)
  expect_identical(check_dyad_residuals(simulations, role = NULL, plot = FALSE)$pit, pit)

  responses <- cbind(simulations$observed_response, t(simulations$simulated_responses))
  n <- ncol(responses)
  below <- t(apply(responses, 1, rank, ties.method = "min")) - 1
  at_most <- t(apply(responses, 1, rank, ties.method = "max"))
  expect_true(all(pit > below / n & pit < at_most / n))
  expect_true(all(apply(ceiling(pit * n), 1, setequal, seq_len(n))))
  # For entirely tied data, no column is systematically the first or last rank.
  ranks <- ceiling(randomized_pit(matrix(1, 1000, 6)) * 6)
  expect_true(all(colMeans(ranks) > 3.2 & colMeans(ranks) < 3.8))

  # Without a seed, the caller's RNG is used and advanced.
  expect_false(identical(check_dyad_residuals(simulations, role = NULL, seed = NULL,
                                              plot = FALSE)$pit, pit))
  expect_false(identical(.Random.seed, random_state))
})


test_that("centring precedes role splits and all PIT summaries use it", {
  simulations <- distribution_check_fixture()
  uncentred <- check_dyad_residuals(simulations, role = NULL, plot = FALSE)
  attr(simulations, "dyadMLM")$free_conditional_intercept <- TRUE
  centred <- check_dyad_residuals(simulations, dyad = "dyad", role = "role", plot = FALSE)
  z <- qnorm(uncentred$pit)
  expected <- pnorm(sweep(z, 2, apply(z, 2, median)))
  expect_equal(centred$pit, expected)
  for (role in names(centred$compositions[[1]]$rows)) {
    rows <- centred$compositions[[1]]$rows[[role]]
    statistics <- centred$compositions[[1]]$statistics[[role]]
    expect_equal(statistics$mean_distance, colMeans(2 * abs(expected[rows, ] - .5)))
    expect_equal(statistics$qq, residual_curve_summary(
      apply(expected[rows, ], 2, quantile, probs = seq(0, 1, length.out = 201))))
  }
})


test_that("missing predictor values affect only their own panels", {
  simulations <- distribution_check_fixture()
  expected <- check_dyad_residuals(simulations, role = NULL, plot = FALSE)$pit
  incomplete <- c(0, NA, 0, 1, 1, NA, 0, 1, 0, NA, 1, 0)
  simulations$model_frame$Incomplete <- incomplete
  expect_warning(result <- check_dyad_residuals(simulations, role = NULL, predictors = "Incomplete",
                                                plot = FALSE), "Incomplete.*3")
  expect_identical(result$pit, expected)
  pattern <- result$compositions[[1]]$patterns[[2]][[1]]
  expect_equal(unname(pattern$positions), c(0, 1))
  summaries <- lapply(c(.25, .5, .75), function(probability) {
    t(vapply(c(0, 1), function(group) {
      apply(expected[which(incomplete == group), , drop = FALSE], 2,
            quantile, probs = probability)
    }, numeric(ncol(expected))))
  })
  joint <- residual_curve_summary(do.call(rbind, summaries))
  for (i in seq_along(summaries))
    expect_equal(lapply(pattern$quantiles[[i]], unname),
                 lapply(joint, `[`, (1:2) + (i - 1L) * 2L))

  simulations$model_frame$Empty <- rep(NA, 12)
  expect_warning(result <- check_dyad_residuals(simulations, role = NULL, predictors = "Empty",
                                                plot = FALSE), "Empty.*12")
  expect_null(result$compositions[[1]]$patterns[[2]][[1]])
  # Missing and unused factor levels get no group.
  simulations$model_frame$Role <- addNA(factor(c(NA, rep(c("A", "B"), 5), "A"),
                                               levels = c("A", "B", "Unused")))
  expect_warning(result <- check_dyad_residuals(simulations, role = NULL, predictors = "Role",
                                                plot = FALSE), "Role.*1")
  expect_identical(result$compositions[[1]]$patterns[[2]][[1]]$labels, c("A", "B"))
})


test_that("predictors missing from the model frame come from the fitting data", {
  simulations <- distribution_check_fixture()
  simulations$model_frame$stress <- factor(rep(c("low", "medium", "high"), 4))
  fitting_data <- simulations$model_frame
  # Omitted and reordered fitted rows retain their original predictor values.
  simulations <- subset_fixture(simulations, c(12, 2, 9, 4, 7, 6, 5, 8))
  expected <- check_dyad_residuals(simulations, role = NULL, predictors = "stress", plot = FALSE)
  simulations$model_frame$stress <- NULL
  expect_identical(check_dyad_residuals(simulations, role = NULL, predictors = "stress",
                                        data = fitting_data, plot = FALSE), expected)
  expect_error(check_dyad_residuals(simulations, predictors = "stress"), "stress.*not found.*data =")
})


test_that("predictor groups absent in one role leave gaps on the shared axis", {
  simulations <- distribution_check_fixture()
  role <- simulations$model_frame$role
  simulations$model_frame$Separated <- as.integer(role == "B")
  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  result <- check_dyad_residuals(simulations, "dyad", "role", predictors = "Separated", ask = FALSE)
  patterns <- result$compositions[[1]]$patterns[[2]]
  expect_equal(patterns$A$quantiles[[2]]$observed, c(median(result$pit[role == "A", 1]), NA),
               ignore_attr = TRUE)
  expect_equal(patterns$B$quantiles[[2]]$observed, c(NA, median(result$pit[role == "B", 1])),
               ignore_attr = TRUE)
})


test_that("numeric predictors use each role's bins, smoothed when there are enough", {
  n <- 240
  simulations <- distribution_check_fixture()
  simulations$model_frame <- simulations$model_frame[rep(1:12, rep(c(10, 30), 6)), ]
  simulations$predicted_response <- seq(0, 2, length.out = n)
  simulations$observed_response <- simulations$predicted_response + sin(seq_len(n))
  simulations$simulated_responses <- sweep(matrix(sin(seq_len(200 * n)), 200),
                                           2, simulations$predicted_response, "+")
  simulations$model_frame$Dense <- seq_len(n)
  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  result <- check_dyad_residuals(simulations, "dyad", "role", "member",
                                 predictors = "Dense", ask = FALSE)
  patterns <- result$compositions[[1]]$patterns[[2]]
  # Role A has 60 observations (three bins); role B has 180 (eight bins, smoothed).
  rows_a <- which(simulations$model_frame$role == "A")
  bins_a <- split(rows_a, cut(rows_a, quantile(rows_a, 0:3 / 3), include.lowest = TRUE))
  expect_false(patterns$A$smooth)
  expect_equal(unname(patterns$A$positions), unname(vapply(bins_a, mean, 0)))
  expect_equal(patterns$A$quantiles[[2]]$observed,
               vapply(bins_a, function(rows) median(result$pit[rows, 1]), 0), ignore_attr = TRUE)
  expect_true(patterns$B$smooth)
  expect_length(patterns$B$positions, 101)
  expect_equal(patterns$A$limits, patterns$B$limits)
  quartiles <- sapply(patterns$B$quantiles, `[[`, "observed")
  expect_true(all(quartiles >= 0 & quartiles <= 1 &
                    quartiles[, 1] <= quartiles[, 2] & quartiles[, 2] <= quartiles[, 3]))
  # Identical weights smooth every dataset's quartiles; envelopes come afterwards.
  rows_b <- which(simulations$model_frame$role == "B")
  bins_b <- split(rows_b, cut(rows_b, quantile(rows_b, 0:8 / 8), include.lowest = TRUE))
  centres <- vapply(bins_b, mean, 0)
  grid <- seq(min(rows_b), max(rows_b), length.out = 101)
  weights <- exp(-.5 * (outer(grid, centres, "-") / median(diff(centres)))^2)
  weights <- weights / rowSums(weights)
  smoothed <- lapply(c(.25, .5, .75), function(probability) weights %*% t(vapply(bins_b,
    function(rows) apply(result$pit[rows, ], 2, quantile, probs = probability),
    numeric(ncol(result$pit)))))
  joint <- residual_curve_summary(do.call(rbind, smoothed))
  for (i in 1:3)
    expect_equal(lapply(patterns$B$quantiles[[i]], unname),
                 lapply(joint, `[`, seq_along(grid) + (i - 1L) * length(grid)))

  # A constant role and a heavily tied predictor need no bins or smoothing.
  simulations$model_frame$Dense <- 0
  simulations$model_frame$Dense[tail(which(simulations$model_frame$role == "B"), 20)] <- 1:20
  patterns <- check_dyad_residuals(simulations, "dyad", "role", "member", predictors = "Dense",
                                   plot = FALSE)$compositions[[1]]$patterns[[2]]
  expect_equal(lengths(lapply(patterns, `[[`, "positions")), c(A = 1L, B = 1L))
})


test_that("lone responses keep their composition, and empty roles still plot", {
  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  simulations <- distribution_check_fixture()
  fitting_data <- simulations$model_frame
  for (rows in list(1:2, seq(1, 12, by = 2))) {
    subset <- subset_fixture(simulations, rows)
    pooled <- check_dyad_residuals(subset, role = NULL, ask = FALSE)$pit
    expect_identical(check_dyad_residuals(subset, "dyad", "role", data = fitting_data,
                                          ask = FALSE)$pit, pooled)
    statistics <- check_dyad_outcomes(subset, "dyad", "role", data = fitting_data,
                                      ask = FALSE)$compositions[[1]]$statistics
    expect_named(statistics, c("A", "B"))
    if (!2 %in% rows) expect_null(statistics$B)
  }
  # SDs need two responses; one simulated dataset is enough to summarise.
  lone <- subset_fixture(simulations, 1L)
  lone$simulated_responses <- lone$simulated_responses[1, , drop = FALSE]
  statistics <- check_dyad_outcomes(lone, "dyad", "role", data = fitting_data,
                                    ask = FALSE)$compositions[[1]]$statistics
  expect_true(all(is.na(statistics$A["Response SD", ])))
})


test_that("checks calculate without graphics and saved results plot later", {
  simulations <- distribution_check_fixture()
  simulations$model_frame$age <- seq_len(12)
  # Zeros add a count panel; a character predictor adds categorical quartiles.
  simulations$observed_response[1] <- simulations$simulated_responses[1, 1] <- 0
  results <- local({
    local_mocked_bindings(plot.new = function(...) stop("unexpected graphics"),
                          .package = "graphics")
    list(check_dyad_residuals(simulations, "dyad", "role", predictors = c("age", "role"),
                              plot = FALSE),
         check_dyad_outcomes(simulations, "dyad", "role", plot = FALSE))
  })
  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  for (result in results) for (panels in c(TRUE, FALSE))
    expect_no_warning(expect_identical(plot(result, panels = panels, ask = FALSE), result))
})


test_that("residual plots draw each role's saved curves and scalar summaries", {
  result <- check_dyad_residuals(distribution_check_fixture(), dyad = "dyad", role = "role", plot = FALSE)
  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  observed <- bounds <- scalars <- list()
  recording <- FALSE
  original_title <- graphics::title
  original_lines <- graphics::lines
  original_polygon <- graphics::polygon
  local_mocked_bindings(title = function(main = NULL, ...) {
    recording <<- isTRUE(grepl("Uniform QQ", main))
    original_title(main = main, ...)
  }, lines = function(x, y, ...) {
    if (recording && !missing(y)) observed[[length(observed) + 1L]] <<- y
    if (missing(y)) original_lines(x, ...) else original_lines(x, y, ...)
  }, polygon = function(x, y, ...) {
    if (recording) bounds[[length(bounds) + 1L]] <<- unname(y)
    original_polygon(x, y, ...)
  }, .package = "graphics")
  local_mocked_bindings(plot_check_statistic = function(values, ...) {
    scalars[[length(scalars) + 1L]] <<- values
    graphics::plot.new()
  })
  plot(result, ask = FALSE)
  statistics <- result$compositions[[1]]$statistics
  expect_equal(observed, unname(lapply(statistics, function(x) x$qq$observed)))
  expect_equal(bounds, unname(lapply(statistics, function(x) c(x$qq$lower, rev(x$qq$upper)))))
  expect_equal(scalars, unname(lapply(statistics, `[[`, "mean_distance")))
})


test_that("each page repeats its composition heading", {
  simulations <- distribution_check_fixture()
  simulations$model_frame$role <- rep(c("A", "A", "A", "B", "B", "B"), 2)
  simulations$model_frame$X <- seq_len(12)
  compositions <- c("A - A", "A - B", "B - B")
  headings <- character(); role_headings <- integer()
  original_mtext <- graphics::mtext
  local_mocked_bindings(mtext = function(text, ...) {
    if (isTRUE(list(...)$outer) && length(text) == 1L && text %in% compositions)
      headings <<- c(headings, text)
    if (any(grepl("(n = ", text, fixed = TRUE))) role_headings <<- c(role_headings, length(text))
    original_mtext(text, ...)
  }, .package = "graphics")
  expect_pages <- function(code, each) {
    headings <<- character()
    expect_equal(count_pdf_pages(code, width = 12, height = 10), sum(each))
    expect_identical(headings, rep(compositions, each))
  }
  # Residuals: two pages plus one per predictor, or four figures plus two per predictor and role.
  expect_pages(check_dyad_residuals(simulations, "dyad", "role", predictors = "X", ask = FALSE),
               c(3, 3, 3))
  role_headings <- integer()
  expect_pages(check_dyad_residuals(simulations, "dyad", "role", panels = FALSE, ask = FALSE),
               c(4, 8, 4))
  expect_true(all(role_headings == 1))  # each separate figure names its one role
  # Outcomes: one page, or one figure per check and role.
  expect_pages(check_dyad_outcomes(simulations, "dyad", "role", ask = FALSE), c(1, 1, 1))
  expect_pages(check_dyad_outcomes(simulations, "dyad", "role", panels = FALSE, ask = FALSE),
               c(3, 6, 3))
})


test_that("plots fit the default device and restore settings after errors", {
  simulations <- distribution_check_fixture()
  grDevices::pdf(NULL, width = 7, height = 7)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mfrow = c(2, 1), mar = c(4, 3, 2, 1), cex = .9, mex = 1.2, las = 2)
  graphics::par(plt = c(.2, .8, .2, .8))
  settings <- graphics::par(c("mfrow", "mar", "oma", "mgp", "cex", "mex", "cex.main", "mfg",
                              "las", "plt", "new"))
  grDevices::devAskNewPage(TRUE)
  checks <- list(check_dyad_residuals, check_dyad_outcomes)
  for (check in checks) {
    check(simulations, "dyad", "role", ask = FALSE)
    expect_equal(graphics::par(names(settings)), settings)
    expect_true(grDevices::devAskNewPage())
  }
  local_mocked_bindings(plot.new = function(...) stop("forced plotting failure"),
                        .package = "graphics")
  for (check in checks) {
    expect_error(check(simulations, "dyad", "role", ask = FALSE), "forced plotting failure")
    expect_equal(graphics::par(names(settings)), settings)
    expect_true(grDevices::devAskNewPage())
  }
})


test_that("residual and outcome plots pause only between several figures", {
  simulations <- distribution_check_fixture()
  outcomes <- check_dyad_outcomes(simulations, role = NULL, plot = FALSE)
  residuals <- check_dyad_residuals(simulations, role = NULL, plot = FALSE)
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  ask_values <- logical()
  local_mocked_bindings(dev.interactive = function(...) TRUE,
    devAskNewPage = function(ask = NULL) {
      ask_values <<- c(ask_values, ask)
      TRUE
    }, .package = "grDevices")
  plot(outcomes)
  plot(outcomes, panels = FALSE)
  plot(residuals)
  expect_identical(ask_values, c(FALSE, TRUE, TRUE, TRUE, TRUE, TRUE))
})


test_that("residual and outcome checks suggest roles only when role is omitted", {
  simulations <- distribution_check_fixture()
  expect_message(check_dyad_residuals(simulations, plot = FALSE), "No role supplied", fixed = TRUE)
  expect_message(check_dyad_outcomes(simulations, plot = FALSE), "No role supplied", fixed = TRUE)
  expect_no_message(check_dyad_residuals(simulations, role = NULL, plot = FALSE))
  expect_no_message(check_dyad_outcomes(simulations, "dyad", "role", plot = FALSE))
})


test_that("saved residual and outcome checks print a short overview", {
  simulations <- distribution_check_fixture()
  simulations$model_frame$age <- seq_len(12)
  residuals <- check_dyad_residuals(simulations, "dyad", "role", predictors = "age", plot = FALSE)
  printed <- capture.output(returned <- withVisible(print(residuals)))
  expect_false(returned$visible)
  expect_identical(returned$value, residuals)
  expect_identical(printed, c("<dyadMLM residual check>", "A - B: 6 dyads; 12 observations",
                              "Predictors: age", "Use plot(x) to view the checks."))
  expect_identical(capture.output(print(check_dyad_outcomes(simulations, role = NULL, plot = FALSE))),
                   c("<dyadMLM outcome check>", "All observations: 12 observations",
                     "Use plot(x) to view the checks."))
})


test_that("invalid simulation inputs and unsupported predictor forms fail clearly", {
  simulations <- distribution_check_fixture()
  expect_error(check_dyad_residuals(unclass(simulations)), "simulate_dyad_responses")
  expect_error(check_dyad_outcomes(unclass(simulations)), "simulate_dyad_responses")
  for (predictors in list(list(age = 1:12), ~ age, 1:12))
    expect_error(check_dyad_residuals(simulations, predictors = predictors, plot = FALSE),
                 "predictors.*(column names|character)")
  # A bare name gets the same guidance instead of "object not found".
  expect_error(check_dyad_residuals(simulations, predictors = age, plot = FALSE),
               "quoted column names")
  simulations$simulated_responses <- simulations$simulated_responses[1:199, ]
  expect_error(check_dyad_residuals(simulations), "200 simulated datasets")
})
