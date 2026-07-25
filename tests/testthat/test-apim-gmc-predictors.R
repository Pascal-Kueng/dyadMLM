test_that("omitting APIM GMC is identical to requesting FALSE", {
  data <- data.frame(
    dyad_id = rep(1:2, each = 2),
    person_id = LETTERS[1:4],
    x = c(1, 3, 5, 9)
  )

  omitted <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    predictors = x,
    model_types = "apim",
    seed = 123
  )
  explicit_false <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    predictors = x,
    model_types = "apim",
    seed = 123,
    add_apim_gmc_predictors = FALSE
  )

  expect_identical(explicit_false, omitted)
})

test_that("APIM GMC validates its argument and preparation context", {
  cross <- data.frame(
    dyad_id = rep(1:2, each = 2),
    person_id = LETTERS[1:4],
    x = 1:4
  )

  for (value in list(NA, c(TRUE, FALSE), "yes", 1)) {
    expect_error(
      prepare_dyad_data(
        cross,
        dyad = dyad_id,
        member = person_id,
        predictors = x,
        add_apim_gmc_predictors = value
      ),
      "`add_apim_gmc_predictors` must be .*TRUE.* or .*FALSE"
    )
  }

  expect_error(
    prepare_dyad_data(
      cross,
      dyad = dyad_id,
      member = person_id,
      predictors = x,
      model_types = "none",
      add_apim_gmc_predictors = TRUE
    ),
    '`model_types` includes "apim"',
    fixed = TRUE
  )

  expect_error(
    prepare_dyad_data(
      cross,
      dyad = dyad_id,
      member = person_id,
      model_types = "apim",
      add_apim_gmc_predictors = TRUE
    ),
    "`predictors`",
    fixed = TRUE
  )

  nonnumeric <- dplyr::mutate(cross, x = factor(.data$x))
  expect_error(
    prepare_dyad_data(
      nonnumeric,
      dyad = dyad_id,
      member = person_id,
      predictors = x,
      model_types = "apim",
      add_apim_gmc_predictors = TRUE
    ),
    "at least one numeric variable selected by `predictors`",
    fixed = TRUE
  )

  longitudinal <- data.frame(
    dyad_id = rep(1:2, each = 4),
    person_id = rep(c("A", "B"), 4),
    time = rep(rep(1:2, each = 2), 2),
    x = 1:8
  )
  expect_error(
    prepare_dyad_data(
      longitudinal,
      dyad = dyad_id,
      member = person_id,
      time = time,
      predictors = x,
      model_types = "apim",
      add_apim_gmc_predictors = TRUE
    ),
    '`temporal_decomposition = "none"` after `"auto"` is resolved',
    fixed = TRUE
  )
})

test_that("APIM GMC uses all retained non-missing observations", {
  data <- data.frame(
    dyad_id = rep(1:4, each = 2),
    person_id = LETTERS[1:8],
    role = c(
      "female", "male",
      "female", "male",
      "female", "male",
      "female", "female"
    ),
    x = c(1, 3, 5, NA, 9, 11, 100, 200),
    all_missing = rep(NA_real_, 8),
    category = factor(rep(c("low", "high"), 4)),
    flag = rep(c(TRUE, FALSE), 4)
  )

  expect_warning(
    result <- prepare_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      role = role,
      predictors = c(x, all_missing, category, flag),
      model_types = "apim",
      keep_compositions = "female-male",
      add_apim_gmc_predictors = TRUE
    ),
    "non-numeric predictor\\(s\\): `category`, `flag`"
  )

  expect_equal(result$dyad_id, rep(1:3, each = 2))

  grand_mean <- mean(c(1, 3, 5, NA, 9, 11), na.rm = TRUE)
  expected_gmc <- result$x - grand_mean
  partner_rows <- c(2L, 1L, 4L, 3L, 6L, 5L)

  expect_equal(result$.x_gmc, expected_gmc)
  expect_equal(result$.x_gmc_actor, expected_gmc)
  expect_equal(result$.x_gmc_partner, expected_gmc[partner_rows])
  expect_equal(result$.x_actor, result$x)
  expect_equal(result$.x_partner, result$x[partner_rows])
  expect_equal(mean(result$.x_gmc, na.rm = TRUE), 0)
  expect_true(is.na(result$.x_gmc[result$dyad_id == 2 & result$role == "male"]))

  expect_true(all(is.na(result$.all_missing_gmc)))
  expect_true(all(is.na(result$.all_missing_gmc_actor)))
  expect_true(all(is.na(result$.all_missing_gmc_partner)))

  expect_equal(result$.category_actor, result$category)
  expect_equal(result$.category_partner, result$category[partner_rows])
  expect_false(any(grepl("^\\.category_gmc", names(result))))
  expect_equal(result$.flag_actor, result$flag)
  expect_equal(result$.flag_partner, result$flag[partner_rows])
  expect_false(any(grepl("^\\.flag_gmc", names(result))))
})

test_that("undecomposed ILD GMC weights observations rather than person means", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2),
    person_id = c("A", "A", "A", "B", "C", "D"),
    time = c(1, 2, 3, 1, 1, 1),
    x = c(0, 0, 30, 20, 40, 60)
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    time = time,
    predictors = x,
    model_types = "apim",
    temporal_decomposition = "none",
    seed = 123,
    add_apim_gmc_predictors = TRUE
  )

  observation_mean <- mean(data$x)
  person_mean <- mean(c(10, 20, 40, 60))
  expect_equal(result$.x_gmc, result$x - observation_mean)
  expect_false(isTRUE(all.equal(result$.x_gmc, result$x - person_mean)))
})

test_that("APIM GMC lags retain the contemporaneous centering constant", {
  data <- data.frame(
    dyad_id = rep(1:2, each = 6),
    person_id = rep(c("A", "B"), 6),
    time = rep(rep(1:3, each = 2), 2),
    x = c(0, 10, 2, 14, 8, 20, 30, 50, 31, 55, 40, 80)
  )

  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    time = time,
    predictors = x,
    lag1_predictors = x,
    model_types = "apim",
    temporal_decomposition = "none",
    seed = 123,
    add_apim_gmc_predictors = TRUE
  )

  grand_mean <- mean(data$x)
  expect_equal(result$.x_gmc, result$x - grand_mean)
  expect_equal(result$.x_gmc_lag1, result$.x_lag1 - grand_mean)
  expect_equal(result$.x_gmc_actor_lag1, result$.x_gmc_lag1)

  partner_id <- c(A = "B", B = "A")[result$person_id]
  partner_rows <- match(
    paste(result$dyad_id, result$time, partner_id),
    paste(result$dyad_id, result$time, result$person_id)
  )
  expect_equal(
    result$.x_gmc_partner_lag1,
    result$.x_gmc_lag1[partner_rows]
  )

  generated_lags <- dyad_generated_columns(attr(result, "dyadMLM")) |>
    dplyr::filter(.data$component == "gmc", .data$lag == 1L)
  expected_columns <- c(
    ".x_gmc_lag1",
    ".x_gmc_actor_lag1",
    ".x_gmc_partner_lag1"
  )
  generated_lags <- generated_lags[
    match(expected_columns, generated_lags$column),
  ]
  expect_equal(generated_lags$column, expected_columns)
  expect_equal(generated_lags$model_family, rep("apim", 3))
  expect_equal(generated_lags$column_role, c("source", "actor", "partner"))
  expect_equal(generated_lags$column_centering, rep("grand_mean", 3))
})

test_that("APIM GMC does not enter DIM or DSM decompositions", {
  exchangeable <- data.frame(
    dyad_id = rep(1:3, each = 2),
    person_id = LETTERS[1:6],
    x = c(1, 4, 5, 9, 10, 15)
  )
  dim_default <- prepare_dyad_data(
    exchangeable,
    dyad = dyad_id,
    member = person_id,
    predictors = x,
    model_types = c("apim", "dim"),
    seed = 123
  )
  dim_gmc <- prepare_dyad_data(
    exchangeable,
    dyad = dyad_id,
    member = person_id,
    predictors = x,
    model_types = c("apim", "dim"),
    seed = 123,
    add_apim_gmc_predictors = TRUE
  )

  dim_columns <- unlist(
    attr(dim_default, "dyadMLM")$dim_predictors[
      c("mean_column", "deviation_column")
    ],
    use.names = FALSE
  )
  expect_equal(
    unname(as.list(dim_gmc)[dim_columns]),
    unname(as.list(dim_default)[dim_columns])
  )
  expect_equal(
    attr(dim_gmc, "dyadMLM")$dim_predictors,
    attr(dim_default, "dyadMLM")$dim_predictors
  )
  expect_false(any(
    attr(dim_gmc, "dyadMLM")$dim_predictors$component == "gmc"
  ))

  distinguishable <- data.frame(
    dyad_id = rep(1:3, each = 2),
    person_id = LETTERS[1:6],
    role = rep(c("female", "male"), 3),
    x = c(1, 4, 5, 9, 10, 15)
  )
  dsm_default <- prepare_dyad_data(
    distinguishable,
    dyad = dyad_id,
    member = person_id,
    role = role,
    predictors = x,
    model_types = c("apim", "dsm"),
    dsm_role_order = c("female", "male")
  )
  dsm_gmc <- prepare_dyad_data(
    distinguishable,
    dyad = dyad_id,
    member = person_id,
    role = role,
    predictors = x,
    model_types = c("apim", "dsm"),
    dsm_role_order = c("female", "male"),
    add_apim_gmc_predictors = TRUE
  )

  dsm_columns <- unlist(
    attr(dsm_default, "dyadMLM")$dsm_predictors[
      c("mean_column", "difference_column")
    ],
    use.names = FALSE
  )
  expect_equal(
    unname(as.list(dsm_gmc)[dsm_columns]),
    unname(as.list(dsm_default)[dsm_columns])
  )
  expect_equal(
    attr(dsm_gmc, "dyadMLM")$dsm_predictors,
    attr(dsm_default, "dyadMLM")$dsm_predictors
  )
  expect_false(any(
    attr(dsm_gmc, "dyadMLM")$dsm_predictors$component == "gmc"
  ))
})

test_that("APIM GMC columns are classified and printed as grand-mean centered", {
  data <- data.frame(
    dyad_id = rep(1:2, each = 2),
    person_id = LETTERS[1:4],
    x = c(1, 3, 5, 9)
  )
  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    predictors = x,
    model_types = "apim",
    seed = 123,
    add_apim_gmc_predictors = TRUE
  )

  generated <- dyad_generated_columns(attr(result, "dyadMLM")) |>
    dplyr::filter(.data$component == "gmc")
  expected_columns <- c(".x_gmc", ".x_gmc_actor", ".x_gmc_partner")
  generated <- generated[match(expected_columns, generated$column), ]

  expect_equal(generated$column, expected_columns)
  expect_equal(generated$model_family, rep("apim", 3))
  expect_equal(generated$variable_role, rep("predictor", 3))
  expect_equal(generated$column_role, c("source", "actor", "partner"))
  expect_equal(generated$temporal_decomposition, rep("none", 3))
  expect_equal(generated$column_centering, rep("grand_mean", 3))

  printed <- capture.output(print(result, n = 1))
  expect_true(any(grepl(".{pred}_gmc", printed, fixed = TRUE)))
  expect_true(any(grepl(".{pred}_gmc_actor", printed, fixed = TRUE)))
  expect_true(any(grepl(".{pred}_gmc_partner", printed, fixed = TRUE)))
  expect_true(any(grepl("grand-mean", printed, fixed = TRUE)))
})

test_that("APIM GMC generated-column collisions fail before construction", {
  data <- data.frame(
    dyad_id = rep(1:2, each = 2),
    person_id = LETTERS[1:4],
    x = c(1, 3, 5, 9)
  )

  for (target in c(".x_gmc", ".x_gmc_actor", ".x_gmc_partner")) {
    conflicting <- data
    conflicting[[target]] <- seq_len(nrow(conflicting))

    expect_error(
      prepare_dyad_data(
        conflicting,
        dyad = dyad_id,
        member = person_id,
        predictors = x,
        model_types = "apim",
        seed = 123,
        add_apim_gmc_predictors = TRUE
      ),
      paste0("Generated-column collision.*", gsub("\\.", "\\\\.", target))
    )
  }

  convergent <- dplyr::mutate(data, x_gmc = .data$x + 100)
  expect_error(
    prepare_dyad_data(
      convergent,
      dyad = dyad_id,
      member = person_id,
      predictors = c(x, x_gmc),
      model_types = "apim",
      seed = 123,
      add_apim_gmc_predictors = TRUE
    ),
    "Generated-column collision.*\\.x_gmc_actor"
  )
})
