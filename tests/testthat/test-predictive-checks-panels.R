partner_check_plot_fixture <- function() {
  exchangeable_statistic_names <- c(
    "Common member SD (exchangeable)", "Partner correlation (exchangeable)",
    "Dyad-average SD", "Half-difference RMS (about zero)"
  )
  statistic_names <- list(
    c("SD (female)", "SD (male)", "Partner correlation (female and male)",
      "Dyad-average SD", "Half-difference SD (female minus male)",
      "Dyad-average/role-difference correlation (female minus male)"),
    exchangeable_statistic_names, exchangeable_statistic_names
  )
  observed_statistics <- list(
    c(1.2, 1.0, 0.4, 0.8, 0.7, 0.2), c(1.1, 0.35, 0.9, 0.6),
    c(1.3, 0.25, 0.8, 0.5)
  )
  statistics_by_composition <- lapply(seq_len(3), function(composition_index) {
    composition_observed_statistics <- observed_statistics[[composition_index]]
    simulated_statistics <- outer(
      seq(-0.2, 0.2, length.out = 80L), composition_observed_statistics, "+"
    )
    composition_statistics <- rbind(composition_observed_statistics, simulated_statistics)
    colnames(composition_statistics) <- statistic_names[[composition_index]]
    tibble::tibble(
      dataset = c("observed", paste0("simulation_", seq_len(80))),
      tibble::as_tibble(composition_statistics)
    )
  })

  structure(list(
    n_simulations = 80L,
    n_pairs = 360L,
    n_incomplete_dyads = 0L,
    n_missing_dyad_rows = 0L,
    n_missing_role_rows = 0L,
    response = "model-centred",
    compositions = tibble::tibble(
      label = c("female - male", "female - female", "male - male"),
      n_pairs = rep(120L, 3L),
      statistics = statistics_by_composition
    )
  ), class = c("dyadMLM_partner_check", "list"), dyadMLM = list(
    reference = "plug-in predictive", random_effects = "new"
  ))
}


test_that("panel mode produces one page per composition", {
  skip_if(Sys.which("pdfinfo") == "", "pdfinfo is needed to count PDF pages")
  check_result <- partner_check_plot_fixture()
  # A small composition stays in the overview but has no plot page.
  check_result$compositions[4L, ] <- list("mother - child", 2L, list(NULL))
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
  recorded_margin_text <- list()
  expected_statistic_titles <- c(
    "SD (female) (variability within this role)",
    "SD (male) (variability within this role)",
    "Partner correlation (how partners vary together)",
    "Dyad-average SD (variation between dyad averages)",
    "Half-difference SD (variation in partner differences)",
    "Mean-difference correlation (which role varies more)",
    rep(c("Common member SD (pooled variability)",
          "Partner correlation (how partners vary together)",
          "Dyad-average SD (variation between dyad averages)",
          "Half-difference RMS (size of partner differences)"), 2)
  )
  original_title <- graphics::title
  original_margin_text <- graphics::mtext
  local_mocked_bindings(title = function(main = NULL, sub = NULL, ...) {
    statistic_title <- gsub("\\s+", " ", main)
    if (length(statistic_title) == 1L &&
        statistic_title %in% expected_statistic_titles) {
      recorded_statistic_titles <<- c(recorded_statistic_titles, statistic_title)
      recorded_panel_positions[[length(recorded_panel_positions) + 1L]] <<-
        graphics::par("mfg")
    }
    original_title(main = main, sub = sub, ...)
  }, mtext = function(text, ...) {
    recorded_margin_text[[length(recorded_margin_text) + 1L]] <<- c(list(text = text), list(...))
    original_margin_text(text, ...)
  }, .package = "graphics")

  visible_result <- withVisible(plot(check_result, ask = FALSE))
  expect_false(visible_result$visible)
  expect_identical(visible_result$value, check_result)
  expect_identical(recorded_statistic_titles, expected_statistic_titles)
  expected_panel_positions <- rbind(
    cbind(rep(1:2, each = 3L), rep(1:3, 2L), 2L, 3L),
    cbind(rep(1:2, each = 2L), rep(1:2, 2L), 2L, 2L),
    cbind(rep(1:2, each = 2L), rep(1:2, 2L), 2L, 2L)
  )
  expect_equal(do.call(rbind, recorded_panel_positions), expected_panel_positions)
  headings <- Filter(function(text) isTRUE(text$outer) && isTRUE(text$side == 3) &&
    length(text$text) == 1L && text$text %in% check_result$compositions$label,
    recorded_margin_text)
  subtitles <- Filter(function(text) isTRUE(text$outer) && isTRUE(text$side == 3) &&
    length(text$text) == 1L && grepl("120.*360", text$text), recorded_margin_text)
  expect_identical(vapply(headings, `[[`, "", "text"), check_result$compositions$label)
  expect_length(subtitles, 3)
  expect_true(all(vapply(headings, `[[`, 0, "font") == 2))
  expect_true(all(vapply(headings, `[[`, 0, "cex") > vapply(subtitles, `[[`, 0, "cex")))
  expect_true(all(grepl("model-centred", vapply(subtitles, `[[`, "", "text"))))
})


test_that("long composition headings fit and retain their size across page layouts", {
  grDevices::pdf(NULL, width = 12, height = 8)
  on.exit(grDevices::dev.off(), add = TRUE)
  composition <- paste(rep("a detailed partner role", 6), collapse = " - ")
  headings <- list()
  original_mtext <- graphics::mtext
  local_mocked_bindings(mtext = function(text, ...) {
    arguments <- list(...)
    if (identical(text, composition)) headings[[length(headings) + 1L]] <<- c(
      size = arguments$cex,
      width = graphics::strwidth(text, "inches", font = arguments$font,
                                 cex = arguments$cex / graphics::par("cex"))
    )
    original_mtext(text, ...)
  }, .package = "graphics")
  for (rows in c(2, 4)) plot_check_page(composition, "Residual checks", c(rows, 2), {
    for (panel in seq_len(rows * 2)) graphics::plot.new()
  })
  expect_length(headings, 2)
  expect_equal(headings[[1]], headings[[2]])
  expect_lt(headings[[1]]["size"], 1.4)
  expect_lte(headings[[1]]["width"], .95 * grDevices::dev.size("in")[1])
})


test_that("individual plots retain composition, pair counts and interpretation", {
  check_result <- partner_check_plot_fixture()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mfcol = c(1, 2), plt = c(0.2, 0.8, 0.2, 0.8))
  previous_graphics_settings <- graphics::par(c("mfcol", "mar", "plt"))
  recorded_plot_text <- character()
  recorded_margin_text <- character()
  original_title <- graphics::title
  original_mtext <- graphics::mtext
  local_mocked_bindings(title = function(main = NULL, sub = NULL, ...) {
    recorded_plot_text <<- c(recorded_plot_text, paste(main, sub, collapse = " "))
    original_title(main = main, sub = sub, ...)
  }, mtext = function(text, ...) {
    recorded_margin_text <<- c(recorded_margin_text, text)
    original_mtext(text, ...)
  }, .package = "graphics")

  plot(check_result, panels = FALSE, ask = FALSE)
  expect_equal(graphics::par(names(previous_graphics_settings)),
               previous_graphics_settings)
  expect_length(recorded_plot_text, 14L)
  for (composition_index in seq_len(nrow(check_result$compositions))) {
    composition <- check_result$compositions[composition_index, ]
    expect_equal(sum(recorded_margin_text == composition$label),
                 ncol(composition$statistics[[1]]) - 1L)
  }
  expect_equal(sum(grepl("120.*360", recorded_margin_text)), 14)
  expect_equal(sum(grepl("Red should usually lie between dashed limits", recorded_margin_text)), 14)
})


test_that("automatic pausing follows the number of figures and device type", {
  check_result <- partner_check_plot_fixture()
  single_composition_check <- check_result
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
    c("mfcol", "mfg", "mar", "oma", "cex", "mex", "cex.main", "mgp", "las", "plt", "new")
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
