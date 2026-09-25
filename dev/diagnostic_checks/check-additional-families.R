# Run from the repository root with Rscript. Bell models also require gsl.
# Check response formats and prediction/simulation agreement, not calibration.
pkgload::load_all(quiet = TRUE)
message("glmmTMB ", utils::packageVersion("glmmTMB"))

count_families <- list(
  nbinom12 = glmmTMB::nbinom12(),
  compois = glmmTMB::compois(),
  genpois = glmmTMB::genpois(),
  truncated_poisson = glmmTMB::truncated_poisson(),
  truncated_nbinom1 = glmmTMB::truncated_nbinom1(),
  truncated_nbinom2 = glmmTMB::truncated_nbinom2(),
  truncated_compois = glmmTMB::truncated_compois(),
  truncated_genpois = glmmTMB::truncated_genpois()
)
families <- c(count_families, list(
  lognormal = glmmTMB::lognormal(),
  skewnormal = glmmTMB::skewnormal(),
  bell = glmmTMB::bell(),
  t = glmmTMB::t_family()
))

draw_count_responses <- function(family_name, response_means) {
  switch(sub("^truncated_", "", family_name),
    nbinom1 = rnbinom(length(response_means), mu = response_means,
                     size = response_means / 1.4),
    nbinom12 = rnbinom(length(response_means), mu = response_means,
                      size = response_means / (1.4 + response_means / 4)),
    nbinom2 =, genpois = rnbinom(length(response_means), mu = response_means, size = 4),
    rpois(length(response_means), response_means)
  )
}

for (family_index in seq_along(families)) {
  family_name <- names(families)[family_index]
  message("Checking ", family_name)
  is_count_family <- family_name %in% names(count_families)
  number_of_rows <- if (is_count_family || family_name == "bell") 1200L else 360L
  set.seed(if (is_count_family) 7301L + 100L * family_index else 7901L)
  fitting_data <- data.frame(
    dyad = rep(seq_len(number_of_rows / 2L), each = 2L),
    predictor = rep(c(-0.5, 0, 0.5), length.out = number_of_rows)
  )

  if (is_count_family) {
    fitting_data$predictor <- factor(rep(rep(c("low", "medium", "high"), each = 2),
                                         length.out = number_of_rows))
    response_means <- c(low = 1.5, medium = 5, high = 15)[as.character(fitting_data$predictor)]
    fitting_data$response <- draw_count_responses(family_name, response_means)
    if (startsWith(family_name, "truncated_")) {
      while (any(fitting_data$response == 0)) {
        zero_rows <- which(fitting_data$response == 0)
        fitting_data$response[zero_rows] <- draw_count_responses(
          family_name, response_means[zero_rows]
        )
      }
    }
  } else {
    positive_means <- exp(0.7 + 0.25 * fitting_data$predictor)
    fitting_data$response <- switch(family_name,
      lognormal = rlnorm(number_of_rows, log(positive_means) - 0.125, 0.5),
      skewnormal = 1 + 0.4 * fitting_data$predictor +
        abs(rnorm(number_of_rows)) + rnorm(number_of_rows, 0, 0.3),
      bell = rpois(number_of_rows, 0.8 * rpois(number_of_rows, exp(0.8))),
      t = 1 + 0.4 * fitting_data$predictor + 0.5 * rt(number_of_rows, df = 6)
    )
  }

  # Omit complete dyads through both response and predictor missingness.
  fitting_data$response[1:2] <- NA
  fitting_data$predictor[9:10] <- NA
  expected_rows <- which(complete.cases(fitting_data))
  model_arguments <- list(
    formula = response ~ predictor, data = fitting_data,
    family = families[[family_name]], na.action = na.exclude
  )
  if (family_name == "skewnormal") model_arguments$start <- list(psi = 2)
  if (family_name == "t") {
    model_arguments$start <- list(psi = log(6))
    model_arguments$map <- list(psi = factor(NA))
  }
  fitted_model <- do.call(glmmTMB::glmmTMB, model_arguments)
  stopifnot(fitted_model$fit$convergence == 0L, isTRUE(fitted_model$sdr$pdHess))

  single_simulation <- simulate_dyad_responses(fitted_model, nsim = 1, seed = 443)
  simulations <- simulate_dyad_responses(fitted_model, nsim = 400, seed = 444)
  stopifnot(
    identical(dim(single_simulation$simulated_responses), c(1L, length(expected_rows))),
    identical(dim(simulations$simulated_responses), c(400L, length(expected_rows))),
    identical(row.names(simulations$model_frame), as.character(expected_rows)),
    identical(simulations$observed_response, as.numeric(fitting_data$response[expected_rows])),
    length(simulations$predicted_response) == length(expected_rows),
    all(is.finite(simulations$predicted_response)),
    all(is.finite(simulations$simulated_responses))
  )

  # Without random effects, response predictions should match simulated means.
  # Check each predictor group, allowing for Monte Carlo uncertainty.
  for (predictor_value in unique(simulations$model_frame$predictor)) {
    group_rows <- simulations$model_frame$predictor == predictor_value
    simulated_means <- rowMeans(simulations$simulated_responses[, group_rows, drop = FALSE])
    predicted_mean <- mean(simulations$predicted_response[group_rows])
    monte_carlo_se <- sd(simulated_means) / sqrt(length(simulated_means))
    stopifnot(abs(mean(simulated_means) - predicted_mean) < 6 * monte_carlo_se)
  }

  for (response_scale in c("raw", "model-centred")) {
    # The dyad column is absent from the model formula, so supply fitting data.
    check <- check_partner_dependence(
      simulations, dyad = dyad, role = NULL, data = fitting_data,
      response = response_scale, plot = FALSE
    )
    stopifnot(
      check$n_pairs == length(expected_rows) / 2L,
      all(is.finite(as.matrix(check$compositions$statistics[[1]][, -1])))
    )
  }
}
message("All additional families passed.")
