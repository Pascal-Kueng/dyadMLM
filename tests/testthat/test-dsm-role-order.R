test_that("DSM role order is required exactly with DSM preparation", {
  distinguishable_data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male")
  )

  expect_error(
    validate_dyad_data(
      distinguishable_data,
      group = dyad_id,
      member = person_id,
      role = role,
      model_type = "dsm"
    ),
    paste0(
      '`model_type = "dsm"` requires `dsm_role_order` to be supplied. ',
      'For exchangeable dyads, use `model_type = "dim"` instead.'
    ),
    fixed = TRUE
  )

  expect_error(
    validate_dyad_data(
      distinguishable_data,
      group = dyad_id,
      member = person_id,
      role = role,
      dsm_role_order = c("female", "male")
    ),
    '`dsm_role_order` can only be supplied when `model_type` includes "dsm".',
    fixed = TRUE
  )

  no_role_data <- distinguishable_data[c("dyad_id", "person_id")]
  expect_error(
    validate_dyad_data(
      no_role_data,
      group = dyad_id,
      member = person_id,
      model_type = "dsm"
    ),
    '`model_type = "dsm"` requires `role` to be supplied.',
    fixed = TRUE
  )

  expect_error(
    validate_dyad_data(
      no_role_data,
      group = dyad_id,
      member = person_id,
      model_type = "dsm",
      dsm_role_order = c("female", "male")
    ),
    '`model_type = "dsm"` requires `role` to be supplied.',
    fixed = TRUE
  )
})

test_that("DIM and DSM cannot be requested together", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male")
  )

  expect_error(
    prepare_dyad_data(
      data,
      group = dyad_id,
      member = person_id,
      role = role,
      model_type = c("dim", "dsm"),
      dsm_role_order = c("female", "male")
    ),
    '`model_type = "dim"` and `model_type = "dsm"` cannot be combined.',
    fixed = TRUE
  )
})

test_that("DSM role order contains two distinct role values", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male")
  )

  invalid_orders <- list(
    "female",
    c("female", "female"),
    c("female", NA_character_),
    c("female", " "),
    c("female", " female "),
    c(1, 2)
  )
  expected_message <- paste0(
    "`dsm_role_order` must be a character vector containing exactly two ",
    "distinct, non-missing, non-empty role values, for example ",
    "`c(\"male\", \"female\")`."
  )

  for (role_order in invalid_orders) {
    error <- tryCatch(
      validate_dyad_data(
        data,
        group = dyad_id,
        member = person_id,
        role = role,
        model_type = "dsm",
        dsm_role_order = role_order
      ),
      error = identity
    )
    expect_identical(conditionMessage(error), expected_message)
  }
})

test_that("DSM role order is stored and matched to the final composition", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male")
  )

  result <- prepare_dyad_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role,
    model_type = "dsm",
    dsm_role_order = c("male", "female")
  )

  expect_equal(attr(result, "dyadMLM")$dsm_role_order, c("male", "female"))
  expect_equal(attr(result, "dyadMLM")$dyad_compositions$dyad_type, "distinguishable")

  trimmed_result <- prepare_dyad_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role,
    model_type = "dsm",
    dsm_role_order = c(" male ", " female ")
  )
  expect_equal(
    attr(trimmed_result, "dyadMLM")$dsm_role_order,
    c("male", "female")
  )

  expect_error(
    prepare_dyad_data(
      data,
      group = dyad_id,
      member = person_id,
      role = role,
      model_type = "dsm",
      dsm_role_order = c("female", "other")
    ),
    "`dsm_role_order` must contain exactly the two role values in the prepared DSM data.",
    fixed = TRUE
  )
})

test_that("DSM requires one distinguishable final composition", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male")
  )

  expect_error(
    prepare_dyad_data(
      data,
      group = dyad_id,
      member = person_id,
      role = role,
      model_type = "dsm",
      dsm_role_order = c("female", "male"),
      set_exchangeable_compositions = "female-male"
    ),
    "DSM currently supports only data with exactly one distinguishable dyad composition.",
    fixed = TRUE
  )

  exchangeable_data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = rep("female", 4)
  )

  expect_error(
    prepare_dyad_data(
      exchangeable_data,
      group = dyad_id,
      member = person_id,
      role = role,
      model_type = "dsm",
      dsm_role_order = c("female", "male")
    ),
    "If the intended dyads are exchangeable, use `model_type = \"dim\"` instead.",
    fixed = TRUE
  )
})

test_that("DSM rejects multiple distinguishable compositions actionably", {
  data <- data.frame(
    dyad_id = rep(1:4, each = 2),
    person_id = LETTERS[1:8],
    role = c(
      "female", "male",
      "female", "male",
      "nonbinary", "male",
      "nonbinary", "male"
    )
  )

  expect_error(
    prepare_dyad_data(
      data,
      group = dyad_id,
      member = person_id,
      role = role,
      model_type = "dsm",
      dsm_role_order = c("female", "male")
    ),
    "Use `include_compositions` to retain one distinguishable composition, or prepare compositions in separate calls.",
    fixed = TRUE
  )
})
