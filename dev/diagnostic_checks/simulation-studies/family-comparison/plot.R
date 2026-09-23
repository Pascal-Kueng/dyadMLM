plot_family_comparison <- function(summary, family_label, repetitions, reference_draws) {
  plot_data <- subset(summary, target_correlation > 0)
  plot_data$axis_position <- ifelse(plot_data$n_dyads == 1000, 600, plot_data$n_dyads)
  plot_data$correlation_label <- factor(plot_data$target_correlation,
    levels = c(0.1, 0.3, 0.5), labels = c("0.10", "0.30", "0.50"))
  plot_data$response_label <- factor(plot_data$response,
    levels = c("model-centred", "raw"),
    labels = c("Subtract fixed-effect predictions", "Use raw outcomes"))
  figure <- ggplot2::ggplot(plot_data, ggplot2::aes(
    x = axis_position, y = frequency, colour = correlation_label, fill = correlation_label,
    group = correlation_label
  )) +
    # Stop lines and ribbons at 500; every point keeps its uncertainty bar.
    ggplot2::geom_ribbon(data = subset(plot_data, n_dyads <= 500),
      ggplot2::aes(ymin = frequency_lower, ymax = frequency_upper),
      alpha = 0.12, colour = NA, show.legend = FALSE) +
    ggplot2::geom_line(data = subset(plot_data, n_dyads <= 500), linewidth = 0.8) +
    ggplot2::geom_errorbar(ggplot2::aes(ymin = frequency_lower, ymax = frequency_upper),
      width = 6, linewidth = 0.5, show.legend = FALSE) +
    ggplot2::geom_point(size = 2) +
    # Dots replace the gridlines across the shortened gap to 1,000.
    ggplot2::annotate("rect", xmin = 530, xmax = 570, ymin = -Inf, ymax = Inf,
      fill = "white", colour = NA) +
    ggplot2::annotate("point", x = rep(c(542, 550, 558), times = 6),
      y = rep(seq(0, 1, 0.2), each = 3), colour = "grey55", size = 0.8) +
    ggplot2::facet_wrap(~ response_label, nrow = 1) +
    ggplot2::scale_colour_manual(values = c("#0072B2", "#D55E00", "#009E73")) +
    ggplot2::scale_fill_manual(values = c("#0072B2", "#D55E00", "#009E73")) +
    ggplot2::scale_x_continuous(
      breaks = c(20, 40, 60, 80, 100, 150, 200, 300, 400, 500, 550, 600),
      labels = c("20", "40", "60", "80", "100", "150", "200", "300", "400", "500", "...", "1,000")
    ) +
    ggplot2::scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.2),
      labels = function(values) paste0(100 * values, "%")) +
    ggplot2::labs(
      title = "Detecting unmodelled partner correlation",
      subtitle = paste(family_label, "APIM with actor and partner effects"),
      x = "Number of dyads", y = "Detected in expected direction (%)",
      colour = "Target residual correlation", fill = "Target residual correlation",
      caption = paste0(
        repetitions, " datasets generated per condition; ", reference_draws,
        " simulations per fit. Rates use valid checks.\n",
        "Bars and shading: 95% uncertainty intervals. Both methods use the same datasets and simulations.\n",
        "Linear spacing through 500 dyads; the gap to 1,000 is shortened."
      )
    ) +
    ggplot2::theme_bw(base_size = 14) +
    ggplot2::theme(
      legend.position = "bottom", panel.grid.minor = ggplot2::element_blank(),
      axis.text = ggplot2::element_text(size = 11.5),
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
      strip.text = ggplot2::element_text(face = "bold"),
      plot.title = ggplot2::element_text(face = "bold", size = 16),
      plot.caption = ggplot2::element_text(hjust = 0, size = 11)
    )
  figure
}

plot_family_false_alarms <- function(summary, family_label, repetitions, reference_draws) {
  plot_data <- subset(summary, target_correlation == 0)
  plot_data$axis_position <- ifelse(plot_data$n_dyads == 1000, 600, plot_data$n_dyads)
  plot_data$response_label <- factor(plot_data$response,
    levels = c("model-centred", "raw"),
    labels = c("Subtract fixed-effect predictions", "Use raw outcomes"))
  # Start with a 0–15% scale, expanding if needed to show every uncertainty bar.
  y_axis_breaks <- pretty(c(0, max(0.15, plot_data$frequency_upper, na.rm = TRUE)), n = 5)

  ggplot2::ggplot(plot_data, ggplot2::aes(
    x = axis_position, y = frequency, linetype = response_label, shape = response_label,
    group = response_label
  )) +
    ggplot2::geom_hline(yintercept = 0.05, colour = "grey45", linetype = "dashed") +
    ggplot2::geom_line(data = subset(plot_data, n_dyads <= 500), linewidth = 0.8) +
    ggplot2::geom_errorbar(ggplot2::aes(ymin = frequency_lower, ymax = frequency_upper),
      width = 6, linewidth = 0.5, linetype = "solid", colour = "grey40", show.legend = FALSE) +
    ggplot2::geom_point(size = 2) +
    # Keep the same shortened gap as the detection plots.
    ggplot2::annotate("rect", xmin = 530, xmax = 570, ymin = -Inf, ymax = Inf,
      fill = "white", colour = NA) +
    ggplot2::annotate("point", x = rep(c(542, 550, 558), times = length(y_axis_breaks)),
      y = rep(y_axis_breaks, each = 3), colour = "grey55", size = 0.8) +
    ggplot2::scale_linetype_manual(values = c("solid", "dotted")) +
    ggplot2::scale_shape_manual(values = c(16, 1)) +
    ggplot2::scale_x_continuous(
      breaks = c(20, 40, 60, 80, 100, 150, 200, 300, 400, 500, 550, 600),
      labels = c("20", "40", "60", "80", "100", "150", "200", "300", "400", "500", "...", "1,000")
    ) +
    ggplot2::scale_y_continuous(limits = range(y_axis_breaks), breaks = y_axis_breaks,
      labels = function(values) paste0(100 * values, "%")) +
    ggplot2::labs(
      title = "False alarms with no residual partner correlation",
      subtitle = paste(family_label, "APIM with actor and partner effects"),
      x = "Number of dyads", y = "False alarms (%)", linetype = NULL, shape = NULL,
      caption = paste0(
        repetitions, " datasets generated per condition; ", reference_draws,
        " simulations per fit. Rates use valid checks.\n",
        "Bars: 95% uncertainty intervals. Grey dashed line: 5% benchmark, not a guaranteed false-alarm rate.\n",
        "Linear spacing through 500 dyads; the gap to 1,000 is shortened."
      )
    ) +
    ggplot2::theme_bw(base_size = 14) +
    ggplot2::theme(
      legend.key.width = grid::unit(1.5, "cm"),
      legend.position = "bottom", panel.grid.minor = ggplot2::element_blank(),
      axis.text = ggplot2::element_text(size = 11.5),
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
      plot.title = ggplot2::element_text(face = "bold", size = 16),
      plot.caption = ggplot2::element_text(hjust = 0, size = 11)
    )
}
