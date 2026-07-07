test_that("validate_interdep_data returns an interdep tibble", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c(1, 2, 3, 4),
    x = 1:4
  )

  result <- validate_interdep_data(data, group = dyad_id, member = person_id)

  expect_s3_class(result, "interdep_data")
  expect_s3_class(result, "tbl_df")
  expect_equal(result$dyad_id, c(1, 1, 2, 2))
  expect_equal(result$person_id, c(1, 2, 3, 4))
  expect_equal(result$x, 1:4)
})

test_that("validate_interdep_data stores input metadata", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  result <- validate_interdep_data(data, group = dyad_id, member = person_id)
  meta <- attr(result, "interdep")

  expect_equal(meta$group, "dyad_id")
  expect_equal(meta$member, "person_id")
  expect_null(meta$role)
  expect_null(meta$time)
  expect_null(meta$predictors)
  expect_equal(meta$model_type, "apim")
  expect_equal(meta$centering, "none")
  expect_equal(meta$n_dyads, 2L)
  expect_false(meta$longitudinal)
  expect_equal(meta$dropped_incomplete_dyads, numeric(0))
  expect_equal(meta$dropped_missing_role_dyads, numeric(0))
})

test_that("validate_interdep_data stores predictor metadata", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = 1:4,
    z = 5:8
  )

  single <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    predictors = x
  )
  expect_equal(attr(single, "interdep")$predictors, "x")

  multiple <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    predictors = c(x, z)
  )
  expect_equal(attr(multiple, "interdep")$predictors, c("x", "z"))
})

test_that("validate_interdep_data resolves model helper metadata", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = 1:8
  )

  result <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    time = time,
    predictors = x,
    model_type = "dim"
  )

  meta <- attr(result, "interdep")

  expect_equal(meta$model_type, "dim")
  expect_equal(meta$centering, "time_2l")
})

test_that("validate_interdep_data validates explicit time_2l centering", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = 1:4
  )

  expect_error(
    validate_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      predictors = x,
      centering = "time_2l"
    ),
    '`centering = "time_2l"` requires `time` to be supplied.',
    fixed = TRUE
  )

  expect_error(
    validate_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      time = x,
      centering = "time_2l"
    ),
    '`centering = "time_2l"` requires `predictors` to be supplied.',
    fixed = TRUE
  )
})

test_that("validate_interdep_data rejects non-data-frame input", {
  expect_error(
    validate_interdep_data(1:3, group = dyad_id, member = person_id),
    "`data` must be a data frame or tibble.",
    fixed = TRUE
  )
})

test_that("validate_interdep_data requires group and member arguments", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  expect_error(
    validate_interdep_data(data, member = person_id),
    "`group` must be supplied.",
    fixed = TRUE
  )

  expect_error(
    validate_interdep_data(data, group = dyad_id),
    "`member` must be supplied.",
    fixed = TRUE
  )
})

test_that("validate_interdep_data rejects missing columns", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  expect_error(
    validate_interdep_data(data, group = missing_group, member = person_id),
    "`group` must refer to an existing column in `data`.",
    fixed = TRUE
  )

  expect_error(
    validate_interdep_data(data, group = dyad_id, member = missing_member),
    "`member` must refer to an existing column in `data`.",
    fixed = TRUE
  )

  expect_error(
    validate_interdep_data(data, group = dyad_id, member = person_id, role = missing_role),
    "`role` must refer to an existing column in `data`.",
    fixed = TRUE
  )

  expect_error(
    validate_interdep_data(data, group = dyad_id, member = person_id, time = missing_time),
    "`time` must refer to an existing column in `data`.",
    fixed = TRUE
  )

  expect_error(
    validate_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      predictors = missing_predictor
    ),
    "`predictors` must refer to existing columns in `data`.",
    fixed = TRUE
  )
})

test_that("validate_interdep_data rejects missing grouping values", {
  expect_error(
    validate_interdep_data(
      data.frame(dyad_id = c(1, NA, 2, 2), person_id = c("A", "B", "C", "D")),
      group = dyad_id,
      member = person_id
    ),
    "`group` must not contain missing values.",
    fixed = TRUE
  )

  expect_error(
    validate_interdep_data(
      data.frame(dyad_id = c(1, 1, 2, 2), person_id = c("A", NA, "C", "D")),
      group = dyad_id,
      member = person_id
    ),
    "`member` must not contain missing values.",
    fixed = TRUE
  )

  expect_error(
    validate_interdep_data(
      data.frame(
        dyad_id = c(1, 1, 2, 2),
        person_id = c("A", "B", "C", "D"),
        time = c(1, NA, 1, 1)
      ),
      group = dyad_id,
      member = person_id,
      time = time
    ),
    "`time` must not contain missing values.",
    fixed = TRUE
  )

  expect_error(
    validate_interdep_data(
      data.frame(
        dyad_id = c(1, 1, 2, 2),
        person_id = c("A", "B", "C", "D"),
        role = c("female", NA, "female", "male")
      ),
      group = dyad_id,
      member = person_id,
      role = role
    ),
    "Each `member` must have at least one non-missing `role` within each `group`.",
    fixed = TRUE
  )
})

test_that("validate_interdep_data rejects duplicate members within group-time", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2),
    person_id = c("A", "B", "A", "A", "C", "D"),
    time = c(1, 1, 2, 2, 1, 1)
  )

  expect_error(
    validate_interdep_data(data, group = dyad_id, member = person_id, time = time),
    "Each `member` must appear at most once per `group`-`time` combination.",
    fixed = TRUE
  )
})

test_that("validate_interdep_data accepts absent longitudinal occasions", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "B", "C", "D", "C", "D"),
    time = c(1, 1, 2, 1, 1, 2, 2)
  )

  result <- validate_interdep_data(data, group = dyad_id, member = person_id, time = time)

  expect_equal(nrow(result), 7L)
  expect_true(attr(result, "interdep")$longitudinal)
  expect_equal(attr(result, "interdep")$n_dyads, 2L)
})

test_that("validate_interdep_data rejects groups without two unique members", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "A", "C", "D")
  )

  expect_error(
    validate_interdep_data(data, group = dyad_id, member = person_id),
    "Each `group` must contain exactly two unique members.",
    fixed = TRUE
  )
})

test_that("validate_interdep_data handles incomplete dyads by policy", {
  data <- data.frame(
    dyad_id = c(1, 2, 2, 3, 3),
    person_id = c("A", "C", "D", "E", "F"),
    role = c("female", "female", "male", "female", "female")
  )

  expect_error(
    validate_interdep_data(data, group = dyad_id, member = person_id, role = role),
    "Found 1 incomplete dyad, with ID: 1.",
    fixed = TRUE
  )

  expect_message(
    dropped <- validate_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      role = role,
      incomplete_dyads = "drop"
    ),
    "Dropped 1 incomplete dyad, with ID: 1.",
    fixed = TRUE
  )
  expect_equal(dropped$dyad_id, c(2, 2, 3, 3))
  expect_equal(attr(dropped, "interdep")$n_dyads, 2L)
  expect_equal(attr(dropped, "interdep")$dropped_incomplete_dyads, 1)
  expect_equal(attr(dropped, "interdep")$dropped_missing_role_dyads, numeric(0))
})

test_that("validate_interdep_data rejects groups with more than two members", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 2, 2),
    person_id = c("A", "B", "C", "D", "E")
  )

  expect_error(
    validate_interdep_data(data, group = dyad_id, member = person_id, incomplete_dyads = "drop"),
    "Found 1 group with more than two members, with ID: 1.",
    fixed = TRUE
  )
})

test_that("validate_interdep_data stores role metadata", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male")
  )

  result <- validate_interdep_data(data, group = dyad_id, member = person_id, role = role)

  expect_equal(attr(result, "interdep")$role, "role")
})

test_that("validate_interdep_data accepts stable longitudinal roles", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 2, 2, 2),
    person_id = c("A", "B", "A", "C", "D", "C"),
    role = c("female", "male", "female", "female", "male", "female"),
    time = c(1, 1, 2, 1, 1, 2)
  )

  result <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role,
    time = time
  )

  expect_equal(attr(result, "interdep")$role, "role")
})

test_that("validate_interdep_data resolves sparse longitudinal roles", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    role = c("female", "male", NA, NA, "female", "male", NA, NA),
    time = c(1, 1, 2, 2, 1, 1, 2, 2)
  )

  result <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role,
    time = time
  )

  expect_equal(
    result$role,
    c("female", "male", "female", "male", "female", "male", "female", "male")
  )
})

test_that("validate_interdep_data rejects inconsistent roles within member", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 2, 2, 2),
    person_id = c("A", "B", "A", "C", "D", "C"),
    role = c("female", "male", "male", "female", "male", "female"),
    time = c(1, 1, 2, 1, 1, 2)
  )

  expect_error(
    validate_interdep_data(data, group = dyad_id, member = person_id, role = role, time = time),
    "Each `member` must have exactly one `role` within each `group`.",
    fixed = TRUE
  )
})

test_that("validate_interdep_data handles missing roles by policy", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2, 3, 3),
    person_id = c("A", "B", "C", "D", "E", "F"),
    role = c("female", NA, "female", "male", "female", "female")
  )

  expect_error(
    validate_interdep_data(data, group = dyad_id, member = person_id, role = role),
    "Each `member` must have at least one non-missing `role` within each `group`.",
    fixed = TRUE
  )

  expect_message(
    dropped <- validate_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      role = role,
      missing_role = "drop"
    ),
    "Dropped 1 dyad with incomplete role information, with ID: 1.",
    fixed = TRUE
  )

  expect_equal(dropped$dyad_id, c(2, 2, 3, 3))
  expect_equal(attr(dropped, "interdep")$n_dyads, 2L)
  expect_equal(attr(dropped, "interdep")$dropped_missing_role_dyads, 1)
  expect_equal(attr(dropped, "interdep")$dropped_incomplete_dyads, numeric(0))
})

test_that("validate_interdep_data rejects fewer than two groups", {
  data <- data.frame(
    dyad_id = c(1, 1),
    person_id = c("A", "B")
  )

  expect_error(
    validate_interdep_data(data, group = dyad_id, member = person_id),
    "At least 2 groups are needed.",
    fixed = TRUE
  )
})

test_that("validate_interdep_data rejects duplicate cross-sectional member rows", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 2, 2),
    person_id = c("A", "B", "A", "C", "D")
  )

  expect_error(
    validate_interdep_data(data, group = dyad_id, member = person_id),
    "Each `member` must appear at most once per `group`. For longitudinal data specify `time`.",
    fixed = TRUE
  )
})

test_that("validate_interdep_data allows one missing member within group-time", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 2, 2, 2),
    person_id = c("A", "B", "A", "C", "D", "C"),
    time = c(1, 1, 2, 1, 1, 2)
  )

  result <- validate_interdep_data(data, group = dyad_id, member = person_id, time = time)
  meta <- attr(result, "interdep")

  expect_s3_class(result, "interdep_data")
  expect_equal(nrow(result), 6)
  expect_equal(meta$group, "dyad_id")
  expect_equal(meta$member, "person_id")
  expect_null(meta$role)
  expect_equal(meta$time, "time")
  expect_equal(meta$n_dyads, 2L)
  expect_true(meta$longitudinal)
})
