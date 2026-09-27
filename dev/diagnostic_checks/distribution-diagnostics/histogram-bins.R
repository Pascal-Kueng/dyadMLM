# Run from the package folder, with one R process and one BLAS/OpenMP thread.
# Four paired examples, not a calibration or power study. Every comparison
# shares the same simulated responses, randomized PIT and ERL envelope method.
pkgload::load_all(quiet = TRUE)
base <- "dev/diagnostic_checks/distribution-diagnostics"
output <- file.path(base, "results/histogram-bins")
dir.create(output, recursive = TRUE, showWarnings = FALSE)
envelope <- getFromNamespace("residual_curve_summary", "dyadMLM")
summary_rows <- bin_rows <- fit_rows <- list()
examples <- c("nbinom2-gaussian", "tweedie-gaussian", "gaussian-correct", "nbinom1-correct")
for (example in examples) {
  warnings <- character()
  withCallingHandlers({
    nsim <- if (example == "tweedie-gaussian") 2000L else 1000L
    simulation_seed <- if (example == "tweedie-gaussian") 100105L else 123L
    data_seed <- NA_integer_
    if (example %in% examples[1:2]) {
      model_data <- read.csv(file.path(base, "results", example, "data.csv"),
                             colClasses = c(role = "factor"))
      model_data$dyad <- factor(model_data$dyad)
    } else {
      data_seed <- if (example == "gaussian-correct") 20260928L else 20260929L
      set.seed(data_seed)
      model_data <- data.frame(dyad = factor(rep(seq_len(100), each = 2)),
                               role = factor(rep(c("A", "B"), 100)), predictor = rnorm(200))
      shared <- rnorm(100, sd = .6)[as.integer(model_data$dyad)]
      if (example == "gaussian-correct") {
        model_data$outcome <- 1 + .4 * model_data$predictor + shared + rnorm(200)
      } else {
        mu <- exp(.7 + .3 * model_data$predictor + shared)
        model_data$outcome <- rnbinom(200, mu = mu, size = mu) # NB1 dispersion = 1.
      }
    }
    formula <- if (example == "nbinom2-gaussian") outcome ~ role + support else
      outcome ~ predictor + (1 | dyad)
    family <- if (example == "nbinom1-correct") glmmTMB::nbinom1() else gaussian()
    model <- glmmTMB::glmmTMB(formula, family = family, dispformula = ~1, data = model_data)
    simulations <- simulate_dyad_responses(model, nsim = nsim, seed = simulation_seed)
    predictor <- if (example == "nbinom2-gaussian") "support" else "predictor"
    result <- check_dyad_residuals(simulations, dyad = dyad, role = role, data = model_data,
                                   predictors = predictor, seed = 123, plot = FALSE)
    stopifnot(length(result$compositions) == 1L)
    composition <- result$compositions[[1]]
    comparison <- list()
    for (role in names(composition$rows)) {
      rows <- composition$rows[[role]]
      pit <- result$pit[rows, , drop = FALSE]
      densities <- lapply(c(20L, 10L), function(bins) apply(pit, 2, function(values)
        hist(values, breaks = seq(0, 1, length.out = bins + 1L), plot = FALSE)$density))
      stopifnot(isTRUE(all.equal(densities[[2]],
        (densities[[1]][seq(1, 19, 2), ] + densities[[1]][seq(2, 20, 2), ]) / 2,
        tolerance = 1e-12, check.attributes = FALSE)))
      comparison[[role]] <- list()
      for (k in seq_along(densities)) {
        bins <- c(20L, 10L)[k]
        values <- densities[[k]]
        curve <- envelope(values)
        if (bins == 10L) stopifnot(identical(composition$statistics[[role]]$histogram, curve))
        outside <- values < curve$lower | values > curve$upper
        bank_fraction <- mean(colSums(outside) > 0L)
        stopifnot(max(abs(colSums(values) / bins - 1)) < 1e-12,
                  bank_fraction <= .05)
        comparison[[role]][[k]] <- curve
        summary_rows[[length(summary_rows) + 1L]] <- data.frame(
          example, role, bins, n = length(rows), nsim,
          centered = attr(result, "dyadMLM")$pit_centered,
          lower_min = min(curve$lower), lower_max = max(curve$lower),
          upper_min = min(curve$upper), upper_max = max(curve$upper),
          mean_width = mean(curve$upper - curve$lower),
          observed_zero_bins = sum(curve$observed == 0), bins_lower_above_zero = sum(curve$lower > 0),
          crossing_bins = sum(outside[, 1]), observed_crosses = any(outside[, 1]),
          envelope_bank_fraction = bank_fraction)
        bin_rows[[length(bin_rows) + 1L]] <- data.frame(example, role, bins,
          midpoint = (seq_len(bins) - .5) / bins, observed = curve$observed,
          lower = curve$lower, upper = curve$upper)
      }
    }
    png(file.path(output, paste0(example, ".png")), width = 1100, height = 800, res = 110)
    par(mfrow = c(length(comparison), 2), mar = c(4, 4, 3, 1), oma = c(0, 0, 2, 0))
    for (role in names(comparison)) {
      limits <- c(0, max(1, unlist(comparison[[role]])))
      for (k in 1:2) {
        bins <- c(20L, 10L)[k]
        curve <- comparison[[role]][[k]]
        breaks <- seq(0, 1, length.out = bins + 1L)
        plot(NA, xlim = c(0, 1), ylim = limits, xaxs = "i", yaxs = "i",
          xlab = "PIT", ylab = "Density", main = paste(role, "-", bins, "bins"))
        rect(head(breaks, -1), curve$lower, tail(breaks, -1), curve$upper,
             col = "#bcd7e8", border = "#7fa7be")
        segments(head(breaks, -1), curve$observed, tail(breaks, -1), curve$observed,
                 col = "#a12b35", lwd = 2)
        abline(h = 1, lty = 2, col = "grey40")
      }
    }
    mtext(paste(example, "| red: observed; blue: 95% global envelope"), outer = TRUE)
    dev.off()
  }, warning = function(w) {
    warnings <<- c(warnings, conditionMessage(w))
    invokeRestart("muffleWarning")
  })
  fit_rows[[example]] <- data.frame(example, formula = paste(deparse(formula), collapse = " "),
    family = family$family, data_seed, nsim, simulation_seed, pit_seed = 123L,
    convergence = model$fit$convergence, pdHess = model$sdr$pdHess,
    warning_count = length(warnings), warnings = paste(warnings, collapse = " | "))
}
summary <- do.call(rbind, summary_rows)
write.csv(summary, file.path(output, "summary.csv"), row.names = FALSE)
write.csv(do.call(rbind, bin_rows), file.path(output, "bins.csv"), row.names = FALSE)
write.csv(do.call(rbind, fit_rows), file.path(output, "fits.csv"), row.names = FALSE)
sources <- c("R/predictive_checks_residuals.R", "R/predictive_checks_envelopes.R",
             "R/predictive_checks_simulation.R", file.path(base, "histogram-bins.R"),
             file.path(base, "results", examples[1:2], "data.csv"))
hashes <- tools::md5sum(sources)
writeLines(trimws(c(capture.output(print(hashes)), "", capture.output(sessionInfo())), which = "right"),
           file.path(output, "session-info.txt"))
stopifnot(all(vapply(fit_rows, function(x) x$convergence == 0L && x$pdHess, logical(1))))
print(summary, row.names = FALSE)
