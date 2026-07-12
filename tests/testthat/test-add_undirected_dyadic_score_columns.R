test_that("undirected DSM retains DIM-style predictor construction", {
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
    model_type = "undirected_dsm",
    temporal_predictor_decomposition = "none",
    seed = 123
  )

  expect_true(".i_x_dyad_mean_gmc" %in% names(result))
  expect_true(".i_x_within_dyad_deviation" %in% names(result))
  expect_false(any(startsWith(names(result), ".i_y_")))
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
    model_type = "undirected_dsm"
  ) |>
    infer_dyad_compositions(seed = 123) |>
    center_predictors()

  expect_error(
    add_undirected_dyadic_score_columns(prepared),
    "female_x_male \\(distinguishable, n_dyads = 2\\)"
  )
})
