test_that("prepare_dyad_data has no outcome-selection argument", {
  expect_false("outcomes" %in% names(formals(prepare_dyad_data)))
  expect_identical(formals(prepare_dyad_data)$short_colnames, TRUE)
})

test_that("prepare_dyad_data returns validated data with dyad composition metadata", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2, 3, 3),
    person_id = c("A", "B", "C", "D", "E", "F"),
    role = c("female", "male", "female", "female", "male", "male")
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role,
    seed = 123
  )

  expect_s3_class(result, "dyadMLM_data")
  expect_s3_class(result, "tbl_df")

  meta <- attr(result, "dyadMLM")
  expect_equal(meta$dyad, "dyad_id")
  expect_equal(meta$member, "person_id")
  expect_equal(meta$role, "role")
  expect_equal(meta$n_dyads, 3L)

  dyad_compositions <- meta$dyad_compositions
  dyad_compositions <- dyad_compositions[order(dyad_compositions$composition), ]

  expect_equal(
    dyad_compositions$composition,
    c("female_x_female", "female_x_male", "male_x_male")
  )
  expect_equal(
    dyad_compositions$dyad_type,
    c("exchangeable", "distinguishable", "exchangeable")
  )
  expect_equal(
    dyad_compositions$dyad_type_source,
    c("inferred", "inferred", "inferred")
  )
  expect_equal(
    dyad_compositions$pooled_from,
    c(NA_character_, NA_character_, NA_character_)
  )
  expect_equal(dyad_compositions$n_dyads, c(1L, 1L, 1L))
  expect_false(".dy_raw_composition" %in% names(result))
  expect_true(is.factor(result$.dy_composition))
  expect_true(is.factor(result$.dy_composition_role))
  indicator_names <- grep("^\\.dy_is_", names(result), value = TRUE)
  expect_equal(rowSums(result[indicator_names]), rep(1, nrow(result)))
  expect_equal(
    as.character(result$.dy_composition),
    c("female_x_male", "female_x_male", "female_x_female", "female_x_female",
      "male_x_male", "male_x_male")
  )
  expect_equal(
    as.character(result$.dy_composition_role),
    c("female_x_male_female", "female_x_male_male",
      "female_x_female", "female_x_female",
      "male_x_male", "male_x_male")
  )
  expect_true(".dy_member_contrast_female_x_female_arbitrary" %in% names(result))
  expect_true(".dy_member_contrast_male_x_male_arbitrary" %in% names(result))
  expect_false(".dy_member_contrast_female_x_female" %in% names(result))
  expect_false(".dy_member_contrast_male_x_male" %in% names(result))
})

test_that("prepare_dyad_data stores predictor metadata", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male"),
    x = 1:4,
    z = 5:8
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role,
    predictors = c(x, z),
    seed = 123
  )

  expect_equal(attr(result, "dyadMLM")$predictors, c("x", "z"))
})

test_that("prepare_dyad_data centers longitudinal predictors", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = c(1, 3, 3, 5, 5, 7, 7, 9)
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    time = time,
    predictors = x,
    seed = 123
  )

  expect_true(".dy_x_cwp" %in% names(result))
  expect_true(".dy_x_cbp" %in% names(result))
  expect_equal(result$.dy_x_cwp, c(-1, -1, 1, 1, -1, -1, 1, 1))
  expect_equal(
    attr(result, "dyadMLM")$temporal_decompositions,
    tibble::tibble(
      predictor = c("x", "x", "x"),
      component = c("raw", "cwp", "cbp"),
      column = c("x", ".dy_x_cwp", ".dy_x_cbp"),
      temporal_decomposition = c("none", "2l", "2l"),
      lag = c(0L, 0L, 0L)
    )
  )
})

test_that("prepare_dyad_data constructs multiple requested model column families", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = 1:4
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    predictors = x,
    model_types = c("apim", "dim"),
    temporal_decomposition = "none",
    seed = 123
  )

  expect_equal(attr(result, "dyadMLM")$model_types, c("apim", "dim"))
  expect_true(".dy_x_actor" %in% names(result))
  expect_true(".dy_x_partner" %in% names(result))
  expect_true(".dy_x_dyad_mean_gmc" %in% names(result))
  expect_true(".dy_x_within_dyad_dev" %in% names(result))
  expect_s3_class(attr(result, "dyadMLM")$apim_predictors, "tbl_df")
  expect_s3_class(attr(result, "dyadMLM")$dim_predictors, "tbl_df")
})

test_that("prepare_dyad_data rejects unsupported model types", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  expect_error(
    prepare_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      model_types = "asdkfjakdfj"
    ),
    'Invalid value(s): "asdkfjakdfj".',
    fixed = TRUE
  )
})

test_that("prepare_dyad_data validates short_colnames", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  for (short_colnames in list(NA, c(TRUE, FALSE), "yes")) {
    expect_error(
      prepare_dyad_data(
        data,
        dyad = dyad_id,
        member = person_id,
        short_colnames = short_colnames
      ),
      "`short_colnames` must be `TRUE` or `FALSE`.",
      fixed = TRUE
    )
  }
})

test_that("prepare_dyad_data can set a distinguishable composition exchangeable for DIM", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male"),
    x = c(1, 2, 3, 4)
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role,
    predictors = x,
    model_types = "dim",
    temporal_decomposition = "none",
    set_exchangeable_compositions = "male-female",
    seed = 123
  )

  expect_equal(attr(result, "dyadMLM")$dyad_compositions$dyad_type, "exchangeable")
  expect_true(paste0(dyad_short_prefix, "is_exchangeable") %in% names(result))
  expect_true(
    paste0(dyad_short_prefix, "member_contrast_arbitrary") %in% names(result)
  )
  expect_false(".dy_member_contrast_female_x_male_arbitrary" %in% names(result))
  expect_true(".dy_x_dyad_mean_gmc" %in% names(result))
  expect_true(".dy_x_within_dyad_dev" %in% names(result))
})

test_that("prepare_dyad_data can pool exchangeable compositions for DIM", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2, 3, 3),
    person_id = c("A", "B", "C", "D", "E", "F"),
    role = c("female", "female", "male", "male", "female", "male"),
    x = c(1, 2, 3, 4, 5, 6)
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role,
    predictors = x,
    model_types = "dim",
    temporal_decomposition = "none",
    set_exchangeable_compositions = "female-male",
    pool_compositions = list(romantic_couples = c("female-female", "male-male", "female-male")),
    seed = 123
  )

  dyad_compositions <- attr(result, "dyadMLM")$dyad_compositions

  expect_equal(nrow(dyad_compositions), 1L)
  expect_equal(dyad_compositions$composition, "romantic_couples")
  expect_equal(dyad_compositions$dyad_type, "exchangeable")
  expect_equal(dyad_compositions$dyad_type_source, "mixed")
  expect_equal(
    dyad_compositions$pooled_from,
    "female_x_female, female_x_male, male_x_male"
  )
  expect_true(paste0(dyad_short_prefix, "is_exchangeable") %in% names(result))
  expect_true(
    paste0(dyad_short_prefix, "member_contrast_arbitrary") %in% names(result)
  )
  expect_false(".dy_member_contrast_romantic_couples_arbitrary" %in% names(result))
  expect_true(".dy_x_dyad_mean_gmc" %in% names(result))
  expect_true(".dy_x_within_dyad_dev" %in% names(result))
})

test_that("prepare_dyad_data treats data without role as assumed exchangeable dyads", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  result <- prepare_dyad_data(data, dyad = dyad_id, member = person_id, seed = 123)

  expect_false(".dy_raw_composition" %in% names(result))
  expect_true(is.factor(result$.dy_composition))
  expect_true(is.factor(result$.dy_composition_role))
  expect_true(paste0(dyad_short_prefix, "is_exchangeable") %in% names(result))
  expect_false(".dy_diff" %in% names(result))
  expect_true(
    paste0(dyad_short_prefix, "member_contrast_arbitrary") %in% names(result)
  )
  expect_false(".dy_is_assumed_exchangeable" %in% names(result))
  expect_false(".dy_member_contrast_assumed_exchangeable_arbitrary" %in% names(result))
  expect_equal(as.character(result$.dy_composition), rep("assumed_exchangeable", 4))
  expect_equal(
    as.character(result$.dy_composition_role),
    rep("assumed_exchangeable", 4)
  )
  expect_equal(
    attr(result, "dyadMLM")$dyad_compositions,
    tibble::tibble(
      composition = "assumed_exchangeable",
      dyad_type = "exchangeable",
      dyad_type_source = "assumed_no_role",
      pooled_from = NA_character_,
      n_dyads = 2L
    )
  )

  long_result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    short_colnames = FALSE,
    seed = 123
  )
  expect_true(".dy_is_assumed_exchangeable" %in% names(long_result))
  expect_true(
    ".dy_member_contrast_assumed_exchangeable_arbitrary" %in%
      names(long_result)
  )
  expect_false(
    paste0(dyad_short_prefix, "is_exchangeable") %in% names(long_result)
  )
  expect_false(
    paste0(dyad_short_prefix, "member_contrast_arbitrary") %in%
      names(long_result)
  )
})

test_that("prepare_dyad_data errors when setting compositions exchangeable without role", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  expect_error(
    prepare_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      keep_compositions = "female-male",
      seed = 123
    ),
    "`keep_compositions` requires `role` to be supplied.",
    fixed = TRUE
  )

  expect_error(
    prepare_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      set_exchangeable_compositions = "female-male",
      seed = 123
    ),
    "`set_exchangeable_compositions` requires `role` to be supplied.",
    fixed = TRUE
  )
})

test_that("prepare_dyad_data errors when pooling compositions without role", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  expect_error(
    prepare_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      pool_compositions = list(couples = "female-male"),
      seed = 123
    ),
    "`pool_compositions` requires `role` to be supplied.",
    fixed = TRUE
  )
})

test_that("prepare_dyad_data validates keep_compositions", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male")
  )

  expect_error(
    prepare_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      role = role,
      keep_compositions = character()
    ),
    "`keep_compositions` must contain at least one dyad composition.",
    fixed = TRUE
  )

  expect_error(
    prepare_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      role = role,
      keep_compositions = list("female-male")
    ),
    "`keep_compositions` must be a character vector",
    fixed = TRUE
  )

  expect_error(
    prepare_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      role = role,
      keep_compositions = "female-female"
    ),
    "`keep_compositions` contains unknown dyad composition",
    fixed = TRUE
  )
})

test_that("prepare_dyad_data filters included compositions before finalizing metadata", {
  data <- data.frame(
    dyad_id = rep(1:3, each = 4),
    person_id = rep(c("A", "B", "A", "B"), times = 3),
    time = rep(c(1, 1, 2, 2), times = 3),
    role = c(
      rep(c("female", "female"), times = 2),
      rep(c("male", "male"), times = 2),
      rep(c("female", "male"), times = 2)
    )
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role,
    time = time,
    keep_compositions = c("female-female", "male-male"),
    seed = 123
  )

  expect_equal(unique(result$dyad_id), c(1L, 2L))
  expect_equal(attr(result, "dyadMLM")$n_dyads, 2L)
  expect_equal(nrow(result), 8L)

  dyad_compositions <- attr(result, "dyadMLM")$dyad_compositions
  dyad_compositions <- dyad_compositions[order(dyad_compositions$composition), ]

  expect_equal(
    dyad_compositions$composition,
    c("female_x_female", "male_x_male")
  )
  expect_equal(dyad_compositions$n_dyads, c(1L, 1L))
  expect_equal(levels(result$.dy_composition), c("female_x_female", "male_x_male"))
  expect_equal(levels(result$.dy_composition_role), c("female_x_female", "male_x_male"))
  expect_true(".dy_is_female_x_female" %in% names(result))
  expect_true(".dy_is_male_x_male" %in% names(result))
  expect_true(".dy_member_contrast_female_x_female_arbitrary" %in% names(result))
  expect_true(".dy_member_contrast_male_x_male_arbitrary" %in% names(result))
  expect_false(any(paste0(
    dyad_short_prefix,
    c("is_exchangeable", "member_contrast_arbitrary")
  ) %in% names(result)))
  expect_false(any(grepl("female_x_male", names(result), fixed = TRUE)))

  expect_error(
    prepare_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      role = role,
      time = time,
      keep_compositions = "female-female"
    ),
    "`keep_compositions` must leave at least two complete dyads after filtering.",
    fixed = TRUE
  )
})

test_that("prepare_dyad_data filters before DIM compatibility checks", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2, 3, 3),
    person_id = c("A", "B", "C", "D", "E", "F"),
    role = c("female", "female", "female", "female", "male", "male"),
    x = c(1, 2, 3, 4, 5, 6),
    y = c(6, 5, 4, 3, 2, 1)
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role,
    predictors = x,
    model_types = "dim",
    temporal_decomposition = "none",
    keep_compositions = "female-female",
    seed = 123
  )

  meta <- attr(result, "dyadMLM")

  expect_equal(unique(result$dyad_id), c(1, 2))
  expect_equal(nrow(result), 4L)
  expect_equal(meta$n_dyads, 2L)
  expect_equal(meta$dyad_compositions$composition, "female_x_female")
  expect_equal(meta$dyad_compositions$dyad_type, "exchangeable")
  expect_equal(meta$dyad_compositions$n_dyads, 2L)
  expect_equal(levels(result$.dy_composition), "female_x_female")
  expect_true(paste0(dyad_short_prefix, "is_exchangeable") %in% names(result))
  expect_true(
    paste0(dyad_short_prefix, "member_contrast_arbitrary") %in% names(result)
  )
  expect_false(".dy_is_female_x_female" %in% names(result))
  expect_false(".dy_member_contrast_female_x_female_arbitrary" %in% names(result))
  expect_false(any(grepl("male_x_male", names(result), fixed = TRUE)))
  expect_true(".dy_x_dyad_mean_gmc" %in% names(result))
  expect_true(".dy_x_within_dyad_dev" %in% names(result))
  expect_false(any(startsWith(names(result), ".dy_y_")))
  expect_equal(meta$dim_predictors$predictor, "x")
})

test_that("prepare_dyad_data can filter, constrain, and pool in one call", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2, 3, 3, 4, 4),
    person_id = c("A", "B", "C", "D", "E", "F", "G", "H"),
    role = c("female", "female", "male", "male", "female", "male", "nonbinary", "nonbinary"),
    x = c(1, 2, 3, 4, 5, 6, 7, 8)
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role,
    predictors = x,
    model_types = "dim",
    temporal_decomposition = "none",
    keep_compositions = c("female-female", "male-male", "female-male"),
    set_exchangeable_compositions = "female-male",
    pool_compositions = list(
      romantic_couples = c("female-female", "male-male", "female-male")
    ),
    seed = 123
  )

  dyad_compositions <- attr(result, "dyadMLM")$dyad_compositions

  expect_equal(unique(result$dyad_id), c(1, 2, 3))
  expect_equal(nrow(result), 6L)
  expect_equal(attr(result, "dyadMLM")$n_dyads, 3L)
  expect_equal(nrow(dyad_compositions), 1L)
  expect_equal(dyad_compositions$composition, "romantic_couples")
  expect_equal(dyad_compositions$dyad_type, "exchangeable")
  expect_equal(dyad_compositions$dyad_type_source, "mixed")
  expect_equal(dyad_compositions$pooled_from, "female_x_female, female_x_male, male_x_male")
  expect_equal(dyad_compositions$n_dyads, 3L)
  expect_equal(levels(result$.dy_composition), "romantic_couples")
  expect_false(any(grepl("nonbinary", names(result), fixed = TRUE)))
  expect_true(paste0(dyad_short_prefix, "is_exchangeable") %in% names(result))
  expect_true(
    paste0(dyad_short_prefix, "member_contrast_arbitrary") %in% names(result)
  )
  expect_false(".dy_member_contrast_romantic_couples_arbitrary" %in% names(result))
  expect_true(".dy_x_dyad_mean_gmc" %in% names(result))
  expect_true(".dy_x_within_dyad_dev" %in% names(result))
  expect_equal(attr(result, "dyadMLM")$dim_predictors$predictor, "x")
})

test_that("prepare_dyad_data applies keep_compositions before constraining and pooling", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2, 3, 3),
    person_id = c("A", "B", "C", "D", "E", "F"),
    role = c("female", "female", "male", "male", "female", "male")
  )

  expect_error(
    prepare_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      role = role,
      keep_compositions = c("female-female", "male-male"),
      set_exchangeable_compositions = "female-male",
      seed = 123
    ),
    "`keep_compositions` filters out composition(s) that are later referenced by `set_exchangeable_compositions` or `pool_compositions`: female_x_male. Add them to `keep_compositions` or remove them from the later argument.",
    fixed = TRUE
  )

  expect_error(
    prepare_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      role = role,
      keep_compositions = c("female-female", "male-male"),
      pool_compositions = list(couples = c("female-female", "female-male")),
      seed = 123
    ),
    "`keep_compositions` filters out composition(s) that are later referenced by `set_exchangeable_compositions` or `pool_compositions`: female_x_male. Add them to `keep_compositions` or remove them from the later argument.",
    fixed = TRUE
  )
})

test_that("prepare_dyad_data rejects reserved dyadMLM columns", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    .dy_composition = c("x", "x", "y", "y")
  )

  expect_error(
    prepare_dyad_data(data, dyad = dyad_id, member = person_id),
    "columns starting with `.dy_`",
    fixed = TRUE
  )
})

test_that("prepare_dyad_data rejects data that is already prepared", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  prepared <- prepare_dyad_data(data, dyad = dyad_id, member = person_id, seed = 123)

  expect_error(
    prepare_dyad_data(prepared, dyad = dyad_id, member = person_id, seed = 123),
    "`data` has already been prepared by dyadMLM.",
    fixed = TRUE
  )
})

test_that("prepare_dyad_data rejects role labels containing the internal separator", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "non_x_binary", "female", "male")
  )

  expect_error(
    prepare_dyad_data(data, dyad = dyad_id, member = person_id, role = role),
    "`role` values must not contain `_x_`",
    fixed = TRUE
  )
})

test_that("prepare_dyad_data rejects empty role labels", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  for (roles in list(
    c("", "male", "female", "male"),
    c("female", "male", " \t", "male"),
    factor(c("", "male", "female", "male"))
  )) {
    data$role <- roles
    expect_error(
      prepare_dyad_data(data, dyad = dyad_id, member = person_id, role = role),
      "`role` values must not be empty or whitespace-only",
      fixed = TRUE
    )
  }
})

test_that("prepare_dyad_data infers compositions from sparse longitudinal roles", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    role = c("female", "male", NA, NA, "female", "male", NA, NA),
    time = c(1, 1, 2, 2, 1, 1, 2, 2)
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role,
    time = time
  )

  expect_equal(as.character(result$.dy_composition), rep("female_x_male", 8))
  expect_equal(
    as.character(result$.dy_composition_role),
    rep(c("female_x_male_female", "female_x_male_male"), 4)
  )
  expect_true(all(
    paste0(dyad_short_prefix, c("is_female", "is_male")) %in% names(result)
  ))
  expect_false(any(c(
    ".dy_is_female_x_male_female",
    ".dy_is_female_x_male_male"
  ) %in% names(result)))
})
