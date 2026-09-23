test_that("outcome summaries use all simulations and each role's fitted rows", {
  simulations <- distribution_check_fixture()
  grDevices::pdf(NULL, width = 7, height = 7)
  on.exit(grDevices::dev.off(), add = TRUE)
  withr::local_seed(392)
  random_state <- .Random.seed
  histograms <- list()
  histogram_values <- NULL
  original_title <- graphics::title
  original_hist <- graphics::hist
  original_abline <- graphics::abline
  local_mocked_bindings(title = function(main = NULL, ...) {
    title <- sub("\n.*", "", main)
    if (!is.null(main) && title %in% c("Response variance", "Largest absolute deviation"))
      histograms[[length(histograms) + 1L]] <<- list(
        name = title, values = histogram_values, limits = graphics::par("usr")[1:2]
      )
    original_title(main = main, ...)
  }, hist = function(x, ...) {
    histogram_values <<- x
    original_hist(x, ...)
  }, abline = function(...) {
    arguments <- list(...)
    if (length(histograms) && !is.null(arguments$v)) {
      marker <- if (identical(arguments$col, "#a12b35")) "observed" else "range"
      histograms[[length(histograms)]][[marker]] <<- arguments$v
    }
    original_abline(...)
  }, .package = "graphics")

  result <- withVisible(check_outcomes(simulations, dyad = "dyad", role = "role", ask = FALSE))
  expect_false(result$visible)
  expect_named(result$value, "A - B")
  expect_named(result$value[[1]], c("A", "B"))
  expect_identical(.Random.seed, random_state)
  checks <- c("Response variability", "Largest absolute deviation")
  expect_identical(vapply(histograms, `[[`, "", "name"),
    rep(c("Response variance", "Largest absolute deviation"), each = 2))
  rows_by_role <- split(seq_len(12), simulations$model_frame$role)
  for (i in seq_along(rows_by_role)) {
    rows <- rows_by_role[[i]]
    responses <- rbind(simulations$observed_response[rows], simulations$simulated_responses[, rows])
    deviations <- sweep(responses, 2, simulations$predicted_response[rows])
    expected <- rbind(apply(deviations, 1, var), apply(abs(deviations), 1, max))
    expect_identical(rownames(result$value[[1]][[i]]), checks)
    expect_equal(unname(result$value[[1]][[i]]), unname(expected))
    for (j in seq_along(checks)) {
      histogram <- histograms[[2 * (j - 1) + i]]
      expect_equal(unname(histogram$values), unname(expected[j, -1]))
      expect_equal(unname(histogram$observed), unname(expected[j, 1]))
      expect_equal(unname(histogram$range), unname(quantile(expected[j, -1], c(.025, .975))))
      expect_true(histogram$observed >= min(histogram$limits) &&
                    histogram$observed <= max(histogram$limits))
    }
  }
})


test_that("outcome pages retain composition headings and restore graphics settings", {
  skip_if(Sys.which("pdfinfo") == "", "pdfinfo is needed to count PDF pages")
  simulations <- distribution_check_fixture()
  simulations$model_frame$role <- rep(c("A", "A", "A", "B", "B", "B"), 2)
  headings <- character()
  original_mtext <- graphics::mtext
  local_mocked_bindings(mtext = function(text, ...) {
    if (length(text) == 1L && text %in% c("A - A", "A - B", "B - B"))
      headings <<- c(headings, text)
    original_mtext(text, ...)
  }, .package = "graphics")
  for (centred in c(FALSE, TRUE)) {
    headings <- character()
    pdf_path <- tempfile(fileext = ".pdf")
    grDevices::pdf(pdf_path, width = 7, height = 7)
    graphics::par(mfrow = c(2, 1), mar = c(4, 3, 2, 1), cex = .9, mex = 1.2, las = 2)
    settings <- graphics::par(c("mfrow", "mar", "oma", "mgp", "cex", "mex", "cex.main", "mfg", "las", "plt", "new"))
    grDevices::devAskNewPage(TRUE)
    result <- tryCatch({
      result <- check_outcomes(simulations, dyad = "dyad", role = "role",
                               centred_overlay = centred, ask = FALSE)
      expect_equal(graphics::par(names(settings)), settings)
      expect_true(grDevices::devAskNewPage())
      result
    }, finally = grDevices::dev.off())
    expect_named(result, c("A - A", "A - B", "B - B"))
    expect_identical(headings, rep(names(result), each = 1 + centred))
    information <- system2("pdfinfo", shQuote(pdf_path), stdout = TRUE)
    unlink(pdf_path)
    pages <- as.integer(sub("^Pages:\\s+", "", information[grepl("^Pages:", information)]))
    expect_equal(pages, 3 * (1 + centred))
  }
})


test_that("outcome plotting restores settings after failure", {
  simulations <- distribution_check_fixture()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mfrow = c(2, 1), cex.main = 1.2, las = 2)
  settings <- graphics::par(c("mfrow", "mar", "oma", "mgp", "cex", "mex", "cex.main", "mfg", "las", "plt", "new"))
  grDevices::devAskNewPage(TRUE)
  local_mocked_bindings(hist = function(...) stop("forced plotting failure"), .package = "graphics")
  expect_error(check_outcomes(simulations, ask = FALSE), "forced plotting failure")
  expect_equal(graphics::par(names(settings)), settings)
  expect_true(grDevices::devAskNewPage())
})


test_that("outcome checks retain lone responses and accept one simulated dataset", {
  simulations <- distribution_check_fixture()
  fitting_data <- simulations$model_frame
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  for (rows in list(1L, 1:2, seq(1, 12, by = 2))) {
    subset <- simulations
    subset$observed_response <- simulations$observed_response[rows]
    subset$predicted_response <- simulations$predicted_response[rows]
    subset$simulated_responses <- simulations$simulated_responses[1, rows, drop = FALSE]
    subset$model_frame <- simulations$model_frame[rows, , drop = FALSE]
    expect_no_error(result <- check_outcomes(subset, dyad = "dyad", role = "role",
                                              data = fitting_data, ask = FALSE))
    expect_named(result[[1]], c("A", "B"))
    expect_equal(ncol(result[[1]]$A), 2)
    if (length(rows) <= 2) expect_true(all(is.na(result[[1]]$A["Response variability", ])))
    if (!2 %in% rows) expect_null(result[[1]]$B)
  }
  expect_error(check_outcomes(unclass(simulations)), "simulate_dyad_responses")
  expect_error(check_outcomes(simulations, check_zeros = NA), "check_zeros")
})


test_that("zero-count panels are automatic and handle constant references", {
  simulations <- distribution_check_fixture()
  grDevices::pdf(NULL, width = 7, height = 7)
  on.exit(grDevices::dev.off(), add = TRUE)
  histograms <- list()
  histogram_values <- histogram_breaks <- NULL
  original_title <- graphics::title
  original_hist <- graphics::hist
  original_abline <- graphics::abline
  local_mocked_bindings(title = function(main = NULL, ...) {
    title <- sub("\n.*", "", main)
    if (!is.null(main) && title %in% c("Response variance", "Largest absolute deviation", "Number of zeros"))
      histograms[[length(histograms) + 1L]] <<- list(
        name = title, values = histogram_values, limits = graphics::par("usr")[1:2],
        breaks = histogram_breaks
      )
    original_title(main = main, ...)
  }, hist = function(x, ...) {
    histogram_values <<- x
    histogram <- original_hist(x, ...)
    histogram_breaks <<- histogram$breaks
    histogram
  }, abline = function(...) {
    arguments <- list(...)
    if (length(histograms) && identical(arguments$col, "#a12b35"))
      histograms[[length(histograms)]]$observed <<- arguments$v
    original_abline(...)
  }, .package = "graphics")
  zero_panels <- function(simulations, ...) {
    histograms <<- list()
    check_outcomes(simulations, ...)
    Filter(function(panel) panel$name == "Number of zeros", histograms)
  }

  # The default call needs no plot flags, and continuous data need no zero panel.
  expect_length(zero_panels(simulations), 0)
  expect_identical(vapply(histograms, `[[`, "", "name"),
    c("Response variance", "Largest absolute deviation"))
  observed_zero <- simulations
  observed_zero$observed_response[1] <- 0
  panel <- zero_panels(observed_zero)[[1]]
  expect_equal(unname(panel$values), rep(0, 40))
  expect_equal(unname(panel$observed), 1)
  expect_equal(panel$breaks, c(-.5, .5))
  expect_true(max(panel$limits) >= 1)
  expect_length(zero_panels(observed_zero, check_zeros = FALSE), 0)

  # Every simulated dataset contributes; there is no PIT reference-bank split.
  reference_zero <- simulations
  reference_zero$simulated_responses[1, 1] <- 0
  panel <- zero_panels(reference_zero)[[1]]
  expect_equal(unname(panel$values), c(1, rep(0, 39)))
  expect_equal(unname(panel$observed), 0)
  evaluated_zeros <- simulations
  evaluated_zeros$simulated_responses[21:23, 1] <- 0
  panel <- zero_panels(evaluated_zeros)[[1]]
  expect_equal(unname(panel$values), c(rep(0, 20), rep(1, 3), rep(0, 17)))
  expect_equal(unname(panel$observed), 0)
  expect_length(zero_panels(simulations, check_zeros = TRUE), 1)
})


test_that("outcome ECDF paths retain ties, constant samples, and both tails", {
  simulations <- distribution_check_fixture()
  simulations$observed_response <- rep(c(-2, 1, 4), c(3, 6, 3))
  simulations$simulated_responses[,] <- 2
  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  paths <- list()
  recording <- FALSE
  original_title <- graphics::title
  original_lines <- graphics::lines
  local_mocked_bindings(title = function(main = NULL, ...) {
    recording <<- !is.null(main) && grepl("outcome ECDF", main, ignore.case = TRUE)
    original_title(main = main, ...)
  }, lines = function(x, y, ...) {
    if (recording) paths[[length(paths) + 1L]] <<- list(
      x = x, y = y, type = list(...)$type, limits = graphics::par("usr")[1:2]
    )
    if (missing(y)) original_lines(x, ...) else original_lines(x, y, ...)
  }, .package = "graphics")

  check_outcomes(simulations, centred_overlay = TRUE, ask = FALSE)
  expect_length(paths, 62)
  expect_true(all(vapply(paths, `[[`, "", "type") == "s"))
  limits <- paths[[1]]$limits
  # Each constant simulated sample jumps from zero to one exactly at two.
  expect_equal(lapply(paths[1:30], `[[`, "x"), rep(list(c(limits[1], 2, limits[2])), 30))
  expect_equal(lapply(paths[1:30], `[[`, "y"), rep(list(c(0, 1, 1)), 30))
  # Tied observations jump by their empirical proportions; no jumps are dropped.
  expect_equal(paths[[31]]$x, c(limits[1], -2, 1, 4, limits[2]))
  expect_equal(paths[[31]]$y, c(0, .25, .75, 1, 1))
  expect_true(limits[1] < -2 && limits[2] > 4)
  # The optional overlay subtracts the same fitted predictions from every dataset.
  limits <- paths[[32]]$limits
  expect_equal(paths[[32]]$x,
    c(limits[1], sort(2 - simulations$predicted_response), limits[2]))
  expect_equal(paths[[62]]$x,
    c(limits[1], sort(simulations$observed_response - simulations$predicted_response), limits[2]))
  expect_equal(paths[[62]]$y, c(0, seq_len(12) / 12, 1))
})


test_that("discrete outcome panels show role-specific proportions and category labels", {
  simulations <- distribution_check_fixture()
  simulations$observed_response <- c(0, 0, 1, 0, 1, 2, 2, 3, 0, 1, 2, 3)
  simulations$simulated_responses <- matrix(as.integer(abs(sin(seq_len(40 * 12))) * 4), 40)
  attr(simulations, "dyadMLM") <- list(family = "poisson")
  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  bars <- bounds <- list()
  recording <- FALSE
  original_barplot <- graphics::barplot
  original_title <- graphics::title
  original_segments <- graphics::segments
  local_mocked_bindings(barplot = function(height, names.arg = NULL, ...) {
    bars[[length(bars) + 1L]] <<- list(values = height, labels = names.arg)
    original_barplot(height, names.arg = names.arg, ...)
  }, title = function(main = NULL, ...) {
    recording <<- identical(main, "Outcome frequencies\n(category proportions)")
    original_title(main = main, ...)
  }, segments = function(x0, y0, x1, y1, ...) {
    if (recording) bounds[[length(bounds) + 1L]] <<- unname(rbind(y0, y1))
    original_segments(x0, y0, x1, y1, ...)
  }, .package = "graphics")

  check_outcomes(simulations, dyad = "dyad", role = "role", ask = FALSE)
  expect_length(bars, 2)
  expect_length(bounds, 2)
  rows_by_role <- split(seq_len(12), simulations$model_frame$role)
  for (i in seq_along(rows_by_role)) {
    rows <- rows_by_role[[i]]
    expect_equal(as.numeric(bars[[i]]$labels), 0:3)
    expect_equal(unname(bars[[i]]$values), tabulate(
      simulations$observed_response[rows] + 1, nbins = 4) / length(rows))
    proportions <- t(apply(simulations$simulated_responses[, rows], 1,
                           function(x) tabulate(x + 1, nbins = 4) / length(x)))
    expect_equal(bounds[[i]], unname(apply(proportions, 2, quantile, c(.025, .975))))
  }

  simulations$observed_response <- simulations$observed_response + 1
  simulations$simulated_responses <- simulations$simulated_responses + 1
  categories <- c("Low", "Middle", "High", "Very high", "Unused")
  simulations$model_frame <- data.frame(
    response = ordered(categories[simulations$observed_response], levels = categories),
    simulations$model_frame
  )
  attr(simulations, "dyadMLM") <- list(family = "ordinal")
  check_outcomes(simulations, ask = FALSE)
  expect_identical(bars[[3]]$labels, categories)
  expect_equal(unname(bars[[3]]$values[5]), 0)
})
