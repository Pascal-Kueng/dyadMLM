test_that("validate_interdep_data has no outcome-selection argument", {
  expect_false("outcomes" %in% names(formals(validate_interdep_data)))
})

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
  expect_null(meta$lag_predictors)
  expect_equal(meta$model_type, "apim")
  expect_equal(meta$temporal_predictor_decomposition, "none")
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

test_that("validate_interdep_data resolves lag predictor metadata", {
  data <- data.frame(
    dyad_id = rep(1:2, each = 4),
    person_id = rep(c("A", "B"), 4),
    time = rep(rep(1:2, each = 2), 2),
    x = 1:8,
    z = 11:18
  )

  result <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    time = time,
    predictors = c(x, z),
    lag_predictors = dplyr::starts_with("x")
  )

  expect_equal(attr(result, "interdep")$lag_predictors, "x")
})

test_that("validate_interdep_data checks lag predictor arguments", {
  longitudinal <- data.frame(
    dyad_id = rep(1:2, each = 4),
    person_id = rep(c("A", "B"), 4),
    time = rep(rep(1:2, each = 2), 2),
    x = 1:8,
    z = 11:18
  )

  expect_error(
    validate_interdep_data(
      longitudinal,
      group = dyad_id,
      member = person_id,
      time = time,
      predictors = x,
      lag_predictors = z
    ),
    "`lag_predictors` must select only variables already selected by `predictors`.",
    fixed = TRUE
  )

  expect_error(
    validate_interdep_data(
      longitudinal,
      group = dyad_id,
      member = person_id,
      predictors = x,
      lag_predictors = x
    ),
    "`lag_predictors` requires `time` to be supplied.",
    fixed = TRUE
  )

  non_integer_time <- dplyr::mutate(longitudinal, time = .data$time / 2)
  expect_error(
    validate_interdep_data(
      non_integer_time,
      group = dyad_id,
      member = person_id,
      time = time,
      predictors = x,
      lag_predictors = x
    ),
    "`lag_predictors` requires `time` to be a finite, integer-valued numeric measurement index.",
    fixed = TRUE
  )

  character_time <- dplyr::mutate(longitudinal, time = as.character(.data$time))
  expect_error(
    validate_interdep_data(
      character_time,
      group = dyad_id,
      member = person_id,
      time = time,
      predictors = x,
      lag_predictors = x
    ),
    "`lag_predictors` requires `time` to be a finite, integer-valued numeric measurement index.",
    fixed = TRUE
  )
})

test_that("validate_interdep_data rejects predictor suffix collisions", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    "x-a" = 1:4,
    "x a" = 5:8,
    check.names = FALSE
  )

  expect_error(
    validate_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      predictors = c(`x-a`, `x a`)
    ),
    "Some `predictors` would create the same generated column-name suffix",
    fixed = TRUE
  )
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
  expect_equal(meta$temporal_predictor_decomposition, "time_2l")
})

test_that("validate_interdep_data accepts multiple model types", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = 1:4
  )

  result <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    predictors = x,
    model_type = c("apim", "dim")
  )

  expect_equal(attr(result, "interdep")$model_type, c("apim", "dim"))
})

test_that("validate_interdep_data validates incompatible model type requests", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = 1:4,
    y = 5:8
  )

  expect_error(
    validate_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      model_type = NULL
    ),
    "`model_type` must be a non-empty character vector without missing values.",
    fixed = TRUE
  )

  expect_error(
    validate_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      model_type = character()
    ),
    "`model_type` must be a non-empty character vector without missing values.",
    fixed = TRUE
  )

  expect_error(
    validate_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      model_type = NA_character_
    ),
    "`model_type` must be a non-empty character vector without missing values.",
    fixed = TRUE
  )

  expect_error(
    validate_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      model_type = 1
    ),
    "`model_type` must be a non-empty character vector without missing values.",
    fixed = TRUE
  )

  expect_error(
    validate_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      model_type = "asdkfjakdfj"
    ),
    'Invalid value(s): "asdkfjakdfj".',
    fixed = TRUE
  )

  expect_error(
    validate_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      model_type = "a"
    ),
    'Invalid value(s): "a".',
    fixed = TRUE
  )

  expect_error(
    validate_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      model_type = c("apim", "none")
    ),
    '`model_type = "none"` cannot be combined with other model types.',
    fixed = TRUE
  )

})

test_that("validate_interdep_data validates explicit time_2l temporal predictor decomposition", {
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
      temporal_predictor_decomposition = "time_2l"
    ),
    '`temporal_predictor_decomposition = "time_2l"` requires `time` to be supplied.',
    fixed = TRUE
  )

  expect_error(
    validate_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      time = x,
      temporal_predictor_decomposition = "time_2l"
    ),
    '`temporal_predictor_decomposition = "time_2l"` requires `predictors` to be supplied.',
    fixed = TRUE
  )
})

test_that("validate_interdep_data rejects non-numeric time_2l predictors", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = letters[1:8]
  )

  expect_error(
    validate_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      time = time,
      predictors = x
    ),
    "only when the selected `model_type` allows undecomposed non-numeric predictors.",
    fixed = TRUE
  )
})

test_that("validate_interdep_data rejects non-numeric DIM and DSM predictors", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male"),
    x = factor(c("low", "high", "low", "high"))
  )

  expect_error(
    validate_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      predictors = x,
      model_type = "dim",
      temporal_predictor_decomposition = "none"
    ),
    '`predictors` used with `model_type = "dim"` or `model_type = "dsm"` must be numeric.',
    fixed = TRUE
  )

  expect_error(
    validate_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      role = role,
      predictors = x,
      model_type = "dsm",
      dsm_role_order = c("female", "male"),
      temporal_predictor_decomposition = "none"
    ),
    '`predictors` used with `model_type = "dim"` or `model_type = "dsm"` must be numeric.',
    fixed = TRUE
  )
})

test_that("validate_interdep_data allows non-numeric uncentered predictors", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = factor(c("low", "high", "low", "high"))
  )

  result <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    predictors = x,
    temporal_predictor_decomposition = "none"
  )

  expect_equal(attr(result, "interdep")$predictors, "x")
  expect_equal(attr(result, "interdep")$temporal_predictor_decomposition, "none")
})

test_that("validate_interdep_data rejects non-data-frame input", {
  expect_error(
    validate_interdep_data(1:3, group = dyad_id, member = person_id),
    "`data` must be a data frame or tibble.",
    fixed = TRUE
  )
})

test_that("validate_interdep_data rejects already validated input", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  validated <- validate_interdep_data(data, group = dyad_id, member = person_id)

  expect_error(
    validate_interdep_data(validated, group = dyad_id, member = person_id),
    "`data` has already been prepared by interdep.",
    fixed = TRUE
  )
})

test_that("validate_interdep_data rejects reserved interdep columns", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    .i_composition = c("x", "x", "y", "y")
  )

  expect_error(
    validate_interdep_data(data, group = dyad_id, member = person_id),
    "columns starting with `.i_`",
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
    "`predictors` must select columns from `data`.",
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
    "Fill in `role` values or use `missing_role = \"drop\"` to drop these dyads.",
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
    "`dyad_id` = 1, `time` = 2, `person_id` = A",
    fixed = TRUE
  )

  date_data <- data
  date_data$time <- as.Date("2026-01-01") + date_data$time
  expect_error(
    validate_interdep_data(
      date_data,
      group = dyad_id,
      member = person_id,
      time = time
    ),
    "`time` = 2026-01-03",
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
    paste0(
      "Found 1 incomplete dyad, with ID: 1. Add the missing member rows or ",
      "use `incomplete_dyads = \"drop\"` to drop these dyads."
    ),
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

test_that("validate_interdep_data rejects role labels with reserved separator", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female_x_male", "other", "female", "male")
  )

  expect_error(
    validate_interdep_data(data, group = dyad_id, member = person_id, role = role),
    "`role` values must not contain `_x_`",
    fixed = TRUE
  )
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

test_that("validate_interdep_data preserves the role column type", {
  factor_data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    role = ordered(
      c("junior", "senior", NA, NA, "junior", "senior", NA, NA),
      levels = c("junior", "senior")
    ),
    time = c(1, 1, 2, 2, 1, 1, 2, 2)
  )

  factor_result <- validate_interdep_data(
    factor_data,
    group = dyad_id,
    member = person_id,
    role = role,
    time = time
  )

  expect_identical(class(factor_result$role), class(factor_data$role))
  expect_identical(levels(factor_result$role), levels(factor_data$role))
  expect_equal(
    as.character(factor_result$role),
    c("junior", "senior", "junior", "senior", "junior", "senior", "junior", "senior")
  )

  date_data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = as.Date(c("2026-01-01", "2026-01-02", "2026-01-01", "2026-01-02"))
  )

  date_result <- validate_interdep_data(
    date_data,
    group = dyad_id,
    member = person_id,
    role = role
  )

  expect_identical(date_result$role, date_data$role)
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
    "`dyad_id` = 1, `person_id` = A",
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
    "Fill in `role` values or use `missing_role = \"drop\"` to drop these dyads.",
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
    "At least 2 complete dyads are required after validation and any requested dropping.",
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
    "`dyad_id` = 1, `person_id` = A",
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
