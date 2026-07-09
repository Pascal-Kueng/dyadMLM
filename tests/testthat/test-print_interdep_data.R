test_that("interdep data prints a header before the tibble", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2),
    person_id = c(1, 2, 3, 4),
    role = c("female", "male", "female", "female")
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role
  )

  printed <- capture.output(print(result))

  expect_true(any(grepl("# interdep data", printed, fixed = TRUE)))
  expect_true(any(grepl("# A tibble:", printed, fixed = TRUE)))
})

test_that("interdep data prints dropped incomplete dyads", {
  data <- tibble::tibble(
    dyad_id = c(1, 2, 2, 3, 3),
    person_id = c("A", "B", "C", "D", "E")
  )

  expect_message(
    result <- prepare_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      incomplete_dyads = "drop",
      seed = 123
    ),
    "Dropped 1 incomplete dyad, with ID: 1.",
    fixed = TRUE
  )

  printed <- capture.output(print(result))

  expect_true(any(grepl("# Dropped incomplete dyads:", printed, fixed = TRUE)))
  expect_true(any(grepl("with ID: 1", printed, fixed = TRUE)))
})

test_that("interdep data print describes generated predictor columns", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2),
    person_id = c(1, 2, 3, 4),
    x = c(1, 2, 3, 4)
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    predictors = x,
    seed = 123
  )

  printed <- capture.output(print(result))

  expect_true(any(grepl(".i_diff", printed, fixed = TRUE)))
  expect_true(any(grepl("sum-diff contrast; 0 for distinguishable dyads", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_*_raw_actor", printed, fixed = TRUE)))
  expect_true(any(grepl("APIM raw actor predictors", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_*_raw_partner", printed, fixed = TRUE)))
  expect_true(any(grepl("APIM raw partner predictors", printed, fixed = TRUE)))
  expect_false(any(grepl(".i_*_actor           actor", printed, fixed = TRUE)))
  expect_false(any(grepl(".i_*_partner         partner", printed, fixed = TRUE)))
})

test_that("interdep data print does not describe removed generated model columns", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2),
    person_id = c(1, 2, 3, 4),
    x = c(1, 2, 3, 4)
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    predictors = x,
    seed = 123
  )

  result$.i_x_raw_actor <- NULL
  result$.i_x_raw_partner <- NULL

  printed <- capture.output(print(result))

  expect_false(any(grepl(".i_*_raw_actor/partner", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_diff", printed, fixed = TRUE)))
})

test_that("interdep data print describes cross-sectional DIM columns", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2),
    person_id = c(1, 2, 3, 4),
    x = c(1, 2, 3, 4)
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    predictors = x,
    model_type = "dim",
    seed = 123
  )

  printed <- capture.output(print(result))

  expect_true(any(grepl(".i_*_raw_dyad_mean_gmc", printed, fixed = TRUE)))
  expect_true(any(grepl("DIM raw predictor dyad means, grand-mean centred", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_*_raw_within_dyad_deviation", printed, fixed = TRUE)))
  expect_true(any(grepl("DIM raw predictor within-dyad deviations", printed, fixed = TRUE)))
})

test_that("interdep data print describes longitudinal DIM columns", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c(1, 2, 1, 2, 3, 4, 3, 4),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = c(1, 2, 3, 4, 5, 6, 7, 8)
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    time = time,
    predictors = x,
    model_type = "dim",
    seed = 123
  )

  printed <- capture.output(print(result))

  expect_true(any(grepl(".i_*_cwp_dyad_mean", printed, fixed = TRUE)))
  expect_true(any(grepl("DIM shared momentary predictor deviations", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_*_cwp_within_dyad_deviation", printed, fixed = TRUE)))
  expect_true(any(grepl("DIM person deviations from shared momentary predictor levels", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_*_cbp_dyad_mean", printed, fixed = TRUE)))
  expect_true(any(grepl("DIM shared usual predictor levels", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_*_cbp_within_dyad_deviation", printed, fixed = TRUE)))
  expect_true(any(grepl("DIM person differences from dyad usual predictor levels", printed, fixed = TRUE)))
})

test_that("interdep data print describes undirected DSM outcome columns", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2),
    person_id = c(1, 2, 3, 4),
    y = c(1, 2, 3, 4)
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    outcomes = y,
    model_type = "undirected_dsm",
    seed = 123
  )

  printed <- capture.output(print(result))

  expect_true(any(grepl(".i_*_raw_dyad_mean", printed, fixed = TRUE)))
  expect_true(any(grepl("DSM raw outcome dyad means", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_*_raw_within_dyad_deviation", printed, fixed = TRUE)))
  expect_true(any(grepl("DSM raw outcome within-dyad deviations", printed, fixed = TRUE)))
  expect_false(any(grepl(".i_*_raw_dyad_mean_gmc", printed, fixed = TRUE)))
})
