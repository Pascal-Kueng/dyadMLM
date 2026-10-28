# Run from the repository root: datasets, reference draws, workers, run/summarise.
# Reuse the frozen main study's generators, fitting and diagnostic summaries.
source("dev/diagnostic_checks/simulation-studies/ild-partner-dependence/run.R")

consequence_conditions <- function() {
  strengths <- dplyr::bind_rows(
    tibble::tibble(axis = "stable_cor", strength = c(0, 0.1, 0.2, 0.4),
                   restricted_model = "no_stable_covariance"),
    tibble::tibble(axis = "occasion_cor", strength = c(0, 0.1, 0.2, 0.3),
                   restricted_model = "no_occasion_covariance"),
    tibble::tibble(axis = "occasion_sd_ratio", strength = c(1, 1.1, 1.25, 1.5),
                   restricted_model = "equal_occasion_variances")
  )
  tidyr::crossing(n_dyads = c(50L, 200L), n_occasions = 14L, strengths) |>
    dplyr::mutate(condition = dplyr::row_number(), .before = 1)
}

consequence_truth <- function(condition) {
  truth <- true_parameters$gaussian
  if (condition$axis == "occasion_sd_ratio") {
    truth$occasion_sds <- sqrt(2 * 1.04 / (1 + condition$strength^2)) * c(condition$strength, 1)
  } else truth[[condition$axis]] <- condition$strength
  truth
}

generate_consequence_data <- function(condition, seed) {
  truth <- consequence_truth(condition)
  generator <- generate_occasion_data
  # Change this function copy's truth lookup without changing the main study.
  environment(generator) <- list2env(list(cell_truth = function(cell) truth),
                                    parent = environment(generator))
  cell <- list(part = "gaussian", n_dyads = condition$n_dyads,
               n_occasions = condition$n_occasions, missing_share = 0, ar_phi = 0)
  generator(cell, seed)
}

record_consequence_inference <- function(model, truth) {
  consequence_inference(glmmTMB::fixef(model)$cond, stats::vcov(model)$cond, truth)
}

consequence_inference <- function(coefficients, covariance, truth) {
  covariance <- covariance[names(coefficients), names(coefficients), drop = FALSE]
  contrasts <- matrix(0, 4L, length(coefficients), dimnames = list(
    c("x_actor", "x_partner", "role_average_intercept", "role_difference"), names(coefficients)))
  contrasts["x_actor", "x_actor"] <- contrasts["x_partner", "x_partner"] <- 1
  contrasts["role_average_intercept", c("genderfemale", "gendermale")] <- 0.5
  contrasts["role_difference", c("genderfemale", "gendermale")] <- c(1, -1)
  estimate <- as.vector(contrasts %*% coefficients)
  se <- sqrt(diag(contrasts %*% covariance %*% t(contrasts)))
  true_value <- c(truth$actor, truth$partner, mean(truth$intercepts), truth$intercepts[1] - truth$intercepts[2])
  defined <- is.finite(estimate) & is.finite(se) & se > 0
  tibble::tibble(parameter = rownames(contrasts), true_value, estimate, se = unname(se), defined,
                 covered = ifelse(defined, abs(estimate - true_value) <= qnorm(0.975) * se, NA))
}

run_consequence_dataset <- function(condition, repetition, reference_draws) {
  dataset_seed <- 1200000000L + 10000L * condition$condition + repetition
  data <- generate_consequence_data(condition, dataset_seed)
  truth <- consequence_truth(condition)
  models <- c(full = "correct", restricted = condition$restricted_model)
  empty_inference <- tibble::tibble(parameter = character(), true_value = numeric(),
    estimate = numeric(), se = numeric(), defined = logical(), covered = logical())
  empty_checks <- tibble::tibble(response = character(), level = character(), statistic = character(),
    observed = numeric(), lower = numeric(), upper = numeric(),
    n_defined = integer(), n_below = integer(), n_above = integer())
  results <- lapply(seq_along(models), function(index) {
    fit <- fit_occasion_model(data, list(part = "gaussian"), unname(models[index]))
    status <- dplyr::mutate(fit$status, inference_error = "", check_error = "",
                            check_warnings = "", check_seconds = NA_real_)
    inference <- empty_inference
    checks <- empty_checks
    if (!is.null(fit$model)) {
      inference <- tryCatch(record_consequence_inference(fit$model, truth), error = function(error) {
        status$inference_error <<- conditionMessage(error)
        empty_inference
      })
      if (names(models)[index] == "restricted") {
        started <- proc.time()[["elapsed"]]
        warnings <- character()
        checks <- tryCatch(withCallingHandlers(suppressMessages({
          simulations <- simulate_dyad_responses(fit$model, nsim = reference_draws,
                                                 seed = dataset_seed + 100000000L)
          check <- check_partner_dependence(simulations, dyad = dyad, role = gender,
            member = person, time = occasion, data = data, plot = FALSE)
          dplyr::mutate(record_occasion_check(check), response = "model-centred", .before = 1)
        }), warning = function(warning) {
          warnings <<- c(warnings, conditionMessage(warning))
          invokeRestart("muffleWarning")
        }), error = function(error) {
          status$check_error <<- conditionMessage(error)
          empty_checks
        })
        status$check_warnings <- paste(unique(warnings), collapse = " | ")
        status$check_seconds <- proc.time()[["elapsed"]] - started
      }
    }
    list(fits = status, inference = inference, checks = checks)
  })
  label_rows <- function(component) {
    dplyr::bind_rows(lapply(seq_along(results), function(index) {
      dplyr::mutate(results[[index]][[component]], fit = names(models)[index], model = unname(models[index]))
    })) |>
      dplyr::mutate(condition = condition$condition, repetition, reference_draws, .before = 1)
  }
  list(fits = dplyr::mutate(label_rows("fits"), dataset_seed),
       inference = label_rows("inference"), checks = label_rows("checks"))
}

summarise_consequences <- function(completed, conditions, output_directory, repetitions, reference_draws) {
  fits <- dplyr::bind_rows(lapply(completed, `[[`, "fits"))
  inference <- dplyr::bind_rows(lapply(completed, `[[`, "inference"))
  defined <- inference |>
    dplyr::summarise(inference_defined = dplyr::n() == 4L && all(defined),
                     .by = c(condition, repetition, fit))
  fits <- fits |>
    dplyr::left_join(defined, by = c("condition", "repetition", "fit")) |>
    dplyr::mutate(inference_defined = !is.na(inference_defined) & inference_defined,
      paired = dplyr::n() == 2L && all(usable & inference_defined), .by = c(condition, repetition))
  valid_inference <- inference |>
    dplyr::inner_join(dplyr::select(fits, condition, repetition, fit, usable, paired),
                      by = c("condition", "repetition", "fit")) |>
    dplyr::filter(usable, defined)
  inference_summary <- dplyr::bind_rows(usable = valid_inference,
    paired = dplyr::filter(valid_inference, paired), .id = "sample") |>
    dplyr::summarise(n = dplyr::n(), true_value = dplyr::first(true_value),
      bias = mean(estimate - true_value), bias_mcse = sd(estimate) / sqrt(n),
      empirical_sd = sd(estimate), mean_se = mean(se), se_ratio = mean_se / empirical_sd,
      checked = n, flagged = sum(covered), .by = c(condition, fit, sample, parameter)) |>
    add_rate_intervals() |>
    dplyr::rename(coverage = rate, coverage_lower = lower, coverage_upper = upper) |>
    dplyr::mutate(coverage_mcse = sqrt(coverage * (1 - coverage) / n)) |>
    dplyr::select(-checked, -flagged)
  checks <- dplyr::bind_rows(lapply(completed, `[[`, "checks")) |>
    dplyr::left_join(dplyr::select(fits, condition, repetition, fit, usable),
                     by = c("condition", "repetition", "fit")) |>
    add_flags()
  check_sets <- dplyr::bind_rows(all = checks, usable = dplyr::filter(checks, usable), .id = "fits")
  flags <- check_sets |>
    dplyr::summarise(checked = dplyr::n(), flagged = sum(flagged), below = sum(below), above = sum(above),
      min_defined = if (length(n_defined)) min(n_defined) else NA_integer_,
      partial_references = sum(n_defined < .env$reference_draws),
      .by = c(fits, rule, condition, level, statistic)) |>
    add_rate_intervals() |>
    dplyr::mutate(mcse = sqrt(rate * (1 - rate) / checked))
  figures <- check_sets |>
    dplyr::summarise(between = any(flagged[level == "between"]), within = any(flagged[level == "within"]),
      .by = c(fits, rule, condition, repetition)) |>
    dplyr::mutate(either = between | within) |>
    tidyr::pivot_longer(c(between, within, either), names_to = "figure", values_to = "flag") |>
    dplyr::summarise(checked = dplyr::n(), flagged = sum(flag), .by = c(fits, rule, condition, figure)) |>
    add_rate_intervals() |>
    dplyr::mutate(mcse = sqrt(rate * (1 - rate) / checked))
  fit_summary <- fits |>
    dplyr::summarise(optimizer = dplyr::first(optimizer), attempted = dplyr::n(),
      inference_defined = sum(usable & inference_defined), paired = sum(paired), usable = sum(usable),
      not_converged = sum(!is.na(convergence) & convergence != 0L),
      not_positive_hessian = sum(positive_hessian %in% FALSE),
      fit_errors = sum(error != ""), fit_warnings = sum(warnings != ""),
      inference_errors = sum(inference_error != ""), check_errors = sum(check_error != ""),
      check_warnings = sum(check_warnings != ""), median_fit_seconds = median(fit_seconds),
      median_check_seconds = median(check_seconds, na.rm = TRUE), .by = c(condition, fit, model))
  tables <- list(conditions = dplyr::mutate(conditions, repetitions, reference_draws),
    inference = inference_summary, flags = flags, figures = figures, fits = fit_summary)
  for (name in names(tables)) write.csv(tables[[name]], file.path(output_directory, paste0(name, ".csv")), row.names = FALSE)
  invisible(tables)
}

run_consequences <- function(repetitions = 500L, reference_draws = 1000L, workers = 10L, mode = "run") {
  stopifnot(repetitions > 0L, reference_draws >= 40L, workers > 0L, mode %in% c("run", "summarise"))
  conditions <- consequence_conditions()
  output_directory <- file.path(study_directory, "results/ild-partner-dependence-consequences",
                                 paste0(repetitions, "-datasets-", reference_draws, "-draws"))
  dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)
  source_files <- c("DESCRIPTION", "NAMESPACE", sort(list.files("R", full.names = TRUE)),
    file.path(study_directory, c("covariance-pooling/run.R", "ild-partner-dependence/run.R",
                                 "ild-partner-dependence/consequences.R")))
  specification <- list(repetitions = repetitions, reference_draws = reference_draws,
    conditions = conditions, baseline = true_parameters$gaussian, source_hashes = tools::md5sum(source_files),
    R = R.version.string, packages = lapply(c("glmmTMB", "TMB", "Matrix", "dplyr", "tidyr"), packageDescription))
  specification_file <- file.path(output_directory, "run-specification.rds")
  if (file.exists(specification_file)) {
    if (!identical(readRDS(specification_file), specification)) {
      stop("Study code, design or software changed. Use a fresh results directory; do not mix checkpoints.")
    }
  } else {
    if (length(list.files(output_directory, "^condition-.*[.]rds$"))) stop("Checkpoints have no run specification.")
    saveRDS(specification, specification_file)
    writeLines(capture.output(sessionInfo()), file.path(output_directory, "session-info.txt"))
    saveRDS(setNames(lapply(source_files, readLines, warn = FALSE), source_files),
            file.path(output_directory, "source-snapshot.rds"))
  }
  tasks <- tidyr::crossing(condition = conditions$condition, block = seq_len(ceiling(repetitions / 10L))) |>
    dplyr::left_join(conditions, by = "condition") |>
    dplyr::mutate(file = file.path(output_directory, sprintf("condition-%02d-block-%02d.rds", condition, block))) |>
    dplyr::arrange(dplyr::desc(n_dyads), block, condition)
  if (mode == "run") {
    pending <- tasks[!file.exists(tasks$file), ]
    message(format(Sys.time()), ": ", nrow(pending), " of ", nrow(tasks), " blocks to run")
    results <- parallel::mclapply(seq_len(nrow(pending)), function(index) {
      task <- pending[index, ]
      condition <- conditions[match(task$condition, conditions$condition), ]
      started <- Sys.time()
      indices <- seq.int((task$block - 1L) * 10L + 1L, min(task$block * 10L, repetitions))
      completed <- lapply(indices, function(repetition) run_consequence_dataset(condition, repetition, reference_draws))
      saveRDS(completed, paste0(task$file, ".tmp"))
      stopifnot(file.rename(paste0(task$file, ".tmp"), task$file))
      message(format(Sys.time()), ": condition ", task$condition, " (", condition$axis, ", ", condition$strength,
        ", ", condition$n_dyads, " dyads) block ", task$block, " done in ",
        round(as.numeric(difftime(Sys.time(), started, units = "mins")), 1), " min")
      NULL
    }, mc.cores = workers, mc.set.seed = FALSE, mc.preschedule = FALSE)
    if (any(vapply(results, inherits, logical(1), "try-error"))) message("Some blocks failed; rerun to resume them.")
  }
  completed <- unlist(lapply(tasks$file[file.exists(tasks$file)], readRDS), recursive = FALSE)
  stopifnot(length(completed) > 0L)
  summarise_consequences(completed, conditions, output_directory, repetitions, reference_draws)
  if (repetitions == 500L && reference_draws == 1000L && all(file.exists(tasks$file))) {
    report_directory <- file.path(study_directory, "report-data/ild-partner-dependence-consequences")
    dir.create(report_directory, showWarnings = FALSE)
    file.copy(file.path(output_directory, paste0(c("conditions", "inference", "flags", "figures", "fits"), ".csv")),
               report_directory, overwrite = TRUE)
  }
  message("Saved results: ", output_directory)
  invisible(output_directory)
}

if (sys.nframe() == 0L) {
  arguments <- commandArgs(trailingOnly = TRUE)
  run_consequences(
    repetitions = if (length(arguments) >= 1L) as.integer(arguments[1]) else 500L,
    reference_draws = if (length(arguments) >= 2L) as.integer(arguments[2]) else 1000L,
    workers = if (length(arguments) >= 3L) as.integer(arguments[3]) else 10L,
    mode = if (length(arguments) >= 4L) arguments[4] else "run")
}
