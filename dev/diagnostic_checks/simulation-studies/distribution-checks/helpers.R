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
  # Stronger dyad dependence; also the false-alarm baseline of the severe mismatches.
  strong <- main |>
    dplyr::filter(scenario == "correct", n_dyads %in% c(100L, 400L)) |>
    dplyr::mutate(dyad_sd = 1.2)
  severe <- tibble::tribble(
    ~family, ~scenario, ~scenario_label, ~nb_size, ~fit_family,
    "gaussian", "omitted_partner", "Omitted partner effect", 3, "gaussian",
    "gaussian", "heteroscedastic", "Residual SD rises with actor predictor", 3, "gaussian",
    "nbinom2", "dispersion_severe", "NB2 size 1 fitted as Poisson", 1, "poisson"
  ) |>
    tidyr::expand_grid(n_dyads = c(100L, 400L)) |>
    dplyr::mutate(role_mean = 0, sd_ratio = 1, zero_probability = 0, n_times = 1L, dyad_sd = 1.2)
  ordinal <- main |>
    dplyr::filter(family == "gaussian", scenario == "correct", n_dyads %in% c(100L, 400L)) |>
    dplyr::mutate(family = "ordinal", fit_family = "ordinal")
  longitudinal <- main |>
    dplyr::filter(family == "gaussian", n_dyads == 100L,
                  scenario %in% c("correct", "mean_small")) |>
    dplyr::mutate(n_times = 6L)
  dplyr::bind_rows(main, strong, severe, ordinal, longitudinal) |>
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
  intercept <- switch(condition$family, gaussian = 1, nbinom2 = log(3), ordinal = 0)
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
  if (condition$family == "ordinal") {
    # Scaling by pi / sqrt(3) keeps the Gaussian dyad-to-residual variance ratio under
    # standard logistic noise. The thresholds give category shares of 10/20/40/20/10%.
    latent <- pi / sqrt(3) * location + stats::rlogis(nrow(data))
    return(ordered(findInterval(latent, c(-3.05, -1.23, 1.23, 3.05)) + 1L, levels = 1:5))
  }
  if (condition$family == "gaussian") {
    # Hold average residual variance at one while changing the between-role SD ratio.
    role_sd <- sqrt(2 / (1 + condition$sd_ratio^2)) *
      ifelse(data$role == "A", 1, condition$sd_ratio)
    if (condition$n_times > 1L) role_sd <- rep(.8, nrow(data))
    # Residual SD exp(actor - 1) gives average variance 1 for standard-normal predictors.
    if (condition$scenario == "heteroscedastic") role_sd <- exp(data$actor_predictor - 1)
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

# Every model keeps actor and partner effects, apart from the omitted partner effect.
distribution_formula <- function(condition) {
  if (condition$scenario == "omitted_partner") return(outcome ~ actor_predictor + (1 | dyad))
  if (condition$n_times == 1L) outcome ~ actor_predictor + partner_predictor + (1 | dyad) else
    outcome ~ actor_predictor + partner_predictor + (1 | dyad) + ar1(time + 0 | member)
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

# Actor and partner estimates, SEs, and 95% Wald coverage. Ordinal effects are on
# the latent logistic scale.
record_inference <- function(model, condition) {
  truth <- c(actor_predictor = .5, partner_predictor = .3) *
    if (condition$family == "ordinal") pi / sqrt(3) else 1
  estimates <- glmmTMB::fixef(model)$cond
  terms <- intersect(names(truth), names(estimates))
  data.frame(term = terms, truth = truth[terms], estimate = estimates[terms],
             se = sqrt(diag(stats::vcov(model)$cond))[terms], row.names = NULL) |>
    dplyr::mutate(covered = abs(estimate - truth) <= stats::qnorm(.975) * se)
}

# Predictor pages show PIT quartiles across each partner's predictor.
distribution_page_statistics <- c("actor_quantiles", "partner_quantiles")
distribution_metrics <- list(
  residual = c("qq", "mean_distance", "predicted_quantiles", distribution_page_statistics),
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

# Pages: predicted outcomes, then the actor and partner predictors.
record_distribution_residuals <- function(result) {
  composition <- result$compositions[[1]]
  stopifnot(identical(result$predictors, c("actor_predictor", "partner_predictor")))
  dplyr::bind_rows(lapply(names(composition$rows), function(role) {
    stats <- composition$statistics[[role]]
    pages <- lapply(composition$patterns, function(pattern) distribution_curve(pattern[[role]]$quantiles))
    dplyr::bind_rows(distribution_curve(stats$qq), distribution_scalar(stats$mean_distance), pages) |>
      dplyr::mutate(statistic = distribution_metrics$residual, role, check = "residual")
  }))
}

# Zeros only where the package shows them; category_any only for ordinal bars.
record_distribution_outcomes <- function(result) {
  composition <- result$compositions[[1]]
  package_names <- c(response_sd = "Response SD", maximum_deviation = "Largest absolute deviation",
                     zeros = "Number of zeros")
  dplyr::bind_rows(lapply(names(composition$rows), function(role) {
    values <- composition$statistics[[role]]
    rows <- empty_distribution_metrics("outcome")
    for (statistic in names(package_names)) {
      if (package_names[[statistic]] %in% rownames(values))
        rows[rows$statistic == statistic, -1] <- distribution_scalar(values[package_names[[statistic]], ])
    }
    if (!is.null(composition$distribution$labels)) {
      bars <- composition$distribution$roles[[role]]
      below <- any(bars$observed < bars$bounds[1, ])
      above <- any(bars$observed > bars$bounds[2, ])
      rows[rows$statistic == "category_any", c("below", "above", "flagged")] <-
        list(below, above, below | above)
    }
    dplyr::mutate(rows, role, check = "outcome")
  }))
}

# Undefined or absent panels never count as agreement. A union is defined if at
# least one constituent is defined; actual check errors are recorded separately.
distribution_any <- function(x) if (all(is.na(x))) NA else any(x, na.rm = TRUE)

# "any" unions the panels without predictor pages, "any_pages" adds the pages.
# Ordinal category ranges are reported separately (category_any).
add_distribution_unions <- function(rows) {
  columns <- c("below", "above", "flagged")
  aggregate_flags <- function(data, groups) data |>
    dplyr::group_by(dplyr::across(dplyr::all_of(groups))) |>
    dplyr::summarise(dplyr::across(dplyr::all_of(columns), distribution_any), .groups = "drop")
  panels <- rows[rows$statistic != "category_any", ]
  groups <- c("reference", "view", "role", "check")
  per_role <- dplyr::bind_rows(
    aggregate_flags(panels[!panels$statistic %in% distribution_page_statistics, ], groups) |>
      dplyr::mutate(statistic = "any"),
    aggregate_flags(panels, groups) |> dplyr::mutate(statistic = "any_pages"))
  all_roles <- aggregate_flags(dplyr::bind_rows(rows, per_role),
                              c("reference", "view", "check", "statistic")) |>
    dplyr::mutate(role = "All")
  result <- dplyr::bind_rows(rows, per_role, all_roles)
  both <- dplyr::bind_rows(lapply(c("known", "fitted-centred", "fitted-uncentred"), function(reference) {
    outcome_reference <- if (reference == "known") "known" else "fitted"
    selected <- result |>
      dplyr::filter(statistic %in% c("any", "any_pages"),
                    (check == "residual" & .data$reference == .env$reference) |
                      (check == "outcome" & .data$reference == .env$outcome_reference))
    if (!any(selected$check == "residual")) return(NULL)
    aggregate_flags(selected, c("view", "role", "statistic")) |>
      dplyr::mutate(reference = reference, check = "both")
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

# Pooled and by role, each with actor and partner predictor pages. "fitted-centred"
# is the package default (centred when the model has a free location, so never for
# ordinal models). Where it centres, the uncentred version changes only that
# setting, and the seed gives identical PIT ranks.
evaluate_distribution_checks <- function(simulations, data, condition, reference, pit_seed) {
  methods <- if (reference == "known") "known" else
    if (isTRUE(attr(simulations, "dyadMLM")$free_conditional_intercept))
      c("fitted-centred", "fitted-uncentred") else "fitted-centred"
  rows <- dplyr::bind_rows(lapply(c("pooled", "roles"), function(view) {
    arguments <- list(simulations = simulations, dyad = "dyad",
      role = if (view == "roles") "role" else NULL,
      member = if (condition$n_times > 1L && view == "roles") "member" else NULL,
      data = data, plot = FALSE)
    residuals <- dplyr::bind_rows(lapply(methods, function(method) {
      if (method == "fitted-uncentred")
        attr(arguments$simulations, "dyadMLM")$free_conditional_intercept <- FALSE
      result <- do.call(check_dyad_residuals, c(arguments, list(
        predictors = c("actor_predictor", "partner_predictor"), seed = pit_seed)))
      dplyr::mutate(record_distribution_residuals(result), reference = method, view)
    }))
    outcome <- do.call(check_dyad_outcomes, arguments)
    dplyr::bind_rows(residuals,
      dplyr::mutate(record_distribution_outcomes(outcome), reference = reference, view))
  }))
  add_distribution_unions(rows)
}

run_distribution_dataset <- function(condition, repetition, reference_draws) {
  # Fresh seeds, above those of all earlier runs of this study.
  dataset_seed <- 1210000000L + 100000L * condition$condition + repetition
  data <- generate_distribution_design(condition, dataset_seed)
  data$outcome <- generate_distribution_response(data, condition)
  # Known-parameter references for correct Gaussian and negative-binomial models.
  references <- if (condition$scenario == "correct" && condition$family != "ordinal")
    c("known", "fitted") else "fitted"
  inference <- NULL
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
        family <- switch(condition$fit_family, gaussian = gaussian(), poisson = poisson(),
          nbinom2 = glmmTMB::nbinom2(), ordinal = glmmTMB::ordinal())
        # A garbage collection before each short fit would triple the fit time.
        status$fit_seconds <- system.time(model <- glmmTMB::glmmTMB(
          distribution_formula(condition), data = data, family = family), gcFirst = FALSE)[["elapsed"]]
        status$convergence <- model$fit$convergence
        status$positive_hessian <- isTRUE(model$sdr$pdHess)
        # Show whether the fit absorbs a misfit: dyad SD and residual SD or NB2 size.
        status$dyad_sd <- attr(glmmTMB::VarCorr(model)$cond$dyad, "stddev")[[1]]
        status$dispersion <- stats::sigma(model)
        if (status$convergence != 0L || !status$positive_hessian) {
          status$status <- "fit_problem"
          stop("Convergence or Hessian problem.")
        }
        inference <<- dplyr::mutate(record_inference(model, condition),
          condition = condition$condition, repetition, .before = 1)
        status$status <- "check_error"
        simulations <- simulate_dyad_responses(model, nsim = reference_draws,
                                               seed = dataset_seed + 10000000L)
      }
      status$check_seconds <- system.time(checked <- evaluate_distribution_checks(
        simulations, data, condition, reference, dataset_seed + 30000000L),
        gcFirst = FALSE)[["elapsed"]]
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
       statistics = dplyr::bind_rows(lapply(results, `[[`, "statistics")),
       inference = inference)
}
