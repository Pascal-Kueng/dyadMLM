test_that("interdep_generated_columns returns empty metadata without model columns", {
  result <- interdep_generated_columns(list())

  expect_equal(result, empty_generated_columns())
})

test_that("interdep_generated_columns errors when generated column specs are missing", {
  meta <- list(
    apim_predictors = tibble::tibble(
      predictor = "x",
      component = "unsupported",
      source_column = "x",
      actor_column = ".i_x_unsupported_actor",
      partner_column = ".i_x_unsupported_partner"
    )
  )

  expect_error(
    interdep_generated_columns(meta),
    "no generated-column specification.*apim/predictor/unsupported/actor"
  )
})

test_that("interdep_generated_columns collects APIM columns", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = c(1, 10, 20, 30)
  )

  prepared <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    predictors = x,
    temporal_predictor_decomposition = "none",
    seed = 123
  )

  result <- interdep_generated_columns(attr(prepared, "interdep"))

  expect_equal(
    result,
    tibble::tibble(
      model_family = c("apim", "apim"),
      variable_role = c("predictor", "predictor"),
      variable = c("x", "x"),
      component = c("raw", "raw"),
      column_role = c("actor", "partner"),
      column = c(".i_x_actor", ".i_x_partner"),
      source_column = c("x", "x"),
      temporal_decomposition = c("none", "none"),
      dyadic_decomposition = c("none", "none"),
      column_centering = c("none", "none"),
      print_order = c(10L, 11L),
      column_pattern = c(".i_{pred}_actor", ".i_{pred}_partner"),
      description = c(
        "APIM actor predictor: actor's original predictor values",
        "APIM partner predictor: partner's original predictor values"
      )
    )
  )
})

test_that("interdep_generated_columns excludes raw temporal predictor records", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = c(1, 10, 20, 30)
  )

  prepared <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    predictors = x,
    model_type = "none",
    temporal_predictor_decomposition = "none",
    seed = 123
  )

  result <- interdep_generated_columns(attr(prepared, "interdep"))

  expect_equal(nrow(result), 0)
})

test_that("interdep_generated_columns records temporal decomposition for APIM columns", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = c(1, 10, 3, 14, 20, 30, 24, 34)
  )

  prepared <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    time = time,
    predictors = x,
    seed = 123
  )

  result <- interdep_generated_columns(attr(prepared, "interdep"))

  expect_equal(
    result,
    tibble::tibble(
      model_family = c("temporal", "temporal", "apim", "apim", "apim", "apim"),
      variable_role = c("predictor", "predictor", "predictor", "predictor", "predictor", "predictor"),
      variable = c("x", "x", "x", "x", "x", "x"),
      component = c("cwp", "cbp", "cwp", "cbp", "cwp", "cbp"),
      column_role = c(
        "temporal_component",
        "temporal_component",
        "actor",
        "actor",
        "partner",
        "partner"
      ),
      column = c(
        ".i_x_cwp",
        ".i_x_cbp",
        ".i_x_cwp_actor",
        ".i_x_cbp_actor",
        ".i_x_cwp_partner",
        ".i_x_cbp_partner"
      ),
      source_column = c("x", "x", ".i_x_cwp", ".i_x_cbp", ".i_x_cwp", ".i_x_cbp"),
      temporal_decomposition = c(
        "within_person",
        "between_person_grand_mean",
        "within_person",
        "between_person_grand_mean",
        "within_person",
        "between_person_grand_mean"
      ),
      dyadic_decomposition = c("none", "none", "none", "none", "none", "none"),
      column_centering = c("none", "none", "none", "none", "none", "none"),
      print_order = c(8L, 9L, 12L, 14L, 13L, 15L),
      column_pattern = c(
        ".i_{pred}_cwp",
        ".i_{pred}_cbp",
        ".i_{pred}_cwp_actor",
        ".i_{pred}_cbp_actor",
        ".i_{pred}_cwp_partner",
        ".i_{pred}_cbp_partner"
      ),
      description = c(
        "within-person predictor: momentary deviations from each person's usual level",
        "between-person predictor: stable differences from the average person's usual level",
        "APIM within-person actor predictor: actor's momentary deviations from their usual level",
        "APIM between-person actor predictor: actor's stable difference from the average person's usual level",
        "APIM within-person partner predictor: partner's momentary deviations from their usual level",
        "APIM between-person partner predictor: partner's stable difference from the average person's usual level"
      )
    )
  )
})

test_that("interdep_generated_columns collects DIM columns", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = c(1, 10, 20, 30)
  )

  prepared <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    predictors = x,
    model_type = "dim",
    temporal_predictor_decomposition = "none",
    seed = 123
  )

  result <- interdep_generated_columns(attr(prepared, "interdep"))

  expect_equal(
    result,
    tibble::tibble(
      model_family = c("dim", "dim"),
      variable_role = c("predictor", "predictor"),
      variable = c("x", "x"),
      component = c("raw", "raw"),
      column_role = c("dyad_mean", "within_dyad_deviation"),
      column = c(".i_x_dyad_mean_gmc", ".i_x_within_dyad_deviation"),
      source_column = c("x", "x"),
      temporal_decomposition = c("none", "none"),
      dyadic_decomposition = c("dyad_mean", "within_dyad_deviation"),
      column_centering = c("grand_mean", "none"),
      print_order = c(20L, 21L),
      column_pattern = c(".i_{pred}_dyad_mean_gmc", ".i_{pred}_within_dyad_deviation"),
      description = c(
        "DIM dyad-mean predictor: dyad's average predictor level, grand-mean centered",
        "DIM within-dyad predictor deviation: person's difference from the dyad average"
      )
    )
  )
})

test_that("interdep_generated_columns records temporal and dyadic decomposition for DIM columns", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    time = c(1, 1, 2, 2, 1, 1, 2, 2),
    x = c(1, 10, 3, 14, 20, 30, 24, 34)
  )

  prepared <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    time = time,
    predictors = x,
    model_type = "dim",
    seed = 123
  )

  result <- interdep_generated_columns(attr(prepared, "interdep"))

  expect_equal(
    result$temporal_decomposition,
    c(
      "within_person",
      "between_person_grand_mean",
      "within_person",
      "between_person_grand_mean",
      "within_person",
      "between_person_grand_mean"
    )
  )
  expect_equal(
    result$dyadic_decomposition,
    c("none", "none", "dyad_mean", "dyad_mean", "within_dyad_deviation", "within_dyad_deviation")
  )
  expect_equal(
    result$column_centering,
    c("none", "none", "none", "none", "none", "none")
  )
  expect_equal(
    result$column_role,
    c(
      "temporal_component",
      "temporal_component",
      "dyad_mean",
      "dyad_mean",
      "within_dyad_deviation",
      "within_dyad_deviation"
    )
  )
})

test_that("interdep_generated_columns combines requested model families", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = c(1, 10, 20, 30)
  )

  prepared <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    predictors = x,
    model_type = c("apim", "dim"),
    temporal_predictor_decomposition = "none",
    seed = 123
  )

  result <- interdep_generated_columns(attr(prepared, "interdep"))

  expect_equal(
    result$model_family,
    c("apim", "apim", "dim", "dim")
  )
  expect_equal(
    result$column_role,
    c("actor", "partner", "dyad_mean", "within_dyad_deviation")
  )
})

test_that("interdep_generated_columns collects DSM-style predictor columns", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = c(1, 10, 20, 30)
  )

  prepared <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    predictors = x,
    model_type = c("dim", "undirected_dsm"),
    temporal_predictor_decomposition = "none",
    seed = 123
  )

  result <- interdep_generated_columns(attr(prepared, "interdep"))

  expect_equal(
    result$model_family,
    c("dim", "dim")
  )
  expect_equal(
    result$variable_role,
    c("predictor", "predictor")
  )
  expect_equal(
    result$column,
    c(
      ".i_x_dyad_mean_gmc",
      ".i_x_within_dyad_deviation"
    )
  )
})
