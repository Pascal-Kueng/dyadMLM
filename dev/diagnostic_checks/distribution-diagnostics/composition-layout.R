# Run from the package folder to reproduce the composition overview examples.
library(glmmTMB)
source("R/utils_arguments.R")
source("R/predictive_checks_simulation.R")
source("R/predictive_checks_residual_groups.R")
source("R/predictive_checks_residuals.R")
load("data/dyads_cross.rda")

model <- glmmTMB(closeness ~ gender + provided_support + (1 | coupleID),
                 data = dyads_cross)
stopifnot(model$fit$convergence == 0, model$sdr$pdHess)
simulations <- simulate_dyad_responses(model, nsim = 1000, seed = 123)
output <- "dev/diagnostic_checks/distribution-diagnostics/results"
png(file.path(output, "composition-%02d.png"), width = 1800, height = 2700, res = 150)
check_residuals(simulations, dyad = coupleID, role = gender, ask = FALSE)
dev.off()
