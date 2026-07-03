test_that("prepare_interdep_data returns validated data with dyad composition metadata", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2, 3, 3),
    person_id = c("A", "B", "C", "D", "E", "F"),
    role = c("female", "male", "female", "female", "male", "male")
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role
  )

  expect_s3_class(result, "interdep_data")
  expect_s3_class(result, "tbl_df")

  meta <- attr(result, "interdep")
  expect_equal(meta$group, "dyad_id")
  expect_equal(meta$member, "person_id")
  expect_equal(meta$role, "role")
  expect_equal(meta$n_dyads, 3L)

  dyad_compositions <- meta$dyad_compositions
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
  expect_equal(dyad_compositions$n_dyads, c(1L, 1L, 1L))
  expect_false(".interdep_raw_composition" %in% names(result))
  expect_true(is.factor(result$.interdep_composition))
  expect_true(is.factor(result$.interdep_composition_role))
  expect_equal(
    as.character(result$.interdep_composition),
    c("female__male", "female__male", "female__female", "female__female",
      "male__male", "male__male")
  )
  expect_equal(
    as.character(result$.interdep_composition_role),
    c("female__male__female", "female__male__male",
      "female__female", "female__female", "male__male", "male__male")
  )
})

test_that("prepare_interdep_data treats data without role as unclassified exchangeable dyads", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  result <- prepare_interdep_data(data, group = dyad_id, member = person_id)

  expect_false(".interdep_raw_composition" %in% names(result))
  expect_true(is.factor(result$.interdep_composition))
  expect_true(is.factor(result$.interdep_composition_role))
  expect_equal(as.character(result$.interdep_composition), rep("assumed-exchangeable", 4))
  expect_equal(as.character(result$.interdep_composition_role), rep("assumed-exchangeable", 4))
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

test_that("prepare_interdep_data rejects reserved interdep columns", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    .interdep_composition = c("x", "x", "y", "y")
  )

  expect_error(
    prepare_interdep_data(data, group = dyad_id, member = person_id),
    "columns starting with `.interdep_`",
    fixed = TRUE
  )
})

test_that("prepare_interdep_data rejects role labels containing the internal separator", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "non__binary", "female", "male")
  )

  expect_error(
    prepare_interdep_data(data, group = dyad_id, member = person_id, role = role),
    "`role` values must not contain `__`",
    fixed = TRUE
  )
})

test_that("prepare_interdep_data infers compositions from sparse longitudinal roles", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    role = c("female", "male", NA, NA, "female", "male", NA, NA),
    time = c(1, 1, 2, 2, 1, 1, 2, 2)
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role,
    time = time
  )

  expect_equal(as.character(result$.interdep_composition), rep("female__male", 8))
  expect_equal(
    as.character(result$.interdep_composition_role),
    rep(c("female__male__female", "female__male__male"), 4)
  )
})

test_that("prepare_interdep_data marks retained unknown roles in compositions", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", NA, "female", "male")
  )

  expect_warning(
    result <- prepare_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      role = role,
      missing_role = "keep"
    ),
    "Keeping 1 dyad with incomplete role information, with ID: 1.",
    fixed = TRUE
  )

  expect_equal(
    as.character(result$.interdep_composition),
    c("female__unknown", "female__unknown", "female__male", "female__male")
  )
  expect_equal(
    as.character(result$.interdep_composition_role),
    c(
      "female__unknown__female",
      "female__unknown__unknown",
      "female__male__female",
      "female__male__male"
    )
  )

  dyad_compositions <- attr(result, "interdep")$dyad_compositions
  dyad_compositions <- dyad_compositions[order(dyad_compositions$composition), ]

  expect_equal(dyad_compositions$composition, c("female__male", "female__unknown"))
  expect_equal(dyad_compositions$dyad_type, c("distinguishable", "unknown"))
})

test_that("prepare_interdep_data marks retained incomplete dyads in compositions", {
  data <- data.frame(
    dyad_id = c(1, 2, 2, 3, 3),
    person_id = c("A", "C", "D", "E", "F"),
    role = c("female", "female", "male", "female", "female")
  )

  expect_warning(
    result <- prepare_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      role = role,
      incomplete_dyads = "keep"
    ),
    "Keeping 1 incomplete dyad, with ID: 1.",
    fixed = TRUE
  )

  expect_equal(
    as.character(result$.interdep_composition),
    c("female__unknown", "female__male", "female__male", "female__female", "female__female")
  )
  expect_equal(
    as.character(result$.interdep_composition_role),
    c(
      "female__unknown__female",
      "female__male__female",
      "female__male__male",
      "female__female",
      "female__female"
    )
  )

  dyad_compositions <- attr(result, "interdep")$dyad_compositions
  dyad_compositions <- dyad_compositions[order(dyad_compositions$composition), ]

  expect_equal(
    dyad_compositions$composition,
    c("female__female", "female__male", "female__unknown")
  )
  expect_equal(
    dyad_compositions$dyad_type,
    c("exchangeable", "distinguishable", "unknown")
  )
})
