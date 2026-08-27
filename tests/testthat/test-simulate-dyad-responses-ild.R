make_gaussian_ild_ar1_test_data <- function(
  seed = 8701L,
  n_dyads = 24L,
  occasions = 0:5
) {
  set.seed(seed)

  test_data <- expand.grid(
    member = factor(c("a", "b"), levels = c("a", "b")),
    occasion = occasions,
    dyad = factor(seq_len(n_dyads)),
    KEEP.OUT.ATTRS = FALSE
  )
  test_data <- test_data[
    order(test_data$dyad, test_data$occasion, test_data$member),
  ]
  row.names(test_data) <- NULL

  test_data$role_a <- as.numeric(test_data$member == "a")
  test_data$role_b <- as.numeric(test_data$member == "b")
  test_data$occasion_c <- test_data$occasion - mean(occasions)
  test_data$occasion_f <- factor(
    test_data$occasion,
    levels = occasions
  )
  test_data$member_series <- interaction(
    test_data$dyad,
    test_data$member,
    drop = TRUE
  )
  test_data$dyad_occasion <- interaction(
    test_data$dyad,
    test_data$occasion_f,
    drop = TRUE
  )
  test_data$row_key <- paste0(
    "dyad_", test_data$dyad,
    "_member_", test_data$member,
    "_occasion_", test_data$occasion
  )

  n_occasions <- length(occasions)
  n_series <- n_dyads * 2L
  ar_sd <- 0.70
  ar_correlation <- 0.55
  member_process <- matrix(
    NA_real_,
    nrow = n_series,
    ncol = n_occasions
  )
  member_process[, 1L] <- stats::rnorm(n_series, sd = ar_sd)
  for (occasion_index in 2:n_occasions) {
    member_process[, occasion_index] <-
      ar_correlation * member_process[, occasion_index - 1L] +
      stats::rnorm(
        n_series,
        sd = ar_sd * sqrt(1 - ar_correlation^2)
      )
  }

  dyad_occasion_effect <- stats::rnorm(
    n_dyads * n_occasions,
    sd = 0.45
  )
  dyad_index <- as.integer(test_data$dyad)
  occasion_index <- match(test_data$occasion, occasions)
  member_series_index <- as.integer(test_data$member_series)
  dyad_occasion_index <-
    (dyad_index - 1L) * n_occasions + occasion_index

  test_data$outcome <-
    1.8 * test_data$role_a +
    2.2 * test_data$role_b +
    0.06 * test_data$occasion_c +
    member_process[cbind(member_series_index, occasion_index)] +
    dyad_occasion_effect[dyad_occasion_index] +
    stats::rnorm(nrow(test_data), sd = 0.25)

  row.names(test_data) <- test_data$row_key
  test_data
}


make_gaussian_ild_mean_difference_test_data <- function(
  seed = 8711L,
  n_dyads = 28L,
  occasions = 0:5
) {
  set.seed(seed)

  test_data <- expand.grid(
    member = factor(c("a", "b"), levels = c("a", "b")),
    occasion = occasions,
    dyad = factor(seq_len(n_dyads)),
    KEEP.OUT.ATTRS = FALSE
  )
  test_data <- test_data[
    order(test_data$dyad, test_data$occasion, test_data$member),
  ]
  row.names(test_data) <- NULL

  test_data$role_a <- as.numeric(test_data$member == "a")
  test_data$role_b <- as.numeric(test_data$member == "b")
  test_data$member_difference <- ifelse(
    test_data$member == "a",
    1,
    -1
  )
  test_data$occasion_c <- test_data$occasion - mean(occasions)
  test_data$occasion_f <- factor(
    test_data$occasion,
    levels = occasions
  )

  simulate_ar_process <- function(standard_deviation, correlation) {
    process <- matrix(
      NA_real_,
      nrow = n_dyads,
      ncol = length(occasions)
    )
    process[, 1L] <- stats::rnorm(
      n_dyads,
      sd = standard_deviation
    )
    for (occasion_index in 2:length(occasions)) {
      process[, occasion_index] <-
        correlation * process[, occasion_index - 1L] +
        stats::rnorm(
          n_dyads,
          sd = standard_deviation * sqrt(1 - correlation^2)
        )
    }
    process
  }

  shared_process <- simulate_ar_process(
    standard_deviation = 0.80,
    correlation = 0.65
  )
  difference_process <- simulate_ar_process(
    standard_deviation = 0.50,
    correlation = 0.30
  )
  process_index <- cbind(
    as.integer(test_data$dyad),
    match(test_data$occasion, occasions)
  )

  test_data$outcome <-
    1.8 * test_data$role_a +
    2.2 * test_data$role_b +
    0.06 * test_data$occasion_c +
    shared_process[process_index] +
    test_data$member_difference * difference_process[process_index]

  test_data
}


test_that("ILD response simulation preserves fitted rows and model state", {
  skip_if_not_installed("glmmTMB")

  test_data <- make_gaussian_ild_ar1_test_data()
  set.seed(8702)
  test_data <- test_data[sample.int(nrow(test_data)), ]
  omitted_rows <- c(
    "dyad_3_member_a_occasion_2",
    "dyad_7_member_b_occasion_4",
    "dyad_19_member_a_occasion_5"
  )
  test_data$outcome[row.names(test_data) %in% omitted_rows] <- NA_real_

  model <- glmmTMB::glmmTMB(
    outcome ~
      0 + role_a + role_b + occasion_c +
      ar1(0 + occasion_f | member_series) +
      (1 | dyad_occasion),
    family = stats::gaussian(),
    data = test_data,
    na.action = stats::na.omit
  )

  expect_identical(model$fit$convergence, 0L)
  expect_true(model$sdr$pdHess)

  original_codes <- get_glmmTMB_simulation_codes(model)
  on.exit(set_glmmTMB_simulation_codes(model, original_codes), add = TRUE)

  caller_codes <- original_codes
  caller_codes$terms[] <- rep(
    c(0, 1),
    length.out = length(caller_codes$terms)
  )
  set_glmmTMB_simulation_codes(model, caller_codes)
  original_parameters <- model$fit$par

  set.seed(8703)
  caller_rng_state <- .Random.seed
  simulations <- simulate_dyad_responses(
    model,
    nsim = 7,
    seed = 8704
  )

  fitted_frame <- stats::model.frame(model)
  expected_row_names <- row.names(test_data)[
    is.finite(test_data$outcome)
  ]
  expected_center <- drop(
    stats::model.matrix(model, component = "cond") %*%
      glmmTMB::fixef(model)$cond
  )

  expect_identical(row.names(fitted_frame), expected_row_names)
  expect_identical(simulations$model_frame, fitted_frame)
  expect_identical(
    simulations$observed_response,
    as.numeric(stats::model.response(fitted_frame))
  )
  expect_equal(simulations$response_center, unname(expected_center))
  expect_identical(
    dim(simulations$simulated_responses),
    c(7L, nrow(fitted_frame))
  )
  expect_false(anyNA(simulations$simulated_responses))

  expect_identical(
    get_glmmTMB_simulation_codes(model),
    caller_codes
  )
  expect_identical(model$fit$par, original_parameters)
  expect_identical(.Random.seed, caller_rng_state)

  unconditional_codes <- lapply(
    original_codes,
    function(codes) rep(2, length(codes))
  )
  set_glmmTMB_simulation_codes(model, unconditional_codes)
  expected_simulations <- withr::with_seed(
    8704,
    t(as.matrix(stats::simulate(model, nsim = 7)))
  )
  set_glmmTMB_simulation_codes(model, caller_codes)

  expect_identical(
    simulations$simulated_responses,
    expected_simulations
  )
  expect_identical(
    get_glmmTMB_simulation_codes(model),
    caller_codes
  )

  fitted_row_index <- match(row.names(fitted_frame), row.names(test_data))
  end_to_end_check <- check_partner_dependence(
    simulations,
    dyad = test_data$dyad[fitted_row_index],
    role = test_data$member[fitted_row_index],
    member = test_data$member[fitted_row_index],
    time = test_data$occasion_f[fitted_row_index],
    lags = 1:2,
    weighting = "dyad",
    plot = FALSE
  )
  expect_s3_class(
    end_to_end_check,
    "dyadMLM_ild_partner_check"
  )
  expect_identical(end_to_end_check$n_dyads, 24L)
  expect_true(all(
    end_to_end_check$statistics_table$n_defined_simulations == 7L
  ))
  expect_true(all(end_to_end_check$statistics_table$n_edges > 0L))
})


test_that("mean-difference AR processes simulate as a structured ILD model", {
  skip_if_not_installed("glmmTMB")

  test_data <- make_gaussian_ild_mean_difference_test_data()
  model <- glmmTMB::glmmTMB(
    outcome ~
      0 + role_a + role_b + occasion_c +
      ar1(0 + occasion_f | dyad) +
      ar1(0 + member_difference:occasion_f | dyad),
    dispformula = ~0,
    family = stats::gaussian(),
    data = test_data
  )

  expect_identical(model$fit$convergence, 0L)
  expect_true(model$sdr$pdHess)
  expect_length(glmmTMB::getME(model, "theta"), 4L)

  original_codes <- get_glmmTMB_simulation_codes(model)
  simulations <- simulate_dyad_responses(
    model,
    nsim = 6,
    seed = 8712
  )

  expect_identical(
    dim(simulations$simulated_responses),
    c(6L, nrow(test_data))
  )
  expect_true(all(is.finite(simulations$simulated_responses)))
  expect_identical(simulations$model_frame, stats::model.frame(model))
  expect_identical(
    get_glmmTMB_simulation_codes(model),
    original_codes
  )
})
