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
    role = role,
    seed = 123
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
      "female_x_female", "female_x_female",
      "male_x_male", "male_x_male")
  )
  expect_true(".i_diff_female_x_female" %in% names(result))
  expect_true(".i_diff_male_x_male" %in% names(result))
})

test_that("prepare_interdep_data stores predictor metadata", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male"),
    x = 1:4,
    z = 5:8
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role,
    predictors = c(x, z),
    seed = 123
  )

  expect_equal(attr(result, "interdep")$predictors, c("x", "z"))
})

test_that("prepare_interdep_data centers longitudinal predictors", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = c(1, 3, 3, 5, 5, 7, 7, 9)
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    time = time,
    predictors = x,
    seed = 123
  )

  expect_true(".i_x_cwp" %in% names(result))
  expect_true(".i_x_cbp" %in% names(result))
  expect_equal(result$.i_x_cwp, c(-1, -1, 1, 1, -1, -1, 1, 1))
  expect_equal(
    attr(result, "interdep")$temporal_predictor_decompositions,
    tibble::tibble(
      predictor = c("x", "x"),
      component = c("cwp", "cbp"),
      column = c(".i_x_cwp", ".i_x_cbp"),
      temporal_predictor_decomposition = c("time_2l", "time_2l")
    )
  )
})

test_that("prepare_interdep_data constructs multiple requested model column families", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = 1:4
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    predictors = x,
    model_type = c("apim", "dim"),
    temporal_predictor_decomposition = "none",
    seed = 123
  )

  expect_equal(attr(result, "interdep")$model_type, c("apim", "dim"))
  expect_true(".i_x_raw_actor" %in% names(result))
  expect_true(".i_x_raw_partner" %in% names(result))
  expect_true(".i_x_raw_dyad_mean_gmc" %in% names(result))
  expect_true(".i_x_raw_within_dyad_deviation" %in% names(result))
  expect_s3_class(attr(result, "interdep")$apim_predictors, "tbl_df")
  expect_s3_class(attr(result, "interdep")$dim_predictors, "tbl_df")
})

test_that("prepare_interdep_data rejects unsupported model types", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  expect_error(
    prepare_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      model_type = "asdkfjakdfj"
    ),
    'Invalid value(s): "asdkfjakdfj".',
    fixed = TRUE
  )
})

test_that("prepare_interdep_data rejects unsupported dyad compositions for undirected DSM", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male"),
    y = c(1, 2, 3, 4)
  )

  expect_error(
    prepare_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      role = role,
      outcomes = y,
      model_type = "undirected_dsm",
      seed = 123
    ),
    "support only data with exactly one exchangeable dyad composition",
    fixed = TRUE
  )
})

test_that("prepare_interdep_data treats data without role as assumed exchangeable dyads", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  result <- prepare_interdep_data(data, group = dyad_id, member = person_id, seed = 123)

  expect_false(".i_raw_composition" %in% names(result))
  expect_true(is.factor(result$.i_composition))
  expect_true(is.factor(result$.i_composition_role))
  expect_true(".i_is_assumed_exchangeable" %in% names(result))
  expect_false(interdep_diff_col %in% names(result))
  expect_true(".i_diff_assumed_exchangeable" %in% names(result))
  expect_equal(as.character(result$.i_composition), rep("assumed_exchangeable", 4))
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

test_that("prepare_interdep_data rejects data that is already prepared", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  prepared <- prepare_interdep_data(data, group = dyad_id, member = person_id, seed = 123)

  expect_error(
    prepare_interdep_data(prepared, group = dyad_id, member = person_id, seed = 123),
    "`data` has already been prepared by interdep.",
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
