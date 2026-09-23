check_colours <- list(observed = "#a12b35", observed_fill = "#f2d3d6",
                      simulated = "#bcd7e8", simulation_line = "#7fa7be",
                      reference = "grey40")

plot_check_caption <- function(text) {
  graphics::mtext(text, side = 1, line = 4.8, cex = .875 * graphics::par("cex"))
}

plot_check_empty <- function(title, label = "No fitted observations") {
  graphics::plot.new()
  graphics::title(main = title)
  graphics::text(.5, .5, label)
}

# The first value is observed; the remaining values are simulated summaries.
plot_check_statistic <- function(values, title, xlab = "Summary value",
                                 counts = FALSE, sub = NULL, caption = TRUE, ...,
                                 col = check_colours$simulated, border = "white",
                                 ylab = "Simulated datasets", ylim = NULL,
                                 xaxt = if (counts) "n" else "s") {
  simulated <- values[-1]
  simulated <- simulated[is.finite(simulated)]
  if (!is.finite(values[1]) || !length(simulated))
    return(plot_check_empty(title, "Not enough observations or variation"))
  breaks <- if (counts && diff(range(simulated)) < 20)
    seq(min(simulated) - .5, max(simulated) + .5, by = 1) else 20
  histogram <- graphics::hist(simulated, breaks = breaks, plot = FALSE)
  if (!caption && is.null(ylim)) ylim <- c(0, max(histogram$counts) * 1.25)
  graphics::plot(histogram, freq = TRUE, xlim = range(values[1], histogram$breaks),
                  col = col, border = border, main = title, ylim = ylim,
                  sub = if (!caption) sub,
                  xlab = xlab, ylab = ylab, xaxt = xaxt, ...)
  if (counts) {
    ticks <- pretty(range(values, finite = TRUE))
    graphics::axis(1, ticks[ticks >= 0 & ticks %% 1 == 0])
  }
  graphics::abline(v = stats::quantile(simulated, c(.025, .975)),
                   lty = 2, col = check_colours$reference)
  graphics::abline(v = values[1], col = check_colours$observed, lwd = 2)
  if (caption) {
    guide <- "Compare the red value with the blue distribution.\nDashed lines mark its middle 95%."
    if (!is.null(sub)) guide <- paste(guide, sub)
    plot_check_caption(guide)
  } else graphics::legend("top", c("Observed", "Middle 95% of simulations"),
    lty = c(1, 2), lwd = c(2, 1), col = c(check_colours$observed, check_colours$reference),
    horiz = TRUE, bty = "n")
}

# Add the shared counts and role headings to a composition page.
plot_check_role_page <- function(composition, rows, title, draw) {
  role_rows <- composition$rows
  counts <- paste(sum(lengths(role_rows)), "observations")
  if (!is.null(composition$n_dyads)) counts <- paste(composition$n_dyads, "dyads;", counts)
  plot_check_page(composition$label, paste(title, counts, sep = " - "),
    c(rows, length(role_rows)), draw,
    column_titles = paste0(names(role_rows), " (n = ", lengths(role_rows), ")"),
    footer = "Red: observed. Blue: simulations; ranges are pointwise middle 95%. Some departures occur by chance.\nParameters fixed; no significance tests.")
}

# Draw one composition page. `draw` is evaluated inside the temporary layout;
# column headings are optional because not every check arranges panels by role.
plot_check_page <- function(composition, title, panels, draw,
                            column_titles = NULL, footer = NULL,
                            mar = c(6.8, 4.5, 2, .8)) {
  previous <- graphics::par(c("mfrow", "mar", "oma", "mgp", "cex", "mex",
                              "mfg", "las", "plt", "cex.main", "new"))
  on.exit({
    graphics::par(previous)
    # Layout restoration resets scaling, which also changes the plot region.
    graphics::par(previous[c("cex", "mex", "plt", "new")])
  }, add = TRUE)
  plot_scale <- min(1, grDevices::dev.size("in") / c(5 * panels[2], 3 * panels[1] + 1))
  heading_scale <- min(1, grDevices::dev.size("in")[1] / 8)
  graphics::par(mfrow = panels, mar = mar,
                mgp = c(2.5, .6, 0), cex = .8 * plot_scale, cex.main = 1.1, las = 1,
                new = FALSE)
  graphics::par(omi = c(if (is.null(footer)) 0 else .6, 0,
                        if (is.null(column_titles)) .75 else 1.15, 0) * heading_scale)
  force(draw)

  # Physical margins keep headings in place regardless of panel text scaling.
  # Only narrow devices or long labels reduce their size to fit the page.
  heading <- function(text, position, size, font = 1, side = 3) {
    size <- size * heading_scale
    size <- size * min(1, .95 * grDevices::dev.size("in")[1] / length(text) /
      max(graphics::strwidth(text, "inches", cex = size / graphics::par("cex"), font = font)))
    line <- (graphics::par("omi")[side] - position * heading_scale) /
      (graphics::par("csi") * graphics::par("mex"))
    graphics::mtext(text, outer = TRUE, side = side, line = line,
                    at = (seq_along(text) - .5) / length(text), cex = size, font = font,
                    padj = 0)
  }
  heading(composition, .3, 1.4, font = 2)
  heading(title, .58, .9)
  if (!is.null(column_titles)) heading(column_titles, .96, 1, font = 2)
  if (!is.null(footer)) heading(footer, .3, .75, side = 1)
  invisible(NULL)
}
