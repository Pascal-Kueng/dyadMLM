# Run from the repository root. Arguments: datasets, reference draws, workers,
# run/summarise, and optional comma-separated condition numbers.
pkgload::load_all(quiet = TRUE)
study_directory <- "dev/diagnostic_checks/simulation-studies"
source(file.path(study_directory, "distribution-checks/helpers.R"))
source(file.path(study_directory, "distribution-checks/summarise.R"))

run_distribution_study <- function(repetitions = 500L, reference_draws = 1000L,
                                   workers = 6L, mode = "run", selected = NULL) {
  integers <- c(repetitions, reference_draws, workers, selected)
  stopifnot(all(is.finite(integers)), all(integers == floor(integers)),
    repetitions > 0L, repetitions < 100000L, reference_draws >= 200L,
    workers > 0L, workers <= 10L, mode %in% c("run", "summarise"))
  repetitions <- as.integer(repetitions)
  reference_draws <- as.integer(reference_draws)
  workers <- as.integer(workers)
  if (.Platform$OS.type == "windows") workers <- 1L
  conditions <- distribution_conditions() |>
    dplyr::mutate(repetitions, reference_draws)
  if (is.null(selected)) selected <- conditions$condition
  stopifnot(length(selected) > 0L, all(selected %in% conditions$condition), !anyDuplicated(selected))
  output_directory <- file.path(study_directory, "results/distribution-checks",
    paste0(repetitions, "-datasets-", reference_draws, "-draws"))
  dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)
  # Prevent a resumed run from silently combining different generators or package code.
  source_files <- c(sort(list.files("R", "[.]R$", full.names = TRUE)),
    file.path(study_directory, "distribution-checks", c("helpers.R", "run.R")))
  settings <- list(conditions = conditions, sources = tools::md5sum(source_files),
    R = as.character(getRversion()), glmmTMB = as.character(utils::packageVersion("glmmTMB")),
    TMB = as.character(utils::packageVersion("TMB")))
  settings_file <- file.path(output_directory, "settings.rds")
  if (file.exists(settings_file)) {
    if (!identical(readRDS(settings_file), settings))
      stop("Saved settings or source code differ. Archive this run before starting a new one.")
  } else {
    saveRDS(settings, settings_file)
    write.csv(conditions, file.path(output_directory, "conditions.csv"), row.names = FALSE)
    write.csv(data.frame(file = names(settings$sources), md5 = unname(settings$sources)),
      file.path(output_directory, "source-hashes.csv"), row.names = FALSE)
    writeLines(c(paste("Commit:", system("git rev-parse HEAD", intern = TRUE)),
      paste("Uncommitted changes:", paste(system("git status --short", intern = TRUE), collapse = "; ")),
      capture.output(sessionInfo())), file.path(output_directory, "session-info.txt"))
  }
  if (mode == "run") {
    completed_conditions <- parallel::mclapply(selected, function(condition_index) {
      condition <- conditions[conditions$condition == condition_index, ]
      checkpoint <- file.path(output_directory, paste0("condition-", condition_index, ".rds"))
      completed <- if (file.exists(checkpoint)) readRDS(checkpoint) else list()
      if (length(completed) < repetitions) {
        for (repetition in seq.int(length(completed) + 1L, repetitions)) {
          completed[[repetition]] <- run_distribution_dataset(condition, repetition, reference_draws)
          if (repetition %% 5L == 0L || repetition == repetitions) {
            saveRDS(completed, paste0(checkpoint, ".tmp"))
            stopifnot(file.rename(paste0(checkpoint, ".tmp"), checkpoint))
            message("Condition ", condition_index, ": ", repetition, "/", repetitions)
          }
        }
      }
      invisible(NULL)
    }, mc.cores = workers, mc.set.seed = FALSE, mc.preschedule = FALSE)
    stopifnot(!any(vapply(completed_conditions, inherits, logical(1), "try-error")))
  }
  checkpoints <- list.files(output_directory, "^condition-[0-9]+[.]rds$", full.names = TRUE)
  if (!length(checkpoints)) stop("No checkpoints found; run at least one condition first.")
  # Summarise one condition at a time; complete PIT matrices and fits are never saved.
  tables <- lapply(checkpoints, function(checkpoint) {
    completed <- readRDS(checkpoint)
    fits <- dplyr::bind_rows(lapply(completed, `[[`, "fits"))
    statistics <- dplyr::bind_rows(lapply(completed, `[[`, "statistics"))
    summarise_distribution_study(conditions[conditions$condition %in% fits$condition, ],
                                 fits, statistics)
  })
  report_tables <- list(
    summary = dplyr::bind_rows(lapply(tables, `[[`, "summary")),
    `paired-comparison` = dplyr::bind_rows(lapply(tables, `[[`, "paired_comparison")),
    fits = dplyr::bind_rows(lapply(tables, `[[`, "fit_summary")))
  for (name in names(report_tables))
    write.csv(report_tables[[name]], file.path(output_directory, paste0(name, ".csv")), row.names = FALSE)
  fit_counts <- report_tables$fits[report_tables$fits$reference == "fitted", ]
  complete <- setequal(fit_counts$condition, conditions$condition) &&
    all(fit_counts$attempted == repetitions)
  if (complete && repetitions == 500L && reference_draws == 1000L) {
    report_directory <- file.path(study_directory, "report-data/distribution-checks")
    dir.create(report_directory, recursive = TRUE, showWarnings = FALSE)
    files <- c("conditions.csv", "summary.csv", "paired-comparison.csv", "fits.csv",
               "source-hashes.csv", "session-info.txt")
    stopifnot(all(file.copy(file.path(output_directory, files), report_directory, overwrite = TRUE)))
    rmarkdown::render("vignettes/articles/distribution-checks.Rmd",
      output_dir = normalizePath(output_directory), envir = new.env(), quiet = TRUE)
  }
  message(if (complete) "Complete" else "Partial", " study saved in ", output_directory)
  invisible(output_directory)
}

if (sys.nframe() == 0L) {
  arguments <- commandArgs(trailingOnly = TRUE)
  run_distribution_study(
    repetitions = if (length(arguments) >= 1L) as.numeric(arguments[1]) else 500L,
    reference_draws = if (length(arguments) >= 2L) as.numeric(arguments[2]) else 1000L,
    workers = if (length(arguments) >= 3L) as.numeric(arguments[3]) else 6L,
    mode = if (length(arguments) >= 4L) arguments[4] else "run",
    selected = if (length(arguments) >= 5L)
      as.numeric(strsplit(arguments[5], ",", fixed = TRUE)[[1]]) else NULL)
}
