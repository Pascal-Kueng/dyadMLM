#' Check outcome distributions against model simulations
#'
#' `r lifecycle::badge("experimental")`
#' Compare observed outcomes with complete datasets from
#' [simulate_dyad_responses()].
#' For PIT residual patterns, use [check_dyad_residuals()].
#'
#' @param simulations An object from [simulate_dyad_responses()]. Use 1,000 or
#'   more simulated datasets for stable comparisons.
#' @inheritParams check_dyad_residuals
#'
#' @return Invisibly returns a `dyadMLM_outcome_check` list containing compositions,
#'   role-specific summary matrices, and outcome distributions. Matrix columns
#'   are observed data followed by simulations. Save it with `plot = FALSE` and
#'   draw it later with `plot(result)`.
#'
#' @section Reading the plots:
#' Compositions and role columns are arranged as in [check_dyad_residuals()].
#'
#' The first row compares outcome distributions. Ordinal responses use bars for
#' all defined categories, with separate 95% ranges per category, so one red
#' point outside can occur by chance. Other outcomes show the proportion at or
#' below each value (ECDF) for the observations and up to 30 simulated datasets.
#'
#' The remaining rows compare the SD (standard deviation) of outcome minus
#' prediction, the largest absolute deviation from prediction, and zero counts
#' when the composition has simulated zeros, or observed zeros for count and
#' Tweedie families. The SD includes random effects; it does not isolate the
#' model's residual variance or dispersion parameter. For complete
#' cross-sectional dyads with distinct roles, these SDs match the default role
#' SDs in [check_partner_dependence()]. Ordinal summaries depend on the category
#' scores. Use a tall plotting window to keep all rows readable.
#'
#' @inheritSection check_dyad_residuals Reading flags
#' @inheritSection check_dyad_residuals Scope
#'
#' @seealso [check_dyad_residuals()], [check_partner_dependence()]
#' @examplesIf requireNamespace("glmmTMB", quietly = TRUE)
#' model <- glmmTMB::glmmTMB(
#'   closeness ~ gender + (1 | coupleID), data = dyads_cross
#' )
#' # Use at least 1,000 simulations when checking a model.
#' simulations <- simulate_dyad_responses(model, nsim = 100, seed = 123)
#' check_dyad_outcomes(simulations, dyad = coupleID, role = gender, ask = FALSE)
#' @export
check_dyad_outcomes <- function(simulations, dyad = NULL, role = NULL, member = NULL,
                                plot = TRUE, ask = NULL,
                                panels = TRUE, data = NULL) {
  if (!inherits(simulations, "dyadMLM_response_simulations"))
    stop("`simulations` must be created by `simulate_dyad_responses()`.", call. = FALSE)
  frame <- simulations$model_frame
  compositions <- build_check_groups(
    frame, rlang::enquo(dyad), rlang::enquo(role), rlang::enquo(member), data
  )
  # Keep each complete dataset in a column, with the observed data first.
  responses <- cbind(observed = simulations$observed_response,
                     t(simulations$simulated_responses))
  centred <- sweep(responses, 1, simulations$predicted_response, "-")
  family <- attr(simulations, "dyadMLM")$family
  # Other families only count zeros their simulations produce; otherwise an
  # observed 0 on a rating scale would always look like excess zeros.
  zero_columns <- if (grepl("pois|nbinom|bell|tweedie", family)) TRUE else -1
  # Ordinal scores are category positions 1, ..., K.
  category_labels <- if (identical(family, "ordinal"))
    if (is.factor(frame[[1]])) levels(frame[[1]]) else seq_len(max(responses))
  compositions <- lapply(compositions, function(composition) {
    composition_rows <- unlist(composition$rows, use.names = FALSE)
    include_zeros <- any(responses[composition_rows, zero_columns] == 0)
    composition$statistics <- lapply(composition$rows, function(rows) {
      if (!length(rows)) return(NULL)
      statistics <- rbind(
        `Response SD` = apply(centred[rows, , drop = FALSE], 2, stats::sd),
        `Largest absolute deviation` = apply(abs(centred[rows, , drop = FALSE]), 2, max)
      )
      if (include_zeros) statistics <- rbind(statistics,
        `Number of zeros` = colSums(responses[rows, , drop = FALSE] == 0))
      statistics
    })
    # Store plain plotting data, so the saved check needs no model or simulation object.
    composition$distribution <- list(
      # A few extreme simulated values should not squash the observed ECDF.
      limits = range(responses[composition_rows, 1], stats::quantile(
        responses[composition_rows, -1], c(.01, .99), names = FALSE)),
      labels = category_labels,
      roles = lapply(composition$rows, function(rows) {
        if (!length(rows)) return(NULL)
        values <- responses[rows, , drop = FALSE]
        if (!is.null(category_labels)) {
          frequencies <- apply(values, 2, tabulate, nbins = length(category_labels)) / nrow(values)
          bounds <- apply(frequencies[, -1, drop = FALSE], 1, simulated_rank_limits)
          bounds[] <- pmax(0, pmin(1, bounds))
          list(observed = frequencies[, 1],
               bounds = bounds, maximum = max(frequencies, bounds, .01))
        } else {
          lapply(seq_len(min(ncol(values), 31)), function(dataset) {
            empirical <- stats::ecdf(values[, dataset])
            knots <- stats::knots(empirical)
            list(x = knots, y = empirical(knots))
          })
        }
      }))
    composition
  })
  result <- structure(list(compositions = compositions), class = c("dyadMLM_outcome_check", "list"))
  attr(result, "dyadMLM") <- attr(simulations, "dyadMLM")
  if (missing(role)) message_pooled_roles()
  if (plot) graphics::plot(result, ask = ask, panels = panels)
  invisible(result)
}

#' @export
print.dyadMLM_outcome_check <- function(x, ...) print_check_overview(x, "outcome check")

#' @export
plot.dyadMLM_outcome_check <- function(x, ask = NULL, panels = TRUE, ...) {
  checks <- lapply(x$compositions, function(composition)
    c("distribution", unique(unlist(lapply(composition$statistics, rownames)))))
  number_of_figures <- if (panels) length(x$compositions) else
    sum(lengths(checks) * vapply(x$compositions, function(composition) length(composition$rows), integer(1)))
  local_check_paging(ask, panels, number_of_figures)
  for (i in seq_along(x$compositions)) {
    composition <- x$compositions[[i]]
    draw <- function(check, role) {
      if (!length(composition$rows[[role]])) return(plot_check_empty(
        if (check == "distribution") "Outcomes" else check))
      if (check == "distribution") {
        plot_outcome_distribution(composition$distribution, role)
      } else {
        plot_check_statistic(composition$statistics[[role]][check, ], switch(check,
          "Response SD" = "Response SD\n(after subtracting predictions)",
          "Largest absolute deviation" = "Largest absolute deviation\n(biggest gap from prediction)",
          "Number of zeros\n(excess or missing zeros)"),
          xlab = switch(check,
            "Response SD" = "SD of outcome minus prediction",
            "Largest absolute deviation" = "Absolute difference from prediction",
            "Number of observations"), counts = check == "Number of zeros",
          sub = paste("Red should usually lie between the dashed limits.", switch(check,
            "Response SD" = "Beyond right: more remaining variation; left: less.",
            "Largest absolute deviation" = "Beyond right: a bigger gap than the model usually produces.",
            "Beyond right: more zeros than predicted; left: fewer."), sep = "\n"))
      }
    }
    plot_check_role_panels(composition, checks[[i]], "Outcome checks", draw, panels)
  }
  invisible(x)
}

plot_outcome_distribution <- function(distribution, role) {
  values <- distribution$roles[[role]]
  if (!is.null(distribution$labels)) {
    positions <- graphics::barplot(values$observed, names.arg = distribution$labels,
      col = check_colours$observed_fill, border = check_colours$observed,
      ylim = c(0, values$maximum), main = "Outcome frequencies\n(category proportions)",
      xlab = "Outcome", ylab = "Proportion")
    graphics::segments(positions, values$bounds[1, ], positions, values$bounds[2, ],
                       col = check_colours$simulated, lwd = 3)
    graphics::points(positions, values$observed, col = check_colours$observed, pch = 16, cex = .65)
    plot_check_caption(paste("Red points should usually lie within their blue 95% ranges;",
      "with several categories, one outside can occur by chance.",
      "Above: more observations in that category; below: fewer.", sep = "\n"))
  } else {
    graphics::plot(distribution$limits, c(0, 1), type = "n", main = "Outcome ECDF\n(distribution shape)",
      xlab = "Outcome", ylab = "Cumulative proportion")
    # One step path retains every ECDF jump while keeping vector exports small.
    draw_ecdf <- function(path, ...) {
      graphics::lines(c(graphics::par("usr")[1], path$x, graphics::par("usr")[2]),
                      c(0, path$y, 1), type = "s", ...)
    }
    for (dataset in 2:length(values)) draw_ecdf(values[[dataset]], col = check_colours$simulated)
    draw_ecdf(values[[1]], col = check_colours$observed, lwd = 2)
    graphics::abline(h = c(0, 1), col = check_colours$reference, lty = 2)
    plot_check_caption(paste("The red curve should run among the blue curves.",
      "Long stretches outside suggest a distribution mismatch.", sep = "\n"))
  }
}
