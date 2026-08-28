scalar_generalized_test_model <- function(
  family = glmmTMB::nbinom2(link = "log"),
  dispformula = ~1
) {
  set.seed(8110)
  n_dyads <- 60L
  test_data <- data.frame(
    dyad = factor(rep(seq_len(n_dyads), each = 2L)),
    batch = factor(rep(seq_len(12L), each = 10L)),
    role = factor(rep(c("female", "male"), times = n_dyads)),
    predictor = rep(c(-0.75, 0.25, 0.75, -0.25), length.out = 2L * n_dyads)
  )
  dyad_effect <- stats::rnorm(n_dyads, sd = 0.35)
  linear_predictor <-
    1 +
    0.25 * test_data$predictor +
    0.15 * (test_data$role == "male") +
    dyad_effect[as.integer(test_data$dyad)]
  response_mean <- if (identical(family$family, "beta")) {
    stats::plogis(linear_predictor - 1)
  } else {
    exp(linear_predictor)
  }

  test_data$outcome <- switch(
    family$family,
    poisson = stats::rpois(nrow(test_data), lambda = response_mean),
    nbinom1 = stats::rnbinom(
      nrow(test_data),
      mu = response_mean,
      size = response_mean / 0.8
    ),
    nbinom2 = stats::rnbinom(
      nrow(test_data),
      mu = response_mean,
      size = 2.5
    ),
    tweedie = {
      power <- 1.5
      dispersion <- 0.8
      poisson_rate <- response_mean^(2 - power) /
        (dispersion * (2 - power))
      event_count <- stats::rpois(nrow(test_data), poisson_rate)
      response <- numeric(nrow(test_data))
      positive <- event_count > 0L
      response[positive] <- stats::rgamma(
        sum(positive),
        shape = event_count[positive] * (2 - power) / (power - 1),
        scale = dispersion * (power - 1) *
          response_mean[positive]^(power - 1)
      )
      response
    },
    Gamma = stats::rgamma(
      nrow(test_data),
      shape = 5,
      scale = response_mean / 5
    ),
    beta = stats::rbeta(
      nrow(test_data),
      shape1 = response_mean * 20,
      shape2 = (1 - response_mean) * 20
    ),
    stop("Unsupported test family.", call. = FALSE)
  )

  glmmTMB::glmmTMB(
    outcome ~ predictor + role + (1 | dyad),
    dispformula = dispformula,
    family = family,
    data = test_data
  )
}
