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
  expect_named(pattern, c("positions", "labels", "limits", "binned", "smooth", "numeric", "quantiles"))
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


test_that("quartile offsets stay inside small-scale panels", {
  simulations <- distribution_check_fixture()
  simulations$model_frame$Edge <- seq(0, 1e-8, length.out = 12)
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  inside <- TRUE
  original_segments <- graphics::segments
  local_mocked_bindings(segments = function(x0, ...) {
    inside <<- inside && all(x0 >= graphics::par("usr")[1] & x0 <= graphics::par("usr")[2])
    original_segments(x0, ...)
  }, .package = "graphics")
  check_dyad_residuals(simulations, role = NULL, predictors = "Edge", ask = FALSE)
  expect_true(inside)
})


test_that("numeric predictors use each role's bins on ranks, smoothed when there are enough", {
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
  # Bins sit at their mean rank within the role, scaled to 0--1.
  expect_equal(unname(patterns$A$positions),
               unname(vapply(bins_a, function(rows) mean(match(rows, rows_a)), 0)) / 60)
  expect_equal(patterns$A$quantiles[[2]]$observed,
               vapply(bins_a, function(rows) median(result$pit[rows, 1]), 0), ignore_attr = TRUE)
  expect_true(patterns$B$smooth)
  expect_length(patterns$B$positions, 101)
  expect_equal(patterns$A$limits, patterns$B$limits)
  quartiles <- sapply(patterns$B$quantiles, `[[`, "observed")
  expect_true(all(quartiles >= 0 & quartiles <= 1 &
                    quartiles[, 1] <= quartiles[, 2] & quartiles[, 2] <= quartiles[, 3]))
  # Identical weights smooth every dataset's quartiles; envelopes come afterwards.
  # The grid is even in ranks, but smoothing uses the predictor's values there.
  rows_b <- which(simulations$model_frame$role == "B")
  bins_b <- split(rows_b, cut(rows_b, quantile(rows_b, 0:8 / 8), include.lowest = TRUE))
  centres <- vapply(bins_b, mean, 0)
  grid <- seq(1 / 180, 1, length.out = 101)
  expect_equal(patterns$B$positions, grid)
  expect_equal(patterns$B$labels, signif(quantile(rows_b, 0:4 / 4, names = FALSE), 2))
  # Each observed PIT residual is kept as a point at its rank.
  expect_equal(unname(patterns$B$points), cbind(seq_along(rows_b) / 180, result$pit[rows_b, 1]))
  grid_values <- approx(seq_along(rows_b) / 180, rows_b, grid)$y
  weights <- exp(-.5 * (outer(grid_values, centres, "-") / median(diff(centres)))^2)
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

test_that("binned axes label close quartiles distinctly and keep tied ones", {
  pit <- matrix(sin(seq_len(300))^2, 100)
  narrow <- calculate_residual_pattern(pit, 1000 + seq(0, 1, length.out = 100), seq_len(100),
                                       list(seq_len(100)), "bins")
  expect_length(unique(narrow$labels), 5)
  # With ties, repeated quartiles keep the same label.
  tied <- calculate_residual_pattern(pit, c(rep(0, 60), 1:40), seq_len(100),
                                     list(seq_len(100)), "bins")
  expect_equal(sum(tied$labels == 0), 3)
})

test_that("qgam lines replace smoothed bins and are fitted on ranks", {
  skip_if_not_installed("qgam")
  # A skewed predictor and an observed PIT that rises with it.
  n <- 100
  predictor <- exp(seq(0, 5, length.out = n))
  pit <- cbind(seq(.1, .9, length.out = n) + .1 * sin(seq_len(n)),
               matrix(sin(seq_len(2 * n))^2, n))
  pattern <- calculate_residual_pattern(pit, predictor, seq_len(n), list(seq_len(n)), "qgam")
  # Lines lie on ranks from 0 to 1, with ticks at the predictor's quartiles.
  expect_equal(range(pattern$positions), c(1 / n, 1))
  expect_equal(pattern$ticks, 0:4 / 4)
  expect_equal(pattern$labels, signif(quantile(predictor, 0:4 / 4, names = FALSE), 2))
  # Close quartiles keep distinct labels.
  narrow <- calculate_residual_pattern(pit, seq(1000, 1001, length.out = n), seq_len(n),
                                       list(seq_len(n)), "qgam")
  expect_length(unique(narrow$labels), 5)
  expect_lt(pattern$quantiles[[2]]$observed[1], .3)
  expect_gt(pattern$quantiles[[2]]$observed[101], .7)
  # Without enough observations for smoothing, bins stay.
  expect_identical(calculate_residual_pattern(pit, predictor, 1:60, list(1:60), "qgam"),
                   calculate_residual_pattern(pit, predictor, 1:60, list(1:60), "bins"))
  # A saved check with qgam lines draws its ranked axis.
  result <- check_dyad_residuals(distribution_check_fixture(), role = NULL, plot = FALSE)
  result$compositions[[1]]$patterns[[1]]$Pooled <- pattern
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_no_error(plot(result, ask = FALSE))
})

test_that("qgam warnings come as one summary per panel", {
  skip_if_not_installed("qgam")
  # Let every fit warn, as mgcv does after a step failure.
  real_qgam <- qgam::qgam
  local_mocked_bindings(qgam = function(...) {
    warning("Fitting terminated with step failure")
    real_qgam(...)
  }, .package = "qgam")
  n <- 100
  pit <- matrix(sin(seq_len(3 * n))^2, n)
  # Three quartiles for three datasets give nine fits.
  expect_warning(
    calculate_residual_pattern(pit, seq_len(n), seq_len(n), list(seq_len(n)), "qgam"),
    "panel \\(9 fits\\):\n9 x Fitting terminated with step failure")
})

test_that("interactive checks suggest qgam lines only when bins are smoothed", {
  withr::local_options(rlang_interactive = TRUE, rlib_message_verbosity = "verbose")
  # 120 observations give six bins of predicted outcomes, which are smoothed.
  simulations <- subset_fixture(distribution_check_fixture(), rep(1:12, 10))
  expect_message(check_dyad_residuals(simulations, role = NULL, plot = FALSE),
                 "quartile_lines = \"qgam\"")
  # 12 observations give too few bins for smoothing.
  expect_no_message(check_dyad_residuals(distribution_check_fixture(), role = NULL,
                                         plot = FALSE))
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
  titles <- character()
  recording <- FALSE
  original_title <- graphics::title
  original_lines <- graphics::lines
  original_polygon <- graphics::polygon
  local_mocked_bindings(title = function(main = NULL, ...) {
    titles <<- c(titles, main)
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
  # Pattern pages have one row of PIT quartiles.
  expect_identical(sub("\n.*", "", titles), rep(c("Uniform QQ", "PIT quartiles"), each = 2))
})


test_that("the first page pairs QQ with the predicted outcome, as in DHARMa", {
  simulations <- distribution_check_fixture()
  simulations$model_frame$X <- seq_len(12)
  result <- check_dyad_residuals(simulations, role = NULL, predictors = "X", plot = FALSE)
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  pages <- character()
  local_mocked_bindings(plot_check_role_panels = function(composition, checks, title, ...)
    pages <<- c(pages, paste(checks, collapse = " + ")))
  plot(result, ask = FALSE)
  expect_identical(pages, c("qq + quartiles", "mean_distance", "quartiles"))
})

test_that("categories get boxes inside their panel, binned axes get points", {
  simulations <- distribution_check_fixture()
  simulations$model_frame$group <- rep(c("a", "b", "c"), 4)
  simulations$model_frame$few <- rep(c(0, 1e-8), 6)
  result <- check_dyad_residuals(simulations, role = NULL, predictors = c("group", "few"),
                                 plot = FALSE)
  expect_null(result$compositions[[1]]$patterns[[2]]$Pooled$points)
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  inside <- TRUE
  widths <- integer()
  original_rect <- graphics::rect
  local_mocked_bindings(rect = function(xleft, ybottom, xright, ...) {
    inside <<- inside && all(xleft >= graphics::par("usr")[1] & xright <= graphics::par("usr")[2])
    widths <<- c(widths, length(xleft))
    original_rect(xleft, ybottom, xright, ...)
  }, .package = "graphics")
  plot(result, ask = FALSE)
  expect_true(inside)
  # One red box per value: three groups, then two values.
  expect_equal(sum(widths == 3), 1)
  expect_equal(sum(widths == 2), 1)
})

test_that("each category quartile is drawn on its own envelope, not the median's", {
  # Too little spread: the outer quartiles leave their own envelopes but stay
  # inside the median's, so a shared band would hide both departures.
  result <- check_dyad_residuals(distribution_check_fixture(), role = NULL, plot = FALSE)
  quantiles <- Map(function(observed, lower, upper)
    list(observed = observed, lower = lower, upper = upper),
    c(.484, .498, .516), c(.157, .401, .644), c(.357, .608, .844))
  result$compositions[[1]]$patterns[[1]]$Pooled <- list(positions = 1, labels = "A",
    limits = c(.55, 1.45), binned = FALSE, smooth = FALSE, numeric = FALSE,
    quantiles = quantiles)
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  ranges <- markers <- NULL
  original_segments <- graphics::segments
  original_points <- graphics::points
  local_mocked_bindings(segments = function(x0, y0, x1 = x0, y1 = y0, ...) {
    if (identical(list(...)$col, check_colours$simulation_line))
      ranges <<- rbind(ranges, c(x = x0, lower = y0, upper = y1))
    original_segments(x0, y0, x1, y1, ...)
  }, points = function(x, y, ...) {
    markers <<- rbind(markers, c(x = x, y = y))
    original_points(x, y, ...)
  }, .package = "graphics")
  plot(result, ask = FALSE)
  # Each quartile's point shares the position of its own range, and only there.
  expect_equal(nrow(ranges), 3)
  expect_equal(markers[, "x"], ranges[, "x"])
  expect_length(unique(ranges[, "x"]), 3)
  outside <- markers[, "y"] < ranges[, "lower"] | markers[, "y"] > ranges[, "upper"]
  expect_identical(unname(outside), c(TRUE, FALSE, TRUE))
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
  # Residuals: two pages plus one per predictor, or three figures plus one per predictor and role.
  expect_pages(check_dyad_residuals(simulations, "dyad", "role", predictors = "X", ask = FALSE),
               c(3, 3, 3))
  role_headings <- integer()
  expect_pages(check_dyad_residuals(simulations, "dyad", "role", panels = FALSE, ask = FALSE),
               c(3, 6, 3))
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
