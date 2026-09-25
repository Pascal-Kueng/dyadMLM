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

  result <- check_partner_dependence(simulations, dyad = "dyad", role = NULL, plot = FALSE)
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


test_that("zero-inflated and hurdle checks use the combined response", {
  skip_if_not_installed("glmmTMB")
  families <- list(stats::poisson(), glmmTMB::ziGamma(link = "log"),
                   glmmTMB::truncated_poisson())
  for (family in families) {
    withr::local_seed(8140)
    fitting_data <- data.frame(
      dyad = factor(rep(seq_len(240), each = 2)),
      study = factor(rep(seq_len(40), each = 12)),
      predictor = stats::rnorm(480),
      zero_predictor = stats::rnorm(480),
      zero_offset = rep(c(-0.2, 0.2), times = 240)
    )
    response_mean <- exp(1.7 + 0.25 * fitting_data$predictor +
      stats::rnorm(240, sd = 0.5)[fitting_data$dyad])
    zero_probability <- stats::plogis(-0.5 + 0.4 * fitting_data$zero_predictor +
      fitting_data$zero_offset +
      stats::rnorm(40, sd = 0.9)[fitting_data$study])
    fitting_data$outcome <- if (family$family == "Gamma") {
      stats::rgamma(480, shape = 4, scale = response_mean / 4)
    } else {
      stats::rpois(480, response_mean)
    }
    if (family$family == "truncated_poisson") {
      # The response component of a hurdle model must generate positive counts.
      while (any(fitting_data$outcome == 0)) {
        zero_rows <- which(fitting_data$outcome == 0)
        fitting_data$outcome[zero_rows] <- stats::rpois(
          length(zero_rows), response_mean[zero_rows]
        )
      }
    }
    fitting_data$outcome[stats::runif(480) < zero_probability] <- 0
    fitting_data$zero_predictor[3] <- NA_real_
    for (zero_formula in list(
      ~zero_predictor + offset(zero_offset),
      ~zero_predictor + offset(zero_offset) + (1 | study)
    )) {
      model <- glmmTMB::glmmTMB(
        outcome ~ predictor + (1 | dyad), ziformula = zero_formula,
        family = family, data = fitting_data, na.action = stats::na.exclude
      )
      expect_identical(model$fit$convergence, 0L)
      expect_true(model$sdr$pdHess)
      expected_draws <- t(as.matrix(stats::simulate(model, nsim = 20, seed = 8141)))

      # Both components must draw new random effects, then restore caller settings.
      model$obj$env$data$terms[[1]]$simCode <- 1
      if (length(model$obj$env$data$termszi)) {
        model$obj$env$data$termszi[[1]]$simCode <- 0
      }
      caller_data <- model$obj$env$data
      rng_state <- .Random.seed
      simulations <- simulate_dyad_responses(model, nsim = 20, seed = 8141)
      expect_identical(model$obj$env$data, caller_data)
      expect_identical(.Random.seed, rng_state)
      expect_identical(simulations$simulated_responses, expected_draws)
      expect_identical(simulations$observed_response, fitting_data$outcome[-3])
      expect_identical(dim(simulations$simulated_responses), c(20L, 479L))

      # Calculate the combined mean independently, with both random effects zero.
      fitted_coefficients <- glmmTMB::fixef(model)
      fitted_data <- fitting_data[-3, ]
      fixed_response_mean <- exp(fitted_coefficients$cond["(Intercept)"] +
        fitted_coefficients$cond["predictor"] * fitted_data$predictor)
      if (family$family == "truncated_poisson") {
        fixed_response_mean <- fixed_response_mean / -expm1(-fixed_response_mean)
      }
      fixed_zero_probability <- stats::plogis(fitted_coefficients$zi["(Intercept)"] +
        fitted_coefficients$zi["zero_predictor"] * fitted_data$zero_predictor +
        fitted_data$zero_offset)
      expect_equal(simulations$predicted_response,
                   as.numeric(fixed_response_mean * (1 - fixed_zero_probability)))
      expect_warning(check <- check_partner_dependence(
        simulations, dyad = dyad, role = NULL, plot = FALSE
      ), "Omitted: 1 incomplete dyad, with ID: 2.", fixed = TRUE)
      expect_identical(check$n_pairs, 239L)
    }
  }
})


test_that("an inactive zero component does not change response predictions", {
  skip_if_not_installed("glmmTMB")
  withr::local_seed(8143)
  fitting_data <- data.frame(
    study = factor(rep(seq_len(20), each = 5)),
    predictor = stats::rnorm(100),
    zero_offset = rep(c(-0.5, 0.5), times = 50)
  )
  fitting_data$outcome <- stats::rpois(100, exp(1 + 0.3 * fitting_data$predictor))
  # glmmTMB omits the zero mixture without fixed coefficients. Fix its unused variance.
  model <- glmmTMB::glmmTMB(
    outcome ~ predictor, ziformula = ~0 + offset(zero_offset) + (1 | study),
    family = stats::poisson(), data = fitting_data,
    start = list(thetazi = log(0.5)), map = list(thetazi = factor(NA))
  )
  expect_identical(model$fit$convergence, 0L)
  expect_true(model$sdr$pdHess)
  expect_identical(ncol(stats::model.matrix(model, component = "zi")), 0L)
  simulations <- simulate_dyad_responses(model, nsim = 2, seed = 8144)
  fitted_coefficients <- glmmTMB::fixef(model)$cond
  expected_response <- exp(fitted_coefficients["(Intercept)"] +
    fitted_coefficients["predictor"] * fitting_data$predictor)
  expect_equal(simulations$predicted_response, as.numeric(expected_response))
  expect_equal(simulations$predicted_response, as.numeric(stats::predict(
    model, newdata = NULL, type = "response", re.form = NA
  )))
})


test_that("Student-t checks require a finite response variance", {
  skip_if_not_installed("glmmTMB")
  withr::local_seed(8142)
  fitting_data <- data.frame(outcome = stats::rt(200, df = 6))
  for (degrees_of_freedom in c(1, 2, 6)) {
    model <- glmmTMB::glmmTMB(
      outcome ~ 1, data = fitting_data, family = glmmTMB::t_family(),
      start = list(psi = log(degrees_of_freedom)), map = list(psi = factor(NA))
    )
    if (degrees_of_freedom <= 2) {
      expect_error(simulate_dyad_responses(model), "more than two degrees of freedom")
    } else {
      expect_s3_class(simulate_dyad_responses(model, nsim = 2),
                       "dyadMLM_response_simulations")
    }
  }
})


test_that("ordinal checks use category scores in the declared order", {
  skip_if_not_installed("glmmTMB")
  skip_if_not("ordinal" %in% getNamespaceExports("glmmTMB"),
              "Ordinal models require a newer glmmTMB version.")
  # Show the once-per-session scoring message on every call.
  withr::local_options(rlib_message_verbosity = "verbose")
  withr::local_seed(9241)
  fitting_data <- data.frame(
    dyad = factor(rep(seq_len(180), each = 2)),
    predictor = stats::rnorm(360)
  )
  latent_response <- 0.6 * fitting_data$predictor +
    stats::rnorm(180, sd = 0.9)[fitting_data$dyad] + stats::rlogis(360)
  category_labels <- c("low", "moderate", "high", "very high")
  ordered_response <- cut(
    latent_response, c(-Inf, -1, 0.5, 2, Inf),
    labels = category_labels, ordered_result = TRUE
  )
  ordered_response[1:2] <- NA
  fitting_data$predictor[9:10] <- NA
  retained_rows <- setdiff(seq_len(360), c(1, 2, 9, 10))

  for (response in list(ordered_response, as.numeric(ordered_response))) {
    fitting_data$outcome <- response
    # glmmTMB warns when interpreting numeric responses as ordinal categories.
    model <- suppressWarnings(glmmTMB::glmmTMB(
      outcome ~ predictor + (1 | dyad), data = fitting_data,
      family = glmmTMB::ordinal(), na.action = stats::na.exclude
    ))
    expect_identical(model$fit$convergence, 0L)
    expect_true(model$sdr$pdHess)
    category_probabilities <- stats::predict(
      model, newdata = NULL, type = "probs", re.form = NA
    )
    for (number_of_simulations in c(1L, 5L)) {
      expect_message(simulations <- simulate_dyad_responses(
        model, nsim = number_of_simulations, seed = 9242
      ), "Ordinal categories are scored 1, 2, ..., K", fixed = TRUE)
      expect_identical(dim(simulations$simulated_responses),
                       c(number_of_simulations, 356L))
      expect_identical(simulations$observed_response,
                       as.numeric(ordered_response[retained_rows]))
      expect_equal(simulations$predicted_response,
                   as.numeric(category_probabilities %*% seq_along(category_labels)))
      expect_identical(simulations$model_frame, stats::model.frame(model))
      native_simulations <- stats::simulate(model, nsim = number_of_simulations,
                                            seed = 9242)
      if (is.factor(response)) {
        native_simulations[] <- lapply(native_simulations, function(draw) {
          match(as.character(draw), category_labels)
        })
      }
      expect_equal(simulations$simulated_responses, t(as.matrix(native_simulations)))
      expect_true(all(simulations$simulated_responses %in% seq_along(category_labels)))
      for (response_scale in c("raw", "model-centred")) {
        check <- check_partner_dependence(
          simulations, dyad = dyad, role = NULL, response = response_scale,
          plot = FALSE
        )
        expect_identical(check$n_pairs, 178L)
        expect_true(all(is.finite(as.matrix(check$compositions$statistics[[1]][, -1]))))
      }
    }
  }
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
  # Unit totals avoid glmmTMB treating the matrix as extra trial weights.
  matrix_response_model$frame[[1L]] <- cbind(rep(1, nrow(model$frame)), 0)
  expect_error(simulate_dyad_responses(matrix_response_model),
               "one numeric response per fitted row")

  weighted_model <- predictive_check_test_model(weights = rep(c(1, 2), 20))
  expect_error(simulate_dyad_responses(weighted_model), "unweighted models")
})
