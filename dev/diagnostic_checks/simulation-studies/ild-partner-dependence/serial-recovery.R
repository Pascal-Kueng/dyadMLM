# Run from the repository root, supplying the main results directory. Rereads the
# saved checkpoints without refitting. Writes the stable-correlation estimates of
# the model without AR when the data have serial dependence (phi = 0.7).
summarise_serial_recovery <- function(main_directory,
    report_directory = "dev/diagnostic_checks/simulation-studies/report-data/ild-partner-dependence") {
  cells <- read.csv(file.path(main_directory, "cells.csv")) |>
    dplyr::filter(part == "ar", ar_phi == 0.7)
  cell_files <- list.files(main_directory, "^cell-[0-9]+-block-[0-9]+[.]rds$", full.names = TRUE)
  cell_files <- cell_files[as.integer(sub("cell-([0-9]+)-.*", "\\1", basename(cell_files))) %in% cells$cell]
  stopifnot(length(cell_files) == sum(ceiling(cells$repetitions / 10)))
  completed <- unlist(lapply(cell_files, readRDS), recursive = FALSE)
  keys <- c("cell", "repetition", "model")
  usable_fits <- dplyr::bind_rows(lapply(completed, `[[`, "fits")) |>
    dplyr::filter(model == "no_ar", usable) |>
    dplyr::select(dplyr::all_of(keys))
  estimates <- dplyr::bind_rows(lapply(completed, `[[`, "estimates")) |>
    dplyr::filter(model == "no_ar", parameter == "block1_cor")
  stopifnot(!anyDuplicated(usable_fits), !anyDuplicated(estimates[keys]))
  specification <- readRDS(file.path(main_directory, "run-specification.rds"))
  serial_recovery <- estimates |>
    dplyr::inner_join(usable_fits, by = keys) |>
    dplyr::summarise(n = dplyr::n(), mean = mean(estimate),
      mcse = stats::sd(estimate) / sqrt(n), .by = c(cell, model, parameter)) |>
    dplyr::mutate(true_value = specification$parameters$ar$stable_cor) |>
    dplyr::arrange(cell)
  write.csv(serial_recovery, file.path(report_directory, "serial-recovery.csv"), row.names = FALSE)
  invisible(serial_recovery)
}

if (sys.nframe() == 0L) {
  do.call(summarise_serial_recovery, as.list(commandArgs(trailingOnly = TRUE)))
}
