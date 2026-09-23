# Conditional margins for the APIM sensitivity study.
# Each quantile uses the same response and dispersion parameterization as glmmTMB.

# For COM-Poisson with nu = 2, the normalizing constant is I0(2 * sqrt(lambda)).
compois_parameters <- function(mean) {
  log_lambda <- 2 * log(mean + 0.25)
  for (iteration in 1:20) {
    square_root_lambda <- exp(log_lambda / 2)
    current_mean <- square_root_lambda *
      besselI(2 * square_root_lambda, 1, expon.scaled = TRUE) /
      besselI(2 * square_root_lambda, 0, expon.scaled = TRUE)
    variance <- exp(log_lambda) - current_mean^2
    change <- (mean - current_mean) / variance
    log_lambda <- log_lambda + change
    if (max(abs(change)) < 1e-12) break
  }
  square_root_lambda <- exp(log_lambda / 2)
  list(log_lambda = log_lambda,
    log_normalizer = log(besselI(2 * square_root_lambda, 0, expon.scaled = TRUE)) +
      2 * square_root_lambda,
    variance = exp(log_lambda) - mean^2)
}

# Sum only as far into the count distribution as each requested quantile needs.
count_quantile <- function(probability, density) {
  result <- integer(length(probability))
  cumulative_probability <- density(0L, seq_along(probability))
  pending <- which(probability > cumulative_probability)
  count <- 0L
  while (length(pending)) {
    count <- count + 1L
    cumulative_probability[pending] <- cumulative_probability[pending] + density(count, pending)
    finished <- pending[probability[pending] <= cumulative_probability[pending]]
    result[finished] <- count
    pending <- pending[probability[pending] > cumulative_probability[pending]]
    if (count > 100000L) stop("Count quantile did not converge.")
  }
  result
}

make_family_margin <- function(family_name) {
  zero_inflated <- family_name == "zi_poisson"
  hurdle <- family_name == "hurdle_nbinom2"
  base_family <- if (zero_inflated) "poisson" else if (hurdle) "truncated_nbinom2" else family_name
  truncated <- startsWith(base_family, "truncated_")
  distribution <- sub("^truncated_", "", base_family)
  mean_intercept <- if (distribution %in% c("gaussian", "skewnormal", "t", "ordinal", "beta")) 0 else log(3)
  zero_probability <- if (zero_inflated || hurdle) 0.25 else 0
  thresholds <- c(-1, 0, 1)
  family <- switch(base_family,
    gaussian = gaussian(), poisson = poisson(), Gamma = Gamma(link = "log"),
    beta = glmmTMB::beta_family(), t = glmmTMB::t_family(),
    ordinal = glmmTMB::ordinal(link = "probit"),
    getExportedValue("glmmTMB", base_family)())

  parameters <- function(linear_predictor) {
    mean <- switch(distribution,
      gaussian = linear_predictor, skewnormal = linear_predictor, t = linear_predictor,
      beta = plogis(linear_predictor), ordinal = linear_predictor,
      exp(mean_intercept + linear_predictor))
    negative_binomial_size <- switch(distribution,
      nbinom1 = mean, nbinom2 = rep(3, length(mean)), nbinom12 = mean / (1 + mean / 3))
    compois <- if (distribution == "compois") compois_parameters(mean) else NULL
    # Bell mean = theta * exp(theta); Newton's method in theta is vectorized.
    bell_theta <- if (distribution == "bell") {
      theta <- log1p(mean)
      for (iteration in 1:10) theta <- theta - (theta - mean * exp(-theta)) / (theta + 1)
      theta
    } else NULL
    probability_at_zero <- switch(distribution,
      poisson = exp(-mean), nbinom1 = dnbinom(0, mu = mean, size = negative_binomial_size),
      nbinom2 = dnbinom(0, mu = mean, size = negative_binomial_size),
      nbinom12 = dnbinom(0, mu = mean, size = negative_binomial_size),
      genpois = exp(-mean / sqrt(2)), compois = exp(-compois$log_normalizer),
      bell = exp(1 - exp(bell_theta)), tweedie = exp(-2 * sqrt(mean)),
      rep(0, length(mean)))
    list(mean = mean, size = negative_binomial_size, compois = compois,
      bell_theta = bell_theta, probability_at_zero = probability_at_zero)
  }

  response_mean <- function(linear_predictor, distribution_parameters = parameters(linear_predictor)) {
    values <- distribution_parameters
    mean <- if (distribution == "ordinal") {
      1 + rowSums(outer(linear_predictor, thresholds, function(eta, cutpoint) pnorm(eta - cutpoint)))
    } else values$mean
    if (truncated) mean <- mean / (1 - values$probability_at_zero)
    mean * (1 - zero_probability)
  }

  quantile <- function(probability, linear_predictor, distribution_parameters = parameters(linear_predictor)) {
    values <- distribution_parameters
    mean <- values$mean
    # The combined distribution first assigns its extra zero mass, then its response.
    extra_zero <- probability <= zero_probability
    probability <- (probability - zero_probability) / (1 - zero_probability)
    # Avoid floating-point endpoints in the inverse CDFs.
    probability <- pmax(1e-12, pmin(1 - 1e-12, probability))
    if (truncated) probability <- values$probability_at_zero +
      probability * (1 - values$probability_at_zero)
    outcome <- switch(distribution,
      gaussian = mean + qnorm(probability),
      poisson = qpois(probability, mean),
      nbinom1 = qnbinom(probability, mu = mean, size = values$size),
      nbinom2 = qnbinom(probability, mu = mean, size = values$size),
      nbinom12 = qnbinom(probability, mu = mean, size = values$size),
      Gamma = qgamma(probability, shape = 3, scale = mean / 3),
      beta = qbeta(probability, mean * 8, (1 - mean) * 8),
      lognormal = {
        log_variance <- log1p((2 / mean)^2)
        qlnorm(probability, log(mean) - log_variance / 2, sqrt(log_variance))
      },
      t = mean + qt(probability, df = 5),
      skewnormal = {
        # With shape = 1, the standard skew-normal CDF is Phi(x)^2.
        mean + (qnorm(sqrt(probability)) - 1 / sqrt(pi)) / sqrt(1 - 1 / pi)
      },
      ordinal = {
        cumulative <- outer(linear_predictor, thresholds,
                            function(eta, cutpoint) pnorm(cutpoint - eta))
        1L + rowSums(probability > cumulative)
      },
      tweedie = {
        # Power 1.5 gives a Poisson sum of exponential variables.
        result <- numeric(length(probability))
        positive <- probability > values$probability_at_zero
        result[positive] <- sqrt(mean[positive]) / 4 *
          qchisq(probability[positive], df = 0, ncp = 4 * sqrt(mean[positive]))
        result
      },
      genpois = count_quantile(probability, function(count, indices) {
        glmmTMB::dgenpois(rep(count, length(indices)), mean[indices] / sqrt(2), 1 - 1 / sqrt(2))
      }),
      compois = count_quantile(probability, function(count, indices) {
        exp(count * values$compois$log_lambda[indices] - 2 * lgamma(count + 1) -
          values$compois$log_normalizer[indices])
      }),
      bell = count_quantile(probability, function(count, indices) {
        glmmTMB:::dbell(rep(count, length(indices)), values$bell_theta[indices])
      })
    )
    outcome[extra_zero] <- 0
    outcome
  }

  fit_arguments <- list(family = family)
  if (zero_inflated || hurdle) fit_arguments$ziformula <- ~1
  settings <- switch(distribution,
    gaussian = "SD = 1", poisson = "Poisson mean",
    nbinom1 = "phi = 1", nbinom2 = "size = 3", nbinom12 = "phi = 1; psi = 3",
    Gamma = "shape = 3", beta = "precision = 8", lognormal = "response SD = 2",
    t = "scale = 1; df = 5", skewnormal = "response SD = 1; shape = 1",
    ordinal = "probit; thresholds -1, 0, 1; four categories",
    tweedie = "phi = 1; power = 1.5", genpois = "phi = 2",
    compois = "phi = 0.5 (nu = 2)", bell = "Bell mean")
  if (truncated) settings <- paste0(settings, "; truncated at zero")
  if (zero_probability > 0) settings <- paste0(settings, "; extra-zero probability = 0.25")
  list(name = family_name, family = family, fit_arguments = fit_arguments,
    mean_intercept = mean_intercept, zero_probability = zero_probability,
    settings = settings, response_mean = response_mean, quantile = quantile,
    parameters = parameters)
}

# Gauss-Hermite nodes and weights for a standard normal variable.
normal_quadrature <- function(number_of_nodes) {
  recurrence <- matrix(0, number_of_nodes, number_of_nodes)
  recurrence[cbind(1:(number_of_nodes - 1), 2:number_of_nodes)] <- sqrt(1:(number_of_nodes - 1))
  decomposition <- eigen(recurrence + t(recurrence), symmetric = TRUE)
  list(nodes = decomposition$values, weights = decomposition$vectors[1, ]^2)
}

calibrate_family_correlations <- function(family_name, calibration_pairs = 200000L,
                                          verification_pairs = 500000L, seed = 32000001L) {
  targets <- c(0, 0.1, 0.3, 0.5)
  if (family_name == "gaussian") {
    return(tibble::tibble(family = family_name, target_correlation = targets,
      latent_correlation = targets, measured_residual_correlation = targets,
      verification_mcse = 0, method = "Exact Gaussian correlation"))
  }
  margin <- make_family_margin(family_name)
  if (family_name == "lognormal") {
    conditional_covariance_average <- function(number_of_nodes) {
      quadrature <- normal_quadrature(number_of_nodes)
      first_predictor <- rep(quadrature$nodes, each = number_of_nodes)
      second_predictor <- 0.3 * first_predictor + sqrt(1 - 0.3^2) *
        rep(quadrature$nodes, times = number_of_nodes)
      first_mean <- exp(log(3) + 0.5 * first_predictor + 0.3 * second_predictor)
      second_mean <- exp(log(3) + 0.5 * second_predictor + 0.3 * first_predictor)
      log_sd_product <- sqrt(log1p(4 / first_mean^2) * log1p(4 / second_mean^2))
      weights <- as.vector(outer(quadrature$weights, quadrature$weights))
      function(latent_correlation) {
        # Both conditional response variances equal four.
        sum(weights * first_mean * second_mean * expm1(latent_correlation * log_sd_product)) / 4
      }
    }
    calibration_correlation <- conditional_covariance_average(40L)
    verification_correlation <- conditional_covariance_average(80L)
    latent_correlations <- vapply(targets, function(target) {
      if (target == 0) 0 else uniroot(function(value) calibration_correlation(value) - target,
        c(0, 0.999), tol = 1e-9)$root
    }, numeric(1))
    return(tibble::tibble(family = family_name, target_correlation = targets,
      latent_correlation = latent_correlations,
      measured_residual_correlation = vapply(latent_correlations, verification_correlation, numeric(1)),
      verification_mcse = 0, method = "Analytic lognormal covariance; 40/80-node Gaussian quadrature"))
  }

  # Reuse predictors and normal draws throughout calibration, then verify independently.
  prepare_draws <- function(number_of_pairs, draw_seed) {
    set.seed(draw_seed)
    first_predictor <- rnorm(number_of_pairs)
    second_predictor <- 0.3 * first_predictor + sqrt(1 - 0.3^2) * rnorm(number_of_pairs)
    first_linear_predictor <- 0.5 * first_predictor + 0.3 * second_predictor
    second_linear_predictor <- 0.5 * second_predictor + 0.3 * first_predictor
    first_normal <- rnorm(number_of_pairs)
    independent_normal <- rnorm(number_of_pairs)
    first_parameters <- margin$parameters(first_linear_predictor)
    second_parameters <- margin$parameters(second_linear_predictor)
    first_residual <- margin$quantile(pnorm(first_normal), first_linear_predictor, first_parameters) -
      margin$response_mean(first_linear_predictor, first_parameters)
    second_mean <- margin$response_mean(second_linear_predictor, second_parameters)
    list(first_residual = first_residual, second_mean = second_mean,
      second_linear_predictor = second_linear_predictor, second_parameters = second_parameters,
      first_normal = first_normal, independent_normal = independent_normal)
  }
  second_residuals <- function(latent_correlation, draws) {
    second_normal <- latent_correlation * draws$first_normal +
      sqrt(1 - latent_correlation^2) * draws$independent_normal
    margin$quantile(pnorm(second_normal), draws$second_linear_predictor,
      draws$second_parameters) - draws$second_mean
  }
  calibration_draws <- prepare_draws(calibration_pairs, seed)
  latent_correlations <- vapply(targets, function(target) {
    if (target == 0) return(0)
    uniroot(function(value) {
      cor(calibration_draws$first_residual, second_residuals(value, calibration_draws)) - target
    }, c(0, 0.999), tol = 1e-4)$root
  }, numeric(1))
  verification_draws <- prepare_draws(verification_pairs, seed + 1L)
  verification <- lapply(latent_correlations, function(latent_correlation) {
    first <- verification_draws$first_residual
    second <- second_residuals(latent_correlation, verification_draws)
    correlation <- cor(first, second)
    first <- (first - mean(first)) / sd(first)
    second <- (second - mean(second)) / sd(second)
    # Pearson correlation's influence values account for non-normal response margins.
    influence <- first * second - correlation * (first^2 + second^2) / 2
    c(correlation = correlation, mcse = sd(influence) / sqrt(verification_pairs))
  })
  result <- tibble::tibble(family = family_name, target_correlation = targets,
    latent_correlation = latent_correlations,
    measured_residual_correlation = vapply(verification, `[[`, numeric(1), "correlation"),
    verification_mcse = vapply(verification, `[[`, numeric(1), "mcse"),
    method = paste0("Gaussian copula calibrated with ", calibration_pairs,
      " pairs; independently verified with ", verification_pairs, " pairs"))
  verified <- abs(result$measured_residual_correlation - targets) <= 0.005
  if (!all(verified) && calibration_pairs < 1000000L) {
    return(calibrate_family_correlations(family_name, 1000000L, 2000000L, seed + 1000000L))
  }
  if (!all(verified)) stop("Correlation calibration needs more draws for ", family_name, ".")
  result
}
