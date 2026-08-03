draw_truth_bias_diagram <- function(result = NULL) {
  bias_colour <- .interdep_diagram_colours$actor
  truth_colour <- .interdep_diagram_colours$partner
  ink_colour <- "#263238"
  muted_colour <- "#64748B"
  node_fill <- "#F8FAFC"
  sans_family <- "Liberation Sans"

  fitted <- !is.null(result)
  if (fitted) {
    if (!inherits(result, "workshop_truth_bias")) {
      stop(
        "`result` must be returned by `fit_truth_bias()`.",
        call. = FALSE
      )
    }

    required_estimates <- c(
      "intercept_female", "intercept_male",
      "bias_female", "bias_male", "truth_female", "truth_male"
    )
    required_residuals <- c("sd_female", "sd_male", "correlation")
    required_similarity <- c("estimate", "p_value")

    if (
      !all(required_estimates %in% names(result$estimates)) ||
      !all(required_estimates %in% names(result$p_values)) ||
      !all(required_residuals %in% names(result$residuals)) ||
      !all(required_similarity %in% names(result$actual_similarity))
    ) {
      stop("The fitted Truth and Bias result is incomplete.", call. = FALSE)
    }
  }

  estimate_label <- function(label, value, p_value = NULL) {
    # Avoid displaying a tiny negative estimate as "-0.00" at two decimals.
    if (is.finite(value) && abs(value) < 0.005) {
      value <- 0
    }
    .diagram_estimate_label(label, value, p_value)
  }

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
      width = native(if (fitted) 0.16 else 0.09),
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

  if (fitted) {
    intercept_labels <- list(
      female = estimate_label(
        expression(b[0 * "," * plain(F)]),
        result$estimates[["intercept_female"]],
        result$p_values[["intercept_female"]]
      ),
      male = estimate_label(
        expression(b[0 * "," * plain(M)]),
        result$estimates[["intercept_male"]],
        result$p_values[["intercept_male"]]
      )
    )
    bias_labels <- list(
      female = estimate_label(
        expression(b[plain(F)]),
        result$estimates[["bias_female"]],
        result$p_values[["bias_female"]]
      ),
      male = estimate_label(
        expression(b[plain(M)]),
        result$estimates[["bias_male"]],
        result$p_values[["bias_male"]]
      )
    )
    truth_labels <- list(
      female = estimate_label(
        expression(italic(t)[plain(F)]),
        result$estimates[["truth_female"]],
        result$p_values[["truth_female"]]
      ),
      male = estimate_label(
        expression(italic(t)[plain(M)]),
        result$estimates[["truth_male"]],
        result$p_values[["truth_male"]]
      )
    )
    residual_labels <- list(
      female = estimate_label(
        expression(sigma[epsilon[plain(F)]]),
        result$residuals[["sd_female"]]
      ),
      male = estimate_label(
        expression(sigma[epsilon[plain(M)]]),
        result$residuals[["sd_male"]]
      ),
      correlation = estimate_label(
        expression(rho[epsilon[plain(F)] * epsilon[plain(M)]]),
        result$residuals[["correlation"]]
      )
    )
    actual_similarity_label <- estimate_label(
      expression(r[italic(P)[plain(F)] * "," * italic(P)[plain(M)]]),
      result$actual_similarity[["estimate"]],
      result$actual_similarity[["p_value"]]
    )
  } else {
    intercept_labels <- list(
      female = expression(b[0 * "," * plain(F)]),
      male = expression(b[0 * "," * plain(M)])
    )
    bias_labels <- list(
      female = expression(b[plain(F)]),
      male = expression(b[plain(M)])
    )
    truth_labels <- list(
      female = expression(italic(t)[plain(F)]),
      male = expression(italic(t)[plain(M)])
    )
    residual_labels <- list(
      female = expression(sigma[epsilon[plain(F)]]),
      male = expression(sigma[epsilon[plain(M)]]),
      correlation = expression(
        rho[epsilon[plain(F)] * epsilon[plain(M)]]
      )
    )
    actual_similarity_label <- "Actual similarity"
  }

  # Each provided-support report is the truth criterion for the partner's
  # received-support judgment and the assumed-similarity variable for the
  # person's own received-support judgment.
  draw_node(
    0.17, 0.72, expression(italic(P)[plain(F)]),
    "Female report:\nsupport provided"
  )
  draw_node(
    0.17, 0.28, expression(italic(P)[plain(M)]),
    "Male report:\nsupport provided"
  )
  draw_node(
    0.64, 0.72, expression(italic(J)[plain(F)]),
    "Female report:\nsupport received"
  )
  draw_node(
    0.64, 0.28, expression(italic(J)[plain(M)]),
    "Male report:\nsupport received"
  )

  draw_intercept(0.64, 0.86, intercept_labels$female)
  draw_intercept(0.64, 0.14, intercept_labels$male)

  draw_residual(0.91, 0.72, expression(epsilon[plain(F)]))
  draw_residual(0.91, 0.28, expression(epsilon[plain(M)]))

  # Same-perceiver (actor) paths are assumed-similarity bias forces.
  draw_path(0.295, 0.72, 0.507, 0.72, bias_colour)
  draw_path(0.295, 0.28, 0.507, 0.28, bias_colour)
  draw_path_label(0.405, 0.72, bias_labels$female, bias_colour)
  draw_path_label(0.405, 0.28, bias_labels$male, bias_colour)

  # Cross-partner (partner) paths are truth forces, or direct accuracy.
  draw_path(0.295, 0.72, 0.507, 0.34, truth_colour)
  draw_path(0.295, 0.28, 0.507, 0.66, truth_colour)
  draw_path_label(0.38, 0.56, truth_labels$male, truth_colour)
  draw_path_label(0.38, 0.44, truth_labels$female, truth_colour)

  # Unexplained judgments can remain interdependent.
  draw_path(
    0.855, 0.72, 0.768 + .diagram_arrow_clearance, 0.72, muted_colour
  )
  draw_path(
    0.855, 0.28, 0.768 + .diagram_arrow_clearance, 0.28, muted_colour
  )
  draw_covariance(
    0.947, 0.68, 0.947, 0.32, curvature = -0.24,
    residual_labels$correlation,
    label_x = 0.90, label_y = 0.50
  )
  .draw_residual_annotation(
    residual_labels$female, 0.91, 0.84, fontsize = 14
  )
  .draw_residual_annotation(
    residual_labels$male, 0.91, 0.16, fontsize = 14
  )

  # Correlated provided-support reports represent actual similarity, which
  # lets assumed similarity contribute indirectly to accuracy.
  draw_covariance(
    0.035, 0.66, 0.035, 0.34, curvature = 0.24,
    actual_similarity_label, label_x = 0.11,
    label_y = if (fitted) 0.485 else 0.50,
    fontsize = if (fitted) 12.5 else 10.7
  )
  if (fitted) {
    draw_text(
      "Actual similarity", 0.11, 0.555,
      colour = muted_colour, fontsize = 10.7
    )
  }

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
  .draw_diagram_significance_key(
    if (fitted) c(result$p_values, result$actual_similarity[["p_value"]])
    else NULL,
    y = 0.022,
    x = 0.405
  )

  grid::popViewport()
  invisible(NULL)
}
