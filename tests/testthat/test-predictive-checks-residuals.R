test_that("PIT ranks use every dataset symmetrically", {
  simulations <- distribution_check_fixture()

  result <- withVisible(check_residuals(simulations, role = NULL, plot = FALSE))
  responses <- cbind(simulations$observed_response, t(simulations$simulated_responses))
  expect_false(result$visible)
  expect_equal(dim(result$value$pit), c(12L, 201L))
  # One PIT in every rank interval, with ordering preserved for untied outcomes.
  expect_equal(unname(ceiling(result$value$pit * ncol(responses))),
               unname(t(apply(responses, 1, rank))))
  expect_true(all(result$value$pit > 0 & result$value$pit < 1))

  # Grouping and predictor choices must not change the residuals being checked.
  simulations$model_frame$X <- seq_len(12)
  expect_equal(check_residuals(simulations, role = NULL, predictors = c("role", "X"),
                              plot = FALSE)$pit, result$value$pit)
  expect_identical(check_residuals(simulations, dyad = "dyad", role = "role",
                                 member = "member", plot = FALSE)$pit, result$value$pit)
  expect_identical(check_residuals(simulations, dyad = "dyad", role = NULL,
                                 plot = FALSE)$pit, result$value$pit)
})


test_that("discrete PIT randomizes ties and preserves the caller's RNG", {
  reference <- cbind(c(0, 0, 1, 1), c(0, 1, 1, 2), c(0, 1, 2, 3),
                     c(0, 0, 0, 1), c(0, 0, 1, 2))
  simulations <- structure(list(
    observed_response = c(0, 1, 2, 0, 3), predicted_response = rep(1, 5),
    simulated_responses = reference[rep(1:4, 50), ],
    model_frame = data.frame(row = seq_len(ncol(reference)))
  ), class = "dyadMLM_response_simulations", dyadMLM = list(family = "poisson"))
  withr::local_seed(392)
  random_state <- .Random.seed

  result <- check_residuals(simulations, role = NULL, seed = 143, plot = FALSE)
  pit <- result$pit
  responses <- cbind(simulations$observed_response, t(simulations$simulated_responses))
  for (row in seq_len(nrow(responses))) {
    lower <- sum(responses[row, ] < responses[row, 1]) / ncol(responses)
    upper <- sum(responses[row, ] <= responses[row, 1]) / ncol(responses)
    expect_gt(pit[row, 1], lower)
    expect_lt(pit[row, 1], upper)
    expect_equal(sort(unname(ceiling(pit[row, ] * ncol(responses)))),
                 seq_len(ncol(responses)))
  }
  expect_identical(.Random.seed, random_state)
  expect_identical(check_residuals(simulations, role = NULL, seed = 143, plot = FALSE), result)

  rm(".Random.seed", envir = .GlobalEnv)
  expect_identical(check_residuals(simulations, role = NULL, seed = 143, plot = FALSE), result)
  expect_false(exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
})


test_that("residual results calculate without graphics and can be plotted later", {
  simulations <- distribution_check_fixture()
  simulations$model_frame$age <- seq_len(12)
  current_device <- grDevices::dev.cur()
  result <- local({
    local_mocked_bindings(plot.new = function(...) stop("unexpected graphics"),
                          .package = "graphics")
    check_residuals(simulations, dyad = "dyad", role = "role",
                    predictors = "age", plot = FALSE)
  })
  expect_s3_class(result, "dyadMLM_residual_check")
  expect_identical(grDevices::dev.cur(), current_device)
  saved <- tempfile(fileext = ".rds")
  on.exit(unlink(saved), add = TRUE)
  saveRDS(result, saved)
  restored <- readRDS(saved)
  expect_identical(restored, result)

  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_identical(check_residuals(simulations, dyad = "dyad", role = "role",
    predictors = "age", ask = FALSE), result)
  expect_identical(check_residuals(simulations, dyad = "dyad", role = "role",
    predictors = "age", panels = FALSE, ask = FALSE), result)
  withr::local_seed(392)
  random_state <- .Random.seed
  local_mocked_bindings(randomized_pit = function(...) stop("PIT recalculated"))
  expect_no_error(plot(restored, ask = FALSE))
  expect_no_error(plot(restored, panels = FALSE, ask = FALSE))
  expect_identical(.Random.seed, random_state)
  expect_identical(restored, result)
})


test_that("rare binary groups and observed factor levels remain visible", {
  simulations <- distribution_check_fixture()
  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  axes <- boxes <- medians <- list()
  recording_role <- connected_role <- FALSE
  original_axis <- graphics::axis
  original_title <- graphics::title
  original_rect <- graphics::rect
  original_segments <- graphics::segments
  original_lines <- graphics::lines
  local_mocked_bindings(axis = function(side, at = NULL, labels = TRUE, ...) {
    if (side == 1) axes[[length(axes) + 1L]] <<- list(at = at, labels = labels)
    original_axis(side, at = at, labels = labels, ...)
  }, title = function(main = NULL, sub = NULL, xlab = NULL, ...) {
    recording_role <<- identical(xlab, "Role")
    original_title(main = main, sub = sub, xlab = xlab, ...)
  }, rect = function(xleft, ybottom, xright, ytop, ...) {
    if (recording_role)
      boxes[[length(boxes) + 1L]] <<- unname(rbind(ybottom, ytop))
    original_rect(xleft, ybottom, xright, ytop, ...)
  }, segments = function(x0, y0, x1, y1, ...) {
    if (recording_role && all(x0 != x1))
      medians[[length(medians) + 1L]] <<- unname(y0)
    original_segments(x0, y0, x1, y1, ...)
  }, lines = function(...) {
    if (recording_role) connected_role <<- TRUE
    original_lines(...)
  }, .package = "graphics")

  role <- factor(rep(c("A", "B"), 6), levels = c("A", "B", "Unused"))
  simulations$model_frame$Binary <- c(rep(0, 11), 1)
  simulations$model_frame$Role <- role
  result <- check_residuals(simulations, role = NULL, predictors = c("Binary", "Role"),
                            ask = FALSE)
  expect_true(any(vapply(axes, function(axis) {
    isTRUE(all.equal(unname(axis$at), c(0, 1)))
  }, logical(1))))
  expect_true(any(vapply(axes, function(axis) {
    identical(as.character(axis$labels), c("A", "B"))
  }, logical(1))))
  expect_false(any(vapply(axes, function(axis) "Unused" %in% axis$labels, logical(1))))
  expect_false(connected_role)
  for (display in 1:2) {
    pattern <- result$compositions[[1]]$patterns[[3]][[1]]
    curves <- pattern[[c("quantiles", "distance")[display]]]
    expected <- do.call(rbind, lapply(curves, `[[`, "observed"))
    expect_equal(boxes[[display]], unname(expected[c(1, 3), ]))
    expect_equal(medians[[display]], unname(expected[2, ]))
  }
})


test_that("missing plotting predictors affect only their own panels", {
  simulations <- distribution_check_fixture()
  expected <- check_residuals(simulations, role = NULL, plot = FALSE)$pit
  incomplete <- c(0, NA, 0, 1, 1, NA, 0, 1, 0, NA, 1, 0)
  simulations$model_frame$Incomplete <- incomplete
  expect_warning(result <- check_residuals(simulations, role = NULL, predictors = "Incomplete",
                                           plot = FALSE), "Incomplete.*3")
  expect_identical(result$pit, expected)
  pattern <- result$compositions[[1]]$patterns[[2]][[1]]
  expect_equal(unname(pattern$positions), c(0, 1))
  expect_equal(pattern$points$predictor, incomplete[!is.na(incomplete)])
  expect_equal(pattern$points$pit, unname(expected[!is.na(incomplete), 1]))
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
  expect_warning(result <- check_residuals(simulations, role = NULL, predictors = "Empty",
                                           plot = FALSE), "Empty.*12")
  expect_identical(result$pit, expected)
  expect_length(result$predictors, 0)
  expect_length(result$compositions[[1]]$patterns, 1)
  simulations$model_frame$Role <- factor(c(NA, rep(c("A", "B"), 5), "A"), exclude = NULL)
  expect_warning(result <- check_residuals(simulations, role = NULL, predictors = "Role",
                                           plot = FALSE), "Role.*1")
  expect_identical(result$pit, expected)
})


test_that("predictor names match unchanged fitting data to fitted rows", {
  simulations <- distribution_check_fixture()
  simulations$model_frame$age <- rep(c(20, 20, 40, 40), 3)
  simulations$model_frame$stress <- factor(rep(c("low", "medium", "high"), 4))
  fitting_data <- simulations$model_frame
  calculate <- function(predictors, data = NULL) {
    check_residuals(simulations, role = NULL, predictors = predictors, data = data, plot = FALSE)
  }

  columns <- c("age", "stress")
  expected <- calculate(columns)
  expect_identical(expected$predictors, columns)
  expect_length(expected$compositions[[1]]$patterns, 3)
  simulations$model_frame$stress <- NULL
  expect_identical(calculate(columns, fitting_data), expected)

  # Omitted and reordered fitted rows retain their original predictor values.
  rows <- c(12, 2, 9, 4, 7, 6, 5, 8)
  simulations$observed_response <- simulations$observed_response[rows]
  simulations$predicted_response <- simulations$predicted_response[rows]
  simulations$simulated_responses <- simulations$simulated_responses[, rows]
  simulations$model_frame <- simulations$model_frame[rows, , drop = FALSE]
  simulations$model_frame$stress <- fitting_data$stress[rows]
  expected <- calculate(columns)
  simulations$model_frame$stress <- NULL
  expect_identical(calculate(columns, fitting_data[12:1, ]), expected)
  expect_error(calculate(columns), "stress.*not found.*data =")
  expect_error(calculate("missing", fitting_data), "missing.*not found")
  fitting_data$age[2] <- 99
  expect_error(calculate(columns, fitting_data), "age.*does not match")
})


test_that("plotting restores graphics settings after success and failure", {
  simulations <- distribution_check_fixture()
  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mfrow = c(2, 1), mar = c(4, 3, 2, 1), cex = .9, mex = 1.2, las = 2)
  graphics::par(plt = c(.2, .8, .2, .8))
  settings <- graphics::par(c("mfrow", "mar", "oma", "mgp", "cex", "mex", "cex.main", "mfg", "las", "plt", "new"))
  grDevices::devAskNewPage(TRUE)

  check_residuals(simulations, role = NULL, ask = FALSE)
  expect_equal(graphics::par(names(settings)), settings)
  expect_true(grDevices::devAskNewPage())
  local_mocked_bindings(hist = function(...) stop("forced plotting failure"),
                        .package = "graphics")
  expect_error(check_residuals(simulations, ask = FALSE), "forced plotting failure")
  expect_equal(graphics::par(names(settings)), settings)
  expect_true(grDevices::devAskNewPage())
})


test_that("complete role panels fit the default graphics device", {
  simulations <- distribution_check_fixture()
  grDevices::pdf(NULL, width = 7, height = 7)
  on.exit(grDevices::dev.off(), add = TRUE)
  settings <- graphics::par(c("mfrow", "mar", "oma", "mgp", "cex", "mex", "cex.main", "mfg", "las", "plt", "new"))

  expect_no_error(check_residuals(simulations, dyad = "dyad", role = "role",
                                 ask = FALSE))
  expect_equal(graphics::par(names(settings)), settings)
})


test_that("overview and optional panels use predictable pages", {
  skip_if(Sys.which("pdfinfo") == "", "pdfinfo is needed to count PDF pages")
  simulations <- distribution_check_fixture()
  simulations$model_frame$age <- rep(c(20, 40), 6)
  simulations$model_frame$stress <- factor(rep(c("low", "high", "medium"), 4))
  cases <- list(
    list(arguments = list(role = NULL), pages = 2L),
    list(arguments = list(role = NULL, predictors = NULL), pages = 2L),
    list(arguments = list(role = NULL, predictors = c("age", "stress")), pages = 4L),
    list(arguments = list(role = NULL, panels = FALSE), pages = 6L),
    list(arguments = list(role = NULL, predictors = c("age", "stress"), panels = FALSE), pages = 10L),
    list(arguments = list(dyad = "dyad", role = "role"), pages = 2L),
    list(arguments = list(dyad = "dyad", role = "role", panels = FALSE), pages = 12L)
  )
  for (case in cases) {
    pdf_path <- tempfile(fileext = ".pdf")
    grDevices::pdf(pdf_path, width = 12, height = 10)
    tryCatch(do.call(check_residuals, c(list(simulations, ask = FALSE), case$arguments)),
             finally = grDevices::dev.off())
    information <- system2("pdfinfo", shQuote(pdf_path), stdout = TRUE)
    unlink(pdf_path)
    pages <- as.integer(sub("^Pages:\\s+", "", information[grepl("^Pages:", information)]))
    expect_equal(pages, case$pages)
  }
})


test_that("all check functions pause consistently only on interactive devices", {
  simulations <- distribution_check_fixture()
  simulations$model_frame$age <- seq_len(12)
  single <- list(
    check_outcomes(simulations, role = NULL, plot = FALSE),
    check_partner_dependence(simulations, "dyad", role = NULL, plot = FALSE)
  )
  multiple <- list(
    check_residuals(simulations, role = NULL, plot = FALSE),
    check_residuals(simulations, role = NULL, predictors = "age", plot = FALSE)
  )
  simulations$model_frame$role <- c(rep("A", 6), rep(c("A", "B"), 3))
  multiple <- c(multiple, list(
    check_outcomes(simulations, "dyad", "role", plot = FALSE),
    check_partner_dependence(simulations, "dyad", "role", plot = FALSE)
  ))
  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  interactive_device <- TRUE
  ask_values <- logical()
  local_mocked_bindings(dev.interactive = function(...) interactive_device,
    devAskNewPage = function(ask = NULL) {
      ask_values <<- c(ask_values, ask)
      TRUE
    }, .package = "grDevices")
  cases <- list(
    list(arguments = list(), pause = FALSE),
    list(arguments = list(panels = FALSE), pause = TRUE),
    list(arguments = list(ask = TRUE), pause = TRUE),
    list(arguments = list(ask = FALSE), pause = FALSE)
  )
  for (result in single) for (case in cases) {
    ask_values <- logical()
    do.call(plot, c(list(result), case$arguments))
    expect_identical(ask_values, c(case$pause, TRUE))
  }
  for (result in multiple) {
    ask_values <- logical()
    plot(result)
    expect_identical(ask_values, c(TRUE, TRUE))
  }
  interactive_device <- FALSE
  for (result in c(single, multiple)) {
    ask_values <- logical()
    plot(result, ask = TRUE, panels = FALSE)
    expect_identical(ask_values, c(FALSE, TRUE))
  }
})


test_that("residual and outcome checks suggest roles only when role is omitted", {
  simulations <- distribution_check_fixture()
  expect_message(check_residuals(simulations, plot = FALSE), "No role supplied", fixed = TRUE)
  expect_message(check_outcomes(simulations, plot = FALSE), "No role supplied", fixed = TRUE)
  expect_no_message(check_residuals(simulations, role = NULL, plot = FALSE))
  expect_no_message(check_outcomes(simulations, "dyad", "role", plot = FALSE))
})


test_that("saved residual and outcome checks print a short overview", {
  simulations <- distribution_check_fixture()
  simulations$model_frame$age <- seq_len(12)
  residuals <- check_residuals(simulations, "dyad", "role", predictors = "age", plot = FALSE)
  printed <- capture.output(returned <- withVisible(print(residuals)))
  expect_false(returned$visible)
  expect_identical(returned$value, residuals)
  expect_identical(printed, c("<dyadMLM residual check>", "A - B: 6 dyads; 12 observations",
                              "Predictors: age", "Use plot(x) to view the checks."))
  expect_identical(capture.output(print(check_outcomes(simulations, role = NULL, plot = FALSE))),
                   c("<dyadMLM outcome check>", "All observations: 12 observations",
                     "Use plot(x) to view the checks."))
})


test_that("every residual page identifies its composition and page contents", {
  skip_if(Sys.which("pdfinfo") == "", "pdfinfo is needed to count PDF pages")
  simulations <- distribution_check_fixture()
  simulations$model_frame$role <- rep(c("A", "A", "A", "B", "B", "B"), 2)
  simulations$model_frame$X <- seq_len(12)
  compositions <- c("A - A", "A - B", "B - B")
  margins <- list()
  original_mtext <- graphics::mtext
  local_mocked_bindings(mtext = function(text, ...) {
    margins[[length(margins) + 1L]] <<- c(list(text = text), list(...))
    original_mtext(text, ...)
  }, .package = "graphics")
  cases <- list(
    list(arguments = list(), pages = c("Residual distribution", "Residual patterns: predicted outcome")),
    list(arguments = list(predictors = "X"),
         pages = c("Residual distribution", "Residual patterns: predicted outcome", "Residual patterns: X"))
  )
  for (case in cases) {
    margins <- list()
    pdf_path <- tempfile(fileext = ".pdf")
    grDevices::pdf(pdf_path, width = 12, height = 10)
    pit <- tryCatch(do.call(check_residuals, c(list(simulations, dyad = "dyad",
      role = "role", member = "member", ask = FALSE), case$arguments)),
      finally = grDevices::dev.off())
    information <- system2("pdfinfo", shQuote(pdf_path), stdout = TRUE)
    unlink(pdf_path)
    pages <- as.integer(sub("^Pages:\\s+", "", information[grepl("^Pages:", information)]))
    expect_equal(pages, 3 * length(case$pages))
    expect_equal(dim(pit$pit), c(12L, 201L))
    headings <- Filter(function(text) isTRUE(text$outer) && isTRUE(text$side == 3) &&
      length(text$text) == 1L && text$text %in% compositions, margins)
    subtitles <- Filter(function(text) isTRUE(text$outer) && isTRUE(text$side == 3) &&
      length(text$text) == 1L && grepl("2.*dyads.*4.*observations", text$text), margins)
    expect_identical(vapply(headings, `[[`, "", "text"),
                     rep(compositions, each = length(case$pages)))
    expect_length(subtitles, pages)
    expect_true(all(vapply(headings, `[[`, 0, "font") == 2))
    expect_true(all(vapply(headings, `[[`, 0, "cex") > vapply(subtitles, `[[`, 0, "cex")))
    expect_true(all(mapply(function(page, subtitle) grepl(page, subtitle, fixed = TRUE),
      rep(case$pages, 3), vapply(subtitles, `[[`, "", "text"))))
  }
})


test_that("individual residual figures retain composition, role and guidance", {
  simulations <- distribution_check_fixture()
  simulations$model_frame$age <- seq_len(12)
  result <- check_residuals(simulations, dyad = "dyad", role = "role",
                            predictors = "age", plot = FALSE)
  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  figures <- list()
  original_plot_new <- graphics::plot.new
  original_mtext <- graphics::mtext
  local_mocked_bindings(plot.new = function(...) {
    figures[[length(figures) + 1L]] <<- list()
    original_plot_new(...)
  }, mtext = function(text, ...) {
    arguments <- list(...)
    index <- length(figures)
    figures[[index]][[length(figures[[index]]) + 1L]] <<-
      c(list(text = text), arguments)
    original_mtext(text, ...)
  }, .package = "graphics")
  plot(result, panels = FALSE, ask = FALSE)
  expect_length(figures, 16)
  roles <- character()
  page_titles <- character()
  for (figure in figures) {
    labels <- unlist(lapply(figure, `[[`, "text"), use.names = FALSE)
    page_titles <- c(page_titles, labels[grepl("dyads;.*observations", labels)])
    expect_true(any(grepl("A - B", labels, fixed = TRUE)))
    role <- labels[grepl("^[AB] \\(n = 6\\)$", labels)]
    expect_length(role, 1)
    roles <- c(roles, role)
    captions <- Filter(function(label) !isTRUE(label$outer) &&
      identical(label$side, 1) && nzchar(label$text), figure)
    expect_length(captions, 1)
  }
  expect_equal(as.integer(table(roles)), c(8L, 8L))
  expect_identical(sub(" - .*", "", page_titles),
    rep(c("Residual distribution", "Residual patterns: predicted outcome", "Residual patterns: age"), c(8, 4, 4)))
})


test_that("role columns use their own observations and simulated references", {
  simulations <- distribution_check_fixture()
  result <- check_residuals(simulations, dyad = "dyad", role = "role", plot = FALSE)
  responses <- cbind(simulations$observed_response, t(simulations$simulated_responses))
  rows_by_role <- split(seq_len(12), simulations$model_frame$role)
  for (i in seq_along(rows_by_role)) {
    rows <- rows_by_role[[i]]
    values <- result$pit[rows, , drop = FALSE]
    statistics <- result$compositions[[1]]$statistics[[i]]
    expected_qq <- apply(values, 2, quantile, probs = seq(0, 1, length.out = 201))
    expect_equal(statistics$qq, residual_curve_summary(expected_qq))
    expected_histogram <- apply(values, 2, function(x)
      hist(x, breaks = seq(0, 1, length.out = 11), plot = FALSE)$density)
    expect_equal(statistics$histogram, residual_curve_summary(expected_histogram))
    # Strict raw-response extrema remain visible even though PIT has no endpoints.
    expect_equal(unname(statistics$outliers), colSums(strict_response_outliers(responses)[rows, ]))
    expect_equal(statistics$mean_distance, colMeans(2 * abs(values - .5)))
  }
})


test_that("residual plots draw each role's saved curves and scalar summaries", {
  result <- check_residuals(distribution_check_fixture(), dyad = "dyad", role = "role", plot = FALSE)
  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  observed <- bounds <- scalars <- list()
  recording <- FALSE
  original_title <- graphics::title
  original_lines <- graphics::lines
  original_segments <- graphics::segments
  local_mocked_bindings(title = function(main = NULL, ...) {
    recording <<- isTRUE(grepl("Uniform QQ", main))
    original_title(main = main, ...)
  }, lines = function(x, y, ...) {
    if (recording && !missing(y)) observed[[length(observed) + 1L]] <<- y
    if (missing(y)) original_lines(x, ...) else original_lines(x, y, ...)
  }, segments = function(x0, y0, x1, y1, ...) {
    if (recording) bounds[[length(bounds) + 1L]] <<- unname(rbind(y0, y1))
    original_segments(x0, y0, x1, y1, ...)
  }, .package = "graphics")
  local_mocked_bindings(plot_check_statistic = function(values, ..., counts = FALSE) {
    scalars[[length(scalars) + 1L]] <<- list(values = values, counts = counts)
    graphics::plot.new()
  })
  plot(result, ask = FALSE)
  statistics <- result$compositions[[1]]$statistics
  expect_equal(observed, unname(lapply(statistics, function(x) x$qq$observed)))
  expect_equal(bounds, unname(lapply(statistics, function(x) rbind(x$qq$lower, x$qq$upper))))
  expected <- c(lapply(statistics, `[[`, "outliers"), lapply(statistics, `[[`, "mean_distance"))
  expect_equal(lapply(scalars, `[[`, "values"), unname(expected))
  expect_identical(vapply(scalars, `[[`, logical(1), "counts"), c(TRUE, TRUE, FALSE, FALSE))
})


test_that("histogram positions match the bin count in new and saved results", {
  result <- check_residuals(distribution_check_fixture(), role = NULL, plot = FALSE)
  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  positions <- limits <- NULL
  recording <- FALSE
  original_title <- graphics::title
  original_lines <- graphics::lines
  local_mocked_bindings(title = function(main = NULL, ...) {
    recording <<- identical(main, "PIT histogram\n(how residuals are distributed)")
    original_title(main = main, ...)
  }, lines = function(x, y, ...) {
    if (recording) {
      positions <<- x
      limits <<- graphics::par("usr")[1:2]
    }
    if (missing(y)) original_lines(x, ...) else original_lines(x, y, ...)
  }, .package = "graphics")
  expect_length(result$compositions[[1]]$statistics[[1]]$histogram$observed, 10)
  for (bins in c(10L, 20L)) {
    # Existing 20-bin saved checks retain their original bin positions.
    densities <- apply(result$pit, 2, function(x)
      hist(x, breaks = seq(0, 1, length.out = bins + 1L), plot = FALSE)$density)
    result$compositions[[1]]$statistics[[1]]$histogram <- residual_curve_summary(densities)
    plot(result, ask = FALSE)
    expect_equal(positions, seq(1 / (2 * bins), 1 - 1 / (2 * bins), length.out = bins))
    expect_lte(limits[1], 0)
    expect_gte(limits[2], 1)
  }
})


test_that("empty and single-observation roles remain plottable", {
  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  for (rows in list(1:2, seq(1, 12, by = 2))) {
    simulations <- distribution_check_fixture()
    fitting_data <- simulations$model_frame
    simulations$observed_response <- simulations$observed_response[rows]
    simulations$predicted_response <- simulations$predicted_response[rows]
    simulations$simulated_responses <- simulations$simulated_responses[, rows]
    simulations$model_frame <- simulations$model_frame[rows, , drop = FALSE]
    pooled <- check_residuals(simulations, role = NULL, ask = FALSE)$pit
    expect_identical(check_residuals(simulations, dyad = "dyad", role = "role",
                                    data = fitting_data, ask = FALSE)$pit, pooled)
  }
})


test_that("predictor groups absent in one role leave gaps on shared axes", {
  simulations <- distribution_check_fixture()
  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  curves <- list()
  recording <- FALSE
  nonfinite_polygon <- FALSE
  original_title <- graphics::title
  original_lines <- graphics::lines
  original_polygon <- graphics::polygon
  local_mocked_bindings(title = function(main = NULL, ...) {
    recording <<- identical(main, "PIT quantiles by Separated\n(fit across predictor values)")
    original_title(main = main, ...)
  }, lines = function(x, y, ...) {
    if (recording && !missing(y))
      curves[[length(curves) + 1L]] <<- unname(y)
    if (missing(y)) original_lines(x, ...) else original_lines(x, y, ...)
  }, polygon = function(x, y = NULL, ...) {
    nonfinite_polygon <<- nonfinite_polygon || any(!is.finite(c(x, y)))
    original_polygon(x, y, ...)
  }, .package = "graphics")

  role <- simulations$model_frame$role
  simulations$model_frame$Separated <- as.integer(role == "B")
  pit <- check_residuals(simulations, dyad = "dyad", role = "role",
                        predictors = "Separated", ask = FALSE)$pit
  expect_length(curves, 6)
  expect_false(nonfinite_polygon)
  quartiles <- quantile(pit[role == "A", 1], c(.25, .5, .75))
  expect_equal(do.call(rbind, curves[1:3]), unname(cbind(quartiles, NA_real_)))
  quartiles <- quantile(pit[role == "B", 1], c(.25, .5, .75))
  expect_equal(do.call(rbind, curves[4:6]), unname(cbind(NA_real_, quartiles)))
})


test_that("numeric patterns use each role's bins and identical smoothing for references", {
  simulations <- distribution_check_fixture()
  simulations$model_frame <- simulations$model_frame[
    rep(seq_len(12), times = rep(c(10, 30), 6)), , drop = FALSE
  ]
  n <- nrow(simulations$model_frame)
  simulations$predicted_response <- seq(0, 2, length.out = n)
  simulations$observed_response <- simulations$predicted_response + sin(seq_len(n))
  simulations$simulated_responses <- sweep(matrix(sin(seq_len(200 * n)), 200),
    2, simulations$predicted_response, "+")
  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  curves <- bands <- band_x <- list()
  recording <- FALSE
  original_title <- graphics::title
  original_lines <- graphics::lines
  original_polygon <- graphics::polygon
  local_mocked_bindings(title = function(main = NULL, ...) {
    recording <<- identical(main, "PIT quantiles by Dense\n(fit across predictor values)")
    original_title(main = main, ...)
  }, lines = function(x, y, ...) {
    if (recording && !missing(y) && identical(list(...)$col, "#a12b35"))
      curves[[length(curves) + 1L]] <<- list(
        x = unname(x), y = unname(y), limits = graphics::par("usr")[1:2]
      )
    if (missing(y)) original_lines(x, ...) else original_lines(x, y, ...)
  }, polygon = function(x, y = NULL, ...) {
    if (recording) {
      bands[[length(bands) + 1L]] <<- unname(y)
      band_x[[length(band_x) + 1L]] <<- unname(x)
    }
    original_polygon(x, y, ...)
  }, .package = "graphics")

  simulations$model_frame$Dense <- seq_len(n)
  pit <- check_residuals(simulations, dyad = "dyad", role = "role", member = "member",
                        predictors = "Dense", ask = FALSE)$pit
  # Role A has 60 observations (three bins); role B has 180 (eight bins, smoothed).
  expect_length(curves, 6)
  expect_equal(lengths(lapply(curves, `[[`, "x")), c(rep(3L, 3), rep(101L, 3)))
  expect_length(bands, 3)
  expect_equal(curves[[2]]$limits, curves[[5]]$limits)
  rows_a <- which(simulations$model_frame$role == "A")
  rows_a <- split(rows_a, cut(rows_a, quantile(rows_a, seq(0, 1, length.out = 4)),
                              include.lowest = TRUE))
  expect_equal(curves[[2]]$x, unname(vapply(rows_a, mean, numeric(1))))
  expect_equal(curves[[2]]$y, unname(vapply(rows_a,
    function(rows) median(pit[rows, 1]), numeric(1))))

  rows_b <- which(simulations$model_frame$role == "B")
  support <- range(rows_b)
  rows_b <- split(rows_b, cut(rows_b, quantile(rows_b, seq(0, 1, length.out = 9)),
                              include.lowest = TRUE))
  centres <- vapply(rows_b, mean, numeric(1))
  grid <- seq(support[1], support[2], length.out = 101)
  weights <- outer(grid, centres, function(x, centre) {
    exp(-.5 * ((x - centre) / median(diff(centres)))^2)
  })
  weights <- weights / rowSums(weights)
  binned <- lapply(c(.25, .5, .75), function(probability) {
    t(vapply(rows_b, function(rows) {
      apply(pit[rows, , drop = FALSE], 2, quantile, probs = probability)
    }, numeric(ncol(pit))))
  })
  smoothed <- lapply(binned, function(values) weights %*% values)
  joint <- residual_curve_summary(do.call(rbind, smoothed))
  before_smoothing <- residual_curve_summary(do.call(rbind, binned))
  for (i in seq_along(smoothed)) {
    indices <- seq_along(grid) + (i - 1L) * length(grid)
    bounds <- rbind(joint$lower[indices], joint$upper[indices])
    expect_equal(curves[[i + 3]]$x, grid)
    expect_equal(band_x[[i]], c(grid, rev(grid)))
    expect_equal(curves[[i + 3]]$y, unname(smoothed[[i]][, 1]))
    expect_equal(bands[[i]], unname(c(bounds[1, ], rev(bounds[2, ]))))
    # Envelopes are computed jointly AFTER smoothing the dataset curves.
    bin_indices <- seq_along(rows_b) + (i - 1L) * length(rows_b)
    wrong_order <- weights %*% cbind(before_smoothing$lower[bin_indices],
                                    before_smoothing$upper[bin_indices])
    expect_gt(max(abs(t(bounds) - wrong_order)), .001)
  }
  observed_quartiles <- do.call(cbind, lapply(curves[4:6], `[[`, "y"))
  expect_true(all(observed_quartiles >= 0 & observed_quartiles <= 1))
  expect_true(all(observed_quartiles[, 1] <= observed_quartiles[, 2] &
                    observed_quartiles[, 2] <= observed_quartiles[, 3]))

  # One constant role and a heavily tied predictor need no smoothing or empty bins.
  curves <- bands <- list()
  tied <- numeric(n)
  tied[tail(which(simulations$model_frame$role == "B"), 20)] <- seq_len(20)
  simulations$model_frame$Dense <- tied
  expect_identical(check_residuals(simulations, dyad = "dyad", role = "role",
    member = "member", predictors = "Dense", ask = FALSE)$pit, pit)
  expect_equal(lengths(lapply(curves, `[[`, "x")), rep(1L, 6))
  expect_length(bands, 0)
  for (i in seq_along(c("A", "B"))) {
    rows <- simulations$model_frame$role == c("A", "B")[i]
    expect_equal(curves[[3 * i - 1]]$x, mean(tied[rows]))
    expect_equal(curves[[3 * i - 1]]$y, median(pit[rows, 1]))
  }
})


test_that("fallback quartile offsets stay visible on small and clustered scales", {
  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  observed_x <- interval_x <- list()
  recording <- filled_pattern <- FALSE
  inside_limits <- TRUE
  original_title <- graphics::title
  original_lines <- graphics::lines
  original_segments <- graphics::segments
  original_polygon <- graphics::polygon
  visible <- function(x) {
    limits <- graphics::par("usr")[1:2]
    all(x >= limits[1] & x <= limits[2])
  }
  local_mocked_bindings(title = function(main = NULL, ...) {
    recording <<- identical(main, "PIT quantiles by Edge\n(fit across predictor values)")
    original_title(main = main, ...)
  }, lines = function(x, y, ...) {
    if (recording && !missing(y) && identical(list(...)$col, "#a12b35")) {
      observed_x[[length(observed_x) + 1L]] <<- x
      inside_limits <<- inside_limits && visible(x)
    }
    if (missing(y)) original_lines(x, ...) else original_lines(x, y, ...)
  }, segments = function(x0, y0, x1, y1, ...) {
    if (recording) {
      interval_x[[length(interval_x) + 1L]] <<- x0
      inside_limits <<- inside_limits && visible(c(x0, x1))
    }
    original_segments(x0, y0, x1, y1, ...)
  }, polygon = function(x, y = NULL, ...) {
    if (recording) filled_pattern <<- TRUE
    original_polygon(x, y, ...)
  }, .package = "graphics")

  scales <- list(
    seq(0, 1e-8, length.out = 12),
    c(seq(0, 1e-6, length.out = 20), seq(1 - 1e-6, 1, length.out = 20)),
    c(seq(0, 1e-6, length.out = 20), seq(.5, .5 + 1e-6, length.out = 20),
      seq(1 - 1e-6, 1, length.out = 20))
  )
  for (i in seq_along(scales)) {
    observed_x <- interval_x <- list()
    inside_limits <- TRUE
    n <- length(scales[[i]])
    simulations <- distribution_check_fixture()
    simulations$model_frame <- data.frame(row = seq_len(n))
    simulations$predicted_response <- rep(0, n)
    simulations$observed_response <- sin(seq_len(n))
    simulations$simulated_responses <- matrix(sin(seq_len(200 * n)), 200)
    simulations$model_frame$Edge <- scales[[i]]
    check_residuals(simulations, role = NULL, predictors = "Edge", ask = FALSE)
    expect_equal(lengths(observed_x), rep(i, 3))
    expect_equal(observed_x, interval_x)
    expect_true(all(observed_x[[1]] < observed_x[[2]] & observed_x[[2]] < observed_x[[3]]))
    expect_false(filled_pattern)
    expect_true(inside_limits)
  }
})




test_that("invalid simulation inputs and unsupported predictor forms fail clearly", {
  simulations <- distribution_check_fixture()
  expect_error(check_residuals(unclass(simulations)), "simulate_dyad_responses")
  for (predictors in list(list(age = 1:12), data.frame(age = 1:12), ~ age, 1:12))
    expect_error(check_residuals(simulations, predictors = predictors, plot = FALSE),
                 "predictors.*(column names|character)")
  expect_error(check_residuals(simulations, details = TRUE), "unused argument")
  simulations$simulated_responses <- simulations$simulated_responses[1:199, ]
  expect_error(check_residuals(simulations), "200 simulated datasets")
})


test_that("strict response extrema exclude tied minima and maxima", {
  responses <- rbind(c(0, 1, 2, 3), c(0, 0, 1, 2), c(0, 1, 2, 2), rep(1, 4))
  expected <- rbind(c(TRUE, FALSE, FALSE, TRUE), c(FALSE, FALSE, FALSE, TRUE),
                    c(TRUE, FALSE, FALSE, FALSE), rep(FALSE, 4))
  expect_identical(strict_response_outliers(responses), expected)
  order <- c(4, 2, 1, 3)
  expect_identical(strict_response_outliers(responses[, order]), expected[, order])
})


test_that("centring precedes role splits and all PIT summaries use it", {
  simulations <- distribution_check_fixture()
  uncentred <- check_residuals(simulations, role = NULL, plot = FALSE)
  attr(simulations, "dyadMLM")$free_conditional_intercept <- TRUE
  centred <- check_residuals(simulations, dyad = "dyad", role = "role", plot = FALSE)
  z <- qnorm(uncentred$pit)
  expected <- pnorm(sweep(z, 2, apply(z, 2, median)))
  expect_equal(centred$pit, expected)
  expect_equal(apply(qnorm(centred$pit), 2, median), rep(0, ncol(expected)),
               ignore_attr = TRUE, tolerance = 1e-12)
  expect_true(attr(centred, "dyadMLM")$pit_centered)
  expect_false(attr(uncentred, "dyadMLM")$pit_centered)
  for (role in names(centred$compositions[[1]]$rows)) {
    rows <- centred$compositions[[1]]$rows[[role]]
    statistics <- centred$compositions[[1]]$statistics[[role]]
    expect_equal(statistics$mean_distance, colMeans(2 * abs(expected[rows, ] - .5)))
    expect_equal(statistics$qq$observed,
                 quantile(expected[rows, 1], seq(0, 1, length.out = 201)))
  }
  # The raw-response outlier count is independent of centring.
  pooled <- check_residuals(simulations, role = NULL, plot = FALSE)
  expect_identical(pooled$pit, centred$pit)
  expect_identical(pooled$compositions[[1]]$statistics[[1]]$outliers,
                   uncentred$compositions[[1]]$statistics[[1]]$outliers)
})


test_that("NULL seed advances RNG without warnings and saved plotting uses none", {
  simulations <- distribution_check_fixture()
  withr::local_seed(97)
  original <- .Random.seed
  expect_no_warning(result <- check_residuals(simulations, role = NULL,
                                             seed = NULL, plot = FALSE))
  expect_false(identical(original, .Random.seed))
  after <- .Random.seed
  expect_identical(check_residuals(simulations, role = NULL, plot = FALSE),
                   check_residuals(simulations, role = NULL, plot = FALSE))
  expect_identical(.Random.seed, after)
  expect_false(identical(result$pit, check_residuals(simulations, role = NULL,
                                                   seed = NULL, plot = FALSE)$pit))
})
