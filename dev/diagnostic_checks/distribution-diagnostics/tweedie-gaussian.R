# Run from the package folder. Reproduce the first Tweedie dataset from the
# simple-generalized-cross-sectional study (ba2fd5e, seed 100104, 120 dyads).
# The Gaussian fit omits roles and the member-difference random effect;
# observation-level variance remains estimated (dispformula = ~1).
pkgload::load_all(quiet = TRUE)

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

model <- glmmTMB::glmmTMB(outcome ~ predictor + (1 | dyad),
  family = gaussian(), dispformula = ~1, data = model_data)
stopifnot(model$fit$convergence == 0, model$sdr$pdHess)
simulations <- simulate_dyad_responses(model, nsim = 2000, seed = 100105)
output <- "dev/diagnostic_checks/distribution-diagnostics/results/tweedie-gaussian"
dir.create(output, recursive = TRUE, showWarnings = FALSE)
write.csv(model_data, file.path(output, "data.csv"), row.names = FALSE)
writeLines(trimws(capture.output(summary(model)), which = "right"), file.path(output, "fit.txt"))

save_pages <- function(name, height, draw) {
  grDevices::svg(file.path(output, paste0(name, "-%02d.svg")),
    width = 12, height = height, onefile = FALSE)
  on.exit(grDevices::dev.off())
  force(draw)
}

pit <- save_pages("residual", 14, check_residuals(
  simulations, dyad = dyad, role = role, data = model_data,
  predictors = simulations$model_frame["predictor"], details = TRUE,
  seed = 123, ask = FALSE
))
outcomes <- save_pages("outcome", 14, check_outcomes(
  simulations, dyad = dyad, role = role, data = model_data,
  check_zeros = TRUE, centred_overlay = TRUE, ask = FALSE
))
partner <- save_pages("partner", 8, check_partner_dependence(
  simulations, dyad = dyad, role = role, data = model_data, ask = FALSE
))
partner_raw <- save_pages("partner-raw", 8, check_partner_dependence(
  simulations, dyad = dyad, role = role, data = model_data,
  response = "raw", ask = FALSE
))

# Compact numerical references to accompany the figures; these are not p-values.
summarise_values <- function(values, check, group, statistic) {
  limits <- quantile(values[-1], c(.025, .975))
  data.frame(check, group, statistic, observed = values[1],
    lower = unname(limits[1]), upper = unname(limits[2]))
}
summaries <- list()
for (role in names(outcomes[[1]])) {
  values <- outcomes[[1]][[role]]
  for (statistic in rownames(values)) {
    summaries[[length(summaries) + 1]] <- summarise_values(
      values[statistic, ], "Outcome", role, statistic)
  }
  rows <- model_data$role == role
  summaries[[length(summaries) + 1]] <- summarise_values(
    colSums(pit[rows, ] == 0 | pit[rows, ] == 1), "Residual", role, "PIT endpoints")
  summaries[[length(summaries) + 1]] <- summarise_values(
    c(sum(model_data$outcome[rows] < 0),
      rowSums(simulations$simulated_responses[, rows] < 0)),
    "Outcome", role, "Negative outcomes")
}
for (check in list(partner, partner_raw)) {
  values <- check$compositions$statistics[[1]]
  for (statistic in names(values)[-1]) {
    summaries[[length(summaries) + 1]] <- summarise_values(
      values[[statistic]], paste("Partner", check$response), "female - male", statistic)
  }
}
summaries <- do.call(rbind, summaries)
write.csv(summaries, file.path(output, "summaries.csv"), row.names = FALSE)
writeLines(trimws(capture.output(sessionInfo()), which = "right"), file.path(output, "session-info.txt"))

pages <- data.frame(
  file = c("residual-01", "outcome-01", "partner-01", "residual-02",
           "residual-03", "outcome-02", "partner-raw-01"),
  title = c("Residual overview", "Outcome distributions and summaries",
    "Partner dependence after subtracting predictions", "Patterns by predictor",
    "Additional residual summaries", "Outcomes after subtracting predictions",
    "Partner dependence in raw outcomes"),
  guide = c(
    "The QQ curves and uneven PIT frequencies reveal a distribution mismatch. Five male outcomes are outside their simulated ranges, versus a reference range of zero to one.",
    "The Gaussian model generates negative values, misses the male zeros, and understates the largest deviations. Its common variance is too large for female responses and too small for male responses.",
    "Both role SDs and the mean/difference correlation show unequal variability. Partner correlation itself is reproduced reasonably well.",
    "Compare each red quartile curve with its matching blue band. With only 120 observations per role, local comparisons are less precise than the overall distribution checks.",
    "The uniformity summaries show a broad distribution mismatch. PIT distance can reflect errors in either location or spread.",
    "Subtracting the same fixed-effect predictions from all datasets leaves the asymmetric observed distribution visible.",
    "These summaries include variation explained by the predictor. The same role-variance mismatch remains visible."
  )
)
navigation <- paste0('<a href="#', pages$file, '">', pages$title, '</a>', collapse = " &middot; ")
sections <- paste0('<section id="', pages$file, '"><h2>', pages$title,
  '</h2><p>', pages$guide, '</p><a href="', pages$file,
  '.svg"><img src="', pages$file, '.svg" alt="', pages$title,
  '"></a><p><a href="#top">Back to overview</a></p></section>')
writeLines(c(
  '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">',
  '<title>Tweedie data checked against an exchangeable Gaussian model</title>',
  '<style>body{font:18px/1.5 system-ui,sans-serif;color:#222;max-width:1100px;margin:40px auto;padding:0 24px}h1{line-height:1.2}h2{font-size:1.4em}a{color:#185b83}nav{padding:18px;background:#f1f6f9}section{margin-top:52px;border-top:1px solid #ddd;padding-top:18px}img{width:100%;height:auto}code{font-size:.9em}li{margin:.4em 0}</style>',
  '<body id="top"><h1>Tweedie data, exchangeable Gaussian model</h1>',
  '<p>All available diagnostic pages for the earlier simulated dataset: 120 female-male dyads, 240 observations, original seed 100104. The generator used a log link, shared dyad effects and different dispersions by role (Tweedie power 1.5).</p>',
  '<p><strong>Fitted model:</strong> <code>outcome ~ predictor + (1 | dyad)</code>, Gaussian identity link, <code>dispformula = ~1</code>. It omits the role effect and member-difference random effect, while estimating a common observation-level variance. The fit converged with a positive-definite Hessian.</p>',
  '<p><strong>Reference:</strong> 2,000 complete simulations, with new random effects and fixed fitted parameters. Residual checks use 1,000 to define PIT ranks and 1,000 for reference envelopes. Role labels are supplied through the original fitting data because the fitted model does not include them.</p>',
  '<p><strong>What fails:</strong> distribution shape, role-specific variability, extreme outcomes, and male zero counts. <strong>What still agrees:</strong> overall partner correlation and the SDs of dyad averages and partner half-differences.</p>',
  '<p>Omitting the difference random effect does not force this model to miss positive partner correlation: its random intercept and observation-level noise can reproduce it. A failed panel cannot isolate which omitted assumption caused the mismatch.</p>',
  '<p>Red is observed; blue is simulated. Ranges contain the middle 95% at each comparison, not across all plots. These are descriptive checks, not significance tests. This example illustrates their use; it does not establish general detection rates.</p>',
  '<p><a href="data.csv">Data</a> &middot; <a href="fit.txt">Fitted model</a> &middot; <a href="summaries.csv">Observed values and reference ranges</a> &middot; <a href="session-info.txt">Package versions</a> &middot; <a href="../../tweedie-gaussian.R">Reproduction script</a></p>',
  paste0('<nav aria-label="Diagnostic pages">', navigation, '</nav>'),
  sections, '</body></html>'
), file.path(output, "index.html"))
