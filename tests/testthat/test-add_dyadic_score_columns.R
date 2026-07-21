test_that("DSM constructs directional cross-sectional predictor scores", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("B", "A", "C", "D"),
    role = factor(c("male", "female", "female", "male")),
    x = c(3, 7, 12, 8),
    y = c(10, 14, 20, 24)
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role,
    predictors = x,
    model_types = "dsm",
    dsm_role_order = c("female", "male"),
    temporal_decomposition = "none"
  )

  expect_equal(result$.dy_dsm_role_contrast, c(-0.5, 0.5, 0.5, -0.5))
  expect_equal(result$.dy_x_dyad_mean_gmc, c(-2.5, -2.5, 2.5, 2.5))
  expect_equal(result$.dy_x_within_dyad_diff, rep(4, 4))
  expect_false(".dy_x_within_dyad_dev" %in% names(result))
  expect_false(any(startsWith(names(result), ".dy_y_")))

  meta <- attr(result, "dyadMLM")
  expect_equal(meta$dsm_role_order, c("female", "male"))
  expect_equal(meta$dsm_role_contrast_column, ".dy_dsm_role_contrast")
  expect_equal(
    meta$dsm_predictors,
    tibble::tibble(
      predictor = "x",
      component = "raw",
      lag = 0L,
      source_column = "x",
      mean_column = ".dy_x_dyad_mean_gmc",
      difference_column = ".dy_x_within_dyad_diff",
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

  female_minus_male <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role,
    predictors = x,
    model_types = "dsm",
    dsm_role_order = c("female", "male")
  )
  male_minus_female <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role,
    predictors = x,
    model_types = "dsm",
    dsm_role_order = c("male", "female")
  )

  expect_equal(
    male_minus_female$.dy_x_dyad_mean_gmc,
    female_minus_male$.dy_x_dyad_mean_gmc
  )
  expect_equal(
    male_minus_female$.dy_x_within_dyad_diff,
    -female_minus_male$.dy_x_within_dyad_diff
  )
  expect_equal(
    male_minus_female$.dy_dsm_role_contrast,
    -female_minus_male$.dy_dsm_role_contrast
  )
})

test_that("DSM columns reproduce APIM fixed and random effects", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male"),
    x = c(7, 3, 12, 8)
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role,
    predictors = x,
    model_types = c("apim", "dsm"),
    dsm_role_order = c("female", "male")
  )

  apim <- c(
    alpha_f = 1.2,
    alpha_m = -0.4,
    A_f = 0.8,
    P_f = -0.2,
    A_m = 1.1,
    P_m = 0.3
  )
  mu_x <- unique(
    (result$.dy_x_actor + result$.dy_x_partner) / 2 -
      result$.dy_x_dyad_mean_gmc
  )

  a11 <- (apim[["A_f"]] + apim[["P_f"]] +
    apim[["A_m"]] + apim[["P_m"]]) / 2
  a12 <- (apim[["A_f"]] - apim[["P_f"]] +
    apim[["P_m"]] - apim[["A_m"]]) / 4
  a21 <- apim[["A_f"]] + apim[["P_f"]] -
    apim[["A_m"]] - apim[["P_m"]]
  a22 <- (apim[["A_f"]] + apim[["A_m"]] -
    apim[["P_f"]] - apim[["P_m"]]) / 2

  dsm <- c(
    a10 = (apim[["alpha_f"]] + apim[["alpha_m"]]) / 2 + mu_x * a11,
    a11 = a11,
    a12 = a12,
    a20 = apim[["alpha_f"]] - apim[["alpha_m"]] + mu_x * a21,
    a21 = a21,
    a22 = a22
  )
  expect_equal(
    dsm,
    c(a10 = 7.9, a11 = 1, a12 = 0.05,
      a20 = -4.4, a21 = -0.8, a22 = 0.9)
  )

  apim_prediction <- ifelse(
    result$role == "female",
    apim[["alpha_f"]] + apim[["A_f"]] * result$.dy_x_actor +
      apim[["P_f"]] * result$.dy_x_partner,
    apim[["alpha_m"]] + apim[["A_m"]] * result$.dy_x_actor +
      apim[["P_m"]] * result$.dy_x_partner
  )
  dsm_prediction <-
    dsm[["a10"]] +
    dsm[["a11"]] * result$.dy_x_dyad_mean_gmc +
    dsm[["a12"]] * result$.dy_x_within_dyad_diff +
    result$.dy_dsm_role_contrast * (
      dsm[["a20"]] +
        dsm[["a21"]] * result$.dy_x_dyad_mean_gmc +
        dsm[["a22"]] * result$.dy_x_within_dyad_diff
    )
  expect_equal(dsm_prediction, apim_prediction)

  apim_covariance <- matrix(c(1.44, 0.36, 0.36, 0.81), nrow = 2)
  rotation <- rbind(c(0.5, 0.5), c(1, -1))
  dsm_covariance <- rotation %*% apim_covariance %*% t(rotation)

  expect_equal(
    dsm_covariance,
    matrix(c(0.7425, 0.315, 0.315, 1.53), nrow = 2)
  )
})

test_that("DSM requires both predictor values for dyadic scores", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male"),
    x = c(NA, 3, 12, 8)
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role,
    predictors = x,
    model_types = "dsm",
    dsm_role_order = c("female", "male")
  )

  expect_true(all(is.na(result$.dy_x_dyad_mean_gmc[result$dyad_id == 1])))
  expect_true(all(is.na(result$.dy_x_within_dyad_diff[result$dyad_id == 1])))
  expect_equal(result$.dy_x_within_dyad_diff[result$dyad_id == 2], c(4, 4))
})

test_that("DSM creates a role contrast without predictors", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male")
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role,
    model_types = "dsm",
    dsm_role_order = c("female", "male")
  )

  expect_equal(result$.dy_dsm_role_contrast, c(0.5, -0.5, 0.5, -0.5))
  expect_equal(
    attr(result, "dyadMLM")$dsm_predictors,
    tibble::tibble(
      predictor = character(),
      component = character(),
      lag = integer(),
      source_column = character(),
      mean_column = character(),
      difference_column = character(),
      dyad_decomposition_level = character()
    )
  )

  generated <- dyad_generated_columns(attr(result, "dyadMLM"))
  expect_equal(generated$column, ".dy_dsm_role_contrast")

  printed <- capture.output(print(result, n = 2))
  expect_true(any(grepl("DSM direction: female - male", printed, fixed = TRUE)))
  expect_true(any(grepl(".dy_dsm_role_contrast", printed, fixed = TRUE)))
  expect_false(any(grepl(".dy_{pred}_dyad_mean", printed, fixed = TRUE)))
})

test_that("DSM keeps multiple predictors and metadata aligned", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male"),
    x = c(7, 3, 12, 8)
  )
  data[["stress level"]] <- c(10, 4, 9, 1)

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role,
    predictors = c(x, `stress level`),
    model_types = "dsm",
    dsm_role_order = c("female", "male")
  )

  expect_equal(result$.dy_x_within_dyad_diff, rep(4, 4))
  expect_equal(result$.dy_stress_level_within_dyad_diff, c(6, 6, 8, 8))
  expect_false(any(grepl("within_dyad_dev", names(result), fixed = TRUE)))

  meta <- attr(result, "dyadMLM")$dsm_predictors
  expect_equal(meta$predictor, c("x", "stress level"))
  expect_equal(
    meta$difference_column,
    c(
      ".dy_x_within_dyad_diff",
      ".dy_stress_level_within_dyad_diff"
    )
  )
})

test_that("DSM constructs longitudinal raw, CWP, and CBP scores", {
  data <- data.frame(
    dyad_id = rep(1:2, each = 4),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    role = rep(c("female", "male"), 4),
    time = rep(c(1, 1, 2, 2), 2),
    x = c(4, 2, 8, 4, 10, 6, 14, 8)
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role,
    time = time,
    predictors = x,
    model_types = "dsm",
    dsm_role_order = c("female", "male")
  )

  expect_equal(result$.dy_x_dyad_mean_gmc, rep(c(-4, -1, 1, 4), each = 2))
  expect_equal(result$.dy_x_within_dyad_diff, rep(c(2, 4, 4, 6), each = 2))
  expect_equal(result$.dy_x_cwp_dyad_mean, rep(c(-1.5, -1.5, 1.5, 1.5), 2))
  expect_equal(result$.dy_x_cwp_within_dyad_diff, rep(c(-1, -1, 1, 1), 2))
  expect_equal(result$.dy_x_cbp_dyad_mean, c(rep(-2.5, 4), rep(2.5, 4)))
  expect_equal(result$.dy_x_cbp_within_dyad_diff, c(rep(3, 4), rep(5, 4)))
  expect_equal(result$.dy_dsm_role_contrast, rep(c(0.5, -0.5), 4))
  expect_false(any(grepl("within_dyad_dev", names(result), fixed = TRUE)))

  meta <- attr(result, "dyadMLM")$dsm_predictors
  expect_equal(meta$component, c("raw", "cwp", "cbp"))
  expect_equal(meta$dyad_decomposition_level, c("dyad_time", "dyad_time", "dyad"))
})

test_that("DSM returns missing CWP scores for an incomplete predictor pair", {
  data <- data.frame(
    dyad_id = rep(1:2, each = 4),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    role = rep(c("female", "male"), 4),
    time = rep(c(1, 1, 2, 2), 2),
    x = c(4, NA, 8, 4, 10, 6, 14, 8)
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role,
    time = time,
    predictors = x,
    model_types = "dsm",
    dsm_role_order = c("female", "male")
  )

  incomplete_occasion <- result$dyad_id == 1 & result$time == 1
  complete_occasion <- result$dyad_id == 1 & result$time == 2

  expect_true(all(is.na(result$.dy_x_dyad_mean_gmc[incomplete_occasion])))
  expect_true(all(is.na(result$.dy_x_within_dyad_diff[incomplete_occasion])))
  expect_false(any(is.na(result$.dy_x_dyad_mean_gmc[complete_occasion])))
  expect_false(any(is.na(result$.dy_x_within_dyad_diff[complete_occasion])))
  expect_true(all(is.na(result$.dy_x_cwp_dyad_mean[incomplete_occasion])))
  expect_true(all(is.na(result$.dy_x_cwp_within_dyad_diff[incomplete_occasion])))
  expect_false(any(is.na(result$.dy_x_cwp_dyad_mean[complete_occasion])))
  expect_false(any(is.na(result$.dy_x_cwp_within_dyad_diff[complete_occasion])))
  expect_false(any(is.na(result$.dy_x_cbp_dyad_mean[result$dyad_id == 1])))
  expect_false(any(is.na(result$.dy_x_cbp_within_dyad_diff[result$dyad_id == 1])))
})

test_that("DSM and APIM predictor columns can coexist", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male"),
    x = c(7, 3, 12, 8)
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role,
    predictors = x,
    model_types = c("apim", "dsm"),
    dsm_role_order = c("female", "male")
  )

  expect_true(all(c(
    ".dy_x_actor",
    ".dy_x_partner",
    ".dy_x_dyad_mean_gmc",
    ".dy_x_within_dyad_diff",
    ".dy_dsm_role_contrast"
  ) %in% names(result)))
})

test_that("DSM constructs raw longitudinal predictor scores", {
  data <- data.frame(
    dyad_id = rep(1:2, each = 4),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    role = rep(c("female", "male"), 4),
    time = rep(c(1, 1, 2, 2), 2),
    x = c(4, 2, 8, 4, 10, 6, 14, 8)
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role,
    time = time,
    predictors = x,
    model_types = "dsm",
    dsm_role_order = c("female", "male"),
    temporal_decomposition = "none"
  )

  expect_equal(result$.dy_x_dyad_mean_gmc, rep(c(-4, -1, 1, 4), each = 2))
  expect_equal(result$.dy_x_within_dyad_diff, rep(c(2, 4, 4, 6), each = 2))
  expect_equal(attr(result, "dyadMLM")$dsm_predictors$component, "raw")
  expect_equal(attr(result, "dyadMLM")$dsm_predictors$dyad_decomposition_level, "dyad_time")
})
