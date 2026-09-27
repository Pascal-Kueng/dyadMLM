#' Check residual distributions and patterns
#'
#' `r lifecycle::badge("experimental")`
#' Check where each observed outcome falls among its simulated values, using
#' complete datasets from [simulate_dyad_responses()].
#' For checks on the outcome scale, use [check_outcomes()].
#'
#' @param simulations An object from [simulate_dyad_responses()]. At least 200
#'   datasets are required; 1,000 or more are recommended.
#' @param predictors Optional column names, e.g. `c("age", "stress")`, looked up
#'   in the model frame or `data`. `NULL` (default) omits additional predictor
#'   pages. Missing or infinite values are omitted only from that predictor's
#'   plots. Predicted outcomes are always checked.
#' @param seed Seed for randomized PIT residuals. The caller's random-number
#'   state is restored afterwards. With `NULL`, use and advance the caller's RNG.
#' @inheritParams check_partner_dependence
#' @param panels If `TRUE` (default), arrange checks in complete panels by
#'   composition, with one column per role or a pooled column. If `FALSE`, draw
#'   each check and role separately, retaining headings and interpretation tips.
#'   Only the arrangement changes; results and checks stay the same.
#' @param dyad,role,member Column names, with or without quotes, identifying
#'   dyads, roles, and members within dyads. Looked up in the fitted model frame
#'   or `data`. With `role = NULL`, all observations are pooled. Otherwise supply
#'   `dyad`; also supply `member` for repeated observations, with `role` unchanged
#'   within each member. Supplying `dyad` without `role` adds the dyad count to
#'   the pooled overview.
#' @param data The unchanged data used to fit the model. Supply it when required
#'   columns are absent from the model frame, or to identify compositions using
#'   partners whose responses were excluded during fitting.
#'
#' @return Invisibly returns a `dyadMLM_residual_check` list with the `pit` matrix
#'   and calculated summaries in `compositions`. PIT rows are fitted observations;
#'   columns are observed data followed by all simulated datasets. This matrix
#'   uses about 77 MiB for 10,080 observations and 1,000 simulations. The `dyadMLM`
#'   attribute records whether PIT was centred in `pit_centered`.
#'   Save it with `plot = FALSE` and draw it later with `plot(result)`.
#'   Graphics settings are restored afterwards.
#'
#' @section Reading the plots:
#' Start with everyone pooled (`role = NULL`), then inspect the roles used in
#' your model. Use `predictors` to examine other measured characteristics. For
#' separate QQ plots, histograms and summaries by a categorical characteristic,
#' use that variable as `role`.
#'
#' A composition is the combination of partners' roles. Each composition gets
#' one pooled column for same-role partners, or separate columns for distinct
#' roles. Every page repeats the composition heading.
#' Roles define the display even if the model treats partners as exchangeable;
#' supplying roles does not change the model's assumptions. Available responses
#' are retained when the composition is known; unknown compositions are omitted
#' with a warning.
#'
#' **Red shows observed data; blue shows simulated references.** The first page
#' shows uniform QQ, a PIT histogram, counts outside the simulated response range,
#' and mean PIT distance. The second shows PIT quartiles and distance against
#' predicted outcomes. Each supplied predictor gets another two-row pattern page.
#' All pages for one composition appear together.
#' The histogram and QQ plot show the same residual distribution in different
#' ways; agreement between them is not independent evidence.
#' The histogram uses 10 equal-width bins to make broad shapes easier to see.
#' Use a tall plotting window or save a large figure to keep all rows readable.
#'
#' PIT (probability integral transform) residuals rank each outcome from 0 (low)
#' to 1 (high) relative to its own simulated values. A suitable model should
#' produce ranks roughly evenly spread between 0 and 1, allowing for the
#' variation shown in blue.
#' Blue curve envelopes cover positions jointly within each panel, with the
#' three quartiles treated together. They use a nominal 95% extreme-rank-length
#' envelope; coverage is not simultaneous across roles, predictors, or pages.
#' Scalar rows show simulated values as a blue histogram and the observed value
#' as a red line; dashed limits use simulation order statistics. Values exactly on
#' a limit count as inside. Because the model was fitted to these same data,
#' the references can make departures look smaller or larger.
#' The lines at 0.25, 0.50 and 0.75 are visual guides. Judge the red quartiles
#' against their matching blue bands.
#'
#' Each additional predictor gets a page with quartile and distance plots. Numeric
#' predictors with more than eight distinct values in a composition use up to
#' eight bins per role, aiming for about 20 observations per bin. For these
#' predictors, fewer than 40 available observations in a role give one bin.
#' Repeated values can reduce the number of bins and hide local patterns, such as
#' differences between zero and positive predictor values.
#' With at least four bins, nearby quartiles are averaged into smooth curves using
#' the same weights for observed and simulated data; blue bands are calculated
#' afterwards. These are smoothed local summaries, not quantile regressions.
#' Curves span each role's predictor range on a shared axis and can hide patterns
#' within bins.
#' Dashed, solid, and dotted lines identify the 25th, 50th, and 75th percentiles;
#' the median is drawn more heavily. Faint points show individual observed residuals.
#' Sparse numeric predictors use unsmoothed intervals; categorical boxes show the
#' middle 50% and median, with blue quartile ranges offset from left to right.
#' Distance is `2 * abs(PIT - 0.5)`; large values can reflect location or spread
#' errors. These are full-model residuals, not partial effects; separate predictors
#' and bins can hide interactions or finer patterns.
#'
#' @section Scope:
#' Observed and simulated datasets are ranked and transformed together. These
#' envelopes retain the fitted partner and time dependence and any modeled
#' differences in variability between roles, without whitening.
#' Simulations redraw all random effects; DHARMa's default since version 0.5.0
#' holds their fitted values fixed.
#' They are dyadMLM's descriptive checks, not DHARMa's plots or tests. Parameters
#' stay fixed, and the observed data were used to fit them; parameter uncertainty
#' is not included. Neither ranking nor centring makes fitted-data references
#' exact. For cross-sectional data, check partner correlations with
#' [check_partner_dependence()].
#'
#' The "Predicted outcome" axis shows model predictions, not observed outcomes
#' or predictions of residuals. Random effects are set to zero, which differs
#' from averaging over random effects for nonlinear links. Additional predictor
#' plots use the supplied predictor values instead. Uses the families
#' and fitted rows supported by [simulate_dyad_responses()]: missing responses are
#' not imputed, and time gaps follow the fitted model. Observations have equal weight.
#'
#' @section Method and credit:
#' The internal calculation follows the simulation-based PIT approach used in
#' Florian Hartig's DHARMa package and the randomized quantile residual method of
#' Dunn and Smyth (1996). We implement the definition directly and keep the
#' uniform 0--1 scale.
#'
#' At each fitted row, rank the observed and all simulated outcomes together,
#' breaking ties randomly. For rank `r` among `m` datasets, use `(r - U) / m`,
#' where `U` is uniform between 0 and 1. This treats all datasets symmetrically
#' and keeps finite-bank PIT values strictly inside 0--1.
#'
#' When the conditional model can freely shift its overall location, whether
#' fitted with an intercept or separate role means, transform each dataset's PIT
#' to normal scores, subtract its median across all fitted rows, then transform
#' back. This removes overall location before splitting by
#' role or predictor. Patterns describe residuals relative to that overall
#' location. This empirically supported adjustment reduces one source of
#' conservativeness; it does not account for every effect of fitting.
#' PIT residuals are not centred for ordinal models.
#'
#' Outlier counts use the original responses: a dataset contributes an outlier
#' when it alone has the smallest or largest outcome at that fitted row. Tied
#' extremes do not count. These are outcomes beyond the finite simulated range,
#' not outcomes impossible under the model. Counts usually fall as simulations
#' are added. With continuous exchangeable datasets, their expected count is
#' `2 * n / (nsim + 1)`; ties and fitted parameters change this benchmark.
#'
#' Global envelopes use extreme-rank-length ordering (Myllymaki et al., 2017),
#' retaining ties at the boundary and rounding coverage conservatively.
#'
#' @references
#' Hartig, F. DHARMa: Residual Diagnostics for Hierarchical (Multi-Level / Mixed)
#' Regression Models. \doi{10.32614/CRAN.package.DHARMa}.
#'
#' Dunn, P. K., and Smyth, G. K. (1996). Randomized quantile residuals.
#' *Journal of Computational and Graphical Statistics*, 5(3), 236--244.
#' \doi{10.2307/1390802}.
#'
#' Myllymaki, M., Mrkvicka, T., Grabarnik, P., Seijo, H., and Hahn, U. (2017).
#' Global envelope tests for spatial point patterns. *Journal of the Royal
#' Statistical Society: Series B*, 79, 381--404. \doi{10.1111/rssb.12172}.
#'
#' @seealso [check_outcomes()], [check_partner_dependence()]
#' @examplesIf requireNamespace("glmmTMB", quietly = TRUE)
#' model <- glmmTMB::glmmTMB(
#'   closeness ~ gender + provided_support + (1 | coupleID), data = dyads_cross
#' )
#' # Use at least 1,000 draws when checking a model.
#' simulations <- simulate_dyad_responses(model, nsim = 200, seed = 123)
#' check_residuals(simulations, dyad = coupleID, role = gender,
#'                 predictors = "provided_support", ask = FALSE)
#' # Save the same checks without drawing, then plot individual figures.
#' result <- check_residuals(simulations, predictors = "provided_support", plot = FALSE)
#' plot(result, panels = FALSE, ask = FALSE)
#' @export
check_residuals <- function(simulations, dyad = NULL, role = NULL, member = NULL,
                            predictors = NULL, seed = 123, plot = TRUE,
                            ask = NULL, panels = TRUE, data = NULL) {
  if (!inherits(simulations, "dyadMLM_response_simulations"))
    stop("`simulations` must be created by `simulate_dyad_responses()`.", call. = FALSE)
  frame <- simulations$model_frame
  if (!is.null(predictors) && !is.character(predictors))
    stop("`predictors` must be NULL or a character vector of column names.", call. = FALSE)
  predictors <- stats::setNames(lapply(predictors, function(column) {
    resolve_fitted_row_argument(rlang::new_quosure(column), "predictors", frame, data)
  }), predictors)
  if (!is.null(seed)) withr::local_seed(seed)
  observed <- simulations$observed_response
  predicted <- simulations$predicted_response
  draws <- simulations$simulated_responses

  if (length(observed) < 2 || nrow(draws) < 200)
    stop("Use at least two observations and 200 simulated datasets; 1,000 draws are recommended.", call. = FALSE)

  usable_predictors <- logical(length(predictors))
  for (i in seq_along(predictors)) {
    predictor <- predictors[[i]]
    if (!(is.numeric(predictor) || is.factor(predictor) ||
          is.character(predictor) || is.logical(predictor)))
      stop("Each predictor must be numeric or categorical.", call. = FALSE)
    available <- available_check_predictor(predictor)
    usable_predictors[i] <- any(available)
    if (any(!available)) warning(names(predictors)[i], ": omitted ", sum(!available),
      " missing or non-finite values from this predictor's panels.", call. = FALSE)
  }
  predictors <- predictors[usable_predictors]

  compositions <- build_check_groups(
    frame, rlang::enquo(dyad), rlang::enquo(role), rlang::enquo(member), data
  )

  # Rows are fitted observations; columns are complete datasets, observed first.
  responses <- cbind(observed, t(draws))
  outliers <- strict_response_outliers(responses)
  pit <- randomized_pit(responses)
  centered <- isTRUE(attr(simulations, "dyadMLM")$free_conditional_intercept)
  if (centered) {
    for (dataset in seq_len(ncol(pit))) {
      normal_scores <- stats::qnorm(pit[, dataset])
      pit[, dataset] <- stats::pnorm(normal_scores - stats::median(normal_scores))
    }
  }

  # Matrices retain complete datasets in columns; subset only their rows.
  probabilities <- seq(0, 1, length.out = 201)
  breaks <- seq(0, 1, length.out = 11)
  for (i in seq_along(compositions)) {
    role_rows <- compositions[[i]]$rows
    compositions[[i]]$statistics <- lapply(role_rows, function(rows) {
      if (!length(rows)) return(NULL)
      values <- pit[rows, , drop = FALSE]
      list(
        qq = residual_curve_summary(apply(values, 2, stats::quantile, probs = probabilities)),
        histogram = residual_curve_summary(apply(values, 2, function(x)
          graphics::hist(x, breaks, plot = FALSE)$density)),
        outliers = colSums(outliers[rows, , drop = FALSE]),
        mean_distance = colMeans(2 * abs(values - .5))
      )
    })
    compositions[[i]]$patterns <- lapply(c(list(predicted), predictors), function(predictor) {
      lapply(role_rows, function(rows)
        calculate_residual_pattern(pit, predictor, rows, role_rows))
    })
  }
  result <- list(pit = pit, compositions = compositions, predictors = names(predictors))
  attr(result, "dyadMLM") <- attr(simulations, "dyadMLM")
  attr(result, "dyadMLM")$pit_centered <- centered
  class(result) <- c("dyadMLM_residual_check", "list")
  if (missing(role)) message_pooled_roles()
  if (plot) graphics::plot(result, ask = ask, panels = panels)
  invisible(result)
}

available_check_predictor <- function(x) {
  if (is.numeric(x)) is.finite(x) else !is.na(as.character(x))
}

calculate_residual_pattern <- function(pit, predictor, rows, role_rows) {
  available <- available_check_predictor(predictor)
  composition_rows <- unlist(role_rows, use.names = FALSE)
  composition_rows <- composition_rows[available[composition_rows]]
  rows <- rows[available[rows]]
  if (!length(rows)) return(NULL)
  available_values <- predictor[composition_rows]
  binned <- is.numeric(predictor) && length(unique(available_values)) > 8
  # Role-specific bins avoid sparsely populated edges caused by pooling roles.
  grouping_rows <- if (binned) rows else composition_rows
  groups <- if (binned) {
    bins <- max(1, min(8, floor(length(rows) / 20)))
    cuts <- unique(stats::quantile(predictor[rows], seq(0, 1, length.out = bins + 1)))
    if (length(cuts) > 1) cut(predictor[rows], cuts, include.lowest = TRUE)
    else factor(predictor[rows])
  } else factor(available_values)
  rows_by_group <- split(grouping_rows, groups, drop = TRUE)
  positions <- if (is.numeric(predictor)) {
    vapply(rows_by_group, function(rows) mean(predictor[rows]), numeric(1))
  } else seq_along(rows_by_group)
  labels <- if (is.numeric(predictor)) format(positions, trim = TRUE) else names(rows_by_group)
  limits <- if (is.numeric(predictor)) range(available_values) else range(positions)
  padding <- if (is.numeric(predictor)) {
    if (!binned && length(positions) > 1) .2 * min(diff(positions)) else 0
  } else .45
  smooth <- binned && length(positions) >= 4
  if (smooth) {
    grid <- seq(min(predictor[rows]), max(predictor[rows]), length.out = 101)
    # Fixed positive weights keep quartiles ordered and within 0--1.
    log_weights <- -.5 * (outer(grid, positions, "-") / stats::median(diff(positions)))^2
    weights <- exp(log_weights - apply(log_weights, 1, max))
    weights <- weights / rowSums(weights)
  }
  curves <- lapply(list(quantiles = pit, distance = 2 * abs(pit - .5)), function(values) {
    quartiles <- lapply(rows_by_group, function(group_rows) {
      apply(values[intersect(rows, group_rows), , drop = FALSE], 2,
            stats::quantile, probs = c(.25, .5, .75), names = FALSE)
    })
    quartile_curves <- lapply(1:3, function(i) {
      values <- do.call(rbind, lapply(quartiles, function(group) group[i, ]))
      if (smooth) weights %*% values else values
    })
    # One envelope covers all three quartiles and positions in this panel.
    joint <- residual_curve_summary(do.call(rbind, quartile_curves))
    positions_per_curve <- nrow(quartile_curves[[1]])
    lapply(1:3, function(i) {
      indices <- seq_len(positions_per_curve) + (i - 1L) * positions_per_curve
      lapply(joint, `[`, indices)
    })
  })
  list(positions = if (smooth) grid else positions, labels = labels,
       limits = limits + c(-padding, padding), binned = binned, smooth = smooth,
       numeric = is.numeric(predictor),
       points = data.frame(predictor = predictor[rows], pit = pit[rows, 1]),
       quantiles = curves$quantiles, distance = curves$distance)
}

#' Print saved residual or outcome checks
#'
#' Lists the checked compositions without printing the stored results.
#' @param x A result from [check_residuals()] or [check_outcomes()].
#' @param ... Unused.
#' @return `x`, invisibly.
#' @keywords internal
#' @export
print.dyadMLM_residual_check <- function(x, ...) {
  print_check_overview(x, "residual check", x$predictors)
}

#' Plot saved residual checks
#'
#' Draw the checks calculated by [check_residuals()] without recalculating PIT.
#' @param x A result from [check_residuals()].
#' @inheritParams check_residuals
#' @param ... Unused.
#' @return `x`, invisibly.
#' @keywords internal
#' @export
plot.dyadMLM_residual_check <- function(x, ask = NULL, panels = TRUE, ...) {
  local_check_paging(ask, panels, if (panels)
    length(x$compositions) * (2L + length(x$predictors)) else
    sum(vapply(x$compositions, function(composition) length(composition$rows), integer(1))) *
      (6L + 2L * length(x$predictors)))
  draw_envelopes <- function(x, curves, connect = TRUE, boxes = FALSE, smooth = FALSE) {
    quartiles <- length(curves) == 3L
    spacing <- min(diff(x), diff(graphics::par("usr")[1:2]) / 4)
    offsets <- if (quartiles && !smooth) c(-1, 0, 1) else rep(0, length(curves))
    offsets <- offsets * if (boxes) .1 else .12 * spacing
    line_types <- if (smooth) c(2, 1, 3) else rep(1, length(curves))
    for (curve_index in seq_along(curves)) {
      curve <- curves[[curve_index]]
      bounds <- rbind(curve$lower, curve$upper)
      if (connect && (!quartiles || smooth) && all(is.finite(bounds)))
        graphics::polygon(c(x, rev(x)), c(bounds[1, ], rev(bounds[2, ])),
                          col = if (smooth) paste0(check_colours$simulated, "40") else check_colours$simulated, border = NA)
      if (smooth) {
        graphics::lines(x, bounds[1, ], col = check_colours$simulation_line, lty = line_types[curve_index])
        graphics::lines(x, bounds[2, ], col = check_colours$simulation_line, lty = line_types[curve_index])
      } else {
        interval_x <- x + offsets[curve_index]
        graphics::segments(interval_x, bounds[1, ], interval_x, bounds[2, ],
                           col = check_colours$simulated, lwd = 3)
      }
    }
    if (boxes) {
      observed_quartiles <- do.call(cbind, lapply(curves, `[[`, "observed"))
      graphics::rect(x - .18, observed_quartiles[, 1], x + .18, observed_quartiles[, 3],
                     border = check_colours$observed, lwd = 1.5)
      graphics::segments(x - .18, observed_quartiles[, 2], x + .18, observed_quartiles[, 2],
                         col = check_colours$observed, lwd = 2)
    } else for (curve_index in seq_along(curves))
      graphics::lines(x + offsets[curve_index], curves[[curve_index]]$observed,
                      type = if (smooth) "l" else if (connect) "b" else "p",
                      pch = 16, cex = if (connect) .65 else 1, lty = line_types[curve_index],
                      lwd = if (quartiles && curve_index == 2) 2 else 1, col = check_colours$observed)
  }
  draw_pattern <- function(pattern, name = NULL, distance = FALSE) {
    title <- paste("PIT", if (distance) "distance" else "quantiles")
    title <- if (is.null(name)) paste0(title, "\n(",
      if (distance) "residual extremes" else "fit", " across predicted outcomes)")
      else paste0(title, " by ", name, "\n(",
        if (distance) "residual extremes" else "fit", " across predictor values)")
    if (is.null(pattern)) return(plot_check_empty(title, "No available predictor values"))
    curves <- if (distance) pattern$distance else pattern$quantiles
    graphics::plot(pattern$positions, rep(.5, length(pattern$positions)), type = "n", ylim = c(0, 1),
      xlim = pattern$limits, xaxt = if (pattern$binned) "s" else "n", yaxt = "n", main = title,
      xlab = if (is.null(name)) "Predicted outcome" else name,
      ylab = if (distance) "PIT distance" else "PIT quantiles")
    if (!pattern$binned) graphics::axis(1, pattern$positions, pattern$labels, cex.axis = .8)
    graphics::axis(2, c(0, .25, .5, .75, 1))
    graphics::abline(h = c(.25, .5, .75), lty = 2, col = check_colours$reference)
    if (pattern$smooth) {
      observed <- pattern$points$pit
      if (distance) observed <- 2 * abs(observed - .5)
      graphics::points(pattern$points$predictor, observed, pch = 16, cex = .4,
                        col = paste0(check_colours$observed, "20"))
    }
    draw_envelopes(pattern$positions, curves, connect = pattern$numeric,
                   boxes = !pattern$numeric, smooth = pattern$smooth)
    guide <- if (distance)
      "Blue ranges form one global envelope for this panel.\nAbove a range: more extreme residuals; below: more central residuals."
      else "Blue ranges form one global envelope for this panel.\nPersistent departures suggest patterns the model does not reproduce."
    key <- if (pattern$smooth) "25th: dashed; median: bold; 75th: dotted."
      else if (pattern$numeric) "Quartiles: 25th, median (bold), 75th, left to right."
      else "Red: box edges and median. Blue: 25th, median, 75th, left to right."
    plot_check_caption(paste(guide, key, sep = "\n"))
  }
  for (composition in x$compositions) {
    draw_check <- function(check, role) {
      statistics <- composition$statistics[[role]]
      title <- switch(check,
        qq = "Uniform QQ\n(overall residual distribution)",
        histogram = "PIT histogram\n(how residuals are distributed)",
        outliers = "Outside simulated range (outliers)",
        mean_distance = "Mean PIT distance\n(overall residual spread)")
      if (is.null(statistics)) return(plot_check_empty(title))
      if (check == "qq") {
        probabilities <- seq(0, 1, length.out = length(statistics$qq$observed))
        graphics::plot(probabilities, probabilities, type = "n", main = title,
                       xlab = "Uniform quantile", ylab = "PIT quantile")
        draw_envelopes(probabilities, list(statistics$qq))
        graphics::abline(0, 1, lty = 2, col = check_colours$reference)
        plot_check_caption("The red curve should roughly follow the diagonal.\nDepartures outside the blue global envelope suggest a distribution mismatch.")
      } else if (check == "histogram") {
        density <- statistics$histogram
        midpoints <- (seq_along(density$observed) - .5) / length(density$observed)
        graphics::plot(midpoints, density$observed, type = "n", xlim = c(0, 1), ylim = c(0, max(unlist(density))),
                       main = title, xlab = "PIT", ylab = "Density")
        draw_envelopes(midpoints, list(density), connect = FALSE)
        graphics::abline(h = 1, lty = 2, col = check_colours$reference)
        plot_check_caption("A binned view of the same residual distribution as the QQ plot.\nPeaks and gaps help identify departures; the blue global envelope\nshows variation across complete simulated datasets.")
      } else if (check == "outliers") {
        plot_check_statistic(statistics$outliers, title,
          xlab = "Number of observations", counts = TRUE,
          sub = "Counts outcomes below or above all their reference simulations.\nRed should usually lie between the dashed limits.\nBeyond right: more such outcomes than simulated; left: fewer.")
      } else {
        plot_check_statistic(statistics$mean_distance, title, xlab = "Mean distance from PIT 0.5",
          sub = "Mean of 2 * |PIT - 0.5|, relative to simulated datasets.\nBeyond right: more extreme residuals; left: more central residuals.\nLocation and spread errors can both affect this distance.")
      }
    }
    plot_check_role_panels(composition,
      c("qq", "histogram", "outliers", "mean_distance"),
      "Residual distribution", draw_check, panels)
    for (i in seq_along(composition$patterns)) {
      name <- if (i == 1L) NULL else x$predictors[i - 1L]
      plot_check_role_panels(composition, c(FALSE, TRUE),
        paste("Residual patterns:", if (is.null(name)) "predicted outcome" else name),
        function(distance, role) draw_pattern(composition$patterns[[i]][[role]],
                                             name, distance), panels)
    }
  }
  invisible(x)
}

# Rank each row symmetrically, breaking ties randomly and jittering within ranks.
randomized_pit <- function(responses) {
  ranks <- t(apply(responses, 1, rank, ties.method = "random"))
  (ranks - stats::runif(length(ranks))) / ncol(responses)
}

# A strict outlier is the unique minimum or maximum among all datasets at a row.
strict_response_outliers <- function(responses) {
  lowest <- responses == apply(responses, 1, min)
  highest <- responses == apply(responses, 1, max)
  (lowest & rowSums(lowest) == 1L) | (highest & rowSums(highest) == 1L)
}
