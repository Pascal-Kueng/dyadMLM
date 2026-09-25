# Run from the repository root after the full family comparison has finished.
# The website needs summary tables, not individual simulated datasets.
study_directory <- "dev/diagnostic_checks/simulation-studies"
results_directory <- file.path(study_directory, "results/family-comparison/500-datasets-1000-draws")
report_directory <- file.path(study_directory, "report-data/family-comparison")
study_settings <- read.csv(file.path(results_directory, "settings.csv"))
study_summary <- read.csv(file.path(results_directory, "summary.csv"))
stopifnot(nrow(study_settings) == 22L, all(study_summary$attempted == 500L))

excluded_fit_counts <- lapply(study_settings$family, function(family_name) {
  read.csv(file.path(results_directory, family_name, "fits.csv")) |>
    dplyr::filter(status != "success") |>
    dplyr::count(family, status, name = "Datasets")
}) |> dplyr::bind_rows()

dir.create(report_directory, recursive = TRUE, showWarnings = FALSE)
file.copy(file.path(results_directory, c("settings.csv", "summary.csv", "calibration.csv")),
  report_directory, overwrite = TRUE)
write.csv(excluded_fit_counts, file.path(report_directory, "fit-exclusions.csv"), row.names = FALSE)
