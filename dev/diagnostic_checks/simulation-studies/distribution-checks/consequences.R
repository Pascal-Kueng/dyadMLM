# Are mismatches that distort estimates or SEs detected? Run from the repository
# root. Arguments match run.R. Main conditions are refitted from their seeds to
# record the actor and partner estimates, SEs, and 95% Wald coverage; their flags
# are in the main study's summary. Severe conditions (101 onwards) also run the
# default checks in either role, with a residual page for each predictor.
pkgload::load_all(quiet = TRUE)
study_directory <- "dev/diagnostic_checks/simulation-studies"
source(file.path(study_directory, "distribution-checks/helpers.R"))
source(file.path(study_directory, "distribution-checks/summarise.R"))

consequence_conditions <- function() {
  severe <- tibble::tribble(
    ~family, ~scenario, ~scenario_label, ~nb_size, ~fit_family,
    "gaussian", "correct", "Correct model", 3, "gaussian",
    "gaussian", "omitted_partner", "Omitted partner effect", 3, "gaussian",
    "gaussian", "heteroscedastic", "Residual SD rises with actor predictor", 3, "gaussian",
    "nbinom2", "dispersion_severe", "NB2 size 1 fitted as Poisson", 1, "poisson"
  ) |>
    tidyr::expand_grid(n_dyads = c(100L, 400L)) |>
    dplyr::mutate(role_mean = 0, sd_ratio = 1, zero_probability = 0, n_times = 1L,
                  dyad_sd = 1.2, severe = TRUE, condition = 100L + dplyr::row_number(), .before = 1)
  dplyr::bind_rows(dplyr::mutate(distribution_conditions(), severe = FALSE), severe)
}

generate_consequence_response <- function(data, condition) {
  if (condition$scenario != "heteroscedastic") return(generate_distribution_response(data, condition))
  # Residual SD exp(actor - 1) gives average variance 1 for standard-normal predictors.
  distribution_linear_predictor(data, condition) +
    rnorm(condition$n_dyads, sd = condition$dyad_sd)[data$dyad] +
    rnorm(nrow(data), sd = exp(data$actor_predictor - 1))
}

# The same models as run_distribution_dataset(), apart from the omitted partner effect.
consequence_formula <- function(condition) {
  if (condition$scenario == "omitted_partner") return(outcome ~ actor_predictor + (1 | dyad))
  if (condition$n_times == 1L) outcome ~ actor_predictor + partner_predictor + (1 | dyad) else
    outcome ~ actor_predictor + partner_predictor + (1 | dyad) + ar1(time + 0 | member)
}

record_inference <- function(model) {
  truth <- c(actor_predictor = .5, partner_predictor = .3)
  estimates <- glmmTMB::fixef(model)$cond
  terms <- intersect(names(truth), names(estimates))
  data.frame(term = terms, truth = truth[terms], estimate = estimates[terms],
             se = sqrt(diag(stats::vcov(model)$cond))[terms], row.names = NULL) |>
    dplyr::mutate(covered = abs(estimate - truth) <= stats::qnorm(.975) * se)
}

# The main study's residual rows plus the quartile and distance envelopes of each predictor page.
record_consequence_residuals <- function(result) {
  composition <- result$compositions[[1]]
  pages <- dplyr::bind_rows(lapply(seq_along(result$predictors), function(page) {
    dplyr::bind_rows(lapply(names(composition$rows), function(role) {
      pattern <- composition$patterns[[page + 1L]][[role]]
      dplyr::bind_rows(distribution_curve(pattern$quantiles), distribution_curve(pattern$distance)) |>
        dplyr::mutate(statistic = paste0(result$predictors[page], c("_quantiles", "_distance")), role)
    }))
  }))
  dplyr::bind_rows(record_distribution_residuals(result), dplyr::mutate(pages, check = "residual"))
}

# The main study's default checks in either role; the same PIT seed gives identical flags.
evaluate_consequence_checks <- function(simulations, data, pit_seed) {
  residuals <- check_dyad_residuals(simulations, dyad = "dyad", role = "role",
    predictors = c("actor_predictor", "partner_predictor"), seed = pit_seed, data = data, plot = FALSE)
  outcomes <- check_dyad_outcomes(simulations, dyad = "dyad", role = "role", data = data, plot = FALSE)
  dplyr::bind_rows(
    dplyr::mutate(record_consequence_residuals(residuals), reference = "fitted-centred"),
    dplyr::mutate(record_distribution_outcomes(outcomes), reference = "fitted")) |>
    dplyr::mutate(view = "roles") |>
    add_distribution_unions()
}

run_consequence_dataset <- function(condition, repetition, reference_draws) {
  # Main conditions keep their seeds, so refits reproduce the main study's fits.
  # Severe seeds, including offsets, lie above all main-study seeds.
  base <- if (condition$severe) 810000000L else 710000000L
  dataset_seed <- base + 100000L * condition$condition + repetition
  data <- generate_distribution_design(condition, dataset_seed)
  data$outcome <- generate_consequence_response(data, condition)
  fits <- data.frame(condition = condition$condition, repetition, reference = "fitted",
    dataset_seed, usable = FALSE, status = "fit_error", convergence = NA_integer_,
    positive_hessian = NA, dyad_sd = NA_real_, dispersion = NA_real_, warnings = "",
    error = "", fit_seconds = 0, check_seconds = 0)
  inference <- statistics <- NULL
  warnings <- character()
  tryCatch(withCallingHandlers({
    family <- switch(condition$fit_family,
      gaussian = gaussian(), poisson = poisson(), nbinom2 = glmmTMB::nbinom2())
    # A garbage collection before each short fit would triple the refit time.
    fits$fit_seconds <- system.time(model <- glmmTMB::glmmTMB(
      consequence_formula(condition), data = data, family = family), gcFirst = FALSE)[["elapsed"]]
    fits$convergence <- model$fit$convergence
    fits$positive_hessian <- isTRUE(model$sdr$pdHess)
    fits$dyad_sd <- attr(glmmTMB::VarCorr(model)$cond$dyad, "stddev")[[1]]
    fits$dispersion <- stats::sigma(model)
    if (fits$convergence != 0L || !fits$positive_hessian) {
      fits$status <- "fit_problem"
      stop("Convergence or Hessian problem.")
    }
    inference <- record_inference(model)
    if (condition$severe) {
      fits$status <- "check_error"
      simulations <- simulate_dyad_responses(model, nsim = reference_draws,
                                             seed = dataset_seed + 10000000L)
      fits$check_seconds <- system.time(statistics <- evaluate_consequence_checks(
        simulations, data, dataset_seed + 30000000L))[["elapsed"]]
    }
    fits$usable <- TRUE
    fits$status <- "success"
  }, warning = function(warning) {
    warnings <<- c(warnings, conditionMessage(warning))
    invokeRestart("muffleWarning")
  }), error = function(error) {
    fits$error <<- conditionMessage(error)
    if (condition$severe) statistics <<- distribution_placeholders("fitted")
  })
  fits$warnings <- paste(unique(warnings), collapse = " | ")
  label <- function(rows) if (!is.null(rows))
    dplyr::mutate(rows, condition = condition$condition, repetition, .before = 1)
  list(fits = fits, inference = label(inference), statistics = label(statistics))
}

summarise_consequences <- function(conditions, output_directory) {
  checkpoints <- list.files(output_directory, "^condition-[0-9]+[.]rds$", full.names = TRUE)
  if (!length(checkpoints)) stop("No checkpoints found; run at least one condition first.")
  completed <- unlist(lapply(checkpoints, readRDS), recursive = FALSE)
  collect <- function(part) dplyr::bind_rows(lapply(completed, `[[`, part))
  fits <- collect("fits")
  tables <- list(inference = collect("inference") |>
    dplyr::group_by(condition, term) |>
    dplyr::summarise(estimated = dplyr::n(), bias = mean(estimate - truth),
      bias_mcse = stats::sd(estimate) / sqrt(estimated), empirical_sd = stats::sd(estimate),
      mean_se = mean(se), se_ratio = mean_se / empirical_sd, coverage = mean(covered),
      coverage_mcse = sqrt(coverage * (1 - coverage) / estimated), .groups = "drop") |>
    dplyr::left_join(dplyr::count(fits, condition, name = "attempted"), by = "condition") |>
    dplyr::left_join(conditions, by = "condition") |>
    dplyr::relocate(dplyr::all_of(names(conditions)), attempted))
  severe <- conditions[conditions$severe & conditions$condition %in% fits$condition, ]
  if (nrow(severe)) tables$`severe-summary` <- summarise_distribution_study(severe,
    fits[fits$condition %in% severe$condition, ], collect("statistics"))$summary
  for (name in names(tables))
    write.csv(tables[[name]], file.path(output_directory, paste0(name, ".csv")), row.names = FALSE)
  complete <- all(table(factor(fits$condition, conditions$condition)) == conditions$repetitions)
  list(complete = complete, files = paste0(names(tables), ".csv"))
}

run_consequences <- function(repetitions = 500L, reference_draws = 1000L, workers = 6L,
                             mode = "run", selected = NULL) {
  integers <- c(repetitions, reference_draws, workers, selected)
  stopifnot(all(is.finite(integers)), all(integers == floor(integers)),
    repetitions > 0L, repetitions < 100000L, reference_draws >= 200L,
    workers > 0L, workers <= 10L, mode %in% c("run", "summarise"))
  if (.Platform$OS.type == "windows") workers <- 1L
  conditions <- consequence_conditions() |>
    dplyr::mutate(repetitions = as.integer(repetitions), reference_draws = as.integer(reference_draws))
  if (is.null(selected)) selected <- conditions$condition
  stopifnot(length(selected) > 0L, all(selected %in% conditions$condition), !anyDuplicated(selected))
  output_directory <- file.path(study_directory, "results/distribution-checks-consequences",
    paste0(repetitions, "-datasets-", reference_draws, "-draws"))
  dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)
  if (mode == "run") {
    # Prevent a resumed run from silently combining different generators or package code.
    fingerprint <- list(conditions = conditions, sources = tools::md5sum(c(
      sort(list.files("R", "[.]R$", full.names = TRUE)),
      file.path(study_directory, "distribution-checks", c("helpers.R", "consequences.R")))),
      R = as.character(getRversion()), glmmTMB = as.character(utils::packageVersion("glmmTMB")),
      TMB = as.character(utils::packageVersion("TMB")))
    fingerprint_file <- file.path(output_directory, "settings.rds")
    if (file.exists(fingerprint_file) && !identical(readRDS(fingerprint_file), fingerprint))
      stop("Saved settings or source code differ. Archive this run before starting a new one.")
    saveRDS(fingerprint, fingerprint_file)
    finished <- parallel::mclapply(selected, function(condition_index) {
      condition <- conditions[conditions$condition == condition_index, ]
      checkpoint <- file.path(output_directory, paste0("condition-", condition_index, ".rds"))
      completed <- if (file.exists(checkpoint)) readRDS(checkpoint) else list()
      if (length(completed) < repetitions) {
        for (repetition in seq.int(length(completed) + 1L, repetitions)) {
          completed[[repetition]] <- run_consequence_dataset(condition, repetition, reference_draws)
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
  summary <- summarise_consequences(conditions, output_directory)
  if (summary$complete && repetitions == 500L && reference_draws == 1000L) {
    report_directory <- file.path(study_directory, "report-data/distribution-checks")
    dir.create(report_directory, recursive = TRUE, showWarnings = FALSE)
    stopifnot(all(file.copy(file.path(output_directory, summary$files), report_directory,
                            overwrite = TRUE)))
  }
  message(if (summary$complete) "Complete" else "Partial", " results saved in ", output_directory)
  invisible(output_directory)
}

if (sys.nframe() == 0L) {
  arguments <- commandArgs(trailingOnly = TRUE)
  run_consequences(
    repetitions = if (length(arguments) >= 1L) as.numeric(arguments[1]) else 500L,
    reference_draws = if (length(arguments) >= 2L) as.numeric(arguments[2]) else 1000L,
    workers = if (length(arguments) >= 3L) as.numeric(arguments[3]) else 6L,
    mode = if (length(arguments) >= 4L) arguments[4] else "run",
    selected = if (length(arguments) >= 5L)
      as.numeric(strsplit(arguments[5], ",", fixed = TRUE)[[1]]) else NULL)
}
