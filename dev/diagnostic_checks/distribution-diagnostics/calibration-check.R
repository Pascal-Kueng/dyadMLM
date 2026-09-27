# Run from the package root with Rscript. This checks the working-tree code.
# Set OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 to avoid threading overhead.
# Optional: DYADMLM_CALIBRATION_REPS=100 DYADMLM_CALIBRATION_DRAWS=200.
# Set DYADMLM_CALIBRATION_OUTPUT to keep a pilot run separate from saved results.
# Crossing rates are illustrative, not proof of general calibration: at 5%,
# 100 repetitions have a Monte Carlo standard error of about 2.2 percentage points.
pkgload::load_all(quiet = TRUE)
repetitions <- as.integer(Sys.getenv("DYADMLM_CALIBRATION_REPS", "100"))
draws <- as.integer(Sys.getenv("DYADMLM_CALIBRATION_DRAWS", "200"))
stopifnot(repetitions > 0L, draws >= 200L)
output <- Sys.getenv("DYADMLM_CALIBRATION_OUTPUT",
                     "dev/diagnostic_checks/distribution-diagnostics/results/calibration")
dir.create(output, recursive = TRUE, showWarnings = FALSE)
writeLines("*", file.path(output, ".gitignore"))
writeLines(c(paste("Commit:", system("git rev-parse HEAD", intern = TRUE)),
             paste("Repetitions:", repetitions, "Draws:", draws),
             "100 dyads, two observations each; seeds = 93000 + repetition",
             "Fitted-reference simulation seeds = 94000 + repetition; PIT seeds = 95000 + repetition",
             "Gaussian: mean = 1 + 0.4*x, dyad SD = 0.6, residual SD = 1",
             "NB2: log(mean) = 0.7 + 0.3*x, dyad SD = 0.6, size = 3",
             "Gaussian omitted-role-mean: add -0.4 for A, +0.4 for B",
             "Gaussian role-variance: residual SD = 0.6 for A, 1.4 for B",
             "All fitted models omit role and use one residual variance/dispersion",
             "Gaussian role panels share a simulation bank with the pooled check"),
           file.path(output, "settings.txt"))
write.csv(tools::md5sum(list.files("R", "^predictive_checks", full.names = TRUE)),
          file.path(output, "source-hashes.csv"))

curve_crosses <- function(curve) {
  any(curve$observed < curve$lower | curve$observed > curve$upper, na.rm = TRUE)
}
scalar_crosses <- function(values) {
  limits <- dyadMLM:::simulated_rank_limits(values[-1])
  values[1] < limits[1] || values[1] > limits[2]
}
check_flags <- function(result, panel) {
  statistics <- result$compositions[[1]]$statistics[[panel]]
  pattern <- result$compositions[[1]]$patterns[[1]][[panel]]
  c(qq = curve_crosses(statistics$qq),
    histogram = curve_crosses(statistics$histogram),
    predictor_quantiles = any(vapply(pattern$quantiles, curve_crosses, logical(1))),
    predictor_distance = any(vapply(pattern$distance, curve_crosses, logical(1))),
    outliers = scalar_crosses(statistics$outliers),
    mean_distance = scalar_crosses(statistics$mean_distance))
}

records <- list()
for (family_name in c("gaussian", "nbinom2")) {
  count <- family_name == "nbinom2"
  designs <- if (count) "correct" else c("correct", "omitted_role_mean", "role_variance")
  for (design in designs) {
    for (iteration in seq_len(repetitions)) {
      set.seed(93000L + iteration)
      data <- data.frame(dyad = factor(rep(seq_len(100), each = 2)),
                         predictor = stats::rnorm(200),
                         role = factor(rep(c("A", "B"), 100)))
      linear_predictor <- if (count) 0.7 + 0.3 * data$predictor else
        1 + 0.4 * data$predictor
      if (design == "omitted_role_mean")
        linear_predictor <- linear_predictor + c(-0.4, 0.4)[data$role]
      residual_sd <- if (design == "role_variance") c(0.6, 1.4)[data$role] else 1
      generate <- function() {
        location <- linear_predictor + stats::rnorm(100, sd = 0.6)[data$dyad]
        if (count) stats::rnbinom(200, mu = exp(location), size = 3) else
          location + stats::rnorm(200, sd = residual_sd)
      }
      data$outcome <- generate()
      if (design == "correct") {
        known <- structure(list(
          observed_response = data$outcome,
          simulated_responses = t(replicate(draws, generate())),
          predicted_response = if (count) exp(linear_predictor) else linear_predictor,
          model_frame = data
        ), class = c("dyadMLM_response_simulations", "list"),
        dyadMLM = list(family = family_name, free_conditional_intercept = FALSE))
      }
      warnings <- character()
      fit_seconds <- system.time(fit <- withCallingHandlers(glmmTMB::glmmTMB(
        outcome ~ predictor + (1 | dyad), data = data,
        family = if (count) glmmTMB::nbinom2() else stats::gaussian()
      ), warning = function(warning) {
        warnings <<- c(warnings, conditionMessage(warning))
        invokeRestart("muffleWarning")
      }))[["elapsed"]]
      fitted <- simulate_dyad_responses(fit, nsim = draws, seed = 94000L + iteration)
      references <- if (design == "correct") c("known", "fitted") else "fitted"
      for (reference in references) {
        simulations <- if (reference == "known") known else fitted
        views <- if (count) "pooled" else c("pooled", "roles")
        for (view in views) {
          elapsed <- system.time(result <- do.call(check_dyad_residuals, list(
            simulations, dyad = "dyad", role = if (view == "roles") "role" else NULL,
            data = data, seed = 95000L + iteration, plot = FALSE
          )))[["elapsed"]]
          for (panel in names(result$compositions[[1]]$statistics)) {
            records[[length(records) + 1L]] <- data.frame(
              family = family_name, design = design, reference = reference,
              role = panel, repetition = iteration,
              centered = attr(result, "dyadMLM")$pit_centered,
              t(check_flags(result, panel)), elapsed = elapsed,
              fit_seconds = if (reference == "fitted") fit_seconds else 0,
              convergence = fit$fit$convergence, pdHess = fit$sdr$pdHess,
              warning = paste(unique(warnings), collapse = "; "), check.names = FALSE
            )
          }
        }
      }
      if (iteration %% 10L == 0L) {
        write.csv(do.call(rbind, records), file.path(output, "replications.csv"), row.names = FALSE)
        message(family_name, "/", design, ": ", iteration, "/", repetitions)
      }
    }
  }
}
records <- do.call(rbind, records)
capture.output(sessionInfo(), file = file.path(output, "session-info.txt"))
write.csv(records, file.path(output, "replications.csv"), row.names = FALSE)
metrics <- c("qq", "histogram", "predictor_quantiles", "predictor_distance",
             "outliers", "mean_distance")
groups <- c("family", "design", "reference", "role")
rates <- aggregate(records[metrics], records[groups], mean)
standard_errors <- rates
standard_errors[metrics] <- lapply(rates[metrics], function(rate)
  sqrt(rate * (1 - rate) / repetitions))
write.csv(rates, file.path(output, "crossing-rates.csv"), row.names = FALSE)
write.csv(standard_errors, file.path(output, "monte-carlo-se.csv"), row.names = FALSE)
capture.output({
  cat("Illustrative crossing rates; each curve panel is checked jointly.\n")
  cat("Coverage is not simultaneous across panels or roles.\n\n")
  print(rates, row.names = FALSE)
  cat("\nMonte Carlo standard errors:\n")
  print(standard_errors, row.names = FALSE)
  cat("\nFit convergence codes (one entry per fitted model):\n")
  fits <- unique(records[records$reference == "fitted",
                         c("family", "design", "repetition", "convergence", "pdHess")])
  print(with(fits, table(family, design, convergence, pdHess)))
  cat("\nWarnings:\n")
  print(unique(records$warning[nzchar(records$warning)]))
  cat("\nTiming in seconds (shared fit and check times repeat across roles):\n")
  print(aggregate(records[c("elapsed", "fit_seconds")],
                  records[groups], mean), row.names = FALSE)
}, file = file.path(output, "report.txt"))
print(rates, row.names = FALSE)
