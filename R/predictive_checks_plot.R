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
