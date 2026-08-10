simulate_dsm_model_equivalence_data <- function(
    n_dyads = 250L,
    seed = 20260809L
) {
  set.seed(seed)

  x_level <- stats::rnorm(n_dyads)
  x_level <- x_level - mean(x_level)
  x_difference <- stats::rnorm(n_dyads, sd = 0.8)

  residual_covariance <- matrix(
    c(1.2, 0.3, 0.3, 0.9),
    nrow = 2L
  )
  score_residuals <- matrix(
    stats::rnorm(2L * n_dyads),
    ncol = 2L
  ) %*% chol(residual_covariance)

  coefficients <- c(
    a10 = 1.1,
    a11 = 0.7,
    a12 = -0.25,
    a20 = -0.4,
    a21 = 0.35,
    a22 = 0.8
  )
  y_level <- coefficients[["a10"]] +
    coefficients[["a11"]] * x_level +
    coefficients[["a12"]] * x_difference +
    score_residuals[, 1L]
  y_difference <- coefficients[["a20"]] +
    coefficients[["a21"]] * x_level +
    coefficients[["a22"]] * x_difference +
    score_residuals[, 2L]

  score_data <- data.frame(
    dyad_id = seq_len(n_dyads),
    x_level = x_level,
    x_difference = x_difference,
    y_level = y_level,
    y_difference = y_difference
  )

  # Reconstruct the two member rows from each dyad's level and full
  # first-minus-second difference scores.
  member_data <- data.frame(
    dyad_id = rep(score_data$dyad_id, each = 2L),
    person_id = rep(c("A", "B"), times = n_dyads),
    role = rep(c("first", "second"), times = n_dyads),
    x = as.vector(rbind(
      x_level + x_difference / 2,
      x_level - x_difference / 2
    )),
    y = as.vector(rbind(
      y_level + y_difference / 2,
      y_level - y_difference / 2
    ))
  )

  list(
    score_data = score_data,
    member_data = member_data
  )
}

fit_direct_dsm_reference <- function(score_data) {
  model <- stats::lm(
    cbind(y_level, y_difference) ~ x_level + x_difference,
    data = score_data
  )
  coefficients <- stats::coef(model)

  list(
    fixed_effects = c(
      a10 = coefficients["(Intercept)", "y_level"],
      a11 = coefficients["x_level", "y_level"],
      a12 = coefficients["x_difference", "y_level"],
      a20 = coefficients["(Intercept)", "y_difference"],
      a21 = coefficients["x_level", "y_difference"],
      a22 = coefficients["x_difference", "y_difference"]
    ),
    # The multivariate Gaussian maximum-likelihood covariance uses n rather
    # than the residual degrees of freedom in its denominator.
    covariance = crossprod(stats::residuals(model)) / nrow(score_data),
    fitted_scores = stats::fitted(model)
  )
}

fit_long_dsm_model <- function(member_data, dsm_role_order) {
  prepared_data <- prepare_dyad_data(
    member_data,
    dyad = dyad_id,
    member = person_id,
    role = role,
    predictors = x,
    model_types = "dsm",
    dsm_role_order = dsm_role_order,
    temporal_decomposition = "none"
  )

  model <- glmmTMB::glmmTMB(
    y ~
      .x_dyad_mean_gmc +
      .x_within_dyad_diff +
      .dsm_role_contrast +
      .x_dyad_mean_gmc:.dsm_role_contrast +
      .x_within_dyad_diff:.dsm_role_contrast +
      us(1 + .dsm_role_contrast | dyad_id),
    dispformula = ~0,
    family = gaussian(),
    data = prepared_data
  )

  list(data = prepared_data, model = model)
}

extract_long_dsm_fixed_effects <- function(model) {
  coefficients <- glmmTMB::fixef(model)$cond

  c(
    a10 = coefficients[["(Intercept)"]],
    a11 = coefficients[[".x_dyad_mean_gmc"]],
    a12 = coefficients[[".x_within_dyad_diff"]],
    a20 = coefficients[[".dsm_role_contrast"]],
    a21 = coefficients[[
      ".x_dyad_mean_gmc:.dsm_role_contrast"
    ]],
    a22 = coefficients[[
      ".x_within_dyad_diff:.dsm_role_contrast"
    ]]
  )
}

extract_long_dsm_covariance <- function(model) {
  covariance <- as.matrix(glmmTMB::VarCorr(model)$cond$dyad_id)
  matrix(as.numeric(covariance), nrow = nrow(covariance))
}

test_that("long DSM matches the direct score-space model", {
  skip_if_not_installed("glmmTMB")

  simulated_data <- simulate_dsm_model_equivalence_data()
  direct_reference <- fit_direct_dsm_reference(simulated_data$score_data)
  long_fit <- fit_long_dsm_model(
    simulated_data$member_data,
    dsm_role_order = c("first", "second")
  )

  expect_identical(long_fit$model$fit$convergence, 0L)
  expect_true(long_fit$model$sdr$pdHess)

  first_member_rows <- long_fit$data$role == "first"
  expect_equal(
    long_fit$data$.x_dyad_mean_gmc[first_member_rows],
    simulated_data$score_data$x_level,
    tolerance = 1e-12
  )
  expect_equal(
    long_fit$data$.x_within_dyad_diff[first_member_rows],
    simulated_data$score_data$x_difference,
    tolerance = 1e-12
  )

  expect_equal(
    extract_long_dsm_fixed_effects(long_fit$model),
    direct_reference$fixed_effects,
    tolerance = 1e-5
  )
  expect_equal(
    extract_long_dsm_covariance(long_fit$model),
    unname(direct_reference$covariance),
    tolerance = 1e-5
  )

  member_predictions <- stats::predict(long_fit$model, re.form = NA)
  member_prediction_pairs <- matrix(
    member_predictions,
    ncol = 2L,
    byrow = TRUE
  )
  fitted_scores_from_long_model <- cbind(
    y_level = rowMeans(member_prediction_pairs),
    y_difference = member_prediction_pairs[, 1L] -
      member_prediction_pairs[, 2L]
  )
  expect_equal(
    unname(fitted_scores_from_long_model),
    unname(direct_reference$fitted_scores),
    tolerance = 1e-5
  )
})

test_that("reversing DSM direction only reverses directional parameters", {
  skip_if_not_installed("glmmTMB")

  simulated_data <- simulate_dsm_model_equivalence_data()
  first_minus_second <- fit_long_dsm_model(
    simulated_data$member_data,
    dsm_role_order = c("first", "second")
  )
  second_minus_first <- fit_long_dsm_model(
    simulated_data$member_data,
    dsm_role_order = c("second", "first")
  )

  expect_identical(second_minus_first$model$fit$convergence, 0L)
  expect_true(second_minus_first$model$sdr$pdHess)
  expect_equal(
    as.numeric(stats::logLik(second_minus_first$model)),
    as.numeric(stats::logLik(first_minus_second$model)),
    tolerance = 1e-6
  )
  expect_equal(
    stats::predict(second_minus_first$model),
    stats::predict(first_minus_second$model),
    tolerance = 1e-8
  )

  expected_reversed_effects <- extract_long_dsm_fixed_effects(
    first_minus_second$model
  )
  expected_reversed_effects[c("a12", "a20", "a21")] <-
    -expected_reversed_effects[c("a12", "a20", "a21")]
  expect_equal(
    extract_long_dsm_fixed_effects(second_minus_first$model),
    expected_reversed_effects,
    tolerance = 5e-5
  )

  direction_reversal <- diag(c(1, -1))
  expected_reversed_covariance <- direction_reversal %*%
    extract_long_dsm_covariance(first_minus_second$model) %*%
    direction_reversal
  expect_equal(
    extract_long_dsm_covariance(second_minus_first$model),
    expected_reversed_covariance,
    tolerance = 1e-5
  )
})

test_that("lavaan matches the direct DSM score-space reference", {
  skip_if_not_installed("lavaan")

  simulated_data <- simulate_dsm_model_equivalence_data()
  direct_reference <- fit_direct_dsm_reference(simulated_data$score_data)
  lavaan_model <- lavaan::sem(
    paste(
      "y_level ~ x_level + x_difference",
      "y_difference ~ x_level + x_difference",
      "y_level ~~ y_difference",
      sep = "\n"
    ),
    data = simulated_data$score_data,
    meanstructure = TRUE,
    fixed.x = TRUE
  )

  expect_true(lavaan::lavInspect(lavaan_model, "converged"))
  parameter_estimates <- lavaan::parameterEstimates(lavaan_model)
  estimate <- function(lhs, operator, rhs = "") {
    matching_row <- parameter_estimates$lhs == lhs &
      parameter_estimates$op == operator &
      parameter_estimates$rhs == rhs
    parameter_estimates$est[matching_row]
  }

  lavaan_fixed_effects <- c(
    a10 = estimate("y_level", "~1"),
    a11 = estimate("y_level", "~", "x_level"),
    a12 = estimate("y_level", "~", "x_difference"),
    a20 = estimate("y_difference", "~1"),
    a21 = estimate("y_difference", "~", "x_level"),
    a22 = estimate("y_difference", "~", "x_difference")
  )
  lavaan_covariance <- matrix(
    c(
      estimate("y_level", "~~", "y_level"),
      estimate("y_level", "~~", "y_difference"),
      estimate("y_level", "~~", "y_difference"),
      estimate("y_difference", "~~", "y_difference")
    ),
    nrow = 2L
  )

  expect_equal(
    lavaan_fixed_effects,
    direct_reference$fixed_effects,
    tolerance = 1e-7
  )
  expect_equal(
    lavaan_covariance,
    unname(direct_reference$covariance),
    tolerance = 1e-7
  )
})
