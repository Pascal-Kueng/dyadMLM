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

  expect_true(any(grepl(".i_diff              sum-diff contrast; 0 for distinguishable dyads", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_*_raw_actor       raw actor predictor columns", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_*_raw_partner     raw partner predictor columns", printed, fixed = TRUE)))
  expect_false(any(grepl(".i_*_actor           actor", printed, fixed = TRUE)))
  expect_false(any(grepl(".i_*_partner         partner", printed, fixed = TRUE)))
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

  expect_true(any(grepl(".i_*_raw_dyad_mean                  grand-mean centred raw dyad means", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_*_raw_within_dyad_deviation      person deviations from raw dyad means", printed, fixed = TRUE)))
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

  expect_true(any(grepl(".i_*_cwp_dyad_mean                  shared momentary deviations from usual levels", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_*_cwp_within_dyad_deviation      person deviations from shared momentary deviations", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_*_cbp_dyad_mean                  shared usual predictor levels, centred across persons", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_*_cbp_within_dyad_deviation      person differences from dyad usual levels", printed, fixed = TRUE)))
})
