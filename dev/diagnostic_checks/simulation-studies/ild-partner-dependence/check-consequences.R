# Structural checks only; these do not fit models or estimate detection rates.
# Run from the repository root with numerical libraries limited to one thread.
source("dev/diagnostic_checks/simulation-studies/ild-partner-dependence/consequences.R")

conditions <- consequence_conditions()
stopifnot(nrow(conditions) == 24L, !anyDuplicated(conditions$condition),
  identical(sort(unique(conditions$n_dyads)), c(50L, 200L)),
  all(conditions$n_occasions == 14L))
baseline <- true_parameters$gaussian
for (index in seq_len(nrow(conditions))) {
  condition <- conditions[index, ]
  truth <- consequence_truth(condition)
  expected <- baseline
  if (condition$axis == "stable_cor") expected$stable_cor <- condition$strength
  if (condition$axis == "occasion_cor") expected$occasion_cor <- condition$strength
  if (condition$axis == "occasion_sd_ratio") {
    expected$occasion_sds <- sqrt(2 * 1.04 / (1 + condition$strength^2)) *
      c(condition$strength, 1)
  }
  stopifnot(isTRUE(all.equal(truth, expected)),
    abs(mean(truth$occasion_sds^2) - 1.04) < 1e-12)
}

# Independent Gaussian moment checks. Member means have stable variance plus
# occasion variance / T. The difference of two occasions / sqrt(2) removes the
# stable effect and has exactly the occasion covariance matrix.
moment_results <- lapply(which(conditions$n_dyads == 50L), function(index) {
  condition <- conditions[index, ]
  condition$n_dyads <- 8000L
  truth <- consequence_truth(condition)
  data <- generate_consequence_data(condition, 1950000000L + index) |>
    dplyr::mutate(residual = outcome - true_fixed_mean)
  means <- data |>
    dplyr::summarise(value = mean(residual), .by = c(dyad, gender)) |>
    tidyr::pivot_wider(names_from = gender, values_from = value)
  differences <- data |>
    dplyr::filter(occasion %in% c("1", "2")) |>
    dplyr::summarise(value = (residual[occasion == "1"] -
      residual[occasion == "2"]) / sqrt(2), .by = c(dyad, gender)) |>
    tidyr::pivot_wider(names_from = gender, values_from = value)
  moments <- function(values) c(var(values$female), var(values$male),
    cov(values$female, values$male))
  occasion <- c(truth$occasion_sds^2, prod(truth$occasion_sds) * truth$occasion_cor)
  between <- c(truth$stable_sds^2, prod(truth$stable_sds) * truth$stable_cor) +
    occasion / condition$n_occasions
  # Sampling SDs for Gaussian variances and covariances across independent dyads.
  sampling_sd <- function(values) sqrt(c(2 * values[1:2]^2,
    values[1] * values[2] + values[3]^2) / (condition$n_dyads - 1))
  observed <- c(moments(means), moments(differences))
  expected <- c(between, occasion)
  standard_error <- c(sampling_sd(between), sampling_sd(occasion))
  stopifnot(all(abs(observed - expected) < 6 * standard_error))
  data.frame(condition = condition$condition,
    moment = c("between_var_female", "between_var_male", "between_covariance",
      "occasion_var_female", "occasion_var_male", "occasion_covariance"),
    observed, expected, standard_error)
})

first <- generate_consequence_data(conditions[1, ], 1960000001L)
second <- generate_consequence_data(conditions[1, ], 1960000001L)
stopifnot(identical(first, second), nrow(first) == 2L * 50L * 14L,
  identical(true_parameters$gaussian, baseline))

# Off-diagonal covariance matters: ignoring it gives the wrong SE for both
# intercept contrasts. Reordering the covariance matrix must leave results intact.
coefficients <- c(genderfemale = 0.2, gendermale = -0.1, x_actor = 0.7, x_partner = 0.2)
covariance <- diag(c(0.09, 0.16, 0.01, 0.04))
dimnames(covariance) <- list(names(coefficients), names(coefficients))
covariance[1, 2] <- covariance[2, 1] <- 0.03
inference <- consequence_inference(coefficients, covariance[4:1, 4:1], baseline)
stopifnot(isTRUE(all.equal(inference$estimate, c(0.7, 0.2, 0.05, 0.3))),
  isTRUE(all.equal(inference$se, sqrt(c(0.01, 0.04, (0.09 + 0.16 + 0.06) / 4,
    0.09 + 0.16 - 0.06)))),
  identical(unname(inference$covered), c(FALSE, TRUE, TRUE, TRUE)))
covariance[3, 3] <- NA_real_
undefined <- consequence_inference(coefficients, covariance, baseline)
stopifnot(!undefined$defined[1], is.na(undefined$covered[1]))

output_directory <- file.path(study_directory,
  "results/ild-partner-dependence-consequences/implementation-checks")
dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)
write.csv(dplyr::bind_rows(moment_results), file.path(output_directory, "moments.csv"),
  row.names = FALSE)
message("Consequence study structural checks passed (no model fits run).")
