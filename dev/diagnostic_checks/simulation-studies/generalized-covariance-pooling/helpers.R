# Shared data generation and fitting for the screening and main study.
source("dev/diagnostic_checks/simulation-studies/covariance-pooling/run.R")
source(file.path(study_directory, "shared/family-margins.R"))

generalized_family_names <- c("poisson", "nbinom1", "nbinom2", "nbinom12", "compois",
  "genpois", "truncated_poisson", "truncated_nbinom1", "truncated_nbinom2",
  "truncated_compois", "truncated_genpois", "tweedie", "Gamma", "beta", "lognormal",
  "skewnormal", "bell", "t", "ordinal", "zi_poisson", "hurdle_nbinom2")
generalized_conditions <- dplyr::filter(study_conditions, allocation == "balanced")
generalized_fixed_formula <- outcome ~ 0 + .composition_role +
  .composition_role:(.support_actor + .support_partner)

true_fixed_predictor <- function(prepared_data) {
  role_indicators <- as.matrix(prepared_data[c(".is_female_x_female",
    ".is_female_x_male_female", ".is_female_x_male_male", ".is_male_x_male")])
  as.numeric(role_indicators %*% c(0.2, 0.4, -0.2, -0.1)) +
    as.numeric(role_indicators %*% c(0.5, 0.6, 0.4, 0.3)) * prepared_data$.support_actor +
    as.numeric(role_indicators %*% c(0.3, 0.2, 0.4, 0.2)) * prepared_data$.support_partner
}

true_latent_covariance <- function(condition) {
  dplyr::tibble(composition = c("female-female", "female-male", "male-male"),
    first_variance = 0.36 * c(1, 2 * condition$sd_ratio^2 / (1 + condition$sd_ratio^2), 1),
    second_variance = 0.36 * c(1, 2 / (1 + condition$sd_ratio^2), 1),
    covariance = 0.36 * (0.3 + c(-1, 0, 1) * condition$correlation_difference)) |>
    dplyr::mutate(correlation = covariance / sqrt(first_variance * second_variance))
}

generate_generalized_covariance_data <- function(condition, family_name, dataset_seed) {
  prepared_data <- generate_covariance_data(condition, dataset_seed)
  fixed_predictor <- true_fixed_predictor(prepared_data)
  # The existing Gaussian generator supplies paired errors with the chosen covariance.
  latent_effect <- 0.6 * (prepared_data$outcome - fixed_predictor)
  margin <- make_family_margin(family_name)
  prepared_data$outcome <- margin$quantile(runif(nrow(prepared_data)), fixed_predictor + latent_effect)
  if (family_name == "ordinal") prepared_data$outcome <- ordered(prepared_data$outcome, levels = 1:4)
  prepared_data
}

generalized_covariance_formula <- function(model_name) {
  if (model_name == "pooled") {
    update(generalized_fixed_formula, . ~ . +
      us(1 | coupleID) + us(0 + pooled_member_contrast | coupleID))
  } else {
    update(generalized_fixed_formula, . ~ . +
      us(0 + .is_female_x_female | coupleID) +
      us(0 + .member_contrast_female_x_female_arbitrary | coupleID) +
      us(0 + .is_female_x_male_female + .is_female_x_male_male | coupleID) +
      us(0 + .is_male_x_male | coupleID) +
      us(0 + .member_contrast_male_x_male_arbitrary | coupleID))
  }
}

fit_generalized_covariance_model <- function(prepared_data, family_name, model_name) {
  warning_messages <- character()
  error_message <- ""
  elapsed <- system.time(fitted_model <- tryCatch(withCallingHandlers(
    do.call(glmmTMB::glmmTMB, c(list(formula = generalized_covariance_formula(model_name), data = prepared_data,
      REML = FALSE, control = glmmTMB::glmmTMBControl(parallel = 1L)),
      make_family_margin(family_name)$fit_arguments)),
    warning = function(warning) {
      warning_messages <<- c(warning_messages, conditionMessage(warning))
      invokeRestart("muffleWarning")
    }), error = function(error) {
      error_message <<- conditionMessage(error)
      NULL
    }))["elapsed"]
  usable <- !is.null(fitted_model) && fitted_model$fit$convergence == 0L &&
    isTRUE(fitted_model$sdr$pdHess) && is.finite(as.numeric(logLik(fitted_model)))
  list(model = fitted_model, status = tibble::tibble(model = model_name, usable,
    convergence = if (is.null(fitted_model)) NA_integer_ else fitted_model$fit$convergence,
    positive_hessian = if (is.null(fitted_model)) NA else isTRUE(fitted_model$sdr$pdHess),
    warnings = paste(unique(warning_messages), collapse = " | "), error = error_message,
    elapsed_seconds = as.numeric(elapsed)))
}

recover_latent_covariance <- function(model, model_name) {
  blocks <- glmmTMB::VarCorr(model)$cond
  if (model_name == "pooled") {
    first_variance <- second_variance <- rep(blocks[[1]][1, 1] + blocks[[2]][1, 1], 3)
    covariance <- rep(blocks[[1]][1, 1] - blocks[[2]][1, 1], 3)
  } else {
    first_variance <- c(blocks[[1]][1, 1] + blocks[[2]][1, 1], blocks[[3]][1, 1],
      blocks[[4]][1, 1] + blocks[[5]][1, 1])
    second_variance <- first_variance
    second_variance[2] <- blocks[[3]][2, 2]
    covariance <- c(blocks[[1]][1, 1] - blocks[[2]][1, 1], blocks[[3]][1, 2],
      blocks[[4]][1, 1] - blocks[[5]][1, 1])
  }
  tibble::tibble(composition = c("female-female", "female-male", "male-male"),
    first_variance, second_variance, covariance,
    correlation = covariance / sqrt(first_variance * second_variance))
}

record_generalized_check <- function(check, check_type) {
  dplyr::bind_rows(lapply(seq_len(nrow(check$compositions)), function(composition_index) {
    values <- check$compositions$statistics[[composition_index]]
    reference_values <- values[-1, -1]
    reference_limits <- vapply(reference_values, function(values) {
      quantile(values[is.finite(values)], c(0.025, 0.975), names = FALSE)
    }, numeric(2))
    observed <- as.numeric(values[1, -1])
    tibble::tibble(check_type,
      composition = gsub(" - ", "-", check$compositions$label[composition_index], fixed = TRUE),
      statistic = names(values)[-1], observed,
      reference_median = vapply(reference_values, median, numeric(1), na.rm = TRUE),
      lower = reference_limits[1, ], upper = reference_limits[2, ],
      below = observed < lower, above = observed > upper,
      flagged = below | above,
      undefined_draws = vapply(reference_values, function(values) sum(!is.finite(values)), integer(1)))
  }))
}
