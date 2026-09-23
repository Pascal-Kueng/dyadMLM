# Run from the repository root:
# OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 Rscript dev/diagnostic_checks/distribution-diagnostics/tail-shape-comparison.R
# Heavy tails and two Gaussian controls; no refits or formal significance tests.
library(glmmTMB)
source("R/predictive_checks_simulation.R")
source("R/utils_arguments.R")
source("R/predictive_checks_residual_groups.R")
source("R/predictive_checks_residuals.R")

output <- "dev/diagnostic_checks/distribution-diagnostics/results"
dir.create(output, showWarnings = FALSE)
set.seed(20260922)
data <- expand.grid(day = 1:20, member = 1:2, dyad = 1:100)
data$dyad <- factor(data$dyad)
data$person <- interaction(data$dyad, data$member, drop = TRUE)
data$time <- factor(data$day, levels = 1:20)
data$x <- rnorm(nrow(data))

# Stationary AR(1) trajectories for the 200 members at 20 occasions.
simulate_ar1 <- function(sd, rho) {
  trajectories <- matrix(0, 20, 200)
  trajectories[1, ] <- rnorm(200, sd = sd)
  for (day in 2:20) {
    trajectories[day, ] <- rho * trajectories[day - 1, ] +
      rnorm(200, sd = sd * sqrt(1 - rho^2))
  }
  trajectories
}
dyad_effect <- rnorm(100, sd = 0.5)
ar_effect <- simulate_ar1(sd = 0.5, rho = 0.6)
latent_mean <- 2 + data$x + dyad_effect[as.integer(data$dyad)] +
  ar_effect[cbind(data$day, as.integer(data$person))]
# Both observation-error distributions have variance one; only shape differs.
errors <- list(t3 = rt(nrow(data), df = 3) / sqrt(3),
               gaussian = rnorm(nrow(data)))
responses <- lapply(errors, function(error) latent_mean + error)

# Strong dependence: shared dyad intercept SD 2, AR SD 1/rho .9, error SD .5.
# After removing fixed effects: partner correlation .762 and own-lag correlation .933.
set.seed(20260924)
strong_dyad_effect <- rnorm(100, sd = 2)
strong_ar_effect <- simulate_ar1(sd = 1, rho = 0.9)
responses$gaussian_strong <- 2 + data$x +
  strong_dyad_effect[as.integer(data$dyad)] +
  strong_ar_effect[cbind(data$day, as.integer(data$person))] +
  rnorm(nrow(data), sd = 0.5)

# Heavier tails with the original dependence; retain theoretical error variance one.
set.seed(20260925)
responses$t22 <- latent_mean + rt(nrow(data), df = 2.2) / sqrt(2.2 / (2.2 - 2))

tail_ratio <- function(x) {
  q <- quantile(x, c(.01, .25, .75, .99), names = FALSE)
  (q[4] - q[1]) / (q[3] - q[2])
}
results <- list()

for (scenario in names(responses)) {
  message(scenario, ": fitting Gaussian model")
  data$y <- responses[[scenario]]
  fit <- glmmTMB(y ~ x + (1 | dyad) + ar1(time + 0 | person),
                family = gaussian(), data = data)
  stopifnot(fit$fit$convergence == 0, fit$sdr$pdHess)
  message(scenario, ": simulating responses")
  simulations <- simulate_dyad_responses(fit, nsim = 1000, seed = 20260923)
  observed <- simulations$observed_response
  predicted <- simulations$predicted_response
  message(scenario, ": plotting diagnostics")

  png(file.path(output, paste0(scenario, "-panel-%02d.png")),
      width = 1800, height = 2700, res = 150)
  check_residuals(simulations, dyad = dyad, role = member,
    member = person, data = data, predictors = list(x = data$x), ask = FALSE)
  dev.off()

  # Match the dashboard's evaluation half for the numerical tail summary.
  reference_rows <- seq_len(floor(nrow(simulations$simulated_responses) / 2))
  replicated <- simulations$simulated_responses[-reference_rows, , drop = FALSE]
  centred_observed <- observed - predicted
  centred_replicated <- sweep(replicated, 2, predicted)
  simulated_tails <- apply(centred_replicated, 1, tail_ratio)
  variance <- VarCorr(fit)$cond
  results[[scenario]] <- data.frame(scenario, n = nrow(data),
    convergence = fit$fit$convergence, positive_hessian = fit$sdr$pdHess,
    dyad_sd = attr(variance$dyad, "stddev")[1],
    ar_sd = attr(variance$person, "stddev")[1],
    ar_rho = attr(variance$person, "correlation")[1, 2], error_sd = sigma(fit),
    observed_tail_ratio = tail_ratio(centred_observed),
    reference_lower = quantile(simulated_tails, .025),
    reference_median = median(simulated_tails),
    reference_upper = quantile(simulated_tails, .975))
}
results <- do.call(rbind, results)
write.csv(results, file.path(output, "results.csv"), row.names = FALSE)
writeLines(trimws(capture.output(sessionInfo()), which = "right"),
           file.path(output, "session-info.txt"))
print(results, row.names = FALSE)
