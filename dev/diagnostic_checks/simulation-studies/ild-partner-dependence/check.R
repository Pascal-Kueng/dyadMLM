# Run from the repository root, with numerical libraries limited to one thread.
source("dev/diagnostic_checks/simulation-studies/ild-partner-dependence/run.R")

# Compare reconstructed rank flags with strict comparisons to order statistics,
# including ties at both boundaries and a completely constant reference.
for (reference in list(rep(1, 500), rep(0:4, 100), seq_len(40), seq_len(1000))) {
  tail_count <- floor(0.05 * (length(reference) + 1) / 2)
  limits <- sort(reference)[c(tail_count, length(reference) - tail_count + 1)]
  for (observed in c(min(reference) - 1, limits, median(reference), max(reference) + 1)) {
    flags <- add_flags(tibble::tibble(observed, lower = limits[1], upper = limits[2],
      n_defined = length(reference), n_below = sum(reference < observed),
      n_above = sum(reference > observed)))
    rank_flags <- dplyr::filter(flags, rule == "rank")
    stopifnot(rank_flags$below == (observed < limits[1]),
              rank_flags$above == (observed > limits[2]))
  }
}

# Undefined simulated values must be excluded from both ranks and limits.
reference <- as.data.frame(matrix(rep(c(2, -Inf, Inf, NA, 1, 3), 6), ncol = 6))
reference <- cbind(dataset = seq_len(nrow(reference)), reference)
check <- list(compositions = tibble::tibble(n_pairs = 4L, level = "between",
  statistics = list(reference)))
record <- record_occasion_check(check)
stopifnot(all(record$n_defined == 2L), all(record$n_below == 1L),
  all(record$n_above == 1L), all(abs(record$lower - 1.05) < 1e-12),
  all(abs(record$upper - 2.95) < 1e-12))

# Independent Gaussian moment formulas validate the stable/occasion split,
# including zero covariance and the stationary AR component.
moment_cells <- study_cells |>
  dplyr::filter(part %in% c("gaussian", "ar"), n_dyads == 50L, missing_share == 0)
moment_results <- lapply(seq_len(nrow(moment_cells)), function(index) {
  cell <- moment_cells[index, ]
  truth <- cell_truth(cell)
  cell$n_dyads <- 30000L
  data <- generate_occasion_data(cell, 710000000L + cell$cell) |>
    dplyr::mutate(residual = outcome - true_fixed_mean,
      member_mean = mean(residual), .by = person) |>
    dplyr::mutate(deviation = residual - member_mean) |>
    tidyr::pivot_wider(id_cols = c(dyad, occasion), names_from = gender,
      values_from = c(member_mean, deviation))
  between <- data[!duplicated(data$dyad), ]
  observed <- c(var(between$member_mean_female), var(between$member_mean_male),
    cov(between$member_mean_female, between$member_mean_male),
    var(data$deviation_female), var(data$deviation_male),
    cov(data$deviation_female, data$deviation_male))
  occasions <- cell$n_occasions
  ar_variance <- if (cell$part == "ar") truth$ar_sd^2 else 0
  ar_mean_variance <- ar_variance / occasions^2 * (occasions +
    2 * sum((occasions - seq_len(occasions - 1)) * cell$ar_phi^seq_len(occasions - 1)))
  occasion_covariance <- prod(truth$occasion_sds) * truth$occasion_cor
  expected <- c(truth$stable_sds^2 + truth$occasion_sds^2 / occasions + ar_mean_variance,
    prod(truth$stable_sds) * truth$stable_cor + occasion_covariance / occasions,
    (1 - 1 / occasions) * truth$occasion_sds^2 + ar_variance - ar_mean_variance,
    (1 - 1 / occasions) * occasion_covariance)
  stopifnot(max(abs(observed - expected)) < 0.04)
  data.frame(cell = cell$cell, moment = c("between_var_female", "between_var_male",
    "between_covariance", "within_var_female", "within_var_male", "within_covariance"),
    observed, expected)
})

# The same dataset seeds must give identical numerical results in serial and
# parallel runs. Timings are deliberately excluded from the comparison.
reproduction_cells <- study_cells |>
  dplyr::filter(n_dyads == 50L, truth_case == "correlated", missing_share == 0,
    (part == "gaussian" & n_occasions == 3L) | (part == "ordinal" & n_occasions == 5L))
tasks <- tidyr::crossing(cell = reproduction_cells$cell, repetition = 1:2)
run_task <- function(index) run_occasion_dataset(study_cells[tasks$cell[index], ],
  tasks$repetition[index], reference_draws = 100L)
serial <- lapply(seq_len(nrow(tasks)), run_task)
parallel_results <- parallel::mclapply(seq_len(nrow(tasks)), run_task,
  mc.cores = if (.Platform$OS.type == "windows") 1L else 2L, mc.set.seed = FALSE)
without_timings <- function(results) lapply(results, function(result) {
  result$fits <- dplyr::select(result$fits, -fit_seconds, -check_seconds)
  result
})
stopifnot(identical(without_timings(serial), without_timings(parallel_results)))
fits <- dplyr::bind_rows(lapply(serial, `[[`, "fits"))
stopifnot(all(fits$error == ""), all(fits$check_error == ""))

output_directory <- file.path(study_directory, "results/ild-partner-dependence/implementation-checks")
dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)
write.csv(dplyr::bind_rows(moment_results), file.path(output_directory, "moments.csv"), row.names = FALSE)
writeLines(c("Rank boundaries and ties: passed", "Gaussian and AR moments: passed",
  "Serial versus parallel numerical results: identical"), file.path(output_directory, "checks.txt"))
message("Implementation checks passed.")
