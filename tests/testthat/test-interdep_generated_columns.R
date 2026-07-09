test_that("interdep_generated_columns returns empty metadata without model columns", {
  result <- interdep_generated_columns(list())

  expect_equal(result, empty_generated_columns())
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
      column = c(".i_x_raw_actor", ".i_x_raw_partner"),
      source_column = c("x", "x"),
      decomposition_level = c("none", "none"),
      temporal_decomposition = c("none", "none"),
      dyadic_decomposition = c("none", "none"),
      column_centering = c("none", "none"),
      print_order = c(10L, 11L),
      column_pattern = c(".i_*_raw_actor", ".i_*_raw_partner"),
      description = c("APIM raw actor predictors", "APIM raw partner predictors")
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
      decomposition_level = c("time_2l", "time_2l", "none", "none", "none", "none"),
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
        ".i_*_cwp",
        ".i_*_cbp",
        ".i_*_cwp_actor",
        ".i_*_cbp_actor",
        ".i_*_cwp_partner",
        ".i_*_cbp_partner"
      ),
      description = c(
        "within-person temporal predictor components",
        "between-person temporal predictor components, centred around grand mean of person means",
        "APIM within-person actor predictors",
        "APIM between-person actor predictors",
        "APIM within-person partner predictors",
        "APIM between-person partner predictors"
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
      column = c(".i_x_raw_dyad_mean_gmc", ".i_x_raw_within_dyad_deviation"),
      source_column = c("x", "x"),
      decomposition_level = c("dyad", "dyad"),
      temporal_decomposition = c("none", "none"),
      dyadic_decomposition = c("dyad_mean", "within_dyad_deviation"),
      column_centering = c("grand_mean", "none"),
      print_order = c(20L, 21L),
      column_pattern = c(".i_*_raw_dyad_mean_gmc", ".i_*_raw_within_dyad_deviation"),
      description = c(
        "DIM raw predictor dyad means, grand-mean centred",
        "DIM raw predictor within-dyad deviations"
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

test_that("interdep_generated_columns collects undirected DSM outcome columns", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    y = c(10, 14, 20, 24)
  )

  prepared <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    outcomes = y,
    model_type = "undirected_dsm",
    seed = 123
  )

  result <- interdep_generated_columns(attr(prepared, "interdep"))

  expect_equal(
    result,
    tibble::tibble(
      model_family = c("undirected_dsm", "undirected_dsm"),
      variable_role = c("outcome", "outcome"),
      variable = c("y", "y"),
      component = c("raw", "raw"),
      column_role = c("dyad_mean", "within_dyad_deviation"),
      column = c(".i_y_raw_dyad_mean", ".i_y_raw_within_dyad_deviation"),
      source_column = c("y", "y"),
      decomposition_level = c("dyad", "dyad"),
      temporal_decomposition = c("none", "none"),
      dyadic_decomposition = c("dyad_mean", "within_dyad_deviation"),
      column_centering = c("none", "none"),
      print_order = c(30L, 31L),
      column_pattern = c(".i_*_raw_dyad_mean", ".i_*_raw_within_dyad_deviation"),
      description = c(
        "DSM raw outcome dyad means",
        "DSM raw outcome within-dyad deviations"
      )
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

test_that("interdep_generated_columns combines DIM predictors and DSM outcomes", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    x = c(1, 10, 20, 30),
    y = c(5, 6, 7, 8)
  )

  prepared <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    predictors = x,
    outcomes = y,
    model_type = c("dim", "undirected_dsm"),
    temporal_predictor_decomposition = "none",
    seed = 123
  )

  result <- interdep_generated_columns(attr(prepared, "interdep"))

  expect_equal(
    result$model_family,
    c("dim", "dim", "undirected_dsm", "undirected_dsm")
  )
  expect_equal(
    result$variable_role,
    c("predictor", "predictor", "outcome", "outcome")
  )
  expect_equal(
    result$column,
    c(
      ".i_x_raw_dyad_mean_gmc",
      ".i_x_raw_within_dyad_deviation",
      ".i_y_raw_dyad_mean",
      ".i_y_raw_within_dyad_deviation"
    )
  )
})
