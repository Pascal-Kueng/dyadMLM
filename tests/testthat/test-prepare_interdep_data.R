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
  expect_equal(dyad_compositions$n_dyads, c(1L, 1L, 1L))
  expect_false(".i_raw_composition" %in% names(result))
  expect_true(is.factor(result$.i_composition))
  expect_true(is.factor(result$.i_composition_role))
  indicator_names <- grep("^\\.i_is_", names(result), value = TRUE)
  expect_equal(rowSums(result[indicator_names]), rep(1, nrow(result)))
  expect_equal(
    as.character(result$.i_composition),
    c("female_x_male", "female_x_male", "female_x_female", "female_x_female",
      "male_x_male", "male_x_male")
  )
  expect_equal(
    as.character(result$.i_composition_role),
    c("female_x_male_female", "female_x_male_male",
      "female_x_female", "female_x_female", "male_x_male", "male_x_male")
  )
})

test_that("prepare_interdep_data treats data without role as unclassified exchangeable dyads", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  result <- prepare_interdep_data(data, group = dyad_id, member = person_id)

  expect_false(".i_raw_composition" %in% names(result))
  expect_true(is.factor(result$.i_composition))
  expect_true(is.factor(result$.i_composition_role))
  expect_equal(result$.i_is_assumed_exchangeable, rep(1, 4))
  expect_equal(as.character(result$.i_composition), rep("assumed_exchangeable", 4))
  expect_equal(as.character(result$.i_composition_role), rep("assumed_exchangeable", 4))
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

test_that("prepare_interdep_data rejects reserved interdep columns", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    .i_composition = c("x", "x", "y", "y")
  )

  expect_error(
    prepare_interdep_data(data, group = dyad_id, member = person_id),
    "columns starting with `.i_`",
    fixed = TRUE
  )
})

test_that("prepare_interdep_data rejects role labels containing the internal separator", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "non_x_binary", "female", "male")
  )

  expect_error(
    prepare_interdep_data(data, group = dyad_id, member = person_id, role = role),
    "`role` values must not contain `_x_`",
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

  expect_equal(as.character(result$.i_composition), rep("female_x_male", 8))
  expect_equal(
    as.character(result$.i_composition_role),
    rep(c("female_x_male_female", "female_x_male_male"), 4)
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
    as.character(result$.i_composition),
    c("female_x_unknown", "female_x_unknown", "female_x_male", "female_x_male")
  )
  expect_equal(
    as.character(result$.i_composition_role),
    c(
      "female_x_unknown_female",
      "female_x_unknown_unknown",
      "female_x_male_female",
      "female_x_male_male"
    )
  )

  dyad_compositions <- attr(result, "interdep")$dyad_compositions
  dyad_compositions <- dyad_compositions[order(dyad_compositions$composition), ]

  expect_equal(dyad_compositions$composition, c("female_x_male", "female_x_unknown"))
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
    as.character(result$.i_composition),
    c("female_x_unknown", "female_x_male", "female_x_male", "female_x_female", "female_x_female")
  )
  expect_equal(
    as.character(result$.i_composition_role),
    c(
      "female_x_unknown_female",
      "female_x_male_female",
      "female_x_male_male",
      "female_x_female",
      "female_x_female"
    )
  )

  dyad_compositions <- attr(result, "interdep")$dyad_compositions
  dyad_compositions <- dyad_compositions[order(dyad_compositions$composition), ]

  expect_equal(
    dyad_compositions$composition,
    c("female_x_female", "female_x_male", "female_x_unknown")
  )
  expect_equal(
    dyad_compositions$dyad_type,
    c("exchangeable", "distinguishable", "unknown")
  )
})
