# Run from the repository root. Arguments: apim/families, repetitions, draws, workers.
# Add "plot" as the fifth argument to summarise saved results without fitting models.
devtools::load_all(quiet = TRUE)
arguments <- commandArgs(trailingOnly = TRUE)
study_group <- if (length(arguments)) arguments[1] else "apim"
repetitions <- if (length(arguments) >= 2L) as.integer(arguments[2]) else
  if (study_group == "apim") 500L else 200L
reference_draws <- if (length(arguments) >= 3L) as.integer(arguments[3]) else 499L
workers <- if (length(arguments) >= 4L) as.integer(arguments[4]) else 4L
plot_only <- length(arguments) >= 5L && arguments[5] == "plot"
stopifnot(study_group %in% c("apim", "families"), repetitions > 0L,
          reference_draws >= 20L, workers > 0L)
output_directory <- file.path("dev/diagnostic_checks/simulation-studies/results/sensitivity",
  study_group, paste0(repetitions, "-datasets-", reference_draws, "-draws"))
dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)

# Preserve the completed studies' conditions and dataset seeds.
if (study_group == "apim") {
  conditions <- expand.grid(
    n_dyads = c(20L, 40L, 60L, 80L, 100L, 150L, 200L, 300L, 400L, 500L, 1000L),
    latent_correlation = c(0, 0.1, 0.3, 0.5)
  ) |>
    dplyr::mutate(family = "gaussian", sd_ratio = 1,
      condition = dplyr::row_number(), seed_base = 110000000L + 100000L * condition)
} else {
  departures <- data.frame(
    condition = 1:9, latent_correlation = c(-0.25, 0, 0.1, 0.25, 0.5, 0, 0, 0, 0.25),
    sd_ratio = c(rep(1, 5), 1.1, 1.25, 1.5, 1.25)
  )
  family_names <- c("gaussian", "nbinom2", "ordinal", "lognormal")
  conditions <- expand.grid(family = family_names, condition = 1:9,
    n_dyads = c(50L, 200L, 1000L), stringsAsFactors = FALSE) |>
    dplyr::left_join(departures, by = "condition") |>
    dplyr::mutate(seed_base = 83000000L + 1000000L * match(family, family_names) +
      100000L * condition + 100L * n_dyads)
}

generate_apim_data <- function(number_of_dyads, residual_correlation) {
  first_predictor <- rnorm(number_of_dyads)
  second_predictor <- 0.3 * first_predictor + sqrt(1 - 0.3^2) * rnorm(number_of_dyads)
  first_error <- rnorm(number_of_dyads)
  second_error <- residual_correlation * first_error +
    sqrt(1 - residual_correlation^2) * rnorm(number_of_dyads)
  # Consecutive rows are partners. Swap their predictors to form the partner column.
  actor_predictor <- as.vector(rbind(first_predictor, second_predictor))
  partner_predictor <- as.vector(rbind(second_predictor, first_predictor))
  data.frame(
    dyad = factor(rep(seq_len(number_of_dyads), each = 2)),
    role = factor(rep(c("first", "second"), number_of_dyads)),
    actor_predictor, partner_predictor,
    outcome = 0.5 * actor_predictor + 0.3 * partner_predictor +
      as.vector(rbind(first_error, second_error))
  )
}


# Change dependence without changing either member's marginal distribution.
# For the SD sweep, change only the second role's spread and keep its mean fixed.
generate_sensitivity_data <- function(family_name, number_of_dyads,
                                      latent_correlation, sd_ratio) {
  first_normal <- rnorm(number_of_dyads)
  second_normal <- latent_correlation * first_normal +
    sqrt(1 - latent_correlation^2) * rnorm(number_of_dyads)
  normal_scores <- as.vector(rbind(first_normal, second_normal))
  role_sd_multiplier <- rep(c(1, sd_ratio), number_of_dyads)

  outcome <- switch(family_name,
    gaussian = normal_scores * role_sd_multiplier,
    nbinom2 = {
      response_sd <- 2 * role_sd_multiplier
      size <- 3^2 / (response_sd^2 - 3)
      qnbinom(pnorm(normal_scores), mu = 3, size = size)
    },
    lognormal = {
      response_sd <- 2 * role_sd_multiplier
      log_variance <- log1p(response_sd^2 / 3^2)
      exp(log(3) - log_variance / 2 + sqrt(log_variance) * normal_scores)
    },
    ordinal = {
      # Symmetric category probabilities give mean 2.5 and the requested SD.
      response_sd <- 0.8 * role_sd_multiplier
      outer_category_probability <- (response_sd^2 - 0.25) / 4
      uniform_scores <- pnorm(normal_scores)
      category_scores <- 1L + (uniform_scores > outer_category_probability) +
        (uniform_scores > 0.5) + (uniform_scores > 1 - outer_category_probability)
      ordered(category_scores, levels = 1:4)
    }
  )
  data.frame(
    dyad = factor(rep(seq_len(number_of_dyads), each = 2)),
    role = factor(rep(c("first", "second"), number_of_dyads)), outcome
  )
}

statistic_columns <- c(
  first_sd = "SD (first)", second_sd = "SD (second)",
  correlation = "Partner correlation (first and second)",
  dyad_average_sd = "Dyad-average SD",
  half_difference_sd = "Half-difference SD (first minus second)",
  mean_difference_correlation = "Dyad-average/role-difference correlation (first minus second)"
)
condition_columns <- c("family", "condition", "n_dyads", "latent_correlation", "sd_ratio")

run_condition <- function(condition_index) {
  condition <- conditions[condition_index, ]
  results <- lapply(seq_len(repetitions), function(repetition) {
    dataset_seed <- condition$seed_base + repetition
    set.seed(dataset_seed)
    fitting_data <- if (study_group == "apim") {
      generate_apim_data(condition$n_dyads, condition$latent_correlation)
    } else {
      generate_sensitivity_data(condition$family, condition$n_dyads,
                                condition$latent_correlation, condition$sd_ratio)
    }
    fit_status <- data.frame(condition[condition_columns], repetition, dataset_seed,
      status = "fit_error", convergence = NA_integer_, positive_hessian = NA,
      warnings = "", error = "")
    warning_messages <- character()
    statistics <- tryCatch(withCallingHandlers({
      if (condition$family == "ordinal" && any(table(fitting_data$outcome) == 0L)) {
        fit_status$status <- "study_exclusion"
        stop("Missing ordinal category: keep the study's four-category scoring fixed.")
      }
      fitted_family <- switch(condition$family,
        gaussian = gaussian(), nbinom2 = glmmTMB::nbinom2(),
        ordinal = glmmTMB::ordinal(link = "probit"), lognormal = glmmTMB::lognormal())
      # Both designs omit partner dependence and pool the roles' variances.
      model <- glmmTMB::glmmTMB(
        if (study_group == "apim") outcome ~ actor_predictor + partner_predictor else outcome ~ 1,
        data = fitting_data, family = fitted_family
      )
      fit_status$convergence <- model$fit$convergence
      fit_status$positive_hessian <- isTRUE(model$sdr$pdHess)
      if (fit_status$convergence != 0L || !fit_status$positive_hessian) {
        fit_status$status <- "fit_problem"
        NULL
      } else {
        fit_status$status <- "check_error"
        simulations <- suppressMessages(simulate_dyad_responses(
          model, nsim = reference_draws, seed = dataset_seed + 10000000L))
        # The identifiers are absent from the formula, so supply their source data.
        check <- check_partner_dependence(simulations, dyad = dyad, role = role,
          data = fitting_data, response = if (study_group == "apim") "model-centred" else "raw",
          plot = FALSE)
        stopifnot(check$n_pairs == condition$n_dyads)
        checked_statistics <- check$compositions$statistics[[1]]
        # Save every panel statistic now, so an SD comparison needs no separate rerun.
        statistics <- lapply(names(statistic_columns), function(statistic_name) {
          values <- checked_statistics[[statistic_columns[[statistic_name]]]]
          reference_values <- values[-1]
          undefined_draws <- sum(!is.finite(reference_values))
          reference_values <- reference_values[is.finite(reference_values)]
          reference_limits <- quantile(reference_values, c(0.025, 0.975))
          data.frame(statistic = statistic_name, observed = values[1],
            reference_median = median(reference_values),
            reference_lower = unname(reference_limits[1]),
            reference_upper = unname(reference_limits[2]), undefined_draws,
            flagged = values[1] < reference_limits[1] | values[1] > reference_limits[2])
        }) |> dplyr::bind_rows()
        fit_status$status <- "success"
        dplyr::bind_cols(fit_status[c(condition_columns, "repetition")], statistics)
      }
    }, warning = function(warning) {
      warning_messages <<- c(warning_messages, conditionMessage(warning))
      invokeRestart("muffleWarning")
    }), error = function(error) {
      fit_status$error <<- conditionMessage(error)
      NULL
    })
    fit_status$warnings <- paste(unique(warning_messages), collapse = " | ")
    list(fit = fit_status, statistics = statistics)
  })
  fits <- dplyr::bind_rows(lapply(results, `[[`, "fit"))
  statistics <- dplyr::bind_rows(lapply(results, `[[`, "statistics"))
  # Separate condition files preserve completed work if a longer run is interrupted.
  write.csv(fits, file.path(output_directory, paste0("fits-", condition_index, ".csv")), row.names = FALSE)
  write.csv(statistics, file.path(output_directory, paste0("statistics-", condition_index, ".csv")), row.names = FALSE)
  message("Condition ", condition_index, "/", nrow(conditions), " complete")
  list(fits = fits, statistics = statistics)
}

if (!plot_only) {
  writeLines(c(paste("Study:", study_group), paste("Datasets per condition:", repetitions),
    paste("Reference simulations:", reference_draws),
    "APIM: actor slope 0.5, partner slope 0.3; predictor SDs 1 and correlation 0.3; residual SDs 1.",
    "Families: intercept-only fits; see README for response means, SDs and copula construction.",
    paste("glmmTMB commit:", packageDescription("glmmTMB")$RemoteSha),
    capture.output(sessionInfo())), file.path(output_directory, "session-info.txt"))
  # Start larger datasets first. Seeds do not depend on worker count or run order.
  completed <- parallel::mclapply(order(conditions$n_dyads, decreasing = TRUE),
    run_condition, mc.cores = workers, mc.set.seed = FALSE, mc.preschedule = FALSE)
  stopifnot(!any(vapply(completed, inherits, logical(1), "try-error")))
  for (filename in c("fits", "statistics")) {
    write.csv(dplyr::bind_rows(lapply(completed, `[[`, filename)),
      file.path(output_directory, paste0(filename, ".csv")), row.names = FALSE)
  }
}
fits <- read.csv(file.path(output_directory, "fits.csv"))
statistics <- read.csv(file.path(output_directory, "statistics.csv"))
completion <- fits |>
  dplyr::group_by(dplyr::across(dplyr::all_of(condition_columns))) |>
  dplyr::summarise(attempted = dplyr::n(), successful = sum(status == "success"),
    with_warnings = sum(!is.na(warnings) & warnings != ""), .groups = "drop")
either_sd <- statistics |>
  dplyr::filter(statistic %in% c("first_sd", "second_sd")) |>
  dplyr::group_by(dplyr::across(dplyr::all_of(c(condition_columns, "repetition")))) |>
  dplyr::summarise(statistic = "either_sd",
    flagged = if (all(!is.na(flagged))) any(flagged) else NA, .groups = "drop")
summary <- dplyr::bind_rows(statistics, either_sd) |>
  dplyr::group_by(dplyr::across(dplyr::all_of(c(condition_columns, "statistic")))) |>
  dplyr::summarise(checked = sum(!is.na(flagged)), flagged = sum(flagged, na.rm = TRUE),
    .groups = "drop") |>
  dplyr::mutate(
    frequency = flagged / checked,
    # Wilson intervals show uncertainty from using a finite number of datasets.
    interval_center = (frequency + qnorm(0.975)^2 / (2 * checked)) /
      (1 + qnorm(0.975)^2 / checked),
    interval_half_width = qnorm(0.975) *
      sqrt(frequency * (1 - frequency) / checked + qnorm(0.975)^2 / (4 * checked^2)) /
      (1 + qnorm(0.975)^2 / checked),
    frequency_lower = pmax(0, interval_center - interval_half_width),
    frequency_upper = pmin(1, interval_center + interval_half_width)
  ) |>
  dplyr::select(-interval_center, -interval_half_width) |>
  dplyr::left_join(completion, by = condition_columns)
write.csv(summary, file.path(output_directory, "summary.csv"), row.names = FALSE)
write.csv(completion, file.path(output_directory, "completion.csv"), row.names = FALSE)

if (study_group == "apim") {
  summary <- summary |>
    dplyr::filter(statistic == "correlation") |>
    dplyr::mutate(residual_correlation = latent_correlation)
  baseline_range <- range(summary$frequency[summary$residual_correlation == 0]) * 100
  plot_data <- summary |>
    dplyr::filter(residual_correlation > 0) |>
    dplyr::mutate(
      # Keep linear spacing through 500; place 1,000 beyond a visible break.
      axis_position = ifelse(n_dyads == 1000, 600, n_dyads),
      correlation_label = factor(residual_correlation,
        levels = c(0.1, 0.3, 0.5), labels = c("0.10", "0.30", "0.50"))
    )
  figure <- ggplot2::ggplot(plot_data, ggplot2::aes(
    x = axis_position, y = frequency, colour = correlation_label, fill = correlation_label,
    group = correlation_label
  )) +
    # Stop lines and ribbons at the break. Every point keeps its uncertainty bar.
    ggplot2::geom_ribbon(data = subset(plot_data, n_dyads <= 500),
                         ggplot2::aes(ymin = frequency_lower, ymax = frequency_upper),
                         alpha = 0.12, colour = NA, show.legend = FALSE) +
    ggplot2::geom_line(data = subset(plot_data, n_dyads <= 500), linewidth = 0.8) +
    ggplot2::geom_errorbar(ggplot2::aes(ymin = frequency_lower, ymax = frequency_upper),
                           width = 6, linewidth = 0.5, show.legend = FALSE) +
    ggplot2::geom_point(size = 2) +
    # Replace gridlines in the gap with dots to make the shortened interval clear.
    ggplot2::annotate("rect", xmin = 530, xmax = 570, ymin = -Inf, ymax = Inf,
                      fill = "white", colour = NA) +
    ggplot2::annotate("point", x = rep(c(542, 550, 558), times = 6),
                      y = rep(seq(0, 1, 0.2), each = 3), colour = "grey55", size = 0.8) +
    ggplot2::scale_colour_manual(values = c("#0072B2", "#D55E00", "#009E73")) +
    ggplot2::scale_fill_manual(values = c("#0072B2", "#D55E00", "#009E73")) +
    ggplot2::scale_x_continuous(
      breaks = c(sort(unique(plot_data$n_dyads[plot_data$n_dyads <= 500])), 550, 600),
      labels = c(sort(unique(plot_data$n_dyads[plot_data$n_dyads <= 500])), "...", "1,000")
    ) +
    ggplot2::scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.2),
                               labels = function(values) paste0(100 * values, "%")) +
    ggplot2::labs(
      title = "Detecting unmodelled partner correlation",
      subtitle = "Gaussian APIM with actor and partner effects",
      x = "Number of dyads", y = "Datasets flagged (%)",
      colour = "Residual correlation", fill = "Residual correlation",
      caption = paste0(
        repetitions, " datasets per point; ", reference_draws, " simulations per fit. Shading and bars: 95% Monte Carlo intervals.\n",
        "Flag: observed model-centred partner correlation outside its middle 95% simulated range.\n",
        sprintf("With zero residual correlation, %.1f%% to %.1f%% were flagged across sample sizes.",
                baseline_range[1], baseline_range[2]),
        "\nLinear spacing through 500 dyads; the gap to 1,000 is shortened."
      )
    ) +
    ggplot2::theme_bw(base_size = 11) +
    ggplot2::theme(
      legend.position = "bottom", panel.grid.minor = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold", size = 14),
      plot.caption = ggplot2::element_text(hjust = 0, size = 9)
    )
  for (extension in c("png", "pdf")) {
    ggplot2::ggsave(file.path(output_directory, paste0("detection-by-sample-size.", extension)),
                    figure, width = 8.5, height = 5.8, dpi = 180)
  }
  # Only the documented study settings update the vignette figure, so pilots cannot replace it.
  if (repetitions == 500L && reference_draws == 499L) {
    figure_directory <- "dev/diagnostic_checks/figures"
    dir.create(figure_directory, showWarnings = FALSE)
    file.copy(file.path(output_directory, "detection-by-sample-size.png"),
              file.path(figure_directory, "apim-sample-size.png"), overwrite = TRUE)
  }
}
print(completion |> dplyr::group_by(family) |>
  dplyr::summarise(dplyr::across(c(attempted, successful, with_warnings), sum)))
