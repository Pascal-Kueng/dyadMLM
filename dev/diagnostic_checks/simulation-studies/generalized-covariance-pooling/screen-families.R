# Run from the repository root. Arguments: datasets, workers, optional family names.
source("dev/diagnostic_checks/simulation-studies/generalized-covariance-pooling/helpers.R")

structural_exclusions <- tibble::tibble(
  family = c("ordinal", "skewnormal"),
  reason = c(
    "Probit thresholds and full latent variances do not identify a unique scale.",
    "Residual and latent Gaussian variation cannot be separated with free skewness."
  )
)

screen_generalized_dataset <- function(study_condition, family_name, repetition) {
  dataset_seed <- 510000000L + 10000000L * match(family_name, generalized_family_names) +
    10000L * study_condition$condition + repetition
  prepared_data <- generate_generalized_covariance_data(study_condition, family_name, dataset_seed)
  fitted_models <- lapply(c("pooled", "composition"), function(model_name) {
    fit_generalized_covariance_model(prepared_data, family_name, model_name)
  })
  fits <- dplyr::bind_rows(lapply(fitted_models, `[[`, "status"))
  recovery <- NULL
  if (fitted_models[[2]]$status$usable) {
    # Only the full model has the generating covariance as its parameter target.
    estimates <- recover_latent_covariance(fitted_models[[2]]$model, "composition") |>
      tidyr::pivot_longer(-composition, names_to = "parameter", values_to = "estimate")
    targets <- true_latent_covariance(study_condition) |>
      tidyr::pivot_longer(-composition, names_to = "parameter", values_to = "true_value")
    recovery <- dplyr::left_join(estimates, targets, by = c("composition", "parameter"))
  }
  list(
    fits = dplyr::mutate(fits, family = family_name, condition = study_condition$condition,
      n_dyads = study_condition$n_dyads, scenario = study_condition$scenario, repetition, dataset_seed),
    recovery = if (!is.null(recovery)) dplyr::mutate(recovery, family = family_name,
      condition = study_condition$condition, n_dyads = study_condition$n_dyads,
      scenario = study_condition$scenario, repetition)
  )
}

run_generalized_screening <- function(repetitions = 50L, workers = 10L,
                                       family_names = generalized_family_names) {
  stopifnot(repetitions > 0L, workers > 0L, all(family_names %in% generalized_family_names))
  output_directory <- file.path(study_directory, "results/generalized-covariance-screening",
    paste0(repetitions, "-datasets"))
  dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)
  writeLines(c(capture.output(sessionInfo()),
    paste("glmmTMB commit:", packageDescription("glmmTMB")$RemoteSha)),
    file.path(output_directory, "session-info.txt"))
  screening_conditions <- generalized_conditions |>
    dplyr::filter(n_dyads %in% c(40L, 100L, 400L),
      scenario %in% c("null", "variance_large", "correlation_large"))
  screening_tasks <- tidyr::crossing(
    family = setdiff(family_names, structural_exclusions$family), screening_conditions)
  completed_tasks <- parallel::mclapply(seq_len(nrow(screening_tasks)), function(task_index) {
    condition <- screening_tasks[task_index, ]
    checkpoint_file <- file.path(output_directory,
      paste0(condition$family, "-condition-", condition$condition, ".rds"))
    completed <- if (file.exists(checkpoint_file)) readRDS(checkpoint_file) else list()
    if (length(completed) < repetitions) {
      for (repetition in seq.int(length(completed) + 1L, repetitions)) {
        completed[[repetition]] <- screen_generalized_dataset(condition, condition$family, repetition)
        if (repetition %% 5L == 0L || repetition == repetitions) {
          saveRDS(completed, paste0(checkpoint_file, ".tmp"))
          stopifnot(file.rename(paste0(checkpoint_file, ".tmp"), checkpoint_file))
        }
      }
    }
    message(condition$family, ": ", condition$n_dyads, " dyads, ", condition$scenario, " complete")
    invisible(NULL)
  }, mc.cores = workers, mc.set.seed = FALSE, mc.preschedule = FALSE)
  stopifnot(!any(vapply(completed_tasks, inherits, logical(1), "try-error")))

  completed <- unlist(lapply(list.files(output_directory,
    pattern = "-condition-[0-9]+[.]rds$", full.names = TRUE), readRDS), recursive = FALSE)
  # Keep empty tables usable when a requested family has no successful fits.
  fits <- dplyr::bind_rows(tibble::tibble(family = character(), condition = integer(),
    n_dyads = integer(), scenario = character(), model = character(), usable = logical(),
    warnings = character(), elapsed_seconds = numeric()), lapply(completed, `[[`, "fits"))
  recovery <- dplyr::bind_rows(tibble::tibble(family = character(), condition = integer(),
    n_dyads = integer(), scenario = character(), composition = character(), parameter = character(),
    estimate = numeric(), true_value = numeric()), lapply(completed, `[[`, "recovery"))
  fit_summary <- fits |>
    dplyr::group_by(family, condition, n_dyads, scenario, model) |>
    dplyr::summarise(attempted = dplyr::n(), usable = sum(usable),
      usable_rate = usable / attempted, with_warnings = sum(warnings != ""),
      median_elapsed_seconds = median(elapsed_seconds), .groups = "drop")
  recovery_summary <- recovery |>
    dplyr::mutate(error = estimate - true_value,
      relative_error = ifelse(parameter %in% c("first_variance", "second_variance"),
        error / true_value, NA_real_)) |>
    dplyr::group_by(family, condition, n_dyads, scenario, composition, parameter, true_value) |>
    dplyr::summarise(usable = dplyr::n(), median_estimate = median(estimate),
      median_bias = median(error), median_absolute_error = median(abs(error)),
      median_relative_bias = median(relative_error),
      median_absolute_relative_error = median(abs(relative_error)), .groups = "drop")

  # Select families before the main study. These are practical screening thresholds.
  completion <- fit_summary |>
    dplyr::group_by(family) |>
    dplyr::summarise(complete = dplyr::n() == 2L * nrow(screening_conditions) &&
      all(attempted == repetitions), .groups = "drop")
  fitting_metrics <- fit_summary |>
    dplyr::filter(n_dyads == 400L) |>
    dplyr::group_by(family) |>
    dplyr::summarise(minimum_usable_rate = min(c(1, usable_rate)), .groups = "drop")
  variance_metrics <- recovery_summary |>
    dplyr::filter(n_dyads == 400L, parameter %in% c("first_variance", "second_variance")) |>
    dplyr::group_by(family) |>
    dplyr::summarise(maximum_absolute_relative_variance_bias = max(c(0, abs(median_relative_bias))),
      maximum_median_absolute_relative_variance_error = max(c(0, median_absolute_relative_error)),
      .groups = "drop")
  correlation_metrics <- recovery_summary |>
    dplyr::filter(n_dyads == 400L, parameter == "correlation") |>
    dplyr::group_by(family) |>
    dplyr::summarise(maximum_absolute_correlation_bias = max(c(0, abs(median_bias))), .groups = "drop")
  selection <- tibble::tibble(family = generalized_family_names) |>
    dplyr::left_join(structural_exclusions, by = "family") |>
    dplyr::left_join(completion, by = "family") |>
    dplyr::left_join(fitting_metrics, by = "family") |>
    dplyr::left_join(variance_metrics, by = "family") |>
    dplyr::left_join(correlation_metrics, by = "family") |>
    dplyr::mutate(reason = dplyr::case_when(
      !is.na(reason) ~ reason,
      is.na(complete) | !complete ~ "Screen not complete.",
      minimum_usable_rate < 0.90 ~ "Fewer than 90% usable fits in at least one setting at 400 dyads.",
      is.na(maximum_absolute_relative_variance_bias) | is.na(maximum_absolute_correlation_bias) ~
        "Incomplete full-model recovery estimates.",
      maximum_absolute_relative_variance_bias > 0.25 ~ "Median latent variance bias exceeds 25%.",
      maximum_absolute_correlation_bias > 0.15 ~ "Median latent correlation bias exceeds 0.15.",
      maximum_median_absolute_relative_variance_error > 0.50 ~ "Median absolute latent variance error exceeds 50%.",
      TRUE ~ "Passed the prespecified screening criteria."
    ), selected = reason == "Passed the prespecified screening criteria.") |>
    dplyr::select(family, selected, reason, dplyr::everything())
  tables <- list(summary = selection, recovery = recovery_summary, fits = fit_summary)
  for (table_name in names(tables)) {
    write.csv(tables[[table_name]], file.path(output_directory, paste0(table_name, ".csv")), row.names = FALSE)
  }
  if (repetitions == 50L) {
    report_directory <- file.path(study_directory, "report-data/generalized-covariance-screening")
    dir.create(report_directory, recursive = TRUE, showWarnings = FALSE)
    file.copy(file.path(output_directory, paste0(names(tables), ".csv")), report_directory, overwrite = TRUE)
  }
  message("Saved screening results: ", output_directory)
  invisible(selection)
}

if (sys.nframe() == 0L) {
  arguments <- commandArgs(trailingOnly = TRUE)
  run_generalized_screening(
    repetitions = if (length(arguments) >= 1L) as.integer(arguments[1]) else 50L,
    workers = if (length(arguments) >= 2L) as.integer(arguments[2]) else 10L,
    family_names = if (length(arguments) >= 3L) unlist(strsplit(arguments[-c(1L, 2L)], ",")) else
      generalized_family_names
  )
}
