# Run from this PR77 checkout. Reuse the original helpers without changes.
source("dev/diagnostic_checks/simulation-studies/generalized-covariance-pooling/helpers.R")

# Reject materially worse nested maxima; retain nominal optimizer/Hessian status.
# The public comparator has its own stricter rounding tolerance. A smaller
# reversal can therefore leave an eligible fit but an explicitly undefined LRT.
nb2_likelihood_tolerance <- 1e-6

nb2_fallback_conditions <- function() {
  generalized_conditions |>
    dplyr::filter(n_dyads %in% c(100L, 400L),
      scenario %in% c("null", "variance_large", "correlation_large")) |>
    dplyr::mutate(original_condition = condition, condition = dplyr::row_number())
}

nb2_fallback_truth <- function() {
  roles <- c("female_x_female", "female_x_male_female", "female_x_male_male", "male_x_male")
  names <- paste0(".composition_role", roles)
  stats::setNames(c(log(3) + c(.2, .4, -.2, -.1), c(.5, 0, .4, .3), c(.3, .2, .4, .2)),
    c(names, paste0(names, ":.support_actor"), paste0(names, ":.support_partner")))
}

generate_nb2_fallback_data <- function(condition, seed) {
  data <- generate_covariance_data(condition, seed)
  # Keep the original latent draws; change the actual count-generating predictor.
  latent <- .6 * (data$outcome - true_fixed_predictor(data))
  design <- stats::model.matrix(generalized_fixed_formula, data)
  truth <- nb2_fallback_truth()
  stopifnot(setequal(colnames(design), names(truth)))
  location <- as.vector(design[, names(truth), drop = FALSE] %*% truth)
  data$outcome <- stats::rnbinom(nrow(data), mu = exp(location + latent), size = 3)
  data
}

nb2_fallback_contrasts <- function() {
  truth <- nb2_fallback_truth()
  contrasts <- matrix(0, 4L, length(truth), dimnames = list(
    c("female_actor_null", "female_partner", "male_actor", "female_minus_male_intercept"), names(truth)))
  contrasts[1, ".composition_rolefemale_x_male_female:.support_actor"] <- 1
  contrasts[2, ".composition_rolefemale_x_male_female:.support_partner"] <- 1
  contrasts[3, ".composition_rolefemale_x_male_male:.support_actor"] <- 1
  contrasts[4, c(".composition_rolefemale_x_male_female", ".composition_rolefemale_x_male_male")] <- c(1, -1)
  contrasts
}

nb2_fallback_inference <- function(model) {
  truth <- nb2_fallback_truth()
  contrast <- rbind(diag(length(truth)), nb2_fallback_contrasts())
  rownames(contrast) <- c(names(truth), rownames(nb2_fallback_contrasts()))
  colnames(contrast) <- names(truth)
  estimate <- se <- rep(NA_real_, nrow(contrast))
  if (!is.null(model)) {
    coefficients <- glmmTMB::fixef(model)$cond[names(truth)]
    covariance <- stats::vcov(model)$cond[names(truth), names(truth), drop = FALSE]
    estimate <- as.vector(contrast %*% coefficients)
    se <- sqrt(diag(contrast %*% covariance %*% t(contrast)))
  }
  true_value <- as.vector(contrast %*% truth)
  defined <- is.finite(estimate) & is.finite(se) & se > 0
  tibble::tibble(parameter = rownames(contrast), primary = seq_len(nrow(contrast)) > length(truth),
    true_value, estimate, se = unname(se), defined,
    covered = ifelse(defined, abs(estimate - true_value) <= qnorm(.975) * se, NA),
    significant = ifelse(defined, abs(estimate) > qnorm(.975) * se, NA))
}

nb2_scalar_check <- function(values) {
  references <- values[-1]
  limits <- dyadMLM:::simulated_rank_limits(references)
  tibble::tibble(observed = values[1], lower = limits[1], upper = limits[2],
    flagged = values[1] < limits[1] | values[1] > limits[2],
    reference_defined = sum(is.finite(references)),
    reference_below = sum(references < values[1], na.rm = TRUE),
    reference_above = sum(references > values[1], na.rm = TRUE), finite_curve = NA)
}

nb2_curve_check <- function(curves) {
  if (!is.list(curves[[1]])) curves <- list(curves)
  values <- dplyr::bind_rows(lapply(curves, as.data.frame))
  finite <- all(is.finite(as.matrix(values[c("observed", "lower", "upper")])))
  tibble::tibble(observed = NA_real_, lower = NA_real_, upper = NA_real_,
    flagged = if (finite) any(values$observed < values$lower | values$observed > values$upper) else NA,
    reference_defined = NA_integer_, reference_below = NA_integer_, reference_above = NA_integer_,
    finite_curve = finite)
}

empty_nb2_fallback_checks <- function() {
  tibble::tibble(condition = integer(), repetition = integer(), dataset_seed = integer(),
    observed = double(), lower = double(), upper = double(), flagged = logical(),
    reference_defined = integer(), reference_below = integer(), reference_above = integer(),
    finite_curve = logical(), check = character(), composition = character(),
    role = character(), statistic = character())
}

record_nb2_fallback_checks <- function(simulations, data, seed) {
  dependence <- check_partner_dependence(simulations, dyad = coupleID, role = gender,
    data = data, plot = FALSE)
  dependence_rows <- dplyr::bind_rows(lapply(seq_len(nrow(dependence$compositions)), function(i) {
    composition <- dependence$compositions[i, ]
    statistics <- composition$statistics[[1]][, -1]
    dplyr::bind_rows(lapply(names(statistics), function(statistic) {
      dplyr::mutate(nb2_scalar_check(statistics[[statistic]]), check = "dependence",
        composition = composition$label, role = "Pair", statistic)
    }))
  }))
  residual <- check_dyad_residuals(simulations, dyad = coupleID, role = gender,
    data = data, plot = FALSE, seed = seed)
  residual_rows <- dplyr::bind_rows(lapply(residual$compositions, function(composition) {
    dplyr::bind_rows(lapply(names(composition$rows), function(role) {
      statistics <- composition$statistics[[role]]
      pattern <- composition$patterns[[1]][[role]]
      dplyr::bind_rows(nb2_curve_check(statistics$qq), nb2_scalar_check(statistics$mean_distance),
        nb2_curve_check(pattern$quantiles), nb2_curve_check(pattern$distance)) |>
        dplyr::mutate(check = "residual", composition = composition$label, role,
          statistic = c("qq", "mean_distance", "predicted_quantiles", "predicted_distance"))
    }))
  }))
  outcome <- check_dyad_outcomes(simulations, dyad = coupleID, role = gender, data = data, plot = FALSE)
  outcome_rows <- dplyr::bind_rows(lapply(outcome$compositions, function(composition) {
    dplyr::bind_rows(lapply(names(composition$rows), function(role) {
      statistics <- composition$statistics[[role]]
      dplyr::bind_rows(lapply(rownames(statistics), function(statistic) {
        dplyr::mutate(nb2_scalar_check(statistics[statistic, ]), check = "outcome",
          composition = composition$label, role, statistic)
      }))
    }))
  }))
  dplyr::bind_rows(dependence_rows, residual_rows, outcome_rows)
}

run_nb2_fallback_dataset <- function(condition, repetition, reference_draws) {
  seed <- 1400000000L + condition$condition * 10000L + repetition
  data <- generate_nb2_fallback_data(condition, seed)
  models <- list(pooled = fit_generalized_covariance_model(data, "nbinom2", "pooled"),
    full = fit_generalized_covariance_model(data, "nbinom2", "composition"))
  fits <- dplyr::bind_rows(lapply(names(models), function(name) {
    likelihood <- tryCatch(stats::logLik(models[[name]]$model), error = function(error) NULL)
    dplyr::mutate(models[[name]]$status, model = name, inference_error = "",
      log_likelihood = if (is.null(likelihood)) NA_real_ else as.numeric(likelihood),
      likelihood_df = if (is.null(likelihood)) NA_integer_ else as.integer(attr(likelihood, "df")))
  }))
  likelihood_delta <- diff(fits$log_likelihood)
  likelihood_reversal <- all(fits$usable) && is.finite(likelihood_delta) &&
    likelihood_delta < -nb2_likelihood_tolerance
  fits$eligible <- fits$usable
  fits$eligibility_reason <- ifelse(fits$usable, "", "optimizer_or_hessian_failure")
  if (likelihood_reversal) {
    fits$eligible[2] <- FALSE
    fits$eligibility_reason[2] <- "full_likelihood_lower_than_pooled"
  }
  inference <- dplyr::bind_rows(lapply(seq_along(models), function(index) {
    rows <- tryCatch(nb2_fallback_inference(models[[index]]$model), error = function(error) {
      fits$inference_error[index] <<- conditionMessage(error)
      nb2_fallback_inference(NULL)
    })
    dplyr::mutate(rows, model = names(models)[index], usable = fits$usable[index],
      eligible = fits$eligible[index])
  }))
  covariance <- lapply(models, function(fit) {
    if (is.null(fit$model)) return(NULL)
    tryCatch(stats::vcov(fit$model)$cond, error = function(error) NULL)
  })
  comparison_error <- ""
  lrt_p <- lrt_statistic <- lrt_df <- NA_real_
  if (all(fits$eligible)) {
    comparison <- tryCatch(compare_nested_models(models$pooled$model, models$full$model),
      error = function(error) { comparison_error <<- conditionMessage(error); NULL })
    if (!is.null(comparison)) {
      lrt_p <- comparison[["Pr(>Chisq)"]][2]
      lrt_statistic <- comparison[["Chisq"]][2]
      lrt_df <- comparison[["Chi Df"]][2]
    }
  }
  # Undefined LRTs with two usable fits do not silently select a model.
  selected <- c(pooled = if (fits$eligible[1]) "pooled" else NA_character_,
    full = if (fits$eligible[2]) "full" else NA_character_,
    full_then_pooled = if (fits$eligible[2]) "full" else if (fits$eligible[1]) "pooled" else NA_character_,
    lrt_05 = if (all(fits$eligible)) {
      if (is.finite(lrt_p)) if (lrt_p < .05) "full" else "pooled" else NA_character_
    } else if (fits$eligible[2]) "full" else if (fits$eligible[1]) "pooled" else NA_character_)
  policies <- dplyr::bind_rows(lapply(names(selected), function(policy) {
    if (is.na(selected[[policy]])) rows <- nb2_fallback_inference(NULL) else
      rows <- inference[inference$model == selected[[policy]], ]
    dplyr::mutate(dplyr::filter(rows, primary), policy = .env$policy,
      selected_model = .env$selected[[.env$policy]],
      available = !is.na(selected_model) & defined)
  }))
  checks <- empty_nb2_fallback_checks()
  check_error <- check_warnings <- ""
  simulation_finite <- NA
  check_seconds <- NA_real_
  if (fits$eligible[1]) {
    started <- proc.time()[["elapsed"]]
    messages <- character()
    checks <- tryCatch(withCallingHandlers({
      simulations <- simulate_dyad_responses(models$pooled$model, nsim = reference_draws,
        seed = seed + 100000000L)
      simulation_finite <- all(is.finite(simulations$simulated_responses))
      stopifnot(simulation_finite, nrow(simulations$simulated_responses) == reference_draws)
      record_nb2_fallback_checks(simulations, data, seed + 200000000L)
    }, warning = function(warning) {
      messages <<- c(messages, conditionMessage(warning)); invokeRestart("muffleWarning")
    }), error = function(error) {
      check_error <<- conditionMessage(error); empty_nb2_fallback_checks()
    })
    check_warnings <- paste(unique(messages), collapse = " | ")
    check_seconds <- proc.time()[["elapsed"]] - started
  }
  identify <- function(table) if (!is.null(table)) dplyr::mutate(table,
    condition = .env$condition$condition, repetition = .env$repetition,
    dataset_seed = .env$seed, .before = 1)
  list(fits = identify(fits), inference = identify(inference), policies = identify(policies),
    checks = identify(checks), covariance = covariance,
    status = tibble::tibble(condition = condition$condition, repetition, dataset_seed = seed,
      lrt_p, lrt_statistic, lrt_df, likelihood_delta, likelihood_reversal, comparison_error, check_error,
      check_warnings, simulation_finite, check_seconds))
}

nb2_fallback_specification <- function(repetitions, reference_draws) {
  sources <- sort(c(list.files("R", "[.]R$", full.names = TRUE), "DESCRIPTION", "NAMESPACE",
    "dev/diagnostic_checks/simulation-studies/covariance-pooling/run.R",
    "dev/diagnostic_checks/simulation-studies/generalized-covariance-pooling/helpers.R",
    "dev/diagnostic_checks/simulation-studies/shared/family-margins.R",
    "dev/diagnostic_checks/simulation-studies/model-simplification/nb2-fallback.R"))
  packages <- c("dyadMLM", "glmmTMB", "TMB", "Matrix", "dplyr", "tidyr", "rlang", "withr")
  list(repetitions = as.integer(repetitions), reference_draws = as.integer(reference_draws),
    conditions = nb2_fallback_conditions(), truth = nb2_fallback_truth(),
    likelihood_tolerance = nb2_likelihood_tolerance,
    sources = tools::md5sum(sources), R = R.version.string,
    software = stats::setNames(vapply(packages, function(package)
      as.character(utils::packageVersion(package)), character(1)), packages),
    glmmTMB_commit = utils::packageDescription("glmmTMB")$RemoteSha)
}

summarise_nb2_fallback <- function(completed, conditions) {
  tables <- lapply(c("fits", "inference", "policies", "checks", "status"), function(name)
    dplyr::bind_rows(lapply(completed, function(result) result[[name]])))
  names(tables) <- c("fits", "inference", "policies", "checks", "status")
  expected <- sum(conditions$repetitions)
  stopifnot(nrow(tables$status) == expected, nrow(tables$fits) == 2L * expected,
    nrow(tables$inference) == 32L * expected, nrow(tables$policies) == 16L * expected,
    !anyDuplicated(tables$status[c("condition", "repetition")]),
    !anyDuplicated(tables$fits[c("condition", "repetition", "model")]),
    !anyDuplicated(tables$inference[c("condition", "repetition", "model", "parameter")]),
    !anyDuplicated(tables$policies[c("condition", "repetition", "policy", "parameter")]))
  for (condition in conditions$condition) stopifnot(identical(sort(
    tables$status$repetition[tables$status$condition == condition]), seq_len(conditions$repetitions[1])))
  fit_summary <- tables$fits |>
    dplyr::summarise(attempted = dplyr::n(), failed = sum(!usable), warnings = sum(warnings != ""),
      errors = sum(error != ""), inference_errors = sum(inference_error != ""),
      eligible_n = sum(eligible),
      likelihood_reversals = sum(eligibility_reason == "full_likelihood_lower_than_pooled"),
      seconds = sum(elapsed_seconds), usable = sum(usable), .by = c(condition, model))
  inference <- tables$inference |>
    dplyr::mutate(available = eligible & defined, method = paste0("fit_", model))
  policy_inference <- tables$policies |> dplyr::mutate(method = paste0("policy_", policy))
  inference_summary <- dplyr::bind_rows(inference, policy_inference) |>
    dplyr::summarise(attempted = dplyr::n(), available_n = sum(available),
      bias = mean(estimate[available] - true_value[available]),
      empirical_sd = stats::sd(estimate[available]), mean_se = mean(se[available]),
      rms_se = sqrt(mean(se[available]^2)), covered_n = sum(covered[available]),
      rejected_n = sum(significant[available]),
      .by = c(condition, method, parameter, primary, true_value)) |>
    dplyr::mutate(coverage = covered_n / available_n, rejection = rejected_n / available_n,
      coverage_mcse = sqrt(coverage * (1 - coverage) / available_n),
      rejection_mcse = sqrt(rejection * (1 - rejection) / available_n),
      se_ratio = mean_se / empirical_sd, available_fraction = available_n / attempted)
  for (metric in c("coverage", "rejection")) {
    numerator <- if (metric == "coverage") inference_summary$covered_n else inference_summary$rejected_n
    interval <- add_rate_intervals(data.frame(checked = inference_summary$available_n, flagged = numerator))
    inference_summary[[paste0(metric, "_lower")]] <- interval$lower
    inference_summary[[paste0(metric, "_upper")]] <- interval$upper
  }
  # Union rates are descriptive and kept separate from individual panels.
  observed_unions <- tables$checks |>
    dplyr::summarise(flagged = if (anyNA(flagged)) NA else any(flagged),
      .by = c(condition, repetition, check))
  unions <- tidyr::crossing(condition = conditions$condition,
    repetition = seq_len(conditions$repetitions[1]), check = c("dependence", "residual", "outcome")) |>
    dplyr::left_join(observed_unions, by = c("condition", "repetition", "check")) |>
    dplyr::mutate(composition = "All", role = "All", statistic = "any_panel", scope = "union")
  availability <- tables$fits |>
    dplyr::select(condition, repetition, model, eligible) |>
    tidyr::pivot_wider(names_from = model, values_from = eligible, names_prefix = "eligible_") |>
    dplyr::mutate(full_fit = ifelse(eligible_full, "eligible", "ineligible"))
  denominators <- dplyr::bind_rows(availability, dplyr::mutate(availability, full_fit = "all")) |>
    dplyr::summarise(attempted = dplyr::n(), pooled_usable = sum(eligible_pooled),
      .by = c(condition, full_fit))
  flag_rows <- dplyr::bind_rows(dplyr::mutate(tables$checks, scope = "panel"), unions) |>
    dplyr::left_join(dplyr::select(availability, condition, repetition, full_fit),
      by = c("condition", "repetition"))
  flags <- dplyr::bind_rows(flag_rows, dplyr::mutate(flag_rows, full_fit = "all")) |>
    dplyr::summarise(checked = sum(!is.na(flagged)), flagged_n = sum(flagged, na.rm = TRUE),
      .by = c(condition, full_fit, scope, check, composition, role, statistic)) |>
    tidyr::complete(condition = conditions$condition, full_fit = c("all", "eligible", "ineligible"),
      tidyr::nesting(scope, check, composition, role, statistic),
      fill = list(checked = 0L, flagged_n = 0L)) |>
    dplyr::left_join(denominators, by = c("condition", "full_fit")) |>
    tidyr::replace_na(list(attempted = 0L, pooled_usable = 0L)) |>
    dplyr::mutate(
      rate = flagged_n / checked, mcse = sqrt(rate * (1 - rate) / checked))
  interval <- add_rate_intervals(data.frame(checked = flags$checked, flagged = flags$flagged_n))
  flags$lower <- interval$lower
  flags$upper <- interval$upper
  selection <- tables$policies |>
    dplyr::filter(parameter == "female_actor_null") |>
    dplyr::count(condition, policy, selected_model, available, name = "datasets")
  list(tables = tables, exports = list(conditions = conditions, fits = fit_summary,
    inference = inference_summary, selection = selection, flags = flags))
}

run_nb2_fallback <- function(repetitions = 500L, reference_draws = 1000L, workers = 5L, mode = "run") {
  stopifnot(repetitions > 0L, reference_draws >= 200L, workers > 0L, workers <= 10L,
    mode %in% c("run", "summarise"))
  specification <- nb2_fallback_specification(repetitions, reference_draws)
  directory <- file.path(study_directory, "results/model-simplification/nb2-fallback",
    paste0(repetitions, "-datasets-", reference_draws, "-draws"))
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  specification_file <- file.path(directory, "run-specification.rds")
  if (file.exists(specification_file)) {
    if (!identical(specification, readRDS(specification_file)))
      stop("Source, software or design changed. Use a fresh run; do not mix checkpoints.")
  } else {
    if (length(list.files(directory, "^condition-.*[.]rds$")))
      stop("Checkpoints exist without a run specification. Preserve them and use a fresh directory.")
    saveRDS(specification, specification_file)
    saveRDS(stats::setNames(lapply(names(specification$sources), readLines, warn = FALSE),
      names(specification$sources)), file.path(directory, "source-snapshot.rds"))
    writeLines(capture.output(sessionInfo()), file.path(directory, "session-info.txt"))
  }
  conditions <- specification$conditions |> dplyr::mutate(repetitions, reference_draws)
  tasks <- tidyr::crossing(condition = conditions$condition,
    first = seq.int(1L, repetitions, by = 10L)) |>
    dplyr::left_join(dplyr::select(conditions, condition, n_dyads), by = "condition") |>
    dplyr::arrange(dplyr::desc(n_dyads), condition, first) |>
    dplyr::mutate(last = pmin(first + 9L, repetitions),
      path = file.path(directory, sprintf("condition-%02d-reps-%03d-%03d.rds", condition, first, last)))
  if (mode == "run") {
    pending <- tasks[!file.exists(tasks$path), ]
    results <- parallel::mclapply(seq_len(nrow(pending)), function(index) {
      task <- pending[index, ]
      condition <- conditions[conditions$condition == task$condition, ]
      completed <- lapply(seq.int(task$first, task$last), function(repetition) {
        tryCatch(run_nb2_fallback_dataset(condition, repetition, reference_draws),
          error = function(error) stop("Condition ", task$condition, ", repetition ", repetition,
            ": ", conditionMessage(error), call. = FALSE))
      })
      saveRDS(completed, paste0(task$path, ".tmp"))
      stopifnot(file.rename(paste0(task$path, ".tmp"), task$path))
      message(format(Sys.time()), " completed condition ", task$condition,
        " repetitions ", task$first, "-", task$last)
      TRUE
    }, mc.cores = workers, mc.preschedule = FALSE, mc.set.seed = FALSE)
    failed <- which(!vapply(results, isTRUE, logical(1)))
    if (length(failed)) {
      for (index in failed) message("Block ", basename(pending$path[index]), ": ", results[[index]])
      stop("A block failed; complete checkpoints were preserved.")
    }
  }
  if (!all(file.exists(tasks$path))) stop("The run is incomplete; no complete-study exports were written.")
  stopifnot(identical(specification, nb2_fallback_specification(repetitions, reference_draws)))
  completed <- unlist(lapply(tasks$path, readRDS), recursive = FALSE)
  result <- summarise_nb2_fallback(completed, conditions)
  for (name in names(result$exports)) write.csv(result$exports[[name]],
    file.path(directory, paste0(name, ".csv")), row.names = FALSE)
  saveRDS(result$tables, file.path(directory, "dataset-tables.rds"))
  writeLines(sprintf("Complete: %d datasets, %d fits, %d checkpoints.",
    nrow(result$tables$status), nrow(result$tables$fits), nrow(tasks)), file.path(directory, "complete.txt"))
  message("Saved NB2 fallback study: ", directory)
  invisible(directory)
}

if (sys.nframe() == 0L) {
  arguments <- commandArgs(trailingOnly = TRUE)
  run_nb2_fallback(if (length(arguments)) as.integer(arguments[1]) else 500L,
    if (length(arguments) >= 2L) as.integer(arguments[2]) else 1000L,
    if (length(arguments) >= 3L) as.integer(arguments[3]) else 5L,
    if (length(arguments) >= 4L) arguments[4] else "run")
}
