# Run from the repository root with Rscript and a glmmTMB version with ordinal().
# Check category scoring and predictions, not statistical calibration.
pkgload::load_all(quiet = TRUE)
message("glmmTMB ", utils::packageVersion("glmmTMB"))

set.seed(9241)
fitting_data <- data.frame(
  dyad = factor(rep(seq_len(180), each = 2)),
  predictor = stats::rnorm(360)
)
latent_response <- 0.6 * fitting_data$predictor +
  stats::rnorm(180, sd = 0.9)[fitting_data$dyad] + stats::rlogis(360)
# Numeric-looking labels must still become category positions 1, 2, 3, and 4.
category_labels <- c("1", "2", "4", "8")
fitting_data$outcome <- cut(
  latent_response, c(-Inf, -1, 0.5, 2, Inf),
  labels = category_labels, ordered_result = TRUE
)

for (link_name in c("logit", "probit")) {
  fitted_model <- glmmTMB::glmmTMB(
    outcome ~ predictor + (1 | dyad), data = fitting_data,
    family = glmmTMB::ordinal(link = link_name)
  )
  stopifnot(fitted_model$fit$convergence == 0L, isTRUE(fitted_model$sdr$pdHess))

  # Calculate category probabilities directly from thresholds and fixed effects.
  # The ordinal model has no fixed intercept; thresholds take its place.
  category_thresholds <- glmmTMB::family_params(fitted_model)
  fixed_effect_predictor <- glmmTMB::fixef(fitted_model)$cond["predictor"] *
    fitting_data$predictor
  inverse_link <- stats::make.link(link_name)$linkinv
  cumulative_probabilities <- sapply(category_thresholds, function(threshold) {
    inverse_link(threshold - fixed_effect_predictor)
  })
  category_probabilities <- cbind(cumulative_probabilities, 1) -
    cbind(0, cumulative_probabilities)
  expected_category_scores <- as.numeric(
    category_probabilities %*% seq_along(category_labels)
  )

  simulations <- simulate_dyad_responses(fitted_model, nsim = 40, seed = 9242)
  native_simulations <- stats::simulate(fitted_model, nsim = 40, seed = 9242)
  native_simulations[] <- lapply(native_simulations, function(draw) {
    match(as.character(draw), category_labels)
  })
  stopifnot(
    identical(dim(simulations$simulated_responses), c(40L, 360L)),
    all(simulations$observed_response ==
          match(as.character(fitting_data$outcome), category_labels)),
    all(simulations$simulated_responses %in% seq_along(category_labels)),
    all(simulations$simulated_responses == t(as.matrix(native_simulations))),
    max(abs(simulations$predicted_response - expected_category_scores)) < 1e-12
  )

  for (response_scale in c("raw", "model-centred")) {
    check <- check_partner_dependence(
      simulations, dyad = dyad, role = NULL, response = response_scale,
      plot = FALSE
    )
    stopifnot(
      check$n_pairs == 180L,
      all(is.finite(as.matrix(check$compositions$statistics[[1]][, -1])))
    )
  }
  message(link_name, ": passed predictions, category scoring, and downstream checks")
}
