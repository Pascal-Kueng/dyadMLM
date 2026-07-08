check_unified_ild_dataset <- function(data, outcome) {
  expected_columns <- c(
    "personID",
    "coupleID",
    "diaryday",
    "gender",
    outcome,
    "provided_support"
  )
  expect_equal(names(data), expected_columns)
  expect_equal(nrow(data), 5600L)

  structural_columns <- c("personID", "coupleID", "diaryday", "gender")
  measured_columns <- c(outcome, "provided_support")
  expect_false(anyNA(data[structural_columns]))
  expect_gt(sum(is.na(data[measured_columns])), 0)
  expect_true(all(colSums(is.na(data[setdiff(names(data), measured_columns)])) == 0))

  prepared <- prepare_interdep_data(
    data,
    group = coupleID,
    member = personID,
    role = gender,
    time = diaryday,
    seed = 123
  )

  dyad_compositions <- attr(prepared, "interdep")$dyad_compositions
  dyad_compositions <- dyad_compositions[order(dyad_compositions$composition), ]

  expect_equal(
    dyad_compositions$composition,
    c("female_x_female", "female_x_male", "male_x_male")
  )
  expect_equal(
    dyad_compositions$dyad_type,
    c("exchangeable", "distinguishable", "exchangeable")
  )
  expect_equal(dyad_compositions$n_dyads, c(60L, 80L, 60L))
  expect_true(".i_diff_female_x_female" %in% names(prepared))
  expect_true(".i_diff_male_x_male" %in% names(prepared))

  female_male <- prepared$.i_composition == "female_x_male"
  exchangeable <- prepared$.i_composition != "female_x_male"
  expect_true(all(prepared[[interdep_diff_col]][female_male] == 0))
  expect_true(all(abs(prepared[[interdep_diff_col]][exchangeable]) == 1))

  female_female <- prepared$.i_composition == "female_x_female"
  male_male <- prepared$.i_composition == "male_x_male"
  expect_true(all(abs(prepared$.i_diff_female_x_female[female_female]) == 1))
  expect_true(all(prepared$.i_diff_female_x_female[!female_female] == 0))
  expect_true(all(abs(prepared$.i_diff_male_x_male[male_male]) == 1))
  expect_true(all(prepared$.i_diff_male_x_male[!male_male] == 0))
}

test_that("unified ILD Gaussian example data has expected structure", {
  data("example_dyadic_ILD_unified", package = "interdep")

  expect_true(exists("example_dyadic_ILD_unified"))
  check_unified_ild_dataset(example_dyadic_ILD_unified, "closeness")
})

test_that("unified ILD Tweedie example data has expected structure", {
  data("example_dyadic_ILD_unified_tweedie", package = "interdep")

  expect_true(exists("example_dyadic_ILD_unified_tweedie"))
  check_unified_ild_dataset(example_dyadic_ILD_unified_tweedie, "physical_activity")
})
