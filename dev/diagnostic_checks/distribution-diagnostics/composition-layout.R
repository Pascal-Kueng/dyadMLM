# Run from the package folder to reproduce the composition examples.
library(glmmTMB)
source("R/utils_arguments.R")
source("R/utils_compositions.R")
source("R/predictive_checks_simulation.R")
source("R/predictive_checks_plot.R")
source("R/predictive_checks_dependence.R")
source("R/predictive_checks_groups.R")
source("R/predictive_checks_residuals.R")
source("R/predictive_checks_outcomes.R")
load("data/dyads_cross.rda")

model <- glmmTMB(closeness ~ gender + provided_support + (1 | coupleID),
                 data = dyads_cross)
stopifnot(model$fit$convergence == 0, model$sdr$pdHess)
simulations <- simulate_dyad_responses(model, nsim = 1000, seed = 123)
output <- "dev/diagnostic_checks/distribution-diagnostics/results"
grDevices::svg(file.path(output, "residual-composition-%02d.svg"),
               width = 12, height = 18, onefile = FALSE)
check_residuals(simulations, dyad = coupleID, role = gender, ask = FALSE)
dev.off()

grDevices::svg(file.path(output, "outcome-composition-%02d.svg"),
               width = 12, height = 18, onefile = FALSE)
check_outcomes(simulations, dyad = coupleID, role = gender, ask = FALSE)
dev.off()

grDevices::svg(file.path(output, "partner-composition-%02d.svg"),
               width = 12, height = 8, onefile = FALSE)
check_partner_dependence(simulations, dyad = coupleID, role = gender, ask = FALSE)
dev.off()
