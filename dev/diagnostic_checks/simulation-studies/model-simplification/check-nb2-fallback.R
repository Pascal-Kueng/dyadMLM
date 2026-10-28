# Structural and failure-handling checks. No models are fitted.
source("dev/diagnostic_checks/simulation-studies/model-simplification/nb2-fallback.R")

conditions <- nb2_fallback_conditions() |> dplyr::mutate(repetitions = 1L, reference_draws = 1000L)
stopifnot(nrow(conditions) == 6L, identical(sort(unique(conditions$n_dyads)), c(100L, 400L)),
  isTRUE(all.equal(as.vector(nb2_fallback_contrasts() %*% nb2_fallback_truth()), c(0, .2, .4, .6))))
data <- generate_nb2_fallback_data(conditions[1, ], 1400010001L)
stopifnot(identical(data, generate_nb2_fallback_data(conditions[1, ], 1400010001L)),
  all(data$outcome >= 0 & data$outcome == floor(data$outcome)),
  identical(colnames(model.matrix(generalized_fixed_formula, data)), names(nb2_fallback_truth())))
old_predictor <- true_fixed_predictor(data) + log(3)
new_predictor <- as.vector(model.matrix(generalized_fixed_formula, data) %*% nb2_fallback_truth())
stopifnot(isTRUE(all.equal(new_predictor,
  old_predictor - .6 * data$.is_female_x_male_female * data$.support_actor)))

# The native functions must produce all expected panels with finite references.
set.seed(17)
simulations <- structure(list(observed_response = data$outcome,
  predicted_response = exp(new_predictor),
  simulated_responses = matrix(rnbinom(1000L * nrow(data), mu = 5, size = 3), nrow = 1000L),
  model_frame = data), class = c("dyadMLM_response_simulations", "list"),
  dyadMLM = list(family = "nbinom2", free_conditional_intercept = FALSE))
checks <- record_nb2_fallback_checks(simulations, data, 31L)
stopifnot(nrow(checks) == 42L, all(!is.na(checks$flagged)),
  identical(as.integer(table(checks$check)), c(14L, 12L, 16L)),
  all(checks$reference_defined[!is.na(checks$reference_defined)] == 1000L),
  all(checks$finite_curve[!is.na(checks$finite_curve)]))

# Exercise the actual dataset path when both fits fail; do not call an optimizer.
failure_runner <- run_nb2_fallback_dataset
environment(failure_runner) <- list2env(list(fit_generalized_covariance_model = function(...) {
  list(model = NULL, status = tibble::tibble(model = "failed", usable = FALSE,
    convergence = 1L, positive_hessian = FALSE, warnings = "", error = "synthetic failure",
    elapsed_seconds = 0))
}), parent = environment(run_nb2_fallback_dataset))
failed_dataset <- failure_runner(conditions[1, ], 1L, 1000L)
stopifnot(nrow(failed_dataset$checks) == 0L, nrow(failed_dataset$fits) == 2L,
  nrow(failed_dataset$inference) == 32L, nrow(failed_dataset$policies) == 16L,
  all(!failed_dataset$policies$available), all(is.na(failed_dataset$policies$selected_model)),
  identical(failed_dataset$status$condition, conditions$condition[1]))

# Also exercise the actual success, fallback and undefined-comparison paths.
logLik.nb2_fallback_mock <- function(object, ...) {
  structure(object$value, df = object$df, class = "logLik")
}
mock_dataset <- function(pooled_usable = TRUE, full_usable = TRUE, p = .01, delta = 2) {
  runner <- run_nb2_fallback_dataset
  environment(runner) <- list2env(list(
    fit_generalized_covariance_model = function(data, family, model) {
      usable <- if (model == "pooled") pooled_usable else full_usable
      mock <- structure(list(value = if (model == "pooled") -100 else -100 + delta,
        df = if (model == "pooled") 15L else 20L), class = "nb2_fallback_mock")
      list(model = if (usable) mock else NULL,
        status = tibble::tibble(model, usable, convergence = if (usable) 0L else 1L,
          positive_hessian = usable, warnings = "", error = "", elapsed_seconds = 0))
    },
    nb2_fallback_inference = function(model) {
      rows <- nb2_fallback_inference(NULL)
      if (!is.null(model)) rows <- dplyr::mutate(rows, estimate = true_value,
        se = .1, defined = TRUE, covered = TRUE, significant = abs(true_value) > qnorm(.975) * .1)
      rows
    },
    compare_nested_models = function(...) {
      if (is.na(p)) stop("synthetic comparison failure")
      stats::setNames(data.frame(c(NA, p), c(NA, qchisq(1 - p, 5)), c(NA, 5)),
        c("Pr(>Chisq)", "Chisq", "Chi Df"))
    },
    simulate_dyad_responses = function(...) simulations,
    record_nb2_fallback_checks = function(...) checks
  ), parent = environment(run_nb2_fallback_dataset))
  runner(conditions[1, ], 1L, 1000L)
}
success <- mock_dataset()
stopifnot(nrow(success$checks) == 42L, all(success$policies$available),
  all(success$policies$selected_model[success$policies$policy == "lrt_05"] == "full"),
  success$status$lrt_p == .01, success$status$lrt_df == 5)
pooled_choice <- mock_dataset(p = .5)
stopifnot(all(pooled_choice$policies$selected_model[pooled_choice$policies$policy == "lrt_05"] == "pooled"))
fallback <- mock_dataset(full_usable = FALSE)
stopifnot(all(fallback$policies$selected_model[fallback$policies$policy == "full_then_pooled"] == "pooled"))
full_only <- mock_dataset(pooled_usable = FALSE)
stopifnot(nrow(full_only$checks) == 0L,
  all(full_only$policies$selected_model[full_only$policies$policy == "lrt_05"] == "full"))
undefined <- mock_dataset(p = NA_real_)
stopifnot(all(!undefined$policies$available[undefined$policies$policy == "lrt_05"]),
  undefined$status$comparison_error == "synthetic comparison failure")
reversal <- mock_dataset(delta = -.1)
stopifnot(all(reversal$fits$usable), identical(reversal$fits$eligible, c(TRUE, FALSE)),
  reversal$status$likelihood_reversal,
  isTRUE(all.equal(reversal$status$likelihood_delta, -.1)),
  all(reversal$policies$selected_model[reversal$policies$policy == "full_then_pooled"] == "pooled"),
  all(reversal$policies$selected_model[reversal$policies$policy == "lrt_05"] == "pooled"),
  all(!reversal$policies$available[reversal$policies$policy == "full"]),
  is.na(reversal$status$lrt_p))

# A run with no usable fits still has all attempted inference and policy rows.
failed_record <- function(condition) {
  identify <- function(table) dplyr::mutate(table, condition, repetition = 1L, dataset_seed = condition)
  fits <- tibble::tibble(model = c("pooled", "full"), usable = FALSE, eligible = FALSE,
    eligibility_reason = "optimizer_or_hessian_failure",
    warnings = "", error = "synthetic failure", inference_error = "", elapsed_seconds = 0)
  inference <- dplyr::bind_rows(lapply(fits$model, function(model)
    dplyr::mutate(nb2_fallback_inference(NULL), model, usable = FALSE, eligible = FALSE)))
  policies <- dplyr::bind_rows(lapply(c("pooled", "full", "full_then_pooled", "lrt_05"), function(policy)
    dplyr::mutate(dplyr::filter(nb2_fallback_inference(NULL), primary),
      policy, selected_model = NA_character_, available = FALSE)))
  list(fits = identify(fits), inference = identify(inference), policies = identify(policies),
    checks = empty_nb2_fallback_checks(), covariance = list(pooled = NULL, full = NULL),
    status = identify(tibble::tibble(lrt_p = NA_real_, comparison_error = "", check_error = "",
      check_warnings = "", simulation_finite = NA, check_seconds = NA_real_)))
}
failed <- lapply(conditions$condition, failed_record)
summary <- summarise_nb2_fallback(failed, conditions)$exports
stopifnot(all(summary$fits$attempted == 1L & summary$fits$usable == 0L),
  all(summary$inference$attempted == 1L & summary$inference$available_n == 0L),
  all(summary$selection$datasets == 1L & !summary$selection$available),
  nrow(summary$flags) == 54L, all(summary$flags$checked == 0L),
  all(is.na(summary$flags$rate)))
failed[[1]]$checks <- dplyr::mutate(checks, condition = 1L, repetition = 1L, dataset_seed = 1L)
partial <- summarise_nb2_fallback(failed, conditions)$exports$flags
stopifnot(nrow(partial) == 810L, all(partial$checked[partial$condition > 1L] == 0L))

# Missing provenance and incomplete checkpoint sets cannot become completed runs.
temporary <- tempfile("nb2-fallback-structural-")
dir.create(temporary)
runner <- run_nb2_fallback
environment(runner) <- list2env(list(study_directory = temporary), parent = environment(run_nb2_fallback))
directory <- file.path(temporary, "results/model-simplification/nb2-fallback/1-datasets-1000-draws")
dir.create(directory, recursive = TRUE)
saveRDS(list(), file.path(directory, "condition-01-reps-001-001.rds"))
error <- tryCatch(runner(1L, 1000L, 1L, "summarise"), error = conditionMessage)
stopifnot(grepl("without a run specification", error, fixed = TRUE))
unlink(file.path(directory, "condition-01-reps-001-001.rds"))
error <- tryCatch(runner(1L, 1000L, 1L, "summarise"), error = conditionMessage)
stopifnot(grepl("run is incomplete", error, fixed = TRUE),
  !file.exists(file.path(directory, "complete.txt")),
  !file.exists(file.path(directory, "inference.csv")))
specification <- readRDS(file.path(directory, "run-specification.rds"))
specification$reference_draws <- 999L
saveRDS(specification, file.path(directory, "run-specification.rds"))
error <- tryCatch(runner(1L, 1000L, 1L, "summarise"), error = conditionMessage)
stopifnot(grepl("Source, software or design changed", error, fixed = TRUE))
unlink(temporary, recursive = TRUE)
cat("NB2 fallback structural checks passed; no fits were run.\n")
