# Run from the repository root: datasets, workers, run/summarise, optional output directory.
source("dev/diagnostic_checks/simulation-studies/mixed-apim-recovery/helpers.R")

summarise_mixed_recovery <- function(completed, repetitions, output_directory) {
  fits <- dplyr::bind_rows(lapply(completed, `[[`, "fits"))
  estimates <- dplyr::bind_rows(lapply(completed, `[[`, "estimates"))
  saveRDS(list(fits = fits, estimates = estimates),
    file.path(output_directory, "dataset-tables.rds"))

  fit_summary <- fits |>
    dplyr::summarise(attempted = dplyr::n(), usable = sum(usable %in% TRUE),
      usable_rate = usable / attempted,
      not_converged = sum(!is.na(convergence) & convergence != 0L),
      not_positive_hessian = sum(positive_hessian %in% FALSE),
      boundary = sum(boundary %in% TRUE),
      initialization_failures = sum(initialization_failures > 0L, na.rm = TRUE),
      fit_warnings = sum(!is.na(warnings) & warnings != ""),
      fit_errors = sum(!is.na(error) & error != ""),
      median_seconds = median(elapsed_seconds, na.rm = TRUE), .by = condition)

  # Recovery conditions on usable fits. Each parameter retains its own estimate
  # and interval denominators.
  recovery <- estimates |>
    dplyr::inner_join(dplyr::filter(fits, usable) |>
        dplyr::select(condition, repetition), by = c("condition", "repetition")) |>
    dplyr::filter(is.finite(estimate), is.finite(true_value)) |>
    dplyr::mutate(error = estimate - true_value,
      interval_available = kind == "fixed" & is.finite(se) & se > 0,
      covered = interval_available & abs(error) <= qnorm(0.975) * se) |>
    dplyr::summarise(n = dplyr::n(), true_value = dplyr::first(true_value),
      mean = mean(estimate), bias = mean(error), empirical_sd = sd(estimate),
      bias_mcse = empirical_sd / sqrt(n), rmse = sqrt(mean(error^2)),
      mean_absolute_error = mean(abs(error)),
      interval_n = sum(interval_available), covered = sum(covered, na.rm = TRUE),
      mean_se = if (any(interval_available)) mean(se[interval_available]) else NA_real_,
      .by = c(condition, component, composition, parameter, kind)) |>
    dplyr::mutate(se_ratio = mean_se / empirical_sd,
      coverage = ifelse(interval_n > 0L, covered / interval_n, NA_real_),
      coverage_mcse = sqrt(coverage * (1 - coverage) / interval_n))
  # Wilson intervals describe Monte Carlo uncertainty in estimated coverage.
  z <- qnorm(0.975)
  denominator <- 1 + z^2 / recovery$interval_n
  centre <- (recovery$coverage + z^2 / (2 * recovery$interval_n)) / denominator
  half_width <- z * sqrt(recovery$coverage * (1 - recovery$coverage) /
    recovery$interval_n + z^2 / (4 * recovery$interval_n^2)) / denominator
  recovery$coverage_lower <- centre - half_width
  recovery$coverage_upper <- centre + half_width
  recovery <- dplyr::left_join(recovery,
    dplyr::select(fit_summary, condition, attempted, usable), by = "condition")

  tables <- list(conditions = dplyr::mutate(study_conditions, repetitions),
    fits = fit_summary, recovery = recovery)
  for (name in names(tables))
    write.csv(tables[[name]], file.path(output_directory, paste0(name, ".csv")), row.names = FALSE)
  invisible(tables)
}

run_mixed_recovery <- function(repetitions = 500L, workers = 10L, mode = "run",
                               output_directory = NULL) {
  stopifnot(length(repetitions) == 1L, is.finite(repetitions), repetitions > 0L,
    repetitions < 10000L, repetitions == floor(repetitions),
    length(workers) == 1L, is.finite(workers), workers > 0L, workers <= 10L,
    workers == floor(workers), mode %in% c("run", "summarise"))
  repetitions <- as.integer(repetitions)
  workers <- if (.Platform$OS.type == "windows") 1L else as.integer(workers)
  seed_offset <- if (repetitions == 500L) 0L else 10000000L
  if (is.null(output_directory)) output_directory <- file.path(study_directory,
    "results/mixed-apim-recovery", paste0(repetitions, "-datasets"))
  dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)

  # Refuse to combine datasets generated with different code, settings or software.
  sources <- c("DESCRIPTION", "NAMESPACE", sort(list.files("R", "[.]R$", full.names = TRUE)),
    file.path(study_directory, "mixed-apim-recovery", c("helpers.R", "run.R")))
  specification <- list(repetitions = repetitions, seed_offset = seed_offset,
    conditions = study_conditions, source_hashes = tools::md5sum(sources),
    R = R.version.string,
    packages = lapply(c("glmmTMB", "TMB", "Matrix", "dplyr", "tidyr", "pkgload"), packageDescription))
  specification_file <- file.path(output_directory, "run-specification.rds")
  if (file.exists(specification_file)) {
    if (!identical(readRDS(specification_file), specification))
      stop("Study code, settings or software changed. Use a fresh results directory; do not mix checkpoints.")
  } else {
    if (length(list.files(output_directory, "^condition-.*[.]rds$")))
      stop("Checkpoints have no run specification. Use a fresh results directory.")
    saveRDS(specification, specification_file)
    saveRDS(setNames(lapply(sources, readLines, warn = FALSE), sources),
      file.path(output_directory, "source-snapshot.rds"))
    writeLines(capture.output(sessionInfo()), file.path(output_directory, "session-info.txt"))
  }

  block_size <- 10L
  tasks <- tidyr::crossing(condition = study_conditions$condition,
    block = seq_len(ceiling(repetitions / block_size))) |>
    dplyr::left_join(study_conditions, by = "condition") |>
    dplyr::mutate(cost = n_dyads * n_occasions * ifelse(design == "ild_slopes", 4, 1),
      file = file.path(output_directory, sprintf("condition-%02d-block-%02d.rds", condition, block))) |>
    dplyr::arrange(dplyr::desc(cost), block, condition)
  if (mode == "run") {
    pending <- tasks[!file.exists(tasks$file), ]
    message(format(Sys.time()), ": ", nrow(pending), " of ", nrow(tasks), " blocks to run")
    results <- parallel::mclapply(seq_len(nrow(pending)), function(index) {
      task <- pending[index, ]
      condition <- study_conditions[match(task$condition, study_conditions$condition), ]
      started <- Sys.time()
      block_repetitions <- seq.int((task$block - 1L) * block_size + 1L,
        min(task$block * block_size, repetitions))
      completed <- lapply(block_repetitions, function(repetition)
        run_recovery_dataset(condition, repetition, seed_offset = seed_offset))
      saveRDS(completed, paste0(task$file, ".tmp"))
      stopifnot(file.rename(paste0(task$file, ".tmp"), task$file))
      message(format(Sys.time()), ": condition ", task$condition, " (", condition$design,
        ", ", condition$pooling, ", ", condition$n_dyads, " dyads), block ", task$block,
        " done in ", round(as.numeric(difftime(Sys.time(), started, units = "mins")), 1), " min")
      NULL
    }, mc.cores = workers, mc.set.seed = FALSE, mc.preschedule = FALSE)
    failed <- vapply(results, inherits, logical(1), "try-error")
    if (any(failed)) message(sum(failed), " blocks failed; rerun to resume them.")
  }
  completed <- unlist(lapply(tasks$file[file.exists(tasks$file)], readRDS), recursive = FALSE)
  if (!length(completed)) stop("No completed datasets found.")
  tables <- summarise_mixed_recovery(completed, repetitions, output_directory)
  complete <- all(file.exists(tasks$file)) &&
    setequal(tables$fits$condition, study_conditions$condition) &&
    all(tables$fits$attempted == repetitions)
  if (complete && repetitions == 500L) {
    report_directory <- file.path(study_directory, "report-data/mixed-apim-recovery")
    dir.create(report_directory, recursive = TRUE, showWarnings = FALSE)
    stopifnot(all(file.copy(file.path(output_directory,
      c("conditions.csv", "fits.csv", "recovery.csv")), report_directory, overwrite = TRUE)))
  }
  message(if (complete) "Complete" else "Partial", " study saved in ", output_directory)
  invisible(output_directory)
}

if (sys.nframe() == 0L) {
  arguments <- commandArgs(trailingOnly = TRUE)
  run_mixed_recovery(
    repetitions = if (length(arguments) >= 1L) as.numeric(arguments[1]) else 500L,
    workers = if (length(arguments) >= 2L) as.numeric(arguments[2]) else 10L,
    mode = if (length(arguments) >= 3L) arguments[3] else "run",
    output_directory = if (length(arguments) >= 4L) arguments[4] else NULL)
}
