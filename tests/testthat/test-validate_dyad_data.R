test_that("validate_dyad_data has no outcome-selection argument", {
  expect_false("outcomes" %in% names(formals(validate_dyad_data)))
})

test_that("validate_dyad_data returns a dyadMLM tibble", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c(1, 2, 3, 4),
    x = 1:4
  )

  result <- validate_dyad_data(data, dyad = dyad_id, member = person_id)

  expect_s3_class(result, "dyadMLM_data")
  expect_s3_class(result, "tbl_df")
  expect_equal(result$dyad_id, c(1, 1, 2, 2))
  expect_equal(result$person_id, c(1, 2, 3, 4))
  expect_equal(result$x, 1:4)
})

test_that("validate_dyad_data stores input metadata", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  result <- validate_dyad_data(data, dyad = dyad_id, member = person_id)
  meta <- attr(result, "dyadMLM")

  expect_equal(meta$dyad, "dyad_id")
  expect_equal(meta$member, "person_id")
  expect_null(meta$role)
  expect_null(meta$time)
  expect_null(meta$predictors)
  expect_null(meta$lag1_predictors)
  expect_equal(meta$model_types, "apim")
  expect_equal(meta$temporal_decomposition, "none")
  expect_equal(meta$n_dyads, 2L)
  expect_false(meta$longitudinal)
  expect_equal(meta$dropped_incomplete_dyads, numeric(0))
  expect_equal(meta$dropped_missing_role_dyads, numeric(0))
})

test_that("validate_dyad_data stores predictor metadata", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = 1:4,
    z = 5:8
  )

  single <- validate_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    predictors = x
  )
  expect_equal(attr(single, "dyadMLM")$predictors, "x")

  multiple <- validate_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    predictors = c(x, z)
  )
  expect_equal(attr(multiple, "dyadMLM")$predictors, c("x", "z"))
})

test_that("validate_dyad_data resolves lag predictor metadata", {
  data <- data.frame(
    dyad_id = rep(1:2, each = 4),
    person_id = rep(c("A", "B"), 4),
    time = rep(rep(1:2, each = 2), 2),
    x = 1:8,
    z = 11:18
  )

  result <- validate_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    time = time,
    predictors = c(x, z),
    lag1_predictors = dplyr::starts_with("x")
  )

  expect_equal(attr(result, "dyadMLM")$lag1_predictors, "x")
})

test_that("validate_dyad_data checks lag predictor arguments", {
  longitudinal <- data.frame(
    dyad_id = rep(1:2, each = 4),
    person_id = rep(c("A", "B"), 4),
    time = rep(rep(1:2, each = 2), 2),
    x = 1:8,
    z = 11:18
  )

  expect_error(
    validate_dyad_data(
      longitudinal,
      dyad = dyad_id,
      member = person_id,
      time = time,
      predictors = x,
      lag1_predictors = z
    ),
    "`lag1_predictors` must select only variables already selected by `predictors`.",
    fixed = TRUE
  )

  expect_error(
    validate_dyad_data(
      longitudinal,
      dyad = dyad_id,
      member = person_id,
      predictors = x,
      lag1_predictors = x
    ),
    "`lag1_predictors` requires `time` to be supplied.",
    fixed = TRUE
  )

  non_integer_time <- dplyr::mutate(longitudinal, time = .data$time / 2)
  expect_error(
    validate_dyad_data(
      non_integer_time,
      dyad = dyad_id,
      member = person_id,
      time = time,
      predictors = x,
      lag1_predictors = x
    ),
    "`lag1_predictors` requires `time` to be a finite, integer-valued numeric measurement index.",
    fixed = TRUE
  )

  character_time <- dplyr::mutate(longitudinal, time = as.character(.data$time))
  expect_error(
    validate_dyad_data(
      character_time,
      dyad = dyad_id,
      member = person_id,
      time = time,
      predictors = x,
      lag1_predictors = x
    ),
    "`lag1_predictors` requires `time` to be a finite, integer-valued numeric measurement index.",
    fixed = TRUE
  )
})

test_that("validate_dyad_data rejects predictor suffix collisions", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    "x-a" = 1:4,
    "x a" = 5:8,
    check.names = FALSE
  )

  expect_error(
    validate_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      predictors = c(`x-a`, `x a`)
    ),
    "Some `predictors` would create the same generated column-name suffix",
    fixed = TRUE
  )
})

test_that("validate_dyad_data resolves model helper metadata", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = 1:8
  )

  result <- validate_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    time = time,
    predictors = x,
    model_types = "dim"
  )

  meta <- attr(result, "dyadMLM")

  expect_equal(meta$model_types, "dim")
  expect_equal(meta$temporal_decomposition, "2l")
})

test_that("validate_dyad_data accepts multiple model types", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = 1:4
  )

  result <- validate_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    predictors = x,
    model_types = c("apim", "dim")
  )

  expect_equal(attr(result, "dyadMLM")$model_types, c("apim", "dim"))
})

test_that("validate_dyad_data validates incompatible model type requests", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = 1:4,
    y = 5:8
  )

  expect_error(
    validate_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      model_types = NULL
    ),
    "`model_types` must be a non-empty character vector without missing values.",
    fixed = TRUE
  )

  expect_error(
    validate_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      model_types = character()
    ),
    "`model_types` must be a non-empty character vector without missing values.",
    fixed = TRUE
  )

  expect_error(
    validate_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      model_types = NA_character_
    ),
    "`model_types` must be a non-empty character vector without missing values.",
    fixed = TRUE
  )

  expect_error(
    validate_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      model_types = 1
    ),
    "`model_types` must be a non-empty character vector without missing values.",
    fixed = TRUE
  )

  expect_error(
    validate_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      model_types = "asdkfjakdfj"
    ),
    'Invalid value(s): "asdkfjakdfj".',
    fixed = TRUE
  )

  expect_error(
    validate_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      model_types = "a"
    ),
    'Invalid value(s): "a".',
    fixed = TRUE
  )

  expect_error(
    validate_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      model_types = c("apim", "none")
    ),
    '`model_types = "none"` cannot be combined with other model types.',
    fixed = TRUE
  )

})

test_that("validate_dyad_data validates explicit 2l temporal predictor decomposition", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = 1:4
  )

  expect_error(
    validate_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      predictors = x,
      temporal_decomposition = "2l"
    ),
    '`temporal_decomposition = "2l"` requires `time` to be supplied.',
    fixed = TRUE
  )

  expect_error(
    validate_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      time = x,
      temporal_decomposition = "2l"
    ),
    '`temporal_decomposition = "2l"` requires `predictors` to be supplied.',
    fixed = TRUE
  )
})

test_that("validate_dyad_data rejects non-numeric 2l predictors", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = letters[1:8]
  )

  expect_error(
    validate_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      time = time,
      predictors = x
    ),
    "only when the requested model types allow undecomposed non-numeric predictors.",
    fixed = TRUE
  )
})

test_that("validate_dyad_data rejects non-numeric DIM and DSM predictors", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male"),
    x = factor(c("low", "high", "low", "high"))
  )

  expect_error(
    validate_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      predictors = x,
      model_types = "dim",
      temporal_decomposition = "none"
    ),
    '`predictors` used with `model_types = "dim"` or `model_types = "dsm"` must be numeric.',
    fixed = TRUE
  )

  expect_error(
    validate_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      role = role,
      predictors = x,
      model_types = "dsm",
      dsm_role_order = c("female", "male"),
      temporal_decomposition = "none"
    ),
    '`predictors` used with `model_types = "dim"` or `model_types = "dsm"` must be numeric.',
    fixed = TRUE
  )
})

test_that("validate_dyad_data allows non-numeric uncentered predictors", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = factor(c("low", "high", "low", "high"))
  )

  result <- validate_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    predictors = x,
    temporal_decomposition = "none"
  )

  expect_equal(attr(result, "dyadMLM")$predictors, "x")
  expect_equal(attr(result, "dyadMLM")$temporal_decomposition, "none")
})

test_that("validate_dyad_data rejects non-data-frame input", {
  expect_error(
    validate_dyad_data(1:3, dyad = dyad_id, member = person_id),
    "`data` must be a data frame or tibble.",
    fixed = TRUE
  )
})

test_that("validate_dyad_data rejects already validated input", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  validated <- validate_dyad_data(data, dyad = dyad_id, member = person_id)

  expect_error(
    validate_dyad_data(validated, dyad = dyad_id, member = person_id),
    "`data` has already been prepared by dyadMLM.",
    fixed = TRUE
  )
})

test_that("validate_dyad_data rejects reserved dyadMLM columns", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    .dy_composition = c("x", "x", "y", "y")
  )

  expect_error(
    validate_dyad_data(data, dyad = dyad_id, member = person_id),
    "columns starting with `.dy_`",
    fixed = TRUE
  )
})

test_that("validate_dyad_data requires group and member arguments", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  expect_error(
    validate_dyad_data(data, member = person_id),
    "`dyad` must be supplied.",
    fixed = TRUE
  )

  expect_error(
    validate_dyad_data(data, dyad = dyad_id),
    "`member` must be supplied.",
    fixed = TRUE
  )
})

test_that("validate_dyad_data rejects missing columns", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  expect_error(
    validate_dyad_data(data, dyad = missing_group, member = person_id),
    "`dyad` must refer to an existing column in `data`.",
    fixed = TRUE
  )

  expect_error(
    validate_dyad_data(data, dyad = dyad_id, member = missing_member),
    "`member` must refer to an existing column in `data`.",
    fixed = TRUE
  )

  expect_error(
    validate_dyad_data(data, dyad = dyad_id, member = person_id, role = missing_role),
    "`role` must refer to an existing column in `data`.",
    fixed = TRUE
  )

  expect_error(
    validate_dyad_data(data, dyad = dyad_id, member = person_id, time = missing_time),
    "`time` must refer to an existing column in `data`.",
    fixed = TRUE
  )

  expect_error(
    validate_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      predictors = missing_predictor
    ),
    "`predictors` must select columns from `data`.",
    fixed = TRUE
  )
})

test_that("validate_dyad_data rejects missing grouping values", {
  expect_error(
    validate_dyad_data(
      data.frame(dyad_id = c(1, NA, 2, 2), person_id = c("A", "B", "C", "D")),
      dyad = dyad_id,
      member = person_id
    ),
    "`dyad` must not contain missing values.",
    fixed = TRUE
  )

  expect_error(
    validate_dyad_data(
      data.frame(dyad_id = c(1, 1, 2, 2), person_id = c("A", NA, "C", "D")),
      dyad = dyad_id,
      member = person_id
    ),
    "`member` must not contain missing values.",
    fixed = TRUE
  )

  expect_error(
    validate_dyad_data(
      data.frame(
        dyad_id = c(1, 1, 2, 2),
        person_id = c("A", "B", "C", "D"),
        time = c(1, NA, 1, 1)
      ),
      dyad = dyad_id,
      member = person_id,
      time = time
    ),
    "`time` must not contain missing values.",
    fixed = TRUE
  )

  expect_error(
    validate_dyad_data(
      data.frame(
        dyad_id = c(1, 1, 2, 2),
        person_id = c("A", "B", "C", "D"),
        role = c("female", NA, "female", "male")
      ),
      dyad = dyad_id,
      member = person_id,
      role = role
    ),
    "Fill in `role` values or use `missing_role = \"drop\"` to drop these dyads.",
    fixed = TRUE
  )
})

test_that("validate_dyad_data rejects duplicate members within group-time", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2),
    person_id = c("A", "B", "A", "A", "C", "D"),
    time = c(1, 1, 2, 2, 1, 1)
  )

  expect_error(
    validate_dyad_data(data, dyad = dyad_id, member = person_id, time = time),
    "`dyad_id` = 1, `time` = 2, `person_id` = A",
    fixed = TRUE
  )

  date_data <- data
  date_data$time <- as.Date("2026-01-01") + date_data$time
  expect_error(
    validate_dyad_data(
      date_data,
      dyad = dyad_id,
      member = person_id,
      time = time
    ),
    "`time` = 2026-01-03",
    fixed = TRUE
  )
})

test_that("validate_dyad_data accepts absent longitudinal occasions", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "B", "C", "D", "C", "D"),
    time = c(1, 1, 2, 1, 1, 2, 2)
  )

  result <- validate_dyad_data(data, dyad = dyad_id, member = person_id, time = time)

  expect_equal(nrow(result), 7L)
  expect_true(attr(result, "dyadMLM")$longitudinal)
  expect_equal(attr(result, "dyadMLM")$n_dyads, 2L)
})

test_that("validate_dyad_data rejects groups without two unique members", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "A", "C", "D")
  )

  expect_error(
    validate_dyad_data(data, dyad = dyad_id, member = person_id),
    "Each `dyad` must contain exactly two unique members.",
    fixed = TRUE
  )
})

test_that("validate_dyad_data handles incomplete dyads by policy", {
  data <- data.frame(
    dyad_id = c(1, 2, 2, 3, 3),
    person_id = c("A", "C", "D", "E", "F"),
    role = c("female", "female", "male", "female", "female")
  )

  expect_error(
    validate_dyad_data(data, dyad = dyad_id, member = person_id, role = role),
    paste0(
      "Found 1 incomplete dyad, with ID: 1. Add the missing member rows or ",
      "use `incomplete_dyads = \"drop\"` to drop these dyads."
    ),
    fixed = TRUE
  )

  expect_message(
    dropped <- validate_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      role = role,
      incomplete_dyads = "drop"
    ),
    "Dropped 1 incomplete dyad, with ID: 1.",
    fixed = TRUE
  )
  expect_equal(dropped$dyad_id, c(2, 2, 3, 3))
  expect_equal(attr(dropped, "dyadMLM")$n_dyads, 2L)
  expect_equal(attr(dropped, "dyadMLM")$dropped_incomplete_dyads, 1)
  expect_equal(attr(dropped, "dyadMLM")$dropped_missing_role_dyads, numeric(0))
})

test_that("validate_dyad_data rejects groups with more than two members", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 2, 2),
    person_id = c("A", "B", "C", "D", "E")
  )

  expect_error(
    validate_dyad_data(data, dyad = dyad_id, member = person_id, incomplete_dyads = "drop"),
    "Found 1 dyad with more than two members, with ID: 1.",
    fixed = TRUE
  )
})

test_that("validate_dyad_data stores role metadata", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male")
  )

  result <- validate_dyad_data(data, dyad = dyad_id, member = person_id, role = role)

  expect_equal(attr(result, "dyadMLM")$role, "role")
})

test_that("validate_dyad_data rejects role labels with reserved separator", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female_x_male", "other", "female", "male")
  )

  expect_error(
    validate_dyad_data(data, dyad = dyad_id, member = person_id, role = role),
    "`role` values must not contain `_x_`",
    fixed = TRUE
  )
})

test_that("validate_dyad_data accepts stable longitudinal roles", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 2, 2, 2),
    person_id = c("A", "B", "A", "C", "D", "C"),
    role = c("female", "male", "female", "female", "male", "female"),
    time = c(1, 1, 2, 1, 1, 2)
  )

  result <- validate_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role,
    time = time
  )

  expect_equal(attr(result, "dyadMLM")$role, "role")
})

test_that("validate_dyad_data resolves sparse longitudinal roles", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    role = c("female", "male", NA, NA, "female", "male", NA, NA),
    time = c(1, 1, 2, 2, 1, 1, 2, 2)
  )

  result <- validate_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role,
    time = time
  )

  expect_equal(
    result$role,
    c("female", "male", "female", "male", "female", "male", "female", "male")
  )
})

test_that("missing_role handles members unresolved across all repeated rows", {
  data <- data.frame(
    dyad_id = rep(1:3, each = 4),
    person_id = rep(c("A", "B", "A", "B"), 3),
    role = c(
      "female", NA, "female", NA,
      "female", "male", NA, NA,
      "female", "male", NA, NA
    ),
    time = rep(c(1, 1, 2, 2), 3)
  )

  expect_error(
    validate_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      role = role,
      time = time
    ),
    "Each `member` must have at least one non-missing `role` within each `dyad`",
    fixed = TRUE
  )

  expect_message(
    dropped <- validate_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      role = role,
      time = time,
      missing_role = "drop"
    ),
    "Dropped 1 dyad with incomplete role information, with ID: 1.",
    fixed = TRUE
  )
  expect_equal(unique(dropped$dyad_id), c(2, 3))
  expect_false(anyNA(dropped$role))
})

test_that("validate_dyad_data preserves the role column type", {
  factor_data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    role = ordered(
      c("junior", "senior", NA, NA, "junior", "senior", NA, NA),
      levels = c("junior", "senior")
    ),
    time = c(1, 1, 2, 2, 1, 1, 2, 2)
  )

  factor_result <- validate_dyad_data(
    factor_data,
    dyad = dyad_id,
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

  date_result <- validate_dyad_data(
    date_data,
    dyad = dyad_id,
    member = person_id,
    role = role
  )

  expect_identical(date_result$role, date_data$role)
})

test_that("validate_dyad_data rejects inconsistent roles within member", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 2, 2, 2),
    person_id = c("A", "B", "A", "C", "D", "C"),
    role = c("female", "male", "male", "female", "male", "female"),
    time = c(1, 1, 2, 1, 1, 2)
  )

  expect_error(
    validate_dyad_data(data, dyad = dyad_id, member = person_id, role = role, time = time),
    "`dyad_id` = 1, `person_id` = A",
    fixed = TRUE
  )
})

test_that("validate_dyad_data handles missing roles by policy", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2, 3, 3),
    person_id = c("A", "B", "C", "D", "E", "F"),
    role = c("female", NA, "female", "male", "female", "female")
  )

  expect_error(
    validate_dyad_data(data, dyad = dyad_id, member = person_id, role = role),
    "Fill in `role` values or use `missing_role = \"drop\"` to drop these dyads.",
    fixed = TRUE
  )

  expect_message(
    dropped <- validate_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      role = role,
      missing_role = "drop"
    ),
    "Dropped 1 dyad with incomplete role information, with ID: 1.",
    fixed = TRUE
  )

  expect_equal(dropped$dyad_id, c(2, 2, 3, 3))
  expect_equal(attr(dropped, "dyadMLM")$n_dyads, 2L)
  expect_equal(attr(dropped, "dyadMLM")$dropped_missing_role_dyads, 1)
  expect_equal(attr(dropped, "dyadMLM")$dropped_incomplete_dyads, numeric(0))
})

test_that("validate_dyad_data rejects fewer than two groups", {
  data <- data.frame(
    dyad_id = c(1, 1),
    person_id = c("A", "B")
  )

  expect_error(
    validate_dyad_data(data, dyad = dyad_id, member = person_id),
    "At least 2 complete dyads are required after validation and any requested dropping.",
    fixed = TRUE
  )
})

test_that("validate_dyad_data rejects duplicate cross-sectional member rows", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 2, 2),
    person_id = c("A", "B", "A", "C", "D")
  )

  expect_error(
    validate_dyad_data(data, dyad = dyad_id, member = person_id),
    "`dyad_id` = 1, `person_id` = A",
    fixed = TRUE
  )
})

test_that("validate_dyad_data allows one missing member within group-time", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 2, 2, 2),
    person_id = c("A", "B", "A", "C", "D", "C"),
    time = c(1, 1, 2, 1, 1, 2)
  )

  result <- validate_dyad_data(data, dyad = dyad_id, member = person_id, time = time)
  meta <- attr(result, "dyadMLM")

  expect_s3_class(result, "dyadMLM_data")
  expect_equal(nrow(result), 6)
  expect_equal(meta$dyad, "dyad_id")
  expect_equal(meta$member, "person_id")
  expect_null(meta$role)
  expect_equal(meta$time, "time")
  expect_equal(meta$n_dyads, 2L)
  expect_true(meta$longitudinal)
})
