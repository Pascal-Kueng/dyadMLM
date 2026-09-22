# Run from the repository root: Rscript dev/diagnostic_checks/simulation-studies/fitting-examples/lognormal.R
# One original 200-dyad dataset illustrates fitting, not repeated-study flag rates.
# Direct integration fits the same model; it is not a proposed package fitting method.
pkgload::load_all(quiet = TRUE)
output_directory <- "dev/diagnostic_checks/simulation-studies/results/fitting-examples/lognormal"
dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)
dataset_seed <- 20380925L
reference_draws <- 499L
true_parameters <- c(intercept = 0.7, slope = 0.4,
  log_response_sd = log(2), log_dyad_sd = log(0.6))

draw_responses <- function(predictor, parameters, number_of_draws) {
  number_of_dyads <- length(predictor) / 2L
  dyad_effects <- matrix(rnorm(number_of_dyads * number_of_draws,
    sd = exp(parameters[4L])), nrow = number_of_dyads)
  log_means <- parameters[1L] + parameters[2L] * predictor +
    dyad_effects[rep(seq_len(number_of_dyads), each = 2L), , drop = FALSE]
  log_variances <- log1p(exp(2 * (parameters[3L] - log_means)))
  matrix(rlnorm(length(log_means), log_means - log_variances / 2,
    sqrt(log_variances)), nrow = length(predictor))
}

# Integrate both partners' densities over their one shared normal effect.
# Split at plausible response modes to avoid missing a narrow second peak.
integrated_negative_log_likelihood <- function(parameters, fitting_data,
  relative_tolerance = 1e-7, integration_limit = 10) {
  fixed_log_means <- parameters[1L] + parameters[2L] * fitting_data$predictor
  response_sd <- exp(parameters[3L])
  dyad_sd <- exp(parameters[4L])
  pair_log_likelihoods <- vapply(seq_len(nrow(fitting_data) / 2L), function(dyad_index) {
    pair_rows <- 2L * dyad_index - c(1L, 0L)
    pair_responses <- fitting_data$outcome[pair_rows]
    pair_fixed_log_means <- fixed_log_means[pair_rows]
    integrand <- function(standard_normal_effect) {
      first_log_mean <- pair_fixed_log_means[1L] + dyad_sd * standard_normal_effect
      second_log_mean <- pair_fixed_log_means[2L] + dyad_sd * standard_normal_effect
      first_log_variance <- log1p(response_sd^2 / exp(2 * first_log_mean))
      second_log_variance <- log1p(response_sd^2 / exp(2 * second_log_mean))
      exp(dlnorm(pair_responses[1L], first_log_mean - first_log_variance / 2,
        sqrt(first_log_variance), log = TRUE) +
        dlnorm(pair_responses[2L], second_log_mean - second_log_variance / 2,
          sqrt(second_log_variance), log = TRUE) + dnorm(standard_normal_effect, log = TRUE))
    }
    response_locations <- (log(pair_responses) - pair_fixed_log_means) / dyad_sd
    split_points <- sort(unique(c(-integration_limit, 0, integration_limit,
      pmax(-integration_limit, pmin(integration_limit, response_locations)))))
    interval_probabilities <- vapply(seq_len(length(split_points) - 1L), function(interval) {
      integrate(integrand, split_points[interval], split_points[interval + 1L],
        rel.tol = relative_tolerance, abs.tol = 1e-14, subdivisions = 200L)$value
    }, numeric(1))
    log(sum(interval_probabilities))
  }, numeric(1))
  -sum(pair_log_likelihoods)
}

set.seed(dataset_seed)
fitting_data <- data.frame(dyad = factor(rep(1:200, each = 2L)), predictor = runif(400, -1, 1))
fitting_data$outcome <- as.numeric(draw_responses(fitting_data$predictor, true_parameters, 1L))
laplace_model <- glmmTMB::glmmTMB(outcome ~ predictor + (1 | dyad),
  data = fitting_data, family = glmmTMB::lognormal())
stopifnot(laplace_model$fit$convergence == 0L, isTRUE(laplace_model$sdr$pdHess))
laplace_parameters <- c(unname(glmmTMB::fixef(laplace_model)$cond),
  log(sigma(laplace_model)), log(sqrt(glmmTMB::VarCorr(laplace_model)$cond$dyad[1L, 1L])))
lower_bounds <- c(-5, -5, -5, -5)
upper_bounds <- c(5, 5, 5, 3)
integrated_fit <- nlminb(laplace_parameters, integrated_negative_log_likelihood,
  fitting_data = fitting_data, lower = lower_bounds, upper = upper_bounds)
alternative_start_fit <- nlminb(true_parameters, integrated_negative_log_likelihood,
  fitting_data = fitting_data, lower = lower_bounds, upper = upper_bounds)
integrated_hessian <- optimHess(integrated_fit$par, integrated_negative_log_likelihood,
  fitting_data = fitting_data)
numerical_checks <- data.frame(
  strict_objective_difference = integrated_negative_log_likelihood(integrated_fit$par,
    fitting_data, relative_tolerance = 1e-10, integration_limit = 12) - integrated_fit$objective,
  alternative_start_difference = alternative_start_fit$objective - integrated_fit$objective,
  smallest_hessian_eigenvalue = min(eigen(integrated_hessian, symmetric = TRUE)$values),
  distance_from_bounds = min(integrated_fit$par - lower_bounds, upper_bounds - integrated_fit$par)
)
stopifnot(integrated_fit$convergence == 0L, alternative_start_fit$convergence == 0L,
  abs(numerical_checks$strict_objective_difference) < 1e-5,
  abs(numerical_checks$alternative_start_difference) < 1e-5,
  numerical_checks$smallest_hessian_eigenvalue > 0, numerical_checks$distance_from_bounds > 0.01)

parameters_by_method <- list(truth = true_parameters,
  glmmTMB = laplace_parameters, numerical_integration = integrated_fit$par)
parameter_results <- dplyr::bind_rows(lapply(names(parameters_by_method), function(method) {
  parameters <- parameters_by_method[[method]]
  data.frame(method, intercept = parameters[1L], slope = parameters[2L],
    response_sd = exp(parameters[3L]), dyad_sd = exp(parameters[4L]),
    integrated_negative_log_likelihood = integrated_negative_log_likelihood(parameters, fitting_data),
    row.names = NULL)
}))
first_partner_rows <- seq.int(1L, nrow(fitting_data), by = 2L)
correlation_results <- dplyr::bind_rows(lapply(names(parameters_by_method), function(method) {
  parameters <- parameters_by_method[[method]]
  # Shared random draws reduce simulation noise in the between-method comparison.
  set.seed(dataset_seed + 2000000L)
  simulated_responses <- draw_responses(fitting_data$predictor, parameters, reference_draws)
  predicted_response <- exp(parameters[1L] + parameters[2L] * fitting_data$predictor)
  centred_responses <- cbind(fitting_data$outcome, simulated_responses) - predicted_response
  correlations <- apply(centred_responses, 2L, function(responses) {
    dyadMLM:::calculate_partner_pair_statistics(responses[first_partner_rows],
      responses[first_partner_rows + 1L])[["Partner correlation (exchangeable)"]]
  })
  stopifnot(all(is.finite(correlations)))
  limits <- quantile(correlations[-1L], c(0.025, 0.975), names = FALSE)
  data.frame(method, observed = correlations[1L], reference_median = median(correlations[-1L]),
    lower = limits[1L], upper = limits[2L],
    flagged = correlations[1L] < limits[1L] || correlations[1L] > limits[2L])
}))
write.csv(parameter_results, file.path(output_directory, "parameters.csv"), row.names = FALSE)
write.csv(correlation_results, file.path(output_directory, "correlations.csv"), row.names = FALSE)
write.csv(numerical_checks, file.path(output_directory, "numerical-checks.csv"), row.names = FALSE)
writeLines(c(paste("Dataset seed:", dataset_seed), paste("Reference draws:", reference_draws),
  "One dataset; does not reproduce the previous repeated-study frequencies.",
  capture.output(sessionInfo())), file.path(output_directory, "session-info.txt"))
print(parameter_results, digits = 4)
print(correlation_results, digits = 4)
print(numerical_checks)
