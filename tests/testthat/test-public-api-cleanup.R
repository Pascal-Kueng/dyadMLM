collision_test_data <- function() {
  data <- expand.grid(
    time = 1:2,
    member_id = c("a", "b"),
    dyad_id = 1:2,
    KEEP.OUT.ATTRS = FALSE
  )
  data$role <- ifelse(data$member_id == "a", "first", "second")
  data$x <- seq_len(nrow(data))
  data$x_cwp <- data$x + 10
  data$x_cbp <- data$x + 20
  data$x_actor <- data$x + 30
  data
}

test_that("the public API and metadata use only the cleaned names", {
  expect_setequal(
    getNamespaceExports("dyadMLM"),
    c(
      "prepare_dyad_data",
      "compare_nested_glmmTMB_models",
      "recover_exchangeable_covariance"
    )
  )

  prepare_arguments <- names(formals(prepare_dyad_data))
  expect_true(all(c(
    "dyad", "lag1_predictors", "model_types", "temporal_decomposition",
    "keep_compositions"
  ) %in% prepare_arguments))
  expect_false(any(c(
    "group", "lag_predictors", "model_type",
    "temporal_predictor_decomposition", "include_compositions"
  ) %in% prepare_arguments))

  covariance_arguments <- names(formals(recover_exchangeable_covariance))
  expect_true("block_pairings" %in% covariance_arguments)
  expect_false("pairs" %in% covariance_arguments)

  print_arguments <- names(formals(print.exchangeable_rescov))
  expect_true("representation" %in% print_arguments)
  expect_false("what" %in% print_arguments)

  data <- collision_test_data()
  prepared <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = member_id,
    time = time,
    predictors = x,
    lag1_predictors = x,
    model_types = "apim",
    temporal_decomposition = "2l",
    seed = 1
  )
  meta <- attr(prepared, "dyadMLM")
  expect_true(all(c(
    "dyad", "lag1_predictors", "model_types", "temporal_decomposition",
    "temporal_decompositions"
  ) %in% names(meta)))
  expect_false(any(c(
    "group", "lag_predictors", "model_type",
    "temporal_predictor_decomposition", "temporal_predictor_decompositions"
  ) %in% names(meta)))
  expect_true("temporal_decomposition" %in% names(meta$temporal_decompositions))
})

test_that("APIM collision preflight is complete and predictor-order independent", {
  data <- collision_test_data()

  for (selected in list(c("x", "x_cwp"), c("x_cwp", "x"),
                        c("x", "x_cbp"), c("x_cbp", "x"))) {
    expect_error(
      prepare_dyad_data(
        data,
        dyad = dyad_id,
        member = member_id,
        time = time,
        predictors = tidyselect::all_of(selected),
        model_types = "apim"
      ),
      "Generated-column collision.*predictor.*temporal component.*lag 0.*model family `apim`.*column role",
      fixed = FALSE
    )
  }
})

test_that("DIM and DSM collision preflights cover suffixes and predictor order", {
  data <- collision_test_data()

  collision_cases <- list(
    list(
      predictors = c("x", "x_cwp"),
      target = ".dy_x_cwp_within_dyad_dev"
    ),
    list(
      predictors = c("x_cwp", "x"),
      target = ".dy_x_cwp_within_dyad_dev"
    ),
    list(
      predictors = c("x", "x_cbp"),
      target = ".dy_x_cbp_within_dyad_dev"
    ),
    list(
      predictors = c("x_cbp", "x"),
      target = ".dy_x_cbp_within_dyad_dev"
    )
  )

  for (collision_case in collision_cases) {
    selected <- collision_case$predictors
    error <- tryCatch(
      prepare_dyad_data(
        data,
        dyad = dyad_id,
        member = member_id,
        time = time,
        predictors = tidyselect::all_of(selected),
        model_types = "dim"
      ),
      error = identity
    )
    message <- conditionMessage(error)
    expect_match(message, collision_case$target, fixed = TRUE)
    expect_match(message, "model family `dim`", fixed = TRUE)
    for (predictor in unique(selected)) {
      expect_match(message, paste0("predictor `", predictor, "`"), fixed = TRUE)
    }
  }

  for (collision_case in collision_cases) {
    selected <- collision_case$predictors
    error <- tryCatch(
      prepare_dyad_data(
        data,
        dyad = dyad_id,
        member = member_id,
        role = role,
        time = time,
        predictors = tidyselect::all_of(selected),
        model_types = "dsm",
        dsm_role_order = c("first", "second")
      ),
      error = identity
    )
    message <- conditionMessage(error)
    expect_match(message, collision_case$target, fixed = TRUE)
    expect_match(message, "model family `dsm`", fixed = TRUE)
    for (predictor in unique(selected)) {
      expect_match(message, paste0("predictor `", predictor, "`"), fixed = TRUE)
    }
  }
})

test_that("lag collisions with earlier generated columns are rejected", {
  data <- collision_test_data()
  expect_error(
    prepare_dyad_data(
      data,
      dyad = dyad_id,
      member = member_id,
      time = time,
      predictors = c(x, x_actor),
      lag1_predictors = c(x, x_actor),
      model_types = "apim"
    ),
    paste0(
      "`.dy_x_actor_lag1`.*predictor `x`.*lag 1.*model family `apim`.*",
      "predictor `x_actor`.*lag 1.*model family `temporal`"
    ),
    fixed = FALSE
  )
})

test_that("predictor columns cannot overwrite composition columns", {
  data <- data.frame(
    dyad_id = rep(1:2, each = 2),
    member_id = rep(c("a", "b"), 2),
    role = rep(c("actor", "f"), 2),
    is_actor_x_f = 1:4
  )

  expect_error(
    prepare_dyad_data(
      data,
      dyad = dyad_id,
      member = member_id,
      role = role,
      predictors = is_actor_x_f,
      model_types = "apim"
    ),
    paste0(
      "`.dy_is_actor_x_f_actor`.*predictor `is_actor_x_f`.*",
      "model family `apim`.*model family `composition`"
    ),
    fixed = FALSE
  )
})

test_that("only the new member contrast is generated", {
  data <- collision_test_data()
  prepared <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = member_id,
    time = time,
    model_types = "none",
    seed = 1
  )
  expect_true(
    ".dy_member_contrast_assumed_exchangeable_arbitrary" %in% names(prepared)
  )
  expect_false(any(startsWith(names(prepared), ".dy_diff_")))
})
