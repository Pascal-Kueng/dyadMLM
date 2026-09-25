# Plots for the covariance-pooling report, styled like the family-comparison plots.
pooling_method_labels <- c(checks = "Composition checks of the pooled model",
  comparison = "Model comparison", full = "Composition checks of the full model")
pooling_method_colours <- c(checks = "#D55E00", comparison = "#009E73", full = "grey50")
pooling_method_lines <- c(checks = "solid", comparison = "longdash", full = "dotted")

pooling_plot_theme <- function() {
  ggplot2::theme_bw(base_size = 14) +
    ggplot2::theme(
      legend.position = "bottom", legend.key.width = grid::unit(1.5, "cm"),
      panel.grid.minor = ggplot2::element_blank(),
      axis.text = ggplot2::element_text(size = 11.5),
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
      strip.text = ggplot2::element_text(face = "bold"),
      plot.title = ggplot2::element_text(face = "bold", size = 16),
      plot.caption = ggplot2::element_text(hjust = 0, size = 11)
    )
}

# Shared layers: shaded uncertainty, lines, bars, and points for each method.
pooling_rate_layers <- function(plot_data) {
  methods <- intersect(names(pooling_method_labels), unique(plot_data$method))
  list(
    ggplot2::geom_ribbon(ggplot2::aes(ymin = lower, ymax = upper, fill = method),
      alpha = 0.12, colour = NA, show.legend = FALSE),
    ggplot2::geom_line(linewidth = 0.8),
    ggplot2::geom_errorbar(ggplot2::aes(ymin = lower, ymax = upper),
      width = 0.04, linewidth = 0.5, linetype = "solid", show.legend = FALSE),
    ggplot2::geom_point(size = 2),
    ggplot2::scale_colour_manual(values = pooling_method_colours[methods],
      labels = pooling_method_labels[methods], breaks = methods),
    ggplot2::scale_fill_manual(values = pooling_method_colours[methods], guide = "none"),
    ggplot2::scale_linetype_manual(values = pooling_method_lines[methods],
      labels = pooling_method_labels[methods], breaks = methods),
    ggplot2::scale_x_continuous(transform = "log10", breaks = sort(unique(plot_data$n_dyads))),
    ggplot2::labs(x = "Total number of dyads", colour = NULL, linetype = NULL)
  )
}

pooling_caption <- function(repetitions, reference_draws, same_datasets, extra) {
  paste0(repetitions, " datasets generated per condition; ", reference_draws,
    " simulations per fit. ",
    if (same_datasets) "All methods use the datasets where both models were fitted and checked.\n" else
      "All fits were usable.\n",
    "Bars and shading: 95% uncertainty intervals. ", extra)
}

plot_pooling_detection <- function(plot_data, family_label, subtitle,
                                   repetitions, reference_draws, same_datasets) {
  ggplot2::ggplot(plot_data, ggplot2::aes(n_dyads, rate, colour = method,
      linetype = method, group = method)) +
    pooling_rate_layers(plot_data) +
    ggplot2::facet_wrap(~ scenario, nrow = 1) +
    ggplot2::scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.2),
      labels = function(values) paste0(100 * values, "%")) +
    ggplot2::labs(
      title = "Detecting incorrect covariance pooling",
      subtitle = paste(family_label, subtitle),
      y = "Flagged or rejected (%)",
      caption = pooling_caption(repetitions, reference_draws, same_datasets,
        "A flag means at least one of 14 composition summaries is outside its middle 95% simulated range.\nCorrelations are listed for female-female, female-male, and male-male dyads.")
    ) +
    pooling_plot_theme()
}

plot_pooling_false_alarms <- function(plot_data, family_label, subtitle,
                                      repetitions, reference_draws, same_datasets) {
  # Start with a 0–20% scale, expanding if needed to show every uncertainty bar.
  y_axis_breaks <- pretty(c(0, max(0.2, plot_data$upper, na.rm = TRUE)), n = 5)
  ggplot2::ggplot(plot_data, ggplot2::aes(n_dyads, rate, colour = method,
      linetype = method, group = method)) +
    ggplot2::geom_hline(yintercept = 0.05, colour = "grey45", linetype = "dashed") +
    pooling_rate_layers(plot_data) +
    ggplot2::scale_y_continuous(limits = range(y_axis_breaks), breaks = y_axis_breaks,
      labels = function(values) paste0(100 * values, "%")) +
    ggplot2::labs(
      title = "False alarms when pooling is correct",
      subtitle = paste(family_label, subtitle),
      y = "False alarms (%)",
      caption = pooling_caption(repetitions, reference_draws, same_datasets,
        "Grey dashed line: 5% benchmark, not a guaranteed false-alarm rate.")
    ) +
    pooling_plot_theme()
}
