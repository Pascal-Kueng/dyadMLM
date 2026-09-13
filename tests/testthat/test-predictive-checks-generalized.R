# Scalar-family fixtures adapted from simple-generalized-checks (ba2fd5e).
# These exercise backend agreement and statistic calculations, not calibration.
generalized_check_test_data <- function(family) {
  withr::local_seed(8110)
  n_dyads <- 60L
  data <- data.frame(
    dyad = factor(rep(seq_len(n_dyads), each = 2L)),
    role = factor(rep(c("female", "male"), times = n_dyads)),
    predictor = rep(c(-0.75, 0.25, 0.75, -0.25), length.out = 2L * n_dyads)
  )
  eta <- 1 + 0.25 * data$predictor + 0.15 * (data$role == "male") +
    stats::rnorm(n_dyads, sd = 0.35)[as.integer(data$dyad)]
  mu <- if (family$family == "beta") stats::plogis(eta - 1) else exp(eta)
  n <- nrow(data)
  data$outcome <- switch(
    family$family,
    poisson = stats::rpois(n, mu),
    nbinom1 = stats::rnbinom(n, mu = mu, size = mu / 0.8),
    nbinom2 = stats::rnbinom(n, mu = mu, size = 2.5),
    tweedie = {
      # Compound Poisson-Gamma draws with power 1.5 and dispersion 0.8.
      events <- stats::rpois(n, sqrt(mu) / 0.4)
      values <- numeric(n)
      positive <- events > 0L
      values[positive] <- stats::rgamma(
        sum(positive), shape = events[positive],
        scale = 0.4 * sqrt(mu[positive])
      )
      values
    },
    Gamma = stats::rgamma(n, shape = 5, scale = mu / 5),
    beta = stats::rbeta(n, shape1 = mu * 20, shape2 = (1 - mu) * 20)
  )
  data
}


test_that("six scalar generalized families share the response-check path", {
  skip_if_not_installed("glmmTMB")
  families <- list(
    stats::poisson(link = "log"),
    glmmTMB::nbinom1(link = "log"),
    glmmTMB::nbinom2(link = "log"),
    glmmTMB::tweedie(link = "log"),
    stats::Gamma(link = "log"),
    glmmTMB::beta_family(link = "logit")
  )

  for (family in families) {
    data <- generalized_check_test_data(family)
    model <- glmmTMB::glmmTMB(
      outcome ~ predictor + role + (1 | dyad), data = data, family = family
    )
    expect_identical(model$fit$convergence, 0L, info = family$family)
    expect_true(model$sdr$pdHess, info = family$family)
    simulations <- simulate_dyad_responses(model, nsim = 20, seed = 459)
    center <- as.numeric(stats::predict(
      model, newdata = NULL, type = "response", re.form = NA
    ))
    expect_identical(dim(simulations$simulated_responses), c(20L, 120L))
    expect_identical(simulations$response_center, center)
    expect_identical(
      simulations$simulated_responses,
      t(as.matrix(stats::simulate(model, nsim = 20, seed = 459)))
    )

    # Formula and raw/centred behavior are covered by the deterministic pair tests.
    result <- check_partner_dependence(
      simulations, dyad = "dyad", role = "role", plot = FALSE
    )
    expect_identical(result$n_pairs, 60L)
    expect_identical(result$statistics_table$n_defined, rep(20L, 6L))
    expect_true(all(is.finite(result$replicated_statistics)))
  }
})


test_that("NB2 offsets and dispersion-only missing values preserve fitted rows", {
  skip_if_not_installed("glmmTMB")
  withr::local_seed(8120)
  data <- generalized_check_test_data(glmmTMB::nbinom2())
  data$exposure <- exp(stats::runif(nrow(data), -0.4, 0.4))
  data$dispersion_predictor <- stats::rnorm(nrow(data))
  mu <- data$exposure * exp(
    1 + 0.25 * data$predictor + 0.15 * (data$role == "male") +
      stats::rnorm(60L, sd = 0.5)[as.integer(data$dyad)]
  )
  data$outcome <- stats::rnbinom(
    nrow(data), mu = mu, size = exp(1 + 0.4 * data$dispersion_predictor)
  )
  data$exposure[2L] <- NA_real_
  data$dispersion_predictor[5L] <- NA_real_
  model <- glmmTMB::glmmTMB(
    outcome ~ predictor + role + offset(log(exposure)) + (1 | dyad),
    dispformula = ~dispersion_predictor,
    family = glmmTMB::nbinom2(), data = data, na.action = stats::na.exclude
  )
  expect_identical(model$fit$convergence, 0L)
  expect_true(model$sdr$pdHess)
  simulations <- simulate_dyad_responses(model, nsim = 10, seed = 8121)
  expect_identical(simulations$model_frame, stats::model.frame(model))
  expect_identical(simulations$observed_response, data$outcome[-c(2L, 5L)])
  expect_identical(dim(simulations$simulated_responses), c(10L, 118L))
  expect_identical(simulations$response_center, as.numeric(stats::predict(
    model, newdata = NULL, type = "response", re.form = NA
  )))
  expect_identical(
    simulations$simulated_responses,
    t(as.matrix(stats::simulate(model, nsim = 10, seed = 8121)))
  )
  result <- check_partner_dependence(
    simulations, dyad = "dyad", role = "role", plot = FALSE
  )
  expect_identical(result$n_pairs, 58L)
  expect_identical(result$n_incomplete_dyads, 2L)
})


test_that("sparse Poisson references retain each statistic's defined draws", {
  skip_if_not_installed("glmmTMB")
  withr::local_seed(44001)
  data <- data.frame(
    dyad = factor(rep(seq_len(40L), each = 2L)),
    role = factor(rep(c("female", "male"), times = 40L)),
    outcome = stats::rpois(80L, lambda = 0.12)
  )
  model <- glmmTMB::glmmTMB(outcome ~ role, data = data, family = stats::poisson())
  simulations <- simulate_dyad_responses(model, nsim = 199, seed = 44002)
  correlations <- apply(simulations$simulated_responses, 1L, function(values) {
    first <- values[data$role == "female"]
    second <- values[data$role == "male"]
    if (stats::sd(first) == 0 || stats::sd(second) == 0) return(NA_real_)
    stats::cor(first, second)
  })
  defined <- correlations[is.finite(correlations)]
  expect_gt(length(defined), 0L)
  expect_lt(length(defined), simulations$nsim)
  expect_warning(result <- check_partner_dependence(
    simulations, dyad = .env$data$dyad, role = "role",
    response = "raw", plot = FALSE
  ), "Undefined simulated summaries")
  table <- result$statistics_table
  partner <- table[table$statistic_name == "partner_correlation", ]
  expect_identical(table$n_defined, as.integer(colSums(is.finite(
    result$replicated_statistics
  ))))
  expect_equal(
    result$replicated_statistics[, "partner_correlation"], unname(correlations)
  )
  expect_equal(
    unlist(partner[c("replicated_lower", "replicated_median", "replicated_upper")],
           use.names = FALSE),
    unname(stats::quantile(defined, c(0.025, 0.5, 0.975)))
  )
  expect_equal(
    partner$observed_quantile,
    (1 + sum(defined <= partner$observed_value)) / (length(defined) + 1)
  )
  count <- paste0(length(defined), "/", simulations$nsim)
  expect_match(paste(capture.output(print(result)), collapse = "\n"), count,
               fixed = TRUE)

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  subtitles <- character()
  original_title <- graphics::title
  testthat::local_mocked_bindings(
    title = function(main = NULL, sub = NULL, ...) {
      subtitles <<- c(subtitles, sub)
      original_title(main = main, sub = sub, ...)
    },
    .package = "graphics"
  )
  plot(result, parameterization = "member", ask = FALSE)
  expect_true(any(grepl(count, subtitles, fixed = TRUE)))

  undefined_observed <- simulations
  undefined_observed$observed_response[] <- 0
  expect_error(check_partner_dependence(
    undefined_observed, dyad = .env$data$dyad, role = "role",
    response = "raw", plot = FALSE
  ), "[Oo]bserved.*undefined")
  undefined_simulations <- simulations
  undefined_simulations$simulated_responses[,] <- 0
  expect_error(check_partner_dependence(
    undefined_simulations, dyad = .env$data$dyad, role = "role",
    response = "raw", plot = FALSE
  ), "[Ee]very.*undefined|[Aa]ll.*undefined")
})


test_that("grouped binomial responses are not supported", {
  skip_if_not_installed("glmmTMB")
  data <- data.frame(successes = c(1, 3, 2, 5, 4, 7), trials = rep(10, 6))
  model <- glmmTMB::glmmTMB(
    cbind(successes, trials - successes) ~ 1, data = data, family = stats::binomial()
  )
  expect_error(simulate_dyad_responses(model, nsim = 2), "Unsupported family/link")
})
