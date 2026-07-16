test_that("semantic effect colors are stable and selectable", {
  expected <- c(
    actor = "#1769AA",
    partner = "#7B3FA1",
    dyad_mean = "#C43C35",
    member_deviation = "#8A6500"
  )

  expect_identical(interdep_colors(), expected)
  expect_identical(
    interdep_colors(c("partner", "actor")),
    expected[c("partner", "actor")]
  )
  expect_error(interdep_colors("residual"), "Unknown effect")
  expect_error(interdep_colors(NA_character_), "without missing")
})
