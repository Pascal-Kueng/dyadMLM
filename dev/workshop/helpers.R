plot_mahalanobis <- function(data, x, y, dyad = "couple_id",
                             n_labels = 4, title = NULL) {
  required_columns <- c(x, y, dyad)
  missing_columns <- setdiff(required_columns, names(data))

  if (length(missing_columns) > 0) {
    stop(
      "Missing columns: ", paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }

  plot_data <- data[stats::complete.cases(data[required_columns]), , drop = FALSE]
  xy <- plot_data[c(x, y)]

  if (!all(vapply(xy, is.numeric, logical(1)))) {
    stop("Both x and y must be numeric.", call. = FALSE)
  }

  if (nrow(plot_data) < 3 || qr(stats::cov(xy))$rank < 2) {
    stop(
      "Mahalanobis distance requires at least three complete, non-collinear observations.",
      call. = FALSE
    )
  }

  plot_data$.mahalanobis_distance <- stats::mahalanobis(
    xy,
    center = colMeans(xy),
    cov = stats::cov(xy)
  )

  label_order <- order(
    plot_data$.mahalanobis_distance,
    decreasing = TRUE
  )
  label_order <- head(label_order, n_labels)
  label_data <- plot_data[label_order, , drop = FALSE]

  ggplot2::ggplot(
    plot_data,
    ggplot2::aes(x = .data[[x]], y = .data[[y]])
  ) +
    ggplot2::geom_point(color = "steelblue") +
    ggplot2::geom_smooth(
      method = "lm",
      formula = y ~ x,
      se = FALSE,
      color = "navy",
      linewidth = 1.1
    ) +
    ggplot2::geom_text(
      data = label_data,
      ggplot2::aes(label = .data[[dyad]]),
      vjust = -0.6,
      check_overlap = TRUE
    ) +
    ggplot2::labs(
      title = title,
      x = x,
      y = y,
      caption = paste(
        "Labels mark the",
        min(n_labels, nrow(plot_data)),
        "largest Mahalanobis distances."
      )
    ) +
    ggplot2::scale_y_continuous(
      expand = ggplot2::expansion(mult = c(0.05, 0.12))
    ) +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(
      plot.title.position = "panel",
      plot.title = ggplot2::element_text(hjust = 0.5)
    )
}
