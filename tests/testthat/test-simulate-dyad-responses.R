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
      "observed_response", "simulated_responses", "response_center",
      "model_frame", "backend", "family", "link", "reference",
      "random_effects", "parameter_uncertainty", "center", "center_target",
      "target", "nsim", "seed", "call"
    )
  )
  expect_identical(dim(simulations$simulated_responses), c(5L, 40L))
  expect_equal(
    simulations$observed_response,
    as.numeric(stats::model.response(stats::model.frame(model)))
  )
  expect_equal(
    simulations$response_center,
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
  expect_identical(simulations$parameter_uncertainty, "excluded")
  expect_identical(
    simulations$center_target,
    paste0(
      "marginal response mean over new random effects ",
      "(Gaussian identity)"
    )
  )
  expect_identical(
    simulations$target,
    paste0(
      "unconditional plug-in replication under the fitted-row design, ",
      "with all random effects newly generated"
    )
  )
  expect_identical(simulations$nsim, 5L)
  expect_identical(simulations$seed, 123L)

  printed_output <- capture.output(
    printed_result <- withVisible(print(simulations))
  )
  expect_identical(
    printed_output,
    c(
      "<dyadMLM response simulations>",
      "5 complete gaussian response datasets from glmmTMB for 40 fitted rows"
    )
  )
  expect_false(printed_result$visible)
  expect_identical(printed_result$value, simulations)

  single_simulation <- simulate_dyad_responses(model, nsim = 1, seed = 124)
  expect_identical(dim(single_simulation$simulated_responses), c(1L, 40L))
  expect_output(
    print(single_simulation),
    "1 complete gaussian response dataset from glmmTMB for 40 fitted rows",
    fixed = TRUE
  )
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

  # A supplied seed also restores the absence of a global RNG state.
  on.exit(
    assign(".Random.seed", rng_state, envir = .GlobalEnv),
    add = TRUE
  )
  rm(".Random.seed", envir = .GlobalEnv)
  expect_false(exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))

  without_existing_state <- simulate_dyad_responses(
    model,
    nsim = 5,
    seed = 456
  )

  expect_false(exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
  expect_identical(
    without_existing_state$simulated_responses,
    first$simulated_responses
  )
})


test_that("response centres stay aligned after row omission", {
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
  expect_length(simulations$response_center, 38L)
  expect_false(anyNA(simulations$response_center))
  expected_response_center <- drop(
    stats::model.matrix(model, component = "cond") %*%
      glmmTMB::fixef(model)$cond
  )
  expect_equal(
    simulations$response_center,
    unname(expected_response_center)
  )
})


test_that("response simulation is unconditional without modifying the model", {
  skip_if_not_installed("glmmTMB")

  model <- predictive_check_test_model(
    dispformula = ~1 + (1 | dyad)
  )
  original_codes <- get_glmmTMB_simulation_codes(model)
  on.exit(set_glmmTMB_simulation_codes(model, original_codes), add = TRUE)

  # Mimic a model whose simulation settings were changed by another package.
  caller_codes <- original_codes
  caller_codes$terms[] <- rep(
    c(0, 1),
    length.out = length(caller_codes$terms)
  )
  caller_codes$termsdisp[] <- 1
  set_glmmTMB_simulation_codes(model, caller_codes)

  simulations <- simulate_dyad_responses(model, nsim = 5, seed = 789)
  expect_identical(get_glmmTMB_simulation_codes(model), caller_codes)

  # Compare against direct simulation with newly drawn random effects.
  unconditional_codes <- lapply(
    original_codes,
    function(codes) rep(2, length(codes))
  )
  set_glmmTMB_simulation_codes(model, unconditional_codes)
  expected <- t(as.matrix(stats::simulate(model, nsim = 5, seed = 789)))
  set_glmmTMB_simulation_codes(model, caller_codes)

  expect_identical(simulations$simulated_responses, expected)
})


test_that("model simulation settings are restored after an error", {
  skip_if_not_installed("glmmTMB")

  model <- predictive_check_test_model(
    dispformula = ~1 + (1 | dyad)
  )
  original_codes <- get_glmmTMB_simulation_codes(model)
  on.exit(set_glmmTMB_simulation_codes(model, original_codes), add = TRUE)

  caller_codes <- original_codes
  caller_codes$terms[] <- 1
  caller_codes$termsdisp[] <- 1
  set_glmmTMB_simulation_codes(model, caller_codes)

  original_simulate <- model$obj$simulate
  on.exit(model$obj$simulate <- original_simulate, add = TRUE)
  model$obj$simulate <- function(...) {
    stop("forced simulation failure", call. = FALSE)
  }

  rng_state <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  on.exit(
    assign(".Random.seed", rng_state, envir = .GlobalEnv),
    add = TRUE
  )
  rm(".Random.seed", envir = .GlobalEnv)
  expect_false(exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))

  expect_error(
    simulate_dyad_responses(model, nsim = 5, seed = 101),
    "forced simulation failure",
    fixed = TRUE
  )
  expect_false(exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
  expect_identical(get_glmmTMB_simulation_codes(model), caller_codes)
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
    "non-negative whole number",
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
