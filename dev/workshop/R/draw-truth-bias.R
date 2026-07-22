draw_truth_bias_diagram <- function() {
  bias_colour <- .interdep_diagram_colours$actor
  truth_colour <- .interdep_diagram_colours$partner
  ink_colour <- "#263238"
  muted_colour <- "#64748B"
  node_fill <- "#F8FAFC"
  sans_family <- "Liberation Sans"

  native <- function(value) grid::unit(value, "native")
  arrow_head <- grid::arrow(
    angle = 28,
    length = grid::unit(0.15, "inches"),
    type = "closed"
  )
  covariance_arrow <- grid::arrow(
    angle = 26,
    length = grid::unit(0.10, "inches"),
    ends = "both",
    type = "closed"
  )

  draw_text <- function(
      label, x, y, colour = ink_colour, fontsize = 14,
      fontface = "plain", just = "centre") {
    is_math <- is.expression(label) || is.language(label)
    if (is_math) {
      label <- .diagram_math_label(label)
    }
    grid::grid.text(
      label,
      x = native(x),
      y = native(y),
      just = just,
      gp = grid::gpar(
        col = colour,
        fontsize = fontsize,
        fontface = fontface,
        fontfamily = if (is_math) "" else sans_family
      )
    )
  }

  draw_node <- function(x, y, symbol, description, width = 0.25) {
    description_size <- if (nchar(description) > 21L) 12.2 else 13.3
    grid::grid.roundrect(
      x = native(x),
      y = native(y),
      width = native(width),
      height = native(0.22),
      r = grid::unit(0.09, "snpc"),
      gp = grid::gpar(fill = node_fill, col = ink_colour, lwd = 1.8)
    )
    draw_text(
      description, x, y + 0.035,
      fontsize = description_size, fontface = "bold"
    )
    draw_text(symbol, x, y - 0.040, fontsize = 18)
  }

  draw_residual <- function(x, y, label) {
    grid::grid.circle(
      x = native(x),
      y = native(y),
      r = grid::unit(0.052, "snpc"),
      gp = grid::gpar(fill = "white", col = ink_colour, lwd = 1.8)
    )
    draw_text(label, x, y, fontsize = 17)
  }

  draw_path <- function(x0, y0, x1, y1, colour) {
    grid::grid.segments(
      x0 = native(x0),
      y0 = native(y0),
      x1 = native(x1),
      y1 = native(y1),
      arrow = arrow_head,
      gp = grid::gpar(col = colour, fill = colour, lwd = 2.2)
    )
  }

  draw_path_label <- function(x, y, label, colour) {
    label <- .diagram_math_label(label)
    label_grob <- grid::textGrob(
      label,
      x = native(x),
      y = native(y),
      gp = grid::gpar(col = colour, fontsize = 15)
    )
    grid::grid.roundrect(
      x = native(x),
      y = native(y),
      width = grid::grobWidth(label_grob) + grid::unit(2.5, "mm"),
      height = grid::grobHeight(label_grob) + grid::unit(1.5, "mm"),
      r = grid::unit(0.02, "snpc"),
      gp = grid::gpar(fill = "white", col = NA)
    )
    grid::grid.draw(label_grob)
  }

  draw_intercept <- function(x, y, label) {
    label <- .diagram_math_label(label)
    grid::grid.roundrect(
      x = native(x),
      y = native(y),
      width = native(0.09),
      height = native(0.065),
      r = grid::unit(0.02, "snpc"),
      gp = grid::gpar(fill = "white", col = muted_colour, lwd = 1)
    )
    draw_text(label, x, y, colour = muted_colour, fontsize = 14)
  }

  draw_covariance <- function(
      x1, y1, x2, y2, curvature, label, label_x, label_y,
      fontsize = 14) {
    grid::grid.curve(
      x1 = native(x1),
      y1 = native(y1),
      x2 = native(x2),
      y2 = native(y2),
      curvature = curvature,
      angle = 90,
      ncp = 12,
      square = FALSE,
      arrow = covariance_arrow,
      gp = grid::gpar(
        col = muted_colour,
        fill = muted_colour,
        lwd = 1.8
      )
    )
    .draw_residual_annotation(
      label, label_x, label_y,
      fontsize = fontsize, colour = muted_colour
    )
  }

  grid::grid.newpage()
  grid::pushViewport(grid::viewport(xscale = c(0, 1), yscale = c(0, 1)))
  grid::grid.rect(gp = grid::gpar(fill = "white", col = NA))

  # Each self-report is the truth criterion for the partner's judgment and
  # the assumed-similarity bias variable for the person's own judgment.
  draw_node(0.17, 0.72, expression(italic(S)[plain(F)]), "Female self-report")
  draw_node(0.17, 0.28, expression(italic(S)[plain(M)]), "Male self-report")
  draw_node(
    0.64, 0.72, expression(italic(J)[plain("F→M")]),
    "Female’s judgment of male"
  )
  draw_node(
    0.64, 0.28, expression(italic(J)[plain("M→F")]),
    "Male’s judgment of female"
  )

  draw_intercept(0.64, 0.86, expression(b[0 * "," * plain(F)]))
  draw_intercept(0.64, 0.14, expression(b[0 * "," * plain(M)]))

  draw_residual(0.91, 0.72, expression(epsilon[plain(F)]))
  draw_residual(0.91, 0.28, expression(epsilon[plain(M)]))

  # Same-perceiver (actor) paths are assumed-similarity bias forces.
  draw_path(0.295, 0.72, 0.507, 0.72, bias_colour)
  draw_path(0.295, 0.28, 0.507, 0.28, bias_colour)
  draw_path_label(0.405, 0.72, expression(b[plain(F)]), bias_colour)
  draw_path_label(0.405, 0.28, expression(b[plain(M)]), bias_colour)

  # Cross-partner (partner) paths are truth forces, or direct accuracy.
  draw_path(0.295, 0.72, 0.507, 0.34, truth_colour)
  draw_path(0.295, 0.28, 0.507, 0.66, truth_colour)
  draw_path_label(0.38, 0.56, expression(italic(t)[plain(M)]), truth_colour)
  draw_path_label(0.38, 0.44, expression(italic(t)[plain(F)]), truth_colour)

  # Unexplained judgments can remain interdependent.
  draw_path(
    0.855, 0.72, 0.768 + .diagram_arrow_clearance, 0.72, muted_colour
  )
  draw_path(
    0.855, 0.28, 0.768 + .diagram_arrow_clearance, 0.28, muted_colour
  )
  draw_covariance(
    0.947, 0.68, 0.947, 0.32, curvature = -0.24,
    expression(rho[epsilon[plain(F)] * epsilon[plain(M)]]),
    label_x = 0.90, label_y = 0.50
  )
  .draw_residual_annotation(
    expression(sigma[epsilon[plain(F)]]), 0.91, 0.84, fontsize = 14
  )
  .draw_residual_annotation(
    expression(sigma[epsilon[plain(M)]]), 0.91, 0.16, fontsize = 14
  )

  # Correlated self-reports represent actual similarity, which lets assumed
  # similarity contribute indirectly to accuracy.
  draw_covariance(
    0.035, 0.66, 0.035, 0.34, curvature = 0.24,
    "Actual similarity", label_x = 0.11, label_y = 0.50,
    fontsize = 10.7
  )

  .draw_diagram_legend(
    labels = c(
      "Assumed similarity (bias force)",
      "Direct accuracy (truth force)"
    ),
    colours = c(bias_colour, truth_colour),
    y = 0.077,
    segment_starts = c(0.10, 0.52),
    text_x = c(0.29, 0.70),
    fontsize = 11.5
  )

  grid::popViewport()
  invisible(NULL)
}
