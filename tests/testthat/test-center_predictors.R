test_that("center_predictors creates time_2l centered predictor columns", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = c(1, 3, 3, 5, 5, 7, 7, 9)
  )

  result <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    time = time,
    predictors = x
  ) |>
    center_predictors()

  expect_true(".i_x_cwp" %in% names(result))
  expect_true(".i_x_cbp" %in% names(result))

  expect_equal(result$.i_x_cwp, c(-1, -1, 1, 1, -1, -1, 1, 1))
  expect_equal(result$.i_x_cbp, c(-3, -1, -3, -1, 1, 3, 1, 3))

  person_summary <- dplyr::summarise(
    dplyr::group_by(result, .data$dyad_id, .data$person_id),
    cwp_mean = mean(.data$.i_x_cwp),
    cbp_n = dplyr::n_distinct(.data$.i_x_cbp),
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
    attr(result, "interdep")$predictor_decompositions,
    tibble::tibble(
      predictor = c("x", "x"),
      component = c("cwp", "cbp"),
      column = c(".i_x_cwp", ".i_x_cbp"),
      temporal_predictor_decomposition = c("time_2l", "time_2l")
    )
  )
})

test_that("center_predictors handles missing predictor values", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = c(1, 3, NA, 5, NA, NA, NA, NA)
  )

  result <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    time = time,
    predictors = x
  ) |>
    center_predictors()

  expect_equal(result$.i_x_cwp[1:4], c(0, -1, NA, 1))
  expect_true(all(is.na(result$.i_x_cwp[5:8])))
  expect_true(all(is.na(result$.i_x_cbp[5:8])))
})

test_that("center_predictors does not remove user-owned person mean columns", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = c(1, 3, 3, 5, 5, 7, 7, 9),
    x_person_mean = 101:108
  )

  result <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    time = time,
    predictors = x
  ) |>
    center_predictors()

  expect_equal(result$x_person_mean, 101:108)
  expect_equal(result$.i_x_cwp, c(-1, -1, 1, 1, -1, -1, 1, 1))
  expect_false(".i_x_person_mean" %in% names(result))
})

test_that("center_predictors leaves uncentered data unchanged", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = 1:4
  )

  result <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    predictors = x,
    temporal_predictor_decomposition = "none"
  ) |>
    center_predictors()

  expect_equal(names(result), c("dyad_id", "person_id", "x"))
  expect_equal(
    attr(result, "interdep")$predictor_decompositions,
    tibble::tibble(
      predictor = "x",
      component = "raw",
      column = "x",
      temporal_predictor_decomposition = "none"
    )
  )
})
