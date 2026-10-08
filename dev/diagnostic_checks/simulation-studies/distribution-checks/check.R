# Run from the repository root before a long study. These are implementation
# checks, not estimates of false-alarm rates or detection probabilities.
pkgload::load_all(quiet = TRUE)
source("dev/diagnostic_checks/simulation-studies/distribution-checks/helpers.R")
source("dev/diagnostic_checks/simulation-studies/distribution-checks/summarise.R")
conditions <- distribution_conditions()
stopifnot(nrow(conditions) == 34L, !anyDuplicated(conditions$condition))

# Check generating moments against independent formulas, including zero-inflated
# expectations and the partner/time indexing of the longitudinal generator.
moment_check <- function(values, expected) {
  stopifnot(abs(mean(values) - expected) < 6 * stats::sd(values) / sqrt(length(values)))
}
for (index in c(1L, 10L, 16L, 19L, 25L, 33L)) {
  condition <- conditions[index, ]
  condition$n_dyads <- 1L
  data <- generate_distribution_design(condition, 11000L + index)
  values <- replicate(20000L, generate_distribution_response(data, condition))
  linear <- distribution_linear_predictor(data, condition)
  if (condition$family == "gaussian") {
    means <- linear
    residual_variance <- 2 / (1 + condition$sd_ratio^2) *
      ifelse(data$role == "A", 1, condition$sd_ratio^2)
    variances <- condition$dyad_sd^2 + residual_variance
    if (condition$n_times > 1L) variances[] <- condition$dyad_sd^2 + .6^2 + .8^2
    partner_covariance <- condition$dyad_sd^2
  } else {
    means <- exp(linear + condition$dyad_sd^2 / 2)
    variances <- means + means^2 *
      ((1 + 1 / condition$nb_size) * exp(condition$dyad_sd^2) /
         (1 - condition$zero_probability) - 1)
    partner_covariance <- means[1] * means[2] * (exp(condition$dyad_sd^2) - 1)
  }
  for (row in 1:2) {
    moment_check(values[row, ], means[row])
    moment_check((values[row, ] - means[row])^2, variances[row])
  }
  moment_check((values[1, ] - means[1]) * (values[2, ] - means[2]), partner_covariance)
  if (condition$n_times > 1L) {
    stopifnot(all(table(data$member) == condition$n_times),
      all(tapply(as.character(data$role), data$member, function(x) length(unique(x))) == 1L))
    moment_check((values[1, ] - means[1]) * (values[3, ] - means[3]),
                 condition$dyad_sd^2 + .6^2 * .5)
  }
}

# Compare the recorded flags to the package's actual numerical results.
condition <- conditions[1, ]
data <- generate_distribution_design(condition, 22001)
data$outcome <- generate_distribution_response(data, condition)
model <- glmmTMB::glmmTMB(outcome ~ actor_predictor + partner_predictor + (1 | dyad), data = data)
simulations <- simulate_dyad_responses(model, nsim = 200, seed = 22002)
centred <- check_dyad_residuals(simulations, dyad = dyad, role = role, data = data, seed = 22003, plot = FALSE)
attr(simulations, "dyadMLM")$free_conditional_intercept <- FALSE
uncentred <- check_dyad_residuals(simulations, dyad = dyad, role = role, data = data, seed = 22003, plot = FALSE)
expected <- apply(uncentred$pit, 2, function(x) pnorm(qnorm(x) - median(qnorm(x))))
stopifnot(isTRUE(all.equal(centred$pit, expected)))
recorded <- evaluate_distribution_checks(simulations, data, condition, "fitted", 22003)
key <- c("reference", "view", "role", "check", "statistic")
stopifnot(!anyDuplicated(recorded[key]))
qq <- centred$compositions[[1]]$statistics$A$qq
stopifnot(identical(with(qq, any(observed < lower | observed > upper)),
  recorded$flagged[with(recorded, reference == "fitted-centred" & view == "roles" &
    role == "A" & statistic == "qq")]))

# Distinct flags must remain distinct when combining residual and outcome checks.
fixture <- expand.grid(reference = c("fitted-centred", "fitted-uncentred"),
  view = "roles", role = c("A", "B"), check = "residual", statistic = "qq",
  stringsAsFactors = FALSE) |>
  dplyr::mutate(below = FALSE, above = reference == "fitted-centred" & role == "A", flagged = above)
fixture <- dplyr::bind_rows(fixture, data.frame(reference = "fitted", view = "roles",
  role = c("A", "B"), check = "outcome", statistic = "zeros", below = FALSE, above = FALSE, flagged = FALSE))
combined <- add_distribution_unions(fixture)
both <- combined[combined$check == "both" & combined$role == "All", ]
stopifnot(both$flagged[both$reference == "fitted-centred"],
          !both$flagged[both$reference == "fitted-uncentred"])
missing <- distribution_placeholders("fitted")
stopifnot(all(is.na(missing$flagged)))

# The count display omits the observed comparison for its blue-only Other row.
source("tests/testthat/helper-predictive-checks.R")
counts <- distribution_check_fixture()
counts$observed_response <- rep(0:1, 6)
counts$simulated_responses <- matrix(rep(0:3, 600), 200, 12)
attr(counts, "dyadMLM")$family <- "poisson"
outcome <- check_dyad_outcomes(counts, role = NULL, plot = FALSE)
frequencies <- record_distribution_outcomes(outcome)
stopifnot(outcome$compositions[[1]]$distribution$has_other_values,
  setequal(frequencies$statistic[startsWith(frequencies$statistic, "category:")],
           c("category:0", "category:1")))
cat("Generator moments, paired PIT, recorded flags, unions, and count display checks passed.\n")
