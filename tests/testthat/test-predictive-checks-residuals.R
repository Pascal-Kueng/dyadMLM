distribution_check_fixture <- function() {
  predicted <- seq(0, 2, length.out = 12)
  structure(list(
    observed_response = predicted + seq(-2, 2, length.out = 12),
    predicted_response = predicted,
    simulated_responses = sweep(matrix(sin(seq_len(40 * 12)), 40),
                                2, predicted, "+"),
    model_frame = data.frame(
      dyad = rep(seq_len(6), each = 2), member = rep(1:2, 6),
      role = rep(c("A", "B"), 6)
    )
  ), class = "dyadMLM_response_simulations", dyadMLM = list(family = "gaussian"))
}


test_that("PIT ranks use only the independent reference bank", {
  skip_if_not_installed("DHARMa")
  simulations <- distribution_check_fixture()
  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)

  result <- withVisible(check_residuals(simulations, ask = FALSE))
  reference <- simulations$simulated_responses[1:20, ]
  evaluated <- rbind(simulations$observed_response,
                    simulations$simulated_responses[21:40, ])
  expected <- vapply(seq_len(nrow(evaluated)), function(dataset) {
    colMeans(reference < rep(evaluated[dataset, ], each = 20))
  }, numeric(ncol(reference)))
  expect_false(result$visible)
  expect_equal(unname(result$value), expected)
  expect_equal(dim(result$value), c(12L, 21L))

  # Plotting choices must not change the residuals being checked.
  expect_equal(check_residuals(simulations, centred_overlay = TRUE,
                              check_zeros = TRUE, ask = FALSE), result$value)
  expect_equal(check_residuals(simulations, predictors = data.frame(
    Role = factor(rep(c("A", "B"), 6)), X = seq_len(12)
  ), ask = FALSE), result$value)
  expect_identical(check_residuals(simulations, dyad = "dyad", role = "role",
                                 member = "member", ask = FALSE), result$value)
  expect_identical(check_residuals(simulations, dyad = "dyad", role = NULL,
                                 details = TRUE, ask = FALSE), result$value)
})


test_that("discrete PIT randomizes ties and preserves the caller's RNG", {
  skip_if_not_installed("DHARMa")
  reference <- cbind(c(0, 0, 1, 1), c(0, 1, 1, 2), c(0, 1, 2, 3),
                     c(0, 0, 0, 1), c(0, 0, 1, 2))
  simulations <- structure(list(
    observed_response = c(0, 1, 2, 0, 3), predicted_response = rep(1, 5),
    simulated_responses = rbind(reference, reference),
    model_frame = data.frame(row = seq_len(ncol(reference)))
  ), class = "dyadMLM_response_simulations", dyadMLM = list(family = "poisson"))
  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  withr::local_seed(392)
  random_state <- .Random.seed

  pit <- check_residuals(simulations, seed = 143, ask = FALSE)
  lower <- colMeans(reference < rep(simulations$observed_response, each = 4))
  upper <- colMeans(reference <= rep(simulations$observed_response, each = 4))
  expect_true(all(pit[, 1] >= lower & pit[, 1] <= upper))
  expect_true(all(pit[1:4, 1] > lower[1:4] & pit[1:4, 1] < upper[1:4]))
  expect_equal(unname(pit[5, 1]), 1)
  expect_identical(.Random.seed, random_state)
  expect_identical(check_residuals(simulations, seed = 143, ask = FALSE), pit)

  rm(".Random.seed", envir = .GlobalEnv)
  expect_identical(check_residuals(simulations, seed = 143, ask = FALSE), pit)
  expect_false(exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
})


test_that("rare binary groups and observed factor levels remain visible", {
  skip_if_not_installed("DHARMa")
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
  pit <- check_residuals(simulations, predictors = list(
    Binary = c(rep(0, 11), 1), Role = role
  ), ask = FALSE)
  expect_true(any(vapply(axes, function(axis) {
    isTRUE(all.equal(unname(axis$at), c(0, 1)))
  }, logical(1))))
  expect_true(any(vapply(axes, function(axis) {
    identical(as.character(axis$labels), c("A", "B"))
  }, logical(1))))
  expect_false(any(vapply(axes, function(axis) "Unused" %in% axis$labels, logical(1))))
  expect_false(connected_role)
  for (display in 1:2) {
    values <- if (display == 1) pit[, 1] else 2 * abs(pit[, 1] - .5)
    expected <- vapply(split(values, role, drop = TRUE), quantile, numeric(3),
                       probs = c(.25, .5, .75))
    expect_equal(boxes[[display]], unname(expected[c(1, 3), ]))
    expect_equal(medians[[display]], unname(expected[2, ]))
  }
})


test_that("missing plotting predictors affect only their own panels", {
  skip_if_not_installed("DHARMa")
  simulations <- distribution_check_fixture()
  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  expected <- check_residuals(simulations, ask = FALSE)
  observed <- bounds <- observed_x <- reference_x <- list()
  recording <- FALSE
  filled_pattern <- FALSE
  original_title <- graphics::title
  original_lines <- graphics::lines
  original_segments <- graphics::segments
  original_polygon <- graphics::polygon
  local_mocked_bindings(title = function(main = NULL, sub = NULL, xlab = NULL, ...) {
    recording <<- identical(xlab, "Incomplete")
    original_title(main = main, sub = sub, xlab = xlab, ...)
  }, lines = function(x, y, ...) {
    if (recording && !missing(y)) {
      observed[[length(observed) + 1L]] <<- unname(y)
      observed_x[[length(observed_x) + 1L]] <<- unname(x)
    }
    if (missing(y)) original_lines(x, ...) else original_lines(x, y, ...)
  }, segments = function(x0, y0, x1, y1, ...) {
    if (recording) {
      bounds[[length(bounds) + 1L]] <<- unname(rbind(y0, y1))
      reference_x[[length(reference_x) + 1L]] <<- unname(x0)
    }
    original_segments(x0, y0, x1, y1, ...)
  }, polygon = function(x, y = NULL, ...) {
    if (recording) filled_pattern <<- TRUE
    original_polygon(x, y, ...)
  }, .package = "graphics")

  incomplete <- c(0, NA, 0, 1, 1, NA, 0, 1, 0, NA, 1, 0)
  expect_warning(result <- check_residuals(simulations, predictors = list(
    Incomplete = incomplete
  ), ask = FALSE), "Incomplete.*3")
  expect_identical(result, expected)
  expect_false(filled_pattern)
  expect_true(all(observed_x[[1]] < observed_x[[2]] &
                    observed_x[[2]] < observed_x[[3]]))
  for (i in seq_along(c(.25, .5, .75))) {
    summaries <- vapply(c(0, 1), function(group) {
      apply(expected[which(incomplete == group), , drop = FALSE], 2,
            quantile, probs = c(.25, .5, .75)[i])
    }, numeric(ncol(expected)))
    expect_equal(observed[[i]], unname(summaries[1, ]))
    expect_equal(observed_x[[i]], reference_x[[i]])
    expect_equal(bounds[[i]], unname(apply(summaries[-1, , drop = FALSE], 2,
                                          quantile, probs = c(.025, .975))))
  }
  expect_warning(result <- check_residuals(simulations, predictors = list(
    Empty = rep(NA, 12)
  ), ask = FALSE), "Empty.*12")
  expect_identical(result, expected)
  expect_warning(result <- check_residuals(simulations, predictors = list(
    Role = factor(c(NA, rep(c("A", "B"), 5), "A"), exclude = NULL)
  ), ask = FALSE), "Role.*1")
  expect_identical(result, expected)
})


test_that("plotting restores graphics settings after success and failure", {
  skip_if_not_installed("DHARMa")
  simulations <- distribution_check_fixture()
  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mfrow = c(2, 1), mar = c(4, 3, 2, 1), cex = .9, mex = 1.2, las = 2)
  graphics::par(plt = c(.2, .8, .2, .8))
  settings <- graphics::par(c("mfrow", "mar", "oma", "mgp", "cex", "mex", "cex.main", "mfg", "las", "plt", "new"))
  grDevices::devAskNewPage(TRUE)

  check_residuals(simulations, ask = FALSE)
  expect_equal(graphics::par(names(settings)), settings)
  expect_true(grDevices::devAskNewPage())
  local_mocked_bindings(hist = function(...) stop("forced plotting failure"),
                        .package = "graphics")
  expect_error(check_residuals(simulations, ask = FALSE), "forced plotting failure")
  expect_equal(graphics::par(names(settings)), settings)
  expect_true(grDevices::devAskNewPage())
})


test_that("role panels and details fit the default graphics device", {
  skip_if_not_installed("DHARMa")
  simulations <- distribution_check_fixture()
  grDevices::pdf(NULL, width = 7, height = 7)
  on.exit(grDevices::dev.off(), add = TRUE)
  settings <- graphics::par(c("mfrow", "mar", "oma", "mgp", "cex", "mex", "cex.main", "mfg", "las", "plt", "new"))

  expect_no_error(check_residuals(simulations, dyad = "dyad", role = "role",
                                 check_zeros = TRUE, details = TRUE, ask = FALSE))
  expect_equal(graphics::par(names(settings)), settings)
})


test_that("overview and optional panels use predictable pages", {
  skip_if_not_installed("DHARMa")
  skip_if(Sys.which("pdfinfo") == "", "pdfinfo is needed to count PDF pages")
  simulations <- distribution_check_fixture()
  cases <- list(
    list(arguments = list(), pages = 2L),
    list(arguments = list(predictors = rep(list(seq_len(12)), 3)), pages = 5L),
    list(arguments = list(details = TRUE), pages = 3L),
    list(arguments = list(centred_overlay = TRUE), pages = 3L),
    list(arguments = list(dyad = "dyad", role = "role"), pages = 2L)
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


test_that("every residual page identifies its composition and page contents", {
  skip_if_not_installed("DHARMa")
  skip_if(Sys.which("pdfinfo") == "", "pdfinfo is needed to count PDF pages")
  simulations <- distribution_check_fixture()
  simulations$model_frame$role <- rep(c("A", "A", "A", "B", "B", "B"), 2)
  compositions <- c("A - A", "A - B", "B - B")
  margins <- list()
  original_mtext <- graphics::mtext
  local_mocked_bindings(mtext = function(text, ...) {
    margins[[length(margins) + 1L]] <<- c(list(text = text), list(...))
    original_mtext(text, ...)
  }, .package = "graphics")
  cases <- list(
    list(arguments = list(), pages = c("Residual checks", "Spread and extremes")),
    list(arguments = list(predictors = list(X = seq_len(12)), details = TRUE,
                          centred_overlay = TRUE),
         pages = c("Residual checks", "Spread and extremes", "X", "PIT distance",
                   "Outcomes minus predictions"))
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
    expect_equal(dim(pit), c(12L, 21L))
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


test_that("role columns use their own observations and simulated references", {
  skip_if_not_installed("DHARMa")
  simulations <- distribution_check_fixture()
  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  panel <- ""
  observed_qq <- simulated_qq <- histograms <- list()
  histogram_values <- histogram_breaks <- NULL
  original_title <- graphics::title
  original_lines <- graphics::lines
  original_segments <- graphics::segments
  original_hist <- graphics::hist
  original_abline <- graphics::abline
  local_mocked_bindings(title = function(main = NULL, ...) {
    panel <<- if (is.null(main)) "" else as.character(main)[1]
    if (panel %in% c("Response variability", "Outside simulated range", "Largest absolute deviation"))
      histograms[[length(histograms) + 1L]] <<- list(
        name = panel, values = histogram_values, limits = graphics::par("usr")[1:2],
        breaks = histogram_breaks
      )
    original_title(main = main, ...)
  }, lines = function(x, y, ...) {
    if (grepl("Uniform QQ", panel) && !missing(y))
      observed_qq[[length(observed_qq) + 1L]] <<- unname(y)
    if (missing(y)) original_lines(x, ...) else original_lines(x, y, ...)
  }, segments = function(x0, y0, x1, y1, ...) {
    if (grepl("Uniform QQ", panel))
      simulated_qq[[length(simulated_qq) + 1L]] <<- unname(rbind(y0, y1))
    original_segments(x0, y0, x1, y1, ...)
  }, hist = function(x, ...) {
    histogram_values <<- x
    histogram <- original_hist(x, ...)
    histogram_breaks <<- histogram$breaks
    histogram
  }, abline = function(...) {
    arguments <- list(...)
    if (length(histograms) && !is.null(arguments$v)) {
      marker <- if (identical(arguments$col, "#a12b35")) "observed" else "range"
      histograms[[length(histograms)]][[marker]] <<- arguments$v
    }
    original_abline(...)
  }, .package = "graphics")

  pit <- check_residuals(simulations, dyad = "dyad", role = "role", ask = FALSE)
  rows_by_role <- split(seq_len(12), simulations$model_frame$role)
  checks <- c("Response variability", "Outside simulated range", "Largest absolute deviation")
  expect_length(observed_qq, 2)
  expect_length(simulated_qq, 2)
  expect_identical(vapply(histograms, `[[`, "", "name"), rep(checks, each = 2))
  for (i in seq_along(rows_by_role)) {
    rows <- rows_by_role[[i]]
    expected_qq <- apply(pit[rows, , drop = FALSE], 2, quantile,
                         probs = seq(0, 1, length.out = 201))
    expect_equal(observed_qq[[i]], unname(expected_qq[, 1]))
    expect_equal(simulated_qq[[i]], unname(apply(expected_qq[, -1], 1,
      quantile, probs = c(.025, .975))))
    # The check's reference contains only held-out whole datasets for this role.
    responses <- rbind(simulations$observed_response[rows],
                       simulations$simulated_responses[21:40, rows])
    deviations <- sweep(responses, 2, simulations$predicted_response[rows])
    expected <- list(apply(deviations, 1, var),
                     colSums(pit[rows, ] == 0 | pit[rows, ] == 1),
                     apply(abs(deviations), 1, max))
    for (j in seq_along(checks)) {
      histogram <- histograms[[2 * (j - 1) + i]]
      expect_equal(unname(histogram$values), unname(expected[[j]][-1]))
      expect_equal(unname(histogram$observed), unname(expected[[j]][1]))
      expect_equal(unname(histogram$range),
                   unname(quantile(expected[[j]][-1], c(.025, .975))))
      expect_true(histogram$observed >= min(histogram$limits) &&
                    histogram$observed <= max(histogram$limits))
      if (checks[j] == "Outside simulated range")
        expect_true(all(diff(histogram$breaks) == 1))
    }
  }
})


test_that("zero-count panels are automatic and handle constant references", {
  skip_if_not_installed("DHARMa")
  simulations <- distribution_check_fixture()
  grDevices::pdf(NULL, width = 7, height = 7)
  on.exit(grDevices::dev.off(), add = TRUE)
  histograms <- list()
  histogram_values <- histogram_breaks <- NULL
  original_title <- graphics::title
  original_hist <- graphics::hist
  original_abline <- graphics::abline
  local_mocked_bindings(title = function(main = NULL, ...) {
    if (!is.null(main) && main %in% c("Response variability", "Outside simulated range",
                                    "Largest absolute deviation", "Number of zeros", "Uniformity"))
      histograms[[length(histograms) + 1L]] <<- list(
        name = main, values = histogram_values, limits = graphics::par("usr")[1:2],
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
    check_residuals(simulations, ...)
    Filter(function(panel) panel$name == "Number of zeros", histograms)
  }

  # The default call needs no plot flags, and continuous data need no zero panel.
  expect_length(zero_panels(simulations), 0)
  expect_identical(vapply(histograms, `[[`, "", "name"),
    c("Response variability", "Outside simulated range", "Largest absolute deviation"))
  observed_zero <- simulations
  observed_zero$observed_response[1] <- 0
  panel <- zero_panels(observed_zero)[[1]]
  expect_equal(unname(panel$values), rep(0, 20))
  expect_equal(unname(panel$observed), 1)
  expect_equal(panel$breaks, c(-.5, .5))
  expect_true(max(panel$limits) >= 1)
  expect_length(zero_panels(observed_zero, check_zeros = FALSE), 0)

  # Zeros in either simulation bank are enough to include the comparison.
  reference_zero <- simulations
  reference_zero$simulated_responses[1, 1] <- 0
  panel <- zero_panels(reference_zero)[[1]]
  expect_equal(unname(panel$values), rep(0, 20))
  expect_equal(unname(panel$observed), 0)
  evaluated_zeros <- simulations
  evaluated_zeros$simulated_responses[21:23, 1] <- 0
  panel <- zero_panels(evaluated_zeros)[[1]]
  expect_equal(unname(panel$values), c(rep(1, 3), rep(0, 17)))
  expect_equal(unname(panel$observed), 0)
  expect_length(zero_panels(simulations, check_zeros = TRUE), 1)
  zero_panels(simulations, details = TRUE)
  expect_true("Uniformity" %in% vapply(histograms, `[[`, "", "name"))
})


test_that("empty and single-observation roles remain plottable", {
  skip_if_not_installed("DHARMa")
  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  for (rows in list(1:2, seq(1, 12, by = 2))) {
    simulations <- distribution_check_fixture()
    fitting_data <- simulations$model_frame
    simulations$observed_response <- simulations$observed_response[rows]
    simulations$predicted_response <- simulations$predicted_response[rows]
    simulations$simulated_responses <- simulations$simulated_responses[, rows]
    simulations$model_frame <- simulations$model_frame[rows, , drop = FALSE]
    pooled <- check_residuals(simulations, ask = FALSE)
    expect_identical(check_residuals(simulations, dyad = "dyad", role = "role",
                                    data = fitting_data, details = TRUE,
                                    ask = FALSE), pooled)
  }
})


test_that("predictor groups absent in one role leave gaps on shared axes", {
  skip_if_not_installed("DHARMa")
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
    recording <<- identical(main, "PIT quantiles by Separated")
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
  pit <- check_residuals(simulations, dyad = "dyad", role = "role",
                        predictors = list(Separated = as.integer(role == "B")),
                        ask = FALSE)
  expect_length(curves, 6)
  expect_false(nonfinite_polygon)
  quartiles <- quantile(pit[role == "A", 1], c(.25, .5, .75))
  expect_equal(do.call(rbind, curves[1:3]), unname(cbind(quartiles, NA_real_)))
  quartiles <- quantile(pit[role == "B", 1], c(.25, .5, .75))
  expect_equal(do.call(rbind, curves[4:6]), unname(cbind(NA_real_, quartiles)))
})


test_that("numeric patterns use each role's bins and identical smoothing for references", {
  skip_if_not_installed("DHARMa")
  simulations <- distribution_check_fixture()
  simulations$model_frame <- simulations$model_frame[
    rep(seq_len(12), times = rep(c(10, 30), 6)), , drop = FALSE
  ]
  n <- nrow(simulations$model_frame)
  simulations$predicted_response <- seq(0, 2, length.out = n)
  simulations$observed_response <- simulations$predicted_response + sin(seq_len(n))
  simulations$simulated_responses <- sweep(matrix(sin(seq_len(40 * n)), 40),
    2, simulations$predicted_response, "+")
  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  curves <- bands <- band_x <- list()
  recording <- FALSE
  original_title <- graphics::title
  original_lines <- graphics::lines
  original_polygon <- graphics::polygon
  local_mocked_bindings(title = function(main = NULL, ...) {
    recording <<- identical(main, "PIT quantiles by Dense")
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

  pit <- check_residuals(simulations, dyad = "dyad", role = "role", member = "member",
                        predictors = list(Dense = seq_len(n)), ask = FALSE)
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
  for (i in seq_along(c(.25, .5, .75))) {
    binned <- t(vapply(rows_b, function(rows) {
      apply(pit[rows, , drop = FALSE], 2, quantile, probs = c(.25, .5, .75)[i])
    }, numeric(ncol(pit))))
    smoothed <- weights %*% binned
    bounds <- apply(smoothed[, -1], 1, quantile, probs = c(.025, .975))
    expect_equal(curves[[i + 3]]$x, grid)
    expect_equal(band_x[[i]], c(grid, rev(grid)))
    expect_equal(curves[[i + 3]]$y, unname(smoothed[, 1]))
    expect_equal(bands[[i]], unname(c(bounds[1, ], rev(bounds[2, ]))))
    # Smoothing the interval endpoints instead would give a different reference.
    wrong_order <- weights %*% t(apply(binned[, -1], 1, quantile, c(.025, .975)))
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
  expect_identical(check_residuals(simulations, dyad = "dyad", role = "role",
    member = "member", predictors = list(Dense = tied), ask = FALSE), pit)
  expect_equal(lengths(lapply(curves, `[[`, "x")), rep(1L, 6))
  expect_length(bands, 0)
  for (i in seq_along(c("A", "B"))) {
    rows <- simulations$model_frame$role == c("A", "B")[i]
    expect_equal(curves[[3 * i - 1]]$x, mean(tied[rows]))
    expect_equal(curves[[3 * i - 1]]$y, median(pit[rows, 1]))
  }
})


test_that("fallback quartile offsets stay visible on small and clustered scales", {
  skip_if_not_installed("DHARMa")
  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  observed_x <- interval_x <- list()
  recording <- FALSE
  inside_limits <- TRUE
  original_title <- graphics::title
  original_lines <- graphics::lines
  original_segments <- graphics::segments
  visible <- function(x) {
    limits <- graphics::par("usr")[1:2]
    all(x >= limits[1] & x <= limits[2])
  }
  local_mocked_bindings(title = function(main = NULL, ...) {
    recording <<- identical(main, "PIT quantiles by Edge")
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
    simulations$simulated_responses <- matrix(sin(seq_len(40 * n)), 40)
    check_residuals(simulations, predictors = list(Edge = scales[[i]]), ask = FALSE)
    expect_equal(lengths(observed_x), rep(i, 3))
    expect_equal(observed_x, interval_x)
    expect_true(inside_limits)
  }
})


test_that("outcome ECDF paths retain ties, constant samples, and both tails", {
  skip_if_not_installed("DHARMa")
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
    recording <<- identical(main, "Outcome overlay")
    original_title(main = main, ...)
  }, lines = function(x, y, ...) {
    if (recording) paths[[length(paths) + 1L]] <<- list(
      x = x, y = y, type = list(...)$type, limits = graphics::par("usr")[1:2]
    )
    if (missing(y)) original_lines(x, ...) else original_lines(x, y, ...)
  }, .package = "graphics")

  check_residuals(simulations, ask = FALSE)
  expect_length(paths, 21)
  expect_true(all(vapply(paths, `[[`, "", "type") == "s"))
  limits <- paths[[1]]$limits
  # Each constant simulated sample jumps from zero to one exactly at two.
  expect_equal(lapply(paths[1:20], `[[`, "x"), rep(list(c(limits[1], 2, limits[2])), 20))
  expect_equal(lapply(paths[1:20], `[[`, "y"), rep(list(c(0, 1, 1)), 20))
  # Tied observations jump by their empirical proportions; no jumps are dropped.
  expect_equal(paths[[21]]$x, c(limits[1], -2, 1, 4, limits[2]))
  expect_equal(paths[[21]]$y, c(0, .25, .75, 1, 1))
  expect_true(limits[1] < -2 && limits[2] > 4)
})


test_that("discrete outcome panels show role-specific proportions and category labels", {
  skip_if_not_installed("DHARMa")
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
    recording <<- identical(main, "Outcome frequencies")
    original_title(main = main, ...)
  }, segments = function(x0, y0, x1, y1, ...) {
    if (recording) bounds[[length(bounds) + 1L]] <<- unname(rbind(y0, y1))
    original_segments(x0, y0, x1, y1, ...)
  }, .package = "graphics")

  check_residuals(simulations, dyad = "dyad", role = "role", ask = FALSE)
  expect_length(bars, 2)
  expect_length(bounds, 2)
  rows_by_role <- split(seq_len(12), simulations$model_frame$role)
  for (i in seq_along(rows_by_role)) {
    rows <- rows_by_role[[i]]
    expect_equal(as.numeric(bars[[i]]$labels), 0:3)
    expect_equal(unname(bars[[i]]$values), tabulate(
      simulations$observed_response[rows] + 1, nbins = 4) / length(rows))
    proportions <- t(apply(simulations$simulated_responses[21:40, rows], 1,
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
  check_residuals(simulations, ask = FALSE)
  expect_identical(bars[[3]]$labels, categories)
  expect_equal(unname(bars[[3]]$values[5]), 0)
})


test_that("invalid simulation inputs and predictor lengths fail clearly", {
  skip_if_not_installed("DHARMa")
  simulations <- distribution_check_fixture()
  expect_error(check_residuals(unclass(simulations)), "simulate_dyad_responses")
  expect_error(check_residuals(simulations, predictors = list(Wrong = 1:3)),
               "one value per observation")
  expect_error(check_residuals(simulations, details = NA), "details.*TRUE or FALSE")
  simulations$simulated_responses <- simulations$simulated_responses[1:3, ]
  expect_error(check_residuals(simulations), "four simulated datasets")
})
