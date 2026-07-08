test_that("add_actor_partner_columns creates actor and partner columns", {
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
    add_actor_partner_columns()

  expect_equal(result$.i_x_cwp_actor, result$.i_x_cwp)
  expect_equal(result$.i_x_cbp_actor, result$.i_x_cbp)
  expect_equal(result$.i_x_cwp_partner, c(-2, -1, 2, 1, -2, -2, 2, 2))
  expect_equal(result$.i_x_cbp_partner, c(-5, -15, -5, -15, 15, 5, 15, 5))
})

test_that("add_actor_partner_columns preserves rows with missing partner occasions", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "C", "D", "C", "D"),
    time = c(1, 1, 2, 1, 1, 2, 2),
    x = c(1, 10, 3, 20, 30, 24, 34)
  )

  result <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    time = time,
    predictors = x,
    centering = "none"
  ) |>
    infer_dyad_compositions(seed = 123) |>
    center_predictors() |>
    add_actor_partner_columns()

  expect_equal(nrow(result), nrow(data))
  expect_equal(result$x_actor, result$x)
  expect_equal(result$x_partner, c(10, 1, NA, 30, 20, 34, 24))
})

test_that("add_actor_partner_columns matches cross-sectional partners", {
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
    add_actor_partner_columns()

  expect_equal(result$x_actor, result$x)
  expect_equal(result$x_partner, c(10, 1, 30, 20))
})

test_that("add_actor_partner_columns preserves measured missingness", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = c(1, NA, NA, 30)
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
    add_actor_partner_columns()

  expect_equal(result$x_actor, result$x)
  expect_equal(result$x_partner, c(NA, 1, 30, NA))
})

test_that("prepare_interdep_data creates actor and partner columns after dropping invalid dyads", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2, 3, 4, 4),
    person_id = c("A", "B", "C", "D", "E", "F", "G"),
    role = c("female", "male", "female", NA, "female", "male", "male"),
    x = c(1, 10, 20, 30, 40, 50, 60)
  )

  result <- suppressMessages(
    prepare_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      role = role,
      predictors = x,
      centering = "none",
      missing_role = "drop",
      incomplete_dyads = "drop",
      seed = 123
    )
  )

  expect_equal(unique(result$dyad_id), c(1, 4))
  expect_equal(result$x_actor, result$x)
  expect_equal(result$x_partner, c(10, 1, 60, 50))
})
