# Confirm the flag rates of the package's reduced panel set on fresh seeds. Run
# from the repository root. Arguments match run.R. The design is frozen in the
# README ("Confirmation run").
pkgload::load_all(quiet = TRUE)
study_directory <- "dev/diagnostic_checks/simulation-studies"
source(file.path(study_directory, "distribution-checks/helpers.R"))
source(file.path(study_directory, "distribution-checks/summarise.R"))

confirmation_conditions <- function() {
  tibble::tribble(
    ~family, ~scenario, ~scenario_label, ~sd_ratio, ~nb_size, ~fit_family,
    "gaussian", "correct", "Correct model", 1, 3, "gaussian",
    "gaussian", "variance_large", "Role SD ratio: 1.50", 1.5, 3, "gaussian",
    "gaussian", "heteroscedastic", "Residual SD rises with actor predictor", 1, 3, "gaussian",
    "gaussian", "omitted_partner", "Omitted partner effect", 1, 3, "gaussian",
    "nbinom2", "correct", "Correct model", 1, 3, "nbinom2",
    "nbinom2", "dispersion_small", "NB2 size 10 fitted as Poisson", 1, 10, "poisson",
    "ordinal", "correct", "Correct model", 1, 3, "ordinal"
  ) |>
    tidyr::expand_grid(n_dyads = c(100L, 400L)) |>
    dplyr::mutate(role_mean = 0, zero_probability = 0, n_times = 1L, dyad_sd = .6,
                  condition = dplyr::row_number(), .before = 1)
}

generate_confirmation_response <- function(data, condition) {
  heteroscedastic <- condition$scenario == "heteroscedastic"
  if (!heteroscedastic && condition$family != "ordinal")
    return(generate_distribution_response(data, condition))
  location <- .5 * data$actor_predictor + .3 * data$partner_predictor +
    rnorm(condition$n_dyads, sd = condition$dyad_sd)[data$dyad]
  # Residual SD exp(actor - 1) gives average variance 1 for standard-normal predictors.
  if (heteroscedastic) return(1 + location + rnorm(nrow(data), sd = exp(data$actor_predictor - 1)))
  # Scaling by pi / sqrt(3) keeps the Gaussian dyad-to-residual variance ratio under
  # standard logistic noise. The thresholds give category shares of 10/20/40/20/10%.
  latent <- pi / sqrt(3) * location + stats::rlogis(nrow(data))
  ordered(findInterval(latent, c(-3.05, -1.23, 1.23, 3.05)) + 1L, levels = 1:5)
}

core_panels <- c("qq", "mean_distance", "predicted_quantiles", "predicted_distance",
                 "response_sd", "maximum_deviation", "zeros")
page_panels <- c(core_panels, "actor_quantiles", "actor_distance",
                 "partner_quantiles", "partner_distance")

record_confirmation_residuals <- function(result) {
  composition <- result$compositions[[1]]
  dplyr::bind_rows(lapply(names(composition$rows), function(role) {
    statistics <- composition$statistics[[role]]
    patterns <- lapply(composition$patterns, function(pattern)
      dplyr::bind_rows(distribution_curve(pattern[[role]]$quantiles),
                       distribution_curve(pattern[[role]]$distance)))
    dplyr::bind_rows(distribution_curve(statistics$qq),
                     distribution_scalar(statistics$mean_distance), patterns) |>
      dplyr::mutate(statistic = c("qq", "mean_distance", paste0(rep(
        c("predicted", "actor", "partner"), each = 2), c("_quantiles", "_distance"))),
        role, check = "residual")
  }))
}

# Zeros only where the package shows them; category_any only for ordinal bars.
record_confirmation_outcomes <- function(result) {
  composition <- result$compositions[[1]]
  labels <- c(response_sd = "Response SD", maximum_deviation = "Largest absolute deviation",
              zeros = "Number of zeros")
  dplyr::bind_rows(lapply(names(composition$rows), function(role) {
    values <- composition$statistics[[role]]
    shown <- labels[labels %in% rownames(values)]
    rows <- dplyr::bind_rows(lapply(shown, function(name) distribution_scalar(values[name, ]))) |>
      dplyr::mutate(statistic = names(shown))
    if (!is.null(composition$distribution$labels)) {
      bars <- composition$distribution$roles[[role]]
      rows <- dplyr::bind_rows(rows, data.frame(statistic = "category_any",
        below = any(bars$observed < bars$bounds[1, ]), above = any(bars$observed > bars$bounds[2, ])) |>
        dplyr::mutate(flagged = below | above))
    }
    dplyr::mutate(rows, role, check = "outcome")
  }))
}

# Unions per role, for each check and both checks together. Then each panel and
# union in either role ("All"), as in the main study.
add_confirmation_unions <- function(rows) {
  any_flag <- function(data) data |>
    dplyr::group_by(view, role, check, statistic) |>
    dplyr::summarise(dplyr::across(c(below, above, flagged), distribution_any), .groups = "drop")
  unions <- list(core = core_panels, pages = page_panels)
  rows <- dplyr::bind_rows(rows, lapply(names(unions), function(union) {
    panels <- dplyr::mutate(rows[rows$statistic %in% unions[[union]], ], statistic = union)
    any_flag(dplyr::bind_rows(panels, dplyr::mutate(panels, check = "both")))
  }))
  dplyr::bind_rows(rows, any_flag(dplyr::mutate(rows, role = "All")))
}

# The same displays in every condition: pooled and by role, with both predictor pages.
evaluate_confirmation_checks <- function(simulations, data, pit_seed) {
  rows <- dplyr::bind_rows(lapply(c("pooled", "roles"), function(view) {
    arguments <- list(simulations, dyad = "dyad", role = if (view == "roles") "role",
                      data = data, plot = FALSE)
    residuals <- do.call(check_dyad_residuals, c(arguments, list(
      predictors = c("actor_predictor", "partner_predictor"), seed = pit_seed)))
    outcomes <- do.call(check_dyad_outcomes, arguments)
    dplyr::bind_rows(record_confirmation_residuals(residuals),
                     record_confirmation_outcomes(outcomes)) |>
      dplyr::mutate(view)
  }))
  add_confirmation_unions(rows)
}

run_confirmation_dataset <- function(condition, repetition, reference_draws) {
  # Seeds, including offsets, lie above those of the main study and its add-on.
  dataset_seed <- 910000000L + 100000L * condition$condition + repetition
  data <- generate_distribution_design(condition, dataset_seed)
  data$outcome <- generate_confirmation_response(data, condition)
  fits <- data.frame(condition = condition$condition, repetition, reference = "fitted",
    dataset_seed, usable = FALSE, status = "fit_error", convergence = NA_integer_,
    positive_hessian = NA, dyad_sd = NA_real_, dispersion = NA_real_, warnings = "",
    error = "", fit_seconds = 0, check_seconds = 0)
  statistics <- NULL
  warnings <- character()
  tryCatch(withCallingHandlers({
    formula <- if (condition$scenario == "omitted_partner") outcome ~ actor_predictor + (1 | dyad) else
      outcome ~ actor_predictor + partner_predictor + (1 | dyad)
    family <- switch(condition$fit_family, gaussian = gaussian(), poisson = poisson(),
      nbinom2 = glmmTMB::nbinom2(), ordinal = glmmTMB::ordinal())
    fits$fit_seconds <- system.time(model <- glmmTMB::glmmTMB(
      formula, data = data, family = family), gcFirst = FALSE)[["elapsed"]]
    fits$convergence <- model$fit$convergence
    fits$positive_hessian <- isTRUE(model$sdr$pdHess)
    fits$dyad_sd <- attr(glmmTMB::VarCorr(model)$cond$dyad, "stddev")[[1]]
    fits$dispersion <- stats::sigma(model)
    if (fits$convergence != 0L || !fits$positive_hessian) {
      fits$status <- "fit_problem"
      stop("Convergence or Hessian problem.")
    }
    fits$status <- "check_error"
    simulations <- simulate_dyad_responses(model, nsim = reference_draws,
                                           seed = dataset_seed + 10000000L)
    fits$check_seconds <- system.time(statistics <- evaluate_confirmation_checks(
      simulations, data, dataset_seed + 30000000L), gcFirst = FALSE)[["elapsed"]]
    fits$usable <- TRUE
    fits$status <- "success"
  }, warning = function(warning) {
    warnings <<- c(warnings, conditionMessage(warning))
    invokeRestart("muffleWarning")
  }), error = function(error) fits$error <<- conditionMessage(error))
  fits$warnings <- paste(unique(warnings), collapse = " | ")
  if (!is.null(statistics)) statistics <- dplyr::mutate(statistics,
    condition = condition$condition, repetition, reference = "fitted", .before = 1)
  list(fits = fits, statistics = statistics)
}

run_confirmation <- function(repetitions = 500L, reference_draws = 1000L, workers = 6L,
                             mode = "run", selected = NULL) {
  integers <- c(repetitions, reference_draws, workers, selected)
  stopifnot(all(is.finite(integers)), all(integers == floor(integers)),
    repetitions > 0L, repetitions < 100000L, reference_draws >= 200L,
    workers > 0L, workers <= 10L, mode %in% c("run", "summarise"))
  if (.Platform$OS.type == "windows") workers <- 1L
  conditions <- confirmation_conditions() |>
    dplyr::mutate(repetitions = as.integer(repetitions), reference_draws = as.integer(reference_draws))
  if (is.null(selected)) selected <- conditions$condition
  stopifnot(length(selected) > 0L, all(selected %in% conditions$condition), !anyDuplicated(selected))
  output_directory <- file.path(study_directory, "results/distribution-checks",
    paste0("confirmation-", repetitions, "-datasets-", reference_draws, "-draws"))
  dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)
  if (mode == "run") {
    # Prevent a resumed run from silently combining different generators or package
    # code. Help text (roxygen lines) may change during the run.
    source_files <- c(sort(list.files("R", "[.]R$", full.names = TRUE)),
      file.path(study_directory, "distribution-checks", c("helpers.R", "confirmation.R")))
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
      writeLines(c(paste("Commit:", system("git rev-parse HEAD", intern = TRUE)),
        paste("Uncommitted changes:", paste(system("git status --short", intern = TRUE), collapse = "; ")),
        capture.output(sessionInfo())), file.path(output_directory, "session-info.txt"))
    }
    finished <- parallel::mclapply(selected, function(condition_index) {
      condition <- conditions[conditions$condition == condition_index, ]
      checkpoint <- file.path(output_directory, paste0("condition-", condition_index, ".rds"))
      completed <- if (file.exists(checkpoint)) readRDS(checkpoint) else list()
      if (length(completed) < repetitions) {
        for (repetition in seq.int(length(completed) + 1L, repetitions)) {
          completed[[repetition]] <- run_confirmation_dataset(condition, repetition, reference_draws)
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
  statistics <- dplyr::bind_rows(lapply(completed, `[[`, "statistics"))
  summaries <- summarise_distribution_study(conditions[conditions$condition %in% fits$condition, ],
                                            fits, statistics)
  tables <- list(summary = summaries$summary, fits = summaries$fit_summary,
    # A range with equal limits means at least 95% of simulated datasets gave the same value.
    `maximum-deviation-ties` = statistics |>
      dplyr::filter(statistic == "maximum_deviation", role != "All") |>
      dplyr::group_by(condition, view, role) |>
      dplyr::summarise(checked = dplyr::n(), tied = sum(lower == upper),
                       rate = tied / checked, .groups = "drop") |>
      dplyr::left_join(conditions, by = "condition"))
  for (name in names(tables))
    write.csv(tables[[name]], file.path(output_directory, paste0(name, ".csv")), row.names = FALSE)
  complete <- all(table(factor(fits$condition, conditions$condition)) == repetitions)
  if (complete && repetitions == 500L && reference_draws == 1000L) {
    files <- c(paste0(names(tables), ".csv"), "session-info.txt")
    stopifnot(all(file.copy(file.path(output_directory, files), file.path(study_directory,
      "report-data/distribution-checks", paste0("confirmation-", files)), overwrite = TRUE)))
  }
  message(if (complete) "Complete" else "Partial", " results saved in ", output_directory)
  invisible(output_directory)
}

if (sys.nframe() == 0L) {
  arguments <- commandArgs(trailingOnly = TRUE)
  run_confirmation(
    repetitions = if (length(arguments) >= 1L) as.numeric(arguments[1]) else 500L,
    reference_draws = if (length(arguments) >= 2L) as.numeric(arguments[2]) else 1000L,
    workers = if (length(arguments) >= 3L) as.numeric(arguments[3]) else 6L,
    mode = if (length(arguments) >= 4L) arguments[4] else "run",
    selected = if (length(arguments) >= 5L)
      as.numeric(strsplit(arguments[5], ",", fixed = TRUE)[[1]]) else NULL)
}
