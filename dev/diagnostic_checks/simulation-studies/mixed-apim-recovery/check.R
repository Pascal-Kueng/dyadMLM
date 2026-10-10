# Run from the repository root. Checks the generator, extraction and model equivalence.
source("dev/diagnostic_checks/simulation-studies/mixed-apim-recovery/helpers.R")

assert_close <- function(actual, expected, tolerance = 1e-10) {
  stopifnot(length(actual) == length(expected), all(is.finite(actual)),
    all(is.finite(expected)), max(abs(actual - expected)) < tolerance)
}

# Check every specification before fitting, using independently constructed predictors.
for (index in seq_len(nrow(study_conditions))) {
  condition <- study_conditions[index, ]
  data <- generate_recovery_data(condition, 820000000L + index)
  stopifnot(identical(gsub("-", "_", as.character(data$.composition), fixed = TRUE),
    data$sim_composition))
  targets <- fixed_targets(condition)
  for (parameter in unique(targets$parameter)) {
    target <- targets[match(parameter, targets$parameter), ]
    if (parameter %in% c("intercept", "time")) next
    assert_close(data[[target$predictor]], data[[parameter]])
  }
  fixed_formula <- as.formula(paste("~ 0 +", paste(targets$term, collapse = " + ")))
  design <- model.matrix(fixed_formula, data)
  positions <- match(term_key(targets$term), term_key(colnames(design)))
  stopifnot(!anyNA(positions))
  assert_close(as.numeric(design[, positions, drop = FALSE] %*% targets$true_value),
    data$true_fixed_mean)
  stopifnot(qr(design)$rank == ncol(design))
  for (composition in covariance_targets(condition)) {
    for (covariance in composition) {
      assert_close(covariance, t(covariance))
      stopifnot(min(eigen(covariance, symmetric = TRUE, only.values = TRUE)$values) > 0)
    }
  }
  stopifnot(any(vapply(covariance_targets(condition), function(components)
    any(vapply(components, function(covariance) any(covariance < 0), logical(1))), logical(1))))
}
message("Predictor, fixed-mean, rank and covariance checks passed for all 12 conditions.")

check_fit <- function(model) {
  if (model$fit$convergence != 0L || !isTRUE(model$sdr$pdHess) || !is.finite(logLik(model)))
    stop("Unusable equivalence-check fit: convergence=", model$fit$convergence,
      ", positive Hessian=", model$sdr$pdHess, ", logLik=", as.numeric(logLik(model)))
}

# Match by coefficient names and grouping level, independent of block position.
model_blocks <- function(model) {
  blocks <- glmmTMB::VarCorr(model)$cond
  blocks <- lapply(blocks, function(block) {
    dimnames(block) <- lapply(dimnames(block), term_key)
    block
  })
  names(blocks) <- paste(make.names(sub("[.][0-9]+$", "", names(blocks))),
    vapply(blocks, function(block) paste(sort(colnames(block)), collapse = "+"), ""), sep = ": ")
  blocks
}

compare_models <- function(joint, separate) {
  joint_fixed <- glmmTMB::fixef(joint)$cond
  separate_fixed <- unlist(lapply(separate, function(model) glmmTMB::fixef(model)$cond))
  names(joint_fixed) <- term_key(names(joint_fixed))
  names(separate_fixed) <- term_key(names(separate_fixed))
  joint_blocks <- model_blocks(joint)
  separate_blocks <- unlist(lapply(separate, model_blocks), recursive = FALSE)
  fixed_error <- max(abs(joint_fixed[names(separate_fixed)] - separate_fixed))
  covariance_error <- max(vapply(names(separate_blocks), function(name) {
    block <- separate_blocks[[name]]
    max(abs(joint_blocks[[name]][rownames(block), colnames(block)] - block))
  }, numeric(1)))
  likelihood_error <- abs(as.numeric(logLik(joint)) - sum(vapply(separate,
    function(model) as.numeric(logLik(model)), numeric(1))))
  # Independent optimizations can stop at slightly different numerical solutions.
  stopifnot(fixed_error < 1e-4, covariance_error < 1e-3, likelihood_error < 1e-4)
  c(fixed_error = fixed_error, covariance_error = covariance_error, likelihood_error = likelihood_error)
}

check_extraction <- function(model, condition) {
  recovered <- fitted_covariances(model, condition)
  extracted <- extract_recovery(model, condition)
  stopifnot(all(is.finite(extracted$estimate)), all(extracted$se[extracted$kind == "fixed"] > 0))
  blocks <- model_blocks(model)
  specifications <- random_blocks(condition)
  for (composition in names(recovered)) {
    for (component in names(recovered[[composition]])) {
      selected <- Filter(function(block) block$composition == composition &&
        block$component == component, specifications)
      fitted <- lapply(selected, function(block) {
        coefficients <- term_key(block$coefficients)
        key <- paste(make.names(block$grouping), paste(sort(coefficients), collapse = "+"), sep = ": ")
        blocks[[key]][coefficients, coefficients, drop = FALSE]
      })
      expected <- fitted[[1]]
      if (length(fitted) == 2L) {
        k <- nrow(fitted[[1]])
        transformation <- rbind(cbind(diag(k), diag(k)), cbind(diag(k), -diag(k)))
        expected <- transformation %*% as.matrix(Matrix::bdiag(fitted)) %*% t(transformation)
      }
      assert_close(recovered[[composition]][[component]], expected)
    }
  }
}

# Independently integrate the slope model using member-level Gaussian covariance.
check_marginal_likelihood <- function(model, data, condition) {
  stopifnot(identical(data$outcome, model$frame$outcome))
  residual <- data$outcome - as.numeric(model.matrix(model) %*% glmmTMB::fixef(model)$cond)
  covariances <- fitted_covariances(model, condition)
  contributions <- vapply(split(seq_len(nrow(data)), data$coupleID), function(rows) {
    member <- data$sim_member[rows]
    blocks <- covariances[[data$sim_composition[rows[1]]]]
    design <- matrix(0, length(rows), 6L)
    columns <- 3L * (member - 1L)
    design[cbind(seq_along(rows), columns + 1L)] <- 1
    design[cbind(seq_along(rows), columns + 2L)] <- data$.support_cwp_actor[rows]
    design[cbind(seq_along(rows), columns + 3L)] <- data$.support_cwp_partner[rows]
    covariance <- design %*% blocks$stable %*% t(design) +
      blocks$occasion[member, member] * outer(data$day[rows], data$day[rows], "==") +
      diag(sigma(model)^2, length(rows))
    factor <- chol(covariance)
    standardized <- backsolve(factor, residual[rows], transpose = TRUE)
    -.5 * (length(rows) * log(2 * pi) + 2 * sum(log(diag(factor))) + sum(standardized^2))
  }, numeric(1))
  error <- abs(sum(contributions) - as.numeric(logLik(model)))
  stopifnot(is.finite(error), error < 1e-4)
  message("Direct member-scale marginal log-likelihood difference: ", signif(error, 3))
  invisible(error)
}

check_equivalence <- function(design, pooling, swap_members = FALSE) {
  condition <- study_conditions[study_conditions$design == design &
    study_conditions$pooling == pooling & study_conditions$dyads_per_composition == 120L, ]
  # Reuse the first prespecified pilot dataset; this checks numerical equivalence.
  seed <- 720000000L + 100000L * condition$condition + 1L
  data <- generate_recovery_data(condition, seed)
  message(format(Sys.time()), ": fitting ", design, " joint model")
  joint <- fit_recovery_model(data, condition)
  check_fit(joint)
  check_extraction(joint, condition)
  if (design == "ild_slopes") check_marginal_likelihood(joint, data, condition)
  # Keep the joint sample's CBP centering in every separate fit.
  separate <- lapply(composition_names(condition), function(composition) {
    message(format(Sys.time()), ": fitting ", design, " ", composition)
    model <- fit_recovery_model(data[data$sim_composition == composition, ], condition, composition)
    check_fit(model)
    model
  })
  results <- rbind(data.frame(design, comparison = "joint versus separate",
    as.list(compare_models(joint, separate))))
  if (swap_members) {
    raw <- as.data.frame(data)[c("coupleID", "personID", "gender", "day", "support", "outcome")]
    raw$original_row <- seq_len(nrow(raw))
    same_sex <- data$sim_composition != "female_x_male"
    raw$personID[same_sex] <- 4L * raw$coupleID[same_sex] - 1L - raw$personID[same_sex]
    swapped <- prepare_dyad_data(raw, dyad = coupleID, member = personID, role = gender,
      time = day, predictors = support, model_types = "apim", short_colnames = FALSE, seed = seed,
      pool_compositions = list("same-sex" = c("female-female", "male-male")))
    swapped <- swapped[match(seq_len(nrow(raw)), swapped$original_row), ]
    assert_close(swapped$.member_contrast_same_sex_arbitrary,
      -data$.member_contrast_same_sex_arbitrary)
    targets <- fixed_targets(condition)
    for (predictor in unique(targets$predictor[targets$predictor != ""]))
      assert_close(swapped[[predictor]], data[[predictor]])
    message(format(Sys.time()), ": fitting swapped ", design, " model")
    refit <- fit_recovery_model(swapped, condition)
    check_fit(refit)
    check_extraction(refit, condition)
    results <- rbind(results, data.frame(design, comparison = "swapped same-sex labels",
      as.list(compare_models(joint, list(refit)))))
  }
  results
}

# Eight requested fits, plus the slope initializer fits; at most two run together.
settings <- list(list(design = "cross_apim", pooling = "separate", swap_members = FALSE),
  list(design = "ild_slopes", pooling = "pooled", swap_members = TRUE))
results <- parallel::mclapply(settings, function(setting) {
  do.call(check_equivalence, setting)
}, mc.cores = if (.Platform$OS.type == "windows") 1L else 2L, mc.set.seed = FALSE)
failed <- vapply(results, inherits, logical(1), "try-error")
if (any(failed)) stop(paste(unlist(results[failed]), collapse = "\n"))
results <- dplyr::bind_rows(results)
output_directory <- file.path(study_directory, "results/mixed-apim-recovery/check")
dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)
write.csv(results, file.path(output_directory, "equivalence.csv"), row.names = FALSE)
print(results)
message("All mixed-APIM recovery checks passed.")
