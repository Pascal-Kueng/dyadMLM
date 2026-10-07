# Structural checks do not fit models. Pilot validation below is called only
# after run_gaussian_selection(2L, 1000L, 10L) and requires fitting capacity.
source("dev/diagnostic_checks/simulation-studies/model-simplification/gaussian.R")

conditions <- gaussian_selection_conditions()
stopifnot(nrow(conditions) == 30L, !anyDuplicated(conditions$condition),
  sum(conditions$scenario == "covariance") == 24L,
  sum(conditions$scenario == "random_slope") == 6L,
  all(conditions$n_occasions == 14L))
invisible(selection_reference_provenance())

# A random slope adds an independent member effect times the within predictor.
# Member centring ensures this addition has exactly zero mean within member.
condition <- conditions[conditions$condition == 27L, ]
condition$n_dyads <- 2000L
with_slopes <- generate_selection_data(condition, 1410000001L)
condition$strength <- 0
without_slopes <- generate_selection_data(condition, 1410000001L)
addition <- with_slopes$outcome - without_slopes$outcome
slopes <- addition / with_slopes$x_actor_within
stopifnot(max(abs(tapply(with_slopes$x_actor_within, with_slopes$person, mean))) < 1e-12,
  max(abs(tapply(addition, with_slopes$person, mean))) < 1e-12,
  max(tapply(slopes, with_slopes$person, sd)) < 1e-9,
  abs(sd(tapply(slopes, with_slopes$person, mean)) - 0.5) < 0.04,
  identical(with_slopes$true_fixed_mean, without_slopes$true_fixed_mean))

mock_fits <- tibble::tibble(fit = c("full", "restricted"), usable = TRUE,
  inference_defined = TRUE, log_likelihood = c(-10, -12), likelihood_df = c(11L, 10L))
stopifnot(isTRUE(all.equal(selection_lrt(mock_fits)$lrt_p, pchisq(4, 1, lower.tail = FALSE))),
  isTRUE(all.equal(selection_lrt(mock_fits, TRUE)$lrt_p, 0.5 * pchisq(4, 1, lower.tail = FALSE))))
mock_fits$log_likelihood[1] <- -12
stopifnot(selection_lrt(mock_fits, TRUE)$lrt_p == 1)
mock_fits$log_likelihood[1] <- -13
stopifnot(!selection_lrt(mock_fits)$lrt_defined, selection_lrt(mock_fits)$reversed_likelihood)
mock_fits$log_likelihood[1] <- -10
checks <- tidyr::crossing(level = c("between", "within"), statistic = statistic_keys) |>
  dplyr::mutate(observed = 0, lower = -1, upper = 1,
    n_defined = 1000L, n_below = 500L, n_above = 500L)
mock_fits$log_likelihood[1] <- -13
quality <- selection_fit_eligibility(mock_fits)
decisions <- selection_decisions(mock_fits, checks, conditions[1, ], 1000L)
stopifnot(all(quality$usable), identical(quality$eligible, c(FALSE, TRUE)),
  is.na(decisions$selected[decisions$method == "always_full"]),
  all(decisions$selected[!startsWith(decisions$method, "always_")] == "restricted"),
  all(decisions$fallback[!startsWith(decisions$method, "always_")]),
  all(decisions$reversed_likelihood), !any(decisions$lrt_defined), !any(decisions$paired))
mock_fits$log_likelihood[1] <- -10
decisions <- selection_decisions(mock_fits, checks, conditions[1, ], 1000L)
stopifnot(all(decisions$selected[startsWith(decisions$method, "check_")] == "restricted"))
checks$n_below[checks$level == "within" & checks$statistic == "partner_cor"] <- 999L
checks$n_above[checks$level == "within" & checks$statistic == "partner_cor"] <- 1L
decisions <- selection_decisions(mock_fits, checks, conditions[1, ], 1000L)
stopifnot(decisions$selected[decisions$method == "check_rank_target"] == "full")
mock_fits$usable[1] <- FALSE
decisions <- selection_decisions(mock_fits, checks, conditions[1, ], 1000L)
stopifnot(is.na(decisions$selected[decisions$method == "always_full"]),
  all(decisions$selected[!startsWith(decisions$method, "always_")] == "restricted"),
  all(decisions$fallback[!startsWith(decisions$method, "always_")]))
mock_fits$usable[2] <- FALSE
stopifnot(all(is.na(selection_decisions(mock_fits, checks, conditions[1, ], 1000L)$selected)))
mock_fits$usable[] <- TRUE
checks$n_defined[1] <- 999L
decisions <- selection_decisions(mock_fits, checks, conditions[1, ], 1000L)
stopifnot(all(is.na(decisions$selected[startsWith(decisions$method, "check_")])))

validate_gaussian_selection_pilot <- function(directory) {
  files <- list.files(directory, "^condition-.*[.]rds$", full.names = TRUE)
  completed <- unlist(lapply(files, readRDS), recursive = FALSE)
  fits <- dplyr::bind_rows(lapply(completed, `[[`, "fits"))
  inference <- dplyr::bind_rows(lapply(completed, `[[`, "inference"))
  checks <- dplyr::bind_rows(lapply(completed, `[[`, "checks"))
  decisions <- dplyr::bind_rows(lapply(completed, `[[`, "decisions"))
  stopifnot(length(files) == 30L, length(completed) == 60L, nrow(fits) == 120L,
    !anyDuplicated(fits[c("condition", "repetition", "fit")]),
    all(table(fits$condition, fits$fit) == 2L),
    all(inference$defined), all(is.finite(inference$estimate)), all(inference$se > 0),
    all(checks$n_defined == 1000L), all(is.finite(checks$observed)),
    all(fits$replay_max_difference[fits$condition <= 24L] < 1e-7))
  # Convergence failures are retained and reported; complete records, not an
  # all-usable requirement, establish whether the workflow itself completed.
  stopifnot(nrow(decisions) == 24L * 2L * 8L + 6L * 2L * 6L,
    all(fits$error == ""), all(fits$inference_error == ""), all(fits$check_error == ""))
  actual_null_checks <- lapply(c(1L, 13L, 27L, 30L), function(index) {
    condition <- gaussian_selection_conditions()[index, ]
    saved <- completed[[which(vapply(completed, function(item) {
      item$fits$condition[1] == index && item$fits$repetition[1] == 1L
    }, logical(1)))]]
    data <- generate_selection_data(condition, saved$fits$dataset_seed[1])
    data$outcome <- data$outcome - data$true_fixed_mean
    null_fits <- list()
    null_check <- NULL
    results <- lapply(c("full", "restricted"), function(fit) {
      model <- fit_selection_model(data, condition, fit)
      stopifnot(model$status$usable)
      null <- selection_inference(model$model, condition)
      previous <- saved$inference[saved$inference$fit == fit, ]
      likelihood <- logLik(model$model)
      errors <- c(estimate = max(abs(null$estimate - (previous$estimate - previous$true_value))),
        estimate_se_units = max(abs(null$estimate - (previous$estimate - previous$true_value)) / previous$se),
        se = max(abs(null$se - previous$se)),
        se_relative = max(abs(null$se - previous$se) / previous$se),
        likelihood = abs(as.numeric(likelihood) - saved$fits$log_likelihood[saved$fits$fit == fit]))
      # Gaussian translation is exact mathematically. Separate optimizer runs
      # may stop at slightly different points; judge drift on the SE scale.
      stopifnot(errors["estimate_se_units"] < .01, errors["se_relative"] < .001,
        errors["likelihood"] < 1e-3,
        identical(abs(null$estimate) > qnorm(.975) * null$se,
          abs(previous$estimate - previous$true_value) > qnorm(.975) * previous$se))
      null_fits[[fit]] <<- dplyr::mutate(model$status, fit,
        log_likelihood = as.numeric(likelihood), likelihood_df = attr(likelihood, "df"),
        inference_defined = all(null$defined))
      if (fit == "restricted") {
        simulations <- simulate_dyad_responses(model$model, nsim = 1000L,
          seed = saved$fits$dataset_seed[1] + 100000000L)
        null_check <<- record_occasion_check(check_partner_dependence(simulations, dyad = dyad,
          role = gender, member = person, time = occasion, data = data, plot = FALSE))
        previous_check <- saved$checks
        key <- paste(null_check$level, null_check$statistic)
        previous_check <- previous_check[match(key, paste(previous_check$level, previous_check$statistic)), ]
        errors <- c(errors, reference = max(abs(as.matrix(null_check[c("observed", "lower", "upper")]) -
          as.matrix(previous_check[c("observed", "lower", "upper")]))))
        stopifnot(errors["reference"] < 5e-4)
        new_flags <- add_flags(null_check)
        previous_flags <- add_flags(previous_check)
        stopifnot(all(new_flags$below == previous_flags$below),
          all(new_flags$above == previous_flags$above))
      }
      tibble::tibble(condition = index, fit, quantity = names(errors), difference = unname(errors))
    })
    new_decisions <- selection_decisions(dplyr::bind_rows(null_fits), null_check, condition, 1000L)
    for (field in c("method", "selected", "fallback", "reason", "paired", "lrt_defined")) {
      stopifnot(identical(new_decisions[[field]], saved$decisions[[field]]))
    }
    stopifnot(identical(new_decisions$lrt_p < .05, saved$decisions$lrt_p < .05),
      identical(new_decisions$lrt_p < .20, saved$decisions$lrt_p < .20))
    dplyr::bind_rows(results)
  })
  before <- tools::md5sum(files)
  run_gaussian_selection(2L, 1000L, 1L, "run")
  stopifnot(identical(before, tools::md5sum(files)))
  result <- dplyr::bind_rows(actual_null_checks)
  write.csv(result, file.path(directory, "null-recentering-validation.csv"), row.names = FALSE)
  writeLines(c("Pilot complete: 30 conditions, 60 datasets, 120 fit attempts.",
    paste("Optimizer-usable fits:", sum(fits$usable)), paste("Eligible fits:", sum(fits$eligible)),
    paste("Likelihood reversals:", sum(fits$likelihood_reversal)), paste("Fit warnings:", sum(fits$warnings != "")),
    "Saved Gaussian estimates and SEs reproduced before reference reuse.",
    "Actual null-response refits and references agree within numerical tolerance: <0.01 SE coefficient drift, <0.1% relative SE drift, <0.001 logLik drift, <0.0005 reference drift.",
    "Null rejection, rank/quantile flags, LRT selection and fallback decisions agree exactly.",
    "Checkpoint resume leaves every completed checkpoint unchanged."), file.path(directory, "validation.txt"))
  invisible(result)
}

message("Gaussian selection structural checks passed (no model fits run).")
