# Run from the package folder. A Gaussian model misses NB2 outcomes and partner dependence.
pkgload::load_all(quiet = TRUE)
set.seed(20260927)
model_data <- data.frame(
  dyad = factor(rep(seq_len(250), each = 2)),
  role = factor(rep(c("female", "male"), 250)),
  support = rnorm(500)
)
shared_effect <- rnorm(250, sd = .8)
mean_response <- exp(1 + .35 * model_data$support +
  .2 * (model_data$role == "male") + shared_effect[as.integer(model_data$dyad)])
# NB2: conditional variance = mean + mean^2 / 2.
model_data$outcome <- rnbinom(500, mu = mean_response, size = 2)

# No dyad random effect: the fitted model treats partners as independent.
model <- glmmTMB::glmmTMB(outcome ~ role + support,
                         family = gaussian(), data = model_data)
stopifnot(model$fit$convergence == 0, model$sdr$pdHess)
simulations <- simulate_dyad_responses(model, nsim = 1000, seed = 123)
residual_check <- check_dyad_residuals(simulations, dyad = dyad, role = role,
  data = model_data, predictors = "support", plot = FALSE)
outcome_check <- check_dyad_outcomes(simulations, dyad = dyad, role = role,
  data = model_data, plot = FALSE)
partner_check <- check_partner_dependence(simulations, dyad = dyad, role = role,
  data = model_data, plot = FALSE)

output <- "dev/diagnostic_checks/distribution-diagnostics/results/nbinom2-gaussian"
dir.create(output, recursive = TRUE, showWarnings = FALSE)
checks <- list(residual = residual_check, outcome = outcome_check, partner = partner_check)
for (name in names(checks)) {
  grDevices::png(file.path(output, paste0(name, "-%02d.png")),
    width = 1200, height = if (name == "partner") 850 else 1200, res = 100)
  plot(checks[[name]], ask = FALSE)
  grDevices::dev.off()
}
write.csv(model_data, file.path(output, "data.csv"), row.names = FALSE)
write.csv(partner_check$summary, file.path(output, "partner-summary.csv"), row.names = FALSE)
correlation <- partner_check$summary[grepl("^Partner correlation", partner_check$summary$statistic), ]
writeLines(c(
  '<!doctype html><html lang="en"><meta charset="utf-8">',
  '<meta name="viewport" content="width=device-width, initial-scale=1">',
  '<title>NB2 dyads checked with an independent Gaussian model</title>',
  '<style>body{max-width:1100px;margin:32px auto;padding:0 20px;font:17px/1.5 sans-serif;color:#222}img{width:100%;height:auto}h2{margin-top:2em}code{background:#f4f4f4;padding:2px 5px}</style>',
  '<h1>NB2 dyads checked with an independent Gaussian model</h1>',
  '<p>250 dyads. Outcomes follow a negative-binomial (NB2) model with a log link,',
  'role and support effects, and a shared dyad effect (SD 0.8). The NB2 size is 2.</p>',
  '<p>We fit <code>outcome ~ role + support</code> with <code>family = gaussian()</code>',
  'and no dyad effect. The model therefore misses both the outcome distribution',
  'and partner dependence. All checks reuse 1,000 simulated datasets.</p>',
  '<p>Red shows the observed data; blue shows model simulations. These are',
  'descriptive checks of one simulated example, not a detection study.</p>',
  '<h2>1. Residual distribution</h2>',
  '<img src="residual-01.png" alt="QQ, PIT histogram, outliers and mean PIT distance by role">',
  '<h2>2. Patterns across predicted outcomes</h2>',
  '<img src="residual-02.png" alt="PIT quartiles and distance across predicted outcomes">',
  '<h2>3. Patterns across support</h2>',
  '<img src="residual-03.png" alt="PIT quartiles and distance across support">',
  '<h2>4. Outcome checks</h2>',
  '<img src="outcome-01.png" alt="Outcome distribution, SD, extremes and zero counts">',
  '<h2>5. Partner dependence</h2>',
  sprintf('<p>Observed model-centred partner correlation: %.2f. Simulated reference limits: %.2f to %.2f.</p>',
          correlation$observed, correlation$lower, correlation$upper),
  '<img src="partner-01.png" alt="Role SDs and partner dependence compared with independent simulations">',
  '<p><a href="../../nbinom2-gaussian.R">Reproduce this example</a> ·',
  '<a href="data.csv">Simulated data</a> · <a href="partner-summary.csv">Partner summaries</a></p>',
  '</html>'
), file.path(output, "index.html"))
print(partner_check$summary)
