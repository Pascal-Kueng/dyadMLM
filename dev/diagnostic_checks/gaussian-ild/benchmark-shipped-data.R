# Reproducible end-to-end benchmark for the Gaussian ILD prototype.

script_argument <- commandArgs(trailingOnly = FALSE)
script_argument <- script_argument[grepl("^--file=", script_argument)]
if (length(script_argument) != 1L) {
  stop("Run this file with Rscript.", call. = FALSE)
}
script_file <- sub("^--file=", "", script_argument)
script_directory <- dirname(normalizePath(script_file))
package_root <- normalizePath(
  file.path(script_directory, "..", "..", "..")
)

devtools::load_all(package_root, quiet = TRUE)
data(dyads_ild, package = "dyadMLM")
benchmark_data <- as.data.frame(dyads_ild)

# The shipped data contain three compositions. Keep only dyads with both
# observed role values, which is the female-male composition in this dataset.
dyad_roles <- unique(benchmark_data[c("coupleID", "gender")])
n_roles <- table(dyad_roles$coupleID)
selected_dyads <- as.integer(names(n_roles[n_roles == 2L]))
benchmark_data <- benchmark_data[
  benchmark_data$coupleID %in% selected_dyads,
]
benchmark_data$time_f <- factor(
  benchmark_data$diaryday,
  levels = 0:13
)
benchmark_data$series <- interaction(
  benchmark_data$coupleID,
  benchmark_data$personID,
  drop = TRUE
)

fit_time <- system.time({
  benchmark_model <- glmmTMB::glmmTMB(
    closeness ~
      gender +
      (1 | coupleID) +
      ar1(0 + time_f | series),
    family = stats::gaussian(),
    data = benchmark_data
  )
})
simulation_time <- system.time({
  benchmark_simulations <- simulate_dyad_responses(
    benchmark_model,
    nsim = 199,
    seed = 20260827
  )
})
check_time <- system.time({
  benchmark_check <- check_partner_dependence(
    benchmark_simulations,
    dyad = benchmark_data$coupleID,
    role = benchmark_data$gender,
    member = benchmark_data$personID,
    time = benchmark_data$time_f,
    lags = 1:5,
    weighting = "dyad",
    plot = FALSE
  )
})

benchmark_result <- data.frame(
  fitted_rows = nrow(benchmark_data),
  dyads = length(unique(benchmark_data$coupleID)),
  simulations = benchmark_simulations$nsim,
  statistics = nrow(benchmark_check$statistics_table),
  defined_observed = sum(
    is.finite(benchmark_check$statistics_table$observed_value)
  ),
  defined_references = sum(
    is.finite(benchmark_check$statistics_table$replicated_median)
  ),
  fit_seconds = unname(fit_time[["elapsed"]]),
  simulation_seconds = unname(simulation_time[["elapsed"]]),
  check_seconds = unname(check_time[["elapsed"]])
)

stopifnot(
  benchmark_model$fit$convergence == 0L,
  isTRUE(benchmark_model$sdr$pdHess),
  benchmark_result$defined_observed == benchmark_result$statistics,
  benchmark_result$defined_references == benchmark_result$statistics
)

print(benchmark_result, row.names = FALSE)
