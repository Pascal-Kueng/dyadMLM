# Run from the repository root. Arguments: datasets, reference draws, workers, run/summarise.
# Validates check_partner_dependence() with `member` and `time`; see §7 of
# dev/diagnostic_checks/ild-partner-dependence-plan.md.
# The covariance study supplies the package and add_rate_intervals().
source("dev/diagnostic_checks/simulation-studies/covariance-pooling/run.R")

study_cells <- dplyr::bind_rows(
  tidyr::crossing(part = "gaussian", n_dyads = c(50L, 200L), n_occasions = c(3L, 5L, 14L),
                  missing_share = c(0, 0.2)),
  tidyr::crossing(part = "ar", n_dyads = c(50L, 200L), n_occasions = 14L, ar_phi = c(0, 0.7)),
  tidyr::crossing(part = c("poisson", "ordinal"), n_dyads = c(50L, 200L), n_occasions = c(5L, 14L)),
  tidyr::crossing(part = c("lag_gaussian", "lag_nbinom2"), n_dyads = c(50L, 200L), n_occasions = 14L),
  tidyr::crossing(part = c("gaussian", "poisson"), n_dyads = c(50L, 200L),
                  n_occasions = c(5L, 14L), truth_case = c("zero_stable", "zero_occasion")),
  tidyr::crossing(part = "ordinal", n_dyads = c(50L, 200L), n_occasions = 14L,
                  truth_case = c("zero_stable", "zero_occasion"))
) |>
  tidyr::replace_na(list(missing_share = 0, ar_phi = 0, truth_case = "correlated")) |>
  dplyr::mutate(cell = dplyr::row_number(), .before = 1)

# True values. SDs and correlations describe latent (link-scale) effects.
true_parameters <- list(
  gaussian = list(intercepts = c(0.2, -0.1), actor = 0.4, partner = 0.2,
                  stable_sds = c(1, 1), stable_cor = 0.4, occasion_sds = c(1.2, 0.8), occasion_cor = 0.3),
  # The occasion part adds a dyad-day block and one AR(1) component per member.
  ar = list(intercepts = c(0.2, -0.1), actor = 0.4, partner = 0.2,
            stable_sds = c(1, 1), stable_cor = 0.4, occasion_sds = sqrt(c(0.4, 0.4)), occasion_cor = 0.5,
            ar_sd = sqrt(0.6)),
  poisson = list(intercepts = c(1, 0.8), actor = 0.3, partner = 0.15,
                 stable_sds = c(0.5, 0.5), stable_cor = 0.4, occasion_sds = c(0.4, 0.4), occasion_cor = 0.4),
  # Ordinal thresholds absorb the intercept; males are shifted by -0.2.
  ordinal = list(intercepts = c(0, -0.2), actor = 0.4, partner = 0.2, thresholds = c(-1, 0, 1),
                 stable_sds = c(0.8, 0.8), stable_cor = 0.4, shared_occasion_sd = 0.6),
  lag_gaussian = list(intercepts = c(0.2, -0.1), actor = 0.4, partner = 0.2, lag_own = 0.3, lag_partner = 0.15,
                      stable_sds = c(1, 1), stable_cor = 0.4, occasion_sds = c(1.2, 0.8), occasion_cor = 0.3),
  # NB2 lags enter as log1p() of the previous counts.
  lag_nbinom2 = list(intercepts = c(0.5, 0.3), actor = 0.3, partner = 0.15, lag_own = 0.3, lag_partner = 0.15,
                     stable_sds = c(0.5, 0.5), stable_cor = 0.4, nbinom2_size = 3)
)

cell_truth <- function(cell) {
  truth <- true_parameters[[cell$part]]
  if (cell$truth_case == "zero_stable") truth$stable_cor <- 0
  if (cell$truth_case == "zero_occasion") {
    if (cell$part == "ordinal") truth$shared_occasion_sd <- 0 else truth$occasion_cor <- 0
  }
  truth
}

stable_block <- "us(0 + gender | dyad)"
occasion_block <- "us(0 + gender | dyad:occasion)"
ar_terms <- "ar1(0 + is_female:occasion | dyad) + ar1(0 + is_male:occasion | dyad)"
fitted_models <- tibble::tribble(
  ~part, ~model, ~random_terms,
  "gaussian", "correct", paste(stable_block, "+", occasion_block),
  "gaussian", "no_occasion_covariance", paste(stable_block, "+ diag(0 + gender | dyad:occasion)"),
  "gaussian", "no_stable_covariance", paste("diag(0 + gender | dyad) +", occasion_block),
  "gaussian", "equal_occasion_variances", paste(stable_block, "+ homcs(0 + gender | dyad:occasion)"),
  "ar", "no_ar", paste(stable_block, "+", occasion_block),
  "ar", "no_ar_equal_occasion_variances", paste(stable_block, "+ homcs(0 + gender | dyad:occasion)"),
  "ar", "with_ar", paste(stable_block, "+", occasion_block, "+", ar_terms),
  "poisson", "correct", paste(stable_block, "+", occasion_block),
  "poisson", "no_occasion_covariance", paste(stable_block, "+ diag(0 + gender | dyad:occasion)"),
  "poisson", "no_stable_covariance", paste("diag(0 + gender | dyad) +", occasion_block),
  "ordinal", "correct", paste(stable_block, "+ (1 | dyad:occasion)"),
  "ordinal", "no_occasion_covariance", stable_block,
  "ordinal", "no_stable_covariance", "diag(0 + gender | dyad) + (1 | dyad:occasion)",
  "lag_gaussian", "lag_sensitivity", paste("lag_own + lag_partner +", stable_block, "+", occasion_block),
  "lag_nbinom2", "lag_sensitivity", paste("lag_own + lag_partner +", stable_block)
)

# The models fitted in each cell. Without AR in the data, both AR-free models are
# correct. Recovery is reported for correct models only.
cell_models <- study_cells |>
  dplyr::inner_join(fitted_models, by = "part", relationship = "many-to-many") |>
  dplyr::filter(!(model == "with_ar" & ar_phi == 0),
    truth_case == "correlated" | model == "correct" |
      (truth_case == "zero_stable" & model == "no_stable_covariance") |
      (truth_case == "zero_occasion" & model == "no_occasion_covariance")) |>
  dplyr::mutate(correct = model == "correct" |
    (truth_case == "zero_stable" & model == "no_stable_covariance") |
    (truth_case == "zero_occasion" & model == "no_occasion_covariance") |
    (part == "ar" & (model == "with_ar" | ar_phi == 0)),
    purpose = dplyr::case_when(startsWith(part, "lag_") ~ "lag_sensitivity",
                               correct ~ "calibration", TRUE ~ "detection"))

# True values named as extract_estimates() names the estimates.
true_estimates <- function(cell, model) {
  truth <- cell_truth(cell)
  occasion_sds <- c(truth$occasion_sds, truth$shared_occasion_sd)
  occasion_cor <- truth$occasion_cor
  if (cell$part == "ar" && model != "with_ar") {
    # Without an AR term, the dyad-day block holds the whole occasion part.
    occasion_sds <- sqrt(occasion_sds^2 + truth$ar_sd^2)
    occasion_cor <- truth$occasion_cor * truth$occasion_sds[1]^2 / occasion_sds[1]^2
  }
  values <- c(
    genderfemale = truth$intercepts[1], gendermale = truth$intercepts[2],
    x_actor = truth$actor, x_partner = truth$partner,
    lag_own = truth$lag_own, lag_partner = truth$lag_partner,
    block1_sd_1 = truth$stable_sds[1], block1_sd_2 = truth$stable_sds[2], block1_cor = truth$stable_cor,
    block2_sd_1 = occasion_sds[1], block2_sd_2 = occasion_sds[2], block2_cor = occasion_cor,
    if (model == "with_ar") c(block3_sd_1 = truth$ar_sd, block3_sd_2 = truth$ar_sd, block3_cor = cell$ar_phi,
                              block4_sd_1 = truth$ar_sd, block4_sd_2 = truth$ar_sd, block4_cor = cell$ar_phi)
  )
  # Ordinal thresholds absorb the female intercept; gendermale is the male shift.
  if (cell$part == "ordinal") values <- values[names(values) != "genderfemale"]
  tibble::tibble(parameter = names(values), true_value = unname(values))
}

draw_partner_effects <- function(n, sds, correlation) {
  first <- rnorm(n)
  second <- correlation * first + sqrt(1 - correlation^2) * rnorm(n)
  cbind(sds[1] * first, sds[2] * second)
}

# Returns one row per member and occasion, with the true fixed-effect mean on the
# response scale (random effects set to zero), which model-centring subtracts.
generate_occasion_data <- function(cell, dataset_seed) {
  set.seed(dataset_seed)
  truth <- cell_truth(cell)
  has_lags <- startsWith(cell$part, "lag_")
  n_dyads <- cell$n_dyads
  # Lagged parts start from a burn-in, so kept occasions are near stationarity.
  n_generated <- cell$n_occasions + if (has_lags) 20L else 0L
  n_values <- n_dyads * n_generated
  # Arrays are dyads x occasions x members (female, male).
  as_array <- function(values) array(values, c(n_dyads, n_generated, 2L))
  # Row i of a dyads x members matrix, repeated over occasions.
  repeat_over_occasions <- function(values) as_array(values[rep(seq_len(n_dyads), n_generated), ])
  # The predictor varies between and within members.
  predictor <- repeat_over_occasions(matrix(0.7 * rnorm(2 * n_dyads), n_dyads)) +
    as_array(0.7 * rnorm(2 * n_values))
  partner_predictor <- predictor[, , 2:1]
  role_intercepts <- as_array(rep(truth$intercepts, each = n_values))
  fixed_part <- role_intercepts + truth$actor * predictor + truth$partner * partner_predictor

  random_part <- repeat_over_occasions(draw_partner_effects(n_dyads, truth$stable_sds, truth$stable_cor))
  if (!is.null(truth$occasion_sds)) {
    random_part <- random_part + as_array(draw_partner_effects(n_values, truth$occasion_sds, truth$occasion_cor))
  }
  if (!is.null(truth$shared_occasion_sd)) {
    random_part <- random_part + as_array(rep(truth$shared_occasion_sd * rnorm(n_values), 2))
  }
  if (!is.null(truth$ar_sd)) {
    # Stationary AR(1) per member, independent between partners.
    phi <- cell$ar_phi
    ar_part <- as_array(0)
    ar_part[, 1, ] <- truth$ar_sd * rnorm(2 * n_dyads)
    for (occasion in seq_len(n_generated)[-1]) {
      ar_part[, occasion, ] <- phi * ar_part[, occasion - 1, ] +
        sqrt(1 - phi^2) * truth$ar_sd * rnorm(2 * n_dyads)
    }
    random_part <- random_part + ar_part
  }

  lag_own <- lag_partner <- as_array(0)
  outcome <- as_array(NA_real_)
  inverse_link <- if (cell$part %in% c("poisson", "lag_nbinom2")) exp else identity
  for (occasion in seq_len(n_generated)) {
    if (has_lags && occasion > 1L) {
      previous <- outcome[, occasion - 1, ]
      if (cell$part == "lag_nbinom2") previous <- log1p(previous)
      lag_own[, occasion, ] <- previous
      lag_partner[, occasion, ] <- previous[, 2:1]
    }
    linear_predictor <- fixed_part[, occasion, ] + random_part[, occasion, ] +
      if (has_lags) truth$lag_own * lag_own[, occasion, ] + truth$lag_partner * lag_partner[, occasion, ] else 0
    outcome[, occasion, ] <- switch(cell$part,
      poisson = rpois(2 * n_dyads, exp(linear_predictor)),
      lag_nbinom2 = rnbinom(2 * n_dyads, mu = exp(linear_predictor), size = truth$nbinom2_size),
      ordinal = findInterval(linear_predictor + rnorm(2 * n_dyads), truth$thresholds) + 1,
      linear_predictor)
  }
  fixed_linear_predictor <- fixed_part +
    if (has_lags) truth$lag_own * lag_own + truth$lag_partner * lag_partner else 0
  true_fixed_mean <- if (cell$part == "ordinal") {
    # Expected category score 1, ..., 4 with random effects set to zero.
    1 + Reduce(`+`, lapply(truth$thresholds, function(threshold) pnorm(fixed_linear_predictor - threshold)))
  } else inverse_link(fixed_linear_predictor)

  kept_occasions <- seq.int(n_generated - cell$n_occasions + 1L, n_generated)
  keep <- function(values) as.vector(values[, kept_occasions, ])
  generated <- tibble::tibble(
    dyad = rep(seq_len(n_dyads), times = 2L * cell$n_occasions),
    occasion = rep(rep(seq_len(cell$n_occasions), each = n_dyads), times = 2L),
    gender = factor(rep(c("female", "male"), each = n_dyads * cell$n_occasions)),
    x_actor = keep(predictor), x_partner = keep(partner_predictor),
    lag_own = keep(lag_own), lag_partner = keep(lag_partner),
    outcome = keep(outcome), true_fixed_mean = keep(true_fixed_mean)
  ) |>
    dplyr::mutate(
      person = factor(paste(dyad, gender)), dyad = factor(dyad),
      occasion = factor(occasion, levels = seq_len(cell$n_occasions)),
      is_female = as.numeric(gender == "female"), is_male = 1 - is_female
    ) |>
    dplyr::arrange(dyad, occasion, gender)
  # Occasions are missing completely at random, separately for each member.
  generated <- generated[runif(nrow(generated)) >= cell$missing_share, ]
  if (cell$part == "ordinal") generated$outcome <- ordered(generated$outcome, levels = 1:4)
  generated
}

fit_occasion_model <- function(generated_data, cell, model_name) {
  random_terms <- fitted_models$random_terms[fitted_models$part == cell$part & fitted_models$model == model_name]
  fixed_terms <- if (cell$part == "ordinal") "gender + x_actor + x_partner" else "0 + gender + x_actor + x_partner"
  model_formula <- as.formula(paste("outcome ~", fixed_terms, "+", random_terms))
  family_arguments <- switch(cell$part,
    poisson = list(family = poisson()),
    ordinal = list(family = glmmTMB::ordinal(link = "probit")),
    lag_nbinom2 = list(family = glmmTMB::nbinom2()),
    list(family = gaussian(), dispformula = ~0))
  # The AR model needs profiling to converge, as in the APIM vignette.
  optimizer <- if (family_arguments$family$family == "gaussian") "BFGS" else "nlminb"
  control <- if (optimizer == "BFGS") {
    glmmTMB::glmmTMBControl(optimizer = optim, optArgs = list(method = "BFGS"),
      optCtrl = list(maxit = 1000, reltol = 1e-10), parallel = 1L, profile = model_name == "with_ar")
  } else glmmTMB::glmmTMBControl(parallel = 1L)
  warning_messages <- character()
  error_message <- ""
  elapsed <- system.time(fitted_model <- tryCatch(withCallingHandlers(
    do.call(glmmTMB::glmmTMB, c(list(formula = model_formula, data = generated_data,
                                     REML = FALSE, control = control), family_arguments)),
    warning = function(warning) {
      warning_messages <<- c(warning_messages, conditionMessage(warning))
      invokeRestart("muffleWarning")
    }), error = function(error) {
      error_message <<- conditionMessage(error)
      NULL
    }))["elapsed"]
  converged <- !is.null(fitted_model) && fitted_model$fit$convergence == 0L
  usable <- converged && isTRUE(fitted_model$sdr$pdHess) && is.finite(as.numeric(logLik(fitted_model)))
  list(model = fitted_model, status = tibble::tibble(
    model = model_name, optimizer, usable,
    convergence = if (is.null(fitted_model)) NA_integer_ else fitted_model$fit$convergence,
    optimizer_message = if (is.null(fitted_model$fit$message)) "" else fitted_model$fit$message,
    positive_hessian = if (is.null(fitted_model)) NA else isTRUE(fitted_model$sdr$pdHess),
    warnings = paste(unique(warning_messages), collapse = " | "), error = error_message,
    fit_seconds = as.numeric(elapsed)))
}

# Fixed effects, then each covariance block's first two SDs and first correlation.
# For an ar1 block these are the AR SD and phi.
extract_estimates <- function(fitted_model) {
  blocks <- glmmTMB::VarCorr(fitted_model)$cond
  covariance <- dplyr::bind_rows(lapply(seq_along(blocks), function(block_index) {
    standard_deviations <- attr(blocks[[block_index]], "stddev")
    correlations <- attr(blocks[[block_index]], "correlation")
    tibble::tibble(
      parameter = paste0("block", block_index, "_", c("sd_1", "sd_2", "cor")),
      estimate = c(standard_deviations[1], standard_deviations[2],
                   if (length(standard_deviations) > 1L) correlations[1, 2] else NA)
    )
  }))
  fixed <- glmmTMB::fixef(fitted_model)$cond
  dplyr::bind_rows(tibble::tibble(parameter = names(fixed), estimate = unname(fixed)), covariance) |>
    dplyr::filter(!is.na(estimate))
}

statistic_keys <- c("sd_female", "sd_male", "partner_cor", "dyad_average_sd",
                    "half_difference_sd", "average_difference_cor")

# One row per level and statistic. Counts of simulations below and above the
# observed value allow the rank limits of PR #77 to be applied later.
record_occasion_check <- function(check) {
  dplyr::bind_rows(lapply(which(check$compositions$n_pairs >= 3L), function(composition_index) {
    statistics <- as.matrix(check$compositions$statistics[[composition_index]][, -1])
    observed <- statistics[1, ]
    simulated <- statistics[-1, , drop = FALSE]
    simulated[!is.finite(simulated)] <- NA_real_
    limits <- apply(simulated, 2, function(values) quantile(values[is.finite(values)], c(0.025, 0.975), names = FALSE))
    tibble::tibble(
      level = check$compositions$level[composition_index],
      statistic = statistic_keys, observed,
      lower = limits[1, ], upper = limits[2, ],
      n_defined = colSums(is.finite(simulated)),
      n_below = colSums(simulated < rep(observed, each = nrow(simulated)), na.rm = TRUE),
      n_above = colSums(simulated > rep(observed, each = nrow(simulated)), na.rm = TRUE)
    )
  }))
}

run_occasion_dataset <- function(cell, repetition, reference_draws) {
  dataset_seed <- 520000000L + 10000L * cell$cell + repetition
  generated_data <- generate_occasion_data(cell, dataset_seed)
  model_names <- cell_models$model[cell_models$cell == cell$cell]
  responses <- if (startsWith(cell$part, "lag_")) c("model-centred", "raw") else "model-centred"
  results <- lapply(seq_along(model_names), function(model_index) {
    fit <- fit_occasion_model(generated_data, cell, model_names[model_index])
    status <- dplyr::mutate(fit$status, estimate_error = "", check_error = "", check_warnings = "", check_seconds = NA_real_)
    if (is.null(fit$model)) return(list(status = status))
    estimates <- tryCatch(extract_estimates(fit$model), error = function(error) {
      status$estimate_error <<- conditionMessage(error)
      NULL
    })
    check_warnings <- character()
    started <- proc.time()[["elapsed"]]
    checks <- tryCatch(withCallingHandlers(suppressMessages({
      simulations <- simulate_dyad_responses(fit$model, nsim = reference_draws,
                                             seed = dataset_seed + 100000000L * model_index)
      dplyr::bind_rows(lapply(responses, function(response) {
        check <- check_partner_dependence(simulations, dyad = dyad, role = gender, member = person,
                                          time = occasion, data = generated_data,
                                          plot = FALSE, response = response)
        dplyr::mutate(record_occasion_check(check), response, .before = 1)
      }))
    }), warning = function(warning) {
      check_warnings <<- c(check_warnings, conditionMessage(warning))
      invokeRestart("muffleWarning")
    }), error = function(error) {
      status$check_error <<- conditionMessage(error)
      NULL
    })
    status$check_warnings <- paste(unique(check_warnings), collapse = " | ")
    status$check_seconds <- proc.time()[["elapsed"]] - started
    list(status = status, estimates = estimates, checks = checks)
  })
  label_rows <- function(component) {
    rows <- dplyr::bind_rows(lapply(seq_along(results), function(model_index) {
      rows <- results[[model_index]][[component]]
      if (is.null(rows)) return(NULL)
      dplyr::mutate(rows, model = model_names[model_index])
    }))
    # Keep the schema when every fit or check in a dataset fails.
    if (ncol(rows) == 0L) {
      rows <- if (component == "estimates") {
        tibble::tibble(model = character(), parameter = character(), estimate = numeric())
      } else tibble::tibble(model = character(), response = character(), level = character(),
        statistic = character(), observed = numeric(), lower = numeric(), upper = numeric(),
        n_defined = integer(), n_below = integer(), n_above = integer())
    }
    dplyr::mutate(rows, cell = cell$cell, repetition, reference_draws, .before = 1)
  }
  list(fits = dplyr::mutate(label_rows("status"), dataset_seed),
       estimates = label_rows("estimates"), checks = label_rows("checks"))
}

# Response-scale partner correlations of responses minus their true fixed-effect
# means, from one large sample per cell (with no missing occasions).
population_effect_sizes <- function(cell) {
  cell$n_dyads <- 20000L
  cell$missing_share <- 0
  generate_occasion_data(cell, 530000000L + cell$cell) |>
    dplyr::mutate(residual = as.numeric(outcome) - true_fixed_mean,
                  member_mean = mean(residual), .by = person) |>
    dplyr::mutate(deviation = residual - member_mean) |>
    dplyr::select(dyad, occasion, gender, member_mean, deviation) |>
    tidyr::pivot_wider(names_from = gender, values_from = c(member_mean, deviation)) |>
    dplyr::summarise(
      between_partner_cor = cor(member_mean_female, member_mean_male),
      within_partner_cor = cor(deviation_female, deviation_male)
    ) |>
    dplyr::mutate(cell = cell$cell, .before = 1)
}

# Flags under both limit rules: quantile() limits (current) and the rank limits of
# PR #77, which flag when fewer than floor(0.05 * (n + 1) / 2) simulations lie beyond.
add_flags <- function(checks) {
  tail_count <- floor(0.05 * (checks$n_defined + 1) / 2)
  dplyr::bind_rows(
    quantile = dplyr::mutate(checks, below = observed < lower, above = observed > upper),
    # Inclusive counts preserve equality at the rank limits: ties do not flag.
    rank = dplyr::mutate(checks, below = n_defined - n_above < tail_count,
                         above = n_defined - n_below < tail_count),
    .id = "rule"
  ) |>
    dplyr::mutate(flagged = below | above)
}

summarise_occasion_study <- function(completed, output_directory,
                                    repetitions = NULL, reference_draws = NULL) {
  fits <- dplyr::bind_rows(lapply(completed, `[[`, "fits"))
  if (is.null(repetitions)) repetitions <- max(fits$repetition)
  if (is.null(reference_draws)) reference_draws <- unique(fits$reference_draws)
  estimates <- dplyr::bind_rows(lapply(completed, `[[`, "estimates"))
  checks <- dplyr::bind_rows(lapply(completed, `[[`, "checks")) |>
    dplyr::left_join(dplyr::select(fits, cell, repetition, model, usable), by = c("cell", "repetition", "model")) |>
    add_flags()
  # Rates over all fits with a check, and over usable fits only.
  by_fit_set <- dplyr::bind_rows(all = checks, usable = dplyr::filter(checks, usable), .id = "fits")
  flags <- by_fit_set |>
    dplyr::summarise(checked = dplyr::n(), flagged = sum(flagged), below = sum(below), above = sum(above),
                     min_defined = if (length(n_defined)) min(n_defined) else NA_integer_,
                     median_defined = median(n_defined),
                     partial_references = sum(n_defined < .env$reference_draws),
                     .by = c(fits, rule, cell, model, response, level, statistic)) |>
    add_rate_intervals() |>
    dplyr::mutate(mcse = sqrt(rate * (1 - rate) / checked))
  figures <- by_fit_set |>
    dplyr::summarise(between = any(flagged[level == "between"]), within = any(flagged[level == "within"]),
                     .by = c(fits, rule, cell, model, response, repetition)) |>
    dplyr::mutate(either = between | within) |>
    tidyr::pivot_longer(c(between, within, either), names_to = "figure", values_to = "flag") |>
    dplyr::summarise(checked = dplyr::n(), flagged = sum(flag), .by = c(fits, rule, cell, model, response, figure)) |>
    add_rate_intervals() |>
    dplyr::mutate(mcse = sqrt(rate * (1 - rate) / checked))
  fit_summary <- fits |>
    dplyr::summarise(optimizer = dplyr::first(optimizer),
                     attempted = dplyr::n(), usable = sum(usable),
                     not_converged = sum(!is.na(convergence) & convergence != 0L),
                     false_convergence = sum(optimizer_message == "false convergence (8)"),
                     not_positive_hessian = sum(positive_hessian %in% FALSE), fit_errors = sum(error != ""),
                     fit_warnings = sum(warnings != ""), estimate_errors = sum(estimate_error != ""),
                     check_errors = sum(check_error != ""), check_warnings = sum(check_warnings != ""),
                     median_fit_seconds = median(fit_seconds), median_check_seconds = median(check_seconds, na.rm = TRUE),
                     .by = c(cell, model))
  correct_models <- dplyr::filter(cell_models, correct)
  true_values <- dplyr::bind_rows(lapply(seq_len(nrow(correct_models)), function(index) {
    dplyr::mutate(true_estimates(correct_models[index, ], correct_models$model[index]),
                  cell = correct_models$cell[index], model = correct_models$model[index])
  }))
  recovery <- estimates |>
    dplyr::inner_join(dplyr::filter(dplyr::select(fits, cell, repetition, model, usable), usable),
                      by = c("cell", "repetition", "model")) |>
    dplyr::inner_join(true_values, by = c("cell", "model", "parameter")) |>
    dplyr::summarise(n = dplyr::n(), true_value = dplyr::first(true_value), mean = mean(estimate),
                     bias = mean - true_value, sd = sd(estimate), .by = c(cell, model, parameter))
  tables <- list(cells = dplyr::mutate(study_cells, repetitions, reference_draws),
                 flags = flags, figures = figures, fits = fit_summary, recovery = recovery,
                 `effect-sizes` = dplyr::bind_rows(lapply(seq_len(nrow(study_cells)), \(index) population_effect_sizes(study_cells[index, ]))))
  for (table_name in c("flags", "figures", "fits", "recovery")) {
    tables[[table_name]] <- dplyr::left_join(tables[[table_name]],
      dplyr::select(cell_models, cell, model, correct, purpose), by = c("cell", "model"))
  }
  for (table_name in names(tables)) {
    write.csv(tables[[table_name]], file.path(output_directory, paste0(table_name, ".csv")), row.names = FALSE)
  }
  tables
}

run_occasion_study <- function(repetitions = 500L, reference_draws = 1000L, workers = 10L, mode = "run") {
  stopifnot(repetitions > 0L, reference_draws >= 40L, workers > 0L, mode %in% c("run", "summarise"))
  output_directory <- file.path(study_directory, "results/ild-partner-dependence",
                                paste0(repetitions, "-datasets-", reference_draws, "-draws"))
  dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)
  # Refuse to combine checkpoints made with different code, designs or software.
  source_files <- c("DESCRIPTION", "NAMESPACE", sort(list.files("R", full.names = TRUE)),
    file.path(study_directory, c("covariance-pooling/run.R", "ild-partner-dependence/run.R")))
  specification <- list(repetitions = repetitions, reference_draws = reference_draws,
    cells = study_cells, models = cell_models, parameters = true_parameters,
    source_hashes = tools::md5sum(source_files), R = R.version.string,
    packages = lapply(c("glmmTMB", "TMB", "Matrix", "dplyr", "tidyr"), packageDescription))
  specification_file <- file.path(output_directory, "run-specification.rds")
  if (file.exists(specification_file)) {
    if (!identical(readRDS(specification_file), specification)) {
      stop("Study code, design or software changed. Use a fresh results directory; do not mix checkpoints.")
    }
  } else {
    if (length(list.files(output_directory, pattern = "^cell-.*[.]rds$"))) {
      stop("Checkpoints have no run specification. Use a fresh results directory.")
    }
    saveRDS(specification, specification_file)
    writeLines(capture.output(sessionInfo()), file.path(output_directory, "session-info.txt"))
    saveRDS(setNames(lapply(source_files, readLines, warn = FALSE), source_files),
      file.path(output_directory, "source-snapshot.rds"))
  }
  block_size <- 10L
  # Each task is one block of datasets in one cell; costly cells start first.
  tasks <- tidyr::crossing(cell = study_cells$cell, block = seq_len(ceiling(repetitions / block_size))) |>
    dplyr::left_join(study_cells, by = "cell") |>
    dplyr::mutate(
      cost = n_dyads * n_occasions * dplyr::case_match(part, "ordinal" ~ 6, "ar" ~ 4, "poisson" ~ 3, .default = 1),
      file = file.path(output_directory, sprintf("cell-%02d-block-%02d.rds", cell, block))
    ) |>
    dplyr::arrange(dplyr::desc(cost), block, cell)
  if (mode == "run") {
    pending <- tasks[!file.exists(tasks$file), ]
    message(format(Sys.time()), ": ", nrow(pending), " of ", nrow(tasks), " blocks to run")
    task_results <- parallel::mclapply(seq_len(nrow(pending)), function(task_index) {
      task <- pending[task_index, ]
      cell <- study_cells[task$cell, ]
      started <- Sys.time()
      repetitions_in_block <- seq.int((task$block - 1L) * block_size + 1L, min(task$block * block_size, repetitions))
      block_results <- lapply(repetitions_in_block, function(repetition) run_occasion_dataset(cell, repetition, reference_draws))
      saveRDS(block_results, paste0(task$file, ".tmp"))
      stopifnot(file.rename(paste0(task$file, ".tmp"), task$file))
      message(format(Sys.time()), ": cell ", task$cell, " (", cell$part, ", ", cell$n_dyads, " dyads, ",
              cell$n_occasions, " occasions) block ", task$block, " done in ",
              round(as.numeric(difftime(Sys.time(), started, units = "mins")), 1), " min")
      NULL
    }, mc.cores = workers, mc.set.seed = FALSE, mc.preschedule = FALSE)
    failed <- vapply(task_results, inherits, logical(1), "try-error")
    if (any(failed)) message(sum(failed), " blocks failed; rerun to resume them.")
  }
  completed <- unlist(lapply(tasks$file[file.exists(tasks$file)], readRDS), recursive = FALSE)
  stopifnot(length(completed) > 0L)
  summarise_occasion_study(completed, output_directory, repetitions, reference_draws)
  if (repetitions == 500L && reference_draws == 1000L && all(file.exists(tasks$file))) {
    report_directory <- file.path(study_directory, "report-data/ild-partner-dependence")
    dir.create(report_directory, showWarnings = FALSE)
    file.copy(file.path(output_directory, paste0(c("cells", "flags", "figures", "fits", "recovery", "effect-sizes"), ".csv")),
              report_directory, overwrite = TRUE)
  }
  message("Saved results: ", output_directory)
  invisible(output_directory)
}

if (sys.nframe() == 0L) {
  arguments <- commandArgs(trailingOnly = TRUE)
  run_occasion_study(
    repetitions = if (length(arguments) >= 1L) as.integer(arguments[1]) else 500L,
    reference_draws = if (length(arguments) >= 2L) as.integer(arguments[2]) else 1000L,
    workers = if (length(arguments) >= 3L) as.integer(arguments[3]) else 10L,
    mode = if (length(arguments) >= 4L) arguments[4] else "run"
  )
}
