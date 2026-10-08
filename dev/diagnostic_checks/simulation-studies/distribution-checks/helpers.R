# Study definitions and recording of the package's displayed comparisons.
distribution_conditions <- function() {
  scenarios <- tibble::tribble(
    ~family, ~scenario, ~scenario_label, ~role_mean, ~sd_ratio, ~zero_probability, ~nb_size, ~fit_family,
    "gaussian", "correct", "Correct model", 0, 1, 0, 3, "gaussian",
    "gaussian", "mean_small", "Omitted role means: +/-0.2", .2, 1, 0, 3, "gaussian",
    "gaussian", "mean_large", "Omitted role means: +/-0.4", .4, 1, 0, 3, "gaussian",
    "gaussian", "variance_small", "Role SD ratio: 1.25", 0, 1.25, 0, 3, "gaussian",
    "gaussian", "variance_large", "Role SD ratio: 1.50", 0, 1.5, 0, 3, "gaussian",
    "nbinom2", "correct", "Correct model", 0, 1, 0, 3, "nbinom2",
    "nbinom2", "dispersion_small", "NB2 size 10 fitted as Poisson", 0, 1, 0, 10, "poisson",
    "nbinom2", "dispersion_large", "NB2 size 3 fitted as Poisson", 0, 1, 0, 3, "poisson",
    "nbinom2", "zeros_small", "Omitted zero inflation: 10%", 0, 1, .1, 3, "nbinom2",
    "nbinom2", "zeros_large", "Omitted zero inflation: 25%", 0, 1, .25, 3, "nbinom2"
  )
  main <- tidyr::crossing(scenarios, n_dyads = c(40L, 100L, 400L)) |>
    dplyr::mutate(n_times = 1L, dyad_sd = .6)
  strong <- main |>
    dplyr::filter(scenario == "correct", n_dyads == 100L) |>
    dplyr::mutate(dyad_sd = 1.2)
  longitudinal <- main |>
    dplyr::filter(family == "gaussian", n_dyads == 100L,
                  scenario %in% c("correct", "mean_small")) |>
    dplyr::mutate(n_times = 6L)
  dplyr::bind_rows(main, strong, longitudinal) |>
    dplyr::mutate(condition = dplyr::row_number(), .before = 1)
}

generate_distribution_design <- function(condition, seed) {
  set.seed(seed)
  pairs <- condition$n_dyads * condition$n_times
  first <- rnorm(pairs)
  second <- .3 * first + sqrt(1 - .3^2) * rnorm(pairs)
  data.frame(
    dyad = factor(rep(seq_len(condition$n_dyads), each = 2 * condition$n_times)),
    role = factor(rep(c("A", "B"), pairs)),
    time = factor(rep(rep(seq_len(condition$n_times), each = 2), condition$n_dyads)),
    actor_predictor = as.vector(rbind(first, second)),
    partner_predictor = as.vector(rbind(second, first))
  ) |>
    # Rows alternate partners at each occasion; member IDs follow those rows.
    dplyr::mutate(member = factor(2L * (as.integer(dyad) - 1L) + as.integer(role)))
}

distribution_linear_predictor <- function(data, condition) {
  intercept <- if (condition$family == "gaussian") 1 else log(3)
  intercept + .5 * data$actor_predictor + .3 * data$partner_predictor +
    ifelse(data$role == "A", -condition$role_mean, condition$role_mean)
}

# Conditional draws use the same fixed predictor rows and redraw all random effects.
generate_distribution_response <- function(data, condition) {
  location <- distribution_linear_predictor(data, condition) +
    rnorm(condition$n_dyads, sd = condition$dyad_sd)[data$dyad]
  if (condition$n_times > 1L) {
    process <- matrix(NA_real_, 2L * condition$n_dyads, condition$n_times)
    process[, 1] <- rnorm(nrow(process), sd = .6)
    for (time in 2:condition$n_times)
      process[, time] <- .5 * process[, time - 1L] +
        rnorm(nrow(process), sd = .6 * sqrt(1 - .5^2))
    location <- location + process[cbind(as.integer(data$member), as.integer(data$time))]
  }
  if (condition$family == "gaussian") {
    # Hold average residual variance at one while changing the between-role SD ratio.
    role_sd <- sqrt(2 / (1 + condition$sd_ratio^2)) *
      ifelse(data$role == "A", 1, condition$sd_ratio)
    if (condition$n_times > 1L) role_sd <- rep(.8, nrow(data))
    location + rnorm(nrow(data), sd = role_sd)
  } else {
    # Offset the count mean so zero inflation does not also change its expectation.
    response <- rnbinom(nrow(data), mu = exp(location) / (1 - condition$zero_probability),
                        size = condition$nb_size)
    if (condition$zero_probability > 0)
      response[runif(nrow(data)) < condition$zero_probability] <- 0
    response
  }
}

known_distribution_simulations <- function(data, condition, draws, seed) {
  set.seed(seed)
  linear <- distribution_linear_predictor(data, condition)
  structure(list(observed_response = data$outcome,
    predicted_response = if (condition$family == "gaussian") linear else exp(linear),
    simulated_responses = t(replicate(draws, generate_distribution_response(data, condition))),
    model_frame = data), class = c("dyadMLM_response_simulations", "list"),
    dyadMLM = list(family = condition$family, free_conditional_intercept = FALSE))
}

distribution_metrics <- list(
  residual = c("qq", "histogram", "outliers", "mean_distance",
               "predicted_quantiles", "predicted_distance"),
  outcome = c("response_sd", "maximum_deviation", "zeros", "category_any")
)

distribution_scalar <- function(values) {
  bounds <- dyadMLM:::simulated_rank_limits(values[-1])
  data.frame(observed = values[1], lower = bounds[1], upper = bounds[2],
    below = values[1] < bounds[1], above = values[1] > bounds[2]) |>
    dplyr::mutate(flagged = below | above)
}

distribution_curve <- function(curves) {
  if (!is.list(curves[[1]])) curves <- list(curves)
  values <- dplyr::bind_rows(lapply(curves, as.data.frame))
  valid <- with(values, is.finite(observed) & is.finite(lower) & is.finite(upper))
  data.frame(observed = NA_real_, lower = NA_real_, upper = NA_real_,
    below = if (any(valid)) any(values$observed[valid] < values$lower[valid]) else NA,
    above = if (any(valid)) any(values$observed[valid] > values$upper[valid]) else NA) |>
    dplyr::mutate(flagged = below | above)
}

empty_distribution_metrics <- function(check) {
  data.frame(statistic = distribution_metrics[[check]], observed = NA_real_,
             lower = NA_real_, upper = NA_real_, below = NA, above = NA, flagged = NA)
}

record_distribution_residuals <- function(result) {
  composition <- result$compositions[[1]]
  dplyr::bind_rows(lapply(names(composition$rows), function(role) {
    stats <- composition$statistics[[role]]
    pattern <- composition$patterns[[1]][[role]]
    rows <- dplyr::bind_rows(
      distribution_curve(stats$qq), distribution_curve(stats$histogram),
      distribution_scalar(stats$outliers), distribution_scalar(stats$mean_distance),
      distribution_curve(pattern$quantiles), distribution_curve(pattern$distance))
    dplyr::mutate(rows, statistic = distribution_metrics$residual, role, check = "residual")
  }))
}

record_distribution_outcomes <- function(result) {
  composition <- result$compositions[[1]]
  dplyr::bind_rows(lapply(names(composition$rows), function(role) {
    values <- composition$statistics[[role]]
    rows <- empty_distribution_metrics("outcome")
    package_names <- c(response_sd = "Response SD", maximum_deviation = "Largest absolute deviation",
                       zeros = "Number of zeros")
    for (statistic in names(package_names)) {
      if (package_names[[statistic]] %in% rownames(values))
        rows[rows$statistic == statistic, -1] <- distribution_scalar(values[package_names[[statistic]], ])
    }
    distribution <- composition$distribution
    if (!is.null(distribution$labels)) {
      frequencies <- distribution$roles[[role]]
      count <- length(distribution$labels) - as.integer(distribution$has_other_values)
      # Other values have no observed comparison in the package's plot.
      categories <- data.frame(statistic = paste0("category:", distribution$labels[seq_len(count)]),
        observed = frequencies$observed[seq_len(count)],
        lower = frequencies$bounds[1, seq_len(count)], upper = frequencies$bounds[2, seq_len(count)]) |>
        dplyr::mutate(below = observed < lower, above = observed > upper, flagged = below | above)
      rows[rows$statistic == "category_any", c("below", "above", "flagged")] <-
        lapply(categories[c("below", "above", "flagged")], any)
      rows <- dplyr::bind_rows(rows, categories)
    }
    dplyr::mutate(rows, role, check = "outcome")
  }))
}

# Undefined or absent panels never count as agreement. A union is defined if at
# least one constituent is defined; actual check errors are recorded separately.
distribution_any <- function(x) if (all(is.na(x))) NA else any(x, na.rm = TRUE)

add_distribution_unions <- function(rows) {
  columns <- c("below", "above", "flagged")
  aggregate_flags <- function(data, groups) data |>
    dplyr::group_by(dplyr::across(dplyr::all_of(groups))) |>
    dplyr::summarise(dplyr::across(dplyr::all_of(columns), distribution_any), .groups = "drop")
  # Pointwise category ranges are reported separately (category_any).
  panels <- rows[!startsWith(rows$statistic, "category"), ]
  per_role <- aggregate_flags(panels, c("reference", "view", "role", "check")) |>
    dplyr::mutate(statistic = "any")
  all_roles <- aggregate_flags(dplyr::bind_rows(rows, per_role),
                              c("reference", "view", "check", "statistic")) |>
    dplyr::mutate(role = "All")
  result <- dplyr::bind_rows(rows, per_role, all_roles)
  both <- dplyr::bind_rows(lapply(c("known", "fitted-centred", "fitted-uncentred"), function(reference) {
    outcome_reference <- if (reference == "known") "known" else "fitted"
    selected <- result |>
      dplyr::filter(statistic == "any", (check == "residual" & .data$reference == .env$reference) |
                      (check == "outcome" & .data$reference == .env$outcome_reference))
    if (!any(selected$check == "residual")) return(NULL)
    aggregate_flags(selected, c("view", "role")) |>
      dplyr::mutate(reference = reference, check = "both", statistic = "any")
  }))
  dplyr::bind_rows(result, both)
}

distribution_placeholders <- function(reference) {
  references <- if (reference == "known") "known" else c("fitted-centred", "fitted-uncentred", "fitted")
  dplyr::bind_rows(lapply(references, function(method) {
    checks <- if (method == "known") names(distribution_metrics) else
      if (method == "fitted") "outcome" else "residual"
    dplyr::bind_rows(lapply(checks, function(check) {
      dplyr::bind_rows(lapply(c("pooled", "roles"), function(view) {
        roles <- if (view == "pooled") "Pooled" else c("A", "B")
        dplyr::bind_rows(lapply(roles, function(role)
          dplyr::mutate(empty_distribution_metrics(check), reference = method, view, role, check)))
      }))
    }))
  })) |>
    add_distribution_unions()
}

evaluate_distribution_checks <- function(simulations, data, condition, reference, pit_seed) {
  methods <- if (reference == "known") "known" else c("fitted-centred", "fitted-uncentred")
  rows <- dplyr::bind_rows(lapply(c("pooled", "roles"), function(view) {
    arguments <- list(simulations = simulations, dyad = "dyad",
      role = if (view == "roles") "role" else NULL,
      member = if (condition$n_times > 1L && view == "roles") "member" else NULL,
      data = data, plot = FALSE)
    residuals <- dplyr::bind_rows(lapply(methods, function(method) {
      # The only changed input is the centring flag. The seed gives identical PIT ranks.
      attr(arguments$simulations, "dyadMLM")$free_conditional_intercept <- method == "fitted-centred"
      result <- do.call(check_dyad_residuals, c(arguments, list(seed = pit_seed)))
      dplyr::mutate(record_distribution_residuals(result), reference = method, view)
    }))
    outcome <- do.call(check_dyad_outcomes, arguments)
    dplyr::bind_rows(residuals,
      dplyr::mutate(record_distribution_outcomes(outcome), reference = reference, view))
  }))
  add_distribution_unions(rows)
}

run_distribution_dataset <- function(condition, repetition, reference_draws) {
  dataset_seed <- 710000000L + 100000L * condition$condition + repetition
  data <- generate_distribution_design(condition, dataset_seed)
  data$outcome <- generate_distribution_response(data, condition)
  references <- if (condition$scenario == "correct") c("known", "fitted") else "fitted"
  results <- lapply(references, function(reference) {
    status <- data.frame(condition = condition$condition, repetition, reference, dataset_seed,
      usable = FALSE, status = if (reference == "known") "check_error" else "fit_error",
      convergence = NA_integer_, positive_hessian = NA, dyad_sd = NA_real_,
      dispersion = NA_real_, warnings = "", error = "", fit_seconds = 0, check_seconds = 0)
    warnings <- character()
    statistics <- tryCatch(withCallingHandlers({
      if (reference == "known") {
        simulations <- known_distribution_simulations(data, condition, reference_draws,
                                                       dataset_seed + 20000000L)
      } else {
        formula <- if (condition$n_times == 1L)
          outcome ~ actor_predictor + partner_predictor + (1 | dyad) else
          outcome ~ actor_predictor + partner_predictor + (1 | dyad) + ar1(time + 0 | member)
        family <- switch(condition$fit_family,
          gaussian = gaussian(), poisson = poisson(), nbinom2 = glmmTMB::nbinom2())
        status$fit_seconds <- system.time(model <- glmmTMB::glmmTMB(
          formula, data = data, family = family))[["elapsed"]]
        status$convergence <- model$fit$convergence
        status$positive_hessian <- isTRUE(model$sdr$pdHess)
        # Show whether the fit absorbs a misfit: dyad SD and residual SD or NB2 size.
        status$dyad_sd <- attr(glmmTMB::VarCorr(model)$cond$dyad, "stddev")[[1]]
        status$dispersion <- stats::sigma(model)
        if (status$convergence != 0L || !status$positive_hessian) {
          status$status <- "fit_problem"
          stop("Convergence or Hessian problem.")
        }
        status$status <- "check_error"
        simulations <- simulate_dyad_responses(model, nsim = reference_draws,
                                               seed = dataset_seed + 10000000L)
      }
      status$check_seconds <- system.time(checked <- evaluate_distribution_checks(
        simulations, data, condition, reference, dataset_seed + 30000000L))[["elapsed"]]
      status$usable <- TRUE
      status$status <- "success"
      checked
    }, warning = function(warning) {
      warnings <<- c(warnings, conditionMessage(warning))
      invokeRestart("muffleWarning")
    }), error = function(error) {
      status$error <<- conditionMessage(error)
      distribution_placeholders(reference)
    })
    status$warnings <- paste(unique(warnings), collapse = " | ")
    list(fits = status, statistics = dplyr::mutate(statistics,
      condition = condition$condition, repetition, .before = 1))
  })
  list(fits = dplyr::bind_rows(lapply(results, `[[`, "fits")),
       statistics = dplyr::bind_rows(lapply(results, `[[`, "statistics")))
}
