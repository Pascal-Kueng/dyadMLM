# Run from the repository root, supplying the consequences results directory.
# Rereads the saved checkpoints without refitting. Writes the coverage change of
# the restricted model on datasets where both fits are usable.
summarise_paired_inference <- function(consequences_directory,
    report_directory = "dev/diagnostic_checks/simulation-studies/report-data/ild-partner-dependence-consequences") {
  condition_files <- list.files(consequences_directory,
    "^condition-[0-9]+-block-[0-9]+[.]rds$", full.names = TRUE)
  specification <- readRDS(file.path(consequences_directory, "run-specification.rds"))
  stopifnot(length(condition_files) == nrow(specification$conditions) *
    ceiling(specification$repetitions / 10))
  completed <- unlist(lapply(condition_files, readRDS), recursive = FALSE)
  fits <- dplyr::bind_rows(lapply(completed, `[[`, "fits"))
  inference <- dplyr::bind_rows(lapply(completed, `[[`, "inference"))
  keys <- c("condition", "repetition", "fit")
  stopifnot(nrow(fits) == 2L * nrow(specification$conditions) * specification$repetitions,
    !anyDuplicated(fits[keys]), !anyDuplicated(inference[c(keys, "parameter")]))
  defined <- inference |>
    dplyr::summarise(defined = dplyr::n() == 4L && all(defined), .by = dplyr::all_of(keys))
  paired <- fits |>
    dplyr::left_join(defined, by = keys) |>
    dplyr::summarise(paired = dplyr::n() == 2L && all(usable & defined),
      .by = c(condition, repetition)) |>
    dplyr::filter(paired)
  comparisons <- inference |>
    dplyr::inner_join(paired, by = c("condition", "repetition")) |>
    dplyr::select(condition, repetition, parameter, fit, covered) |>
    tidyr::pivot_wider(names_from = fit, values_from = covered) |>
    dplyr::mutate(change = as.integer(restricted) - as.integer(full)) |>
    dplyr::summarise(n = dplyr::n(), coverage_full = mean(full),
      coverage_restricted = mean(restricted), coverage_change = mean(change),
      coverage_change_mcse = stats::sd(change) / sqrt(n),
      .by = c(condition, parameter)) |>
    dplyr::arrange(condition, parameter)
  write.csv(comparisons, file.path(report_directory, "paired-inference.csv"), row.names = FALSE)
  invisible(comparisons)
}

if (sys.nframe() == 0L) {
  do.call(summarise_paired_inference, as.list(commandArgs(trailingOnly = TRUE)))
}
