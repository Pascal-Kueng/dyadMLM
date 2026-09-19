partner_check_plot_fixture <- function() {
  statistic_names <- c(
    "SD (female)", "SD (male)", "Partner correlation (female and male)",
    "Dyad-average SD", "Half-difference SD (female minus male)",
    "Dyad-average/role-difference correlation (female minus male)",
    rep(c("Common member SD (exchangeable)",
          "Partner correlation (exchangeable)", "Dyad-average SD",
          "Half-difference RMS (about zero)"), 2L)
  )
  observed_statistics <- stats::setNames(
    c(1.2, 1.0, 0.4, 0.8, 0.7, 0.2, 1.1, 0.35, 0.9, 0.6,
      1.3, 0.25, 0.8, 0.5), statistic_names
  )
  simulated_statistics <- outer(
    seq(-0.2, 0.2, length.out = 80L), observed_statistics, "+"
  )
  colnames(simulated_statistics) <- statistic_names

  structure(list(
    observed_statistics = observed_statistics,
    replicated_statistics = simulated_statistics,
    n_pairs = 360L,
    n_incomplete_dyads = 0L,
    n_missing_dyad_rows = 0L,
    n_missing_role_rows = 0L,
    response = "model-centred",
    compositions = data.frame(
      label = c("female - male", "female - female", "male - male"),
      n_pairs = rep(120L, 3L),
      first_statistic = c(1L, 7L, 11L),
      last_statistic = c(6L, 10L, 14L)
    )
  ), class = c("dyadMLM_partner_check", "list"), dyadMLM = list(
    reference = "plug-in predictive", random_effects = "new"
  ))
}


test_that("panel mode produces one page per composition", {
  skip_if(Sys.which("pdfinfo") == "", "pdfinfo is needed to count PDF pages")
  check_result <- partner_check_plot_fixture()
  # A small composition stays in the overview but has no plot page.
  check_result$compositions[4L, ] <- list("mother - child", 2L, NA_integer_, NA_integer_)
  check_result$n_pairs <- 362L

  for (panels in c(TRUE, FALSE)) {
    pdf_path <- tempfile(fileext = ".pdf")
    grDevices::pdf(pdf_path, width = 12, height = 8)
    tryCatch({
      if (panels) {
        plot(check_result, ask = FALSE)
      } else {
        plot(check_result, panels = FALSE, ask = FALSE)
      }
    }, finally = grDevices::dev.off())
    pdf_information <- system2("pdfinfo", shQuote(pdf_path), stdout = TRUE)
    unlink(pdf_path)
    page_count <- as.integer(sub("^Pages:\\s+", "",
                                 pdf_information[grepl("^Pages:", pdf_information)]))
    expect_identical(page_count, if (panels) 3L else 14L)
  }
})


test_that("compositions use row-wise panels with clear titles and pair counts", {
  check_result <- partner_check_plot_fixture()
  grDevices::pdf(NULL, width = 12, height = 8)
  on.exit(grDevices::dev.off(), add = TRUE)
  recorded_statistic_titles <- character()
  recorded_panel_positions <- list()
  recorded_figure_text <- character()
  original_title <- graphics::title
  original_margin_text <- graphics::mtext
  local_mocked_bindings(title = function(main = NULL, sub = NULL, ...) {
    statistic_title <- gsub("\\s+", " ", main)
    if (length(statistic_title) == 1L &&
        statistic_title %in% names(check_result$observed_statistics)) {
      recorded_statistic_titles <<- c(recorded_statistic_titles, statistic_title)
      recorded_panel_positions[[length(recorded_panel_positions) + 1L]] <<-
        graphics::par("mfg")
    }
    recorded_figure_text <<- c(recorded_figure_text, main, sub)
    original_title(main = main, sub = sub, ...)
  }, mtext = function(text, ...) {
    recorded_figure_text <<- c(recorded_figure_text, text)
    original_margin_text(text, ...)
  }, .package = "graphics")

  visible_result <- withVisible(plot(check_result, ask = FALSE))
  expect_false(visible_result$visible)
  expect_identical(visible_result$value, check_result)
  expect_identical(recorded_statistic_titles, names(check_result$observed_statistics))
  expected_panel_positions <- rbind(
    cbind(rep(1:2, each = 3L), rep(1:3, 2L), 2L, 3L),
    cbind(rep(1:2, each = 2L), rep(1:2, 2L), 2L, 2L),
    cbind(rep(1:2, each = 2L), rep(1:2, 2L), 2L, 2L)
  )
  expect_equal(do.call(rbind, recorded_panel_positions), expected_panel_positions)
  for (composition_label in check_result$compositions$label) {
    composition_titles <- recorded_figure_text[
      grepl(composition_label, recorded_figure_text, fixed = TRUE)
    ]
    expect_true(length(composition_titles) >= 1L)
    expect_true(any(grepl("120.*360", composition_titles)))
  }
})


test_that("individual plots identify each composition and its pair counts", {
  check_result <- partner_check_plot_fixture()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mfcol = c(1, 2), plt = c(0.2, 0.8, 0.2, 0.8))
  previous_graphics_settings <- graphics::par(c("mfcol", "mar", "plt"))
  recorded_plot_text <- character()
  original_title <- graphics::title
  local_mocked_bindings(title = function(main = NULL, sub = NULL, ...) {
    recorded_plot_text <<- c(recorded_plot_text, paste(main, sub, collapse = " "))
    original_title(main = main, sub = sub, ...)
  }, .package = "graphics")

  plot(check_result, panels = FALSE, ask = FALSE)
  expect_equal(graphics::par(names(previous_graphics_settings)),
               previous_graphics_settings)
  expect_length(recorded_plot_text, 14L)
  for (composition_index in seq_len(nrow(check_result$compositions))) {
    composition <- check_result$compositions[composition_index, ]
    statistic_indices <- seq.int(composition$first_statistic,
                                 composition$last_statistic)
    expect_true(all(grepl(composition$label, recorded_plot_text[statistic_indices],
                         fixed = TRUE)))
    expect_true(all(grepl("120.*360", recorded_plot_text[statistic_indices])))
  }
})


test_that("automatic pausing follows the number of figures and device type", {
  check_result <- partner_check_plot_fixture()
  single_composition_check <- check_result
  single_composition_check$observed_statistics <- check_result$observed_statistics[1:6]
  single_composition_check$replicated_statistics <-
    check_result$replicated_statistics[, 1:6, drop = FALSE]
  single_composition_check$compositions <- check_result$compositions[1L, ]
  single_composition_check$n_pairs <- 120L
  grDevices::pdf(NULL, width = 12, height = 8)
  on.exit(grDevices::dev.off(), add = TRUE)
  device_is_interactive <- TRUE
  recorded_pause_settings <- logical()
  local_mocked_bindings(
    dev.interactive = function(...) device_is_interactive,
    devAskNewPage = function(ask = NULL) {
      recorded_pause_settings <<- c(recorded_pause_settings, ask)
      FALSE
    }, .package = "grDevices"
  )

  plot(check_result)
  expect_identical(recorded_pause_settings, c(TRUE, FALSE))
  recorded_pause_settings <- logical()
  plot(single_composition_check)
  expect_identical(recorded_pause_settings, c(FALSE, FALSE))
  recorded_pause_settings <- logical()
  plot(single_composition_check, panels = FALSE)
  expect_identical(recorded_pause_settings, c(TRUE, FALSE))
  recorded_pause_settings <- logical()
  plot(check_result, ask = FALSE)
  expect_identical(recorded_pause_settings, c(FALSE, FALSE))
  recorded_pause_settings <- logical()
  plot(single_composition_check, ask = TRUE)
  expect_identical(recorded_pause_settings, c(TRUE, FALSE))

  device_is_interactive <- FALSE
  for (ask in list(NULL, TRUE, FALSE)) {
    recorded_pause_settings <- logical()
    plot(check_result, ask = ask)
    expect_identical(recorded_pause_settings, c(FALSE, FALSE))
  }
})


test_that("panel plotting restores graphics settings after success and errors", {
  check_result <- partner_check_plot_fixture()
  grDevices::pdf(NULL, width = 12, height = 8)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mfcol = c(1L, 2L), mar = c(3, 3, 2, 1), oma = c(1, 1, 1, 1),
                cex = 0.9, mex = 1.2, cex.main = 1.1)
  graphics::par(plt = c(0.2, 0.8, 0.2, 0.8))
  previous_graphics_settings <- graphics::par(
    c("mfcol", "mfg", "mar", "oma", "cex", "mex", "cex.main", "plt")
  )
  # Use the real pause setting: restoring par() can overwrite it too.
  grDevices::devAskNewPage(TRUE)

  plot(check_result, ask = FALSE)
  expect_equal(graphics::par(names(previous_graphics_settings)),
               previous_graphics_settings)
  expect_true(grDevices::devAskNewPage())

  # Fail after the next composition has changed the panel layout.
  histogram_count <- 0L
  original_histogram <- graphics::hist
  local_mocked_bindings(hist = function(...) {
    histogram_count <<- histogram_count + 1L
    if (histogram_count == 8L) stop("test histogram failure")
    original_histogram(...)
  }, .package = "graphics")
  expect_error(plot(check_result, ask = FALSE), "test histogram failure")
  expect_equal(graphics::par(names(previous_graphics_settings)),
               previous_graphics_settings)
  expect_true(grDevices::devAskNewPage())
})
