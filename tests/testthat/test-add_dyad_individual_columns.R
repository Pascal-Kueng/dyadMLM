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

  expect_equal(result$.i_x_dyad_mean_gmc, c(-11.5, -11.5, -8.5, -8.5, 8, 8, 12, 12))
  expect_equal(result$.i_x_within_dyad_dev, c(-4.5, 4.5, -5.5, 5.5, -5, 5, -5, 5))
  expect_equal(result$.i_x_cwp_dyad_mean, c(-1.5, -1.5, 1.5, 1.5, -2, -2, 2, 2))
  expect_equal(result$.i_x_cwp_within_dyad_dev, c(0.5, -0.5, -0.5, 0.5, 0, 0, 0, 0))
  expect_equal(result$.i_x_cbp_dyad_mean, c(-10, -10, -10, -10, 10, 10, 10, 10))
  expect_equal(result$.i_x_cbp_within_dyad_dev, c(-5, 5, -5, 5, -5, 5, -5, 5))

  expect_equal(
    attr(result, "interdep")$dim_predictors,
    tibble::tibble(
      predictor = c("x", "x", "x"),
      component = c("raw", "cwp", "cbp"),
      lag = c(0L, 0L, 0L),
      source_column = c("x", ".i_x_cwp", ".i_x_cbp"),
      mean_column = c(".i_x_dyad_mean_gmc", ".i_x_cwp_dyad_mean", ".i_x_cbp_dyad_mean"),
      deviation_column = c(
        ".i_x_within_dyad_dev",
        ".i_x_cwp_within_dyad_dev",
        ".i_x_cbp_within_dyad_dev"
      ),
      dyad_decomposition_level = c("dyad_time", "dyad_time", "dyad")
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
  expect_false(is.na(result$.i_x_dyad_mean_gmc[1]))
  expect_true(is.na(result$.i_x_dyad_mean_gmc[3]))
  expect_true(is.na(result$.i_x_within_dyad_dev[3]))
  expect_true(all(is.na(result$.i_x_cbp_dyad_mean[result$dyad_id == 2])))
  expect_true(all(is.na(result$.i_x_cbp_within_dyad_dev[result$dyad_id == 2])))
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
    temporal_predictor_decomposition = "none"
  ) |>
    infer_dyad_compositions(seed = 123) |>
    center_predictors() |>
    add_dyad_individual_columns()

  expect_equal(result$.i_x_dyad_mean_gmc, c(-9.75, -9.75, 9.75, 9.75))
  expect_equal(result$.i_x_within_dyad_dev, c(-4.5, 4.5, -5, 5))

  expect_equal(
    attr(result, "interdep")$dim_predictors,
    tibble::tibble(
      predictor = "x",
      component = "raw",
      lag = 0L,
      source_column = "x",
      mean_column = ".i_x_dyad_mean_gmc",
      deviation_column = ".i_x_within_dyad_dev",
      dyad_decomposition_level = "dyad"
    )
  )
})

test_that("DIM sum-and-difference variances reproduce exchangeable member covariance", {
  shared_variance <- 1.3
  difference_variance <- 0.4
  sum_difference_covariance <- diag(c(shared_variance, difference_variance))
  member_rotation <- rbind(
    member_1 = c(1, 1),
    member_2 = c(1, -1)
  )

  member_covariance <-
    member_rotation %*% sum_difference_covariance %*% t(member_rotation)

  expect_equal(
    unname(member_covariance),
    matrix(c(1.7, 0.9, 0.9, 1.7), nrow = 2)
  )

  member_variance <- member_covariance[1, 1]
  partner_covariance <- member_covariance[1, 2]
  expect_equal(
    c(
      shared = (member_variance + partner_covariance) / 2,
      difference = (member_variance - partner_covariance) / 2
    ),
    c(shared = shared_variance, difference = difference_variance)
  )
})

test_that("DIM construction allows one role-supplied exchangeable composition", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "female", "female", "female"),
    x = c(1, 10, 20, 30)
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role,
    predictors = x,
    model_type = "dim",
    temporal_predictor_decomposition = "none",
    seed = 123
  )

  expect_true(".i_x_dyad_mean_gmc" %in% names(result))
  expect_true(".i_x_within_dyad_dev" %in% names(result))
  expect_equal(unique(as.character(result$.i_composition)), "female_x_female")
  expect_equal(attr(result, "interdep")$dyad_compositions$dyad_type, "exchangeable")
})

test_that("raw cross-sectional DIM requires complete dyad values", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = c(1, NA, 20, 30)
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    predictors = x,
    model_type = "dim",
    temporal_predictor_decomposition = "none",
    seed = 123
  )

  expect_true(all(is.na(result$.i_x_dyad_mean_gmc[result$dyad_id == 1])))
  expect_true(all(is.na(result$.i_x_within_dyad_dev[result$dyad_id == 1])))
  expect_equal(result$.i_x_dyad_mean_gmc[result$dyad_id == 2], c(0, 0))
  expect_equal(result$.i_x_within_dyad_dev[result$dyad_id == 2], c(-5, 5))
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
    temporal_predictor_decomposition = "none",
    seed = 123
  )

  expect_true(".i_x_dyad_mean_gmc" %in% names(result))
  expect_false("x_actor" %in% names(result))
  expect_false("x_partner" %in% names(result))
})

test_that("DIM construction errors for distinguishable dyads", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male"),
    x = c(1, 10, 20, 30)
  )

  expect_error(
    prepare_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      role = role,
      predictors = x,
      model_type = "dim",
      temporal_predictor_decomposition = "none",
      seed = 123
    ),
    "female_x_male \\(distinguishable, n_dyads = 2\\)"
  )
})

test_that("DIM construction errors for mixed distinguishable and exchangeable dyads", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2, 3, 3),
    person_id = c("A", "B", "C", "D", "E", "F"),
    role = c("female", "male", "female", "female", "male", "male"),
    x = c(1, 10, 20, 30, 40, 50)
  )

  expect_error(
    prepare_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      role = role,
      predictors = x,
      model_type = c("apim", "dim"),
      temporal_predictor_decomposition = "none",
      seed = 123
    ),
    "female_x_female \\(exchangeable, n_dyads = 1\\).*female_x_male \\(distinguishable, n_dyads = 1\\).*male_x_male \\(exchangeable, n_dyads = 1\\)"
  )
})

test_that("DIM construction errors for multiple exchangeable dyad compositions", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "female", "male", "male"),
    x = c(1, 10, 20, 30)
  )

  expect_error(
    prepare_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      role = role,
      predictors = x,
      model_type = "dim",
      temporal_predictor_decomposition = "none",
      seed = 123
    ),
    "female_x_female \\(exchangeable, n_dyads = 1\\).*male_x_male \\(exchangeable, n_dyads = 1\\)"
  )
})

test_that("longitudinal DIM constructs undecomposed raw predictor scores", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = c(1, 10, 3, 14, 20, 30, 24, 34)
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    time = time,
    predictors = x,
    model_type = "dim",
    temporal_predictor_decomposition = "none",
    seed = 123
  )

  expect_equal(result$.i_x_dyad_mean_gmc, c(-11.5, -11.5, -8.5, -8.5, 8, 8, 12, 12))
  expect_equal(result$.i_x_within_dyad_dev, c(-4.5, 4.5, -5.5, 5.5, -5, 5, -5, 5))
  expect_equal(attr(result, "interdep")$dim_predictors$component, "raw")
  expect_equal(attr(result, "interdep")$dim_predictors$dyad_decomposition_level, "dyad_time")
})
