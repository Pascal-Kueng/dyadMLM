predictive_check_test_model <- function(
  ziformula = ~0, dispformula = ~1, weights = NULL
) {
  set.seed(8101)
  test_data <- data.frame(
    dyad = factor(rep(seq_len(20), each = 2)),
    study = factor(rep(seq_len(5), each = 8)),
    predictor = rep(c(-0.5, 0.5), times = 20)
  )
  test_data$outcome <- 1 + 0.4 * test_data$predictor +
    stats::rnorm(20, sd = 0.8)[as.integer(test_data$dyad)] +
    stats::rnorm(5, sd = 0.4)[as.integer(test_data$study)] +
    stats::rnorm(nrow(test_data), sd = 0.3)
  glmmTMB::glmmTMB(
    outcome ~ predictor + (1 | study) + (1 | dyad),
    ziformula = ziformula, dispformula = dispformula,
    weights = weights, data = test_data
  )
}


test_that("complete response simulations retain fitted-row alignment", {
  skip_if_not_installed("glmmTMB")
  model <- predictive_check_test_model()
  simulations <- simulate_dyad_responses(model, nsim = 5, seed = 123)

  expect_s3_class(simulations, "dyadMLM_response_simulations")
  expect_named(simulations, c("observed_response", "simulated_responses",
                             "predicted_response", "model_frame"))
  expect_identical(dim(simulations$simulated_responses), c(5L, 40L))
  expect_equal(simulations$observed_response,
               as.numeric(stats::model.response(stats::model.frame(model))))
  expect_equal(simulations$predicted_response, as.numeric(stats::predict(
    model, newdata = NULL, type = "response", re.form = NA
  )))
  expect_identical(simulations$model_frame, stats::model.frame(model))
  expect_identical(attr(simulations, "dyadMLM"), list(
    backend = "glmmTMB", family = "gaussian", link = "identity",
    reference = "plug-in predictive", random_effects = "new",
    parameter_uncertainty = "excluded", seed = 123L
  ))

  result <- check_partner_dependence(simulations, dyad = "dyad", plot = FALSE)
  expect_s3_class(result, "dyadMLM_partner_check")
  expect_identical(result$n_pairs, 20L)
  simulated_statistics <- as.matrix(result$compositions$statistics[[1]][-1, -1])
  expect_identical(dim(simulated_statistics), c(5L, 4L))
  expect_true(all(is.finite(simulated_statistics)))

  expect_output(printed <- withVisible(print(simulations)),
                "5 complete gaussian response datasets")
  expect_false(printed$visible)
  expect_identical(printed$value, simulations)

  single <- simulate_dyad_responses(model, nsim = 1, seed = 124)
  expect_identical(dim(single$simulated_responses), c(1L, 40L))
})


test_that("seeded simulations are reproducible and preserve the caller's RNG", {
  skip_if_not_installed("glmmTMB")
  model <- predictive_check_test_model()
  set.seed(8103)
  rng_state <- .Random.seed
  first <- simulate_dyad_responses(model, nsim = 5, seed = -456)
  expect_identical(.Random.seed, rng_state)
  # Seeds follow R's integer conversion, including negative and fractional values.
  second <- simulate_dyad_responses(model, nsim = 5, seed = -456.9)
  third <- simulate_dyad_responses(model, nsim = 5, seed = -457)
  expect_identical(attr(second, "dyadMLM")$seed, -456L)
  expect_identical(first$simulated_responses, second$simulated_responses)
  expect_false(identical(first$simulated_responses, third$simulated_responses))

  # Restoration also preserves the absence of a global RNG state.
  on.exit(assign(".Random.seed", rng_state, envir = .GlobalEnv), add = TRUE)
  rm(".Random.seed", envir = .GlobalEnv)
  without_state <- simulate_dyad_responses(model, nsim = 5, seed = -456)
  expect_false(exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
  expect_identical(without_state$simulated_responses, first$simulated_responses)
})


test_that("transformed predictors and dispersion omissions retain fitted rows", {
  skip_if_not_installed("glmmTMB")
  set.seed(8104)
  data <- data.frame(
    dyad = factor(rep(seq_len(20), each = 2L)),
    predictor = stats::rnorm(40),
    dispersion_predictor = stats::rnorm(40)
  )
  data$outcome <- 1 + 0.3 * data$predictor +
    stats::rnorm(20, sd = 0.5)[as.integer(data$dyad)] +
    stats::rnorm(40, sd = exp(0.2 + 0.15 * data$dispersion_predictor))
  data$outcome[3L] <- NA_real_
  data$dispersion_predictor[18L] <- NA_real_
  model <- glmmTMB::glmmTMB(
    outcome ~ scale(predictor) + (1 | dyad),
    dispformula = ~dispersion_predictor,
    data = data, na.action = stats::na.exclude
  )
  simulations <- simulate_dyad_responses(model, nsim = 5, seed = 321)
  retained <- setdiff(seq_len(nrow(data)), c(3L, 18L))

  expect_identical(dim(simulations$simulated_responses), c(5L, 38L))
  expect_identical(simulations$observed_response, data$outcome[retained])
  expect_identical(simulations$model_frame$dispersion_predictor,
                   data$dispersion_predictor[retained])
  expect_identical(simulations$simulated_responses,
                   t(as.matrix(stats::simulate(model, nsim = 5, seed = 321))))
  # The fitted design matrix independently checks centring after scale() and omissions.
  expected_center <- stats::model.matrix(model, component = "cond") %*%
    glmmTMB::fixef(model)$cond
  expect_equal(simulations$predicted_response, as.numeric(expected_center))
})


test_that("response simulation redraws all random effects and restores settings", {
  skip_if_not_installed("glmmTMB")
  model <- predictive_check_test_model(dispformula = ~1 + (1 | dyad))
  # Mixed caller settings, including dispersion REs, must not affect the draws.
  model$obj$env$data$terms[[1]]$simCode <- 0
  model$obj$env$data$terms[[2]]$simCode <- 1
  model$obj$env$data$termsdisp[[1]]$simCode <- 1
  caller_data <- model$obj$env$data
  simulations <- simulate_dyad_responses(model, nsim = 5, seed = 789)
  expect_identical(model$obj$env$data, caller_data)

  glmmTMB::set_simcodes(model$obj, "random")
  model$obj$env$data$termsdisp[[1]]$simCode <- 2
  expected <- t(as.matrix(stats::simulate(model, nsim = 5, seed = 789)))
  expect_identical(simulations$simulated_responses, expected)
})


test_that("model simulation settings and RNG are restored after an error", {
  skip_if_not_installed("glmmTMB")
  model <- predictive_check_test_model(dispformula = ~1 + (1 | dyad))
  glmmTMB::set_simcodes(model$obj, "fix")
  model$obj$env$data$termsdisp[[1]]$simCode <- 1
  caller_data <- model$obj$env$data
  model$obj$simulate <- function(...) stop("forced simulation failure", call. = FALSE)

  rng_state <- .Random.seed
  on.exit(assign(".Random.seed", rng_state, envir = .GlobalEnv), add = TRUE)
  rm(".Random.seed", envir = .GlobalEnv)
  expect_error(simulate_dyad_responses(model, nsim = 5, seed = 101),
               "forced simulation failure", fixed = TRUE)
  expect_false(exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
  expect_identical(model$obj$env$data, caller_data)

  model$obj$simulate <- function(...) list(yobs = rep(Inf, nrow(model$frame)))
  expect_error(simulate_dyad_responses(model, nsim = 5, seed = 101),
               "Expected finite predictions and one simulated response per fitted row.",
               fixed = TRUE)
  expect_false(exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
  expect_identical(model$obj$env$data, caller_data)
})


test_that("unsupported predictive-check inputs fail clearly", {
  skip_if_not_installed("glmmTMB")
  model <- predictive_check_test_model()
  expect_error(simulate_dyad_responses(stats::lm(mpg ~ wt, data = mtcars)),
               "fitted `glmmTMB` model", fixed = TRUE)
  expect_error(simulate_dyad_responses(model, nsim = 0), "positive whole number")
  invalid_nsim <- list(
    NA_real_, Inf, 1.5, numeric(), c(1, 2), TRUE, "1", factor("1"),
    as.Date("2026-01-01"), 1 + 1i, .Machine$integer.max + 1
  )
  for (value in invalid_nsim) {
    expect_error(simulate_dyad_responses(model, nsim = value),
                 "positive whole number")
  }
  expect_error(simulate_dyad_responses(model, seed = NA_real_),
               "supplied seed is not a valid integer")

  matrix_response_model <- model
  matrix_response_model$frame[[1L]] <- cbind(model$frame[[1L]], model$frame[[1L]])
  expect_error(simulate_dyad_responses(matrix_response_model),
               "one numeric response per fitted row")

  weighted_model <- predictive_check_test_model(weights = rep(c(1, 2), 20))
  expect_error(simulate_dyad_responses(weighted_model), "unweighted models")
  zero_inflated_model <- predictive_check_test_model(ziformula = ~1)
  expect_error(simulate_dyad_responses(zero_inflated_model),
               "`ziformula = ~ 0`", fixed = TRUE)
})
