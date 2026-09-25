# Run from the repository root. Arguments: datasets, reference draws, workers, run/summarise, families.
source("dev/diagnostic_checks/simulation-studies/generalized-covariance-pooling/helpers.R")

run_generalized_covariance_dataset <- function(condition, repetition, reference_draws) {
  dataset_seed <- 900000000L + 10000000L * match(condition$family, generalized_family_names) +
    10000L * condition$condition + repetition
  prepared_data <- generate_generalized_covariance_data(condition, condition$family, dataset_seed)
  pooled_fit <- fit_generalized_covariance_model(prepared_data, condition$family, "pooled")
  full_fit <- fit_generalized_covariance_model(prepared_data, condition$family, "composition")
  fits <- dplyr::bind_rows(pooled_fit$status, full_fit$status) |>
    dplyr::mutate(family = condition$family, condition = condition$condition, repetition,
      dataset_seed, check_error = "", check_warnings = "", comparison_error = "")
  statistics <- vector("list", 2L)
  outcomes <- tibble::tibble(family = condition$family, condition = condition$condition, repetition,
    pooled_any = NA, composition_any = NA, full_any = NA, likelihood_ratio = NA,
    composition_paired = NA, full_paired = NA, likelihood_ratio_paired = NA)
  for (model_index in 1:2) {
    fit <- list(pooled_fit, full_fit)[[model_index]]
    if (!fit$status$usable) next
    check_warnings <- character()
    statistics[model_index] <- list(tryCatch(withCallingHandlers({
      simulations <- simulate_dyad_responses(fit$model, nsim = reference_draws,
        seed = dataset_seed + 200000000L + model_index)
      # Roles are absent from the fitted formula, so use the original fitting data.
      composition_check <- check_partner_dependence(simulations, dyad = coupleID,
        role = gender, data = prepared_data, plot = FALSE)
      composition_statistics <- record_generalized_check(composition_check, "composition")
      if (model_index == 1L) {
        pooled_check <- check_partner_dependence(simulations, dyad = coupleID, role = NULL, plot = FALSE)
        dplyr::bind_rows(record_generalized_check(pooled_check, "pooled"), composition_statistics)
      } else composition_statistics
    }, warning = function(warning) {
      check_warnings <<- c(check_warnings, conditionMessage(warning))
      invokeRestart("muffleWarning")
    }), error = function(error) {
      fits$check_error[model_index] <<- conditionMessage(error)
      NULL
    }))
    fits$check_warnings[model_index] <- paste(unique(check_warnings), collapse = " | ")
    if (!is.null(statistics[[model_index]])) {
      model_statistics <- statistics[[model_index]]
      if (model_index == 1L) {
        outcomes$pooled_any <- any(model_statistics$flagged[model_statistics$check_type == "pooled"])
        outcomes$composition_any <- any(model_statistics$flagged[model_statistics$check_type == "composition"])
      } else outcomes$full_any <- any(model_statistics$flagged)
      statistics[[model_index]] <- dplyr::mutate(model_statistics,
        family = condition$family, condition = condition$condition, repetition, model = fit$status$model)
    }
  }
  if (pooled_fit$status$usable && full_fit$status$usable) {
    comparison <- tryCatch(compare_nested_models(pooled_fit$model, full_fit$model),
      error = function(error) {
        fits$comparison_error[2] <<- conditionMessage(error)
        NULL
      })
    if (!is.null(comparison)) outcomes$likelihood_ratio <- comparison[["Pr(>Chisq)"]][2] < 0.05
  }
  # Paired summaries show whether exclusions change the comparison.
  if (!anyNA(outcomes[c("composition_any", "full_any", "likelihood_ratio")])) {
    outcomes$composition_paired <- outcomes$composition_any
    outcomes$full_paired <- outcomes$full_any
    outcomes$likelihood_ratio_paired <- outcomes$likelihood_ratio
  }
  list(fits = fits, statistics = dplyr::bind_rows(statistics), outcomes = outcomes)
}

run_generalized_covariance_study <- function(repetitions = 500L, reference_draws = 1000L,
                                              workers = 10L, mode = "run", family_names = NULL) {
  stopifnot(repetitions > 0L, reference_draws >= 20L, workers > 0L, mode %in% c("run", "summarise"))
  screening <- read.csv(file.path(study_directory,
    "report-data/generalized-covariance-screening/summary.csv"))
  selected_families <- screening$family[screening$selected]
  if (!is.null(family_names)) selected_families <- intersect(selected_families, family_names)
  stopifnot(length(selected_families) > 0L)
  conditions <- tidyr::crossing(family = selected_families,
    dplyr::filter(generalized_conditions, n_dyads %in% c(40L, 100L, 400L))) |>
    dplyr::mutate(repetitions, reference_draws)
  output_directory <- file.path(study_directory, "results/generalized-covariance-pooling",
    paste0(repetitions, "-datasets-", reference_draws, "-draws"))
  dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)
  write.csv(conditions, file.path(output_directory, "conditions.csv"), row.names = FALSE)
  if (mode == "run") {
    writeLines(c(capture.output(sessionInfo()),
      paste("glmmTMB commit:", packageDescription("glmmTMB")$RemoteSha)),
      file.path(output_directory, "session-info.txt"))
    for (condition_index in seq_len(nrow(conditions))) {
      condition <- conditions[condition_index, ]
      checkpoint_file <- file.path(output_directory,
        paste0(condition$family, "-condition-", condition$condition, ".rds"))
      completed <- if (file.exists(checkpoint_file)) readRDS(checkpoint_file) else list()
      while (length(completed) < repetitions) {
        batch_repetitions <- seq.int(length(completed) + 1L,
          min(length(completed) + workers, repetitions))
        # Each dataset has its own seeds, so worker count does not change its results.
        batch_results <- parallel::mclapply(batch_repetitions, function(repetition) {
          run_generalized_covariance_dataset(condition, repetition, reference_draws)
        }, mc.cores = workers, mc.set.seed = FALSE, mc.preschedule = FALSE)
        if (any(vapply(batch_results, function(result) {
          is.null(result) || inherits(result, "try-error")
        }, logical(1)))) {
          stop("A dataset worker failed. The previous checkpoint is unchanged.")
        }
        # Only the parent writes checkpoints, with datasets kept in repetition order.
        completed <- c(completed, batch_results)
        saveRDS(completed, paste0(checkpoint_file, ".tmp"))
        stopifnot(file.rename(paste0(checkpoint_file, ".tmp"), checkpoint_file))
      }
      message(condition$family, ": ", condition$n_dyads, " dyads, ", condition$scenario, " complete")
    }
  }
  checkpoint_files <- file.path(output_directory,
    paste0(conditions$family, "-condition-", conditions$condition, ".rds"))
  completed <- unlist(lapply(checkpoint_files[file.exists(checkpoint_files)], readRDS), recursive = FALSE)
  fits <- dplyr::bind_rows(lapply(completed, `[[`, "fits"))
  statistics <- dplyr::bind_rows(lapply(completed, `[[`, "statistics"))
  outcomes <- dplyr::bind_rows(lapply(completed, `[[`, "outcomes"))
  stopifnot(nrow(outcomes) > 0L)
  summary <- outcomes |>
    tidyr::pivot_longer(-c(family, condition, repetition), names_to = "method", values_to = "flag") |>
    dplyr::group_by(family, condition, method) |>
    dplyr::summarise(checked = sum(!is.na(flag)), flagged = sum(flag, na.rm = TRUE), .groups = "drop") |>
    add_rate_intervals()
  fit_summary <- fits |>
    dplyr::group_by(family, condition, model) |>
    dplyr::summarise(attempted = dplyr::n(), usable = sum(usable),
      with_warnings = sum(warnings != ""), check_failures = sum(check_error != ""),
      check_warnings = sum(check_warnings != ""), comparison_failures = sum(comparison_error != ""),
      .groups = "drop")
  statistic_summary <- statistics |>
    dplyr::group_by(family, condition, model, check_type, composition, statistic) |>
    dplyr::summarise(checked = sum(!is.na(flagged)), flagged = sum(flagged, na.rm = TRUE),
      below = sum(below, na.rm = TRUE), above = sum(above, na.rm = TRUE),
      undefined_draws = sum(undefined_draws), .groups = "drop") |>
    add_rate_intervals()
  settings <- dplyr::bind_rows(lapply(selected_families, function(family_name) {
    margin <- make_family_margin(family_name)
    tibble::tibble(family = family_name, link = margin$family$link,
      added_intercept = margin$mean_intercept, response_settings = margin$settings)
  }))
  report_tables <- list(summary = summary, fits = fit_summary, `stats-summary` = statistic_summary,
    settings = settings,
    screening = screening, conditions = conditions)
  for (table_name in names(report_tables)) {
    write.csv(report_tables[[table_name]], file.path(output_directory, paste0(table_name, ".csv")), row.names = FALSE)
  }
  if (repetitions == 500L && reference_draws == 1000L &&
      setequal(selected_families, screening$family[screening$selected]) &&
      nrow(outcomes) == nrow(conditions) * repetitions) {
    report_directory <- file.path(study_directory, "report-data/generalized-covariance-pooling")
    dir.create(report_directory, recursive = TRUE, showWarnings = FALSE)
    file.copy(file.path(output_directory, paste0(names(report_tables), ".csv")), report_directory, overwrite = TRUE)
    rmarkdown::render("vignettes/articles/generalized-covariance-pooling.Rmd",
      output_file = "generalized-covariance-pooling.html", output_dir = study_directory,
      envir = new.env(), quiet = TRUE)
  }
  message("Saved results: ", output_directory)
  invisible(output_directory)
}

if (sys.nframe() == 0L) {
  arguments <- commandArgs(trailingOnly = TRUE)
  run_generalized_covariance_study(
    repetitions = if (length(arguments) >= 1L) as.integer(arguments[1]) else 500L,
    reference_draws = if (length(arguments) >= 2L) as.integer(arguments[2]) else 1000L,
    workers = if (length(arguments) >= 3L) as.integer(arguments[3]) else 10L,
    mode = if (length(arguments) >= 4L) arguments[4] else "run",
    family_names = if (length(arguments) >= 5L) strsplit(arguments[5], ",", fixed = TRUE)[[1]] else NULL
  )
}
