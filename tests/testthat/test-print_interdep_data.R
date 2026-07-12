added_column_lines <- function(printed) {
  printed[startsWith(printed, "#   ")]
}

added_column_count <- function(lines, column_pattern) {
  sum(startsWith(lines, paste0("#   ", column_pattern, " ")))
}

added_column_index <- function(lines, column_pattern) {
  match(TRUE, startsWith(lines, paste0("#   ", column_pattern, " ")))
}

capture_wide_print <- function(x) {
  old_options <- options(width = 1000)
  on.exit(options(old_options), add = TRUE)
  capture.output(print(x))
}

expect_added_column_description <- function(printed, column_pattern, description) {
  expect_true(any(grepl(column_pattern, printed, fixed = TRUE)))
  expect_true(any(grepl(description, printed, fixed = TRUE)))
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

  printed <- capture_wide_print(result)

  expect_true(any(grepl("# interdep data", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_is_{comp-role}", printed, fixed = TRUE)))
  expect_true(any(grepl("# A tibble:", printed, fixed = TRUE)))
})

test_that("interdep data header and structure wrap to console width", {
  old_options <- options(width = 46)
  on.exit(options(old_options), add = TRUE)

  data <- tibble::tibble(
    very_long_dyad_identifier = c(1, 1, 2, 2),
    very_long_member_identifier = c(1, 2, 3, 4),
    very_long_role_identifier = c("female", "male", "female", "female")
  )

  result <- prepare_interdep_data(
    data,
    group = very_long_dyad_identifier,
    member = very_long_member_identifier,
    role = very_long_role_identifier,
    seed = 123
  )

  printed <- capture.output(print(result, n = 0))

  expect_true(any(grepl("# Rows: 4 | Dyads: 2", printed, fixed = TRUE)))
  expect_true(any(grepl("#       Intensive longitudinal: no", printed, fixed = TRUE)))
  expect_true(any(grepl("# Structure:", printed, fixed = TRUE)))
  expect_true(any(grepl("#   group = very_long_dyad_identifier", printed, fixed = TRUE)))
  expect_true(any(grepl("#   member = very_long_member_identifier", printed, fixed = TRUE)))
  expect_true(any(grepl("#   role = very_long_role_identifier", printed, fixed = TRUE)))
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

  printed <- capture_wide_print(result)

  expect_true(any(grepl("# Dropped incomplete dyads:", printed, fixed = TRUE)))
  expect_true(any(grepl("with ID: 1", printed, fixed = TRUE)))
})

test_that("comment field label styling is limited to the label", {
  old_options <- options(cli.num_colors = 256)
  on.exit(options(old_options), add = TRUE)

  printed <- capture.output(
    print_wrapped_comment_fields(
      label = "Dropped incomplete dyads",
      fields = "1 dyad, with ID: 1",
      label_style = "negative"
    )
  )

  expect_equal(
    printed,
    paste0(
      "# ",
      pillar::style_neg("Dropped incomplete dyads:"),
      " 1 dyad, with ID: 1"
    )
  )
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

  printed <- capture_wide_print(result)

  expect_false(any(grepl("sum-diff contrast for exchangeable dyads; 0 for distinguishable dyads", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_diff_{comp}", printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    ".i_diff_{comp}",
    "composition-specific sum-diff contrasts with arbitrary direction; 0 for distinguishable dyads or other exchangeable compositions"
  )
  expect_true(any(grepl(".i_{pred}_raw_actor", printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    ".i_{pred}_raw_actor",
    "APIM actor predictor: actor's original predictor values"
  )
  expect_true(any(grepl(".i_{pred}_raw_partner", printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    ".i_{pred}_raw_partner",
    "APIM partner predictor: partner's original predictor values"
  )
  expect_false(any(grepl(".i_{pred}_actor           actor", printed, fixed = TRUE)))
  expect_false(any(grepl(".i_{pred}_partner         partner", printed, fixed = TRUE)))
})

test_that("added column descriptions align and wrap to console width", {
  old_options <- options(width = 60)
  on.exit(options(old_options), add = TRUE)

  printed <- capture.output(print_added_columns(tibble::tibble(
    column_pattern = c(".short", ".much_longer_column_name"),
    description = c(
      "short description",
      "long description that wraps across multiple lines"
    )
  )))

  description_column <- as.integer(regexpr("short description", printed[[1]], fixed = TRUE))

  expect_equal(as.integer(regexpr("long description", printed[[2]], fixed = TRUE)), description_column)
  expect_equal(as.integer(regexpr("across", printed[[3]], fixed = TRUE)), description_column)
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

  printed <- capture_wide_print(result)

  expect_false(any(grepl(".i_{pred}_raw_actor", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_{pred}_raw_partner", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_diff_{comp}", printed, fixed = TRUE)))
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

  printed <- capture_wide_print(result)

  expect_true(any(grepl(".i_{pred}_cwp", printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    ".i_{pred}_cwp",
    "within-person predictor: momentary deviations from each person's usual level"
  )
  expect_true(any(grepl(".i_{pred}_cbp", printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    ".i_{pred}_cbp",
    "between-person predictor: stable differences from the average person's usual level"
  )
  expect_true(any(grepl(".i_{pred}_cwp_actor", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_{pred}_cwp_partner", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_{pred}_cbp_actor", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_{pred}_cbp_partner", printed, fixed = TRUE)))
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

  lines <- added_column_lines(capture_wide_print(result))

  expect_lt(added_column_index(lines, ".i_{pred}_cwp"), added_column_index(lines, ".i_{pred}_cwp_actor"))
  expect_lt(added_column_index(lines, ".i_{pred}_cbp"), added_column_index(lines, ".i_{pred}_cbp_actor"))
  expect_lt(added_column_index(lines, ".i_{pred}_cbp_partner"), added_column_index(lines, ".i_{pred}_cwp_dyad_mean"))
  expect_lt(added_column_index(lines, ".i_{pred}_cbp_within_dyad_deviation"), added_column_index(lines, ".i_{out}_raw_dyad_mean"))
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

  lines <- added_column_lines(capture_wide_print(result))

  expect_equal(added_column_count(lines, ".i_{pred}_cwp"), 1)
  expect_equal(added_column_count(lines, ".i_{pred}_cbp"), 1)
  expect_equal(added_column_count(lines, ".i_{pred}_cwp_actor"), 1)
  expect_equal(added_column_count(lines, ".i_{pred}_cwp_partner"), 1)
  expect_equal(added_column_count(lines, ".i_{pred}_cbp_actor"), 1)
  expect_equal(added_column_count(lines, ".i_{pred}_cbp_partner"), 1)
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

  lines <- added_column_lines(capture_wide_print(result))

  expect_equal(added_column_count(lines, ".i_{pred}_cwp"), 0)
  expect_equal(added_column_count(lines, ".i_{pred}_cbp"), 1)
  expect_equal(added_column_count(lines, ".i_{pred}_cwp_actor"), 1)
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

  printed <- capture_wide_print(result)

  expect_true(any(grepl(".i_{pred}_raw_dyad_mean_gmc", printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    ".i_{pred}_raw_dyad_mean_gmc",
    "DIM dyad-mean predictor: dyad's average predictor level, grand-mean centered"
  )
  expect_true(any(grepl(".i_{pred}_raw_within_dyad_deviation", printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    ".i_{pred}_raw_within_dyad_deviation",
    "DIM within-dyad predictor deviation: person's difference from the dyad average"
  )
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

  printed <- capture_wide_print(result)

  expect_true(any(grepl(".i_{pred}_cwp_dyad_mean", printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    ".i_{pred}_cwp_dyad_mean",
    "DIM within-person dyad-mean predictor: shared momentary deviations in the dyad"
  )
  expect_true(any(grepl(".i_{pred}_cwp_within_dyad_deviation", printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    ".i_{pred}_cwp_within_dyad_deviation",
    "DIM within-person within-dyad predictor deviation: person's momentary deviation from the dyad average"
  )
  expect_true(any(grepl(".i_{pred}_cbp_dyad_mean", printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    ".i_{pred}_cbp_dyad_mean",
    "DIM between-person dyad-mean predictor: dyad's stable usual level, grand-mean centered"
  )
  expect_true(any(grepl(".i_{pred}_cbp_within_dyad_deviation", printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    ".i_{pred}_cbp_within_dyad_deviation",
    "DIM between-person within-dyad predictor deviation: person's stable difference from the dyad's usual level"
  )
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

  printed <- capture_wide_print(result)

  expect_true(any(grepl(".i_{out}_raw_dyad_mean", printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    ".i_{out}_raw_dyad_mean",
    "DSM dyad-mean outcome: dyad's average outcome level"
  )
  expect_true(any(grepl(".i_{out}_raw_within_dyad_deviation", printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    ".i_{out}_raw_within_dyad_deviation",
    "DSM within-dyad outcome deviation: person's difference from the dyad average"
  )
  expect_false(any(grepl(".i_{pred}_raw_dyad_mean_gmc", printed, fixed = TRUE)))
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

  printed <- capture_wide_print(result)

  expect_true(any(grepl(".i_{pred}_cwp", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_{pred}_cbp", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_{pred}_cwp_dyad_mean", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_{pred}_cbp_dyad_mean", printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    ".i_{out}_raw_dyad_mean",
    "DSM dyad-mean outcome: dyad's average outcome level"
  )
  expect_added_column_description(
    printed,
    ".i_{out}_raw_within_dyad_deviation",
    "DSM within-dyad outcome deviation: person's difference from the dyad average"
  )
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

  printed <- capture_wide_print(result)

  expect_true(any(grepl(".i_{pred}_raw_actor", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_{pred}_raw_partner", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_{pred}_raw_dyad_mean_gmc", printed, fixed = TRUE)))
  expect_true(any(grepl(".i_{pred}_raw_within_dyad_deviation", printed, fixed = TRUE)))
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

  printed <- capture_wide_print(result)

  expect_true(any(grepl(".i_{pred}_raw_actor", printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    ".i_{pred}_raw_actor",
    "APIM actor predictor: actor's original predictor values"
  )
  expect_true(any(grepl(".i_{out}_raw_dyad_mean", printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    ".i_{out}_raw_dyad_mean",
    "DSM dyad-mean outcome: dyad's average outcome level"
  )
  expect_true(any(grepl(".i_{out}_raw_within_dyad_deviation", printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    ".i_{out}_raw_within_dyad_deviation",
    "DSM within-dyad outcome deviation: person's difference from the dyad average"
  )
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

  printed <- capture_wide_print(result)

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

  printed <- capture_wide_print(result)

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

  printed <- capture_wide_print(result)

  expect_true(any(grepl(
    "# Structure: group = dyad_id, member = person_id, role = role, time = day",
    printed,
    fixed = TRUE
  )))
})

test_that("interdep data print describes mixed dyad types", {
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

  printed <- capture_wide_print(result)

  expect_true(any(grepl("# Dyad compositions:", printed, fixed = TRUE)))
  expect_true(any(grepl("female_x_male\\s+distinguishable\\s+1 dyad", printed)))
  expect_true(any(grepl("female_x_female\\s+exchangeable\\s+1 dyad", printed)))
  expect_true(any(grepl("male_x_male\\s+exchangeable\\s+1 dyad", printed)))
})

test_that("interdep data print marks dyad types set by user", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male")
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role,
    set_exchangeable_compositions = "female-male",
    seed = 123
  )

  printed <- capture_wide_print(result)

  expect_true(any(grepl(
    "female_x_male\\s+exchangeable \\(set by user\\)\\s+2 dyads",
    printed
  )))
})

test_that("interdep data print describes pooled compositions", {
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
    set_exchangeable_compositions = "female-male",
    pool_compositions = list(ss = c("female-female", "male-male")),
    seed = 123
  )

  printed <- capture_wide_print(result)

  expect_true(any(grepl(
    "ss \\(pooled\\)\\s+exchangeable\\s+2 dyads",
    printed
  )))
  expect_true(any(grepl("#   female_x_female", printed, fixed = TRUE)))
  expect_true(any(grepl("#   male_x_male", printed, fixed = TRUE)))

  composition_lines <- printed[grepl("female_x_male|ss \\(pooled\\)", printed)]
  exchangeable_start <- regexpr("exchangeable", composition_lines)
  expect_equal(exchangeable_start[[1]], exchangeable_start[[2]])
})
