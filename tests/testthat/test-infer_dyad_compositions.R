test_that("infer_dyad_compositions counts role compositions", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2, 3, 3, 4, 4),
    person_id = c("A", "B", "C", "D", "E", "F", "G", "H"),
    role = c("female", "male", "female", "male", "female", "female", "male", "male")
  )

  validated <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role
  )

  result <- infer_dyad_compositions(validated, seed = 123)
  expect_s3_class(result, "interdep_data")
  expect_false(".i_raw_composition" %in% names(result))
  expect_false(".i_arbitrary_role" %in% names(result))
  expect_true(".i_composition" %in% names(result))
  expect_true(".i_composition_role" %in% names(result))
  expect_true(is.factor(result$.i_composition))
  expect_true(is.factor(result$.i_composition_role))
  indicator_names <- grep("^\\.i_is_", names(result), value = TRUE)
  expect_equal(
    indicator_names,
    c(
      ".i_is_female_x_female",
      ".i_is_female_x_male_female",
      ".i_is_female_x_male_male",
      ".i_is_male_x_male"
    )
  )
  expect_true(".i_diff_female_x_female" %in% names(result))
  expect_true(".i_diff_male_x_male" %in% names(result))
  expect_true(all(sapply(result[indicator_names], is.numeric)))
  expect_equal(rowSums(result[indicator_names]), rep(1, nrow(result)))

  dyad_compositions <- attr(result, "interdep")$dyad_compositions
  dyad_compositions <- dyad_compositions[order(dyad_compositions$composition), ]

  expect_equal(
    dyad_compositions$raw_composition,
    c("female_x_female", "female_x_male", "male_x_male")
  )
  expect_equal(
    dyad_compositions$composition,
    c("female_x_female", "female_x_male", "male_x_male")
  )
  expect_equal(
    dyad_compositions$dyad_type,
    c("exchangeable", "distinguishable", "exchangeable")
  )
  expect_equal(dyad_compositions$n_dyads, c(1L, 2L, 1L))
  expect_equal(
    as.character(result$.i_composition),
    c("female_x_male", "female_x_male", "female_x_male", "female_x_male",
      "female_x_female", "female_x_female", "male_x_male", "male_x_male")
  )
  expect_equal(
    as.character(result$.i_composition_role),
    c("female_x_male_female", "female_x_male_male",
      "female_x_male_female", "female_x_male_male",
      "female_x_female", "female_x_female",
      "male_x_male", "male_x_male")
  )
  expect_equal(result[[interdep_diff_col]][result$dyad_id %in% c(1, 2)], rep(0, 4))
  expect_equal(abs(result[[interdep_diff_col]][result$dyad_id %in% c(3, 4)]), rep(1, 4))
  expect_equal(result$.i_diff_female_x_female[result$dyad_id != 3], rep(0, 6))
  expect_equal(result$.i_diff_male_x_male[result$dyad_id != 4], rep(0, 6))
})

test_that("idiff signs do not depend on distinguishable dyads", {
  exchangeable_only <- data.frame(
    dyad_id = c(2, 2, 3, 3),
    person_id = c("C", "D", "E", "F"),
    role = c("female", "female", "male", "male")
  )
  mixed <- rbind(
    data.frame(
      dyad_id = c(1, 1),
      person_id = c("A", "B"),
      role = c("female", "male")
    ),
    exchangeable_only
  )

  exchangeable_result <- validate_interdep_data(
    exchangeable_only,
    group = dyad_id,
    member = person_id,
    role = role
  ) |>
    infer_dyad_compositions(seed = 123)

  mixed_result <- validate_interdep_data(
    mixed,
    group = dyad_id,
    member = person_id,
    role = role
  ) |>
    infer_dyad_compositions(seed = 123)

  expect_equal(
    mixed_result[[interdep_diff_col]][mixed_result$dyad_id %in% c(2, 3)],
    exchangeable_result[[interdep_diff_col]]
  )
})

test_that("infer_dyad_compositions is not inflated by longitudinal rows", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    role = c("female", "male", "female", "male", "female", "female", "female", "female"),
    time = c(1, 1, 2, 2, 1, 1, 2, 2)
  )

  validated <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role,
    time = time
  )

  result <- infer_dyad_compositions(validated, seed = 123)
  dyad_compositions <- attr(result, "interdep")$dyad_compositions
  dyad_compositions <- dyad_compositions[order(dyad_compositions$composition), ]
  indicator_names <- grep("^\\.i_is_", names(result), value = TRUE)

  expect_equal(dyad_compositions$raw_composition, c("female_x_female", "female_x_male"))
  expect_equal(dyad_compositions$composition, c("female_x_female", "female_x_male"))
  expect_equal(dyad_compositions$dyad_type, c("exchangeable", "distinguishable"))
  expect_equal(dyad_compositions$n_dyads, c(1L, 1L))
  expect_equal(rowSums(result[indicator_names]), rep(1, nrow(result)))
  expect_equal(
    as.character(result$.i_composition),
    c("female_x_male", "female_x_male", "female_x_male", "female_x_male",
      "female_x_female", "female_x_female", "female_x_female", "female_x_female")
  )
  expect_equal(
    as.character(result$.i_composition_role),
    c("female_x_male_female", "female_x_male_male",
      "female_x_male_female", "female_x_male_male",
      "female_x_female", "female_x_female",
      "female_x_female", "female_x_female")
  )
  expect_true(".i_diff_female_x_female" %in% names(result))
  expect_equal(result$.i_diff_female_x_female[result$dyad_id == 1], rep(0, 4))
  expect_equal(abs(result$.i_diff_female_x_female[result$dyad_id == 2]), rep(1, 4))
})

test_that("infer_dyad_compositions handles ragged longitudinal rows", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "B", "C", "D", "C", "D"),
    role = c("female", "male", "male", "female", "female", "female", "female"),
    time = c(1, 1, 2, 1, 1, 2, 2)
  )

  result <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role,
    time = time
  ) |>
    infer_dyad_compositions(seed = 123)

  dyad_compositions <- attr(result, "interdep")$dyad_compositions
  dyad_compositions <- dyad_compositions[order(dyad_compositions$composition), ]

  expect_equal(dyad_compositions$composition, c("female_x_female", "female_x_male"))
  expect_equal(dyad_compositions$n_dyads, c(1L, 1L))
  expect_equal(as.character(result$.i_composition[result$dyad_id == 1]), rep("female_x_male", 3))
  expect_equal(as.character(result$.i_composition[result$dyad_id == 2]), rep("female_x_female", 4))
})

test_that("infer_dyad_compositions creates formula-friendly indicator names", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female partner", "male-partner", "female partner", "male-partner")
  )

  validated <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role
  )

  result <- infer_dyad_compositions(validated, seed = 123)

  expect_true(".i_is_female_partner_x_male_partner_female_partner" %in% names(result))
  expect_true(".i_is_female_partner_x_male_partner_male_partner" %in% names(result))
})

test_that("infer_dyad_compositions rejects generated indicator name collisions", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("a b", "a-b", "a b", "a-b")
  )

  validated <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role
  )

  expect_error(
    infer_dyad_compositions(validated, seed = 123),
    "same generated column-name suffix",
    fixed = TRUE
  )
})

test_that("infer_dyad_compositions treats missing role metadata as unclassified", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  validated <- validate_interdep_data(data, group = dyad_id, member = person_id)
  result <- infer_dyad_compositions(validated, seed = 123)

  expect_false(".i_raw_composition" %in% names(result))
  expect_false(".i_arbitrary_role" %in% names(result))
  expect_true(is.factor(result$.i_composition))
  expect_true(is.factor(result$.i_composition_role))
  expect_true(".i_is_assumed_exchangeable" %in% names(result))
  expect_true(".i_diff_assumed_exchangeable" %in% names(result))
  expect_equal(abs(result[[interdep_diff_col]]), rep(1, 4))
  expect_equal(result$.i_diff_assumed_exchangeable, result[[interdep_diff_col]])
  expect_equal(
    as.character(result$.i_composition),
    rep("assumed_exchangeable", 4)
  )
  expect_equal(
    as.character(result$.i_composition_role),
    rep("assumed_exchangeable", 4)
  )
  expect_equal(
    attr(result, "interdep")$dyad_compositions,
    tibble::tibble(
      raw_composition = "assumed_exchangeable",
      composition = "assumed_exchangeable",
      dyad_type = "exchangeable",
      n_dyads = 2L
    )
  )
})
