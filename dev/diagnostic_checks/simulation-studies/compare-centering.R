# Run from the repository root. Arguments: datasets, reference draws, workers, run/plot, families.
# The last argument optionally selects comma-separated family names.
devtools::load_all(quiet = TRUE)
study_directory <- "dev/diagnostic_checks/simulation-studies"
script_file <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))
source(file.path(dirname(script_file), "family-margins.R"))
source(file.path(dirname(script_file), "plot-family-comparison.R"))
source(file.path(dirname(script_file), "summarise-family-comparison.R"))
arguments <- commandArgs(trailingOnly = TRUE)
repetitions <- if (length(arguments) >= 1L) as.integer(arguments[1]) else 500L
reference_draws <- if (length(arguments) >= 2L) as.integer(arguments[2]) else 1000L
workers <- if (length(arguments) >= 3L) as.integer(arguments[3]) else 8L
plot_only <- length(arguments) >= 4L && arguments[4] == "plot"
family_names <- c("gaussian", "poisson", "nbinom1", "nbinom2", "nbinom12", "compois", "genpois",
  "truncated_poisson", "truncated_nbinom1", "truncated_nbinom2", "truncated_compois",
  "truncated_genpois", "tweedie", "Gamma", "beta", "lognormal", "skewnormal", "bell", "t",
  "ordinal", "zi_poisson", "hurdle_nbinom2")
vignette_families <- c("gaussian", "nbinom2", "ordinal", "lognormal", "zi_poisson", "hurdle_nbinom2")
selected_families <- if (length(arguments) >= 5L) strsplit(arguments[5], ",", fixed = TRUE)[[1]] else
  c(vignette_families, setdiff(family_names, vignette_families))
stopifnot(all(selected_families %in% family_names), repetitions > 0L, reference_draws >= 20L, workers > 0L)
output_directory <- file.path(study_directory, "results/family-comparison",
  paste0(repetitions, "-datasets-", reference_draws, "-draws"))
dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)
conditions <- expand.grid(n_dyads = c(20L, 40L, 60L, 80L, 100L, 150L, 200L, 300L, 400L, 500L, 1000L),
  target_correlation = c(0, 0.1, 0.3, 0.5)) |>
  dplyr::mutate(condition = dplyr::row_number())
if (!plot_only) {
  calibration_file <- file.path(study_directory, "results/family-comparison/calibration.csv")
  calibration <- if (file.exists(calibration_file)) read.csv(calibration_file) else data.frame()
  missing_families <- setdiff(selected_families, calibration$family)
  for (family_name in missing_families) {
    family_calibration <- calibrate_family_correlations(family_name,
      seed = 32000000L + 100L * match(family_name, family_names))
    family_calibration$verified <- TRUE
    calibration <- dplyr::bind_rows(calibration, family_calibration)
    write.csv(calibration, calibration_file, row.names = FALSE)
  }
}

# The study always places partners in alternating columns. This is Pearson correlation,
# calculated for all datasets at once instead of also calculating the other five checks.
partner_correlations <- function(responses) {
  first_partner_responses <- responses[, seq.int(1L, ncol(responses), 2L), drop = FALSE]
  second_partner_responses <- responses[, seq.int(2L, ncol(responses), 2L), drop = FALSE]
  first_partner_responses <- first_partner_responses - rowMeans(first_partner_responses)
  second_partner_responses <- second_partner_responses - rowMeans(second_partner_responses)
  rowSums(first_partner_responses * second_partner_responses) /
    sqrt(rowSums(first_partner_responses^2) * rowSums(second_partner_responses^2))
}

run_condition <- function(condition_index) {
  condition <- conditions[condition_index, ]
  latent_correlation <- family_calibration$latent_correlation[
    family_calibration$target_correlation == condition$target_correlation]
  checkpoint_file <- file.path(family_directory, paste0("condition-", condition_index, ".rds"))
  completed <- if (file.exists(checkpoint_file)) readRDS(checkpoint_file) else list(fits = NULL, statistics = NULL)
  first_repetition <- nrow(as.data.frame(completed$fits)) + 1L
  if (first_repetition > repetitions) return(invisible(NULL))
  for (repetition in seq.int(first_repetition, repetitions)) {
    dataset_seed <- 110000000L + 20000000L * (match(family_name, family_names) - 1L) +
      100000L * condition_index + repetition
    set.seed(dataset_seed)
    first_predictor <- rnorm(condition$n_dyads)
    second_predictor <- 0.3 * first_predictor + sqrt(1 - 0.3^2) * rnorm(condition$n_dyads)
    first_error <- rnorm(condition$n_dyads)
    second_error <- latent_correlation * first_error +
      sqrt(1 - latent_correlation^2) * rnorm(condition$n_dyads)
    actor_predictor <- as.vector(rbind(first_predictor, second_predictor))
    partner_predictor <- as.vector(rbind(second_predictor, first_predictor))
    linear_predictor <- 0.5 * actor_predictor + 0.3 * partner_predictor
    latent_errors <- as.vector(rbind(first_error, second_error))
    # Keep the original Gaussian generator exactly; other families transform its errors.
    outcome <- if (family_name == "gaussian") linear_predictor + latent_errors else
      margin$quantile(pnorm(latent_errors), linear_predictor)
    if (family_name == "ordinal") outcome <- ordered(outcome, levels = 1:4)
    fitting_data <- data.frame(dyad = factor(rep(seq_len(condition$n_dyads), each = 2)),
      role = factor(rep(c("first", "second"), condition$n_dyads)),
      actor_predictor, partner_predictor, outcome)
    fit_status <- data.frame(family = family_name, condition, repetition, dataset_seed,
      status = "fit_error", convergence = NA_integer_, positive_hessian = NA,
      warnings = "", error = "")
    warning_messages <- character()
    statistics <- tryCatch(withCallingHandlers({
      if (family_name == "ordinal" && any(table(fitting_data$outcome) == 0L)) {
        fit_status$status <- "study_exclusion"
        stop("A category is absent; retain the study's four-category scoring.")
      }
      model <- do.call(glmmTMB::glmmTMB, c(list(
        formula = outcome ~ actor_predictor + partner_predictor, data = fitting_data),
        margin$fit_arguments))
      fit_status$convergence <- model$fit$convergence
      fit_status$positive_hessian <- isTRUE(model$sdr$pdHess)
      if (fit_status$convergence != 0L || !fit_status$positive_hessian) {
        fit_status$status <- "fit_problem"
        NULL
      } else {
        fit_status$status <- "check_error"
        simulations <- suppressMessages(simulate_dyad_responses(
          model, nsim = reference_draws, seed = dataset_seed + 10000000L))
        # Use one simulation object for both methods, including the combined zeros in ZI/hurdle models.
        statistics <- lapply(c("model-centred", "raw"), function(response_mode) {
          responses <- rbind(simulations$observed_response, simulations$simulated_responses)
          if (response_mode == "model-centred") {
            responses <- sweep(responses, 2L, simulations$predicted_response, "-")
          }
          values <- partner_correlations(responses)
          reference_values <- values[-1L]
          defined_reference_values <- reference_values[is.finite(reference_values)]
          reference_limits <- if (length(defined_reference_values))
            quantile(defined_reference_values, c(0.025, 0.975)) else c(NA_real_, NA_real_)
          # Missing statistics remain missing, rather than counting as agreement.
          data.frame(response = response_mode, observed = values[1L],
            reference_lower = unname(reference_limits[1]), reference_upper = unname(reference_limits[2]),
            undefined_draws = sum(!is.finite(reference_values)),
            flagged = if (is.finite(values[1L]))
              values[1L] < reference_limits[1] | values[1L] > reference_limits[2] else NA)
        }) |> dplyr::bind_rows()
        fit_status$status <- "success"
        dplyr::bind_cols(fit_status[c("family", "condition", "n_dyads", "target_correlation", "repetition")], statistics)
      }
    }, warning = function(warning) {
      warning_messages <<- c(warning_messages, conditionMessage(warning))
      invokeRestart("muffleWarning")
    }), error = function(error) {
      fit_status$error <<- conditionMessage(error)
      NULL
    })
    fit_status$warnings <- paste(unique(warning_messages), collapse = " | ")
    completed$fits <- dplyr::bind_rows(completed$fits, fit_status)
    completed$statistics <- dplyr::bind_rows(completed$statistics, statistics)
    # A stopped run resumes after the last saved dataset; seeds do not depend on worker count.
    if (repetition %% 25L == 0L || repetition == repetitions) {
      saveRDS(completed, paste0(checkpoint_file, ".tmp"))
      file.rename(paste0(checkpoint_file, ".tmp"), checkpoint_file)
    }
  }
  message(family_name, ": condition ", condition_index, "/", nrow(conditions), " complete")
  invisible(NULL)
}

summarise_family <- function(family_name) {
  family_directory <- file.path(output_directory, family_name)
  completed <- lapply(list.files(family_directory, pattern = "^condition-[0-9]+[.]rds$", full.names = TRUE), readRDS)
  fits <- dplyr::bind_rows(lapply(completed, `[[`, "fits"))
  statistics <- dplyr::bind_rows(lapply(completed, `[[`, "statistics"))
  write.csv(fits, file.path(family_directory, "fits.csv"), row.names = FALSE)
  write.csv(statistics, file.path(family_directory, "statistics.csv"), row.names = FALSE)
  completion <- fits |>
    dplyr::group_by(family, condition, n_dyads, target_correlation) |>
    dplyr::summarise(attempted = dplyr::n(), successful = sum(status == "success"),
      with_warnings = sum(warnings != ""), check_errors = sum(status == "check_error"),
      .groups = "drop")
  if (!nrow(statistics)) {
    stop("No correlations could be checked for ", family_name, "; see its fits.csv.")
  }
  summaries <- summarise_family_comparison(statistics, completion)
  write.csv(summaries$summary, file.path(family_directory, "summary.csv"), row.names = FALSE)
  write.csv(summaries$paired_comparison, file.path(family_directory, "paired-comparison.csv"), row.names = FALSE)
  summaries$summary
}

family_labels <- c(gaussian = "Gaussian", nbinom2 = "Negative binomial (NB2)",
  ordinal = "Ordinal", lognormal = "Lognormal", zi_poisson = "Zero-inflated Poisson",
  hurdle_nbinom2 = "Hurdle negative binomial (NB2)", poisson = "Poisson",
  nbinom1 = "Negative binomial (NB1)", nbinom12 = "Negative binomial (NB12)",
  compois = "COM-Poisson", genpois = "Generalized Poisson", truncated_poisson = "Zero-truncated Poisson",
  truncated_nbinom1 = "Zero-truncated NB1", truncated_nbinom2 = "Zero-truncated NB2",
  truncated_compois = "Zero-truncated COM-Poisson", truncated_genpois = "Zero-truncated generalized Poisson",
  tweedie = "Tweedie", Gamma = "Gamma", beta = "Beta", skewnormal = "Skew-normal", bell = "Bell", t = "Student t")
if (!plot_only) {
  writeLines(c(paste("Generated datasets per condition:", repetitions),
    paste("Reference simulations per fit:", reference_draws),
    "Actor slope 0.5, partner slope 0.3; predictor SDs 1 and partner correlation 0.3.",
    "Both methods share each fitted model and simulation object.",
    paste("glmmTMB commit:", packageDescription("glmmTMB")$RemoteSha), capture.output(sessionInfo())),
    file.path(output_directory, "session-info.txt"))
}
for (family_name in selected_families) {
  family_directory <- file.path(output_directory, family_name)
  if (!plot_only) {
    margin <- make_family_margin(family_name)
    dir.create(family_directory, showWarnings = FALSE)
    family_calibration <- calibration[calibration$family == family_name, ]
    stopifnot(nrow(family_calibration) == 4L)
    completed <- parallel::mclapply(order(conditions$n_dyads, decreasing = TRUE), run_condition,
      mc.cores = workers, mc.set.seed = FALSE, mc.preschedule = FALSE)
    stopifnot(!any(vapply(completed, inherits, logical(1), "try-error")))
  }
  summary <- summarise_family(family_name)
  figure <- plot_family_comparison(summary, family_labels[[family_name]], repetitions, reference_draws)
  for (extension in c("png", "pdf")) {
    ggplot2::ggsave(file.path(output_directory, paste0(family_name, ".", extension)),
      figure, width = 13, height = 6, dpi = 180)
  }
  if (repetitions == 500L && reference_draws == 1000L &&
      all(summary$attempted == 500L) && family_name %in% vignette_families) {
    ggplot2::ggsave(file.path(study_directory, "../figures", paste0("family-comparison-", family_name, ".png")),
      figure, width = 13, height = 6, dpi = 180)
  }
  if (!plot_only) {
    family_settings <- data.frame(family = family_name, label = family_labels[[family_name]],
      formula = "outcome ~ actor_predictor + partner_predictor",
      mean_settings = paste0("Actor effect 0.5; partner effect 0.3; ", margin$family$link,
        " link; intercept ", signif(margin$mean_intercept, 3), "."),
      dispersion_settings = margin$settings,
      zero_settings = if (margin$zero_probability > 0) "Constant zero component, probability 0.25; fitted with ziformula = ~1." else "",
      datasets_per_condition = repetitions, reference_draws = reference_draws)
    write.csv(family_settings, file.path(family_directory, "settings.csv"), row.names = FALSE)
  }
  # Refresh the combined report data after each family, without fitting during rendering.
  for (filename in c("summary", "settings")) {
    saved_files <- file.path(output_directory, family_names, paste0(filename, ".csv"))
    combined <- dplyr::bind_rows(lapply(saved_files[file.exists(saved_files)], read.csv))
    write.csv(combined, file.path(output_directory, paste0(filename, ".csv")), row.names = FALSE)
  }
  if (!plot_only) {
    write.csv(calibration, file.path(output_directory, "calibration.csv"), row.names = FALSE)
  }
  message("Completed ", family_name, ": ", sum(summary$attempted[summary$response == "raw"]), " datasets")
}

# Render both documents after a complete run. Plot mode only updates saved results.
saved_settings <- read.csv(file.path(output_directory, "settings.csv"))
if (!plot_only && repetitions == 500L && reference_draws == 1000L &&
    all(family_names %in% saved_settings$family)) {
  source(file.path(study_directory, "export-report-data.R"))
  rmarkdown::render("vignettes/articles/partner-dependence-simulation.Rmd", quiet = TRUE)
  rmarkdown::render(file.path(study_directory, "../partner-dependence-vignette-draft.Rmd"), quiet = TRUE)
}
