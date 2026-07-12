test_that("DSM role order is required exactly with DSM preparation", {
  distinguishable_data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male")
  )

  expect_error(
    validate_interdep_data(
      distinguishable_data,
      group = dyad_id,
      member = person_id,
      role = role,
      model_type = "dsm"
    ),
    '`model_type = "dsm"` requires `dsm_role_order` to be supplied.',
    fixed = TRUE
  )

  expect_error(
    validate_interdep_data(
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
    validate_interdep_data(
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
    c(1, 2)
  )

  for (role_order in invalid_orders) {
    expect_error(
      validate_interdep_data(
        data,
        group = dyad_id,
        member = person_id,
        role = role,
        model_type = "dsm",
        dsm_role_order = role_order
      ),
      "`dsm_role_order` must be a character vector",
      fixed = TRUE
    )
  }
})

test_that("DSM role order is stored and matched to the final composition", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male")
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role,
    model_type = "dsm",
    dsm_role_order = c("male", "female")
  )

  expect_equal(attr(result, "interdep")$dsm_role_order, c("male", "female"))
  expect_equal(attr(result, "interdep")$dyad_compositions$dyad_type, "distinguishable")

  expect_error(
    prepare_interdep_data(
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
    prepare_interdep_data(
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
})
