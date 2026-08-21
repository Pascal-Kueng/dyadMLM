predictive_check_test_model <- function(
  family = stats::gaussian(),
  ziformula = ~0,
  dispformula = ~1,
  weights = NULL
) {
  set.seed(8101)
  test_data <- data.frame(
    dyad = factor(rep(seq_len(20), each = 2)),
    study = factor(rep(seq_len(5), each = 8)),
    predictor = rep(c(-0.5, 0.5), times = 20)
  )
  dyad_effect <- stats::rnorm(20, sd = 0.8)
  study_effect <- stats::rnorm(5, sd = 0.4)
  test_data$outcome <- 1 +
    0.4 * test_data$predictor +
    dyad_effect[as.integer(test_data$dyad)] +
    study_effect[as.integer(test_data$study)] +
    stats::rnorm(nrow(test_data), sd = 0.3)

  if (identical(family$family, "poisson")) {
    test_data$outcome <- stats::rpois(
      nrow(test_data),
      lambda = exp(0.2 + 0.3 * test_data$predictor)
    )
  }

  glmmTMB::glmmTMB(
    outcome ~ predictor + (1 | study) + (1 | dyad),
    ziformula = ziformula,
    dispformula = dispformula,
    family = family,
    weights = weights,
    data = test_data
  )
}


test_that("complete response simulations retain fitted-row alignment", {
  skip_if_not_installed("glmmTMB")

  model <- predictive_check_test_model()
  simulations <- simulate_dyad_responses(model, nsim = 5, seed = 123)

  expect_s3_class(simulations, "dyadMLM_response_simulations")
  expect_named(
    simulations,
    c(
      "observed_response", "simulated_responses", "fitted_response",
      "model_frame", "backend", "family", "link", "reference",
      "random_effects", "nsim", "seed", "call"
    )
  )
  expect_identical(dim(simulations$simulated_responses), c(5L, 40L))
  expect_equal(
    simulations$observed_response,
    as.numeric(stats::model.response(stats::model.frame(model)))
  )
  expect_equal(
    simulations$fitted_response,
    as.numeric(stats::predict(
      model,
      newdata = NULL,
      type = "response",
      re.form = NA
    ))
  )
  expect_identical(simulations$model_frame, stats::model.frame(model))
  expect_identical(simulations$backend, "glmmTMB")
  expect_identical(simulations$reference, "plug-in predictive")
  expect_identical(simulations$random_effects, "new")
  expect_identical(simulations$nsim, 5L)
  expect_identical(simulations$seed, 123L)

  single_simulation <- simulate_dyad_responses(model, nsim = 1, seed = 124)
  expect_identical(dim(single_simulation$simulated_responses), c(1L, 40L))
})


test_that("seeded response simulations are reproducible", {
  skip_if_not_installed("glmmTMB")

  model <- predictive_check_test_model()
  set.seed(8103)
  rng_state <- .Random.seed
  first <- simulate_dyad_responses(model, nsim = 5, seed = 456)
  expect_identical(.Random.seed, rng_state)
  second <- simulate_dyad_responses(model, nsim = 5, seed = 456)
  third <- simulate_dyad_responses(model, nsim = 5, seed = 457)

  expect_identical(first$simulated_responses, second$simulated_responses)
  expect_false(identical(first$simulated_responses, third$simulated_responses))
})


test_that("fitted responses stay aligned when source rows were omitted", {
  skip_if_not_installed("glmmTMB")

  set.seed(8102)
  test_data <- data.frame(
    dyad = factor(rep(seq_len(20), each = 2)),
    predictor = stats::rnorm(40),
    outcome = stats::rnorm(40)
  )
  test_data$outcome[c(3, 18)] <- NA_real_
  model <- glmmTMB::glmmTMB(
    outcome ~ scale(predictor) + (1 | dyad),
    data = test_data,
    na.action = stats::na.exclude
  )

  simulations <- simulate_dyad_responses(model, nsim = 5, seed = 321)

  expect_identical(nrow(simulations$model_frame), 38L)
  expect_identical(dim(simulations$simulated_responses), c(5L, 38L))
  expected_simulations <- t(as.matrix(
    stats::simulate(model, nsim = 5, seed = 321)
  ))
  expect_identical(simulations$simulated_responses, expected_simulations)
  expect_length(simulations$fitted_response, 38L)
  expect_false(anyNA(simulations$fitted_response))
  expected_center <- drop(
    stats::model.matrix(model, component = "cond") %*%
      glmmTMB::fixef(model)$cond
  )
  expect_equal(simulations$fitted_response, unname(expected_center))
})


test_that("response simulation is unconditional without modifying the model", {
  skip_if_not_installed("glmmTMB")

  model <- predictive_check_test_model(
    dispformula = ~1 + (1 | dyad)
  )
  simulation_components <- c("terms", "termszi", "termsdisp")
  read_simulation_codes <- function() {
    lapply(
      model$obj$env$data[simulation_components],
      function(component_terms) {
        vapply(
          component_terms,
          function(term) as.numeric(term$simCode),
          numeric(1)
        )
      }
    )
  }

  # Mimic a model whose simulation settings were changed by another package.
  for (component in simulation_components) {
    component_terms <- model$obj$env$data[[component]]
    for (term_index in seq_along(component_terms)) {
      component_terms[[term_index]]$simCode <- 1
    }
    model$obj$env$data[[component]] <- component_terms
  }
  caller_codes <- read_simulation_codes()

  simulations <- simulate_dyad_responses(model, nsim = 5, seed = 789)
  expect_identical(read_simulation_codes(), caller_codes)

  # Compare against direct simulation with newly drawn random effects.
  for (component in simulation_components) {
    component_terms <- model$obj$env$data[[component]]
    for (term_index in seq_along(component_terms)) {
      component_terms[[term_index]]$simCode <- 2
    }
    model$obj$env$data[[component]] <- component_terms
  }
  expected <- t(as.matrix(stats::simulate(model, nsim = 5, seed = 789)))

  expect_identical(simulations$simulated_responses, expected)
})


test_that("unsupported predictive-check inputs fail clearly", {
  skip_if_not_installed("glmmTMB")

  gaussian_model <- predictive_check_test_model()
  expect_error(
    simulate_dyad_responses(stats::lm(mpg ~ wt, data = mtcars)),
    "fitted `glmmTMB` model",
    fixed = TRUE
  )
  expect_error(
    simulate_dyad_responses(gaussian_model, nsim = 0),
    "positive whole number",
    fixed = TRUE
  )
  expect_error(
    simulate_dyad_responses(gaussian_model, nsim = 1.5),
    "positive whole number",
    fixed = TRUE
  )
  expect_error(
    simulate_dyad_responses(gaussian_model, seed = -1),
    "nonnegative whole number",
    fixed = TRUE
  )

  poisson_model <- predictive_check_test_model(family = stats::poisson())
  expect_error(
    simulate_dyad_responses(poisson_model),
    "Gaussian identity-link models",
    fixed = TRUE
  )

  log_link_model <- gaussian_model
  log_link_model$modelInfo$family <- stats::gaussian(link = "log")
  expect_error(
    simulate_dyad_responses(log_link_model),
    "Gaussian identity-link models",
    fixed = TRUE
  )

  matrix_response_model <- gaussian_model
  matrix_response_model$frame[[1L]] <- cbind(
    gaussian_model$frame[[1L]],
    gaussian_model$frame[[1L]]
  )
  expect_error(
    simulate_dyad_responses(matrix_response_model),
    "one numeric response per fitted row",
    fixed = TRUE
  )

  weighted_model <- predictive_check_test_model(weights = rep(c(1, 2), 20))
  expect_error(
    simulate_dyad_responses(weighted_model),
    "unit case weights",
    fixed = TRUE
  )

  zero_inflated_model <- predictive_check_test_model(ziformula = ~1)
  expect_error(
    simulate_dyad_responses(zero_inflated_model),
    "`ziformula = ~ 0`",
    fixed = TRUE
  )
})
