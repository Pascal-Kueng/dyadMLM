# Run from the repository root. Existing Gaussian datasets are replayed for
# likelihoods; their checked reference summaries are reused without new draws.
# Selection thresholds: Matuschek et al. (2017), doi:10.1016/j.jml.2017.01.001.
# Single independent variance boundary: Self & Liang (1987),
# doi:10.1080/01621459.1987.10478472 (other nuisance parameters are interior).
source("dev/diagnostic_checks/simulation-studies/ild-partner-dependence/consequences.R")

gaussian_selection_conditions <- function() {
  covariance <- consequence_conditions() |>
    dplyr::mutate(reference_condition = condition, scenario = "covariance")
  slopes <- tidyr::crossing(n_dyads = c(50L, 200L), strength = c(0, 0.2, 0.5)) |>
    dplyr::mutate(condition = nrow(covariance) + dplyr::row_number(),
      reference_condition = NA_integer_, n_occasions = 14L, axis = "random_slope",
      restricted_model = "no_random_slope", scenario = "random_slope")
  dplyr::bind_rows(covariance, slopes)
}

selection_source_directory <- function() {
  file.path(study_directory, "results/ild-partner-dependence-consequences/500-datasets-1000-draws")
}

selection_reference_provenance <- function() {
  directory <- selection_source_directory()
  specification <- readRDS(file.path(directory, "run-specification.rds"))
  helpers <- file.path(study_directory, c("covariance-pooling/run.R",
    "ild-partner-dependence/run.R", "ild-partner-dependence/consequences.R"))
  stopifnot(identical(specification$repetitions, 500L),
    identical(specification$reference_draws, 1000L),
    identical(specification$conditions, consequence_conditions()),
    identical(specification$baseline, true_parameters$gaussian),
    identical(specification$source_hashes[helpers], tools::md5sum(helpers)),
    identical(specification$R, R.version.string),
    identical(specification$packages,
      lapply(c("glmmTMB", "TMB", "Matrix", "dplyr", "tidyr"), packageDescription)))
  checkpoints <- file.path(directory, sprintf("condition-%02d-block-%02d.rds",
    rep(seq_len(24L), each = 50L), rep(seq_len(50L), 24L)))
  stopifnot(all(file.exists(checkpoints)))
  # The original snapshots remain intact, including the original flag rule.
  # Saved counts support the rank rule without changing any reference draws.
  tools::md5sum(c(file.path(directory, c("run-specification.rds", "source-snapshot.rds")), checkpoints))
}

generate_selection_data <- function(condition, seed) {
  if (condition$scenario == "covariance") return(generate_consequence_data(condition, seed))
  baseline <- condition
  baseline$axis <- "stable_cor"
  baseline$strength <- 0.4
  data <- generate_consequence_data(baseline, seed) |>
    dplyr::mutate(x_actor_between = mean(x_actor), x_partner_between = mean(x_partner),
      .by = person) |>
    dplyr::mutate(x_actor_within = x_actor - x_actor_between,
      x_partner_within = x_partner - x_partner_between)
  fixed_mean <- with(data, ifelse(gender == "female", 0.2, -0.1) +
    0.25 * x_actor_between + 0.4 * x_actor_within +
    0.15 * x_partner_between + 0.2 * x_partner_within)
  set.seed(seed + 10000000L)
  random_slopes <- condition$strength * rnorm(nlevels(data$person))
  data$outcome <- data$outcome - data$true_fixed_mean + fixed_mean +
    random_slopes[as.integer(data$person)] * data$x_actor_within
  data$true_fixed_mean <- fixed_mean
  data
}

fit_selection_model <- function(data, condition, fit) {
  if (condition$scenario == "covariance") {
    return(fit_occasion_model(data, list(part = "gaussian"),
      if (fit == "full") "correct" else condition$restricted_model))
  }
  formula <- outcome ~ 0 + gender + x_actor_between + x_actor_within +
    x_partner_between + x_partner_within + us(0 + gender | dyad) +
    us(0 + gender | dyad:occasion)
  if (fit == "full") formula <- update(formula, ~ . + (0 + x_actor_within | person))
  warnings <- character()
  error <- ""
  elapsed <- system.time(fitted_model <- tryCatch(withCallingHandlers(
    glmmTMB::glmmTMB(formula, data = data, family = gaussian(), dispformula = ~0,
      REML = FALSE, control = glmmTMB::glmmTMBControl(optimizer = optim,
        optArgs = list(method = "BFGS"), optCtrl = list(maxit = 1000, reltol = 1e-10), parallel = 1L)),
    warning = function(warning) {
      warnings <<- c(warnings, conditionMessage(warning))
      invokeRestart("muffleWarning")
    }), error = function(condition) {
      error <<- conditionMessage(condition)
      NULL
    }))["elapsed"]
  usable <- !is.null(fitted_model) && fitted_model$fit$convergence == 0L &&
    isTRUE(fitted_model$sdr$pdHess) && is.finite(as.numeric(logLik(fitted_model)))
  list(model = fitted_model, status = tibble::tibble(model = fit, optimizer = "BFGS", usable,
    convergence = if (is.null(fitted_model)) NA_integer_ else fitted_model$fit$convergence,
    optimizer_message = if (is.null(fitted_model$fit$message)) "" else fitted_model$fit$message,
    positive_hessian = if (is.null(fitted_model)) NA else isTRUE(fitted_model$sdr$pdHess),
    warnings = paste(unique(warnings), collapse = " | "), error, fit_seconds = as.numeric(elapsed)))
}

selection_inference <- function(model, condition) {
  if (condition$scenario == "covariance") {
    return(record_consequence_inference(model, consequence_truth(condition)))
  }
  coefficients <- glmmTMB::fixef(model)$cond
  covariance <- stats::vcov(model)$cond[names(coefficients), names(coefficients), drop = FALSE]
  parameters <- c("x_actor_between", "x_actor_within", "x_partner_between", "x_partner_within",
    "role_average_intercept", "role_difference")
  contrasts <- matrix(0, length(parameters), length(coefficients), dimnames = list(parameters, names(coefficients)))
  for (parameter in parameters[1:4]) contrasts[parameter, parameter] <- 1
  contrasts["role_average_intercept", c("genderfemale", "gendermale")] <- 0.5
  contrasts["role_difference", c("genderfemale", "gendermale")] <- c(1, -1)
  estimate <- as.vector(contrasts %*% coefficients)
  se <- sqrt(diag(contrasts %*% covariance %*% t(contrasts)))
  true_value <- c(0.25, 0.4, 0.15, 0.2, 0.05, 0.3)
  defined <- is.finite(estimate) & is.finite(se) & se > 0
  tibble::tibble(parameter = parameters, true_value, estimate, se = unname(se), defined,
    covered = ifelse(defined, abs(estimate - true_value) <= qnorm(0.975) * se, NA))
}

selection_lrt <- function(fits, boundary = FALSE) {
  full <- fits[fits$fit == "full", ]
  restricted <- fits[fits$fit == "restricted", ]
  difference <- full$log_likelihood - restricted$log_likelihood
  df <- full$likelihood_df - restricted$likelihood_df
  defined <- all(fits$usable) && is.finite(difference) && difference >= -1e-6 && identical(as.integer(df), 1L)
  statistic <- if (defined) 2 * max(0, difference) else NA_real_
  # Only the added independent slope variance is tested on a boundary. Its
  # asymptotic 50:50 mixture is evaluated, not assumed calibrated, at SD = 0.
  p <- if (!defined) NA_real_ else if (boundary && statistic > 0) {
    0.5 * pchisq(statistic, 1, lower.tail = FALSE)
  } else pchisq(statistic, 1, lower.tail = FALSE)
  tibble::tibble(lrt_defined = defined, lrt_statistic = statistic, lrt_df = df,
    lrt_p = p, reversed_likelihood = all(fits$usable) && is.finite(difference) && difference < -1e-6,
    lrt_reference = if (boundary) "0.5 chi0 + 0.5 chi1" else "chi1")
}

selection_fit_eligibility <- function(fits, comparison = selection_lrt(fits)) {
  # Preserve optimizer usability. A worse full-model likelihood identifies an
  # unresolved fit even when its optimizer and Hessian checks passed.
  dplyr::mutate(fits, likelihood_reversal = fit == "full" & comparison$reversed_likelihood,
    eligible = usable & !likelihood_reversal)
}

selection_decisions <- function(fits, checks, condition, reference_draws) {
  lrt <- selection_lrt(fits, condition$scenario == "random_slope")
  fits <- selection_fit_eligibility(fits, lrt)
  usable <- setNames(fits$eligible & fits$inference_defined, fits$fit)
  target_level <- if (condition$axis == "stable_cor") "between" else "within"
  target_statistic <- if (condition$axis == "occasion_sd_ratio") "average_difference_cor" else "partner_cor"
  complete <- nrow(checks) == 12L && all(checks$n_defined == reference_draws) &&
    all(is.finite(as.matrix(checks[c("observed", "lower", "upper")])))
  flagged <- add_flags(checks)
  check_flag <- function(rule, targeted) {
    if (!complete) return(NA)
    rows <- flagged$rule == rule
    if (targeted) rows <- rows & flagged$level == target_level & flagged$statistic == target_statistic
    if (!any(rows)) return(NA)
    any(flagged$flagged[rows])
  }
  candidates <- tibble::tibble(
    method = c("always_full", "always_restricted", "lrt_05", "lrt_20", "check_rank_any", "check_quantile_any"),
    retain_full = c(TRUE, FALSE, lrt$lrt_p < 0.05, lrt$lrt_p < 0.20,
      check_flag("rank", FALSE), check_flag("quantile", FALSE)))
  if (condition$scenario == "covariance") candidates <- dplyr::bind_rows(candidates,
    tibble::tibble(method = c("check_rank_target", "check_quantile_target"),
      retain_full = c(check_flag("rank", TRUE), check_flag("quantile", TRUE))))
  candidates$selected <- NA_character_
  candidates$fallback <- FALSE
  candidates$reason <- "comparison_undefined"
  for (index in seq_len(nrow(candidates))) {
    fixed <- startsWith(candidates$method[index], "always_")
    if (fixed) {
      preferred <- if (candidates$retain_full[index]) "full" else "restricted"
      candidates$selected[index] <- if (usable[preferred]) preferred else NA_character_
      candidates$reason[index] <- if (usable[preferred]) "fixed_model" else "model_unavailable"
    } else if (sum(usable) == 1L) {
      candidates$selected[index] <- names(usable)[usable]
      candidates$fallback[index] <- TRUE
      candidates$reason[index] <- "only_eligible_model"
    } else if (!any(usable)) {
      candidates$reason[index] <- "both_models_unavailable"
    } else if (!is.na(candidates$retain_full[index])) {
      candidates$selected[index] <- if (candidates$retain_full[index]) "full" else "restricted"
      candidates$reason[index] <- "selection_rule"
    }
  }
  dplyr::mutate(candidates, paired = all(usable), !!!as.list(lrt))
}

run_gaussian_selection_dataset <- function(condition, repetition, reference_draws) {
  dataset_seed <- if (condition$scenario == "covariance") {
    1200000000L + 10000L * condition$reference_condition + repetition
  } else 1400000000L + 10000L * condition$condition + repetition
  data <- generate_selection_data(condition, dataset_seed)
  fitted <- lapply(c("full", "restricted"), function(fit) fit_selection_model(data, condition, fit))
  names(fitted) <- c("full", "restricted")
  inference <- fits <- list()
  for (fit in names(fitted)) {
    model <- fitted[[fit]]$model
    error <- ""
    inference[[fit]] <- tryCatch(if (is.null(model)) tibble::tibble() else selection_inference(model, condition),
      error = function(condition) { error <<- conditionMessage(condition); tibble::tibble() })
    likelihood <- if (is.null(model)) NA_real_ else logLik(model)
    fits[[fit]] <- dplyr::mutate(fitted[[fit]]$status,
      log_likelihood = as.numeric(likelihood),
      likelihood_df = if (is.null(attr(likelihood, "df"))) NA_integer_ else attr(likelihood, "df"),
      inference_error = error, inference_defined = nrow(inference[[fit]]) ==
        ifelse(condition$scenario == "covariance", 4L, 6L) && all(inference[[fit]]$defined))
  }
  fits <- dplyr::bind_rows(fits, .id = "fit")
  inference <- dplyr::bind_rows(inference, .id = "fit")
  checks <- tibble::tibble()
  check_error <- ""
  check_warnings <- character()
  reference_source <- "new_draws"
  replay_max_difference <- NA_real_
  if (condition$scenario == "covariance") {
    old <- readRDS(file.path(selection_source_directory(), sprintf("condition-%02d-block-%02d.rds",
      condition$reference_condition, ceiling(repetition / 10L))))[[(repetition - 1L) %% 10L + 1L]]
    stopifnot(all(old$fits$dataset_seed == dataset_seed), all(old$fits$reference_draws == reference_draws),
      identical(fits$usable, old$fits$usable), nrow(inference) == nrow(old$inference),
      identical(inference$fit, old$inference$fit), identical(inference$parameter, old$inference$parameter),
      identical(inference$true_value, old$inference$true_value))
    replay_max_difference <- max(abs(as.matrix(inference[c("estimate", "se")]) -
      as.matrix(old$inference[c("estimate", "se")])))
    if (!is.finite(replay_max_difference) || replay_max_difference > 1e-7) {
      stop("Replayed fit differs from the saved fit; its reference summaries cannot be reused.")
    }
    checks <- dplyr::select(old$checks, level, statistic, observed, lower, upper, n_defined, n_below, n_above)
    reference_source <- "verified_completed_consequences"
  } else if (fits$usable[fits$fit == "restricted"]) {
    checks <- tryCatch(withCallingHandlers(suppressMessages({
      simulations <- simulate_dyad_responses(fitted$restricted$model, nsim = reference_draws,
        seed = dataset_seed + 100000000L)
      record_occasion_check(check_partner_dependence(simulations, dyad = dyad, role = gender,
        member = person, time = occasion, data = data, plot = FALSE))
    }), warning = function(warning) {
      check_warnings <<- c(check_warnings, conditionMessage(warning))
      invokeRestart("muffleWarning")
    }), error = function(condition) { check_error <<- conditionMessage(condition); tibble::tibble() })
  }
  # Preserve an empty schema for a failed check so selection abstains cleanly.
  if (!nrow(checks)) checks <- tibble::tibble(level = character(), statistic = character(), observed = numeric(),
    lower = numeric(), upper = numeric(), n_defined = integer(), n_below = integer(), n_above = integer())
  fits <- selection_fit_eligibility(fits)
  decisions <- selection_decisions(fits, checks, condition, reference_draws)
  fits <- dplyr::mutate(fits, dataset_seed, replay_max_difference, reference_source,
    check_error = ifelse(fit == "restricted", check_error, ""),
    check_warnings = ifelse(fit == "restricted", paste(unique(check_warnings), collapse = " | "), ""))
  label <- function(rows) dplyr::mutate(rows, condition = condition$condition, repetition, .before = 1)
  list(fits = label(fits), inference = label(inference), checks = label(checks), decisions = label(decisions))
}

summarise_gaussian_selection <- function(completed, conditions, directory, repetitions, reference_draws) {
  fits <- dplyr::bind_rows(lapply(completed, `[[`, "fits"))
  decisions <- dplyr::bind_rows(lapply(completed, `[[`, "decisions"))
  estimates <- dplyr::bind_rows(lapply(completed, `[[`, "inference"))
  selected <- decisions |>
    dplyr::filter(!is.na(selected)) |>
    dplyr::inner_join(estimates, by = c("condition", "repetition", "selected" = "fit"),
      relationship = "many-to-many") |>
    dplyr::filter(defined)
  # Subtracting X beta from a Gaussian response leaves covariance likelihoods,
  # SEs and model-centred checks unchanged. Both fitted candidates have the same
  # fixed-effect design. These are matched null cases, not independent datasets.
  cases <- dplyr::bind_rows(nonzero = selected,
    null = dplyr::mutate(selected, estimate = estimate - true_value, true_value = 0), .id = "effect_case") |>
    dplyr::mutate(covered = abs(estimate - true_value) <= qnorm(0.975) * se,
      significant = abs(estimate) > qnorm(0.975) * se)
  samples <- dplyr::bind_rows(all = cases, paired = dplyr::filter(cases, paired), .id = "sample")
  inference <- samples |>
    dplyr::summarise(n = dplyr::n(), true_value = dplyr::first(true_value), bias = mean(estimate - true_value),
      bias_mcse = sd(estimate) / sqrt(n), empirical_sd = sd(estimate), mean_se = mean(se),
      se_ratio = mean_se / empirical_sd, covered = sum(covered), rejected = sum(significant),
      .by = c(condition, method, sample, effect_case, parameter))
  rates <- function(table, count, prefix) {
    intervals <- add_rate_intervals(dplyr::mutate(table, checked = n, flagged = .data[[count]]))
    table[[prefix]] <- intervals$rate
    table[[paste0(prefix, "_lower")]] <- intervals$lower
    table[[paste0(prefix, "_upper")]] <- intervals$upper
    table[[paste0(prefix, "_mcse")]] <- sqrt(intervals$rate * (1 - intervals$rate) / table$n)
    table
  }
  inference <- rates(rates(inference, "covered", "coverage"), "rejected", "rejection")
  selection <- decisions |>
    dplyr::summarise(attempted = dplyr::n(), returned = sum(!is.na(selected)),
      full_selected = sum(selected == "full", na.rm = TRUE), fallback = sum(fallback),
      paired = sum(paired), lrt_defined = sum(lrt_defined), reversed_likelihood = sum(reversed_likelihood),
      .by = c(condition, method))
  fit_summary <- fits |>
    dplyr::summarise(attempted = dplyr::n(), inference_defined = sum(eligible & inference_defined),
      usable = sum(usable), eligible = sum(eligible), likelihood_reversals = sum(likelihood_reversal),
      not_converged = sum(!is.na(convergence) & convergence != 0),
      not_positive_hessian = sum(positive_hessian %in% FALSE), errors = sum(error != ""),
      warnings = sum(warnings != ""), inference_errors = sum(inference_error != ""),
      check_errors = sum(check_error != ""), check_warnings = sum(check_warnings != ""),
      replay_max_difference = if (all(is.na(replay_max_difference))) NA_real_ else max(replay_max_difference, na.rm = TRUE),
      median_fit_seconds = median(fit_seconds), .by = c(condition, fit))
  # Pair each selected interval with the full model on the same dataset. This
  # gives Monte Carlo uncertainty for the selection-induced coverage change.
  full <- dplyr::filter(cases, method == "always_full") |>
    dplyr::select(condition, repetition, effect_case, parameter, full_covered = covered)
  comparisons <- dplyr::filter(cases, paired) |>
    dplyr::inner_join(full, by = c("condition", "repetition", "effect_case", "parameter")) |>
    dplyr::mutate(change = as.integer(covered) - as.integer(full_covered)) |>
    dplyr::summarise(n = dplyr::n(), coverage_change = mean(change),
      coverage_change_mcse = sd(change) / sqrt(n), .by = c(condition, method, effect_case, parameter))
  tables <- list(conditions = dplyr::mutate(conditions, repetitions, reference_draws), fits = fit_summary,
    selection = selection, inference = inference, comparisons = comparisons)
  for (name in names(tables)) write.csv(tables[[name]], file.path(directory, paste0(name, ".csv")), row.names = FALSE)
  invisible(tables)
}

run_gaussian_selection <- function(repetitions = 500L, reference_draws = 1000L, workers = 10L, mode = "run") {
  stopifnot(repetitions > 0L, repetitions <= 500L, reference_draws == 1000L, workers > 0L,
    mode %in% c("run", "summarise"))
  conditions <- gaussian_selection_conditions()
  directory <- file.path(study_directory, "results/model-simplification-gaussian",
    paste0(repetitions, "-datasets-", reference_draws, "-draws"))
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  sources <- c("DESCRIPTION", "NAMESPACE", sort(list.files("R", full.names = TRUE)),
    file.path(study_directory, c("covariance-pooling/run.R", "ild-partner-dependence/run.R",
      "ild-partner-dependence/consequences.R", "model-simplification/gaussian.R")))
  specification <- list(repetitions = repetitions, reference_draws = reference_draws, conditions = conditions,
    source_hashes = tools::md5sum(sources), reused_references = selection_reference_provenance(),
    R = R.version.string, packages = lapply(c("glmmTMB", "TMB", "Matrix", "dplyr", "tidyr"), packageDescription))
  specification_file <- file.path(directory, "run-specification.rds")
  if (file.exists(specification_file)) {
    if (!identical(readRDS(specification_file), specification)) {
      stop("Study code, references, design or software changed. Use a fresh directory; do not mix checkpoints.")
    }
  } else {
    if (length(list.files(directory, "^condition-.*[.]rds$"))) stop("Checkpoints have no run specification.")
    saveRDS(specification, specification_file)
    saveRDS(setNames(lapply(sources, readLines, warn = FALSE), sources), file.path(directory, "source-snapshot.rds"))
    writeLines(capture.output(sessionInfo()), file.path(directory, "session-info.txt"))
  }
  tasks <- tidyr::crossing(condition = conditions$condition, block = seq_len(ceiling(repetitions / 10L))) |>
    dplyr::left_join(conditions, by = "condition") |>
    dplyr::mutate(file = file.path(directory, sprintf("condition-%02d-block-%02d.rds", condition, block))) |>
    dplyr::arrange(dplyr::desc(n_dyads), dplyr::desc(scenario), block, condition)
  if (mode == "run") {
    pending <- tasks[!file.exists(tasks$file), ]
    message(format(Sys.time()), ": ", nrow(pending), " of ", nrow(tasks), " blocks to run")
    results <- parallel::mclapply(seq_len(nrow(pending)), function(index) {
      task <- pending[index, ]
      condition <- conditions[match(task$condition, conditions$condition), ]
      started <- Sys.time()
      repetitions_in_block <- seq.int((task$block - 1L) * 10L + 1L, min(task$block * 10L, repetitions))
      completed <- tryCatch(lapply(repetitions_in_block, function(repetition) {
        run_gaussian_selection_dataset(condition, repetition, reference_draws)
      }), error = function(error) {
        message("FAILED condition ", condition$condition, " block ", task$block, ": ", conditionMessage(error))
        stop(error)
      })
      saveRDS(completed, paste0(task$file, ".tmp"))
      stopifnot(file.rename(paste0(task$file, ".tmp"), task$file))
      message(format(Sys.time()), ": condition ", condition$condition, " (", condition$axis,
        ", ", condition$strength, ", ", condition$n_dyads, " dyads) block ", task$block,
        " done in ", round(as.numeric(difftime(Sys.time(), started, units = "mins")), 1), " min")
      NULL
    }, mc.cores = workers, mc.set.seed = FALSE, mc.preschedule = FALSE)
    if (any(vapply(results, inherits, logical(1), "try-error"))) message("Some blocks failed; rerun to resume them.")
  }
  completed <- unlist(lapply(tasks$file[file.exists(tasks$file)], readRDS), recursive = FALSE)
  if (!length(completed)) stop("No completed datasets.")
  summarise_gaussian_selection(completed, conditions, directory, repetitions, reference_draws)
  if (repetitions == 500L && all(file.exists(tasks$file))) {
    keys <- dplyr::bind_rows(lapply(completed, `[[`, "fits"))
    stopifnot(nrow(keys) == 2L * nrow(conditions) * repetitions,
      !anyDuplicated(keys[c("condition", "repetition", "fit")]),
      all(table(keys$condition, keys$fit) == repetitions))
    report_directory <- file.path(study_directory, "report-data/model-simplification-gaussian")
    dir.create(report_directory, showWarnings = FALSE)
    file.copy(file.path(directory, paste0(c("conditions", "fits", "selection", "inference", "comparisons"), ".csv")),
      report_directory, overwrite = TRUE)
  }
  message("Saved results: ", directory)
  invisible(directory)
}
