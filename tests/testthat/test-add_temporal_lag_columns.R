test_that("lag predictors are matched at exactly time minus one", {
  data <- data.frame(
    row_id = 1:10,
    dyad_id = c(2, 1, 2, 1, 2, 1, 2, 1, 2, 2),
    person_id = c("C", "A", "D", "B", "C", "A", "D", "B", "C", "D"),
    time = c(2, 1, 1, 3, 1, 3, 2, 1, 3, 3),
    x = c(22, 11, 31, 13, 21, 12, 32, 14, 23, 33),
    z = 101:110
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    time = time,
    predictors = c(x, z),
    lag_predictors = x,
    model_type = "apim",
    seed = 123
  )

  expect_equal(result$row_id, data$row_id)
  expect_equal(result$.i_x_lag1, c(21, NA, NA, NA, NA, NA, 31, NA, 22, 32))

  prior_cwp <- result$.i_x_cwp[match(
    paste(result$dyad_id, result$person_id, result$time - 1),
    paste(result$dyad_id, result$person_id, result$time)
  )]
  expect_equal(result$.i_x_cwp_lag1, prior_cwp)
  expect_equal(result$.i_x_actor_lag1, result$.i_x_lag1)

  partner_id <- c(A = "B", B = "A", C = "D", D = "C")[result$person_id]
  expected_partner_lag <- result$.i_x_lag1[match(
    paste(result$dyad_id, result$time, partner_id),
    paste(result$dyad_id, result$time, result$person_id)
  )]
  expect_equal(result$.i_x_partner_lag1, expected_partner_lag)

  expect_false(any(grepl(".i_z.*lag1", names(result))))
  expect_false(any(grepl("cbp.*lag1", names(result))))
  expect_equal(attr(result, "interdep")$lag_predictors, "x")
  expect_equal(
    attr(result, "interdep")$temporal_predictor_decompositions$lag,
    c(rep(0L, 6), 1L, 1L)
  )

  generated_lags <- interdep_generated_columns(attr(result, "interdep")) |>
    dplyr::filter(.data$lag == 1L)
  expect_equal(
    generated_lags$column,
    c(
      ".i_x_lag1",
      ".i_x_cwp_lag1",
      ".i_x_actor_lag1",
      ".i_x_cwp_actor_lag1",
      ".i_x_partner_lag1",
      ".i_x_cwp_partner_lag1"
    )
  )

  printed <- capture.output(print(result, n = 1))
  expect_true(any(grepl(".i_{pred}_actor_lag1", printed, fixed = TRUE)))
  expect_true(any(grepl("lag-1 APIM actor predictor", printed, fixed = TRUE)))
})

test_that("lag predictors handle a missing row for one member", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2),
    person_id = c("A", "B", "B", "A", "B", "C", "D", "C", "D", "C", "D"),
    time = c(1, 1, 2, 3, 3, 1, 1, 2, 2, 3, 3),
    x = c(10, 20, 21, 12, 22, 30, 40, 31, 41, 32, 42)
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    time = time,
    predictors = x,
    lag_predictors = x,
    model_type = "apim",
    seed = 123
  )

  member_a_time_3 <- result$dyad_id == 1 &
    result$person_id == "A" &
    result$time == 3

  expect_true(is.na(result$.i_x_actor_lag1[member_a_time_3]))
  expect_equal(result$.i_x_partner_lag1[member_a_time_3], 21)
})

test_that("lag predictors create DIM and DSM model-ready columns", {
  exchangeable <- data.frame(
    dyad_id = rep(1:2, each = 6),
    person_id = rep(c("A", "B"), 6),
    time = rep(rep(1:3, each = 2), 2),
    x = 1:12
  )

  dim_result <- prepare_interdep_data(
    exchangeable,
    group = dyad_id,
    member = person_id,
    time = time,
    predictors = x,
    lag_predictors = x,
    model_type = "dim",
    seed = 123
  )

  expect_true(all(c(
    ".i_x_dyad_mean_gmc_lag1",
    ".i_x_within_dyad_dev_lag1",
    ".i_x_cwp_dyad_mean_lag1",
    ".i_x_cwp_within_dyad_dev_lag1"
  ) %in% names(dim_result)))
  expect_true(all(is.na(dim_result$.i_x_dyad_mean_gmc_lag1[dim_result$time == 1])))
  expect_equal(
    dim_result$.i_x_within_dyad_dev_lag1[dim_result$time > 1],
    rep(c(-0.5, 0.5), 4)
  )

  distinguishable <- dplyr::mutate(
    exchangeable,
    role = ifelse(.data$person_id == "A", "first", "second")
  )
  dsm_result <- prepare_interdep_data(
    distinguishable,
    group = dyad_id,
    member = person_id,
    role = role,
    time = time,
    predictors = x,
    lag_predictors = x,
    model_type = "dsm",
    dsm_role_order = c("first", "second"),
    seed = 123
  )

  expect_true(all(c(
    ".i_x_dyad_mean_gmc_lag1",
    ".i_x_within_dyad_diff_lag1",
    ".i_x_cwp_dyad_mean_lag1",
    ".i_x_cwp_within_dyad_diff_lag1"
  ) %in% names(dsm_result)))
  expect_equal(
    dsm_result$.i_x_within_dyad_diff_lag1[dsm_result$time > 1],
    rep(-1, 8)
  )
})

test_that("lag predictors work without temporal centering", {
  data <- data.frame(
    dyad_id = rep(1:2, each = 4),
    person_id = rep(c("A", "B"), 4),
    time = rep(rep(1:2, each = 2), 2),
    x = letters[1:8]
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    time = time,
    predictors = x,
    lag_predictors = x,
    temporal_predictor_decomposition = "none",
    model_type = "apim",
    seed = 123
  )

  expect_equal(result$.i_x_lag1, c(NA, NA, "a", "b", NA, NA, "e", "f"))
  expect_equal(result$.i_x_actor_lag1, result$.i_x_lag1)
  expect_false(any(grepl("cwp.*lag1", names(result))))
})
