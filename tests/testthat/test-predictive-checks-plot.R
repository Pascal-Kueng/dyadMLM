test_that("scalar plots retain all summaries, rank limits, and count-scale markers", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  histogram <- lines <- NULL
  original_hist <- graphics::hist
  original_abline <- graphics::abline
  local_mocked_bindings(hist = function(x, ...) {
    histogram <<- list(values = x, result = original_hist(x, ...))
    histogram$result
  }, abline = function(...) {
    lines[[length(lines) + 1L]] <<- list(...)
    original_abline(...)
  }, .package = "graphics")
  for (simulated in list(rep(0, 200), rep(0:4, 40))) {
    lines <- list()
    plot_check_statistic(c(7, simulated), "Summary", counts = TRUE)
    expect_equal(histogram$values, simulated)
    expect_equal(histogram$result$breaks, seq(min(simulated) - .5, max(simulated) + .5))
    expect_equal(lines[[1]]$v, simulated_rank_limits(simulated))
    expect_equal(lines[[1]]$lty, 2)
    expect_equal(lines[[2]]$v, 7)
    expect_identical(lines[[2]]$col, check_colours$observed)
    expect_true(graphics::par("usr")[1] <= 7 && graphics::par("usr")[2] >= 7)
  }
})
