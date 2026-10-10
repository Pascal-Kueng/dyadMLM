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

expect_printed <- function(printed, text) {
  expect_match(printed, text, fixed = TRUE, all = FALSE)
}

prepare_partner_data <- function(data, ...) {
  suppressMessages(prepare_dyad_data(data, dyad = dyad_id, member = person_id, seed = 123, ...))
}

test_that("dyadMLM data prints a header before the tibble", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2),
    person_id = c(1, 2, 3, 4),
    role = c("female", "male", "female", "female")
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role
  )

  printed <- capture_wide_print(result)

  expect_true(any(grepl("# dyadMLM data", printed, fixed = TRUE)))
  expect_true(any(grepl(".is_{comp-role}", printed, fixed = TRUE)))
  expect_true(any(grepl("# A tibble:", printed, fixed = TRUE)))
})

test_that("dyadMLM data header and structure wrap to console width", {
  old_options <- options(width = 46)
  on.exit(options(old_options), add = TRUE)

  data <- tibble::tibble(
    very_long_dyad_identifier = c(1, 1, 2, 2),
    very_long_member_identifier = c(1, 2, 3, 4),
    very_long_role_identifier = c("female", "male", "female", "female")
  )

  result <- prepare_dyad_data(
    data,
    dyad = very_long_dyad_identifier,
    member = very_long_member_identifier,
    role = very_long_role_identifier,
    seed = 123
  )

  printed <- capture.output(print(result, n = 0))

  expect_true(any(grepl("# Rows: 4 | Dyads: 2", printed, fixed = TRUE)))
  expect_true(any(grepl("#       Intensive longitudinal: no", printed, fixed = TRUE)))
  expect_true(any(grepl("# Structure:", printed, fixed = TRUE)))
  expect_true(any(grepl("#   dyad = very_long_dyad_identifier", printed, fixed = TRUE)))
  expect_true(any(grepl("#   member = very_long_member_identifier", printed, fixed = TRUE)))
  expect_true(any(grepl("#   role = very_long_role_identifier", printed, fixed = TRUE)))
})

test_that("dyadMLM data prints current dyad and composition counts", {
  data <- tibble::tibble(
    dyad_id = rep(1:3, each = 2),
    person_id = 1:6,
    role = c("female", "male", "female", "male", "female", "female")
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role
  )
  filtered_result <- dplyr::filter(result, .data$dyad_id != 2)
  result_before_printing <- filtered_result

  printed <- capture_wide_print(filtered_result)
  female_male_line <- printed[grepl("^# female_x_male", printed)]

  expect_true(any(grepl("# Rows: 4 | Dyads: 2", printed, fixed = TRUE)))
  expect_length(female_male_line, 1L)
  expect_match(female_male_line, "distinguishable +1 dyad$")
  expect_identical(filtered_result, result_before_printing)

  base_filtered_result <- result[result$dyad_id != 3, ]
  base_filtered_print <- capture_wide_print(base_filtered_result)

  expect_true(any(grepl("# Rows: 4 | Dyads: 2", base_filtered_print, fixed = TRUE)))
  expect_false(any(grepl("^# female_x_female", base_filtered_print)))
})

test_that("dyadMLM data identifies unavailable current summaries", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2),
    person_id = 1:4
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    seed = 123
  )

  result_with_missing_dyad <- result
  result_with_missing_dyad$dyad_id[result_with_missing_dyad$dyad_id == 2] <- NA
  printed_with_missing_dyad <- capture_wide_print(result_with_missing_dyad)
  composition_line <- printed_with_missing_dyad[
    grepl("^# assumed_exchangeable", printed_with_missing_dyad)
  ]

  expect_true(any(grepl("# Rows: 4 | Dyads: 1", printed_with_missing_dyad, fixed = TRUE)))
  expect_length(composition_line, 1L)
  expect_match(composition_line, "exchangeable +1 dyad$")

  result_without_composition <- result
  result_without_composition[[dyad_composition_col]] <- NULL
  printed_without_composition <- capture_wide_print(result_without_composition)

  expect_true(any(grepl("# Rows: 4 | Dyads: 2", printed_without_composition, fixed = TRUE)))
  expect_true(any(grepl(
    "# Dyad compositions: unavailable because required columns are missing",
    printed_without_composition,
    fixed = TRUE
  )))

  result_without_dyad <- result
  result_without_dyad$dyad_id <- NULL
  printed_without_dyad <- capture_wide_print(result_without_dyad)

  expect_true(any(grepl("# Rows: 4 | Dyads: unavailable", printed_without_dyad, fixed = TRUE)))
  expect_true(any(grepl(
    "# Dyad compositions: unavailable because required columns are missing",
    printed_without_dyad,
    fixed = TRUE
  )))
})

test_that("dyadMLM data prints dropped incomplete dyads", {
  data <- tibble::tibble(
    dyad_id = c(1, 2, 2, 3, 3),
    person_id = c("A", "B", "C", "D", "E")
  )

  expect_message(
    result <- prepare_dyad_data(
      data,
      dyad = dyad_id,
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

test_that("dyadMLM data print describes generated predictor columns", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2),
    person_id = c(1, 2, 3, 4),
    x = c(1, 2, 3, 4)
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    predictors = x,
    seed = 123
  )

  printed <- capture_wide_print(result)
  short_indicator_pattern <- paste0(dyad_retained_prefix, "is_exchangeable")
  short_member_contrast_pattern <- paste0(
    dyad_retained_prefix,
    "member_contrast_arbitrary"
  )

  expect_false(any(grepl("sum-diff contrast for exchangeable dyads; 0 for distinguishable dyads", printed, fixed = TRUE)))
  expect_true(any(grepl(short_indicator_pattern, printed, fixed = TRUE)))
  expect_false(any(grepl(".is_{role}", printed, fixed = TRUE)))
  expect_true(any(grepl(short_member_contrast_pattern, printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    short_member_contrast_pattern,
    paste(
      "composition-specific member contrasts coded -1/+1 in arbitrary",
      "direction for exchangeability-constrained random effects. Values are",
      "0 for other compositions"
    )
  )
  expect_true(any(grepl(".{pred}_actor", printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    ".{pred}_actor",
    "APIM actor predictor: actor's original predictor values"
  )
  expect_true(any(grepl(".{pred}_partner", printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    ".{pred}_partner",
    "APIM partner predictor: partner's original predictor values"
  )
  expect_false(any(grepl(".{pred}_actor           actor", printed, fixed = TRUE)))
  expect_false(any(grepl(".{pred}_partner         partner", printed, fixed = TRUE)))
})

test_that("dyadMLM data print retains the short distinguishable indicator pattern", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2),
    person_id = c(1, 2, 3, 4),
    role = rep(c("female", "male"), 2)
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role
  )

  printed <- capture_wide_print(result)

  expect_true(any(grepl(".is_{role}", printed, fixed = TRUE)))
  expect_false(any(grepl(".is_exchangeable", printed, fixed = TRUE)))
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

test_that("dyadMLM data print does not describe removed generated model column families", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2),
    person_id = c(1, 2, 3, 4),
    x = c(1, 2, 3, 4)
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    predictors = x,
    seed = 123
  )

  result$.x_actor <- NULL

  printed <- capture_wide_print(result)
  short_member_contrast_pattern <- paste0(
    dyad_retained_prefix,
    "member_contrast_arbitrary"
  )

  expect_false(any(grepl(".{pred}_actor", printed, fixed = TRUE)))
  expect_true(any(grepl(".{pred}_partner", printed, fixed = TRUE)))
  expect_true(any(grepl(
    short_member_contrast_pattern,
    printed,
    fixed = TRUE
  )))
})

test_that("dyadMLM data print describes longitudinal APIM columns", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c(1, 2, 1, 2, 3, 4, 3, 4),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = c(1, 2, 3, 4, 5, 6, 7, 8)
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    time = time,
    predictors = x,
    seed = 123
  )

  printed <- capture_wide_print(result)

  expect_true(any(grepl(".{pred}_cwp", printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    ".{pred}_cwp",
    "within-person predictor: momentary deviations from each person's usual level"
  )
  expect_true(any(grepl(".{pred}_cbp", printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    ".{pred}_cbp",
    "between-person predictor: stable differences from the average person's usual level"
  )
  expect_true(any(grepl(".{pred}_actor", printed, fixed = TRUE)))
  expect_true(any(grepl(".{pred}_partner", printed, fixed = TRUE)))
  expect_true(any(grepl(".{pred}_cwp_actor", printed, fixed = TRUE)))
  expect_true(any(grepl(".{pred}_cwp_partner", printed, fixed = TRUE)))
  expect_true(any(grepl(".{pred}_cbp_actor", printed, fixed = TRUE)))
  expect_true(any(grepl(".{pred}_cbp_partner", printed, fixed = TRUE)))
})

test_that("dyadMLM data print reports missing partner data", {
  complete <- tibble::tibble(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c(1, 2, 1, 2, 3, 4, 3, 4),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = c(1, 2, 3, 4, 5, 6, 7, 8)
  )
  prepare <- function(data, ...) {
    prepare_partner_data(data, predictors = x, temporal_decomposition = "none", ...)
  }
  one_member_line <- paste0(
    "Dyad-occasions with a row for only one member: 2 of 4 ",
    "(the partner is assumed to exist, with missing values)."
  )

  # Person 2 has no row at time 2; person 4 has an empty row at time 1.
  incomplete <- complete[-4, ]
  incomplete$x[incomplete$person_id == 4 & incomplete$time == 1] <- NA
  prepared <- prepare(incomplete[-5, ], time = time)
  printed <- capture_wide_print(prepared)
  expect_printed(printed, "# Partner data:")
  expect_printed(printed, one_member_line)
  expect_printed(printed, "Rows with at least one missing partner predictor: 2 of 6")
  expect_printed(printed, "Check: If no partner existed")
  summary_printed <- withr::with_options(list(width = 1000), capture.output(summary(prepared)))
  expect_printed(summary_printed, one_member_line)

  # An empty partner row is counted as missing partner data, not as an
  # occasion with one member.
  printed <- capture_wide_print(prepare(incomplete, time = time))
  expect_printed(printed, "Dyad-occasions with a row for only one member: 1 of 4")
  expect_printed(printed, "Rows with at least one missing partner predictor: 2 of 7")

  # Cross-sectional data report missing partner predictors only.
  cross_sectional <- complete[complete$time == 1, ]
  cross_sectional$x[1] <- NA
  printed <- capture_wide_print(prepare(cross_sectional))
  expect_no_match(printed, "Dyad-occasions", fixed = TRUE)
  expect_printed(printed, "Rows with at least one missing partner predictor: 1 of 4.")
  # Partners have rows here, so no existence assumption needs checking.
  expect_no_match(printed, "Check:", fixed = TRUE)

  expect_no_match(capture_wide_print(prepare(complete, time = time)), "# Partner data:", fixed = TRUE)
})

test_that("dyadMLM data print reports people observed alone and two-part coding", {
  # Dyad 1: the wife (person 1) answers waves 1-3, her husband (person 2) only
  # wave 1. He skips wave 2 and dies before wave 3. Dyad 2 is complete. Dyad 3
  # is a person without a partner.
  data <- tibble::tibble(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2, 3, 3),
    person_id = c(1, 1, 1, 2, 3, 4, 3, 4, 5, 5),
    wave = c(1, 2, 3, 1, 1, 1, 2, 2, 1, 2),
    alive = c(TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE),
    x = 1:10
  )
  printed <- capture_wide_print(prepare_partner_data(
    data, time = wave, predictors = x, temporal_decomposition = "none", partner_exists = alive
  ))

  expect_match(printed, "# singleton +singleton +1 person", all = FALSE)
  expect_printed(printed, "People observed alone: 1 without a partner.")
  # Without a partner: dyad 1 at wave 3 and dyad 3 at waves 1-2. With a partner
  # who has missing values: dyad 1 at wave 2.
  expect_printed(printed, paste0(
    "Dyad-occasions with a row for only one member: 4 of 7 ",
    "(3 without a partner, 1 with a partner who has missing values)."
  ))
  expect_printed(
    printed,
    "Two-part coding: Partner predictors are 0 where no partner existed. Suggested fixed-effect terms"
  )
  expect_true("#     + .partner_exists  # a partner exists (1) or not (0)" %in% printed)
  # `partner_exists` already says which partners existed.
  expect_no_match(printed, "Check:", fixed = TRUE)
})

test_that("dyadMLM data print orders generated column descriptions", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c(1, 2, 1, 2, 3, 4, 3, 4),
    role = rep(c("female", "male"), 4),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = c(1, 2, 3, 4, 5, 6, 7, 8),
    y = c(2, 3, 4, 5, 6, 7, 8, 9)
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role,
    time = time,
    predictors = x,
    model_types = c("apim", "dsm"),
    dsm_role_order = c("female", "male"),
    seed = 123
  )

  lines <- added_column_lines(capture_wide_print(result))

  expect_lt(added_column_index(lines, ".{pred}_cwp"), added_column_index(lines, ".{pred}_cwp_actor"))
  expect_lt(added_column_index(lines, ".{pred}_cbp"), added_column_index(lines, ".{pred}_cbp_actor"))
  expect_lt(added_column_index(lines, ".{pred}_cbp_partner"), added_column_index(lines, ".{pred}_cwp_dyad_mean"))
})

test_that("dyadMLM data print collapses repeated generated column types", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c(1, 2, 1, 2, 3, 4, 3, 4),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = c(1, 2, 3, 4, 5, 6, 7, 8),
    z = c(8, 7, 6, 5, 4, 3, 2, 1)
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    time = time,
    predictors = c(x, z),
    seed = 123
  )

  lines <- added_column_lines(capture_wide_print(result))

  expect_equal(added_column_count(lines, ".{pred}_cwp"), 1)
  expect_equal(added_column_count(lines, ".{pred}_cbp"), 1)
  expect_equal(added_column_count(lines, ".{pred}_actor"), 1)
  expect_equal(added_column_count(lines, ".{pred}_partner"), 1)
  expect_equal(added_column_count(lines, ".{pred}_cwp_actor"), 1)
  expect_equal(added_column_count(lines, ".{pred}_cwp_partner"), 1)
  expect_equal(added_column_count(lines, ".{pred}_cbp_actor"), 1)
  expect_equal(added_column_count(lines, ".{pred}_cbp_partner"), 1)
})

test_that("dyadMLM data print does not describe removed temporal source columns", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c(1, 2, 1, 2, 3, 4, 3, 4),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = c(1, 2, 3, 4, 5, 6, 7, 8)
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    time = time,
    predictors = x,
    seed = 123
  )

  result$.x_cwp <- NULL

  lines <- added_column_lines(capture_wide_print(result))

  expect_equal(added_column_count(lines, ".{pred}_cwp"), 0)
  expect_equal(added_column_count(lines, ".{pred}_cbp"), 1)
  expect_equal(added_column_count(lines, ".{pred}_cwp_actor"), 1)
})

test_that("dyadMLM data print describes cross-sectional DIM columns", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2),
    person_id = c(1, 2, 3, 4),
    x = c(1, 2, 3, 4)
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    predictors = x,
    model_types = "dim",
    seed = 123
  )

  printed <- capture_wide_print(result)

  expect_true(any(grepl(".{pred}_dyad_mean_gmc", printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    ".{pred}_dyad_mean_gmc",
    "dyad-mean predictor: dyad's average predictor level, grand-mean centered"
  )
  expect_true(any(grepl(".{pred}_within_dyad_dev", printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    ".{pred}_within_dyad_dev",
    "DIM within-dyad member-deviation predictor: member's difference from the dyad mean"
  )
})

test_that("dyadMLM data print describes longitudinal DIM columns", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c(1, 2, 1, 2, 3, 4, 3, 4),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = c(1, 2, 3, 4, 5, 6, 7, 8)
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    time = time,
    predictors = x,
    model_types = "dim",
    seed = 123
  )

  printed <- capture_wide_print(result)

  expect_true(any(grepl(".{pred}_dyad_mean_gmc", printed, fixed = TRUE)))
  expect_true(any(grepl(".{pred}_within_dyad_dev", printed, fixed = TRUE)))
  expect_true(any(grepl(".{pred}_cwp_dyad_mean", printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    ".{pred}_cwp_dyad_mean",
    "within-person dyad-mean predictor: shared momentary deviations in the dyad"
  )
  expect_true(any(grepl(".{pred}_cwp_within_dyad_dev", printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    ".{pred}_cwp_within_dyad_dev",
    "DIM within-person, within-dyad member-deviation predictor: member's momentary deviation from the dyad mean"
  )
  expect_true(any(grepl(".{pred}_cbp_dyad_mean", printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    ".{pred}_cbp_dyad_mean",
    "between-person dyad-mean predictor: dyad's stable usual level, grand-mean centered"
  )
  expect_true(any(grepl(".{pred}_cbp_within_dyad_dev", printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    ".{pred}_cbp_within_dyad_dev",
    "DIM between-person, within-dyad member-deviation predictor: member's stable difference from the dyad's usual level"
  )
})

test_that("dyadMLM data print describes longitudinal DSM predictors", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c(1, 2, 1, 2, 3, 4, 3, 4),
    role = rep(c("female", "male"), 4),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = c(1, 2, 3, 4, 5, 6, 7, 8),
    y = c(2, 3, 4, 5, 6, 7, 8, 9)
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
    seed = 123
  )

  printed <- capture_wide_print(result)

  expect_true(any(grepl(".{pred}_cwp", printed, fixed = TRUE)))
  expect_true(any(grepl(".{pred}_cbp", printed, fixed = TRUE)))
  expect_true(any(grepl("DSM direction: female - male", printed, fixed = TRUE)))
  expect_true(any(grepl(".dsm_role_contrast", printed, fixed = TRUE)))
  expect_true(any(grepl(".{pred}_dyad_mean_gmc", printed, fixed = TRUE)))
  expect_true(any(grepl(".{pred}_within_dyad_diff", printed, fixed = TRUE)))
  expect_true(any(grepl(".{pred}_cwp_dyad_mean", printed, fixed = TRUE)))
  expect_true(any(grepl(".{pred}_cbp_dyad_mean", printed, fixed = TRUE)))
  expect_true(any(grepl(".{pred}_cwp_within_dyad_diff", printed, fixed = TRUE)))
  expect_true(any(grepl(".{pred}_cbp_within_dyad_diff", printed, fixed = TRUE)))
  expect_false(any(grepl("within_dyad_dev", printed, fixed = TRUE)))
})

test_that("dyadMLM data print combines APIM and DIM column descriptions", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2),
    person_id = c(1, 2, 3, 4),
    x = c(1, 2, 3, 4)
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    predictors = x,
    model_types = c("apim", "dim"),
    seed = 123
  )

  printed <- capture_wide_print(result)

  expect_true(any(grepl(".{pred}_actor", printed, fixed = TRUE)))
  expect_true(any(grepl(".{pred}_partner", printed, fixed = TRUE)))
  expect_true(any(grepl(".{pred}_dyad_mean_gmc", printed, fixed = TRUE)))
  expect_true(any(grepl(".{pred}_within_dyad_dev", printed, fixed = TRUE)))
})

test_that("dyadMLM data print combines APIM and DSM predictors", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2),
    person_id = c(1, 2, 3, 4),
    role = c("female", "male", "female", "male"),
    x = c(1, 2, 3, 4),
    y = c(5, 6, 7, 8)
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role,
    predictors = x,
    model_types = c("apim", "dsm"),
    dsm_role_order = c("female", "male"),
    seed = 123
  )

  printed <- capture_wide_print(result)

  expect_true(any(grepl(".{pred}_actor", printed, fixed = TRUE)))
  expect_added_column_description(
    printed,
    ".{pred}_actor",
    "APIM actor predictor: actor's original predictor values"
  )
  expect_true(any(grepl(".{pred}_dyad_mean_gmc", printed, fixed = TRUE)))
  expect_true(any(grepl(".{pred}_within_dyad_diff", printed, fixed = TRUE)))
})

test_that("dyadMLM data print describes dropped dyads with missing role information", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2, 3, 3),
    person_id = c("A", "B", "C", "D", "E", "F"),
    role = c("female", NA, "female", "male", "female", "male")
  )

  expect_message(
    result <- prepare_dyad_data(
      data,
      dyad = dyad_id,
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

test_that("dyadMLM data print truncates many dropped incomplete dyad IDs", {
  data <- tibble::tibble(
    dyad_id = c(1:14, 15, 15, 16, 16),
    person_id = c(paste0("single", 1:14), "A", "B", "C", "D")
  )

  suppressMessages(
    result <- prepare_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      incomplete_dyads = "drop",
      seed = 123
    )
  )

  printed <- capture_wide_print(result)

  expect_true(any(grepl("# Dropped incomplete dyads:", printed, fixed = TRUE)))
  expect_true(any(grepl("14 dyads, with IDs: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, ... and 4 more", printed, fixed = TRUE)))
})

test_that("dyadMLM data print includes role and time in structure line", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    role = c("female", "male", "female", "male", "female", "male", "female", "male"),
    day = c(1, 1, 2, 2, 1, 1, 2, 2)
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role,
    time = day,
    seed = 123
  )

  printed <- capture_wide_print(result)

  expect_true(any(grepl(
    "# Structure: dyad = dyad_id, member = person_id, role = role, time = day",
    printed,
    fixed = TRUE
  )))
})

test_that("dyadMLM data print describes mixed dyad types", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2, 3, 3),
    person_id = c("A", "B", "C", "D", "E", "F"),
    role = c("female", "male", "female", "female", "male", "male")
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
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

test_that("dyadMLM data print marks dyad types set by user", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male")
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
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

test_that("dyadMLM data print describes pooled compositions", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2, 3, 3),
    person_id = c("A", "B", "C", "D", "E", "F"),
    role = c("female", "male", "female", "female", "male", "male")
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
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

test_that("partner data print relies on dyadMLM's own status columns", {
  prepare <- function(data, ...) {
    prepare_partner_data(data, time = wave, temporal_decomposition = "none", ...)
  }
  # Dyads 1 and 2 are observed together at waves 1-2. Dyad 1 separates at
  # wave 2 but both partners keep taking part.
  separated <- tibble::tibble(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c(1, 2, 1, 2, 3, 4, 3, 4),
    wave = c(1, 1, 2, 2, 1, 1, 2, 2),
    together = c(TRUE, TRUE, FALSE, FALSE, TRUE, TRUE, TRUE, TRUE),
    x = 1:8
  )

  # An input column named `.partner_exists` is not treated as a status column.
  data <- separated
  data$.partner_exists <- c(1, NA, 0, 1, 1, 1, 1, 1)
  expect_no_match(capture_wide_print(prepare(data, predictors = x)), "Two-part coding:", fixed = TRUE)

  # The reminder is shown without other partner data lines.
  printed <- capture_wide_print(prepare(separated, predictors = x, partner_exists = together))
  expect_no_match(printed, "Rows with at least", fixed = TRUE)
  expect_printed(printed, "Two-part coding: Partner predictors are 0")

  # A constant FALSE status does not claim that partners exist.
  alone <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2),
    person_id = c(1, 1, 2, 2),
    wave = c(1, 2, 1, 2),
    x = 1:4
  )
  printed <- capture_wide_print(prepare(alone, predictors = x, partner_exists = FALSE))
  expect_printed(printed, "only one member: 4 of 4.")
  expect_no_match(printed, "assumed to exist", fixed = TRUE)
})

test_that("people observed alone are counted in the current data", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2, 3, 4, 5),
    person_id = 1:7,
    partnered = c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
    x = 1:7
  )
  prepared <- prepare_partner_data(data, predictors = x, partner_exists = partnered)
  printed <- capture_wide_print(prepared)
  expect_printed(printed, "People observed alone: 2 without a partner, 1 with a partner not in the data.")
  # Their indicators keep their full names under "Added columns".
  expect_printed(printed, "#   .is_singleton ")

  printed <- capture_wide_print(prepared[prepared$dyad_id != 4 & prepared$dyad_id != 5, ])
  expect_printed(printed, "People observed alone: 1 without a partner.")

  # Terms that became constant are not suggested. With only partnered rows
  # left, no status varies, so there is no reminder.
  printed <- capture_wide_print(prepared[prepared$.partner_exists == 1, ])
  expect_no_match(printed, "Two-part coding:", fixed = TRUE)
})

test_that("partner data print lists split two-part terms and counts their missing values", {
  # The wife (person 1) loses her husband (person 2, who never answered x)
  # before wave 3. Dyad 2 is a stable couple.
  data <- tibble::tibble(
    dyad_id = c(1, 1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c(1, 1, 1, 2, 2, 3, 4, 3, 4),
    wave = c(1, 2, 3, 1, 2, 1, 1, 2, 2),
    partnered = c(TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE),
    x = c(1, 2, 3, NA, NA, 6, 7, 8, 9)
  )
  prepared <- prepare_partner_data(data, time = wave, predictors = x, partner_exists = partnered)
  printed <- capture_wide_print(prepared)

  # The former partner's usual level is unknown, so `_after_exists` is only 0
  # or NA and not suggested.
  term_lines <- grep("^#     \\+ ", printed, value = TRUE)
  expect_equal(sub("^#     \\+ (\\S+).*", "\\1", term_lines), c(
    ".partner_exists_cwp", ".partner_exists_cbp", ".x_cwp_partner",
    ".x_cbp_partner_when_exists"
  ))
  expect_printed(printed, "#   .{pred}_cbp_partner_when_exists ")
  # The wife's partner predictors are unknown at all three waves. At wave 3,
  # only the former partner's usual level is (`_after_exists` is NA).
  expect_printed(printed, "Rows with at least one missing partner predictor: 3 of 9.")

  # The reminder still appears without the raw status.
  printed <- capture_wide_print(dplyr::select(prepared, -".partner_exists"))
  expect_printed(printed, "Two-part coding:")

  # With the former partner's usual level known, it is suggested, and a
  # singleton then needs its own intercept, unless filtered out.
  answered <- data
  answered$x[answered$person_id == 2] <- c(4, 5)
  with_singleton <- dplyr::bind_rows(
    answered,
    tibble::tibble(dyad_id = 3, person_id = 5, wave = 1:2, partnered = FALSE, x = c(4, 5))
  )
  prepared <- prepare_partner_data(with_singleton, time = wave, predictors = x, partner_exists = partnered)
  printed <- capture_wide_print(prepared)
  expect_true("#     + .x_cbp_partner_after_exists  # former partner's usual level, after a loss" %in% printed)
  expect_printed(printed, "+ .is_singleton")
  printed <- capture_wide_print(prepared[prepared$dyad_id != 3, ])
  expect_no_match(printed, "+ .is_singleton", fixed = TRUE)
  expect_printed(printed, "Two-part coding:")
})
