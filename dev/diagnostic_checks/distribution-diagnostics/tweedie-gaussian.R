# Run from the package folder. Reproduce the first Tweedie dataset from the
# simple-generalized-cross-sectional study (ba2fd5e, seed 100104, 120 dyads).
# The Gaussian fit omits roles and the member-difference random effect;
# observation-level variance remains estimated (dispformula = ~1).
set.seed(100104)
model_data <- data.frame(
  dyad = factor(rep(seq_len(120), each = 2)),
  role = factor(rep(c("female", "male"), 120)),
  predictor = rnorm(240)
)
shared_effect <- rnorm(120, sd = .65)
mean_response <- exp(.75 + .3 * model_data$predictor +
  .2 * (model_data$role == "male") + shared_effect[as.integer(model_data$dyad)])
dispersion <- .45 * ifelse(model_data$role == "male", 1.45, .75)
# Power 1.5: a Poisson number of Gamma contributions, with exact zeros possible.
events <- rpois(240, 2 * sqrt(mean_response) / dispersion)
positive <- events > 0
model_data$outcome <- 0
model_data$outcome[positive] <- rgamma(sum(positive), shape = events[positive],
  scale = dispersion[positive] * sqrt(mean_response[positive]) / 2)
output <- "dev/diagnostic_checks/distribution-diagnostics/results/tweedie-gaussian"
dir.create(output, recursive = TRUE, showWarnings = FALSE)
write.csv(model_data, file.path(output, "data.csv"), row.names = FALSE)

# Render the same executable workflow included in the development vignette.
rmarkdown::render(
  "dev/diagnostic_checks/tweedie-gaussian-example.Rmd",
  output_file = "index.html", output_dir = normalizePath(output), quiet = TRUE
)
