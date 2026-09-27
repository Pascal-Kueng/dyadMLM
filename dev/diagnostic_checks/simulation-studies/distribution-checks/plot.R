distribution_family_labels <- c(gaussian = "Gaussian", nbinom2 = "Negative binomial")
distribution_scenario_order <- c("correct", "mean_small", "mean_large", "variance_small",
  "variance_large", "dispersion_small", "dispersion_large", "zeros_small", "zeros_large")
distribution_panel_labels <- c(
  qq = "PIT QQ envelope", histogram = "PIT histogram envelope",
  outliers = "Outlier count", mean_distance = "Mean PIT distance",
  predicted_quantiles = "PIT quartiles vs prediction",
  predicted_distance = "PIT distance vs prediction",
  response_sd = "Response SD", maximum_deviation = "Largest deviation",
  zeros = "Zero count"
)

distribution_plot_theme <- function() {
  ggplot2::theme_bw(base_size = 13) +
    ggplot2::theme(legend.position = "bottom",
      panel.grid.minor = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold"),
      plot.title = ggplot2::element_text(face = "bold", size = 16),
      plot.caption = ggplot2::element_text(hjust = 0, size = 10.5))
}

distribution_percent <- function(values) paste0(round(100 * values), "%")

distribution_run_caption <- function(data) {
  attempted <- range(data$attempted)
  datasets <- if (diff(attempted) == 0) attempted[1] else paste(attempted, collapse = "–")
  paste0(datasets, " datasets per shown condition; ", unique(data$reference_draws),
    " reference simulations per bank.",
    if (any(data$repetitions < 500 | data$reference_draws < 1000)) " Pilot results." else "",
    "\n")
}

plot_distribution_panels <- function(summary) {
  plot_data <- subset(summary, scenario == "correct" & n_times == 1 & dyad_sd == .6 &
    view == "pooled" & role == "Pooled" & statistic %in% names(distribution_panel_labels) &
    is.finite(rate))
  if (!nrow(plot_data)) return(NULL)
  plot_data$method <- factor(plot_data$reference,
    levels = c("known", "fitted-centred", "fitted", "fitted-uncentred"),
    labels = c("Known parameters", "Fitted (default)", "Fitted (default)", "Fitted (no centring)"))
  plot_data$panel <- factor(plot_data$statistic,
    levels = rev(names(distribution_panel_labels)), labels = rev(distribution_panel_labels))
  plot_data$family_label <- distribution_family_labels[plot_data$family]
  plot_data$sample_label <- factor(plot_data$n_dyads,
    labels = paste(sort(unique(plot_data$n_dyads)), "dyads"))
  dodge <- ggplot2::position_dodge(width = .65, orientation = "y")

  ggplot2::ggplot(plot_data, ggplot2::aes(x = rate, y = panel, colour = method)) +
    ggplot2::geom_vline(xintercept = .05, linetype = "dashed", colour = "grey55") +
    ggplot2::geom_errorbar(ggplot2::aes(xmin = rate_lower, xmax = rate_upper),
      orientation = "y", position = dodge, width = .4, show.legend = FALSE) +
    ggplot2::geom_point(position = dodge, size = 1.8) +
    ggplot2::facet_grid(family_label ~ sample_label, scales = "free_y", space = "free_y") +
    ggplot2::scale_colour_manual(values = c("#777777", "#0072B2", "#D55E00")) +
    ggplot2::scale_x_continuous(limits = c(0, NA), labels = distribution_percent) +
    ggplot2::labs(title = "Individual panels under a correct model",
      subtitle = "All observations pooled; no additional predictor pages",
      x = "Datasets flagged (%)", y = NULL, colour = NULL,
      caption = paste0(distribution_run_caption(plot_data),
        "Bars: 95% Wilson intervals for Monte Carlo uncertainty. Dashed line: 5% benchmark.\n",
        "Fitted references need not attain 5%; centring affects only PIT summaries. Category-frequency flags are reported separately.")) +
    distribution_plot_theme()
}

plot_distribution_detection <- function(summary, family_name) {
  plot_data <- subset(summary, family == family_name &
    n_times == 1 & dyad_sd == .6 & statistic == "any" &
    ((check == "residual" & reference == "fitted-centred") |
      (check == "outcome" & reference == "fitted")) &
    ((view == "pooled" & role == "Pooled") | (view == "roles" & role == "All")))
  plot_data <- transform(plot_data,
    check_label = factor(check, levels = c("residual", "outcome"),
      labels = c("Residual checks", "Outcome checks")),
    view_label = factor(view, levels = c("pooled", "roles"),
      labels = c("All observations pooled", "Either role flagged")))
  mismatch <- subset(plot_data, scenario != "correct")
  if (!nrow(mismatch)) return(NULL)
  mismatch$scenario_label <- factor(mismatch$scenario_label,
    levels = unique(mismatch$scenario_label[order(match(mismatch$scenario, distribution_scenario_order))]))
  # Without a setting column, ggplot repeats the correct-model rates in every column.
  baseline <- subset(plot_data, scenario == "correct", select = -scenario_label)

  ggplot2::ggplot(mismatch, ggplot2::aes(x = n_dyads, y = rate,
    linetype = view_label, shape = view_label, group = view_label)) +
    ggplot2::geom_line(data = baseline, ggplot2::aes(colour = "Correct model"), linewidth = .6) +
    ggplot2::geom_point(data = baseline, ggplot2::aes(colour = "Correct model"), size = 1.6) +
    ggplot2::geom_line(ggplot2::aes(colour = "Model mismatch"), linewidth = .7) +
    ggplot2::geom_errorbar(ggplot2::aes(ymin = rate_lower, ymax = rate_upper, colour = "Model mismatch"),
      width = 5, linewidth = .4, linetype = "solid", show.legend = FALSE) +
    ggplot2::geom_point(ggplot2::aes(colour = "Model mismatch"), size = 2) +
    ggplot2::facet_grid(check_label ~ scenario_label,
      labeller = ggplot2::labeller(scenario_label = ggplot2::label_wrap_gen(20))) +
    ggplot2::scale_colour_manual(values = c(`Model mismatch` = "#0072B2", `Correct model` = "grey60"),
      breaks = c("Model mismatch", "Correct model")) +
    ggplot2::guides(colour = ggplot2::guide_legend(order = 1)) +
    ggplot2::scale_linetype_manual(values = c("dotted", "solid")) +
    ggplot2::scale_shape_manual(values = c(1, 16)) +
    ggplot2::scale_x_continuous(breaks = sort(unique(plot_data$n_dyads))) +
    ggplot2::scale_y_continuous(limits = c(0, 1), labels = distribution_percent) +
    ggplot2::labs(title = paste(distribution_family_labels[family_name], "model mismatches"),
      subtitle = "At least one numerical panel flagged; residual checks use the default median centring",
      x = "Number of dyads", y = "Datasets flagged (%)", colour = NULL, linetype = NULL, shape = NULL,
      caption = paste0(distribution_run_caption(plot_data),
        "Bars: 95% Wilson intervals for Monte Carlo uncertainty. Rates use available checks.\n",
        "Checking both roles gives more opportunities for a flag. These rates are not calibrated power.")) +
    distribution_plot_theme()
}

plot_distribution_centring <- function(paired, family_name) {
  panels <- c(distribution_panel_labels[c("qq", "histogram", "mean_distance",
    "predicted_quantiles", "predicted_distance")], any = "Any panel")
  plot_data <- subset(paired, family == family_name & n_times == 1 & dyad_sd == .6 &
    n_dyads %in% c(100, 400) & check == "residual" & statistic %in% names(panels) &
    ((view == "pooled" & role == "Pooled") | (view == "roles" & role == "All")))
  if (!nrow(plot_data)) return(NULL)
  plot_data$panel <- factor(plot_data$statistic, levels = rev(names(panels)), labels = rev(panels))
  plot_data$sample_label <- factor(plot_data$n_dyads,
    labels = paste(sort(unique(plot_data$n_dyads)), "dyads"))
  plot_data$view_label <- factor(plot_data$view,
    levels = c("pooled", "roles"), labels = c("All observations pooled", "Either role flagged"))
  plot_data$scenario_label <- factor(plot_data$scenario_label,
    levels = unique(plot_data$scenario_label[order(match(plot_data$scenario, distribution_scenario_order))]))
  plot_data$lower <- plot_data$centred_minus_uncentred - 1.96 * plot_data$difference_mcse
  plot_data$upper <- plot_data$centred_minus_uncentred + 1.96 * plot_data$difference_mcse
  dodge <- ggplot2::position_dodge(width = .6, orientation = "y")

  ggplot2::ggplot(plot_data, ggplot2::aes(x = centred_minus_uncentred,
    y = panel, shape = view_label)) +
    ggplot2::geom_vline(xintercept = 0, colour = "grey55", linetype = "dashed") +
    ggplot2::geom_errorbar(ggplot2::aes(xmin = lower, xmax = upper),
      orientation = "y", position = dodge, width = .35, show.legend = FALSE) +
    ggplot2::geom_point(position = dodge, size = 2) +
    ggplot2::facet_grid(sample_label ~ scenario_label,
      labeller = ggplot2::labeller(scenario_label = ggplot2::label_wrap_gen(20))) +
    ggplot2::scale_shape_manual(values = c(1, 16)) +
    ggplot2::scale_x_continuous(labels = function(values) sprintf("%+.0f", 100 * values)) +
    ggplot2::labs(title = paste(distribution_family_labels[family_name],
        "models: what changes when PIT residuals are median-centred?"),
      subtitle = "Difference in the frequency of flags, per panel",
      x = "Centred minus uncentred (percentage points)", y = NULL, shape = NULL,
      caption = paste0(distribution_run_caption(plot_data),
        "Positive values mean more flags after centring. Both versions use identical fits, draws and PIT randomization.\n",
        "Bars: difference ± 1.96 paired Monte Carlo SE. The outlier count does not depend on centring and is omitted.")) +
    distribution_plot_theme()
}
