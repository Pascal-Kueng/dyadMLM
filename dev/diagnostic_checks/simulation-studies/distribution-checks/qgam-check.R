# Add DHARMa's quantile lines ("qgam", variant C: qgam on the rank axis of B, as
# in DHARMa::testQuantiles with rank = TRUE) to the comparison of
# ranked-axis-check.R, in fewer conditions with fewer draws. Condition numbers,
# and hence datasets, match ranked-axis-check.R. Also records, per quartile
# panel, the mean absolute difference between each smoother's observed lines
# and those of "qgam", over the panel's observations, and each dataset's status,
# warnings and error (fits.csv). Run from the repository root. Arguments:
# datasets, reference draws, workers, run/summarise, and optional
# comma-separated condition numbers.
source("dev/diagnostic_checks/simulation-studies/distribution-checks/ranked-axis-check.R")

smoothers <- c("current", "kernel", "qgam")

# With 400 dyads: Gaussian correct, curvature, end shift. With 100 dyads:
# Gaussian correct, NB2 correct, omitted partner, heteroscedastic, curvature,
# end shift.
qgam_conditions <- function() dplyr::filter(ranked_conditions(), condition %in% c(1, 5:8, 10, 11, 13, 14))

# Rows match record_ranked_residuals(): qq, mean distance, then the quartile
# panels of the predicted outcome, actor and partner, in each role.
qgam_differences <- function(result, reference, values) {
  composition <- result$compositions[[1]]
  rows <- unlist(composition$rows)
  unlist(lapply(names(composition$rows), function(role) c(NA, NA, vapply(seq_along(values), function(page) {
    # Ranked lines lie on ranks shared by all roles, as in calculate_residual_pattern().
    ranks <- values[[page]]
    ranks[rows] <- (rank(ranks[rows]) - .5) / length(rows)
    at <- composition$rows[[role]]
    lines <- function(pattern) sapply(pattern$quantiles, function(quartile) stats::approx(
      pattern$positions, quartile$observed, if (pattern$ranked) ranks[at] else values[[page]][at],
      rule = 2)$y)
    mean(abs(lines(composition$patterns[[page]][[role]]) -
             lines(reference$compositions[[1]]$patterns[[page]][[role]])))
  }, numeric(1)))))
}

# As in ranked-axis-check.R, adding the differences from "qgam".
evaluate_ranked_checks <- function(simulations, data, pit_seed) {
  seconds <- stats::setNames(numeric(4), c(smoothers, "outcome"))
  predictors <- c("actor_predictor", "partner_predictor")
  values <- c(list(simulations$predicted_response), as.list(data[predictors]))
  rows <- dplyr::bind_rows(lapply(c("pooled", "roles"), function(view) {
    arguments <- list(simulations, dyad = "dyad", role = if (view == "roles") "role",
                      data = data, plot = FALSE)
    results <- lapply(stats::setNames(nm = smoothers), function(smoother) {
      seconds[smoother] <<- seconds[smoother] + system.time(result <- withr::with_options(
        list(dyadMLM.residual_smoother = smoother), do.call(check_dyad_residuals, c(arguments,
          list(predictors = predictors, seed = pit_seed)))), gcFirst = FALSE)[["elapsed"]]
      result
    })
    residuals <- dplyr::bind_rows(lapply(smoothers, function(name)
      dplyr::mutate(record_ranked_residuals(results[[name]]), smoother = name,
        qgam_difference = qgam_differences(results[[name]], results$qgam, values))))
    seconds["outcome"] <<- seconds["outcome"] + system.time(
      outcomes <- do.call(check_dyad_outcomes, arguments), gcFirst = FALSE)[["elapsed"]]
    dplyr::bind_rows(residuals, record_confirmation_outcomes(outcomes)) |>
      dplyr::mutate(view)
  }))
  list(rows = rows, seconds = seconds)
}

# As run_ranked_axis_check(), with these conditions, the differences table and
# its own output directory.
run_qgam_check <- function(repetitions = 100L, reference_draws = 200L, workers = 8L,
                           mode = "run", selected = NULL) {
  stopifnot(repetitions >= 1L, reference_draws >= 200L, workers >= 1L, workers <= 10L,
            mode %in% c("run", "summarise"))
  conditions <- qgam_conditions() |>
    dplyr::mutate(repetitions = as.integer(repetitions), reference_draws = as.integer(reference_draws))
  if (is.null(selected)) selected <- conditions$condition
  stopifnot(length(selected) > 0L, all(selected %in% conditions$condition), !anyDuplicated(selected))
  output_directory <- file.path(study_directory, "results/distribution-checks",
    paste0("qgam-", repetitions, "-datasets-", reference_draws, "-draws"))
  dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)
  if (mode == "run") {
    source_files <- c(sort(list.files("R", "[.]R$", full.names = TRUE)),
      file.path(study_directory, "distribution-checks",
                c("helpers.R", "confirmation.R", "ranked-axis-check.R", "qgam-check.R")))
    fingerprint <- list(conditions = conditions, sources = vapply(source_files, function(file)
      rlang::hash(grep("^#'", readLines(file), value = TRUE, invert = TRUE)), character(1)),
      versions = vapply(c("glmmTMB", "TMB", "qgam", "mgcv"), function(package)
        as.character(utils::packageVersion(package)), character(1)),
      R = as.character(getRversion()))
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
  statistics <- dplyr::bind_rows(lapply(completed, `[[`, "statistics"))
  summaries <- summarise_ranked_axis_check(conditions[conditions$condition %in% fits$condition, ],
                                           fits, statistics)
  summaries$differences <- statistics |>
    dplyr::filter(!is.na(qgam_difference), smoother != "qgam") |>
    dplyr::group_by(condition, smoother, view, role, statistic) |>
    dplyr::summarise(datasets = dplyr::n(), mean = mean(qgam_difference),
      median = stats::median(qgam_difference), p90 = stats::quantile(qgam_difference, .9),
      .groups = "drop") |>
    dplyr::left_join(dplyr::select(conditions, condition, scenario_label, n_dyads), by = "condition")
  # Status, warnings and error of each dataset.
  summaries$fits <- fits
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
  run_qgam_check(
    repetitions = if (length(arguments) >= 1L) as.numeric(arguments[1]) else 100L,
    reference_draws = if (length(arguments) >= 2L) as.numeric(arguments[2]) else 200L,
    workers = if (length(arguments) >= 3L) as.numeric(arguments[3]) else 8L,
    mode = if (length(arguments) >= 4L) arguments[4] else "run",
    selected = if (length(arguments) >= 5L)
      as.numeric(strsplit(arguments[5], ",", fixed = TRUE)[[1]]) else NULL)
}
