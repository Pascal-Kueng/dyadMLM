check_mixed_dyad_type_ild_dataset <- function(data, outcome) {
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

  prepared <- prepare_dyad_data(
    data,
    dyad = coupleID,
    member = personID,
    role = gender,
    time = diaryday,
    seed = 123
  )

  dyad_compositions <- attr(prepared, "dyadMLM")$dyad_compositions
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
  expect_false(dyad_diff_col %in% names(prepared))
  expect_true(".dy_member_contrast_female_x_female_arbitrary" %in% names(prepared))
  expect_true(".dy_member_contrast_male_x_male_arbitrary" %in% names(prepared))

  female_female <- prepared$.dy_composition == "female_x_female"
  male_male <- prepared$.dy_composition == "male_x_male"
  expect_true(all(abs(prepared$.dy_member_contrast_female_x_female_arbitrary[female_female]) == 1))
  expect_true(all(prepared$.dy_member_contrast_female_x_female_arbitrary[!female_female] == 0))
  expect_true(all(abs(prepared$.dy_member_contrast_male_x_male_arbitrary[male_male]) == 1))
  expect_true(all(prepared$.dy_member_contrast_male_x_male_arbitrary[!male_male] == 0))
}

test_that("ILD Gaussian example data with mixed dyad types has expected structure", {
  data("example_dyadic_ILD_mixed", package = "dyadMLM")

  check_mixed_dyad_type_ild_dataset(example_dyadic_ILD_mixed, "closeness")
})

test_that("ILD Tweedie example data with mixed dyad types has expected structure", {
  data("example_dyadic_ILD_mixed_tweedie", package = "dyadMLM")

  check_mixed_dyad_type_ild_dataset(example_dyadic_ILD_mixed_tweedie, "physical_activity")
})
