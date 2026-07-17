draw_apim_exchangeability_comparison <- function() {
  actor_colour <- "#1769AA"
  partner_colour <- "#7B3FA1"
  female_colour <- "#004D40"
  male_colour <- "#00A6B2"
  ink_colour <- "#263238"
  muted_colour <- "#64748B"
  border_colour <- "#CBD5E1"
  grid_colour <- "#E2E8F0"
  node_fill <- "#F8FAFC"
  shared_colour <- "#64748B"
  # Use the same STIX face distributed with MathJax for every mathematical
  # expression.  This keeps the SVG self-contained while giving equations and
  # symbols consistent LaTeX-like typography.
  math_family <- "STIX MathJax Main"

  native <- function(value) grid::unit(value, "native")

  draw_panel <- function(x) {
    grid::grid.roundrect(
      x = native(x), y = native(0.51),
      width = native(0.47), height = native(0.94),
      r = grid::unit(0.03, "snpc"),
      gp = grid::gpar(fill = node_fill, col = border_colour, lwd = 1.25)
    )
  }

  draw_text <- function(
      label, x, y, colour = ink_colour, fontsize = 11,
      fontface = "plain", just = "centre") {
    is_math <- is.expression(label) || is.language(label)
    grid::grid.text(
      label,
      x = native(x), y = native(y), just = just,
      gp = grid::gpar(
        col = colour, fontsize = fontsize, fontface = fontface,
        fontfamily = if (is_math) math_family else ""
      )
    )
  }

  draw_coloured_equation <- function(parts, colours, x, y, fontsize = 12.2) {
    grobs <- Map(
      function(label, colour) {
        grid::textGrob(
          label,
          gp = grid::gpar(
            col = colour, fontsize = fontsize, fontfamily = math_family
          )
        )
      },
      parts, colours
    )
    widths <- vapply(
      grobs,
      function(grob) {
        grid::convertWidth(grid::grobWidth(grob), "native", valueOnly = TRUE)
      },
      numeric(1)
    )
    # A modest visual space between differently coloured formula terms.
    gap <- 0.006
    total_width <- sum(widths) + gap * (length(widths) - 1)
    left <- x - total_width / 2

    for (i in seq_along(grobs)) {
      grid::grid.draw(grid::editGrob(
        grobs[[i]],
        x = native(left + widths[i] / 2),
        y = native(y)
      ))
      left <- left + widths[i] + gap
    }
  }

  draw_divider <- function(x0, x1, y) {
    grid::grid.segments(
      x0 = native(x0), x1 = native(x1),
      y0 = native(y), y1 = native(y),
      gp = grid::gpar(col = grid_colour, lwd = 1)
    )
  }

  draw_prediction_row <- function(
      label, y, intercept, actor_change, partner_change,
      domain, panel_left, panel_right, intercept_label,
      actor_label, partner_label, prediction_label,
      residual_values, residual_colour, sd_label, residual_envelope) {
    map_x <- function(value) {
      panel_left + (value - domain[1]) / diff(domain) *
        (panel_right - panel_left)
    }
    arrow_head <- grid::arrow(
      angle = 26,
      length = grid::unit(0.10, "inches"),
      type = "closed"
    )
    after_actor <- intercept + actor_change
    prediction <- after_actor + partner_change
    label_x <- panel_left - 0.012
    actor_y <- y - 0.040
    partner_y <- y - 0.090
    residual_y <- y + 0.035
    residual_scale <- 0.026
    prediction_x <- map_x(prediction)
    example_i <- which.max(abs(residual_values))
    example_x <- prediction_x + residual_values[example_i] * residual_scale

    draw_text(
      label, label_x, y, fontsize = 13.8, fontface = "bold", just = "right"
    )

    grid::grid.roundrect(
      x = native(prediction_x), y = native(y),
      width = native(2 * residual_envelope * residual_scale),
      height = native(0.030),
      r = grid::unit(0.015, "snpc"),
      gp = grid::gpar(fill = residual_colour, col = NA, alpha = 0.10)
    )
    grid::grid.segments(
      x0 = native(map_x(domain[1])), x1 = native(map_x(domain[2])),
      y0 = native(y), y1 = native(y),
      gp = grid::gpar(col = grid_colour, lwd = 1.5)
    )
    grid::grid.points(
      x = native(map_x(intercept)), y = native(y),
      pch = 21, size = grid::unit(3.0, "mm"),
      gp = grid::gpar(fill = "white", col = muted_colour, lwd = 1.4)
    )
    draw_text(
      intercept_label, map_x(intercept), y + 0.033,
      colour = muted_colour, fontsize = 11.7
    )

    # Offset the two contributions vertically so their labels remain legible.
    grid::grid.segments(
      x0 = native(map_x(intercept)), x1 = native(map_x(intercept)),
      y0 = native(y), y1 = native(actor_y),
      gp = grid::gpar(col = border_colour, lwd = 1)
    )
    grid::grid.segments(
      x0 = native(map_x(intercept)), x1 = native(map_x(after_actor)),
      y0 = native(actor_y), y1 = native(actor_y),
      arrow = arrow_head,
      gp = grid::gpar(col = actor_colour, fill = actor_colour, lwd = 2.6)
    )
    draw_text(
      actor_label,
      (map_x(intercept) + map_x(after_actor)) / 2,
      actor_y - 0.032,
      colour = actor_colour, fontsize = 11.7, fontface = "bold"
    )

    grid::grid.segments(
      x0 = native(map_x(after_actor)), x1 = native(map_x(after_actor)),
      y0 = native(actor_y), y1 = native(partner_y),
      gp = grid::gpar(col = border_colour, lwd = 1)
    )
    grid::grid.segments(
      x0 = native(map_x(after_actor)), x1 = native(map_x(prediction)),
      y0 = native(partner_y), y1 = native(partner_y),
      arrow = arrow_head,
      gp = grid::gpar(
        col = partner_colour, fill = partner_colour, lwd = 2.6
      )
    )
    draw_text(
      partner_label,
      (map_x(after_actor) + map_x(prediction)) / 2,
      partner_y - 0.032,
      colour = partner_colour, fontsize = 11.7, fontface = "bold"
    )
    grid::grid.segments(
      x0 = native(map_x(prediction)), x1 = native(map_x(prediction)),
      y0 = native(partner_y), y1 = native(y),
      gp = grid::gpar(col = border_colour, lwd = 1)
    )

    # Other outcomes sit on the prediction line; one residual is expanded.
    other_values <- residual_values[-example_i]
    grid::grid.points(
      x = native(prediction_x + other_values * residual_scale),
      y = native(rep(y, length(other_values))),
      pch = 16, size = grid::unit(1.45, "mm"),
      gp = grid::gpar(col = residual_colour, alpha = 0.82)
    )
    grid::grid.segments(
      x0 = native(prediction_x), x1 = native(example_x),
      y0 = native(residual_y), y1 = native(residual_y),
      arrow = grid::arrow(
        angle = 25, length = grid::unit(0.075, "inches"), type = "closed"
      ),
      gp = grid::gpar(
        col = residual_colour, fill = residual_colour, lwd = 1.8
      )
    )
    grid::grid.points(
      x = native(example_x), y = native(y),
      pch = 16, size = grid::unit(1.8, "mm"),
      gp = grid::gpar(col = residual_colour)
    )
    draw_text(
      expression(epsilon),
      (prediction_x + example_x) / 2, residual_y + 0.027,
      colour = residual_colour, fontsize = 12.3, fontface = "bold"
    )
    draw_text(
      sd_label, panel_right, y + 0.075,
      colour = residual_colour, fontsize = 11.8,
      fontface = "bold", just = "right"
    )

    # Draw the fitted value last so residual dots never obscure it.
    grid::grid.points(
      x = native(prediction_x), y = native(y),
      pch = 21, size = grid::unit(4.2, "mm"),
      gp = grid::gpar(fill = "white", col = ink_colour, lwd = 2.0)
    )
    draw_text(
      prediction_label, prediction_x, y - 0.030,
      colour = ink_colour, fontsize = 12.0, fontface = "bold"
    )
  }

  grid::grid.newpage()
  grid::pushViewport(grid::viewport(xscale = c(0, 1), yscale = c(0, 1)))
  grid::grid.rect(gp = grid::gpar(fill = "white", col = NA))

  draw_panel(0.255)
  draw_panel(0.745)

  # Panel headings and symmetric equations.
  draw_text(
    "Distinguishable APIM", 0.255, 0.935,
    fontsize = 18.0, fontface = "bold"
  )
  draw_text(
    "Role-specific parameters", 0.255, 0.897,
    colour = muted_colour, fontsize = 12.5
  )
  draw_text(
    "Exchangeable APIM", 0.745, 0.935,
    fontsize = 18.0, fontface = "bold"
  )
  draw_text(
    "Shared parameters are refitted—not averaged", 0.745, 0.897,
    colour = muted_colour, fontsize = 12.5
  )

  draw_coloured_equation(
    list(
      expression(hat(Y)[plain(F)] ~~ "="),
      expression(b[0 * "," * plain(F)]),
      expression(+a[plain(F)] * X[plain(F)]),
      expression(+p[plain(F)] * X[plain(M)])
    ),
    c(ink_colour, muted_colour, actor_colour, partner_colour),
    0.255, 0.837, fontsize = 15.2
  )
  draw_coloured_equation(
    list(
      expression(hat(Y)[plain(M)] ~~ "="),
      expression(b[0 * "," * plain(M)]),
      expression(+a[plain(M)] * X[plain(M)]),
      expression(+p[plain(M)] * X[plain(F)])
    ),
    c(ink_colour, muted_colour, actor_colour, partner_colour),
    0.255, 0.775, fontsize = 15.2
  )
  draw_coloured_equation(
    list(
      expression(hat(Y)[1] ~~ "="),
      expression(b[0]),
      expression(+a * X[1]),
      expression(+p * X[2])
    ),
    c(ink_colour, muted_colour, actor_colour, partner_colour),
    0.745, 0.837, fontsize = 15.2
  )
  draw_coloured_equation(
    list(
      expression(hat(Y)[2] ~~ "="),
      expression(b[0]),
      expression(+a * X[2]),
      expression(+p * X[1])
    ),
    c(ink_colour, muted_colour, actor_colour, partner_colour),
    0.745, 0.775, fontsize = 15.2
  )

  draw_text(
    expression("Illustrative example:" ~~ X[plain(F)] == +1 ~~ "," ~~
      X[plain(M)] == +1),
    0.255, 0.708, colour = muted_colour, fontsize = 12.0
  )
  draw_text(
    expression("Illustrative example:" ~~ X[1] == +1 ~~ "," ~~
      X[2] == +1),
    0.745, 0.708, colour = muted_colour, fontsize = 12.0
  )

  draw_divider(0.04, 0.47, 0.675)
  draw_divider(0.53, 0.96, 0.675)
  draw_text(
    "Predictions and residual variation", 0.255, 0.642,
    fontsize = 13.5, fontface = "bold"
  )
  draw_text(
    "Predictions and residual variation", 0.745, 0.642,
    fontsize = 13.5, fontface = "bold"
  )
  draw_text(
    expression(sigma[plain(F)] ~~ "and" ~~ sigma[plain(M)] ~~
      "estimated separately"),
    0.255, 0.603, colour = muted_colour, fontsize = 11.8
  )
  draw_text(
    expression(sigma[1] == sigma[2] ~~ "=" ~~ sigma),
    0.745, 0.603, colour = muted_colour, fontsize = 12.2
  )

  draw_prediction_row(
    "Female", 0.485,
    intercept = 8, actor_change = 2, partner_change = 1,
    domain = c(7, 13), panel_left = 0.095, panel_right = 0.455,
    intercept_label = expression(b[0 * "," * plain(F)] == 8),
    actor_label = expression(a[plain(F)] * X[plain(F)] == +2),
    partner_label = expression(p[plain(F)] * X[plain(M)] == +1),
    prediction_label = expression(hat(Y)[plain(F)] == 11),
    residual_values = c(-0.55, -0.34, -0.18, 0.08, 0.24, 0.39, 0.58),
    residual_colour = female_colour,
    sd_label = expression(sigma[plain(F)] == 0.5),
    residual_envelope = 0.5
  )
  draw_prediction_row(
    "Male", 0.200,
    intercept = 9, actor_change = 0.5, partner_change = 2,
    domain = c(7, 13), panel_left = 0.095, panel_right = 0.455,
    intercept_label = expression(b[0 * "," * plain(M)] == 9),
    actor_label = expression(a[plain(M)] * X[plain(M)] == +0.5),
    partner_label = expression(p[plain(M)] * X[plain(F)] == +2),
    prediction_label = expression(hat(Y)[plain(M)] == 11.5),
    residual_values = c(-1.55, -1.08, -0.62, 0.22, 0.74, 1.16, 1.48),
    residual_colour = male_colour,
    sd_label = expression(sigma[plain(M)] == 1.5),
    residual_envelope = 1.5
  )

  draw_prediction_row(
    "Member 1", 0.485,
    intercept = 9, actor_change = 1.5, partner_change = 1,
    domain = c(7, 13), panel_left = 0.585, panel_right = 0.945,
    intercept_label = expression(b[0] == 9),
    actor_label = expression(a * X[1] == +1.5),
    partner_label = expression(p * X[2] == +1),
    prediction_label = expression(hat(Y)[1] == 11.5),
    residual_values = c(-1.14, -0.71, -0.33, 0.12, 0.48, 0.82, 1.06),
    residual_colour = shared_colour,
    sd_label = expression(sigma),
    residual_envelope = 1
  )
  draw_prediction_row(
    "Member 2", 0.200,
    intercept = 9, actor_change = 1.5, partner_change = 1,
    domain = c(7, 13), panel_left = 0.585, panel_right = 0.945,
    intercept_label = expression(b[0] == 9),
    actor_label = expression(a * X[2] == +1.5),
    partner_label = expression(p * X[1] == +1),
    prediction_label = expression(hat(Y)[2] == 11.5),
    residual_values = c(-1.02, -0.78, -0.26, 0.18, 0.43, 0.76, 1.17),
    residual_colour = shared_colour,
    sd_label = expression(sigma),
    residual_envelope = 1
  )

  draw_text(
    expression(
      "Symmetry constraints do not imply identical predictions or residuals; " *
        rho * " remains estimated."
    ),
    0.5, 0.017, colour = muted_colour, fontsize = 10.4
  )

  grid::popViewport()
  invisible(NULL)
}
