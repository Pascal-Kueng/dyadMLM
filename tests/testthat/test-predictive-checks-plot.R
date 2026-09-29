test_that("scalar plots keep the observed value on the axis", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  plot_check_statistic(c(7, rep(0:4, 40)), "Summary", counts = TRUE)
  expect_true(graphics::par("usr")[1] <= 7 && graphics::par("usr")[2] >= 7)
})
