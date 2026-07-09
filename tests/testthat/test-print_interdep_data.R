added_column_lines <- function(printed) {
  printed[startsWith(printed, "#   ")]
}

added_column_count <- function(lines, column_pattern) {
  sum(startsWith(lines, paste0("#   ", column_pattern, " ")))
}

added_column_index <- function(lines, column_pattern) {
  match(TRUE, startsWith(lines, paste0("#   ", column_pattern, " ")))
}

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
  expect_true(any(grepl(
    "sum-diff contrast for exchangeable dyads; 0 for distinguishable dyads",
    printed,
    fixed = TRUE
  )))
  expect_true(any(grepl(".i_*_raw_actor", printed, fixed = TRUE)))
  expect_true(any(grepl("APIM raw actor predictors", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_*_raw_partner", printed, fixed = TRUE)))
  expect_true(any(grepl("APIM raw partner predictors", printed, fixed = TRUE)))
  expect_false(any(grepl(".i_*_actor           actor", printed, fixed = TRUE)))
  expect_false(any(grepl(".i_*_partner         partner", printed, fixed = TRUE)))
})

test_that("interdep data print does not describe removed generated model column families", {
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

  printed <- capture.output(print(result))

  expect_false(any(grepl(".i_*_raw_actor", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_*_raw_partner", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_diff", printed, fixed = TRUE)))
})

test_that("interdep data print describes longitudinal APIM columns", {
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
    seed = 123
  )

  printed <- capture.output(print(result))

  expect_true(any(grepl(".i_*_cwp", printed, fixed = TRUE)))
  expect_true(any(grepl("within-person temporal predictor components", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_*_cbp", printed, fixed = TRUE)))
  expect_true(any(grepl(
    "between-person temporal predictor components, centred around grand mean of person means",
    printed,
    fixed = TRUE
  )))
  expect_true(any(grepl(".i_*_cwp_actor", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_*_cwp_partner", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_*_cbp_actor", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_*_cbp_partner", printed, fixed = TRUE)))
})

test_that("interdep data print orders generated column descriptions", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c(1, 2, 1, 2, 3, 4, 3, 4),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = c(1, 2, 3, 4, 5, 6, 7, 8),
    y = c(2, 3, 4, 5, 6, 7, 8, 9)
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    time = time,
    predictors = x,
    outcomes = y,
    model_type = c("apim", "undirected_dsm"),
    seed = 123
  )

  lines <- added_column_lines(capture.output(print(result)))

  expect_lt(added_column_index(lines, ".i_*_cwp"), added_column_index(lines, ".i_*_cwp_actor"))
  expect_lt(added_column_index(lines, ".i_*_cbp"), added_column_index(lines, ".i_*_cbp_actor"))
  expect_lt(added_column_index(lines, ".i_*_cbp_partner"), added_column_index(lines, ".i_*_cwp_dyad_mean"))
  expect_lt(added_column_index(lines, ".i_*_cbp_within_dyad_deviation"), added_column_index(lines, ".i_*_raw_dyad_mean"))
})

test_that("interdep data print collapses repeated generated column types", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c(1, 2, 1, 2, 3, 4, 3, 4),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = c(1, 2, 3, 4, 5, 6, 7, 8),
    z = c(8, 7, 6, 5, 4, 3, 2, 1)
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    time = time,
    predictors = c(x, z),
    seed = 123
  )

  lines <- added_column_lines(capture.output(print(result)))

  expect_equal(added_column_count(lines, ".i_*_cwp"), 1)
  expect_equal(added_column_count(lines, ".i_*_cbp"), 1)
  expect_equal(added_column_count(lines, ".i_*_cwp_actor"), 1)
  expect_equal(added_column_count(lines, ".i_*_cwp_partner"), 1)
  expect_equal(added_column_count(lines, ".i_*_cbp_actor"), 1)
  expect_equal(added_column_count(lines, ".i_*_cbp_partner"), 1)
})

test_that("interdep data print does not describe removed temporal source columns", {
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
    seed = 123
  )

  result$.i_x_cwp <- NULL

  lines <- added_column_lines(capture.output(print(result)))

  expect_equal(added_column_count(lines, ".i_*_cwp"), 0)
  expect_equal(added_column_count(lines, ".i_*_cbp"), 1)
  expect_equal(added_column_count(lines, ".i_*_cwp_actor"), 1)
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
  expect_true(any(grepl(
    "DIM shared usual predictor levels, centred across persons",
    printed,
    fixed = TRUE
  )))
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

test_that("interdep data print describes longitudinal undirected DSM columns", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c(1, 2, 1, 2, 3, 4, 3, 4),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = c(1, 2, 3, 4, 5, 6, 7, 8),
    y = c(2, 3, 4, 5, 6, 7, 8, 9)
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    time = time,
    predictors = x,
    outcomes = y,
    model_type = "undirected_dsm",
    seed = 123
  )

  printed <- capture.output(print(result))

  expect_true(any(grepl(".i_*_cwp", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_*_cbp", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_*_cwp_dyad_mean", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_*_cbp_dyad_mean", printed, fixed = TRUE)))
  expect_true(any(grepl("DSM raw outcome dyad means", printed, fixed = TRUE)))
  expect_true(any(grepl("DSM raw outcome within-dyad deviations", printed, fixed = TRUE)))
})

test_that("interdep data print combines APIM and DIM column descriptions", {
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
    model_type = c("apim", "dim"),
    seed = 123
  )

  printed <- capture.output(print(result))

  expect_true(any(grepl(".i_*_raw_actor", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_*_raw_partner", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_*_raw_dyad_mean_gmc", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_*_raw_within_dyad_deviation", printed, fixed = TRUE)))
})

test_that("interdep data print combines APIM predictors and DSM outcomes", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2),
    person_id = c(1, 2, 3, 4),
    x = c(1, 2, 3, 4),
    y = c(5, 6, 7, 8)
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    predictors = x,
    outcomes = y,
    model_type = c("apim", "undirected_dsm"),
    seed = 123
  )

  printed <- capture.output(print(result))

  expect_true(any(grepl(".i_*_raw_actor", printed, fixed = TRUE)))
  expect_true(any(grepl("APIM raw actor predictors", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_*_raw_dyad_mean", printed, fixed = TRUE)))
  expect_true(any(grepl("DSM raw outcome dyad means", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_*_raw_within_dyad_deviation", printed, fixed = TRUE)))
  expect_true(any(grepl("DSM raw outcome within-dyad deviations", printed, fixed = TRUE)))
})

test_that("interdep data print describes dropped dyads with missing role information", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2, 3, 3),
    person_id = c("A", "B", "C", "D", "E", "F"),
    role = c("female", NA, "female", "male", "female", "male")
  )

  expect_message(
    result <- prepare_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      role = role,
      missing_role = "drop",
      seed = 123
    ),
    "Dropped 1 dyad with incomplete role information, with ID: 1.",
    fixed = TRUE
  )

  printed <- capture.output(print(result))

  expect_true(any(grepl(
    "# Dropped dyads with incomplete role information:",
    printed,
    fixed = TRUE
  )))
  expect_true(any(grepl("with ID: 1", printed, fixed = TRUE)))
})

test_that("interdep data print truncates many dropped incomplete dyad IDs", {
  data <- tibble::tibble(
    dyad_id = c(1:14, 15, 15, 16, 16),
    person_id = c(paste0("single", 1:14), "A", "B", "C", "D")
  )

  suppressMessages(
    result <- prepare_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      incomplete_dyads = "drop",
      seed = 123
    )
  )

  printed <- capture.output(print(result))

  expect_true(any(grepl("# Dropped incomplete dyads:", printed, fixed = TRUE)))
  expect_true(any(grepl("14 dyads, with IDs: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, ... and 4 more", printed, fixed = TRUE)))
})

test_that("interdep data print includes role and time in structure line", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    role = c("female", "male", "female", "male", "female", "male", "female", "male"),
    day = c(1, 1, 2, 2, 1, 1, 2, 2)
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role,
    time = day,
    seed = 123
  )

  printed <- capture.output(print(result))

  expect_true(any(grepl(
    "# Structure: group = dyad_id, member = person_id, role = role, time = day",
    printed,
    fixed = TRUE
  )))
})

test_that("interdep data print describes multiple dyad compositions", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2, 3, 3),
    person_id = c("A", "B", "C", "D", "E", "F"),
    role = c("female", "male", "female", "female", "male", "male")
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role,
    seed = 123
  )

  printed <- capture.output(print(result))

  expect_true(any(grepl("# Dyad compositions:", printed, fixed = TRUE)))
  expect_true(any(grepl("female_x_male\\s+distinguishable\\s+1 dyads", printed)))
  expect_true(any(grepl("female_x_female\\s+exchangeable\\s+1 dyads", printed)))
  expect_true(any(grepl("male_x_male\\s+exchangeable\\s+1 dyads", printed)))
})
