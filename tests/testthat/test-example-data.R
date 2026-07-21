check_example_dyads <- function(
    data, outcome, predictor, intensive_longitudinal) {
  structural_columns <- c("personID", "coupleID")
  if (intensive_longitudinal) {
    structural_columns <- c(structural_columns, "diaryday")
  }
  structural_columns <- c(
    structural_columns,
    "gender",
    "dyad_composition"
  )

  expect_equal(
    names(data),
    c(structural_columns, outcome, predictor)
  )
  expect_equal(nrow(data), if (intensive_longitudinal) 10080L else 720L)
  expect_equal(dplyr::n_distinct(data$coupleID), 360L)

  # All four examples are complete and contain two members per dyad.
  expect_false(anyNA(data))
  rows_per_dyad <- table(data$coupleID)
  expected_rows_per_dyad <- if (intensive_longitudinal) 28L else 2L
  expect_true(all(rows_per_dyad == expected_rows_per_dyad))

  if (intensive_longitudinal) {
    expect_equal(dplyr::n_distinct(data$diaryday), 14L)
    rows_per_dyad_day <- table(data$coupleID, data$diaryday)
    expect_true(all(rows_per_dyad_day == 2L))
  } else {
    expect_false("diaryday" %in% names(data))
  }

  if (intensive_longitudinal) {
    prepared <- prepare_dyad_data(
      data,
      dyad = coupleID,
      member = personID,
      role = gender,
      time = diaryday,
      seed = 123
    )
  } else {
    prepared <- prepare_dyad_data(
      data,
      dyad = coupleID,
      member = personID,
      role = gender,
      seed = 123
    )
  }

  dyad_compositions <- attr(prepared, "dyadMLM")$dyad_compositions
  dyad_compositions <- dyad_compositions[
    order(dyad_compositions$composition),
  ]

  expect_equal(
    dyad_compositions$composition,
    c("female_x_female", "female_x_male", "male_x_male")
  )
  expect_equal(
    dyad_compositions$dyad_type,
    c("exchangeable", "distinguishable", "exchangeable")
  )
  expect_equal(dyad_compositions$n_dyads, c(120L, 120L, 120L))
  expect_false(dyad_diff_col %in% names(prepared))
  expect_true(
    ".dy_member_contrast_female_x_female_arbitrary" %in% names(prepared)
  )
  expect_true(
    ".dy_member_contrast_male_x_male_arbitrary" %in% names(prepared)
  )

  female_female <- prepared$.dy_composition == "female_x_female"
  male_male <- prepared$.dy_composition == "male_x_male"
  female_female_contrast <-
    prepared$.dy_member_contrast_female_x_female_arbitrary
  male_male_contrast <-
    prepared$.dy_member_contrast_male_x_male_arbitrary

  expect_true(all(abs(female_female_contrast[female_female]) == 1))
  expect_true(all(female_female_contrast[!female_female] == 0))
  expect_true(all(abs(male_male_contrast[male_male]) == 1))
  expect_true(all(male_male_contrast[!male_male] == 0))
}

test_that("Gaussian cross-sectional example has the expected structure", {
  data("dyads_cross", package = "dyadMLM")

  check_example_dyads(
    dyads_cross,
    outcome = "closeness",
    predictor = "provided_support",
    intensive_longitudinal = FALSE
  )
})

test_that("Gaussian ILD example has the expected structure", {
  data("dyads_ild", package = "dyadMLM")

  check_example_dyads(
    dyads_ild,
    outcome = "closeness",
    predictor = "provided_support",
    intensive_longitudinal = TRUE
  )
})

test_that("negative-binomial examples have the expected structures", {
  data("dyads_nbinom_cross", package = "dyadMLM")
  data("dyads_nbinom_ild", package = "dyadMLM")

  check_example_dyads(
    dyads_nbinom_cross,
    outcome = "conflict_count",
    predictor = "stress",
    intensive_longitudinal = FALSE
  )
  check_example_dyads(
    dyads_nbinom_ild,
    outcome = "conflict_count",
    predictor = "stress",
    intensive_longitudinal = TRUE
  )
})

test_that("negative-binomial outcomes are nonnegative integer counts", {
  data("dyads_nbinom_cross", package = "dyadMLM")
  data("dyads_nbinom_ild", package = "dyadMLM")

  count_outcomes <- list(
    cross = dyads_nbinom_cross$conflict_count,
    ild = dyads_nbinom_ild$conflict_count
  )

  for (counts in count_outcomes) {
    expect_true(all(counts >= 0))
    expect_true(all(counts == floor(counts)))
    expect_true(any(counts == 0))
  }
})

test_that("cross-sectional scores are member averages of the ILD scores", {
  data("dyads_cross", package = "dyadMLM")
  data("dyads_ild", package = "dyadMLM")
  data("dyads_nbinom_cross", package = "dyadMLM")
  data("dyads_nbinom_ild", package = "dyadMLM")

  gaussian_member_means <- dyads_ild |>
    dplyr::group_by(personID) |>
    dplyr::summarise(
      closeness = mean(closeness),
      provided_support = mean(provided_support),
      .groups = "drop"
    ) |>
    dplyr::arrange(personID)

  observed_gaussian_scores <- dyads_cross |>
    dplyr::select(personID, closeness, provided_support) |>
    dplyr::arrange(personID)

  expect_equal(observed_gaussian_scores, gaussian_member_means)

  stress_member_means <- dyads_nbinom_ild |>
    dplyr::group_by(personID) |>
    dplyr::summarise(
      stress = mean(stress),
      .groups = "drop"
    ) |>
    dplyr::arrange(personID)

  observed_cross_stress <- dyads_nbinom_cross |>
    dplyr::select(personID, stress) |>
    dplyr::arrange(personID)

  expect_equal(observed_cross_stress, stress_member_means)
})

test_that("example datasets use parallel dyad structures", {
  data("dyads_cross", package = "dyadMLM")
  data("dyads_ild", package = "dyadMLM")
  data("dyads_nbinom_cross", package = "dyadMLM")
  data("dyads_nbinom_ild", package = "dyadMLM")

  cross_structural_columns <- c(
    "personID",
    "coupleID",
    "gender",
    "dyad_composition"
  )
  ild_structural_columns <- c(
    "personID",
    "coupleID",
    "diaryday",
    "gender",
    "dyad_composition"
  )

  expect_identical(
    dyads_cross[cross_structural_columns],
    dyads_nbinom_cross[cross_structural_columns]
  )
  expect_identical(
    dyads_ild[ild_structural_columns],
    dyads_nbinom_ild[ild_structural_columns]
  )

  gaussian_ild_day_zero <- dyads_ild |>
    dplyr::filter(diaryday == 0L) |>
    dplyr::select(dplyr::all_of(cross_structural_columns))
  nbinom_ild_day_zero <- dyads_nbinom_ild |>
    dplyr::filter(diaryday == 0L) |>
    dplyr::select(dplyr::all_of(cross_structural_columns))

  expect_identical(
    dyads_cross[cross_structural_columns],
    gaussian_ild_day_zero
  )
  expect_identical(
    dyads_nbinom_cross[cross_structural_columns],
    nbinom_ild_day_zero
  )
})
