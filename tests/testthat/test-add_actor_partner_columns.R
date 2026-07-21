test_that("add_actor_partner_columns creates actor and partner columns", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = c(1, 10, 3, 14, 20, 30, 24, 34)
  )

  result <- validate_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    time = time,
    predictors = x
  ) |>
    infer_dyad_compositions(seed = 123) |>
    center_predictors() |>
    add_actor_partner_columns()

  expect_equal(result$.dy_x_actor, result$x)
  expect_equal(result$.dy_x_cwp_actor, result$.dy_x_cwp)
  expect_equal(result$.dy_x_cbp_actor, result$.dy_x_cbp)
  expect_equal(result$.dy_x_partner, c(10, 1, 14, 3, 30, 20, 34, 24))
  expect_equal(result$.dy_x_cwp_partner, c(-2, -1, 2, 1, -2, -2, 2, 2))
  expect_equal(result$.dy_x_cbp_partner, c(-5, -15, -5, -15, 15, 5, 15, 5))
  expect_equal(
    attr(result, "dyadMLM")$apim_predictors,
    tibble::tibble(
      predictor = c("x", "x", "x"),
      component = c("raw", "cwp", "cbp"),
      lag = c(0L, 0L, 0L),
      source_column = c("x", ".dy_x_cwp", ".dy_x_cbp"),
      actor_column = c(".dy_x_actor", ".dy_x_cwp_actor", ".dy_x_cbp_actor"),
      partner_column = c(".dy_x_partner", ".dy_x_cwp_partner", ".dy_x_cbp_partner")
    )
  )
  expect_equal(
    attr(result, "dyadMLM")$temporal_decompositions$component,
    c("raw", "cwp", "cbp")
  )
})

test_that("longitudinal APIM and DIM predictor columns can coexist", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = c(1, 10, 3, 14, 20, 30, 24, 34)
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    time = time,
    predictors = x,
    model_types = c("apim", "dim"),
    seed = 123
  )

  expect_true(all(c(
    ".dy_x_actor",
    ".dy_x_partner",
    ".dy_x_cwp_actor",
    ".dy_x_cwp_partner",
    ".dy_x_cbp_actor",
    ".dy_x_cbp_partner",
    ".dy_x_dyad_mean_gmc",
    ".dy_x_within_dyad_dev",
    ".dy_x_cwp_dyad_mean",
    ".dy_x_cwp_within_dyad_dev",
    ".dy_x_cbp_dyad_mean",
    ".dy_x_cbp_within_dyad_dev"
  ) %in% names(result)))
  expect_equal(
    attr(result, "dyadMLM")$dim_predictors$component,
    c("raw", "cwp", "cbp")
  )
})

test_that("add_actor_partner_columns preserves rows with missing partner occasions", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "C", "D", "C", "D"),
    time = c(1, 1, 2, 1, 1, 2, 2),
    x = c(1, 10, 3, 20, 30, 24, 34)
  )

  result <- validate_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    time = time,
    predictors = x,
    temporal_decomposition = "none"
  ) |>
    infer_dyad_compositions(seed = 123) |>
    center_predictors() |>
    add_actor_partner_columns()

  expect_equal(nrow(result), nrow(data))
  expect_equal(result$.dy_x_actor, result$x)
  expect_equal(result$.dy_x_partner, c(10, 1, NA, 30, 20, 34, 24))
  expect_false("x_actor" %in% names(result))
  expect_false("x_partner" %in% names(result))
  expect_equal(
    attr(result, "dyadMLM")$apim_predictors,
    tibble::tibble(
      predictor = "x",
      component = "raw",
      lag = 0L,
      source_column = "x",
      actor_column = ".dy_x_actor",
      partner_column = ".dy_x_partner"
    )
  )
})

test_that("add_actor_partner_columns matches cross-sectional partners", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = c(1, 10, 20, 30)
  )

  result <- validate_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    predictors = x,
    temporal_decomposition = "none"
  ) |>
    infer_dyad_compositions(seed = 123) |>
    center_predictors() |>
    add_actor_partner_columns()

  expect_equal(result$.dy_x_actor, result$x)
  expect_equal(result$.dy_x_partner, c(10, 1, 30, 20))
})

test_that("add_actor_partner_columns uses generated names for raw predictors", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    check.names = FALSE
  )
  data[["stress level"]] <- c(1, 10, 20, 30)

  result <- validate_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    predictors = `stress level`,
    temporal_decomposition = "none"
  ) |>
    infer_dyad_compositions(seed = 123) |>
    center_predictors() |>
    add_actor_partner_columns()

  expect_equal(result$.dy_stress_level_actor, result[["stress level"]])
  expect_equal(result$.dy_stress_level_partner, c(10, 1, 30, 20))
  expect_equal(
    attr(result, "dyadMLM")$apim_predictors,
    tibble::tibble(
      predictor = "stress level",
      component = "raw",
      lag = 0L,
      source_column = "stress level",
      actor_column = ".dy_stress_level_actor",
      partner_column = ".dy_stress_level_partner"
    )
  )
})

test_that("add_actor_partner_columns stores empty metadata without predictors", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  result <- validate_dyad_data(data, dyad = dyad_id, member = person_id) |>
    infer_dyad_compositions(seed = 123) |>
    center_predictors() |>
    add_actor_partner_columns()

  expect_equal(
    attr(result, "dyadMLM")$apim_predictors,
    tibble::tibble(
      predictor = character(),
      component = character(),
      lag = integer(),
      source_column = character(),
      actor_column = character(),
      partner_column = character()
    )
  )
})

test_that("add_actor_partner_columns preserves measured missingness", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = c(1, NA, NA, 30)
  )

  result <- validate_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    predictors = x,
    temporal_decomposition = "none"
  ) |>
    infer_dyad_compositions(seed = 123) |>
    center_predictors() |>
    add_actor_partner_columns()

  expect_equal(result$.dy_x_actor, result$x)
  expect_equal(result$.dy_x_partner, c(NA, 1, 30, NA))
})

test_that("prepare_dyad_data creates actor and partner columns after dropping invalid dyads", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2, 3, 4, 4),
    person_id = c("A", "B", "C", "D", "E", "F", "G"),
    role = c("female", "male", "female", NA, "female", "male", "male"),
    x = c(1, 10, 20, 30, 40, 50, 60)
  )

  result <- suppressMessages(
    prepare_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      role = role,
      predictors = x,
      temporal_decomposition = "none",
      missing_role = "drop",
      incomplete_dyads = "drop",
      seed = 123
    )
  )

  expect_equal(unique(result$dyad_id), c(1, 4))
  expect_equal(result$.dy_x_actor, result$x)
  expect_equal(result$.dy_x_partner, c(10, 1, 60, 50))
})
