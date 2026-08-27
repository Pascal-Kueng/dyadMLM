ild_partner_test_simulations <- function(
  n_dyads = 4L,
  n_times = 4L,
  nsim = 6L,
  omit = NULL
) {
  model_frame <- expand.grid(
    time_number = seq_len(n_times),
    member = c("member_a", "member_b"),
    dyad = seq_len(n_dyads),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  model_frame$dyad <- factor(model_frame$dyad)
  model_frame$member <- factor(
    model_frame$member,
    levels = c("member_a", "member_b")
  )
  model_frame$role <- factor(
    ifelse(model_frame$member == "member_a", "female", "male"),
    levels = c("female", "male")
  )
  model_frame$time <- factor(
    paste0("time_", model_frame$time_number),
    levels = paste0("time_", seq_len(n_times))
  )

  if (!is.null(omit)) {
    keep <- !omit(model_frame)
    model_frame <- model_frame[keep, , drop = FALSE]
  }

  dyad_number <- as.integer(model_frame$dyad)
  member_number <- as.integer(model_frame$member)
  time_number <- model_frame$time_number
  response_center <-
    2 + 0.3 * time_number - 0.2 * (member_number - 1L)
  model_centred_response <-
    0.8 * dyad_number +
    0.35 * member_number +
    (0.10 + 0.04 * dyad_number + 0.03 * member_number) * time_number +
    0.025 * (time_number + dyad_number * member_number)^2

  simulated_responses <- vapply(
    seq_len(nsim),
    function(simulation_number) {
      response_center +
        model_centred_response * (0.85 + 0.04 * simulation_number) +
        0.12 * sin(
          seq_len(nrow(model_frame)) * (0.4 + 0.09 * simulation_number)
        ) +
        0.015 * simulation_number * dyad_number * time_number
    },
    numeric(nrow(model_frame))
  )
  simulated_responses <- t(simulated_responses)

  simulations <- list(
    observed_response = response_center + model_centred_response,
    simulated_responses = simulated_responses,
    response_center = response_center,
    model_frame = model_frame,
    backend = "glmmTMB",
    family = "gaussian",
    link = "identity",
    reference = "plug-in predictive",
    random_effects = "new",
    parameter_uncertainty = "excluded",
    center = "random-effects-zero expected response",
    center_target = paste0(
      "marginal response mean over new random effects ",
      "(Gaussian identity)"
    ),
    target = paste0(
      "unconditional plug-in replication under the fitted-row design, ",
      "with all random effects newly generated"
    ),
    nsim = as.integer(nsim),
    seed = 123L,
    call = quote(simulate_dyad_responses(model))
  )
  class(simulations) <- c("dyadMLM_response_simulations", "list")
  simulations
}


ild_cross_sectional_test_simulations <- function() {
  simulations <- ild_partner_test_simulations()
  keep <- simulations$model_frame$time_number == 1L
  simulations$model_frame <-
    simulations$model_frame[keep, c("dyad", "member", "role"), drop = FALSE]
  simulations$observed_response <- simulations$observed_response[keep]
  simulations$response_center <- simulations$response_center[keep]
  simulations$simulated_responses <-
    simulations$simulated_responses[, keep, drop = FALSE]
  simulations
}


test_that("ILD arguments dispatch without changing cross-sectional results", {
  cross_simulations <- ild_cross_sectional_test_simulations()

  established_result <- check_partner_dependence(
    cross_simulations,
    dyad = "dyad",
    role = "role",
    plot = FALSE
  )
  explicit_cross_sectional_result <- check_partner_dependence(
    cross_simulations,
    dyad = "dyad",
    role = "role",
    plot = FALSE,
    member = NULL,
    time = NULL,
    lags = NULL
  )

  expect_s3_class(established_result, "dyadMLM_partner_check")
  expect_false(inherits(established_result, "dyadMLM_ild_partner_check"))
  expect_identical(
    names(explicit_cross_sectional_result),
    names(established_result)
  )
  expect_equal(
    explicit_cross_sectional_result$statistics_table,
    established_result$statistics_table
  )
  expect_equal(
    explicit_cross_sectional_result$replicated_statistics,
    established_result$replicated_statistics
  )

  repeated_simulations <- ild_partner_test_simulations()
  expect_error(
    check_partner_dependence(
      repeated_simulations,
      dyad = "dyad",
      time = "time",
      plot = FALSE
    ),
    "also requires member",
    fixed = TRUE
  )
  expect_error(
    check_partner_dependence(
      cross_simulations,
      dyad = "dyad",
      lags = 1L,
      plot = FALSE
    ),
    "only together with time",
    fixed = TRUE
  )

  numeric_time <- as.integer(repeated_simulations$model_frame$time)
  expect_error(
    check_partner_dependence(
      repeated_simulations,
      dyad = "dyad",
      member = "member",
      time = numeric_time,
      plot = FALSE
    ),
    "time must be a factor",
    fixed = TRUE
  )
  expect_error(
    check_partner_dependence(
      repeated_simulations,
      dyad = "dyad",
      member = "member",
      time = "time",
      lags = c(1, 1),
      plot = FALSE
    ),
    "distinct positive whole numbers",
    fixed = TRUE
  )
  expect_error(
    check_partner_dependence(
      repeated_simulations,
      dyad = "dyad",
      member = "member",
      time = "time",
      lags = 0,
      plot = FALSE
    ),
    "distinct positive whole numbers",
    fixed = TRUE
  )
  expect_silent(
    very_large_lag <- check_partner_dependence(
      repeated_simulations,
      dyad = "dyad",
      member = "member",
      role = "role",
      time = "time",
      lags = .Machine$integer.max,
      plot = FALSE
    )
  )
  large_lag_profiles <- very_large_lag$statistics_table$component %in%
    c("own_lag", "cross_lag")
  expect_true(all(
    very_large_lag$statistics_table$n_edges[large_lag_profiles] == 0L
  ))

  ild_result <- check_partner_dependence(
    repeated_simulations,
    dyad = "dyad",
    member = "member",
    role = "role",
    time = "time",
    plot = FALSE
  )
  expect_s3_class(ild_result, "dyadMLM_ild_partner_check")
  expect_identical(ild_result$lags, 1:5)
  expect_named(
    ild_result,
    c(
      "statistics_table", "replicated_statistics", "maps", "role_order",
      "time_levels", "lags", "weighting", "n_dyads", "response",
      "backend", "family", "link", "reference", "random_effects",
      "parameter_uncertainty", "nsim", "seed", "call"
    )
  )
  expect_named(ild_result$maps, c("rows", "concurrent", "profiles"))
  expect_named(
    ild_result$statistics_table,
    c(
      "statistic_id", "component", "curve", "lag", "statistic",
      "parameterization", "label", "weighting", "n_dyads", "n_edges",
      "structural_reason", "observed_value", "replicated_median",
      "replicated_lower_50", "replicated_upper_50", "replicated_lower",
      "replicated_upper", "observed_quantile",
      "n_defined_simulations", "minimum_defined_simulations",
      "observed_reason", "reference_reason"
    )
  )
  statistic_ids <- ild_result$statistics_table$statistic_id
  expect_identical(anyDuplicated(statistic_ids), 0L)
  expect_identical(
    colnames(ild_result$replicated_statistics),
    statistic_ids
  )
  expect_identical(
    dim(ild_result$replicated_statistics),
    c(repeated_simulations$nsim, nrow(ild_result$statistics_table))
  )
  expect_s3_class(ild_result, "dyadMLM_partner_check")
  expect_identical(
    ild_result$maps$rows$fitted_row,
    seq_len(nrow(repeated_simulations$model_frame))
  )

  concurrent <- ild_result$statistics_table$component == "concurrent"
  expect_true(all(
    ild_result$statistics_table$n_edges[concurrent] ==
      nrow(ild_result$maps$concurrent)
  ))
  for (profile in names(ild_result$maps$profiles)) {
    statistic_id <- paste(profile, "correlation", sep = "__")
    row <- match(statistic_id, statistic_ids)
    edges <- ild_result$maps$profiles[[profile]]
    expect_identical(ild_result$statistics_table$n_edges[[row]], nrow(edges))
    expect_identical(
      ild_result$statistics_table$n_dyads[[row]],
      length(unique(edges$dyad_index))
    )
  }
})


test_that("ILD response centring is explicit and applied symmetrically", {
  simulations <- ild_partner_test_simulations()
  check_with <- function(response = NULL) {
    arguments <- list(
      simulations = simulations,
      dyad = "dyad",
      member = "member",
      role = "role",
      time = "time",
      lags = 1:2,
      plot = FALSE
    )
    if (!is.null(response)) {
      arguments$response <- response
    }
    do.call(check_partner_dependence, arguments)
  }

  default <- check_with()
  centred <- check_with("model-centred")
  raw <- check_with("raw")
  expect_equal(default$statistics_table, centred$statistics_table)
  expect_equal(default$replicated_statistics, centred$replicated_statistics)
  expect_false(isTRUE(all.equal(
    raw$statistics_table$observed_value,
    centred$statistics_table$observed_value
  )))
  expect_false(isTRUE(all.equal(
    raw$replicated_statistics,
    centred$replicated_statistics
  )))
})


test_that("ILD structure validation rejects ambiguous row identities", {
  simulations <- ild_partner_test_simulations()

  duplicate_time <- simulations$model_frame$time
  duplicate_rows <- which(
    simulations$model_frame$dyad == "1" &
      simulations$model_frame$member == "member_a"
  )
  duplicate_time[duplicate_rows[[2L]]] <- duplicate_time[duplicate_rows[[1L]]]
  expect_error(
    check_partner_dependence(
      simulations,
      dyad = "dyad",
      member = "member",
      time = duplicate_time,
      plot = FALSE
    ),
    "dyad-member-time key",
    fixed = TRUE
  )

  one_member <- as.character(simulations$model_frame$member)
  one_member[simulations$model_frame$dyad == "1"] <- "member_a"
  expect_error(
    check_partner_dependence(
      simulations,
      dyad = "dyad",
      member = one_member,
      time = "time",
      plot = FALSE
    ),
    "exactly two stable member identities",
    fixed = TRUE
  )

  changing_role <- as.character(simulations$model_frame$role)
  changing_role[which(
    simulations$model_frame$dyad == "1" &
      simulations$model_frame$member == "member_a"
  )[[1L]]] <- "male"
  expect_error(
    check_partner_dependence(
      simulations,
      dyad = "dyad",
      member = "member",
      role = changing_role,
      time = "time",
      plot = FALSE
    ),
    "stable role",
    fixed = TRUE
  )

  explicit_missing_time <- addNA(simulations$model_frame$time)
  expect_error(
    check_partner_dependence(
      simulations,
      dyad = "dyad",
      member = "member",
      role = "role",
      time = explicit_missing_time,
      plot = FALSE
    ),
    "cannot have missing",
    fixed = TRUE
  )

  explicit_missing_member <- addNA(simulations$model_frame$member)
  explicit_missing_member[[1L]] <- NA
  expect_error(
    check_partner_dependence(
      simulations,
      dyad = "dyad",
      member = explicit_missing_member,
      role = "role",
      time = "time",
      plot = FALSE
    ),
    "cannot have missing",
    fixed = TRUE
  )

  explicit_missing_role <- addNA(simulations$model_frame$role)
  explicit_missing_role[[1L]] <- NA
  expect_error(
    check_partner_dependence(
      simulations,
      dyad = "dyad",
      member = "member",
      role = explicit_missing_role,
      time = "time",
      plot = FALSE
    ),
    "cannot have missing",
    fixed = TRUE
  )

  explicit_missing_dyad <- addNA(simulations$model_frame$dyad)
  explicit_missing_dyad[[1L]] <- NA
  expect_error(
    check_partner_dependence(
      simulations,
      dyad = explicit_missing_dyad,
      member = "member",
      role = "role",
      time = "time",
      plot = FALSE
    ),
    "cannot have missing",
    fixed = TRUE
  )

  cross_simulations <- ild_cross_sectional_test_simulations()
  duplicate_cross_member <- as.character(
    cross_simulations$model_frame$member
  )
  duplicate_cross_member[cross_simulations$model_frame$dyad == "1"] <-
    "member_a"
  expect_error(
    check_partner_dependence(
      cross_simulations,
      dyad = "dyad",
      member = duplicate_cross_member,
      plot = FALSE
    ),
    "two distinct members",
    fixed = TRUE
  )

  explicit_missing_cross_member <- addNA(
    cross_simulations$model_frame$member
  )
  explicit_missing_cross_member[[1L]] <- NA
  expect_error(
    check_partner_dependence(
      cross_simulations,
      dyad = "dyad",
      member = explicit_missing_cross_member,
      plot = FALSE
    ),
    "cannot be missing",
    fixed = TRUE
  )
})


test_that("public lag statistics respect unused scheduled time levels", {
  simulations <- ild_partner_test_simulations(
    n_dyads = 4L,
    omit = function(data) data$time_number == 2L
  )
  dyad <- as.integer(simulations$model_frame$dyad)
  time <- simulations$model_frame$time_number
  x <- c(-2, -1, 1, 2)
  y <- c(-1, 2, -2, 1)
  female <- ifelse(time == 1L, -x[dyad] - y[dyad], x[dyad])
  female[time == 4L] <- y[dyad[time == 4L]]
  male <- -0.4 * female + 0.2 * dyad
  values <- ifelse(
    simulations$model_frame$role == "female",
    female,
    male
  )
  simulations$observed_response <- simulations$response_center + values

  result <- check_partner_dependence(
    simulations,
    dyad = "dyad",
    member = "member",
    role = "role",
    time = "time",
    lags = 1:2,
    plot = FALSE
  )
  female_profile <- result$statistics_table[
    result$statistics_table$component == "own_lag" &
      result$statistics_table$curve == "female",
    ,
    drop = FALSE
  ]

  expect_equal(
    female_profile$observed_value[female_profile$lag == 1L],
    stats::cor(x, y)
  )
  expect_equal(
    female_profile$observed_value[female_profile$lag == 2L],
    stats::cor(-x - y, x)
  )
  expect_false(isTRUE(all.equal(stats::cor(x, y), stats::cor(-x - y, x))))

  row_time <- result$maps$rows$time_index
  lag_1 <- result$maps$profiles$own_lag__role_1__lag1
  lag_2 <- result$maps$profiles$own_lag__role_1__lag2
  expect_true(all(
    row_time[lag_1$end_row] - row_time[lag_1$start_row] == 1L
  ))
  expect_true(all(
    row_time[lag_2$end_row] - row_time[lag_2$start_row] == 2L
  ))
  expect_false(any(
    row_time[lag_1$start_row] == 1L & row_time[lag_1$end_row] == 3L
  ))
})


test_that("member demeaning is recomputed for every simulated dataset", {
  simulations <- ild_partner_test_simulations(nsim = 6L)
  dyad <- as.integer(simulations$model_frame$dyad)
  member <- as.integer(simulations$model_frame$member)
  for (simulation in seq_len(simulations$nsim)) {
    member_offset <-
      0.08 * simulation * dyad^2 * ifelse(member == 1L, 1, -0.6) +
      0.03 * simulation * dyad * member
    simulations$simulated_responses[simulation, ] <-
      simulations$observed_response + member_offset
  }

  result <- check_partner_dependence(
    simulations,
    dyad = "dyad",
    member = "member",
    role = "role",
    time = "time",
    lags = 1:2,
    plot = FALSE
  )
  observed <- stats::setNames(
    result$statistics_table$observed_value,
    result$statistics_table$statistic_id
  )
  within_ids <- result$statistics_table$statistic_id[
    result$statistics_table$component != "stable"
  ]
  expected_within <- matrix(
    observed[within_ids],
    nrow = simulations$nsim,
    ncol = length(within_ids),
    byrow = TRUE
  )
  expect_equal(
    unname(result$replicated_statistics[, within_ids, drop = FALSE]),
    unname(expected_within),
    tolerance = 1e-12
  )

  stable_ids <- result$statistics_table$statistic_id[
    result$statistics_table$component == "stable"
  ]
  stable_difference <- sweep(
    result$replicated_statistics[, stable_ids, drop = FALSE],
    2L,
    observed[stable_ids],
    "-"
  )
  expect_true(any(abs(stable_difference) > 1e-8))
})


test_that("distinguishable profile maps retain both role directions", {
  simulations <- ild_partner_test_simulations(n_dyads = 3L)
  design <- prepare_ild_design(
    dyad_values = simulations$model_frame$dyad,
    member_values = simulations$model_frame$member,
    role_values = simulations$model_frame$role,
    time_values = simulations$model_frame$time,
    lags = 2L
  )

  female_to_male <-
    design$profiles$cross_lag__role_1_to_role_2__lag2$edges
  male_to_female <-
    design$profiles$cross_lag__role_2_to_role_1__lag2$edges
  roles <- design$rows$role
  times <- design$rows$time_index

  expect_identical(design$role_order, c("female", "male"))
  expect_true(all(roles[female_to_male$start_row] == "female"))
  expect_true(all(roles[female_to_male$end_row] == "male"))
  expect_true(all(roles[male_to_female$start_row] == "male"))
  expect_true(all(roles[male_to_female$end_row] == "female"))
  expect_true(all(
    times[female_to_male$end_row] -
      times[female_to_male$start_row] == 2L
  ))
  expect_true(all(
    times[male_to_female$end_row] -
      times[male_to_female$start_row] == 2L
  ))

  result <- check_partner_dependence(
    simulations,
    dyad = "dyad",
    member = "member",
    role = "role",
    time = "time",
    lags = 2L,
    plot = FALSE
  )
  expect_identical(result$role_order, c("female", "male"))
  cross_lag <- result$statistics_table[
    result$statistics_table$component == "cross_lag",
    ,
    drop = FALSE
  ]
  expect_setequal(
    cross_lag$curve,
    c("female -> male", "male -> female")
  )
})


test_that("exchangeable ILD results are invariant to dyad-specific label swaps", {
  simulations <- ild_partner_test_simulations()
  original_member <- as.character(simulations$model_frame$member)
  swapped_member <- original_member
  swap_rows <- simulations$model_frame$dyad %in% c("1", "3")
  swapped_member[swap_rows] <- ifelse(
    swapped_member[swap_rows] == "member_a",
    "member_b",
    "member_a"
  )

  original_result <- check_partner_dependence(
    simulations,
    dyad = "dyad",
    member = original_member,
    time = "time",
    lags = 1:3,
    weighting = "dyad",
    plot = FALSE
  )
  swapped_result <- check_partner_dependence(
    simulations,
    dyad = "dyad",
    member = swapped_member,
    time = "time",
    lags = 1:3,
    weighting = "dyad",
    plot = FALSE
  )

  expect_equal(
    swapped_result$statistics_table,
    original_result$statistics_table
  )
  expect_equal(
    swapped_result$replicated_statistics,
    original_result$replicated_statistics
  )
})


test_that("public ILD checks apply dyad and edge weighting", {
  simulations <- ild_partner_test_simulations(
    n_dyads = 4L,
    n_times = 5L,
    omit = function(data) {
      (data$dyad == "2" & data$time_number == 5L) |
        (data$dyad == "3" & data$time_number %in% 4:5)
    }
  )
  check_with <- function(weighting) {
    check_partner_dependence(
      simulations,
      dyad = "dyad",
      member = "member",
      role = "role",
      time = "time",
      lags = 1L,
      weighting = weighting,
      plot = FALSE
    )
  }
  dyad_result <- check_with("dyad")
  edge_result <- check_with("edge")

  stable_ids <- dyad_result$statistics_table$statistic_id[
    dyad_result$statistics_table$component == "stable"
  ]
  expect_equal(
    dyad_result$replicated_statistics[, stable_ids, drop = FALSE],
    edge_result$replicated_statistics[, stable_ids, drop = FALSE]
  )
  expect_equal(
    dyad_result$statistics_table[
      dyad_result$statistics_table$component == "stable",
      "observed_value"
    ],
    edge_result$statistics_table[
      edge_result$statistics_table$component == "stable",
      "observed_value"
    ]
  )

  profile_id <- "own_lag__role_1__lag1"
  statistic_id <- paste(profile_id, "correlation", sep = "__")
  rows <- dyad_result$maps$rows
  values <- simulations$observed_response - simulations$response_center
  member <- interaction(rows$dyad_index, rows$member_slot, drop = TRUE)
  within <- values - ave(values, member, FUN = mean)
  edges <- dyad_result$maps$profiles[[profile_id]]
  x <- within[edges$start_row]
  y <- within[edges$end_row]
  cluster <- match(edges$dyad_index, unique(edges$dyad_index))

  manual_correlation <- function(weighting) {
    weights <- if (weighting == "dyad") {
      counts <- tabulate(cluster, nbins = max(cluster))
      1 / (max(cluster) * counts[cluster])
    } else {
      rep(1 / length(cluster), length(cluster))
    }
    x_centred <- x - sum(weights * x)
    y_centred <- y - sum(weights * y)
    sum(weights * x_centred * y_centred) /
      sqrt(
        sum(weights * x_centred^2) *
          sum(weights * y_centred^2)
      )
  }
  observed_profile <- function(result) {
    result$statistics_table$observed_value[
      result$statistics_table$statistic_id == statistic_id
    ]
  }

  expect_equal(observed_profile(dyad_result), manual_correlation("dyad"))
  expect_equal(observed_profile(edge_result), manual_correlation("edge"))
  expect_gt(
    abs(observed_profile(dyad_result) - observed_profile(edge_result)),
    1e-6
  )
})


test_that("exchangeable dyad weights span both pooled directions", {
  simulations <- ild_partner_test_simulations(
    n_dyads = 4L,
    n_times = 5L,
    omit = function(data) {
      (data$dyad == "2" & data$member == "member_a" &
        data$time_number %in% 4:5) |
        (data$dyad == "3" & data$member == "member_b" &
          data$time_number %in% 1:2)
    }
  )
  result <- check_partner_dependence(
    simulations,
    dyad = "dyad",
    member = "member",
    time = "time",
    lags = 1L,
    weighting = "dyad",
    plot = FALSE
  )

  profile_id <- "cross_lag__pooled_directions__lag1"
  edges <- result$maps$profiles[[profile_id]]
  rows <- result$maps$rows
  values <- simulations$observed_response - simulations$response_center
  member <- interaction(rows$dyad_index, rows$member_slot, drop = TRUE)
  within <- values - ave(values, member, FUN = mean)
  cluster <- match(edges$dyad_index, unique(edges$dyad_index))
  counts <- tabulate(cluster, nbins = max(cluster))
  weights <- 1 / (max(cluster) * counts[cluster])
  x <- within[edges$start_row]
  y <- within[edges$end_row]
  x <- x - sum(weights * x)
  y <- y - sum(weights * y)
  expected <- sum(weights * x * y) /
    sqrt(sum(weights * x^2) * sum(weights * y^2))

  statistic_id <- paste(profile_id, "correlation", sep = "__")
  observed <- result$statistics_table$observed_value[
    result$statistics_table$statistic_id == statistic_id
  ]
  expect_gt(length(unique(counts)), 1L)
  expect_equal(observed, expected)
})


test_that("dyad and edge weighting follow the prespecified moments", {
  cluster <- c(1L, 1L, 1L, 2L, 3L)
  x <- c(0, 2, 5, 8, 13)
  y <- c(1, 4, 3, 11, 7)

  manual_moments <- function(weights) {
    correction <- 3 / 2
    mean_x <- sum(weights * x)
    mean_y <- sum(weights * y)
    variance_x <- correction * sum(weights * (x - mean_x)^2)
    variance_y <- correction * sum(weights * (y - mean_y)^2)
    covariance <-
      correction * sum(weights * (x - mean_x) * (y - mean_y))
    c(
      variance_x = variance_x,
      variance_y = variance_y,
      covariance = covariance,
      correlation = covariance / sqrt(variance_x * variance_y)
    )
  }

  dyad_weights <- c(rep(1 / 9, 3), 1 / 3, 1 / 3)
  edge_weights <- rep(1 / 5, 5)
  dyad_moments <- calculate_pair_moments(
    x, y, cluster, weighting = "dyad"
  )
  edge_moments <- calculate_pair_moments(
    x, y, cluster, weighting = "edge"
  )

  expect_equal(dyad_moments, manual_moments(dyad_weights))
  expect_equal(edge_moments, manual_moments(edge_weights))
  expect_false(isTRUE(all.equal(dyad_moments, edge_moments)))

  balanced_cluster <- rep(1:3, each = 2)
  balanced_x <- c(0, 2, 5, 8, 13, 15)
  balanced_y <- c(1, 4, 3, 11, 7, 12)
  expect_equal(
    calculate_pair_moments(
      balanced_x, balanced_y, balanced_cluster, weighting = "dyad"
    ),
    calculate_pair_moments(
      balanced_x, balanced_y, balanced_cluster, weighting = "edge"
    )
  )
})


test_that("stable ILD summaries equal a cross-sectional member-mean check", {
  simulations <- ild_partner_test_simulations(nsim = 6L)
  ild_result <- check_partner_dependence(
    simulations,
    dyad = "dyad",
    member = "member",
    role = "role",
    time = "time",
    lags = 1L,
    plot = FALSE
  )

  rows <- ild_result$maps$rows
  member_ids <- seq_len(2L * ild_result$n_dyads)
  member_mean <- function(values) {
    unname(vapply(
      member_ids,
      function(member_id) mean(values[rows$member_id == member_id]),
      numeric(1)
    ))
  }
  cross_simulations <- simulations
  member_rows <- rows[!duplicated(rows$member_id), ]
  member_rows <- member_rows[order(member_rows$member_id), ]
  cross_simulations$model_frame <- member_rows[c("dyad", "member", "role")]
  cross_simulations$observed_response <- member_mean(
    simulations$observed_response - simulations$response_center
  )
  cross_simulations$response_center <- rep(0, length(member_ids))
  cross_simulations$simulated_responses <- t(vapply(
    seq_len(simulations$nsim),
    function(simulation) {
      member_mean(
        simulations$simulated_responses[simulation, ] -
          simulations$response_center
      )
    },
    numeric(length(member_ids))
  ))
  cross_result <- check_partner_dependence(
    cross_simulations,
    dyad = "dyad",
    member = "member",
    role = "role",
    response = "raw",
    plot = FALSE
  )

  stable_ids <- paste(
    "stable",
    cross_result$statistics_table$statistic_name,
    sep = "__"
  )
  stable_rows <- match(
    stable_ids,
    ild_result$statistics_table$statistic_id
  )
  expect_equal(
    ild_result$statistics_table$observed_value[stable_rows],
    cross_result$statistics_table$observed_value
  )
  expect_equal(
    unname(ild_result$replicated_statistics[, stable_ids, drop = FALSE]),
    unname(cross_result$replicated_statistics)
  )
})


test_that("unsupported lags and undefined correlations remain auditable", {
  simulations <- ild_partner_test_simulations(nsim = 21L)
  simulations$simulated_responses[1L, ] <- simulations$response_center

  result <- check_partner_dependence(
    simulations,
    dyad = "dyad",
    member = "member",
    role = "role",
    time = "time",
    lags = c(1L, 4L),
    plot = FALSE
  )

  supported <- result$statistics_table[
    result$statistics_table$component == "own_lag" &
      result$statistics_table$lag == 1L &
      result$statistics_table$curve == "female",
    ,
    drop = FALSE
  ]
  expect_identical(supported$n_defined_simulations, 20L)
  expect_identical(supported$minimum_defined_simulations, 20L)
  expect_true(is.finite(supported$replicated_lower))
  supported_replicates <-
    result$replicated_statistics[, supported$statistic_id, drop = TRUE]
  defined_replicates <- supported_replicates[is.finite(supported_replicates)]
  expect_equal(
    supported$observed_quantile,
    (1 + sum(defined_replicates <= supported$observed_value)) /
      (length(defined_replicates) + 1)
  )

  unsupported <- result$statistics_table[
    result$statistics_table$component %in% c("own_lag", "cross_lag") &
      result$statistics_table$lag == 4L,
    ,
    drop = FALSE
  ]
  expect_gt(nrow(unsupported), 0L)
  expect_true(all(unsupported$n_dyads == 0L))
  expect_true(all(unsupported$n_edges == 0L))
  expect_true(all(is.na(unsupported$observed_value)))
  expect_true(all(unsupported$n_defined_simulations == 0L))
  expect_true(all(
    unsupported$observed_reason == "fewer than three contributing dyads"
  ))
  expect_true(all(
    unsupported$reference_reason == "too few defined simulated statistics"
  ))

  zero_observed <- simulations
  zero_observed$observed_response <- zero_observed$response_center
  zero_result <- check_partner_dependence(
    zero_observed,
    dyad = "dyad",
    member = "member",
    role = "role",
    time = "time",
    lags = 1L,
    plot = FALSE
  )
  zero_profile <- zero_result$statistics_table[
    zero_result$statistics_table$component == "own_lag" &
      zero_result$statistics_table$curve == "female",
    ,
    drop = FALSE
  ]
  expect_true(is.na(zero_profile$observed_value))
  expect_identical(
    zero_profile$observed_reason,
    "zero variance or numerical degeneracy"
  )
  expect_true(is.finite(zero_profile$replicated_median))
})


test_that("ILD results do not depend on fitted-row order", {
  simulations <- ild_partner_test_simulations()
  original_result <- check_partner_dependence(
    simulations,
    dyad = "dyad",
    member = "member",
    role = "role",
    time = "time",
    lags = 1:3,
    weighting = "dyad",
    plot = FALSE
  )

  reordered <- simulations
  row_order <- rev(seq_len(nrow(simulations$model_frame)))
  reordered$model_frame <-
    simulations$model_frame[row_order, , drop = FALSE]
  reordered$observed_response <- simulations$observed_response[row_order]
  reordered$response_center <- simulations$response_center[row_order]
  reordered$simulated_responses <-
    simulations$simulated_responses[, row_order, drop = FALSE]

  reordered_result <- check_partner_dependence(
    reordered,
    dyad = "dyad",
    member = "member",
    role = "role",
    time = "time",
    lags = 1:3,
    weighting = "dyad",
    plot = FALSE
  )

  expect_equal(
    reordered_result$statistics_table,
    original_result$statistics_table
  )
  expect_equal(
    reordered_result$replicated_statistics,
    original_result$replicated_statistics
  )
})


test_that("ILD print and plot methods dispatch and return invisibly", {
  simulations <- ild_partner_test_simulations(nsim = 21L)
  result <- check_partner_dependence(
    simulations,
    dyad = "dyad",
    member = "member",
    role = "role",
    time = "time",
    lags = c(1L, 4L),
    weighting = "dyad",
    plot = FALSE
  )

  expect_output(
    printed <- print(result),
    "Stable partner dependence"
  )
  expect_identical(printed, result)
  expect_output(print(result), "Weighting: dyad", fixed = TRUE)
  expect_output(print(result), "Cross-member lag profile", fixed = TRUE)

  previous_device <- grDevices::dev.cur()
  grDevices::pdf(NULL)
  on.exit({
    if (grDevices::dev.cur() != previous_device) {
      grDevices::dev.off()
    }
  }, add = TRUE)
  expect_invisible(plot(result, ask = FALSE))
  grDevices::dev.off()
})
