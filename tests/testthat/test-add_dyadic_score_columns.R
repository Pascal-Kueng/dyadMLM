test_that("DSM constructs directional cross-sectional predictor scores", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("B", "A", "C", "D"),
    role = factor(c("male", "female", "female", "male")),
    x = c(3, 7, 12, 8),
    y = c(10, 14, 20, 24)
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role,
    predictors = x,
    model_type = "dsm",
    dsm_role_order = c("female", "male"),
    temporal_predictor_decomposition = "none"
  )

  expect_equal(result$.i_dsm_role_contrast, c(-0.5, 0.5, 0.5, -0.5))
  expect_equal(result$.i_x_dyad_mean_gmc, c(-2.5, -2.5, 2.5, 2.5))
  expect_equal(result$.i_x_within_dyad_diff, rep(4, 4))
  expect_false(".i_x_within_dyad_dev" %in% names(result))
  expect_false(any(startsWith(names(result), ".i_y_")))

  meta <- attr(result, "interdep")
  expect_equal(meta$dsm_role_order, c("female", "male"))
  expect_equal(meta$dsm_role_contrast_column, ".i_dsm_role_contrast")
  expect_equal(
    meta$dsm_predictors,
    tibble::tibble(
      predictor = "x",
      component = "raw",
      source_column = "x",
      mean_column = ".i_x_dyad_mean_gmc",
      difference_column = ".i_x_within_dyad_diff",
      dyad_decomposition_level = "dyad"
    )
  )
})

test_that("reversing DSM role order reverses directional columns only", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male"),
    x = c(7, 3, 12, 8)
  )

  female_minus_male <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role,
    predictors = x,
    model_type = "dsm",
    dsm_role_order = c("female", "male")
  )
  male_minus_female <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role,
    predictors = x,
    model_type = "dsm",
    dsm_role_order = c("male", "female")
  )

  expect_equal(
    male_minus_female$.i_x_dyad_mean_gmc,
    female_minus_male$.i_x_dyad_mean_gmc
  )
  expect_equal(
    male_minus_female$.i_x_within_dyad_diff,
    -female_minus_male$.i_x_within_dyad_diff
  )
  expect_equal(
    male_minus_female$.i_dsm_role_contrast,
    -female_minus_male$.i_dsm_role_contrast
  )
})

test_that("DSM requires both predictor values for dyadic scores", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male"),
    x = c(NA, 3, 12, 8)
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role,
    predictors = x,
    model_type = "dsm",
    dsm_role_order = c("female", "male")
  )

  expect_true(all(is.na(result$.i_x_dyad_mean_gmc[result$dyad_id == 1])))
  expect_true(all(is.na(result$.i_x_within_dyad_diff[result$dyad_id == 1])))
  expect_equal(result$.i_x_within_dyad_diff[result$dyad_id == 2], c(4, 4))
})

test_that("DSM creates a role contrast without predictors", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male")
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role,
    model_type = "dsm",
    dsm_role_order = c("female", "male")
  )

  expect_equal(result$.i_dsm_role_contrast, c(0.5, -0.5, 0.5, -0.5))
  expect_equal(
    attr(result, "interdep")$dsm_predictors,
    tibble::tibble(
      predictor = character(),
      component = character(),
      source_column = character(),
      mean_column = character(),
      difference_column = character(),
      dyad_decomposition_level = character()
    )
  )

  generated <- interdep_generated_columns(attr(result, "interdep"))
  expect_equal(generated$column, ".i_dsm_role_contrast")

  printed <- capture.output(print(result, n = 2))
  expect_true(any(grepl("DSM direction: female - male", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_dsm_role_contrast", printed, fixed = TRUE)))
  expect_false(any(grepl(".i_{pred}_dyad_mean", printed, fixed = TRUE)))
})

test_that("DSM keeps multiple predictors and metadata aligned", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male"),
    x = c(7, 3, 12, 8)
  )
  data[["stress level"]] <- c(10, 4, 9, 1)

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role,
    predictors = c(x, `stress level`),
    model_type = "dsm",
    dsm_role_order = c("female", "male")
  )

  expect_equal(result$.i_x_within_dyad_diff, rep(4, 4))
  expect_equal(result$.i_stress_level_within_dyad_diff, c(6, 6, 8, 8))
  expect_false(any(grepl("within_dyad_dev", names(result), fixed = TRUE)))

  meta <- attr(result, "interdep")$dsm_predictors
  expect_equal(meta$predictor, c("x", "stress level"))
  expect_equal(
    meta$difference_column,
    c(
      ".i_x_within_dyad_diff",
      ".i_stress_level_within_dyad_diff"
    )
  )
})

test_that("DSM constructs longitudinal CWP and CBP scores", {
  data <- data.frame(
    dyad_id = rep(1:2, each = 4),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    role = rep(c("female", "male"), 4),
    time = rep(c(1, 1, 2, 2), 2),
    x = c(4, 2, 8, 4, 10, 6, 14, 8)
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role,
    time = time,
    predictors = x,
    model_type = "dsm",
    dsm_role_order = c("female", "male")
  )

  expect_equal(result$.i_x_cwp_dyad_mean, rep(c(-1.5, -1.5, 1.5, 1.5), 2))
  expect_equal(result$.i_x_cwp_within_dyad_diff, rep(c(-1, -1, 1, 1), 2))
  expect_equal(result$.i_x_cbp_dyad_mean, c(rep(-2.5, 4), rep(2.5, 4)))
  expect_equal(result$.i_x_cbp_within_dyad_diff, c(rep(3, 4), rep(5, 4)))
  expect_equal(result$.i_dsm_role_contrast, rep(c(0.5, -0.5), 4))
  expect_false(any(grepl("within_dyad_dev", names(result), fixed = TRUE)))

  meta <- attr(result, "interdep")$dsm_predictors
  expect_equal(meta$component, c("cwp", "cbp"))
  expect_equal(meta$dyad_decomposition_level, c("dyad_time", "dyad"))
})

test_that("DSM returns missing CWP scores for an incomplete predictor pair", {
  data <- data.frame(
    dyad_id = rep(1:2, each = 4),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    role = rep(c("female", "male"), 4),
    time = rep(c(1, 1, 2, 2), 2),
    x = c(4, NA, 8, 4, 10, 6, 14, 8)
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role,
    time = time,
    predictors = x,
    model_type = "dsm",
    dsm_role_order = c("female", "male")
  )

  incomplete_occasion <- result$dyad_id == 1 & result$time == 1
  complete_occasion <- result$dyad_id == 1 & result$time == 2

  expect_true(all(is.na(result$.i_x_cwp_dyad_mean[incomplete_occasion])))
  expect_true(all(is.na(result$.i_x_cwp_within_dyad_diff[incomplete_occasion])))
  expect_false(any(is.na(result$.i_x_cwp_dyad_mean[complete_occasion])))
  expect_false(any(is.na(result$.i_x_cwp_within_dyad_diff[complete_occasion])))
  expect_false(any(is.na(result$.i_x_cbp_dyad_mean[result$dyad_id == 1])))
  expect_false(any(is.na(result$.i_x_cbp_within_dyad_diff[result$dyad_id == 1])))
})

test_that("DSM and APIM predictor columns can coexist", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male"),
    x = c(7, 3, 12, 8)
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role,
    predictors = x,
    model_type = c("apim", "dsm"),
    dsm_role_order = c("female", "male")
  )

  expect_true(all(c(
    ".i_x_actor",
    ".i_x_partner",
    ".i_x_dyad_mean_gmc",
    ".i_x_within_dyad_diff",
    ".i_dsm_role_contrast"
  ) %in% names(result)))
})

test_that("DSM rejects raw longitudinal predictor-score construction", {
  data <- data.frame(
    dyad_id = rep(1:2, each = 4),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    role = rep(c("female", "male"), 4),
    time = rep(c(1, 1, 2, 2), 2),
    x = c(4, 2, 8, 4, 10, 6, 14, 8)
  )

  expect_error(
    prepare_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      role = role,
      time = time,
      predictors = x,
      model_type = "dsm",
      dsm_role_order = c("female", "male"),
      temporal_predictor_decomposition = "none"
    ),
    "Longitudinal dyadic predictor-score construction requires temporally decomposed predictors.",
    fixed = TRUE
  )
})
