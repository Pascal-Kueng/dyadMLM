plot_mahalanobis <- function(data, x, y, dyad = "couple_id",
                             n_labels = 4, title = NULL) {
  required_columns <- c(x, y, dyad)
  missing_columns <- setdiff(required_columns, names(data))

  if (length(missing_columns) > 0) {
    stop(
      "Missing columns: ", paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }

  plot_data <- data[stats::complete.cases(data[required_columns]), , drop = FALSE]
  xy <- plot_data[c(x, y)]

  if (!all(vapply(xy, is.numeric, logical(1)))) {
    stop("Both x and y must be numeric.", call. = FALSE)
  }

  if (nrow(plot_data) < 3 || qr(stats::cov(xy))$rank < 2) {
    stop(
      "Mahalanobis distance requires at least three complete, non-collinear observations.",
      call. = FALSE
    )
  }

  plot_data$.mahalanobis_distance <- stats::mahalanobis(
    xy,
    center = colMeans(xy),
    cov = stats::cov(xy)
  )

  label_order <- order(
    plot_data$.mahalanobis_distance,
    decreasing = TRUE
  )
  label_order <- head(label_order, n_labels)
  label_data <- plot_data[label_order, , drop = FALSE]

  ggplot2::ggplot(
    plot_data,
    ggplot2::aes(x = .data[[x]], y = .data[[y]])
  ) +
    ggplot2::geom_point(color = "steelblue") +
    ggplot2::geom_smooth(
      method = "lm",
      formula = y ~ x,
      se = FALSE,
      color = "navy",
      linewidth = 1.1
    ) +
    ggplot2::geom_text(
      data = label_data,
      ggplot2::aes(label = .data[[dyad]]),
      vjust = -0.6,
      check_overlap = TRUE
    ) +
    ggplot2::labs(
      title = title,
      x = x,
      y = y,
      caption = paste(
        "Labels mark the",
        min(n_labels, nrow(plot_data)),
        "largest Mahalanobis distances."
      )
    ) +
    ggplot2::scale_y_continuous(
      expand = ggplot2::expansion(mult = c(0.05, 0.12))
    ) +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(
      plot.title.position = "panel",
      plot.title = ggplot2::element_text(hjust = 0.5)
    )
}

make_ild_ar1_start <- function(
    data,
    stable_sd = c(female = 0.50, male = 0.50),
    stable_rho = 0.20,
    ar_sd = c(female = 0.50, male = 0.50),
    ar_rho = c(female = 0.50, male = 0.50),
    same_day_sd = c(female = 0.50, male = 0.50),
    same_day_rho = 0.20) {
  required_columns <- c(
    "closeness",
    ".is_female",
    ".is_male",
    "diaryday_c",
    ".provided_support_cwp_actor",
    ".provided_support_cwp_partner",
    ".provided_support_cbp_actor",
    ".provided_support_cbp_partner"
  )
  missing_columns <- setdiff(required_columns, names(data))
  if (length(missing_columns) > 0L) {
    stop(
      "Missing columns: ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }
  if (length(stable_sd) != 2L ||
      any(!is.finite(stable_sd)) ||
      any(stable_sd <= 0)) {
    stop("stable_sd must contain two positive finite values.", call. = FALSE)
  }
  if (length(ar_sd) != 2L || any(!is.finite(ar_sd)) || any(ar_sd <= 0)) {
    stop("ar_sd must contain two positive finite values.", call. = FALSE)
  }
  if (length(same_day_sd) != 2L ||
      any(!is.finite(same_day_sd)) ||
      any(same_day_sd <= 0)) {
    stop("same_day_sd must contain two positive finite values.", call. = FALSE)
  }
  if (length(ar_rho) != 2L ||
      any(!is.finite(ar_rho)) ||
      any(abs(ar_rho) >= 1)) {
    stop("ar_rho must contain two finite values between -1 and 1.", call. = FALSE)
  }
  if (length(stable_rho) != 1L ||
      !is.finite(stable_rho) ||
      abs(stable_rho) >= 1) {
    stop(
      "stable_rho must be one finite value between -1 and 1.",
      call. = FALSE
    )
  }
  if (length(same_day_rho) != 1L ||
      !is.finite(same_day_rho) ||
      abs(same_day_rho) >= 1) {
    stop(
      "same_day_rho must be one finite value between -1 and 1.",
      call. = FALSE
    )
  }

  fixed_formula <- closeness ~
    0 + .is_female + .is_male +
    .is_female:diaryday_c +
    .is_male:diaryday_c +
    .is_female:.provided_support_cwp_actor +
    .is_male:.provided_support_cwp_actor +
    .is_female:.provided_support_cwp_partner +
    .is_male:.provided_support_cwp_partner +
    .is_female:.provided_support_cbp_actor +
    .is_male:.provided_support_cbp_actor +
    .is_female:.provided_support_cbp_partner +
    .is_male:.provided_support_cbp_partner

  fixed_model <- stats::lm(fixed_formula, data = data)
  beta_start <- stats::coef(fixed_model)
  if (length(beta_start) != 12L || any(!is.finite(beta_start))) {
    stop(
      "The fixed-effects starting model must have 12 finite coefficients.",
      call. = FALSE
    )
  }

  list(
    beta = unname(beta_start),
    theta = unname(c(
      log(stable_sd[[1L]]),
      log(stable_sd[[2L]]),
      glmmTMB::put_cor(stable_rho, input_val = "vec"),
      log(ar_sd[[1L]]),
      glmmTMB::put_cor(ar_rho[[1L]], input_val = "vec"),
      log(ar_sd[[2L]]),
      glmmTMB::put_cor(ar_rho[[2L]], input_val = "vec"),
      log(same_day_sd[[1L]]),
      log(same_day_sd[[2L]]),
      glmmTMB::put_cor(same_day_rho, input_val = "vec")
    ))
  )
}

make_pooled_apim_effects_start <- function(role_specific_model) {
  if (!inherits(role_specific_model, "glmmTMB")) {
    stop("role_specific_model must be a fitted glmmTMB model.", call. = FALSE)
  }
  if (role_specific_model$fit$convergence != 0L ||
      !isTRUE(role_specific_model$sdr$pdHess)) {
    stop(
      "The role-specific model must converge with a positive-definite Hessian.",
      call. = FALSE
    )
  }

  role_specific_beta <- glmmTMB::fixef(role_specific_model)$cond
  intercept_names <- c(
    ".is_female",
    ".is_male"
  )
  time_names <- c(
    ".is_female:diaryday_c",
    ".is_male:diaryday_c"
  )
  effect_pairs <- list(
    c(
      ".is_female:.provided_support_cwp_actor",
      ".is_male:.provided_support_cwp_actor"
    ),
    c(
      ".is_female:.provided_support_cwp_partner",
      ".is_male:.provided_support_cwp_partner"
    ),
    c(
      ".is_female:.provided_support_cbp_actor",
      ".is_male:.provided_support_cbp_actor"
    ),
    c(
      ".is_female:.provided_support_cbp_partner",
      ".is_male:.provided_support_cbp_partner"
    )
  )
  required_names <- c(intercept_names, time_names, unlist(effect_pairs))
  missing_names <- setdiff(required_names, names(role_specific_beta))
  if (length(missing_names) > 0L) {
    stop(
      "Missing fixed effects: ",
      paste(missing_names, collapse = ", "),
      call. = FALSE
    )
  }

  pooled_effects <- numeric(length(effect_pairs))
  for (effect_index in seq_along(effect_pairs)) {
    pooled_effects[[effect_index]] <- mean(
      role_specific_beta[effect_pairs[[effect_index]]]
    )
  }

  list(
    beta = unname(c(
      role_specific_beta[intercept_names],
      pooled_effects,
      role_specific_beta[time_names]
    )),
    theta = unname(glmmTMB::getME(role_specific_model, "theta"))
  )
}

simulate_ild_dharma <- function(model, dyad, member, time, role = NULL,
                                n = 250, seed = 123) {
  model_family <- stats::family(model)
  if (model_family$family != "gaussian" ||
      model_family$link != "identity") {
    stop(
      "Block whitening is implemented only for Gaussian identity-link models.",
      call. = FALSE
    )
  }

  model_data <- stats::model.frame(model)
  model_rows <- suppressWarnings(as.integer(rownames(model_data)))
  align_rows <- function(x) {
    if (length(x) == nrow(model_data)) {
      return(x)
    }
    if (anyNA(model_rows) || max(model_rows) > length(x)) {
      stop("Could not align identifiers with the fitted model.", call. = FALSE)
    }
    x[model_rows]
  }

  dyad_id <- align_rows(dyad)
  member_id <- align_rows(member)
  time_id <- align_rows(time)
  role_id <- if (is.null(role)) NULL else align_rows(role)
  if (anyNA(dyad_id) || anyNA(member_id) || anyNA(time_id)) {
    stop("Dyad, member, and time identifiers must be complete.", call. = FALSE)
  }
  if (!is.null(role_id) && anyNA(role_id)) {
    stop("Role identifiers must be complete.", call. = FALSE)
  }
  if (!is.numeric(time_id)) {
    stop("Time must be numeric.", call. = FALSE)
  }
  blocks <- split(seq_along(dyad_id), dyad_id)
  if (n <= max(lengths(blocks))) {
    stop("n must exceed the largest couple block.", call. = FALSE)
  }

  dharma_residuals <- DHARMa::simulateResiduals(
    fittedModel = model,
    n = 2 * n,
    simulateREs = "unconditional",
    refit = FALSE,
    seed = seed,
    plot = FALSE
  )

  simulations <- as.matrix(dharma_residuals$simulatedResponse)
  covariance_simulations <- simulations[, seq_len(n), drop = FALSE]
  evaluation_simulations <- simulations[, n + seq_len(n), drop = FALSE]
  expected <- as.numeric(stats::predict(
    model,
    re.form = NA,
    type = "response"
  ))

  covariance_simulations <- sweep(covariance_simulations, 1, expected)
  whitened_simulations <- sweep(evaluation_simulations, 1, expected)
  whitened_observed <- dharma_residuals$observedResponse - expected

  for (rows in blocks) {
    rows <- rows[order(time_id[rows], member_id[rows])]
    response_covariance <- stats::cov(
      t(covariance_simulations[rows, , drop = FALSE])
    )
    ridge <- max(mean(diag(response_covariance)), 1) *
      sqrt(.Machine$double.eps)
    lower_cholesky <- t(chol(
      response_covariance + diag(ridge, length(rows))
    ))
    whitened_observed[rows] <- forwardsolve(
      lower_cholesky,
      whitened_observed[rows]
    )
    whitened_simulations[rows, ] <- forwardsolve(
      lower_cholesky,
      whitened_simulations[rows, , drop = FALSE]
    )
  }

  dharma_residuals$simulatedResponse <- evaluation_simulations
  dharma_residuals$nSim <- n
  dharma_residuals$fittedPredictedResponse <- expected
  dharma_residuals$scaledResiduals <- DHARMa::getQuantile(
    simulations = whitened_simulations,
    observed = whitened_observed,
    integerResponse = FALSE,
    method = "PIT"
  )
  attr(dharma_residuals, "ild_index") <- list(
    person = interaction(dyad_id, member_id, drop = TRUE),
    time = time_id,
    role = role_id
  )

  dharma_residuals
}

test_ild_lag1 <- function(residuals, plot = FALSE, by_role = FALSE) {
  index <- attr(residuals, "ild_index")
  if (is.null(index)) {
    stop("Use residuals created by simulate_ild_dharma().", call. = FALSE)
  }

  person <- index$person
  time <- index$time
  role <- index$role
  if (by_role && is.null(role)) {
    stop(
      "Supply role to simulate_ild_dharma() before requesting role-specific tests.",
      call. = FALSE
    )
  }
  ordering <- order(person, time)
  previous <- ordering[-length(ordering)]
  current <- ordering[-1]
  consecutive <- person[current] == person[previous] &
    time[current] == time[previous] + 1
  previous <- previous[consecutive]
  current <- current[consecutive]

  test_pairs <- function(previous_rows, current_rows, label) {
    if (length(current_rows) < 3L) {
      stop("At least three consecutive-day pairs are required.", call. = FALSE)
    }

    lag1_correlation <- function(response) {
      model_residual <- response - residuals$fittedPredictedResponse
      model_residual <- model_residual -
        ave(model_residual, person, FUN = mean)
      stats::cor(
        model_residual[previous_rows],
        model_residual[current_rows]
      )
    }

    if (isTRUE(plot)) {
      lag1_label_parameters <- graphics::par(col.lab = "transparent")
      on.exit(graphics::par(lag1_label_parameters), add = TRUE)
    }

    test <- DHARMa::testGeneric(
      residuals,
      summary = lag1_correlation,
      alternative = "two.sided",
      plot = plot,
      methodName = paste0(
        "Consecutive-day lag-1 residual-dependence check",
        label
      )
    )
    if (isTRUE(plot)) {
      graphics::par(lag1_label_parameters)
      p_text <- if (test$p.value < .001) {
        "p < .001"
      } else {
        paste0("p = ", sub("^0", "", sprintf("%.3f", test$p.value)))
      }
      graphics::title(
        xlab = paste("Simulated values; red = observed;", p_text),
        ylab = "Frequency"
      )
    }
    test$statistic <- c(
      `lag-1 correlation` = lag1_correlation(residuals$observedResponse)
    )
    test
  }

  if (!by_role) {
    return(test_pairs(previous, current, ""))
  }

  role_values <- unique(as.character(role[current]))
  role_tests <- vector("list", length(role_values))
  names(role_tests) <- role_values

  for (role_index in seq_along(role_values)) {
    role_value <- role_values[[role_index]]
    role_pairs <- as.character(role[current]) == role_value
    role_tests[[role_index]] <- test_pairs(
      previous[role_pairs],
      current[role_pairs],
      paste0(" for ", role_value)
    )
  }

  role_tests
}
