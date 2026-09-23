# Run from the repository root. These checks validate the study implementation.
devtools::load_all(quiet = TRUE)
study_directory <- "dev/diagnostic_checks/simulation-studies"
source(file.path(study_directory, "shared/family-margins.R"))
output_directory <- file.path(study_directory, "results/family-comparison/implementation-checks")
dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)

# Load the actual shortcut without starting the simulation study.
study_expressions <- parse(file.path(study_directory, "family-comparison/run.R"))
for (expression in study_expressions) {
  if (is.call(expression) && identical(expression[[1]], as.name("<-")) &&
      identical(expression[[2]], as.name("partner_correlations"))) eval(expression)
}

family_names <- c("gaussian", "poisson", "nbinom1", "nbinom2", "nbinom12", "compois", "genpois",
  "truncated_poisson", "truncated_nbinom1", "truncated_nbinom2", "truncated_compois",
  "truncated_genpois", "tweedie", "Gamma", "beta", "lognormal", "skewnormal", "bell", "t",
  "ordinal", "zi_poisson", "hurdle_nbinom2")
margin_checks <- list()
for (family_name in family_names) {
  margin <- make_family_margin(family_name)
  distribution <- sub("^truncated_", "", if (family_name == "zi_poisson") "poisson" else
    if (family_name == "hurdle_nbinom2") "truncated_nbinom2" else family_name)
  fitting_data <- data.frame(predictor = rep(c(-1, 0, 1), 4), outcome = rep(1:4, 3))
  if (distribution == "ordinal") fitting_data$outcome <- ordered(fitting_data$outcome)
  if (distribution == "beta") fitting_data$outcome <- fitting_data$outcome / 5
  model_arguments <- c(list(outcome ~ predictor, data = fitting_data), margin$fit_arguments)
  model_specification <- do.call(glmmTMB::glmmTMB, c(model_arguments, list(doFit = FALSE)))
  true_parameters <- model_specification$parameters
  true_parameters$beta <- c(margin$mean_intercept, 1)
  if (length(true_parameters$betazi)) true_parameters$betazi <- qlogis(margin$zero_probability)
  if (length(true_parameters$betadisp)) {
    true_parameters$betadisp <- log(switch(distribution,
      nbinom2 = 3, compois = 0.5, genpois = 2, Gamma = 3, beta = 8, lognormal = 2, 1))
  }
  if (length(true_parameters$psi)) {
    true_parameters$psi <- switch(distribution,
      t = log(5), nbinom12 = log(3), tweedie = 0, skewnormal = 1,
      ordinal = {
        category_probabilities <- diff(c(0, plogis(c(-1, 0, 1)), 1))
        log(category_probabilities[1:3] / category_probabilities[4])
      })
  }
  model_specification$parameters <- true_parameters
  simulation_object <- glmmTMB::fitTMB(model_specification, doOptim = FALSE)
  set.seed(39000000L + match(family_name, family_names))
  native_simulations <- replicate(10000L, simulation_object$simulate()$yobs)
  # Keep the supplied parameters fixed. The optimizer's immediate stop is intentional.
  fitted_model <- suppressWarnings(do.call(glmmTMB::glmmTMB, c(model_arguments, list(
    start = true_parameters,
    control = glmmTMB::glmmTMBControl(optCtrl = list(iter.max = 0, eval.max = 1))))))
  prediction_error <- max(abs(predict(fitted_model, type = "response") -
    margin$response_mean(fitting_data$predictor)))
  stopifnot(prediction_error < 1e-7)
  for (linear_predictor in c(-1, 0, 1)) {
    quantile_outcomes <- margin$quantile((seq_len(50000L) - 0.5) / 50000,
      rep(linear_predictor, 50000L))
    native_outcomes <- as.vector(native_simulations[fitting_data$predictor == linear_predictor, ])
    expected_mean <- margin$response_mean(linear_predictor)
    native_mean_standard_error <- sd(native_outcomes) / sqrt(length(native_outcomes))
    # Compare distribution shapes too; discrete outcomes can share quantile cutpoints.
    cutpoints <- margin$quantile(c(0.1, 0.5, 0.9), rep(linear_predictor, 3L))
    expected_cdf <- vapply(cutpoints, function(value) mean(quantile_outcomes <= value), numeric(1))
    native_cdf <- vapply(cutpoints, function(value) mean(native_outcomes <= value), numeric(1))
    cdf_tolerance <- pmax(0.001, 5 * sqrt(expected_cdf * (1 - expected_cdf) / length(native_outcomes)))
    stopifnot(all(is.finite(quantile_outcomes)), abs(mean(quantile_outcomes) - expected_mean) < 0.003,
      abs(mean(native_outcomes) - expected_mean) < 5 * native_mean_standard_error,
      all(abs(native_cdf - expected_cdf) < cdf_tolerance))
    margin_checks[[length(margin_checks) + 1L]] <- data.frame(family = family_name, linear_predictor,
      expected_mean, quantile_mean = mean(quantile_outcomes), native_mean = mean(native_outcomes),
      quantile_variance = var(quantile_outcomes), native_variance = var(native_outcomes),
      maximum_cdf_error = max(abs(native_cdf - expected_cdf)), prediction_error)
  }
  message(family_name, ": response margin passed")
}
write.csv(dplyr::bind_rows(margin_checks), file.path(output_directory, "response-margins.csv"), row.names = FALSE)

correlation_checks <- list()
for (family_name in c("gaussian", "poisson", "nbinom2")) {
  for (number_of_dyads in c(20L, 1000L)) {
    set.seed(40000000L + number_of_dyads)
    margin <- make_family_margin(family_name)
    actor_predictor <- rnorm(2L * number_of_dyads)
    partner_predictor <- as.vector(matrix(actor_predictor, nrow = 2L)[2:1, ])
    fitting_data <- data.frame(dyad = rep(seq_len(number_of_dyads), each = 2L),
      role = rep(c("first", "second"), number_of_dyads), actor_predictor, partner_predictor,
      outcome = margin$quantile(runif(2L * number_of_dyads), 0.5 * actor_predictor + 0.3 * partner_predictor))
    fitted_model <- do.call(glmmTMB::glmmTMB, c(list(
      outcome ~ actor_predictor + partner_predictor, data = fitting_data), margin$fit_arguments))
    simulations <- simulate_dyad_responses(fitted_model, seed = 41000000L + number_of_dyads)
    for (response_mode in c("model-centred", "raw")) {
      public_check <- check_partner_dependence(simulations, dyad = dyad, role = role,
        data = fitting_data, response = response_mode, plot = FALSE)
      public_values <- public_check$compositions$statistics[[1L]][["Partner correlation (first and second)"]]
      responses <- rbind(simulations$observed_response, simulations$simulated_responses)
      if (response_mode == "model-centred") responses <- sweep(responses, 2L, simulations$predicted_response, "-")
      shortcut_values <- partner_correlations(responses)
      public_limits <- quantile(public_values[-1L], c(0.025, 0.975))
      shortcut_limits <- quantile(shortcut_values[-1L], c(0.025, 0.975))
      public_flag <- public_values[1L] < public_limits[1L] || public_values[1L] > public_limits[2L]
      shortcut_flag <- shortcut_values[1L] < shortcut_limits[1L] || shortcut_values[1L] > shortcut_limits[2L]
      maximum_difference <- max(abs(public_values - shortcut_values))
      stopifnot(maximum_difference < 1e-12, max(abs(public_limits - shortcut_limits)) < 1e-12,
        identical(public_flag, shortcut_flag))
      correlation_checks[[length(correlation_checks) + 1L]] <- data.frame(
        family = family_name, number_of_dyads, response = response_mode, maximum_difference)
    }
  }
}
write.csv(dplyr::bind_rows(correlation_checks), file.path(output_directory, "partner-correlations.csv"), row.names = FALSE)
writeLines(c(paste("glmmTMB commit:", packageDescription("glmmTMB")$RemoteSha), capture.output(sessionInfo())),
  file.path(output_directory, "session-info.txt"))
message("All response-margin and partner-correlation checks passed.")
