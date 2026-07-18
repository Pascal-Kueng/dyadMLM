draw_residual_concepts <- function() {
  predicted_value <- 10

  residual_data <- data.frame(
    dyad = rep(seq_len(10), each = 2),
    role = factor(
      rep(c("Female partner", "Male partner"), times = 10),
      levels = c("Female partner", "Male partner")
    ),
    residual = as.vector(rbind(
      c(0.05, -1.00, 0.95, -0.20, 0.75, -0.45, 0.55, -0.80, 0.35, 0.15),
      c(0.40, -2.70, 2.00, -0.80, 2.80, -2.00, 0.90, -1.50, 1.40, -0.30)
    ))
  )
  residual_data$observed <- predicted_value + residual_data$residual

  role_colours <- c(
    "Female partner" = "#004D40",
    "Male partner" = "#00A6B2"
  )
  ink_colour <- "#263238"
  muted_colour <- "#64748B"

  residual_plot <- ggplot2::ggplot(
    residual_data,
    ggplot2::aes(x = dyad, colour = role)
  ) +
    ggplot2::geom_hline(
      yintercept = predicted_value,
      colour = muted_colour,
      linewidth = 0.8,
      linetype = "dashed"
    ) +
    ggplot2::geom_segment(
      ggplot2::aes(
        xend = dyad,
        y = predicted_value,
        yend = observed
      ),
      linewidth = 1.25,
      alpha = 0.72,
      show.legend = FALSE
    ) +
    ggplot2::geom_point(
      ggplot2::aes(y = observed),
      size = 3.1,
      show.legend = FALSE
    ) +
    ggplot2::annotate(
      "label",
      x = 1.1,
      y = predicted_value + 0.35,
      label = "hat(italic(Y)) == 10",
      parse = TRUE,
      hjust = 0,
      size = 3.7,
      colour = muted_colour,
      fill = "white",
      linewidth = 0
    ) +
    ggplot2::facet_grid(
      rows = ggplot2::vars(role),
      labeller = ggplot2::labeller(role = ggplot2::as_labeller(
        c(
          "Female partner" =
            "plain('Female: smaller')~italic(sigma)[italic(epsilon)[plain(F)]]^2",
          "Male partner" =
            "plain('Male: larger')~italic(sigma)[italic(epsilon)[plain(M)]]^2"
        ),
        default = ggplot2::label_parsed
      ))
    ) +
    ggplot2::scale_colour_manual(values = role_colours) +
    ggplot2::scale_x_continuous(
      breaks = seq_len(10),
      expand = ggplot2::expansion(mult = c(0.03, 0.04))
    ) +
    ggplot2::coord_cartesian(ylim = c(6.8, 14.0), clip = "off") +
    ggplot2::labs(
      title = "Residual = observed − predicted",
      subtitle = "Line length shows the size of each residual",
      x = "Illustrative dyad (arbitrary order)",
      y = "Outcome"
    ) +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(
        face = "bold", colour = ink_colour, size = 15
      ),
      plot.subtitle = ggplot2::element_text(colour = muted_colour, size = 11),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_blank(),
      panel.grid.major.y = ggplot2::element_line(
        colour = "#E2E8F0", linewidth = 0.35
      ),
      strip.text = ggplot2::element_text(
        face = "bold", colour = ink_colour, size = 11
      ),
      strip.background = ggplot2::element_rect(
        fill = "#F1F5F9", colour = NA
      ),
      axis.text = ggplot2::element_text(colour = ink_colour),
      axis.title = ggplot2::element_text(colour = ink_colour),
      plot.margin = ggplot2::margin(6, 8, 6, 6)
    )

  paired_residuals <- stats::reshape(
    residual_data[c("dyad", "role", "residual")],
    idvar = "dyad",
    timevar = "role",
    direction = "wide"
  )
  names(paired_residuals) <- c("dyad", "female", "male")

  correlation_plot <- ggplot2::ggplot(
    paired_residuals,
    ggplot2::aes(x = male, y = female)
  ) +
    ggplot2::geom_hline(
      yintercept = 0,
      colour = "#CBD5E1",
      linewidth = 0.7
    ) +
    ggplot2::geom_vline(
      xintercept = 0,
      colour = "#CBD5E1",
      linewidth = 0.7
    ) +
    ggplot2::geom_smooth(
      method = "lm",
      formula = y ~ x,
      se = FALSE,
      colour = muted_colour,
      linewidth = 1,
      linetype = "dashed"
    ) +
    ggplot2::geom_point(
      shape = 21,
      size = 5,
      stroke = 1.1,
      colour = ink_colour,
      fill = "#D9EAF7"
    ) +
    ggplot2::geom_text(
      ggplot2::aes(label = dyad),
      colour = ink_colour,
      size = 2.7,
      fontface = "bold"
    ) +
    ggplot2::annotate(
      "text",
      x = 2.7,
      y = 0.35,
      label = "Both above\nprediction",
      hjust = 1,
      vjust = 1,
      colour = ink_colour,
      size = 3.7,
      fontface = "bold"
    ) +
    ggplot2::annotate(
      "text",
      x = -2.6,
      y = -0.15,
      label = "Both below\nprediction",
      hjust = 0,
      vjust = 0,
      colour = ink_colour,
      size = 3.7,
      fontface = "bold"
    ) +
    ggplot2::scale_x_continuous(
      limits = c(-3.1, 3.1),
      breaks = -3:3,
      expand = ggplot2::expansion(mult = 0)
    ) +
    ggplot2::scale_y_continuous(
      limits = c(-1.25, 1.25),
      breaks = c(-1, 0, 1),
      expand = ggplot2::expansion(mult = 0)
    ) +
    ggplot2::labs(
      title = "Same dyads: residuals move together",
      subtitle = expression(
        "Each numbered point pairs two partners; " *
          italic(rho)[italic(epsilon)[plain(F)] * italic(epsilon)[plain(M)]] > 0
      ),
      x = "Male partner residual",
      y = "Female partner residual"
    ) +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(
        face = "bold", colour = ink_colour, size = 15
      ),
      plot.subtitle = ggplot2::element_text(colour = muted_colour, size = 11),
      panel.grid = ggplot2::element_blank(),
      axis.text = ggplot2::element_text(colour = ink_colour),
      axis.title = ggplot2::element_text(colour = ink_colour),
      plot.margin = ggplot2::margin(6, 6, 6, 8)
    )

  patchwork::wrap_plots(
    residual_plot,
    correlation_plot,
    widths = c(1.18, 1)
  ) +
    patchwork::plot_annotation(
      caption = paste0(
        "Schematic intercept-only example: all partners have the same ",
        "predicted value; dyads are shown in arbitrary order."
      ),
      theme = ggplot2::theme(
        plot.caption = ggplot2::element_text(
          colour = muted_colour,
          size = 10.5,
          hjust = 0.5,
          margin = ggplot2::margin(t = 5)
        )
      )
    )
}

residual_concepts_widget <- function(
  script_src = "js/residual-concepts.js",
  id = "residual-concepts-widget"
) {
  markup <- sprintf(
    paste0(
      "<div id=\"%s\" class=\"residual-concepts-widget\">\n",
      "  <div class=\"residual-concepts-controls\" ",
      "aria-label=\"Residual parameter controls\">\n",
      "    <label class=\"residual-control residual-control-female\">\n",
      "      <span>Female residual variance, ",
      "<span class=\"rc-math\">σ<sup>2</sup><sub>εF</sub></span></span>\n",
      "      <span class=\"residual-control-input\">\n",
      "        <input type=\"range\" min=\"0.1\" max=\"7\" step=\"0.1\" ",
      "value=\"0.5\" data-parameter=\"female-variance\" ",
      "aria-label=\"Female residual variance\">\n",
      "        <output data-output=\"female-variance\">0.5</output>\n",
      "      </span>\n",
      "    </label>\n",
      "    <label class=\"residual-control residual-control-male\">\n",
      "      <span>Male residual variance, ",
      "<span class=\"rc-math\">σ<sup>2</sup><sub>εM</sub></span></span>\n",
      "      <span class=\"residual-control-input\">\n",
      "        <input type=\"range\" min=\"0.1\" max=\"7\" step=\"0.1\" ",
      "value=\"3\" data-parameter=\"male-variance\" ",
      "aria-label=\"Male residual variance\">\n",
      "        <output data-output=\"male-variance\">3.0</output>\n",
      "      </span>\n",
      "    </label>\n",
      "    <label class=\"residual-control residual-control-correlation\">\n",
      "      <span>Residual correlation, ",
      "<span class=\"rc-math\">ρ<sub>εF εM</sub></span></span>\n",
      "      <span class=\"residual-control-input\">\n",
      "        <input type=\"range\" min=\"-0.9\" max=\"0.9\" step=\"0.1\" ",
      "value=\"0.7\" data-parameter=\"correlation\" ",
      "aria-label=\"Residual correlation\">\n",
      "        <output data-output=\"correlation\">0.7</output>\n",
      "      </span>\n",
      "    </label>\n",
      "    <button type=\"button\" class=\"residual-reset\" ",
      "data-action=\"reset\">Reset</button>\n",
      "  </div>\n",
      "  <svg class=\"residual-concepts-svg\" viewBox=\"0 0 1200 500\" ",
      "role=\"img\" aria-live=\"polite\"></svg>\n",
      "  <p class=\"residual-concepts-caption\">",
      "One linked set of dyads: changing a variance rescales one partner's residuals ",
      "while preserving <span class=\"rc-math\">ρ<sub>εF εM</sub></span>; ",
      "changing <span class=\"rc-math\">ρ<sub>εF εM</sub></span> ",
      "preserves both residual variances. ",
      "The correlation guide is scale-free, not a fitted regression line.",
      "</p>\n",
      "</div>\n",
      "<script src=\"%s\"></script>\n"
    ),
    id,
    script_src
  )

  cat("```{=html}\n", markup, "```\n", sep = "")
  invisible(NULL)
}
