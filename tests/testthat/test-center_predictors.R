test_that("center_predictors creates 2l centered predictor columns", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = c(1, 3, 3, 5, 5, 7, 7, 9)
  )

  result <- validate_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    time = time,
    predictors = x
  ) |>
    center_predictors()

  expect_true(".dy_x_cwp" %in% names(result))
  expect_true(".dy_x_cbp" %in% names(result))

  expect_equal(result$.dy_x_cwp, c(-1, -1, 1, 1, -1, -1, 1, 1))
  expect_equal(result$.dy_x_cbp, c(-3, -1, -3, -1, 1, 3, 1, 3))

  person_summary <- dplyr::summarise(
    dplyr::group_by(result, .data$dyad_id, .data$person_id),
    cwp_mean = mean(.data$.dy_x_cwp),
    cbp_n = dplyr::n_distinct(.data$.dy_x_cbp),
    .groups = "drop"
  )

  expect_equal(
    person_summary$cwp_mean,
    rep(0, 4)
  )

  expect_equal(
    person_summary$cbp_n,
    rep(1L, 4)
  )

  expect_equal(
    attr(result, "dyadMLM")$temporal_decompositions,
    tibble::tibble(
      predictor = c("x", "x", "x"),
      component = c("raw", "cwp", "cbp"),
      column = c("x", ".dy_x_cwp", ".dy_x_cbp"),
      temporal_decomposition = c("none", "2l", "2l"),
      lag = c(0L, 0L, 0L)
    )
  )
})

test_that("center_predictors weights people equally for between-person centering", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2),
    person_id = c("A", "A", "A", "B", "C", "D"),
    time = c(1, 2, 3, 1, 1, 1),
    x = c(0, 0, 30, 20, 40, 60)
  )

  result <- validate_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    time = time,
    predictors = x
  ) |>
    center_predictors()

  expect_equal(result$.dy_x_cwp, c(-10, -10, 20, 0, 0, 0))
  expect_equal(result$.dy_x_cbp, c(-22.5, -22.5, -22.5, -12.5, 7.5, 27.5))
})

test_that("center_predictors handles missing predictor values", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = c(1, 3, NA, 5, NA, NA, NA, NA)
  )

  result <- validate_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    time = time,
    predictors = x
  ) |>
    center_predictors()

  expect_equal(result$.dy_x_cwp[1:4], c(0, -1, NA, 1))
  expect_true(all(is.na(result$.dy_x_cwp[5:8])))
  expect_true(all(is.na(result$.dy_x_cbp[5:8])))
})

test_that("center_predictors does not remove user-owned person mean columns", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = c(1, 3, 3, 5, 5, 7, 7, 9),
    x_person_mean = 101:108
  )

  result <- validate_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    time = time,
    predictors = x
  ) |>
    center_predictors()

  expect_equal(result$x_person_mean, 101:108)
  expect_equal(result$.dy_x_cwp, c(-1, -1, 1, 1, -1, -1, 1, 1))
  expect_false(".dy_x_person_mean" %in% names(result))
})

test_that("center_predictors leaves uncentered data unchanged", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = 1:4
  )

  result <- validate_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    predictors = x,
    temporal_decomposition = "none"
  ) |>
    center_predictors()

  expect_equal(names(result), c("dyad_id", "person_id", "x"))
  expect_equal(
    attr(result, "dyadMLM")$temporal_decompositions,
    tibble::tibble(
      predictor = "x",
      component = "raw",
      column = "x",
      temporal_decomposition = "none",
      lag = 0L
    )
  )
})
