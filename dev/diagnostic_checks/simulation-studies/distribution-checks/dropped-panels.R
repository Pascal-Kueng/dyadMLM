# How often did the finished main study and its add-on flag datasets without the
# PIT histogram and outlier count, which the package no longer shows? Run from the
# repository root. The optional argument is the results directory of both runs.
# Flags use the default references (centred residuals, fitted outcomes);
# category ranges are excluded, as in the study's unions.
study_directory <- "dev/diagnostic_checks/simulation-studies"
source(file.path(study_directory, "distribution-checks/helpers.R"))
arguments <- commandArgs(trailingOnly = TRUE)
results_directory <- if (length(arguments)) arguments[1] else file.path(study_directory, "results")
report_directory <- file.path(study_directory, "report-data/distribution-checks")

# Unions across panels and roles, per dataset, view, and check.
dataset_unions <- function(checkpoint) {
  panels <- dplyr::bind_rows(lapply(readRDS(checkpoint), `[[`, "statistics"))
  if (!nrow(panels)) return(NULL)
  panels <- dplyr::filter(panels, role != "All", statistic != "any",
    !startsWith(statistic, "category"), (check == "residual" & reference == "fitted-centred") |
      (check == "outcome" & reference == "fitted"))
  panels <- dplyr::bind_rows(dplyr::mutate(panels, panel_set = "all"),
    dplyr::mutate(dplyr::filter(panels, !statistic %in% c("histogram", "outliers")),
                  panel_set = "without histogram and outliers"))
  dplyr::bind_rows(dplyr::filter(panels, check == "residual"), dplyr::mutate(panels, check = "both")) |>
    dplyr::group_by(condition, repetition, view, check, panel_set) |>
    dplyr::summarise(flagged = distribution_any(flagged), .groups = "drop")
}

checkpoints <- list.files(file.path(results_directory, c("distribution-checks",
  "distribution-checks-consequences"), "500-datasets-1000-draws"),
  "^condition-[0-9]+[.]rds$", full.names = TRUE)
z <- stats::qnorm(.975)
rates <- dplyr::bind_rows(lapply(checkpoints, dataset_unions)) |>
  dplyr::group_by(condition, view, check, panel_set) |>
  dplyr::summarise(checked = sum(!is.na(flagged)), flagged = sum(flagged, na.rm = TRUE),
                   .groups = "drop") |>
  # 95% Wilson interval
  dplyr::mutate(rate = flagged / checked,
    rate_lower = (flagged + z^2 / 2 - z * sqrt(flagged * (checked - flagged) / checked + z^2 / 4)) /
      (checked + z^2),
    rate_upper = (flagged + z^2 / 2 + z * sqrt(flagged * (checked - flagged) / checked + z^2 / 4)) /
      (checked + z^2))

# With all panels, the unions must reproduce the reported "any" rates.
reported <- dplyr::bind_rows(lapply(c("summary.csv", "severe-summary.csv"), function(file)
  utils::read.csv(file.path(report_directory, file)))) |>
  dplyr::filter(reference == "fitted-centred", statistic == "any", role == "All",
                check %in% c("residual", "both"))
comparison <- dplyr::inner_join(rates[rates$panel_set == "all", ], reported,
                                by = c("condition", "view", "check"), suffix = c("", "_reported"))
stopifnot(nrow(comparison) == nrow(reported), nrow(comparison) == sum(rates$panel_set == "all"),
  comparison$checked == comparison$checked_reported, comparison$flagged == comparison$flagged_reported)

rates <- dplyr::distinct(reported, condition, family, scenario, scenario_label, fit_family,
                         n_dyads, n_times, dyad_sd) |>
  dplyr::right_join(rates, by = "condition") |>
  dplyr::arrange(condition)
utils::write.csv(rates, file.path(report_directory, "dropped-panels.csv"), row.names = FALSE)
