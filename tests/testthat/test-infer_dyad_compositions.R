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

  result <- infer_dyad_compositions(validated)
  expect_s3_class(result, "interdep_data")
  expect_false(".i_raw_composition" %in% names(result))
  expect_true(".i_composition" %in% names(result))
  expect_true(".i_composition_role" %in% names(result))
  expect_true(is.factor(result$.i_composition))
  expect_true(is.factor(result$.i_composition_role))
  indicator_names <- grep("^\\.i_is_", names(result), value = TRUE)
  expect_equal(
    indicator_names,
    c(
      ".i_is_female__female",
      ".i_is_female__male__female",
      ".i_is_female__male__male",
      ".i_is_male__male"
    )
  )
  expect_true(all(sapply(result[indicator_names], is.numeric)))
  expect_equal(rowSums(result[indicator_names]), rep(1, nrow(result)))

  dyad_compositions <- attr(result, "interdep")$dyad_compositions
  dyad_compositions <- dyad_compositions[order(dyad_compositions$composition), ]

  expect_equal(
    dyad_compositions$raw_composition,
    c("female__female", "female__male", "male__male")
  )
  expect_equal(
    dyad_compositions$composition,
    c("female__female", "female__male", "male__male")
  )
  expect_equal(
    dyad_compositions$dyad_type,
    c("exchangeable", "distinguishable", "exchangeable")
  )
  expect_equal(dyad_compositions$n_dyads, c(1L, 2L, 1L))
  expect_equal(
    as.character(result$.i_composition),
    c("female__male", "female__male", "female__male", "female__male",
      "female__female", "female__female", "male__male", "male__male")
  )
  expect_equal(
    as.character(result$.i_composition_role),
    c("female__male__female", "female__male__male",
      "female__male__female", "female__male__male",
      "female__female", "female__female", "male__male", "male__male")
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

  result <- infer_dyad_compositions(validated)
  dyad_compositions <- attr(result, "interdep")$dyad_compositions
  dyad_compositions <- dyad_compositions[order(dyad_compositions$composition), ]
  indicator_names <- grep("^\\.i_is_", names(result), value = TRUE)

  expect_equal(dyad_compositions$raw_composition, c("female__female", "female__male"))
  expect_equal(dyad_compositions$composition, c("female__female", "female__male"))
  expect_equal(dyad_compositions$dyad_type, c("exchangeable", "distinguishable"))
  expect_equal(dyad_compositions$n_dyads, c(1L, 1L))
  expect_equal(rowSums(result[indicator_names]), rep(1, nrow(result)))
  expect_equal(
    as.character(result$.i_composition),
    c("female__male", "female__male", "female__male", "female__male",
      "female__female", "female__female", "female__female", "female__female")
  )
  expect_equal(
    as.character(result$.i_composition_role),
    c("female__male__female", "female__male__male",
      "female__male__female", "female__male__male",
      "female__female", "female__female", "female__female", "female__female")
  )
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

  result <- infer_dyad_compositions(validated)

  expect_true(".i_is_female_partner__male_partner__female_partner" %in% names(result))
  expect_true(".i_is_female_partner__male_partner__male_partner" %in% names(result))
})

test_that("infer_dyad_compositions treats missing role metadata as unclassified", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  validated <- validate_interdep_data(data, group = dyad_id, member = person_id)
  result <- infer_dyad_compositions(validated)

  expect_false(".i_raw_composition" %in% names(result))
  expect_true(is.factor(result$.i_composition))
  expect_true(is.factor(result$.i_composition_role))
  expect_equal(result$.i_is_assumed_exchangeable, rep(1, 4))
  expect_equal(
    as.character(result$.i_composition),
    rep(interdep_assumed_exchangeable_label, 4)
  )
  expect_equal(
    as.character(result$.i_composition_role),
    rep(interdep_assumed_exchangeable_label, 4)
  )
  expect_equal(
    attr(result, "interdep")$dyad_compositions,
    tibble::tibble(
      raw_composition = interdep_assumed_exchangeable_label,
      composition = interdep_assumed_exchangeable_label,
      dyad_type = "exchangeable",
      n_dyads = 2L
    )
  )
})
