# Run from the repository root. Arguments: repetitions, reference draws, dyads.
# These short development runs check model behavior, not precise rejection rates.
devtools::load_all(quiet = TRUE)
arguments <- commandArgs(trailingOnly = TRUE)
repetitions <- if (length(arguments) >= 1L) as.integer(arguments[1]) else 20L
reference_draws <- if (length(arguments) >= 2L) as.integer(arguments[2]) else 199L
number_of_dyads <- if (length(arguments) >= 3L) as.integer(arguments[3]) else 200L
stopifnot(repetitions > 0L, reference_draws >= 20L, number_of_dyads >= 3L)
output_directory <- file.path("dev/diagnostic_checks/simulation-studies/results/validation",
  paste0(repetitions, "-datasets-", reference_draws, "-draws-", number_of_dyads, "-dyads"))
dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)

gaussian_populations <- data.frame(
  population = c("positive", "zero", "negative", "unequal_sd"),
  first_sd = c(1, 1, 1, 0.8), second_sd = c(1, 1, 1, 1.4),
  correlation = c(0.5, 0, -0.5, 0.4)
)
population_names <- c(gaussian_populations$population, "zero_inflated_poisson", "hurdle_poisson")
set.seed(139000001L)
design <- data.frame(
  dyad = factor(rep(seq_len(number_of_dyads), each = 2)),
  role = factor(rep(c("first", "second"), number_of_dyads)),
  member_sign = rep(c(-1, 1), number_of_dyads),
  predictor = rep(rnorm(number_of_dyads, sd = 0.6), each = 2) +
    rnorm(2 * number_of_dyads, sd = 0.8)
)

draw_gaussian_responses <- function(expected_mean, population) {
  first_normal <- rnorm(length(expected_mean) / 2)
  second_normal <- population$correlation * first_normal +
    sqrt(1 - population$correlation^2) * rnorm(length(first_normal))
  expected_mean + as.vector(rbind(population$first_sd * first_normal,
                                 population$second_sd * second_normal))
}

generate_data <- function(population_name) {
  fitting_data <- design
  if (population_name %in% gaussian_populations$population) {
    population <- subset(gaussian_populations, population == population_name)
    fitting_data$expected_mean <- 0.6 * fitting_data$predictor
    if (population_name == "unequal_sd") {
      fitting_data$expected_mean <- fitting_data$expected_mean +
        rep(c(-0.3, 0.3), number_of_dyads)
    }
    fitting_data$outcome <- draw_gaussian_responses(fitting_data$expected_mean, population)
  } else {
    fitting_data$predictor <- runif(nrow(fitting_data), -1, 1)
    response_effect <- rep(rnorm(number_of_dyads, sd = 0.6), each = 2)
    zero_effect <- rep(rnorm(number_of_dyads, sd = 1.2), each = 2)
    poisson_mean <- exp(0.8 + 0.5 * fitting_data$predictor + response_effect)
    zero_probability <- plogis(-0.6 - 0.5 * fitting_data$predictor + zero_effect)
    outcome <- rpois(nrow(fitting_data), poisson_mean)
    if (population_name == "hurdle_poisson") {
      # Redraw zeros to obtain the positive-count component.
      while (any(outcome == 0)) {
        zero_rows <- which(outcome == 0)
        outcome[zero_rows] <- rpois(length(zero_rows), poisson_mean[zero_rows])
      }
    }
    outcome[rbinom(nrow(fitting_data), 1, zero_probability) == 1] <- 0
    fitting_data$outcome <- outcome
  }
  fitting_data
}

fit_validation_model <- function(fitting_data, population_name, model_name) {
  if (population_name %in% gaussian_populations$population) {
    if (population_name == "zero" || (model_name == "restricted" && population_name != "unequal_sd")) {
      return(glmmTMB::glmmTMB(outcome ~ predictor, data = fitting_data, family = gaussian()))
    }
    model_formula <- if (population_name == "unequal_sd") {
      if (model_name == "correct") {
        outcome ~ 0 + role + predictor + (0 + role | dyad)
      } else {
        outcome ~ 0 + role + predictor + (1 | dyad) + (0 + member_sign | dyad)
      }
    } else {
      outcome ~ predictor + (1 | dyad) + (0 + member_sign | dyad)
    }
    # The Gaussian dyad block represents the residual covariance.
    return(glmmTMB::glmmTMB(model_formula, data = fitting_data,
                           family = gaussian(), dispformula = ~0))
  }
  model_formula <- if (model_name == "correct") outcome ~ predictor + (1 | dyad) else outcome ~ predictor
  zero_formula <- if (model_name == "correct") ~ predictor + (1 | dyad) else ~ predictor
  glmmTMB::glmmTMB(model_formula, ziformula = zero_formula, data = fitting_data,
    family = if (population_name == "hurdle_poisson") glmmTMB::truncated_poisson() else poisson())
}

record_statistics <- function(check, response_scale) {
  composition_statistics <- check$compositions$statistics[[1]]
  dplyr::bind_rows(lapply(names(composition_statistics)[-1], function(statistic_name) {
    values <- composition_statistics[[statistic_name]]
    reference_values <- values[-1]
    undefined_draws <- sum(!is.finite(reference_values))
    reference_values <- reference_values[is.finite(reference_values)]
    reference_limits <- quantile(reference_values, c(0.025, 0.975), names = FALSE)
    data.frame(response_scale, statistic = statistic_name, observed = values[1],
      reference_median = median(reference_values), reference_lower = reference_limits[1],
      reference_upper = reference_limits[2], undefined_reference_draws = undefined_draws,
      observed_position = (1 + sum(reference_values <= values[1])) / (length(reference_values) + 1),
      below = values[1] < reference_limits[1], above = values[1] > reference_limits[2])
  }))
}

fit_results <- statistic_results <- list()
for (population_index in seq_along(population_names)) {
  population_name <- population_names[population_index]
  model_names <- if (population_name == "positive") c("known_parameters", "correct", "restricted") else
    if (population_name == "zero") "correct" else c("correct", "restricted")
  role_column <- if (population_name == "unequal_sd") "role" else NULL
  for (repetition in seq_len(repetitions)) {
    dataset_seed <- 140000000L + 100000L * population_index + repetition
    set.seed(dataset_seed)
    fitting_data <- generate_data(population_name)
    for (model_index in seq_along(model_names)) {
      model_name <- model_names[model_index]
      reference_seed <- 160000000L + 1000000L * population_index + 10000L * model_index + repetition
      fit_status <- data.frame(population = population_name, model = model_name,
        repetition, n_dyads = number_of_dyads, dataset_seed, reference_seed,
        status = "fit_error", convergence = NA_integer_, positive_hessian = NA,
        warnings = "", error = "")
      warning_messages <- character()
      statistics <- tryCatch(withCallingHandlers({
        if (model_name == "known_parameters") {
          # Independent draws at the true parameters separate the check from estimation.
          set.seed(reference_seed)
          simulated_responses <- t(replicate(reference_draws, draw_gaussian_responses(
            fitting_data$expected_mean, gaussian_populations[1, ])))
          simulations <- structure(list(observed_response = fitting_data$outcome,
            simulated_responses = simulated_responses, predicted_response = fitting_data$expected_mean,
            model_frame = data.frame(outcome = fitting_data$outcome)),
            class = c("dyadMLM_response_simulations", "list"), dyadMLM = list(
              backend = "glmmTMB", family = "gaussian", link = "identity",
              reference = "known-parameter control", random_effects = "known covariance",
              parameter_uncertainty = "not applicable", seed = reference_seed))
          fit_status$status <- "check_error"
        } else {
          model <- fit_validation_model(fitting_data, population_name, model_name)
          fit_status$convergence <- model$fit$convergence
          fit_status$positive_hessian <- isTRUE(model$sdr$pdHess)
          fit_status$status <- "fit_problem"
          if (fit_status$convergence == 0L && fit_status$positive_hessian) {
            fit_status$status <- "check_error"
            simulations <- simulate_dyad_responses(model, nsim = reference_draws, seed = reference_seed)
          }
        }
        if (fit_status$status == "check_error") {
          checked_statistics <- lapply(c("raw", "model-centred"), function(response_scale) {
            check <- check_partner_dependence(simulations, dyad = dyad, role = !!role_column,
              data = fitting_data, response = response_scale, plot = FALSE)
            stopifnot(check$n_pairs == number_of_dyads)
            record_statistics(check, response_scale)
          }) |> dplyr::bind_rows()
          fit_status$status <- "success"
          checked_statistics
        } else NULL
      }, warning = function(warning) {
        warning_messages <<- c(warning_messages, conditionMessage(warning))
        invokeRestart("muffleWarning")
      }), error = function(error) {
        fit_status$error <<- conditionMessage(error)
        NULL
      })
      fit_status$warnings <- paste(unique(warning_messages), collapse = " | ")
      fit_results[[length(fit_results) + 1L]] <- fit_status
      if (!is.null(statistics)) {
        statistic_results[[length(statistic_results) + 1L]] <- cbind(
          fit_status[c("population", "model", "repetition", "n_dyads")], statistics)
      }
    }
  }
  message(population_name, ": complete")
}
fits <- dplyr::bind_rows(fit_results)
statistics <- dplyr::bind_rows(statistic_results)
write.csv(fits, file.path(output_directory, "fits.csv"), row.names = FALSE)
write.csv(statistics, file.path(output_directory, "statistics.csv"), row.names = FALSE)
writeLines(c("Short development validation; frequencies are not precise rejection-rate estimates.",
  paste("Repetitions:", repetitions), paste("Reference draws:", reference_draws),
  paste("Dyads:", number_of_dyads), paste("glmmTMB commit:", packageDescription("glmmTMB")$RemoteSha),
  capture.output(sessionInfo())), file.path(output_directory, "session-info.txt"))
print(dplyr::count(fits, population, model, status))
