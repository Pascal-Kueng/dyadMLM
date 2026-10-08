# How often did the finished main study, its add-on, and the confirmation run flag
# datasets without panels the package no longer shows: first the PIT histogram and
# outlier count, then also the PIT distance patterns ("current")? Run from the
# repository root. The optional arguments are the results directory of the main
# study and its add-on, and that of the confirmation run (by default the same).
# Flags use the default references (centred residuals, fitted outcomes);
# category ranges are excluded, as in the study's unions.
study_directory <- "dev/diagnostic_checks/simulation-studies"
source(file.path(study_directory, "distribution-checks/helpers.R"))
arguments <- commandArgs(trailingOnly = TRUE)
results_directory <- if (length(arguments)) arguments[1] else file.path(study_directory, "results")
confirmation_directory <- if (length(arguments) > 1) arguments[2] else results_directory
report_directory <- file.path(study_directory, "report-data/distribution-checks")

# Unions across panels and roles, per dataset, view, check, and panel set. The add-on
# shows predictor pages by role; the confirmation run in both views, so its unions
# are formed with and without them.
dataset_unions <- function(checkpoint, run) {
  panels <- dplyr::bind_rows(lapply(readRDS(checkpoint), `[[`, "statistics"))
  if (!nrow(panels)) return(NULL)
  # The confirmation run records only the default reference, as "fitted".
  panels <- dplyr::filter(panels, role != "All", !statistic %in% c("any", "core", "pages"),
    !startsWith(statistic, "category"), reference %in% c("fitted-centred", "fitted")) |>
    dplyr::mutate(run = run, pages = run != "main")
  if (run == "confirmation") panels <- dplyr::bind_rows(panels, dplyr::mutate(
    dplyr::filter(panels, !grepl("^(actor|partner)_", statistic)), pages = FALSE))
  shown <- !panels$statistic %in% c("histogram", "outliers")
  # PIT distance patterns, across predicted outcomes and on predictor pages
  distance <- endsWith(panels$statistic, "_distance") & panels$statistic != "mean_distance"
  panels <- dplyr::bind_rows(dplyr::mutate(panels, panel_set = "all"),
    dplyr::mutate(panels[shown, ], panel_set = "without histogram and outliers"),
    dplyr::mutate(panels[shown & !distance, ], panel_set = "current"))
  dplyr::bind_rows(dplyr::filter(panels, check == "residual"), dplyr::mutate(panels, check = "both")) |>
    dplyr::group_by(run, condition, repetition, view, pages, check, panel_set) |>
    dplyr::summarise(flagged = distribution_any(flagged), .groups = "drop")
}

runs <- c(main = file.path(results_directory, "distribution-checks/500-datasets-1000-draws"),
  `add-on` = file.path(results_directory,
                       "distribution-checks-consequences/500-datasets-1000-draws"),
  confirmation = file.path(confirmation_directory,
                           "distribution-checks/confirmation-500-datasets-1000-draws"))
checkpoints <- lapply(runs, list.files, "^condition-[0-9]+[.]rds$", full.names = TRUE)
z <- stats::qnorm(.975)
rates <- dplyr::bind_rows(Map(dataset_unions, unlist(checkpoints),
                              rep(names(runs), lengths(checkpoints)))) |>
  dplyr::group_by(run, condition, view, pages, check, panel_set) |>
  dplyr::summarise(checked = sum(!is.na(flagged)), flagged = sum(flagged, na.rm = TRUE),
                   .groups = "drop") |>
  # 95% Wilson interval
  dplyr::mutate(rate = flagged / checked,
    rate_lower = (flagged + z^2 / 2 - z * sqrt(flagged * (checked - flagged) / checked + z^2 / 4)) /
      (checked + z^2),
    rate_upper = (flagged + z^2 / 2 + z * sqrt(flagged * (checked - flagged) / checked + z^2 / 4)) /
      (checked + z^2))

# With all panels, the unions must reproduce the reported rates: "any", or in the
# confirmation run "core" (without predictor pages) and "pages".
reported <- dplyr::bind_rows(lapply(c(main = "summary.csv", `add-on` = "severe-summary.csv",
    confirmation = "confirmation-summary.csv"), function(file)
  utils::read.csv(file.path(report_directory, file))), .id = "run") |>
  dplyr::filter(reference %in% c("fitted-centred", "fitted"), role == "All",
                statistic %in% c("any", "core", "pages"), check %in% c("residual", "both")) |>
  dplyr::mutate(pages = run == "add-on" | statistic == "pages")
comparison <- dplyr::inner_join(rates[rates$panel_set == "all", ], reported,
  by = c("run", "condition", "view", "pages", "check"), suffix = c("", "_reported"))
stopifnot(nrow(comparison) == nrow(reported), nrow(comparison) == sum(rates$panel_set == "all"),
  comparison$checked == comparison$checked_reported, comparison$flagged == comparison$flagged_reported)

rates <- dplyr::distinct(reported, run, condition, family, scenario, scenario_label, fit_family,
                         n_dyads, n_times, dyad_sd) |>
  dplyr::right_join(rates, by = c("run", "condition")) |>
  dplyr::arrange(match(run, names(runs)), condition)
utils::write.csv(rates, file.path(report_directory, "dropped-panels.csv"), row.names = FALSE)
