draw_dyadic_response_surface <- function(result) {
  if (!inherits(result, "workshop_drsa")) {
    stop("`result` must come from `fit_dyadic_response_surface()`.")
  }

  # The model is fitted in long format. For plotting, place both outcomes on
  # one row per couple while retaining the fixed female and male support axes.
  plot_data <- result$data |>
    dplyr::select(
      couple_id, role, total_mvpa,
      female_support_c, male_support_c
    ) |>
    tidyr::pivot_wider(
      id_cols = c(couple_id, female_support_c, male_support_c),
      names_from = role,
      values_from = total_mvpa,
      names_glue = "{role}_mvpa"
    )

  # Use shared horizontal and vertical limits so the two surfaces are directly
  # comparable. The vertical limits cover both fitted polynomial surfaces.
  xy_range <- range(
    c(plot_data$female_support_c, plot_data$male_support_c),
    finite = TRUE
  )
  xy_padding <- 0.015 * diff(xy_range)
  xy_limit <- xy_range + c(-xy_padding, xy_padding)

  surface_value <- function(coefficients, x, y) {
    coefficients[["b0"]] +
      coefficients[["x"]] * x +
      coefficients[["y"]] * y +
      coefficients[["x2"]] * x^2 +
      coefficients[["xy"]] * x * y +
      coefficients[["y2"]] * y^2
  }

  plot_grid <- expand.grid(
    x = seq(xy_limit[1], xy_limit[2], length.out = 101),
    y = seq(xy_limit[1], xy_limit[2], length.out = 101)
  )
  grid_predictions <- unlist(lapply(
    result$surface_coefficients,
    \(coefficients) surface_value(
      coefficients, plot_grid$x, plot_grid$y
    )
  ))
  z_limit <- c(
    floor(min(0, grid_predictions) / 50) * 50,
    ceiling(max(grid_predictions) / 50) * 50
  )

  palette <- grDevices::colorRampPalette(
    c("#F8FAFC", "#BFE4EA", "#00A6B2", "#0028A5")
  )(24)

  axes_styles <- list(
    LOC = list(lty = "solid", lwd = 2, col = "#1769AA"),
    LOIC = list(lty = "dashed", lwd = 2, col = "#7B3FA1")
  )

  draw_partner_surface <- function(role) {
    coefficients <- result$surface_coefficients[[role]]
    outcome <- paste0(role, "_mvpa")

    RSA::plotRSA(
      x = coefficients[["x"]],
      y = coefficients[["y"]],
      x2 = coefficients[["x2"]],
      y2 = coefficients[["y2"]],
      xy = coefficients[["xy"]],
      b0 = coefficients[["b0"]],
      xlim = xy_limit,
      ylim = xy_limit,
      zlim = z_limit,
      xlab = "Female-provided emotional\nsupport (centered)",
      ylab = "Male-provided emotional\nsupport (centered)",
      zlab = "Predicted value",
      main = paste0(tools::toTitleCase(role), " total MVPA (min/day)"),
      legend = FALSE,
      param = FALSE,
      axes = c("LOC", "LOIC"),
      axesStyles = axes_styles,
      project = c("contour", "LOC", "LOIC", "points"),
      points = list(
        data = data.frame(
          plot_data$female_support_c,
          plot_data$male_support_c,
          plot_data[[outcome]]
        ),
        show = TRUE,
        value = "predicted",
        jitter = 0,
        color = "#20252B",
        cex = 0.38
      ),
      hull = TRUE,
      border = FALSE,
      gridsize = 23,
      pal = palette,
      pal.range = "box",
      distance = c(1.05, 1.05, 1.1),
      cex.tickLabel = 0.66,
      cex.axesLabel = 0.74,
      cex.main = 0.90,
      pad = 0.35
    )
  }

  plots <- lapply(c("female", "male"), draw_partner_surface)

  gridExtra::grid.arrange(
    grobs = plots,
    ncol = 2,
    padding = grid::unit(0.15, "line")
  )
}
