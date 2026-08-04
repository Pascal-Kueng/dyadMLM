test_that("temporary completion adds and then removes only missing member rows", {
  data <- data.frame(
    row_id = 1:7,
    dyad_id = c(1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "C", "D", "C", "D"),
    role = factor(c("first", "second", "first", "first", "second", "first", "second")),
    time = c(1, 1, 3, 1, 1, 3, 3),
    x = c(10, 20, 12, 30, 40, 32, 42)
  )

  validated <- validate_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role,
    time = time,
    predictors = x
  )

  completion <- temporarily_complete_dyad_occasions(validated)
  completed <- completion$data

  temporary_missing_member_rows <- dplyr::anti_join(
    tibble::as_tibble(completed),
    completion$original_observed_row_keys,
    by = c("dyad_id", "person_id", "time")
  )

  expect_equal(nrow(temporary_missing_member_rows), 1L)
  expect_equal(temporary_missing_member_rows$dyad_id, 1)
  expect_equal(temporary_missing_member_rows$person_id, "B")
  expect_equal(temporary_missing_member_rows$time, 3)
  expect_equal(as.character(temporary_missing_member_rows$role), "second")
  expect_true(is.na(temporary_missing_member_rows$x))
  expect_false(2 %in% completed$time[completed$dyad_id == 1])

  restored <- restore_observed_dyad_rows(
    completed,
    completion$original_observed_row_keys
  )

  expect_equal(restored$row_id, data$row_id)
  expect_identical(names(restored), names(validated))
  expect_identical(class(restored), class(validated))
  expect_identical(attr(restored, "dyadMLM"), attr(validated, "dyadMLM"))
})


test_that("temporary completion recovers APIM partner CBP and lagged values", {
  sparse <- data.frame(
    row_id = 1:10,
    dyad_id = c(rep(1, 4), rep(2, 6)),
    person_id = c("A", "B", "B", "A", "C", "D", "C", "D", "C", "D"),
    time = c(1, 1, 2, 3, 1, 1, 2, 2, 3, 3),
    x = c(10, 20, 21, 12, 30, 40, 31, 41, 32, 42)
  )

  explicitly_completed <- dplyr::bind_rows(
    sparse,
    data.frame(
      row_id = c(NA_integer_, NA_integer_),
      dyad_id = 1,
      person_id = c("A", "B"),
      time = c(2, 3),
      x = NA_real_
    )
  )

  sparse_result <- prepare_dyad_data(
    sparse,
    dyad = dyad_id,
    member = person_id,
    time = time,
    predictors = x,
    lag1_predictors = x,
    model_types = "apim",
    seed = 123
  )
  completed_result <- prepare_dyad_data(
    explicitly_completed,
    dyad = dyad_id,
    member = person_id,
    time = time,
    predictors = x,
    lag1_predictors = x,
    model_types = "apim",
    seed = 123
  ) |>
    dplyr::filter(!is.na(.data$row_id)) |>
    dplyr::arrange(.data$row_id)

  compared_columns <- c(
    ".x_partner",
    ".x_cwp_partner",
    ".x_cbp_partner",
    ".x_actor_lag1",
    ".x_partner_lag1",
    ".x_cwp_partner_lag1"
  )
  expect_equal(
    sparse_result[compared_columns],
    completed_result[compared_columns]
  )

  target_row <- sparse_result$dyad_id == 1 &
    sparse_result$person_id == "A" &
    sparse_result$time == 3

  expect_true(is.na(sparse_result$.x_partner[target_row]))
  expect_true(is.na(sparse_result$.x_cwp_partner[target_row]))
  expect_false(is.na(sparse_result$.x_cbp_partner[target_row]))
  expect_true(is.na(sparse_result$.x_actor_lag1[target_row]))
  expect_equal(sparse_result$.x_partner_lag1[target_row], 21)
  expect_equal(sparse_result$.x_cwp_partner_lag1[target_row], 0.5)

  expect_equal(sparse_result$row_id, sparse$row_id)
  expect_false(any(startsWith(names(sparse_result), ".dy_")))
})


test_that("temporary completion recovers lagged DIM and DSM scores", {
  sparse <- data.frame(
    row_id = 1:11,
    dyad_id = c(rep(1, 5), rep(2, 6)),
    person_id = c("A", "B", "A", "B", "A", "C", "D", "C", "D", "C", "D"),
    time = c(1, 1, 2, 2, 3, 1, 1, 2, 2, 3, 3),
    x = c(10, 20, 11, 21, 12, 30, 40, 31, 41, 32, 42)
  )
  explicitly_completed <- dplyr::bind_rows(
    sparse,
    data.frame(
      row_id = NA_integer_,
      dyad_id = 1,
      person_id = "B",
      time = 3,
      x = NA_real_
    )
  )

  dim_sparse <- prepare_dyad_data(
    sparse,
    dyad = dyad_id,
    member = person_id,
    time = time,
    predictors = x,
    lag1_predictors = x,
    model_types = "dim",
    seed = 123
  )
  dim_completed <- prepare_dyad_data(
    explicitly_completed,
    dyad = dyad_id,
    member = person_id,
    time = time,
    predictors = x,
    lag1_predictors = x,
    model_types = "dim",
    seed = 123
  ) |>
    dplyr::filter(!is.na(.data$row_id)) |>
    dplyr::arrange(.data$row_id)

  dim_lag_columns <- c(
    ".x_dyad_mean_gmc_lag1",
    ".x_within_dyad_dev_lag1",
    ".x_cwp_dyad_mean_lag1",
    ".x_cwp_within_dyad_dev_lag1"
  )
  expect_equal(dim_sparse[dim_lag_columns], dim_completed[dim_lag_columns])

  target_row <- dim_sparse$dyad_id == 1 &
    dim_sparse$person_id == "A" &
    dim_sparse$time == 3
  expect_false(any(is.na(dim_sparse[target_row, dim_lag_columns])))

  sparse$role <- ifelse(sparse$person_id %in% c("A", "C"), "first", "second")
  explicitly_completed$role <- ifelse(
    explicitly_completed$person_id %in% c("A", "C"),
    "first",
    "second"
  )

  dsm_sparse <- prepare_dyad_data(
    sparse,
    dyad = dyad_id,
    member = person_id,
    role = role,
    time = time,
    predictors = x,
    lag1_predictors = x,
    model_types = "dsm",
    dsm_role_order = c("first", "second"),
    seed = 123
  )
  dsm_completed <- prepare_dyad_data(
    explicitly_completed,
    dyad = dyad_id,
    member = person_id,
    role = role,
    time = time,
    predictors = x,
    lag1_predictors = x,
    model_types = "dsm",
    dsm_role_order = c("first", "second"),
    seed = 123
  ) |>
    dplyr::filter(!is.na(.data$row_id)) |>
    dplyr::arrange(.data$row_id)

  dsm_lag_columns <- c(
    ".x_dyad_mean_gmc_lag1",
    ".x_within_dyad_diff_lag1",
    ".x_cwp_dyad_mean_lag1",
    ".x_cwp_within_dyad_diff_lag1"
  )
  expect_equal(dsm_sparse[dsm_lag_columns], dsm_completed[dsm_lag_columns])

  target_row <- dsm_sparse$dyad_id == 1 &
    dsm_sparse$person_id == "A" &
    dsm_sparse$time == 3
  expect_false(any(is.na(dsm_sparse[target_row, dsm_lag_columns])))
})
