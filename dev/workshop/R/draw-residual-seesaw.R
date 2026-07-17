draw_residual_seesaw <- function(model = c("dim", "dsm")) {
  model <- match.arg(model)

  ink <- "#263238"
  muted <- "#64748B"
  border <- "#CBD5E1"
  grid_colour <- "#E2E8F0"
  surface <- "#F8FAFC"
  female <- "#004D40"
  male <- "#00A6B2"
  male_text <- "#007486"
  accent_fill <- "#E7F3F3"
  sans <- "Liberation Sans"

  native <- function(value) grid::unit(value, "native")

  draw_text <- function(
      label, x, y, fontsize = 14, colour = ink,
      fontface = "plain", just = "centre") {
    grid::grid.text(
      label,
      x = native(x), y = native(y), just = just,
      gp = grid::gpar(
        col = colour, fontsize = fontsize,
        fontface = fontface, fontfamily = sans
      )
    )
  }

  draw_panel <- function(x, y, width, height) {
    grid::grid.roundrect(
      x = native(x), y = native(y),
      width = native(width), height = native(height),
      r = grid::unit(0.025, "snpc"),
      gp = grid::gpar(fill = surface, col = border, lwd = 1.4)
    )
  }

  draw_person <- function(x, y, colour, label = NULL, label_colour = colour) {
    grid::grid.circle(
      x = native(x), y = native(y + 0.043),
      r = grid::unit(0.019, "snpc"),
      gp = grid::gpar(fill = colour, col = "white", lwd = 1.2)
    )
    grid::grid.roundrect(
      x = native(x), y = native(y - 0.005),
      width = native(0.037), height = native(0.065),
      r = grid::unit(0.016, "snpc"),
      gp = grid::gpar(fill = colour, col = "white", lwd = 1.2)
    )
    if (!is.null(label)) {
      draw_text(
        label, x, y - 0.105,
        fontsize = 12.5, colour = label_colour, fontface = "bold"
      )
    }
  }

  draw_elevator <- function() {
    draw_panel(0.255, 0.715, 0.46, 0.49)
    draw_text("Elevator", 0.255, 0.905, fontsize = 19, fontface = "bold")
    draw_text(
      "Dyad mean residual", 0.255, 0.855,
      fontsize = 14.5, colour = muted
    )

    grid::grid.segments(
      x0 = native(c(0.105, 0.345)), x1 = native(c(0.105, 0.345)),
      y0 = native(0.525), y1 = native(0.805),
      gp = grid::gpar(col = grid_colour, lwd = 2.2)
    )
    grid::grid.roundrect(
      x = native(0.225), y = native(0.645),
      width = native(0.205), height = native(0.105),
      r = grid::unit(0.012, "snpc"),
      gp = grid::gpar(fill = "white", col = muted, lwd = 1.8)
    )
    draw_person(0.185, 0.665, female)
    draw_person(0.265, 0.665, male)

    grid::grid.segments(
      x0 = native(0.405), x1 = native(0.405),
      y0 = native(0.625), y1 = native(0.765),
      arrow = grid::arrow(
        ends = "both", type = "closed", angle = 25,
        length = grid::unit(0.10, "inches")
      ),
      gp = grid::gpar(col = muted, fill = muted, lwd = 2.4)
    )
    draw_text(
      "both move together", 0.225, 0.545,
      fontsize = 13.5, colour = ink, fontface = "bold"
    )
  }

  draw_seesaw <- function(labelled = FALSE) {
    if (labelled) {
      panel_x <- 0.30
      panel_width <- 0.56
      left <- 0.11
      right <- 0.49
      centre <- 0.30
      y_left <- 0.56
      y_right <- 0.72
    } else {
      panel_x <- 0.745
      panel_width <- 0.46
      left <- 0.575
      right <- 0.915
      centre <- 0.745
      y_left <- 0.61
      y_right <- 0.73
    }

    draw_panel(panel_x, 0.715, panel_width, 0.49)
    draw_text("Seesaw", panel_x, 0.905, fontsize = 19, fontface = "bold")
    draw_text(
      if (labelled) "Outcome difference residual" else
        "Within-dyad residual",
      panel_x, 0.855, fontsize = 14.5, colour = muted
    )

    grid::grid.polygon(
      x = native(c(centre - 0.045, centre + 0.045, centre)),
      y = native(c(
        mean(c(y_left, y_right)) - 0.09,
        mean(c(y_left, y_right)) - 0.09,
        mean(c(y_left, y_right))
      )),
      gp = grid::gpar(fill = border, col = muted, lwd = 1.3)
    )
    grid::grid.segments(
      x0 = native(left), y0 = native(y_left),
      x1 = native(right), y1 = native(y_right),
      gp = grid::gpar(col = muted, lwd = 5, lineend = "round")
    )
    grid::grid.segments(
      x0 = native(c(left, right)), x1 = native(c(left, right)),
      y0 = native(c(y_left - 0.02, y_right - 0.02)),
      y1 = native(c(y_left + 0.03, y_right + 0.03)),
      gp = grid::gpar(col = muted, lwd = 2.2)
    )

    draw_person(
      left, y_left + 0.055, female,
      if (labelled) "Female" else "Member 1", female
    )
    draw_person(
      right, y_right + 0.055, male,
      if (labelled) "Male" else "Member 2", male_text
    )

    if (!labelled) {
      draw_text(
        "one rises as the other falls", panel_x, 0.795,
        fontsize = 12.5, colour = ink, fontface = "bold"
      )
    }
  }

  grid::grid.newpage()
  grid::grid.rect(gp = grid::gpar(fill = "white", col = NA))
  grid::pushViewport(grid::viewport(xscale = c(0, 1), yscale = c(0.45, 1)))

  if (identical(model, "dim")) {
    draw_elevator()
    draw_seesaw(labelled = FALSE)
  } else {
    draw_seesaw(labelled = TRUE)

    draw_panel(0.78, 0.715, 0.38, 0.49)
    draw_text(
      "The direction is meaningful", 0.78, 0.895,
      fontsize = 18, fontface = "bold"
    )
    draw_text(
      "Female and male are", 0.78, 0.800,
      fontsize = 15, colour = ink, fontface = "bold"
    )
    draw_text(
      "substantive labels.", 0.78, 0.752,
      fontsize = 15, colour = ink, fontface = "bold"
    )
    draw_text(
      "Relabelling is no longer an", 0.78, 0.655,
      fontsize = 14, colour = muted
    )
    draw_text(
      "allowed symmetry of the model.", 0.78, 0.610,
      fontsize = 14, colour = muted
    )
  }

  grid::popViewport()
  invisible(NULL)
}
