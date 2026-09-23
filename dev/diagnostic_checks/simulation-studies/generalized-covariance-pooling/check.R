# Run after screening, from the repository root. Optional arguments select families.
# Compare the study's generating distribution with native simulation at known parameters.
source("dev/diagnostic_checks/simulation-studies/generalized-covariance-pooling/helpers.R")

known_covariance_simulator <- function(prepared_data, study_condition, family_name) {
  margin <- make_family_margin(family_name)
  specification <- do.call(glmmTMB::glmmTMB, c(list(
    formula = generalized_covariance_formula("composition"), data = prepared_data,
    doFit = FALSE, control = glmmTMB::glmmTMBControl(parallel = 1L)), margin$fit_arguments))
  parameters <- specification$parameters
  fixed_design <- stats::model.matrix(generalized_fixed_formula, prepared_data)
  parameters$beta <- as.numeric(qr.solve(fixed_design,
    true_fixed_predictor(prepared_data) + margin$mean_intercept))
  covariance <- true_latent_covariance(study_condition)
  # Same-role blocks use shared and difference effects. The mixed block uses two roles.
  parameters$theta <- c(
    log(sqrt((covariance$first_variance[1] + covariance$covariance[1]) / 2)),
    log(sqrt((covariance$first_variance[1] - covariance$covariance[1]) / 2)),
    log(sqrt(covariance$first_variance[2])), log(sqrt(covariance$second_variance[2])),
    covariance$correlation[2] / sqrt(1 - covariance$correlation[2]^2),
    log(sqrt((covariance$first_variance[3] + covariance$covariance[3]) / 2)),
    log(sqrt((covariance$first_variance[3] - covariance$covariance[3]) / 2))
  )
  distribution <- sub("^truncated_", "", if (family_name == "zi_poisson") "poisson" else
    if (family_name == "hurdle_nbinom2") "nbinom2" else family_name)
  if (length(parameters$betazi)) parameters$betazi <- qlogis(margin$zero_probability)
  if (length(parameters$betadisp)) parameters$betadisp <- log(switch(distribution,
    nbinom2 = 3, compois = 0.5, genpois = 2, Gamma = 3, beta = 8, lognormal = 2, 1))
  if (length(parameters$psi)) parameters$psi <- switch(distribution,
    nbinom12 = log(3), tweedie = 0, t = log(5))
  specification$parameters <- parameters
  glmmTMB::fitTMB(specification, doOptim = FALSE)
}

generate_known_covariance_responses <- function(prepared_data, study_condition, family_name, draws) {
  covariance <- true_latent_covariance(study_condition)
  composition_indices <- rep(1:3, c(study_condition$female_female_dyads,
    study_condition$female_male_dyads, study_condition$male_male_dyads))
  first_variance <- covariance$first_variance[composition_indices]
  second_variance <- covariance$second_variance[composition_indices]
  partner_covariance <- covariance$covariance[composition_indices]
  first_normal <- matrix(rnorm(draws * study_condition$n_dyads), nrow = draws)
  second_normal <- matrix(rnorm(draws * study_condition$n_dyads), nrow = draws)
  latent_effects <- matrix(0, nrow = draws, ncol = nrow(prepared_data))
  latent_effects[, seq(1L, nrow(prepared_data), 2L)] <-
    sweep(first_normal, 2L, sqrt(first_variance), "*")
  latent_effects[, seq(2L, nrow(prepared_data), 2L)] <-
    sweep(first_normal, 2L, partner_covariance / sqrt(first_variance), "*") +
    sweep(second_normal, 2L, sqrt(second_variance - partner_covariance^2 / first_variance), "*")
  conditional_predictor <- sweep(latent_effects, 2L, true_fixed_predictor(prepared_data), "+")
  matrix(make_family_margin(family_name)$quantile(runif(length(conditional_predictor)),
    as.vector(conditional_predictor)), nrow = draws)
}

paired_response_moments <- function(responses, study_condition) {
  dyad_composition <- rep(c("female-female", "female-male", "male-male"),
    c(study_condition$female_female_dyads, study_condition$female_male_dyads,
      study_condition$male_male_dyads))
  moments <- lapply(unique(dyad_composition), function(composition) {
    pair_indices <- which(dyad_composition == composition)
    first <- responses[, 2L * pair_indices - 1L, drop = FALSE]
    second <- responses[, 2L * pair_indices, drop = FALSE]
    first_centred <- first - rowMeans(first)
    second_centred <- second - rowMeans(second)
    values <- cbind(first_mean = rowMeans(first), second_mean = rowMeans(second),
      first_variance = rowSums(first_centred^2) / (length(pair_indices) - 1L),
      second_variance = rowSums(second_centred^2) / (length(pair_indices) - 1L),
      covariance = rowSums(first_centred * second_centred) / (length(pair_indices) - 1L))
    colnames(values) <- paste(composition, colnames(values), sep = ": ")
    values
  })
  do.call(cbind, moments)
}

check_generalized_covariance <- function(family_names, draws = 5000L) {
  stopifnot(length(family_names) > 0L,
    all(family_names %in% setdiff(generalized_family_names, c("ordinal", "skewnormal"))))
  output_directory <- file.path(study_directory, "results/generalized-covariance/implementation-checks")
  dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)
  conditions <- dplyr::filter(generalized_conditions, n_dyads == 40L,
    scenario %in% c("null", "variance_large", "correlation_large"))
  results <- list()
  for (family_name in family_names) {
    for (condition_index in seq_len(nrow(conditions))) {
      study_condition <- conditions[condition_index, ]
      dataset_seed <- 820000000L + 10000L * match(family_name, generalized_family_names) + condition_index
      prepared_data <- generate_generalized_covariance_data(study_condition, family_name, dataset_seed)
      stopifnot(identical(prepared_data$personID, seq_len(nrow(prepared_data))))
      native_simulator <- known_covariance_simulator(prepared_data, study_condition, family_name)
      set.seed(dataset_seed + 1000000L)
      native_responses <- t(replicate(draws, native_simulator$simulate()$yobs))
      generated_responses <- generate_known_covariance_responses(prepared_data, study_condition,
        family_name, draws)
      native_moments <- paired_response_moments(native_responses, study_condition)
      generated_moments <- paired_response_moments(generated_responses, study_condition)
      difference <- colMeans(native_moments) - colMeans(generated_moments)
      standard_error <- sqrt((apply(native_moments, 2L, var) +
        apply(generated_moments, 2L, var)) / draws)
      results[[length(results) + 1L]] <- tibble::tibble(family = family_name,
        scenario = study_condition$scenario, moment = colnames(native_moments),
        generated = colMeans(generated_moments), native = colMeans(native_moments),
        difference, standard_error, within_tolerance = abs(difference) <= 5 * standard_error)
      message(family_name, ": ", study_condition$scenario, " checked")
    }
  }
  summary <- dplyr::bind_rows(results)
  write.csv(summary, file.path(output_directory, "known-parameter-moments.csv"), row.names = FALSE)
  writeLines(c(capture.output(sessionInfo()),
    paste("glmmTMB commit:", packageDescription("glmmTMB")$RemoteSha)),
    file.path(output_directory, "session-info.txt"))
  stopifnot(all(summary$within_tolerance))
  message("All known-parameter response moments agreed within Monte Carlo uncertainty.")
  invisible(summary)
}

if (sys.nframe() == 0L) {
  family_names <- commandArgs(trailingOnly = TRUE)
  if (!length(family_names)) {
    screening_file <- file.path(study_directory, "report-data/generalized-covariance-screening/summary.csv")
    family_names <- if (file.exists(screening_file)) {
      selection <- read.csv(screening_file)
      selection$family[selection$selected]
    } else c("poisson", "nbinom1", "nbinom2", "Gamma", "beta", "lognormal")
  }
  check_generalized_covariance(family_names)
}
