# Recompute the flag unions of the main study, its add-on, and the confirmation run
# with only the panels the package shows: without the PIT histogram, the outlier
# count, and the PIT distance patterns. Run from the repository root. The optional
# arguments are the results directory of the main study and its add-on, and that of
# the confirmation run (by default the same). The output has the format of the
# summary tables, so the report can replace their union rows ("any", or in the
# confirmation run "core" and "pages").
study_directory <- "dev/diagnostic_checks/simulation-studies"
source(file.path(study_directory, "distribution-checks/helpers.R"))
source(file.path(study_directory, "distribution-checks/summarise.R"))
arguments <- commandArgs(trailingOnly = TRUE)
results_directory <- if (length(arguments)) arguments[1] else file.path(study_directory, "results")
confirmation_directory <- if (length(arguments) > 1) arguments[2] else results_directory
report_directory <- file.path(study_directory, "report-data/distribution-checks")

runs <- c(main = file.path(results_directory, "distribution-checks/500-datasets-1000-draws"),
  `add-on` = file.path(results_directory,
                       "distribution-checks-consequences/500-datasets-1000-draws"),
  confirmation = file.path(confirmation_directory,
                           "distribution-checks/confirmation-500-datasets-1000-draws"))
reported_files <- c(main = "summary.csv", `add-on` = "severe-summary.csv",
                    confirmation = "confirmation-summary.csv")
union_names <- c("any", "core", "pages")
removed <- function(statistic) statistic %in% c("histogram", "outliers") |
  (endsWith(statistic, "_distance") & statistic != "mean_distance")
# distribution_any() of two flags, elementwise
either <- function(x, y) ifelse(is.na(x) & is.na(y), NA, x %in% TRUE | y %in% TRUE)

# Unions per dataset as in the study: within each role, across roles ("All"), and
# across both checks, pairing each residual reference with its outcome reference.
dataset_unions <- function(statistics, run, current) {
  panels <- dplyr::filter(statistics, role != "All", check != "both",
                          !statistic %in% union_names, !startsWith(statistic, "category"))
  if (current) panels <- panels[!removed(panels$statistic), ]
  panels <- if (run == "confirmation") dplyr::bind_rows(
    dplyr::mutate(panels[!grepl("^(actor|partner)_", panels$statistic), ], statistic = "core"),
    dplyr::mutate(panels, statistic = "pages")) else dplyr::mutate(panels, statistic = "any")
  any_flag <- function(data, ...) data |> dplyr::group_by(...) |>
    dplyr::summarise(dplyr::across(c(below, above, flagged), distribution_any), .groups = "drop")
  per_role <- any_flag(panels, condition, repetition, reference, view, role, check, statistic)
  roles <- dplyr::bind_rows(per_role, dplyr::mutate(any_flag(per_role, condition, repetition,
    reference, view, check, statistic), role = "All"))
  residual <- dplyr::filter(roles, check == "residual")
  outcome <- dplyr::filter(roles, check == "outcome") |>
    dplyr::rename(outcome_reference = reference)
  both <- residual |>
    dplyr::mutate(outcome_reference = ifelse(reference == "known", "known", "fitted")) |>
    dplyr::inner_join(outcome, by = c("condition", "repetition", "outcome_reference", "view",
                                      "role", "statistic"), suffix = c("", "_outcome")) |>
    dplyr::mutate(below = either(below, below_outcome), above = either(above, above_outcome),
                  flagged = either(flagged, flagged_outcome), check = "both") |>
    dplyr::select(dplyr::all_of(names(roles)))
  dplyr::bind_rows(roles, both)
}

tables <- lapply(names(runs), function(run) {
  completed <- unlist(lapply(list.files(runs[[run]], "^condition-[0-9]+[.]rds$",
                                        full.names = TRUE), readRDS), recursive = FALSE)
  fits <- dplyr::bind_rows(lapply(completed, `[[`, "fits"))
  statistics <- dplyr::bind_rows(lapply(completed, `[[`, "statistics"))
  reported <- utils::read.csv(file.path(report_directory, reported_files[[run]]))
  conditions <- dplyr::distinct(reported[seq_len(match("reference", names(reported)) - 1)])
  fits <- dplyr::filter(fits, condition %in% conditions$condition)
  summarise_unions <- function(current) summarise_distribution_study(conditions, fits,
    dataset_unions(statistics, run, current))$summary
  # With all panels, the unions must reproduce the reported ones.
  all_panels <- summarise_unions(FALSE)
  comparison <- dplyr::inner_join(all_panels, reported,
    by = c("condition", "reference", "view", "role", "check", "statistic"))
  stopifnot(nrow(comparison) == nrow(all_panels),
            nrow(comparison) == sum(reported$statistic %in% union_names),
            comparison$checked.x == comparison$checked.y,
            comparison$flagged.x == comparison$flagged.y)
  dplyr::mutate(summarise_unions(TRUE), run = run, .before = 1)
})
utils::write.csv(dplyr::bind_rows(tables), file.path(report_directory, "flag-unions.csv"),
                 row.names = FALSE)
