# Run from the repository root. Arguments: datasets, reference draws, workers, run/summarise.
devtools::load_all(quiet = TRUE)
study_directory <- "dev/diagnostic_checks/simulation-studies"

covariance_scenarios <- tibble::tibble(
  scenario = c("null", "variance_small", "variance_large", "correlation_small", "correlation_large"),
  sd_ratio = c(1, 1.25, 1.5, 1, 1),
  correlation_difference = c(0, 0, 0, 0.2, 0.4)
)
study_conditions <- dplyr::bind_rows(
  tidyr::crossing(n_dyads = c(40L, 60L, 100L, 200L, 400L), covariance_scenarios) |>
    dplyr::mutate(allocation = "balanced"),
  dplyr::mutate(covariance_scenarios, n_dyads = 100L, allocation = "unbalanced")
) |>
  dplyr::mutate(
    condition = dplyr::row_number(),
    female_female_dyads = ifelse(allocation == "balanced", round(n_dyads / 3), 20L),
    male_male_dyads = female_female_dyads,
    female_male_dyads = n_dyads - female_female_dyads - male_male_dyads
  )

generate_covariance_data <- function(condition, dataset_seed) {
  set.seed(dataset_seed)
  dyad_composition <- rep(c("female-female", "female-male", "male-male"),
    c(condition$female_female_dyads, condition$female_male_dyads, condition$male_male_dyads))
  first_predictor <- rnorm(condition$n_dyads)
  second_predictor <- 0.3 * first_predictor + sqrt(1 - 0.3^2) * rnorm(condition$n_dyads)
  generated_data <- data.frame(
    coupleID = factor(rep(seq_len(condition$n_dyads), each = 2)),
    personID = seq_len(2 * condition$n_dyads),
    gender = factor(as.vector(rbind(
      ifelse(dyad_composition == "male-male", "male", "female"),
      ifelse(dyad_composition == "female-female", "female", "male")
    )), levels = c("female", "male")),
    support = as.vector(rbind(first_predictor, second_predictor))
  )
  prepared_data <- prepare_dyad_data(
    generated_data, dyad = coupleID, member = personID, role = gender,
    predictors = support, model_types = "apim",
    include_arbitrary_member_contrast = TRUE, seed = dataset_seed
  )
  # Each contrast is zero outside its composition. Their sum covers every dyad.
  prepared_data$pooled_member_contrast <- with(prepared_data,
    .member_contrast_female_x_female_arbitrary +
      .member_contrast_female_x_male_arbitrary + .member_contrast_male_x_male_arbitrary)
  mean_coefficients <- tibble::tibble(
    intercept = c(0.2, 0.4, -0.2, -0.1),
    actor_effect = c(0.5, 0.6, 0.4, 0.3),
    partner_effect = c(0.3, 0.2, 0.4, 0.2)
  )
  # Use the package's composition-role indicators to keep the row order unchanged.
  role_indicators <- as.matrix(prepared_data[c(".is_female_x_female",
    ".is_female_x_male_female", ".is_female_x_male_male", ".is_male_x_male")])
  expected_response <- as.numeric(role_indicators %*% mean_coefficients$intercept) +
    as.numeric(role_indicators %*% mean_coefficients$actor_effect) * prepared_data$.support_actor +
    as.numeric(role_indicators %*% mean_coefficients$partner_effect) * prepared_data$.support_partner

  mixed_dyad <- dyad_composition == "female-male"
  first_variance <- ifelse(mixed_dyad, 2 * condition$sd_ratio^2 / (1 + condition$sd_ratio^2), 1)
  second_variance <- ifelse(mixed_dyad, 2 / (1 + condition$sd_ratio^2), 1)
  partner_covariance <- 0.3 + condition$correlation_difference *
    ifelse(dyad_composition == "female-female", -1, ifelse(dyad_composition == "male-male", 1, 0))
  first_error <- rnorm(condition$n_dyads)
  second_error <- partner_covariance / sqrt(first_variance) * first_error +
    sqrt(second_variance - partner_covariance^2 / first_variance) * rnorm(condition$n_dyads)
  prepared_data$outcome <- expected_response +
    as.vector(rbind(sqrt(first_variance) * first_error, second_error))
  prepared_data
}

fit_covariance_model <- function(prepared_data, model_name) {
  model_formula <- outcome ~ 0 + .composition_role +
    .composition_role:(.support_actor + .support_partner)
  model_formula <- if (model_name == "pooled") {
    update(model_formula, . ~ . + us(1 | coupleID) + us(0 + pooled_member_contrast | coupleID))
  } else {
    update(model_formula, . ~ . +
      us(0 + .is_female_x_female | coupleID) +
      us(0 + .member_contrast_female_x_female_arbitrary | coupleID) +
      us(0 + .is_female_x_male_female + .is_female_x_male_male | coupleID) +
      us(0 + .is_male_x_male | coupleID) +
      us(0 + .member_contrast_male_x_male_arbitrary | coupleID))
  }
  warning_messages <- character()
  error_message <- ""
  fitted_model <- tryCatch(withCallingHandlers(
    glmmTMB::glmmTMB(model_formula, data = prepared_data, family = gaussian(),
      dispformula = ~0, REML = FALSE),
    warning = function(warning) {
      warning_messages <<- c(warning_messages, conditionMessage(warning))
      invokeRestart("muffleWarning")
    }), error = function(error) {
      error_message <<- conditionMessage(error)
      NULL
    })
  usable <- !is.null(fitted_model) && fitted_model$fit$convergence == 0L &&
    isTRUE(fitted_model$sdr$pdHess) && is.finite(as.numeric(logLik(fitted_model)))
  list(model = fitted_model, status = tibble::tibble(model = model_name, usable,
    convergence = if (is.null(fitted_model)) NA_integer_ else fitted_model$fit$convergence,
    positive_hessian = if (is.null(fitted_model)) NA else isTRUE(fitted_model$sdr$pdHess),
    warnings = paste(unique(warning_messages), collapse = " | "), error = error_message))
}

# Population values follow the same order as the package's plotted summaries.
population_summaries <- function(first_variance, second_variance, covariance, distinct_roles) {
  mean_variance <- (first_variance + second_variance + 2 * covariance) / 4
  difference_variance <- (first_variance + second_variance - 2 * covariance) / 4
  if (distinct_roles) {
    c(sqrt(first_variance), sqrt(second_variance), covariance / sqrt(first_variance * second_variance),
      sqrt(mean_variance), sqrt(difference_variance),
      (first_variance - second_variance) / (4 * sqrt(mean_variance * difference_variance)))
  } else {
    c(sqrt((first_variance + second_variance) / 2), 2 * covariance / (first_variance + second_variance),
      sqrt(mean_variance), sqrt(difference_variance))
  }
}

record_covariance_check <- function(check, condition, check_type) {
  dplyr::bind_rows(lapply(seq_len(nrow(check$compositions)), function(composition_index) {
    composition <- gsub(" - ", "-", check$compositions$label[composition_index], fixed = TRUE)
    values <- check$compositions$statistics[[composition_index]]
    distinct_roles <- ncol(values) == 7L
    first_variance <- second_variance <- 1
    covariance <- 0.3
    if (composition == "female-male") {
      first_variance <- 2 * condition$sd_ratio^2 / (1 + condition$sd_ratio^2)
      second_variance <- 2 / (1 + condition$sd_ratio^2)
    }
    if (composition == "female-female") covariance <- covariance - condition$correlation_difference
    if (composition == "male-male") covariance <- covariance + condition$correlation_difference
    true_values <- population_summaries(first_variance, second_variance, covariance, distinct_roles)
    pooled_values <- population_summaries(1, 1, 0.3, distinct_roles)
    reference_limits <- vapply(values[-1], function(statistic) quantile(statistic[-1], c(0.025, 0.975)), numeric(2))
    observed_values <- as.numeric(values[1, -1])
    tibble::tibble(check_type, composition, statistic = names(values)[-1],
      true_value = true_values, pooled_value = pooled_values,
      expected_direction = sign(round(true_values - pooled_values, 10)),
      observed = observed_values, lower = reference_limits[1, ], upper = reference_limits[2, ],
      below = observed < lower, above = observed > upper, flagged = below | above)
  }))
}

run_covariance_dataset <- function(condition, repetition, reference_draws) {
  dataset_seed <- 410000000L + 100000L * condition$condition + repetition
  prepared_data <- generate_covariance_data(condition, dataset_seed)
  pooled_fit <- fit_covariance_model(prepared_data, "pooled")
  composition_fit <- fit_covariance_model(prepared_data, "composition")
  fits <- dplyr::bind_rows(pooled_fit$status, composition_fit$status) |>
    dplyr::mutate(condition = condition$condition, repetition, dataset_seed,
      check_error = "", comparison_error = "")
  statistics <- NULL
  outcomes <- tibble::tibble(condition = condition$condition, repetition,
    pooled_any = NA, composition_any = NA, expected_direction = NA, opposite_direction = NA,
    likelihood_ratio = NA, composition_without_pooled = NA, composition_without_lrt = NA)
  if (pooled_fit$status$usable) {
    statistics <- tryCatch({
      simulations <- simulate_dyad_responses(pooled_fit$model, nsim = reference_draws,
        seed = dataset_seed + 10000000L)
      pooled_check <- check_partner_dependence(simulations, dyad = coupleID, role = NULL, plot = FALSE)
      # Gender is not in the formula, so supply the fitting data to find it.
      composition_check <- check_partner_dependence(simulations, dyad = coupleID,
        role = gender, data = prepared_data, plot = FALSE)
      dplyr::bind_rows(record_covariance_check(pooled_check, condition, "pooled"),
        record_covariance_check(composition_check, condition, "composition")) |>
        dplyr::mutate(condition = condition$condition, repetition)
    }, error = function(error) {
      fits$check_error[fits$model == "pooled"] <<- conditionMessage(error)
      NULL
    })
    if (!is.null(statistics)) {
      outcomes$pooled_any <- any(statistics$flagged[statistics$check_type == "pooled"])
      outcomes$composition_any <- any(statistics$flagged[statistics$check_type == "composition"])
      changed_statistics <- dplyr::filter(statistics, expected_direction != 0)
      if (nrow(changed_statistics)) {
        outcomes$expected_direction <- any(with(changed_statistics,
          (expected_direction > 0 & above) | (expected_direction < 0 & below)))
        outcomes$opposite_direction <- any(with(changed_statistics,
          (expected_direction > 0 & below) | (expected_direction < 0 & above)))
      }
      outcomes$composition_without_pooled <- outcomes$composition_any && !outcomes$pooled_any
    }
  }
  if (pooled_fit$status$usable && composition_fit$status$usable) {
    comparison <- tryCatch(compare_nested_models(pooled_fit$model, composition_fit$model),
      error = function(error) {
        fits$comparison_error[fits$model == "composition"] <<- conditionMessage(error)
        NULL
      })
    if (!is.null(comparison)) {
      outcomes$likelihood_ratio <- comparison[["Pr(>Chisq)"]][2] < 0.05
      outcomes$composition_without_lrt <- outcomes$composition_any & !outcomes$likelihood_ratio
    }
  }
  list(fits = fits, statistics = statistics, outcomes = outcomes)
}

add_rate_intervals <- function(counts) {
  # Wilson intervals describe uncertainty from the finite number of study datasets.
  counts |>
    dplyr::mutate(rate = flagged / checked,
      interval_centre = (rate + qnorm(0.975)^2 / (2 * checked)) / (1 + qnorm(0.975)^2 / checked),
      interval_half_width = qnorm(0.975) * sqrt(rate * (1 - rate) / checked +
        qnorm(0.975)^2 / (4 * checked^2)) / (1 + qnorm(0.975)^2 / checked),
      lower = pmax(0, interval_centre - interval_half_width), upper = pmin(1, interval_centre + interval_half_width)) |>
    dplyr::select(-interval_centre, -interval_half_width)
}

run_covariance_study <- function(repetitions = 1000L, reference_draws = 1000L, workers = 4L, mode = "run") {
  stopifnot(repetitions > 0L, reference_draws >= 20L, workers > 0L, mode %in% c("run", "summarise"))
  output_directory <- file.path(study_directory, "results/covariance-pooling",
    paste0(repetitions, "-datasets-", reference_draws, "-draws"))
  dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)
  conditions <- dplyr::mutate(study_conditions, repetitions, reference_draws)
  write.csv(conditions, file.path(output_directory, "conditions.csv"), row.names = FALSE)
  if (mode == "run") {
    writeLines(c(capture.output(sessionInfo()), paste("glmmTMB commit:", packageDescription("glmmTMB")$RemoteSha)),
      file.path(output_directory, "session-info.txt"))
    completed_conditions <- parallel::mclapply(seq_len(nrow(conditions)), function(condition_index) {
      condition <- conditions[condition_index, ]
      checkpoint_file <- file.path(output_directory, paste0("condition-", condition_index, ".rds"))
      completed <- if (file.exists(checkpoint_file)) readRDS(checkpoint_file) else list()
      if (length(completed) < repetitions) {
        for (repetition in seq.int(length(completed) + 1L, repetitions)) {
          completed[[repetition]] <- run_covariance_dataset(condition, repetition, reference_draws)
          if (repetition %% 10L == 0L || repetition == repetitions) {
            saveRDS(completed, paste0(checkpoint_file, ".tmp"))
            file.rename(paste0(checkpoint_file, ".tmp"), checkpoint_file)
          }
        }
      }
      message("Condition ", condition_index, "/", nrow(conditions), " complete")
      invisible(NULL)
    }, mc.cores = workers, mc.set.seed = FALSE, mc.preschedule = FALSE)
    stopifnot(!any(vapply(completed_conditions, inherits, logical(1), "try-error")))
  }
  completed <- unlist(lapply(list.files(output_directory,
    pattern = "^condition-[0-9]+[.]rds$", full.names = TRUE), readRDS), recursive = FALSE)
  fits <- dplyr::bind_rows(lapply(completed, `[[`, "fits"))
  statistics <- dplyr::bind_rows(lapply(completed, `[[`, "statistics"))
  outcomes <- dplyr::bind_rows(lapply(completed, `[[`, "outcomes"))
  stopifnot(nrow(outcomes) > 0L)
  summary <- outcomes |>
    tidyr::pivot_longer(-c(condition, repetition), names_to = "method", values_to = "flag") |>
    dplyr::group_by(condition, method) |>
    dplyr::summarise(checked = sum(!is.na(flag)), flagged = sum(flag, na.rm = TRUE), .groups = "drop") |>
    add_rate_intervals()
  statistic_summary <- statistics |>
    dplyr::group_by(condition, composition, statistic, true_value, pooled_value, expected_direction) |>
    dplyr::summarise(checked = dplyr::n(), flagged = sum(flagged), below = sum(below), above = sum(above),
      .groups = "drop") |>
    add_rate_intervals()
  fit_summary <- fits |>
    dplyr::group_by(condition, model) |>
    dplyr::summarise(attempted = dplyr::n(), usable = sum(usable), with_warnings = sum(warnings != ""),
      check_failures = sum(check_error != ""), comparison_failures = sum(comparison_error != ""), .groups = "drop")
  report_tables <- list(summary = summary, `stats-summary` = statistic_summary, fits = fit_summary)
  for (table_name in names(report_tables)) {
    write.csv(report_tables[[table_name]], file.path(output_directory, paste0(table_name, ".csv")), row.names = FALSE)
  }
  if (repetitions == 1000L && reference_draws == 1000L && nrow(outcomes) == nrow(conditions) * repetitions) {
    report_directory <- file.path(study_directory, "report-data/covariance-pooling")
    dir.create(report_directory, showWarnings = FALSE)
    file.copy(file.path(output_directory, c("conditions.csv", "summary.csv", "stats-summary.csv", "fits.csv")),
      report_directory, overwrite = TRUE)
    rmarkdown::render("vignettes/articles/covariance-pooling.Rmd",
      output_dir = study_directory, envir = new.env(), quiet = TRUE)
  }
  message("Saved results: ", output_directory)
  invisible(output_directory)
}

if (sys.nframe() == 0L) {
  arguments <- commandArgs(trailingOnly = TRUE)
  run_covariance_study(
    repetitions = if (length(arguments) >= 1L) as.integer(arguments[1]) else 1000L,
    reference_draws = if (length(arguments) >= 2L) as.integer(arguments[2]) else 1000L,
    workers = if (length(arguments) >= 3L) as.integer(arguments[3]) else 4L,
    mode = if (length(arguments) >= 4L) arguments[4] else "run"
  )
}
