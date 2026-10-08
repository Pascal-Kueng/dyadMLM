# Compare three ways to draw the PIT quartile lines on the same PIT residuals:
# "current" (bins on the predictor's scale), "ranked_bins" (the same bins on a
# rank axis) and "kernel" (kernel-weighted quartiles on a rank axis), chosen with
# the option dyadMLM.residual_smoother. Run from the repository root. Arguments
# match confirmation.R: datasets, reference draws, workers, run/summarise, and
# optional comma-separated condition numbers.
source("dev/diagnostic_checks/simulation-studies/distribution-checks/confirmation.R")

# Slow 400-dyad conditions come first, so they start first.
ranked_conditions <- function() {
  tibble::tribble(
    ~family, ~scenario, ~n_dyads,
    "gaussian", "correct", 400L,
    "nbinom2", "correct", 400L,
    "gaussian", "omitted_partner", 400L,
    "nbinom2", "dispersion_small", 400L,
    "gaussian", "correct", 100L,
    "nbinom2", "correct", 100L,
    "ordinal", "correct", 100L,
    "gaussian", "omitted_partner", 100L,
    "gaussian", "heteroscedastic", 100L,
    "gaussian", "variance_large", 100L
  ) |>
    dplyr::inner_join(dplyr::select(confirmation_conditions(), -condition),
                      by = c("family", "scenario", "n_dyads")) |>
    # Patterns near the end of the actor predictor's range, fitted without them.
    dplyr::bind_rows(tidyr::expand_grid(scenario = c("curvature", "end_shift"), n_dyads = c(400L, 100L)) |>
      dplyr::mutate(family = "gaussian", fit_family = "gaussian", sd_ratio = 1, nb_size = 3,
        scenario_label = ifelse(scenario == "curvature", "Omitted curvature: 0.3 (actor^2 - 1)",
                                "Shift of 1.2 in the top 10% of actor"),
        role_mean = 0, zero_probability = 0, n_times = 1L, dyad_sd = .6)) |>
    dplyr::arrange(dplyr::desc(n_dyads)) |>
    dplyr::mutate(condition = dplyr::row_number(), .before = 1)
}

generate_ranked_response <- function(data, condition) {
  if (!condition$scenario %in% c("curvature", "end_shift"))
    return(generate_confirmation_response(data, condition))
  actor <- data$actor_predictor
  generate_confirmation_response(data, dplyr::mutate(condition, scenario = "correct")) +
    if (condition$scenario == "curvature") .3 * (actor^2 - 1) else 1.2 * (actor > stats::qnorm(.9))
}

smoothers <- c("current", "ranked_bins", "kernel")
shown_panels <- c("qq", "mean_distance", "predicted_quantiles",
                  "response_sd", "maximum_deviation", "zeros")
predictor_panels <- c("actor_quantiles", "partner_quantiles")

record_ranked_residuals <- function(result) {
  composition <- result$compositions[[1]]
  dplyr::bind_rows(lapply(names(composition$rows), function(role) {
    statistics <- composition$statistics[[role]]
    dplyr::bind_rows(distribution_curve(statistics$qq),
      distribution_scalar(statistics$mean_distance),
      lapply(composition$patterns, function(pattern) distribution_curve(pattern[[role]]$quantiles))) |>
      dplyr::mutate(statistic = c("qq", "mean_distance", "predicted_quantiles", predictor_panels),
                    role, check = "residual")
  }))
}

# Pooled and by role, with both predictor pages. The fixed seed gives every
# smoother the same PIT; the outcome check does not depend on the smoother.
evaluate_ranked_checks <- function(simulations, data, pit_seed) {
  seconds <- stats::setNames(numeric(4), c(smoothers, "outcome"))
  rows <- dplyr::bind_rows(lapply(c("pooled", "roles"), function(view) {
    arguments <- list(simulations, dyad = "dyad", role = if (view == "roles") "role",
                      data = data, plot = FALSE)
    residuals <- dplyr::bind_rows(lapply(smoothers, function(smoother) {
      seconds[smoother] <<- seconds[smoother] + system.time(result <- withr::with_options(
        list(dyadMLM.residual_smoother = smoother), do.call(check_dyad_residuals, c(arguments,
          list(predictors = c("actor_predictor", "partner_predictor"), seed = pit_seed)))),
        gcFirst = FALSE)[["elapsed"]]
      dplyr::mutate(record_ranked_residuals(result), smoother)
    }))
    seconds["outcome"] <<- seconds["outcome"] + system.time(
      outcomes <- do.call(check_dyad_outcomes, arguments), gcFirst = FALSE)[["elapsed"]]
    dplyr::bind_rows(residuals, record_confirmation_outcomes(outcomes)) |>
      dplyr::mutate(view)
  }))
  list(rows = rows, seconds = seconds)
}

run_ranked_dataset <- function(condition, repetition, reference_draws) {
  # Seeds, including offsets, lie above those of the earlier runs.
  dataset_seed <- 1110000000L + 100000L * condition$condition + repetition
  data <- generate_distribution_design(condition, dataset_seed)
  data$outcome <- generate_ranked_response(data, condition)
  fits <- data.frame(condition = condition$condition, repetition, dataset_seed,
    status = "fit_error", warnings = "", error = "", fit_seconds = 0, simulation_seconds = 0)
  statistics <- NULL
  warnings <- character()
  tryCatch(withCallingHandlers({
    formula <- if (condition$scenario == "omitted_partner") outcome ~ actor_predictor + (1 | dyad) else
      outcome ~ actor_predictor + partner_predictor + (1 | dyad)
    family <- switch(condition$fit_family, gaussian = gaussian(), poisson = poisson(),
      nbinom2 = glmmTMB::nbinom2(), ordinal = glmmTMB::ordinal())
    fits$fit_seconds <- system.time(model <- glmmTMB::glmmTMB(
      formula, data = data, family = family), gcFirst = FALSE)[["elapsed"]]
    if (model$fit$convergence != 0L || !isTRUE(model$sdr$pdHess)) {
      fits$status <- "fit_problem"
      stop("Convergence or Hessian problem.")
    }
    fits$status <- "check_error"
    fits$simulation_seconds <- system.time(simulations <- simulate_dyad_responses(
      model, nsim = reference_draws, seed = dataset_seed + 10000000L), gcFirst = FALSE)[["elapsed"]]
    checked <- evaluate_ranked_checks(simulations, data, dataset_seed + 30000000L)
    fits[paste0(names(checked$seconds), "_seconds")] <- as.list(checked$seconds)
    statistics <- dplyr::mutate(checked$rows, condition = condition$condition, repetition, .before = 1)
    fits$status <- "success"
  }, warning = function(warning) {
    warnings <<- c(warnings, conditionMessage(warning))
    invokeRestart("muffleWarning")
  }), error = function(error) fits$error <<- conditionMessage(error))
  fits$warnings <- paste(unique(warnings), collapse = " | ")
  list(fits = fits, statistics = statistics)
}

# Flag rates with 95% Wilson intervals, per condition and the given groups.
ranked_rates <- function(data, conditions, ...) {
  z <- stats::qnorm(.975)
  data |>
    dplyr::group_by(condition, ...) |>
    dplyr::summarise(checked = sum(!is.na(flagged)), flagged = sum(flagged, na.rm = TRUE),
                     .groups = "drop") |>
    dplyr::mutate(rate = flagged / checked,
      rate_lower = (flagged + z^2 / 2 - z * sqrt(flagged * (checked - flagged) / checked + z^2 / 4)) /
        (checked + z^2),
      rate_upper = (flagged + z^2 / 2 + z * sqrt(flagged * (checked - flagged) / checked + z^2 / 4)) /
        (checked + z^2)) |>
    dplyr::left_join(dplyr::select(conditions, condition, scenario_label, fit_family, n_dyads),
                     by = "condition") |>
    dplyr::relocate(scenario_label, fit_family, n_dyads, .after = condition)
}

summarise_ranked_axis_check <- function(conditions, fits, statistics) {
  # Each residual panel: pooled, in each role, and in either role.
  residual <- dplyr::filter(statistics, check == "residual")
  either <- residual |>
    dplyr::filter(view == "roles") |>
    dplyr::group_by(condition, repetition, smoother, view, statistic) |>
    dplyr::summarise(flagged = distribution_any(flagged), .groups = "drop") |>
    dplyr::mutate(role = "Either")
  panels <- ranked_rates(dplyr::bind_rows(residual, either), conditions,
                         smoother, view, role, statistic)
  # Any flag among the shown residual and outcome panels, without and with
  # predictor pages, across roles; each smoother with the same outcome check.
  outcomes <- dplyr::filter(statistics, check == "outcome")
  shown <- dplyr::bind_rows(residual, lapply(smoothers, function(name)
    dplyr::mutate(outcomes, smoother = name)))
  unions <- dplyr::bind_rows(lapply(c(FALSE, TRUE), function(pages) shown |>
    dplyr::filter(statistic %in% c(shown_panels, if (pages) predictor_panels)) |>
    dplyr::group_by(condition, repetition, smoother, view) |>
    dplyr::summarise(flagged = distribution_any(flagged), .groups = "drop") |>
    dplyr::mutate(pages = pages))) |>
    ranked_rates(conditions, smoother, view, pages)
  # Mean seconds per dataset, both views together.
  timing <- fits |>
    dplyr::group_by(condition) |>
    dplyr::summarise(attempted = dplyr::n(), succeeded = sum(status == "success"),
      dplyr::across(dplyr::ends_with("_seconds"), function(x) round(mean(x, na.rm = TRUE), 2)),
      .groups = "drop")
  timing <- dplyr::select(conditions, condition, scenario_label, fit_family, n_dyads) |>
    dplyr::right_join(timing, by = "condition")
  list(panels = panels, unions = unions, timing = timing)
}

run_ranked_axis_check <- function(repetitions = 200L, reference_draws = 1000L, workers = 8L,
                                  mode = "run", selected = NULL) {
  integers <- c(repetitions, reference_draws, workers, selected)
  stopifnot(all(is.finite(integers)), all(integers == floor(integers)),
    repetitions > 0L, repetitions < 100000L, reference_draws >= 200L,
    workers > 0L, workers <= 10L, mode %in% c("run", "summarise"))
  if (.Platform$OS.type == "windows") workers <- 1L
  conditions <- ranked_conditions() |>
    dplyr::mutate(repetitions = as.integer(repetitions), reference_draws = as.integer(reference_draws))
  if (is.null(selected)) selected <- conditions$condition
  stopifnot(length(selected) > 0L, all(selected %in% conditions$condition), !anyDuplicated(selected))
  output_directory <- file.path(study_directory, "results/distribution-checks",
    paste0("ranked-axis-", repetitions, "-datasets-", reference_draws, "-draws"))
  dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)
  if (mode == "run") {
    # As in confirmation.R: a resumed run must use the same settings and code.
    source_files <- c(sort(list.files("R", "[.]R$", full.names = TRUE)),
      file.path(study_directory, "distribution-checks",
                c("helpers.R", "confirmation.R", "ranked-axis-check.R")))
    fingerprint <- list(conditions = conditions, sources = vapply(source_files, function(file)
      rlang::hash(grep("^#'", readLines(file), value = TRUE, invert = TRUE)), character(1)),
      R = as.character(getRversion()), glmmTMB = as.character(utils::packageVersion("glmmTMB")),
      TMB = as.character(utils::packageVersion("TMB")))
    fingerprint_file <- file.path(output_directory, "settings.rds")
    if (file.exists(fingerprint_file)) {
      if (!identical(readRDS(fingerprint_file), fingerprint))
        stop("Saved settings or source code differ. Archive this run before starting a new one.")
    } else {
      saveRDS(fingerprint, fingerprint_file)
      writeLines(capture.output(sessionInfo()), file.path(output_directory, "session-info.txt"))
    }
    finished <- parallel::mclapply(selected, function(condition_index) {
      condition <- conditions[conditions$condition == condition_index, ]
      checkpoint <- file.path(output_directory, paste0("condition-", condition_index, ".rds"))
      completed <- if (file.exists(checkpoint)) readRDS(checkpoint) else list()
      if (length(completed) < repetitions) {
        for (repetition in seq.int(length(completed) + 1L, repetitions)) {
          completed[[repetition]] <- run_ranked_dataset(condition, repetition, reference_draws)
          if (repetition %% 5L == 0L || repetition == repetitions) {
            saveRDS(completed, paste0(checkpoint, ".tmp"))
            stopifnot(file.rename(paste0(checkpoint, ".tmp"), checkpoint))
            message("Condition ", condition_index, ": ", repetition, "/", repetitions)
          }
        }
      }
      invisible(NULL)
    }, mc.cores = workers, mc.set.seed = FALSE, mc.preschedule = FALSE)
    stopifnot(!any(vapply(finished, inherits, logical(1), "try-error")))
  }
  checkpoints <- list.files(output_directory, "^condition-[0-9]+[.]rds$", full.names = TRUE)
  if (!length(checkpoints)) stop("No checkpoints found; run at least one condition first.")
  completed <- unlist(lapply(checkpoints, readRDS), recursive = FALSE)
  fits <- dplyr::bind_rows(lapply(completed, `[[`, "fits"))
  summaries <- summarise_ranked_axis_check(conditions[conditions$condition %in% fits$condition, ],
    fits, dplyr::bind_rows(lapply(completed, `[[`, "statistics")))
  for (name in names(summaries))
    write.csv(summaries[[name]], file.path(output_directory, paste0(name, ".csv")), row.names = FALSE)
  withr::with_options(list(width = 120), print(as.data.frame(tidyr::pivot_wider(
    summaries$unions, id_cols = c(condition, scenario_label, n_dyads, view, pages),
    names_from = smoother, values_from = rate))[c("condition", "scenario_label", "n_dyads",
    "view", "pages", smoothers)], digits = 2))
  complete <- all(table(factor(fits$condition, conditions$condition)) == repetitions)
  message(if (complete) "Complete" else "Partial", " results saved in ", output_directory)
  invisible(output_directory)
}

if (sys.nframe() == 0L) {
  arguments <- commandArgs(trailingOnly = TRUE)
  run_ranked_axis_check(
    repetitions = if (length(arguments) >= 1L) as.numeric(arguments[1]) else 200L,
    reference_draws = if (length(arguments) >= 2L) as.numeric(arguments[2]) else 1000L,
    workers = if (length(arguments) >= 3L) as.numeric(arguments[3]) else 8L,
    mode = if (length(arguments) >= 4L) arguments[4] else "run",
    selected = if (length(arguments) >= 5L)
      as.numeric(strsplit(arguments[5], ",", fixed = TRUE)[[1]]) else NULL)
}
