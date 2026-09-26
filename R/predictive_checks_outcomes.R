#' Check outcome distributions against model simulations
#'
#' `r lifecycle::badge("experimental")`
#' Compare observed outcomes with complete datasets from
#' [simulate_dyad_responses()]. Uses every simulated dataset directly.
#' For PIT residual patterns, use [check_residuals()].
#'
#' @param simulations An object from [simulate_dyad_responses()]. Use 1,000 or
#'   more simulated datasets for stable comparisons.
#' @inheritParams check_residuals
#' @param check_zeros Include zero counts? `NULL` (default) includes them for all
#'   roles in a composition if any observed or simulated outcome there is zero.
#'
#' @return Invisibly returns a `dyadMLM_outcome_check` list containing compositions,
#'   role-specific summary matrices, and outcome distributions. Matrix columns
#'   are observed data followed by simulations. Save it with `plot = FALSE` and
#'   draw it later with `plot(result)`. Graphics settings are restored afterwards.
#'
#' @section Reading the plots:
#' Each combination of partners' roles gets one pooled column for same-role
#' partners, or separate columns for distinct roles, as in [check_residuals()].
#' Roles define the display without changing the model's assumptions.
#' Every page repeats its composition heading. Available responses are retained
#' when the composition is known; unknown compositions are omitted with a warning.
#'
#' **Red shows observed data; blue shows simulations.** The first row compares
#' outcome distributions. Ordinal responses and counts with up to 20 distinct
#' observed or simulated values use category frequencies. Other outcomes show
#' the proportion at or below each outcome value, for the observations and up to
#' 30 simulated datasets.
#'
#' The remaining rows compare response variability (variance of outcome minus
#' prediction), the largest absolute deviation from prediction, and zero counts
#' where relevant. Each blue histogram shows simulated values; the red line shows
#' the observed value. A red line far to the right or left means more or less than
#' the model usually produces. Dashed lines mark the middle 95%.
#' Some departures occur by chance. Variance needs at least two observations.
#' Use a tall plotting window to keep all rows readable.
#'
#' @section Scope:
#' These are descriptive predictive checks, not significance tests. Complete
#' simulations retain fitted partner and time dependence and any modelled
#' differences in variability between roles. Parameters stay fixed;
#' the observed data were used to fit them, and parameter uncertainty is not included.
#'
#' Predictions have random effects set to zero; for nonlinear links they differ
#' from averages over random effects. Variability includes random effects; it does
#' not isolate the model's residual variance or dispersion parameter.
#' Ordinal summaries use category scores;
#' zero counts describe the combined response distribution for zero-inflated models.
#' Uses the families and fitted rows supported by [simulate_dyad_responses()]:
#' missing responses are not imputed, time gaps follow the fitted model, and
#' observations have equal weight. For cross-sectional data, check partner
#' correlations with [check_partner_dependence()].
#'
#' @seealso [check_residuals()], [check_partner_dependence()]
#' @examplesIf requireNamespace("glmmTMB", quietly = TRUE)
#' model <- glmmTMB::glmmTMB(
#'   closeness ~ gender + (1 | coupleID), data = dyads_cross
#' )
#' # Use at least 1,000 draws when checking a model.
#' simulations <- simulate_dyad_responses(model, nsim = 100, seed = 123)
#' check_outcomes(simulations, dyad = coupleID, role = gender, ask = FALSE)
#' @export
check_outcomes <- function(simulations, dyad = NULL, role = NULL, member = NULL,
                            check_zeros = NULL, plot = TRUE, ask = NULL,
                            panels = TRUE, data = NULL) {
  if (!inherits(simulations, "dyadMLM_response_simulations"))
    stop("`simulations` must be created by `simulate_dyad_responses()`.", call. = FALSE)
  if (!is.null(check_zeros) && !rlang::is_bool(check_zeros))
    stop("`check_zeros` must be NULL, TRUE, or FALSE.", call. = FALSE)
  frame <- simulations$model_frame
  compositions <- build_check_groups(
    frame, rlang::enquo(dyad), rlang::enquo(role), rlang::enquo(member), data
  )
  # Keep each complete dataset in a column, with the observed data first.
  responses <- cbind(observed = simulations$observed_response,
                     t(simulations$simulated_responses))
  centred <- sweep(responses, 1, simulations$predicted_response, "-")
  family <- attr(simulations, "dyadMLM")$family
  count_families <- c("poisson", "compois", "genpois", "bell", "nbinom1", "nbinom2", "nbinom12",
                     "truncated_poisson", "truncated_nbinom1", "truncated_nbinom2",
                     "truncated_compois", "truncated_genpois")
  compositions <- lapply(compositions, function(composition) {
    composition_rows <- unlist(composition$rows, use.names = FALSE)
    include_zeros <- if (is.null(check_zeros))
      any(responses[composition_rows, ] == 0) else check_zeros
    composition$statistics <- lapply(composition$rows, function(rows) {
      if (!length(rows)) return(NULL)
      statistics <- rbind(
        `Response variability` = apply(centred[rows, , drop = FALSE], 2, stats::var),
        `Largest absolute deviation` = apply(abs(centred[rows, , drop = FALSE]), 2, max)
      )
      if (include_zeros) statistics <- rbind(statistics,
        `Number of zeros` = colSums(responses[rows, , drop = FALSE] == 0))
      statistics
    })
    support <- category_labels <- NULL
    if (identical(family, "ordinal") && is.factor(frame[[1]])) {
      category_labels <- levels(frame[[1]])
      support <- seq_along(category_labels)
    } else if (family %in% c("ordinal", count_families)) {
      support <- sort(unique(as.vector(responses[composition_rows, ])))
      if (family != "ordinal" && length(support) > 20) support <- NULL
      category_labels <- support
    }
    # Store plain plotting data, so the saved check needs no model or simulation object.
    composition$distribution <- list(
      limits = range(responses[composition_rows, ]), labels = category_labels,
      roles = lapply(composition$rows, function(rows) {
        if (!length(rows)) return(NULL)
        values <- responses[rows, , drop = FALSE]
        if (!is.null(support)) {
          frequencies <- vapply(seq_len(ncol(values)), function(dataset)
            tabulate(match(values[, dataset], support), nbins = length(support)) / nrow(values),
            numeric(length(support)))
          frequencies <- matrix(frequencies, nrow = length(support))
          list(observed = frequencies[, 1],
               bounds = apply(frequencies[, -1, drop = FALSE], 1, stats::quantile, c(.025, .975)),
               maximum = max(frequencies, .01))
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
  if (missing(role)) message_pooled_roles()
  if (plot) graphics::plot(result, ask = ask, panels = panels)
  invisible(result)
}

#' @rdname print.dyadMLM_residual_check
#' @export
print.dyadMLM_outcome_check <- function(x, ...) print_check_overview(x, "outcome check")

#' Plot saved outcome checks
#'
#' @param x An object returned by [check_outcomes()].
#' @inheritParams check_residuals
#' @param ... Unused.
#' @return Invisibly returns `x`.
#' @keywords internal
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
          "Response variability" = "Response variance\n(variation after subtracting predictions)",
          "Largest absolute deviation" = "Largest absolute deviation\n(biggest gap from prediction)",
          "Number of zeros\n(excess or missing zeros)"),
          xlab = switch(check,
            "Response variability" = "Variance of outcome minus prediction",
            "Largest absolute deviation" = "Absolute difference from prediction",
            "Number of observations"), counts = check == "Number of zeros",
          sub = paste("Red should usually lie between the dashed limits.", switch(check,
            "Response variability" = "Beyond right: more remaining variation; left: less.",
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
    plot_check_caption(paste("Red proportions should usually lie within the blue ranges.",
      "Above: more observations in that category; below: fewer.", sep = "\n"))
  } else {
    graphics::plot(distribution$limits, c(0, 1), type = "n", main = "Outcome ECDF\n(distribution shape)",
      xlab = "Outcome", ylab = "Proportion at or below this value")
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
