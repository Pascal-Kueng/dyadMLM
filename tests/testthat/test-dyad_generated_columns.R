non_composition_generated_columns <- function(prepared) {
  dyad_generated_columns(attr(prepared, "dyadMLM")) |>
    dplyr::filter(.data$model_family != "composition")
}

test_that("dyad_generated_columns returns empty metadata without model columns", {
  result <- dyad_generated_columns(list())

  expect_equal(result, empty_generated_columns())
})

test_that("dyad_generated_columns errors when generated column specs are missing", {
  meta <- list(
    generated_columns = tibble::tibble(
      model_family = "apim",
      variable_role = "predictor",
      variable = "x",
      component = "unsupported",
      lag = 0L,
      column_role = "actor",
      column = ".dy_x_unsupported_actor",
      source_column = "x"
    )
  )

  expect_error(
    dyad_generated_columns(meta),
    "no generated-column specification.*apim/predictor/unsupported/actor"
  )
})

test_that("generated column specification keys are unique", {
  specifications <- generated_column_spec_lookup()
  keys <- c("model_family", "variable_role", "component", "column_role")

  expect_equal(anyDuplicated(specifications[keys]), 0L)
})

test_that("dyad_generated_columns records every created composition column", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male")
  )

  prepared <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role,
    model_types = "none"
  )

  meta <- attr(prepared, "dyadMLM")
  stored <- meta$generated_columns
  result <- dyad_generated_columns(meta)

  expect_equal(stored, result[names(stored)])
  expect_setequal(stored$column, setdiff(names(prepared), names(data)))
  expect_true(all(result$model_family == "composition"))
  expect_false(any(grepl("member_contrast", result$column, fixed = TRUE)))
})

test_that("dyad_generated_columns collects APIM columns", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = c(1, 10, 20, 30)
  )

  prepared <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    predictors = x,
    temporal_decomposition = "none",
    seed = 123
  )

  result <- non_composition_generated_columns(prepared)

  expect_equal(
    result,
    tibble::tibble(
      model_family = c("apim", "apim"),
      variable_role = c("predictor", "predictor"),
      variable = c("x", "x"),
      component = c("raw", "raw"),
      lag = c(0L, 0L),
      column_role = c("actor", "partner"),
      column = c(".dy_x_actor", ".dy_x_partner"),
      source_column = c("x", "x"),
      temporal_decomposition = c("none", "none"),
      dyadic_decomposition = c("none", "none"),
      column_centering = c("none", "none"),
      print_order = c(10L, 11L),
      column_pattern = c(".dy_{pred}_actor", ".dy_{pred}_partner"),
      description = c(
        "APIM actor predictor: actor's original predictor values",
        "APIM partner predictor: partner's original predictor values"
      )
    )
  )
})

test_that("dyad_generated_columns excludes raw temporal predictor records", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = c(1, 10, 20, 30)
  )

  prepared <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    predictors = x,
    model_types = "none",
    temporal_decomposition = "none",
    seed = 123
  )

  result <- non_composition_generated_columns(prepared)

  expect_equal(nrow(result), 0)
})

test_that("dyad_generated_columns records temporal decomposition for APIM columns", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = c(1, 10, 3, 14, 20, 30, 24, 34)
  )

  prepared <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    time = time,
    predictors = x,
    seed = 123
  )

  result <- non_composition_generated_columns(prepared)

  expect_equal(
    result,
    tibble::tibble(
      model_family = c("temporal", "temporal", rep("apim", 6)),
      variable_role = rep("predictor", 8),
      variable = rep("x", 8),
      component = c("cwp", "cbp", "raw", "cwp", "cbp", "raw", "cwp", "cbp"),
      lag = rep(0L, 8),
      column_role = c(
        "temporal_component",
        "temporal_component",
        "actor",
        "actor",
        "actor",
        "partner",
        "partner",
        "partner"
      ),
      column = c(
        ".dy_x_cwp",
        ".dy_x_cbp",
        ".dy_x_actor",
        ".dy_x_cwp_actor",
        ".dy_x_cbp_actor",
        ".dy_x_partner",
        ".dy_x_cwp_partner",
        ".dy_x_cbp_partner"
      ),
      source_column = c("x", "x", "x", ".dy_x_cwp", ".dy_x_cbp", "x", ".dy_x_cwp", ".dy_x_cbp"),
      temporal_decomposition = c(
        "within_person",
        "between_person_grand_mean",
        "none",
        "within_person",
        "between_person_grand_mean",
        "none",
        "within_person",
        "between_person_grand_mean"
      ),
      dyadic_decomposition = rep("none", 8),
      column_centering = rep("none", 8),
      print_order = c(8L, 9L, 10L, 12L, 14L, 11L, 13L, 15L),
      column_pattern = c(
        ".dy_{pred}_cwp",
        ".dy_{pred}_cbp",
        ".dy_{pred}_actor",
        ".dy_{pred}_cwp_actor",
        ".dy_{pred}_cbp_actor",
        ".dy_{pred}_partner",
        ".dy_{pred}_cwp_partner",
        ".dy_{pred}_cbp_partner"
      ),
      description = c(
        "within-person predictor: momentary deviations from each person's usual level",
        "between-person predictor: stable differences from the average person's usual level",
        "APIM actor predictor: actor's original predictor values",
        "APIM within-person actor predictor: actor's momentary deviations from their usual level",
        "APIM between-person actor predictor: actor's stable difference from the average person's usual level",
        "APIM partner predictor: partner's original predictor values",
        "APIM within-person partner predictor: partner's momentary deviations from their usual level",
        "APIM between-person partner predictor: partner's stable difference from the average person's usual level"
      )
    )
  )
})

test_that("dyad_generated_columns collects DIM columns", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = c(1, 10, 20, 30)
  )

  prepared <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    predictors = x,
    model_types = "dim",
    temporal_decomposition = "none",
    seed = 123
  )

  result <- non_composition_generated_columns(prepared)

  expect_equal(
    result,
    tibble::tibble(
      model_family = c("dim", "dim"),
      variable_role = c("predictor", "predictor"),
      variable = c("x", "x"),
      component = c("raw", "raw"),
      lag = c(0L, 0L),
      column_role = c("dyad_mean", "within_dyad_deviation"),
      column = c(".dy_x_dyad_mean_gmc", ".dy_x_within_dyad_dev"),
      source_column = c("x", "x"),
      temporal_decomposition = c("none", "none"),
      dyadic_decomposition = c("dyad_mean", "within_dyad_deviation"),
      column_centering = c("grand_mean", "none"),
      print_order = c(20L, 21L),
      column_pattern = c(".dy_{pred}_dyad_mean_gmc", ".dy_{pred}_within_dyad_dev"),
      description = c(
        "dyad-mean predictor: dyad's average predictor level, grand-mean centered",
        "DIM within-dyad member-deviation predictor: member's difference from the dyad mean"
      )
    )
  )
})

test_that("dyad_generated_columns records temporal and dyadic decomposition for DIM columns", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = c(1, 10, 3, 14, 20, 30, 24, 34)
  )

  prepared <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    time = time,
    predictors = x,
    model_types = "dim",
    seed = 123
  )

  result <- non_composition_generated_columns(prepared)

  expect_equal(
    result$temporal_decomposition,
    c(
      "within_person",
      "between_person_grand_mean",
      "none",
      "within_person",
      "between_person_grand_mean",
      "none",
      "within_person",
      "between_person_grand_mean"
    )
  )
  expect_equal(
    result$dyadic_decomposition,
    c(
      "none", "none",
      "dyad_mean", "dyad_mean", "dyad_mean",
      "within_dyad_deviation", "within_dyad_deviation", "within_dyad_deviation"
    )
  )
  expect_equal(
    result$column_centering,
    c("none", "none", "grand_mean", "none", "none", "none", "none", "none")
  )
  expect_equal(
    result$column_role,
    c(
      "temporal_component",
      "temporal_component",
      "dyad_mean",
      "dyad_mean",
      "dyad_mean",
      "within_dyad_deviation",
      "within_dyad_deviation",
      "within_dyad_deviation"
    )
  )
})

test_that("dyad_generated_columns combines requested model families", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = c(1, 10, 20, 30)
  )

  prepared <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    predictors = x,
    model_types = c("apim", "dim"),
    temporal_decomposition = "none",
    seed = 123
  )

  result <- non_composition_generated_columns(prepared)

  expect_equal(
    result$model_family,
    c("apim", "apim", "dim", "dim")
  )
  expect_equal(
    result$column_role,
    c("actor", "partner", "dyad_mean", "within_dyad_deviation")
  )
})

test_that("dyad_generated_columns collects DSM columns", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male"),
    x = c(1, 10, 20, 30)
  )

  prepared <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    role = role,
    predictors = x,
    model_types = "dsm",
    dsm_role_order = c("female", "male"),
    temporal_decomposition = "none",
    seed = 123
  )

  result <- non_composition_generated_columns(prepared)

  expect_equal(
    result$model_family,
    c("dsm", "dsm", "dsm")
  )
  expect_equal(
    result$variable_role,
    c("role", "predictor", "predictor")
  )
  expect_equal(
    result$column_role,
    c("role_contrast", "dyad_mean", "dyad_difference")
  )
  expect_equal(
    result$column,
    c(
      ".dy_dsm_role_contrast",
      ".dy_x_dyad_mean_gmc",
      ".dy_x_within_dyad_diff"
    )
  )
  expect_equal(result$dyadic_decomposition, c("role_contrast", "dyad_mean", "dyad_difference"))
})
