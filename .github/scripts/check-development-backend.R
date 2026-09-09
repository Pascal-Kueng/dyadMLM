# A compatibility smoke test, not a check of parameter recovery or MCMC accuracy.
backend <- commandArgs(trailingOnly = TRUE)
stopifnot(length(backend) == 1L, backend %in% c("glmmTMB", "brms"))
description <- utils::packageDescription(backend)
message(backend, " ", description$Version)
if (!is.null(description$RemoteSha)) message("Upstream commit: ", description$RemoteSha)

set.seed(91)
data <- expand.grid(member = c(-1, 1), occasion = 1:3, coupleID = 1:20)
data$coupleID <- factor(data$coupleID)
shared <- stats::rnorm(20, sd = 0.8)
difference <- stats::rnorm(20, sd = 0.5)
data$outcome <- shared[data$coupleID] + data$member * difference[data$coupleID] +
  stats::rnorm(nrow(data), sd = 0.4)
data <- dyadMLM::prepare_dyad_data(
  data, dyad = coupleID, member = member, time = occasion,
  model_types = "none", seed = 91
)

# Repeated observations identify stable dyad effects separately from residual sigma.
formula <- outcome ~ 1 + (1 | coupleID) +
  (0 + .member_contrast_arbitrary | coupleID)
if (backend == "glmmTMB") {
  model <- glmmTMB::glmmTMB(formula, data = data)
  stopifnot(model$fit$convergence == 0L, isTRUE(model$sdr$pdHess))
  covariance <- glmmTMB::VarCorr(model)$cond
  shared_variance <- covariance[[1L]][1L, 1L]
  difference_variance <- covariance[[2L]][1L, 1L]
} else {
  # Twenty retained draws exercise real extraction; they are not for inference.
  # Keep warnings visible. Compilation can take longer than this short sampling run.
  model <- brms::brm(
    formula, data = data, backend = "rstan",
    prior = c(
      brms::set_prior("normal(0, 2)", class = "Intercept"),
      brms::set_prior("exponential(1)", class = "sd"),
      brms::set_prior("exponential(1)", class = "sigma")
    ),
    chains = 1, cores = 1, iter = 120, warmup = 100,
    init = 0, seed = 91, refresh = 0
  )
  standard_deviations <- brms::VarCorr(model, summary = FALSE)$coupleID$sd
  stopifnot(nrow(standard_deviations) == 20L)
  shared_variance <- standard_deviations[, "Intercept"]^2
  difference_variance <- standard_deviations[, ".member_contrast_arbitrary"]^2
}

# Independent reference calculation from public backend output, draw by draw.
member_variance <- shared_variance + difference_variance
member_covariance <- shared_variance - difference_variance
expected_varcov <- expected_sdcor <- array(NA_real_, c(length(member_variance), 2, 2))
expected_varcov[, 1, 1] <- expected_varcov[, 2, 2] <- member_variance
expected_varcov[, 1, 2] <- expected_varcov[, 2, 1] <- member_covariance
expected_sdcor[, 1, 1] <- expected_sdcor[, 2, 2] <- sqrt(member_variance)
expected_sdcor[, 1, 2] <- expected_sdcor[, 2, 1] <- member_covariance / member_variance
if (backend == "glmmTMB") {
  expected_varcov <- expected_varcov[1, , ]
  expected_sdcor <- expected_sdcor[1, , ]
}

recovered <- dyadMLM::recover_exchangeable_covariance(model, posterior = "draws")
stopifnot(inherits(recovered, "exchangeable_covariance"), length(recovered) == 1L)
assert_equal <- function(actual, expected) {
  stopifnot(all(is.finite(actual)))
  stopifnot(isTRUE(all.equal(unname(actual), unname(expected), tolerance = 1e-10)))
}
assert_equal(recovered[[1L]]$varcov, expected_varcov)
assert_equal(recovered[[1L]]$sdcor, expected_sdcor)

if (backend == "brms") {
  # In particular, average each draw's correlation, not the averaged variances.
  posterior_mean <- dyadMLM::recover_exchangeable_covariance(model)
  assert_equal(posterior_mean[[1L]]$varcov, apply(expected_varcov, c(2, 3), mean))
  assert_equal(posterior_mean[[1L]]$sdcor, apply(expected_sdcor, c(2, 3), mean))
}
message(backend, " covariance extraction and recovery passed.")
