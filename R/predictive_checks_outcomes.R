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
#' @param check_zeros Include zero counts? `NULL` (default) includes them wherever
#'   the observed or simulated group contains zeros.
#' @param centred_overlay Add an outcome overlay after subtracting the same
#'   model predictions from observed and simulated outcomes? Default: `FALSE`.
#'
#' @return One page per composition, plus an optional centred-outcome page.
#'   Invisibly returns a list of summary matrices, grouped by composition and
#'   role. Rows are statistics; columns are observed data followed by simulations.
#'   Graphics settings are restored afterwards.
#'
#' @section Reading the plots:
#' Each composition gets one pooled column for same-role partners, or separate
#' columns for distinct roles, as in [check_residuals()]. Every page repeats its
#' composition heading. Available responses are retained when the composition is
#' known; unknown compositions are omitted with a warning.
#'
#' **Red shows observed data; blue shows simulations.** The first row compares
#' outcome distributions. Ordinal responses and counts with up to 20 observed or
#' simulated values use category frequencies; other outcomes use cumulative
#' distributions from up to 30 simulated datasets.
#'
#' The remaining rows compare response variability (variance of outcome minus
#' prediction), the largest absolute deviation from prediction, and zero counts
#' where relevant. Each blue histogram shows simulated values; the red line shows
#' the observed value. A red line far to the right or left means more or less than
#' the model usually produces. Dashed lines mark the middle 95%.
#' Variance needs at least two observations. Use a tall plotting window to keep
#' all rows readable.
#'
#' @section Scope:
#' These are descriptive predictive checks, not significance tests. Complete
#' simulations retain fitted partner and time dependence. Parameters stay fixed;
#' the observed data were used to fit them, and parameter uncertainty is not included.
#'
#' Predictions have random effects set to zero; for nonlinear links they differ
#' from averages over random effects. Variability includes random effects and is
#' not a family dispersion parameter. Ordinal summaries use category scores;
#' zero counts describe the combined response distribution for zero-inflated models.
#' Uses the families and fitted rows supported by [simulate_dyad_responses()]:
#' missing responses are not imputed, time gaps follow the fitted model, and
#' observations have equal weight. Check partner and time dependence separately.
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
                            check_zeros = NULL, centred_overlay = FALSE,
                            ask = NULL, data = NULL) {
  if (!inherits(simulations, "dyadMLM_response_simulations"))
    stop("`simulations` must be created by `simulate_dyad_responses()`.", call. = FALSE)
  if (!is.null(check_zeros) && !rlang::is_bool(check_zeros))
    stop("`check_zeros` must be NULL, TRUE, or FALSE.", call. = FALSE)
  if (!rlang::is_bool(centred_overlay))
    stop("`centred_overlay` must be TRUE or FALSE.", call. = FALSE)
  if (!is.null(ask) && !rlang::is_bool(ask))
    stop("`ask` must be NULL, TRUE, or FALSE.", call. = FALSE)
  frame <- simulations$model_frame
  compositions <- build_check_groups(
    frame, rlang::enquo(dyad), rlang::enquo(role), rlang::enquo(member), data
  )
  # Keep each complete dataset in a column, with the observed data first.
  responses <- cbind(observed = simulations$observed_response,
                     t(simulations$simulated_responses))
  centred <- sweep(responses, 1, simulations$predicted_response, "-")
  summaries <- lapply(compositions, function(composition) {
    lapply(composition$rows, function(rows) {
      if (!length(rows)) return(NULL)
      statistics <- rbind(
        `Response variability` = apply(centred[rows, , drop = FALSE], 2, stats::var),
        `Largest absolute deviation` = apply(abs(centred[rows, , drop = FALSE]), 2, max)
      )
      include_zeros <- if (is.null(check_zeros)) any(responses[rows, ] == 0) else check_zeros
      if (include_zeros) statistics <- rbind(statistics,
        `Number of zeros` = colSums(responses[rows, , drop = FALSE] == 0))
      statistics
    })
  })
  names(summaries) <- vapply(compositions, `[[`, character(1), "label")

  draw_distribution <- function(values, limits, support = NULL, labels = support,
                                 label = "Outcome") {
    if (!is.null(support)) {
      frequencies <- matrix(vapply(seq_len(ncol(values)), function(dataset) {
        tabulate(match(values[, dataset], support), nbins = length(support)) / nrow(values)
      }, numeric(length(support))), nrow = length(support))
      positions <- graphics::barplot(frequencies[, 1], names.arg = labels,
        col = check_colours$observed_fill, border = check_colours$observed,
        ylim = c(0, max(frequencies, .01)),
        main = "Outcome frequencies", xlab = "Outcome", ylab = "Proportion")
      bounds <- apply(frequencies[, -1, drop = FALSE], 1, stats::quantile, c(.025, .975))
      graphics::segments(positions, bounds[1, ], positions, bounds[2, ],
                         col = check_colours$simulated, lwd = 3)
      graphics::points(positions, frequencies[, 1], col = check_colours$observed,
                       pch = 16, cex = .65)
      plot_check_caption("Red proportions should resemble simulations.\nCompare each with its blue range.")
    } else {
      shown <- values[, seq_len(min(ncol(values), 31)), drop = FALSE]
      graphics::plot(limits, c(0, 1), type = "n", main = "Outcome overlay",
                     xlab = label, ylab = "Cumulative proportion")
      # One step path retains every ECDF jump while keeping vector exports small.
      draw_ecdf <- function(response, ...) {
        empirical <- stats::ecdf(response)
        knots <- stats::knots(empirical)
        graphics::lines(c(graphics::par("usr")[1], knots, graphics::par("usr")[2]),
                        c(0, empirical(knots), 1), type = "s", ...)
      }
      for (dataset in 2:ncol(shown))
        draw_ecdf(shown[, dataset], col = check_colours$simulated)
      draw_ecdf(shown[, 1], col = check_colours$observed, lwd = 2)
      graphics::abline(h = c(0, 1), col = check_colours$reference, lty = 2)
      plot_check_caption("The red curve should resemble the blue curves.\nUp to 30 simulated datasets are shown.")
    }
  }
  family <- attr(simulations, "dyadMLM")$family
  count_families <- c("poisson", "compois", "genpois", "bell", "nbinom1", "nbinom2", "nbinom12",
                     "truncated_poisson", "truncated_nbinom1", "truncated_nbinom2",
                     "truncated_compois", "truncated_genpois")
  old_ask <- grDevices::devAskNewPage((is.null(ask) || ask) && grDevices::dev.interactive())
  on.exit(grDevices::devAskNewPage(old_ask), add = TRUE)
  for (i in seq_along(compositions)) {
    composition <- compositions[[i]]
    role_rows <- composition$rows
    composition_rows <- unlist(role_rows, use.names = FALSE)
    statistics <- summaries[[i]]
    statistic_names <- unique(unlist(lapply(statistics, rownames)))
    support <- category_labels <- NULL
    if (identical(family, "ordinal") && is.factor(frame[[1]])) {
      category_labels <- levels(frame[[1]])
      support <- seq_along(category_labels)
    } else if (family %in% c("ordinal", count_families)) {
      support <- sort(unique(as.vector(responses[composition_rows, ])))
      if (family != "ordinal" && length(support) > 20) support <- NULL
      category_labels <- support
    }
    plot_check_role_page(composition, 1 + length(statistic_names), "Outcome checks", {
      for (rows in role_rows) {
        if (!length(rows)) plot_check_empty("Outcomes")
        else draw_distribution(responses[rows, , drop = FALSE],
                                range(responses[composition_rows, ]), support, category_labels)
      }
      for (name in statistic_names) for (values in statistics) {
        if (is.null(values) || !name %in% rownames(values)) plot_check_empty(name, "Not applicable")
        else plot_check_statistic(values[name, ], name, xlab = switch(name,
          "Response variability" = "Variance of outcome minus prediction",
          "Largest absolute deviation" = "Absolute difference from prediction",
          "Number of observations"), counts = name == "Number of zeros")
      }
    })
    if (centred_overlay) {
      plot_check_role_page(composition, 1, "Outcomes minus predictions", {
        for (rows in role_rows) {
          if (!length(rows)) plot_check_empty("Centred outcome overlay")
          else draw_distribution(centred[rows, , drop = FALSE], range(centred[composition_rows, ]),
                                  label = "Outcome minus prediction")
        }
      })
    }
  }
  invisible(summaries)
}
