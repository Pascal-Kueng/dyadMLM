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
  expect_true(".interdep_raw_composition" %in% names(result))
  expect_true(".interdep_composition" %in% names(result))
  expect_true(".interdep_composition_role" %in% names(result))

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
    result$.interdep_raw_composition,
    c("female__male", "female__male", "female__male", "female__male",
      "female__female", "female__female", "male__male", "male__male")
  )
  expect_equal(result$.interdep_composition, result$.interdep_raw_composition)
  expect_equal(
    result$.interdep_composition_role,
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

  expect_equal(dyad_compositions$raw_composition, c("female__female", "female__male"))
  expect_equal(dyad_compositions$composition, c("female__female", "female__male"))
  expect_equal(dyad_compositions$dyad_type, c("exchangeable", "distinguishable"))
  expect_equal(dyad_compositions$n_dyads, c(1L, 1L))
  expect_equal(
    result$.interdep_raw_composition,
    c("female__male", "female__male", "female__male", "female__male",
      "female__female", "female__female", "female__female", "female__female")
  )
  expect_equal(result$.interdep_composition, result$.interdep_raw_composition)
  expect_equal(
    result$.interdep_composition_role,
    c("female__male__female", "female__male__male",
      "female__male__female", "female__male__male",
      "female__female", "female__female", "female__female", "female__female")
  )
})

test_that("infer_dyad_compositions treats missing role metadata as unclassified", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  validated <- validate_interdep_data(data, group = dyad_id, member = person_id)
  result <- infer_dyad_compositions(validated)

  expect_equal(
    result$.interdep_raw_composition,
    rep("assumed-exchangeable", 4)
  )
  expect_equal(
    result$.interdep_composition,
    rep("assumed-exchangeable", 4)
  )
  expect_equal(
    result$.interdep_composition_role,
    rep("assumed-exchangeable", 4)
  )
  expect_equal(
    attr(result, "interdep")$dyad_compositions,
    tibble::tibble(
      raw_composition = "assumed-exchangeable",
      composition = "assumed-exchangeable",
      dyad_type = "exchangeable",
      n_dyads = 2L
    )
  )
})
