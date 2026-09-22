# Run from the repository root: Rscript dev/diagnostic_checks/simulation-studies/fitting-examples/ordinal.R
# One original balanced dataset illustrates a fitting approximation, not flag rates.
# Both fits use the same ordinal model with one shared normal effect per dyad.
pkgload::load_all(quiet = TRUE)
output_directory <- "dev/diagnostic_checks/simulation-studies/results/fitting-examples/ordinal"
dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)
dataset_seed <- 40370923L
number_of_dyads <- 1000L
reference_draws <- 499L
true_thresholds <- c(-1.4, 0, 1.4)

set.seed(dataset_seed)
fitting_data <- data.frame(
  dyad = factor(rep(seq_len(number_of_dyads), each = 2L)),
  predictor = rnorm(2L * number_of_dyads)
)
latent_response <- 0.6 * fitting_data$predictor +
  rnorm(number_of_dyads)[fitting_data$dyad] + rlogis(nrow(fitting_data))
fitting_data$outcome <- cut(latent_response, c(-Inf, true_thresholds, Inf),
  labels = c("low", "medium", "high", "very high"), ordered_result = TRUE)

laplace_model <- glmmTMB::glmmTMB(outcome ~ predictor + (1 | dyad),
  data = fitting_data, family = glmmTMB::ordinal(link = "logit"))
quadrature_model <- ordinal::clmm(outcome ~ predictor + (1 | dyad),
  data = fitting_data, link = "logit", nAGQ = 25L)
accuracy_model <- ordinal::clmm(outcome ~ predictor + (1 | dyad),
  data = fitting_data, link = "logit", nAGQ = 50L)
stopifnot(laplace_model$fit$convergence == 0L, isTRUE(laplace_model$sdr$pdHess))
for (model in list(quadrature_model, accuracy_model)) {
  stopifnot(model$optRes$convergence == 0L,
    min(eigen(model$Hessian, symmetric = TRUE, only.values = TRUE)$values) > 0)
}

quadrature_parameters <- function(model) {
  c(slope = unname(model$beta["predictor"]),
    dyad_sd = unname(model$ST$dyad[1L, 1L]), unname(model$alpha))
}
parameters_by_method <- list(
  truth = c(slope = 0.6, dyad_sd = 1, true_thresholds),
  glmmTMB = c(slope = unname(glmmTMB::fixef(laplace_model)$cond["predictor"]),
    dyad_sd = unname(attr(glmmTMB::VarCorr(laplace_model)$cond$dyad, "stddev")),
    unname(glmmTMB::family_params(laplace_model))),
  quadrature_25 = quadrature_parameters(quadrature_model)
)
numerical_checks <- data.frame(
  maximum_parameter_difference = max(abs(quadrature_parameters(accuracy_model) -
    quadrature_parameters(quadrature_model))),
  log_likelihood_difference = as.numeric(logLik(accuracy_model) - logLik(quadrature_model))
)
stopifnot(numerical_checks$maximum_parameter_difference < 1e-4,
  abs(numerical_checks$log_likelihood_difference) < 1e-6)

# Reuse normal and logistic draws, so differences come from fitted parameters.
set.seed(dataset_seed + 2000000L)
standard_dyad_effects <- matrix(rnorm(reference_draws * number_of_dyads),
  nrow = reference_draws)
logistic_errors <- matrix(rlogis(reference_draws * nrow(fitting_data)),
  nrow = reference_draws)
first_partner_rows <- seq.int(1L, nrow(fitting_data), by = 2L)
correlation_results <- lapply(names(parameters_by_method), function(method) {
  parameters <- parameters_by_method[[method]]
  fitted_thresholds <- parameters[3:5]
  fixed_predictor <- parameters["slope"] * fitting_data$predictor
  simulated_latent <- sweep(parameters["dyad_sd"] *
    standard_dyad_effects[, as.integer(fitting_data$dyad)] + logistic_errors,
    2L, fixed_predictor, "+")
  simulated_scores <- matrix(1, nrow = reference_draws, ncol = nrow(fitting_data))
  for (threshold in fitted_thresholds) {
    simulated_scores <- simulated_scores + (simulated_latent > threshold)
  }
  # Expected category scores with the random effect set to zero, as in the check.
  expected_scores <- 1 + rowSums(vapply(fitted_thresholds,
    function(threshold) plogis(fixed_predictor - threshold), numeric(nrow(fitting_data))))
  centred_responses <- sweep(rbind(as.numeric(fitting_data$outcome), simulated_scores),
    2L, expected_scores, "-")
  correlations <- apply(centred_responses, 1L, function(responses) {
    dyadMLM:::calculate_partner_pair_statistics(responses[first_partner_rows],
      responses[first_partner_rows + 1L])[["Partner correlation (exchangeable)"]]
  })
  stopifnot(all(is.finite(correlations)))
  limits <- quantile(correlations[-1L], c(0.025, 0.975), names = FALSE)
  data.frame(method, observed = correlations[1L],
    reference_median = median(correlations[-1L]), lower = limits[1L], upper = limits[2L],
    flagged = correlations[1L] < limits[1L] || correlations[1L] > limits[2L])
})
parameter_results <- data.frame(method = names(parameters_by_method),
  do.call(rbind, parameters_by_method), row.names = NULL)
names(parameter_results)[4:6] <- paste0("threshold", 1:3)
correlation_results <- dplyr::bind_rows(correlation_results)
write.csv(parameter_results, file.path(output_directory, "parameters.csv"), row.names = FALSE)
write.csv(correlation_results, file.path(output_directory, "correlations.csv"), row.names = FALSE)
write.csv(numerical_checks, file.path(output_directory, "numerical-checks.csv"), row.names = FALSE)
writeLines(c(paste("Dataset seed:", dataset_seed), paste("Reference draws:", reference_draws),
  "One dataset; does not reproduce the previous repeated-study frequencies.",
  capture.output(sessionInfo())), file.path(output_directory, "session-info.txt"))
print(parameter_results, digits = 4)
print(correlation_results, digits = 4)
print(numerical_checks)
