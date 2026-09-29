test_that("outcome summaries use all simulations and each role's fitted rows", {
  simulations <- distribution_check_fixture()
  withr::local_seed(392)
  random_state <- .Random.seed
  result <- withVisible(check_dyad_outcomes(simulations, dyad = "dyad", role = "role", plot = FALSE))
  expect_false(result$visible)
  expect_s3_class(result$value, "dyadMLM_outcome_check")
  expect_identical(attr(result$value, "dyadMLM"), attr(simulations, "dyadMLM"))
  expect_identical(result$value$compositions[[1]]$label, "A - B")
  expect_named(result$value$compositions[[1]]$statistics, c("A", "B"))
  expect_identical(.Random.seed, random_state)
  rows_by_role <- split(seq_len(12), simulations$model_frame$role)
  for (i in seq_along(rows_by_role)) {
    rows <- rows_by_role[[i]]
    responses <- rbind(simulations$observed_response[rows], simulations$simulated_responses[, rows])
    deviations <- sweep(responses, 2, simulations$predicted_response[rows])
    expected <- rbind(`Response SD` = apply(deviations, 1, sd),
                      `Largest absolute deviation` = apply(abs(deviations), 1, max))
    expect_equal(unname(result$value$compositions[[1]]$statistics[[i]]), unname(expected))
    expect_identical(rownames(result$value$compositions[[1]]$statistics[[i]]), rownames(expected))
  }
})


test_that("outcome SDs match partner role SDs for complete distinct-role dyads", {
  simulations <- distribution_check_fixture()
  simulations$observed_response[1] <- simulations$observed_response[1] + 1
  outcomes <- check_dyad_outcomes(simulations, dyad = "dyad", role = "role", plot = FALSE)
  partners <- check_partner_dependence(simulations, dyad = "dyad", role = "role", plot = FALSE)
  for (role in c("A", "B")) {
    expect_equal(unname(outcomes$compositions[[1]]$statistics[[role]]["Response SD", ]),
                 partners$compositions$statistics[[1]][[paste0("SD (", role, ")")]])
  }
})


test_that("outcome pages retain composition headings and restore graphics settings", {
  simulations <- distribution_check_fixture()
  simulations$model_frame$role <- rep(c("A", "A", "A", "B", "B", "B"), 2)
  headings <- character()
  original_mtext <- graphics::mtext
  local_mocked_bindings(mtext = function(text, ...) {
    if (length(text) == 1L && text %in% c("A - A", "A - B", "B - B"))
      headings <<- c(headings, text)
    original_mtext(text, ...)
  }, .package = "graphics")
  for (panels in c(TRUE, FALSE)) {
    headings <- character()
    pages <- count_pdf_pages({
      graphics::par(mfrow = c(2, 1), mar = c(4, 3, 2, 1), cex = .9, mex = 1.2, las = 2)
      settings <- graphics::par(c("mfrow", "mar", "oma", "mgp", "cex", "mex", "cex.main", "mfg", "las", "plt", "new"))
      grDevices::devAskNewPage(TRUE)
      result <- check_dyad_outcomes(simulations, dyad = "dyad", role = "role",
                                    panels = panels, ask = FALSE)
      expect_equal(graphics::par(names(settings)), settings)
      expect_true(grDevices::devAskNewPage())
    }, width = 7, height = 7)
    labels <- vapply(result$compositions, `[[`, "", "label")
    expect_identical(labels, c("A - A", "A - B", "B - B"))
    expect_identical(headings, rep(labels, if (panels) 1 else c(3, 6, 3)))
    expect_equal(pages, if (panels) 3 else 12)
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
  expect_error(check_dyad_outcomes(simulations, role = NULL, ask = FALSE), "forced plotting failure")
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
    expect_no_error(result <- check_dyad_outcomes(subset, dyad = "dyad", role = "role",
                                              data = fitting_data, ask = FALSE))
    expect_named(result$compositions[[1]]$statistics, c("A", "B"))
    expect_equal(ncol(result$compositions[[1]]$statistics$A), 2)
    if (length(rows) <= 2) expect_true(all(is.na(result$compositions[[1]]$statistics$A["Response SD", ])))
    if (!2 %in% rows) expect_null(result$compositions[[1]]$statistics$B)
  }
  expect_error(check_dyad_outcomes(unclass(simulations)), "simulate_dyad_responses")
  expect_error(check_dyad_outcomes(simulations, check_zeros = NA), "check_zeros")
})


test_that("zero counts include every dataset and can be selected explicitly", {
  simulations <- distribution_check_fixture()
  nsim <- nrow(simulations$simulated_responses)
  result <- check_dyad_outcomes(simulations, role = NULL, plot = FALSE)
  expect_identical(rownames(result$compositions[[1]]$statistics[[1]]),
                   c("Response SD", "Largest absolute deviation"))

  observed_zero <- simulations
  observed_zero$observed_response[1] <- 0
  # A Gaussian model never simulates an exact zero, so an observed zero alone
  # (e.g. on a rating scale) does not add the row; count and Tweedie families,
  # which can produce zeros, compare it.
  result <- check_dyad_outcomes(observed_zero, role = NULL, plot = FALSE)
  expect_false("Number of zeros" %in% rownames(result$compositions[[1]]$statistics[[1]]))
  for (family in c("poisson", "tweedie")) {
    attr(observed_zero, "dyadMLM")$family <- family
    result <- check_dyad_outcomes(observed_zero, role = NULL, plot = FALSE)
    expect_equal(unname(result$compositions[[1]]$statistics[[1]]["Number of zeros", ]),
                 c(1, rep(0, nsim)))
  }
  result <- check_dyad_outcomes(observed_zero, role = NULL, check_zeros = FALSE, plot = FALSE)
  expect_false("Number of zeros" %in% rownames(result$compositions[[1]]$statistics[[1]]))

  # Include early and later simulations, without a separate reference-bank split.
  simulations$simulated_responses[c(1, 21:23), 1] <- 0
  result <- check_dyad_outcomes(simulations, role = NULL, plot = FALSE)
  expect_equal(unname(result$compositions[[1]]$statistics[[1]]["Number of zeros", ]),
               c(0, as.numeric(seq_len(nsim) %in% c(1, 21:23))))
  result <- check_dyad_outcomes(distribution_check_fixture(), role = NULL,
                            check_zeros = TRUE, plot = FALSE)
  expect_equal(unname(result$compositions[[1]]$statistics[[1]]["Number of zeros", ]),
               rep(0, nsim + 1))
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

  check_dyad_outcomes(simulations, role = NULL, ask = FALSE)
  expect_length(paths, 31)
  expect_true(all(vapply(paths, `[[`, "", "type") == "s"))
  limits <- paths[[1]]$limits
  # Each constant simulated sample jumps from zero to one exactly at two.
  expect_equal(lapply(paths[1:30], `[[`, "x"), rep(list(c(limits[1], 2, limits[2])), 30))
  expect_equal(lapply(paths[1:30], `[[`, "y"), rep(list(c(0, 1, 1)), 30))
  # Tied observations jump by their empirical proportions; no jumps are dropped.
  expect_equal(paths[[31]]$x, c(limits[1], -2, 1, 4, limits[2]))
  expect_equal(paths[[31]]$y, c(0, .25, .75, 1, 1))
  expect_true(limits[1] < -2 && limits[2] > 4)

})


test_that("ordinal panels use saved role proportions, bounds, and all category labels", {
  simulations <- distribution_check_fixture()
  simulations$observed_response <- c(1, 1, 2, 1, 2, 3, 3, 4, 1, 2, 3, 4)
  simulations$simulated_responses <- matrix(as.integer(abs(sin(seq_len(40 * 12))) * 4) + 1, 40)
  attr(simulations, "dyadMLM") <- list(family = "ordinal")
  result <- check_dyad_outcomes(simulations, dyad = "dyad", role = "role", plot = FALSE)
  distribution <- result$compositions[[1]]$distribution
  expect_equal(as.numeric(distribution$labels), 1:4)
  rows_by_role <- split(seq_len(12), simulations$model_frame$role)
  for (i in seq_along(rows_by_role)) {
    rows <- rows_by_role[[i]]
    expect_equal(unname(distribution$roles[[i]]$observed), tabulate(
      simulations$observed_response[rows], nbins = 4) / length(rows))
    proportions <- t(apply(simulations$simulated_responses[, rows], 1,
                           function(x) tabulate(x, nbins = 4) / length(x)))
    expect_equal(unname(distribution$roles[[i]]$bounds),
                 unname(apply(proportions, 2, simulated_rank_limits)))
  }

  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  bars <- bounds <- list()
  caption <- NULL
  original_barplot <- graphics::barplot
  original_segments <- graphics::segments
  original_mtext <- graphics::mtext
  local_mocked_bindings(barplot = function(height, names.arg = NULL, ...) {
    bars[[length(bars) + 1L]] <<- list(values = height, labels = names.arg)
    original_barplot(height, names.arg = names.arg, ...)
  }, segments = function(x0, y0, x1, y1, ...) {
    bounds[[length(bounds) + 1L]] <<- rbind(y0, y1)
    original_segments(x0, y0, x1, y1, ...)
  }, mtext = function(text, ...) {
    caption <<- text
    original_mtext(text, ...)
  }, .package = "graphics")
  for (i in seq_along(distribution$roles)) {
    plot_outcome_distribution(distribution, i)
    expect_equal(bars[[i]], list(values = distribution$roles[[i]]$observed,
                                 labels = distribution$labels))
    expect_equal(unname(bounds[[i]]), unname(distribution$roles[[i]]$bounds))
  }
  expect_match(caption, "one outside can occur by chance")

  # Declared categories are retained even when no dataset uses them.
  categories <- c("Low", "Middle", "High", "Very high", "Unused")
  simulations$model_frame <- data.frame(
    response = ordered(categories[simulations$observed_response], levels = categories),
    simulations$model_frame
  )
  result <- check_dyad_outcomes(simulations, role = NULL, plot = FALSE)
  plot_outcome_distribution(result$compositions[[1]]$distribution, 1)
  expect_identical(bars[[3]]$labels, categories)
  expect_equal(unname(bars[[3]]$values[5]), 0)
})


test_that("zero-count inclusion is shared across roles within each composition", {
  simulations <- distribution_check_fixture()
  simulations$model_frame$role <- rep(c("A", "A", "A", "B", "B", "B"), 2)
  for (source in c("observed", "simulated")) {
    changed <- simulations
    if (source == "observed") {
      changed$observed_response[3] <- 0
      attr(changed, "dyadMLM")$family <- "poisson"
    } else changed$simulated_responses[1, 3] <- 0
    result <- check_dyad_outcomes(changed, dyad = "dyad", role = "role", plot = FALSE)
    statistics <- lapply(result$compositions, `[[`, "statistics")
    expect_false("Number of zeros" %in% rownames(statistics[[1]][[1]]))
    expect_false("Number of zeros" %in% rownames(statistics[[3]][[1]]))
    expect_true(all(vapply(statistics[[2]], function(role)
      "Number of zeros" %in% rownames(role), logical(1))))
    expect_equal(unname(statistics[[2]]$B["Number of zeros", ]),
                 rep(0, nrow(simulations$simulated_responses) + 1))
  }
})


test_that("count outcomes use the ECDF instead of observed categories", {
  simulations <- distribution_check_fixture()
  simulations$observed_response <- rep(0:2, 4)
  simulations$simulated_responses[] <- 0:3
  attr(simulations, "dyadMLM")$family <- "poisson"
  distribution <- check_dyad_outcomes(simulations, role = NULL, plot = FALSE)$compositions[[1]]$distribution
  expect_null(distribution$labels)
  expect_equal(distribution$roles[[1]][[1]], list(x = 0:2, y = c(1, 2, 3) / 3))
})


test_that("ECDF axes span observed values and the middle 98% of simulations", {
  simulations <- distribution_check_fixture()
  simulations$model_frame$role <- rep(c("A", "A", "A", "B", "B", "B"), 2)
  simulations$simulated_responses[1, 1] <- 1e6
  result <- check_dyad_outcomes(simulations, "dyad", "role", plot = FALSE)
  for (composition in result$compositions) {
    rows <- unlist(composition$rows)
    expect_equal(composition$distribution$limits,
                 range(simulations$observed_response[rows],
                       quantile(simulations$simulated_responses[, rows], c(.01, .99))))
  }
  expect_lt(result$compositions[[1]]$distribution$limits[2], 1e6)
})


test_that("outcome results can be calculated without graphics and plotted later", {
  simulations <- distribution_check_fixture()
  # Gaussian simulations include the zero row only when they contain a zero.
  simulations$observed_response[1] <- 0
  simulations$simulated_responses[1, 1] <- 0
  device <- grDevices::dev.cur()
  result <- with_mocked_bindings(
    check_dyad_outcomes(simulations, role = NULL, plot = FALSE, ask = "ignored", panels = "ignored"),
    plot.new = function(...) stop("Unexpected drawing"), .package = "graphics"
  )
  expect_identical(grDevices::dev.cur(), device)
  expect_s3_class(result, "dyadMLM_outcome_check")
  withr::local_seed(392)
  random_state <- .Random.seed
  # Saved checks contain plain data, including every overlay path and comparison.
  saved <- unserialize(serialize(result, NULL))
  grDevices::pdf(NULL, width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_identical(check_dyad_outcomes(simulations, role = NULL, ask = FALSE), result)
  expect_identical(check_dyad_outcomes(simulations, role = NULL, panels = FALSE, ask = FALSE), result)
  expect_identical(plot(saved, ask = FALSE), result)
  expect_identical(plot(saved, panels = FALSE, ask = FALSE), result)

  drawn <- list()
  local_mocked_bindings(plot_check_statistic = function(values, title, ..., counts) {
    drawn[[length(drawn) + 1L]] <<- list(values = values, title = title, counts = counts)
    graphics::plot.new()
  })
  plot(saved, ask = FALSE)
  statistics <- saved$compositions[[1]]$statistics[[1]]
  expect_equal(lapply(drawn, `[[`, "values"),
               lapply(seq_len(nrow(statistics)), function(i) statistics[i, ]))
  expect_identical(vapply(drawn, function(panel) sub("\n.*", "", panel$title), ""),
                   c("Response SD", "Largest absolute deviation", "Number of zeros"))
  expect_identical(vapply(drawn, `[[`, logical(1), "counts"), c(FALSE, FALSE, TRUE))
  expect_identical(.Random.seed, random_state)
})
