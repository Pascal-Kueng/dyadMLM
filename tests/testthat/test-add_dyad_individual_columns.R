test_that("add_dyad_individual_columns creates longitudinal DIM columns", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = c(1, 10, 3, 14, 20, 30, 24, 34)
  )

  result <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    time = time,
    predictors = x
  ) |>
    infer_dyad_compositions(seed = 123) |>
    center_predictors() |>
    add_dyad_individual_columns()

  expect_equal(result$.i_x_cwp_dyad_mean, c(-1.5, -1.5, 1.5, 1.5, -2, -2, 2, 2))
  expect_equal(result$.i_x_cwp_dyad_deviation, c(0.5, -0.5, -0.5, 0.5, 0, 0, 0, 0))
  expect_equal(result$.i_x_cbp_dyad_mean, c(-10, -10, -10, -10, 10, 10, 10, 10))
  expect_equal(result$.i_x_cbp_dyad_deviation, c(-5, 5, -5, 5, -5, 5, -5, 5))

  expect_equal(
    attr(result, "interdep")$dim_predictors,
    tibble::tibble(
      predictor = c("x", "x"),
      component = c("cwp", "cbp"),
      source_column = c(".i_x_cwp", ".i_x_cbp"),
      mean_column = c(".i_x_cwp_dyad_mean", ".i_x_cbp_dyad_mean"),
      deviation_column = c(".i_x_cwp_dyad_deviation", ".i_x_cbp_dyad_deviation"),
      grouping = c("dyad_time", "dyad")
    )
  )
})

test_that("add_dyad_individual_columns requires complete dyad values for each component", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "C", "D", "C", "D"),
    time = c(1, 1, 2, 1, 1, 2, 2),
    x = c(1, 10, 3, 20, NA, 24, NA)
  )

  result <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    time = time,
    predictors = x
  ) |>
    infer_dyad_compositions(seed = 123) |>
    center_predictors() |>
    add_dyad_individual_columns()

  expect_false(is.na(result$.i_x_cwp_dyad_mean[1]))
  expect_true(is.na(result$.i_x_cwp_dyad_mean[3]))
  expect_true(all(is.na(result$.i_x_cbp_dyad_mean[result$dyad_id == 2])))
  expect_true(all(is.na(result$.i_x_cbp_dyad_deviation[result$dyad_id == 2])))
})

test_that("add_dyad_individual_columns creates cross-sectional raw DIM columns", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = c(1, 10, 20, 30)
  )

  result <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    predictors = x,
    centering = "none"
  ) |>
    infer_dyad_compositions(seed = 123) |>
    center_predictors() |>
    add_dyad_individual_columns()

  expect_equal(result$.i_x_raw_dyad_mean, c(-9.75, -9.75, 9.75, 9.75))
  expect_equal(result$.i_x_raw_dyad_deviation, c(-4.5, 4.5, -5, 5))
})

test_that("prepare_interdep_data creates DIM columns without APIM columns", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = c(1, 10, 20, 30)
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    predictors = x,
    model_type = "dim",
    centering = "none",
    seed = 123
  )

  expect_true(".i_x_raw_dyad_mean" %in% names(result))
  expect_false("x_actor" %in% names(result))
  expect_false("x_partner" %in% names(result))
})

test_that("longitudinal raw DIM construction errors clearly", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = c(1, 10, 3, 14, 20, 30, 24, 34)
  )

  expect_error(
    prepare_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      time = time,
      predictors = x,
      model_type = "dim",
      centering = "none",
      seed = 123
    ),
    "requires centered predictor components"
  )
})
