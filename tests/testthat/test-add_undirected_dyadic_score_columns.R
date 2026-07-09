test_that("undirected DSM creates raw cross-sectional outcome columns", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = c(1, 10, 20, 30),
    y = c(10, 14, 20, 24)
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    predictors = x,
    outcomes = y,
    model_type = "undirected_dsm",
    temporal_predictor_decomposition = "none",
    seed = 123
  )

  expect_equal(result$.i_y_raw_dyad_mean, c(12, 12, 22, 22))
  expect_equal(result$.i_y_raw_within_dyad_deviation, c(-2, 2, -2, 2))
  expect_true(".i_x_raw_dyad_mean_gmc" %in% names(result))
  expect_true(".i_x_raw_within_dyad_deviation" %in% names(result))

  expect_equal(
    attr(result, "interdep")$undirected_dsm_outcomes,
    tibble::tibble(
      outcome = "y",
      source_column = "y",
      mean_column = ".i_y_raw_dyad_mean",
      deviation_column = ".i_y_raw_within_dyad_deviation",
      decomposition_level = "dyad"
    )
  )
})

test_that("undirected DSM does not grand-mean center outcome dyad means", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    y = c(10, 14, 20, 24)
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    outcomes = y,
    model_type = "undirected_dsm",
    seed = 123
  )

  expect_equal(result$.i_y_raw_dyad_mean, c(12, 12, 22, 22))
  expect_false(isTRUE(all.equal(result$.i_y_raw_dyad_mean, c(-5, -5, 5, 5))))
})

test_that("undirected DSM creates raw longitudinal outcome columns by dyad-time", {
  data <- data.frame(
    dyad_id = rep(c(1, 1, 2, 2), each = 2),
    person_id = rep(c("A", "B", "C", "D"), each = 2),
    time = rep(1:2, 4),
    x = c(1, 2, 3, 4, 20, 21, 30, 31),
    y = c(10, 12, 14, 16, 20, 22, 24, 26)
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    time = time,
    predictors = x,
    outcomes = y,
    model_type = "undirected_dsm",
    seed = 123
  )

  expect_equal(result$.i_y_raw_dyad_mean, c(12, 14, 12, 14, 22, 24, 22, 24))
  expect_equal(result$.i_y_raw_within_dyad_deviation, c(-2, -2, 2, 2, -2, -2, 2, 2))
  expect_true(".i_x_cwp_dyad_mean" %in% names(result))
  expect_true(".i_x_cbp_dyad_mean" %in% names(result))

  expect_equal(
    attr(result, "interdep")$undirected_dsm_outcomes,
    tibble::tibble(
      outcome = "y",
      source_column = "y",
      mean_column = ".i_y_raw_dyad_mean",
      deviation_column = ".i_y_raw_within_dyad_deviation",
      decomposition_level = "dyad_time"
    )
  )
})

test_that("undirected DSM requires complete outcome values within dyad unit", {
  data <- data.frame(
    dyad_id = rep(c(1, 1, 2, 2), each = 2),
    person_id = rep(c("A", "B", "C", "D"), each = 2),
    time = rep(1:2, 4),
    y = c(10, 12, NA, 16, 20, NA, 24, 26)
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    time = time,
    outcomes = y,
    model_type = "undirected_dsm",
    seed = 123
  )

  expect_true(all(is.na(result$.i_y_raw_dyad_mean[result$dyad_id == 1 & result$time == 1])))
  expect_false(any(is.na(result$.i_y_raw_dyad_mean[result$dyad_id == 1 & result$time == 2])))
  expect_true(all(is.na(result$.i_y_raw_dyad_mean[result$dyad_id == 2 & result$time == 2])))
})

test_that("undirected DSM constructor enforces exchangeable compatibility without predictors", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male"),
    y = c(1, 2, 3, 4)
  )

  prepared <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role,
    outcomes = y,
    model_type = "undirected_dsm"
  ) |>
    infer_dyad_compositions(seed = 123) |>
    center_predictors()

  expect_error(
    add_undirected_dyadic_score_columns(prepared),
    "support only data with exactly one exchangeable dyad composition",
    fixed = TRUE
  )
})
