#' Check residual distributions and patterns
#'
#' `r lifecycle::badge("experimental")`
#' Compare PIT residuals with complete datasets from [simulate_dyad_responses()].
#' For checks on the outcome scale, use [check_outcomes()].
#'
#' @param simulations An object from [simulate_dyad_responses()]. At least four
#'   datasets are required; 1,000 or more are recommended.
#' @param predictors Optional named list or data frame of additional predictors,
#'   in fitted-row order, for separate pages. Use `simulations$model_frame` columns
#'   where possible. Missing or infinite values are omitted only from that
#'   predictor's plots. Fitted predictions are always checked.
#' @param seed Seed for randomized PIT residuals. The caller's random-number
#'   state is restored afterwards.
#' @param ask Pause between pages on interactive devices? `NULL` (default) and
#'   `TRUE` pause; `FALSE` does not. File devices never pause.
#' @param dyad,role,member Column names, with or without quotes, identifying
#'   dyads, roles, and members within dyads. Looked up in the fitted model frame
#'   or `data`. With `role = NULL`, all observations are pooled. Otherwise supply
#'   `dyad`; also supply `member` for repeated observations. Supplying `dyad`
#'   without `role` adds the dyad count to the pooled overview.
#' @param data The unchanged data used to fit the model. Supply it when grouping
#'   columns are absent from the model frame, or to identify compositions using
#'   partners whose responses were excluded during fitting.
#' @param details Add a uniformity histogram and PIT-distance plots against
#'   fitted values? Default: `FALSE`.
#'
#' @return One page per composition, plus optional predictor and detail pages.
#'   Invisibly returns PIT residuals for all fitted observations: rows are
#'   observations; columns are observed data followed by the second half of the
#'   simulations. Graphics settings are restored afterwards.
#'
#' @section Reading the plots:
#' Each composition gets one pooled column for same-role partners, or separate
#' columns for distinct roles. Every page repeats the composition heading.
#' Roles define the display even if the fitted model
#' treats partners as exchangeable. Available responses are retained when the
#' composition is known; unknown compositions are omitted with a warning.
#'
#' **Red shows observed data; blue shows simulated references.** The four rows
#' show uniform QQ, a PIT histogram, PIT quartiles against fitted predictions,
#' and the number of outcomes outside their simulated range (PIT endpoints).
#' Use a tall plotting window or save a large figure to keep all rows readable.
#'
#' PIT residuals rank each outcome from 0 (low) to 1 (high) relative to its own
#' simulated values. Blue ranges contain the middle 95% at each plotted position,
#' not across the whole plot. Some red points can fall outside by chance.
#' For out-of-range counts, the blue histogram shows simulated counts and the red
#' line shows the observed count; dashed lines mark the middle 95%.
#' `details = TRUE` adds a page with uniformity (KS distance) and fitted-value
#' PIT-distance plots.
#'
#' Each additional predictor gets a page with quartile and distance plots. Numeric
#' predictors with many values use up to eight bins, chosen within each role.
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
#' The first half of simulations defines PIT; the other half provides complete
#' reference datasets, transformed and grouped just like the observations. These
#' envelopes account for fitted partner and time dependence without whitening.
#' They are dyadMLM's descriptive checks, not DHARMa's plots or tests. Parameters
#' stay fixed, and the observed data were used to fit them; parameter uncertainty
#' is not included. Check partner and time dependence separately.
#'
#' Fitted values are response predictions with random effects set to zero, which
#' differ from averages over random effects for nonlinear links. Uses the families
#' and fitted rows supported by [simulate_dyad_responses()]: missing responses are
#' not imputed, and time gaps follow the fitted model. Observations have equal weight.
#'
#' @section Method and credit:
#' The internal calculation follows the simulation-based PIT approach used in
#' Florian Hartig's DHARMa package and the randomized quantile residual method of
#' Dunn and Smyth (1996). We implement the definition directly and keep the
#' uniform 0--1 scale, rather than transforming to normal quantiles.
#'
#' For each outcome, calculate the proportions of reference simulations below
#' it and at or below it. If these match, use that proportion; otherwise draw
#' uniformly between them. This handles continuous outcomes, discrete ties, and
#' mixtures of both. A finite simulation bank approximates the model's PIT.
#'
#' @references
#' Hartig, F. DHARMa: Residual Diagnostics for Hierarchical (Multi-Level / Mixed)
#' Regression Models. \doi{10.32614/CRAN.package.DHARMa}.
#'
#' Dunn, P. K., and Smyth, G. K. (1996). Randomized quantile residuals.
#' *Journal of Computational and Graphical Statistics*, 5(3), 236--244.
#' \doi{10.2307/1390802}.
#'
#' @seealso [check_outcomes()], [check_partner_dependence()]
#' @examplesIf requireNamespace("glmmTMB", quietly = TRUE)
#' model <- glmmTMB::glmmTMB(
#'   closeness ~ gender + (1 | coupleID), data = dyads_cross
#' )
#' # Use at least 1,000 draws when checking a model.
#' simulations <- simulate_dyad_responses(model, nsim = 100, seed = 123)
#' check_residuals(simulations, dyad = coupleID, role = gender, ask = FALSE)
#' @export
check_residuals <- function(simulations, dyad = NULL, role = NULL, member = NULL,
                            predictors = list(),
                            seed = 123, ask = NULL,
                            data = NULL, details = FALSE) {
  if (!inherits(simulations, "dyadMLM_response_simulations"))
    stop("`simulations` must be created by `simulate_dyad_responses()`.", call. = FALSE)
  if (!is.list(predictors))
    stop("`predictors` must be a list or data frame of fitted-row values.", call. = FALSE)
  names(predictors) <- rlang::names2(predictors)
  if (!is.null(ask) && !rlang::is_bool(ask))
    stop("`ask` must be NULL, TRUE, or FALSE.", call. = FALSE)
  if (!rlang::is_bool(details))
    stop("`details` must be TRUE or FALSE.", call. = FALSE)
  withr::local_seed(seed)
  observed <- simulations$observed_response
  predicted <- simulations$predicted_response
  draws <- simulations$simulated_responses

  if (length(observed) < 2 || nrow(draws) < 4)
    stop("Use at least two observations and four simulated datasets; 1,000 draws are recommended.", call. = FALSE)

  available_predictor <- function(x) {
    if (is.numeric(x)) is.finite(x) else !is.na(as.character(x))
  }
  usable_predictors <- logical(length(predictors))
  for (i in seq_along(predictors)) {
    predictor <- predictors[[i]]
    if (!(is.numeric(predictor) || is.factor(predictor) ||
          is.character(predictor) || is.logical(predictor)))
      stop("Each predictor must be numeric or categorical.", call. = FALSE)
    if (length(predictor) != length(observed) || !is.null(dim(predictor)))
      stop("Each predictor must contain one value per observation used in the fit.", call. = FALSE)
    if (names(predictors)[i] == "")
      names(predictors)[i] <- paste("Predictor", i)
    available <- available_predictor(predictor)
    usable_predictors[i] <- any(available)
    if (any(!available)) warning(names(predictors)[i], ": omitted ", sum(!available),
      " missing or non-finite values from this predictor's panels.", call. = FALSE)
  }
  predictors <- predictors[usable_predictors]

  frame <- simulations$model_frame
  compositions <- build_check_groups(
    frame, rlang::enquo(dyad), rlang::enquo(role), rlang::enquo(member), data
  )

  # First half defines PIT; the other half supplies independent whole datasets.
  reference_rows <- seq_len(floor(nrow(draws) / 2))
  reference <- t(draws[reference_rows, , drop = FALSE])
  responses <- cbind(observed, t(draws[-reference_rows, , drop = FALSE]))
  # Every matrix below has observations in rows, datasets in columns; observed first.
  pit <- apply(responses, 2, function(response) {
    randomized_pit(reference, response)
  })

  # Matrices retain complete datasets in columns; subset only their rows.
  draw_envelopes <- function(x, curves, connect = TRUE, boxes = FALSE, smooth = FALSE) {
    quartiles <- length(curves) == 3L
    spacing <- min(diff(x), diff(graphics::par("usr")[1:2]) / 4)
    offsets <- if (quartiles && !smooth) c(-1, 0, 1) else rep(0, length(curves))
    offsets <- offsets * if (boxes) .1 else .12 * spacing
    line_types <- if (smooth) c(2, 1, 3) else rep(1, length(curves))
    for (curve_index in seq_along(curves)) {
      values <- curves[[curve_index]]
      bounds <- apply(values[, -1, drop = FALSE], 1, stats::quantile,
                      c(.025, .975), na.rm = TRUE)
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
      observed_quartiles <- do.call(cbind, lapply(curves, function(values) values[, 1]))
      graphics::rect(x - .18, observed_quartiles[, 1], x + .18, observed_quartiles[, 3],
                     border = check_colours$observed, lwd = 1.5)
      graphics::segments(x - .18, observed_quartiles[, 2], x + .18, observed_quartiles[, 2],
                         col = check_colours$observed, lwd = 2)
    } else for (curve_index in seq_along(curves))
      graphics::lines(x + offsets[curve_index], curves[[curve_index]][, 1],
                      type = if (smooth) "l" else if (connect) "b" else "p",
                      pch = 16, cex = .65, lty = line_types[curve_index],
                      lwd = if (quartiles && curve_index == 2) 2 else 1, col = check_colours$observed)
  }
  draw_pattern <- function(rows, predictor, name, role_rows, distance = FALSE) {
    available <- available_predictor(predictor)
    composition_rows <- unlist(role_rows, use.names = FALSE)
    composition_rows <- composition_rows[available[composition_rows]]
    rows <- rows[available[rows]]
    title <- paste("PIT", if (distance) "distance" else "quantiles", "by", name)
    if (!length(rows)) return(plot_check_empty(title, "No available predictor values"))
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
    predictor_label <- if (name == "Fitted") "Predicted response" else name
    limits <- if (is.numeric(predictor)) range(available_values) else range(positions)
    padding <- if (is.numeric(predictor)) {
      if (!binned && length(positions) > 1) .2 * min(diff(positions)) else 0
    } else .45
    graphics::plot(positions, rep(.5, length(positions)), type = "n", ylim = c(0, 1),
      xlim = limits + c(-padding, padding),
      xaxt = if (binned) "s" else "n", yaxt = "n", main = title,
      xlab = predictor_label,
      ylab = if (distance) "PIT distance" else "PIT quantiles")
    if (!binned) graphics::axis(1, positions, labels, cex.axis = .8)
    graphics::axis(2, c(0, .25, .5, .75, 1))
    graphics::abline(h = c(.25, .5, .75), lty = 2, col = check_colours$reference)
    values <- if (distance) 2 * abs(pit - .5) else pit
    quartiles <- lapply(rows_by_group, function(group_rows) {
      apply(values[intersect(rows, group_rows), , drop = FALSE], 2,
            stats::quantile, probs = c(.25, .5, .75))
    })
    curves <- lapply(1:3, function(i) do.call(rbind,
      lapply(quartiles, function(group) group[i, ])))
    smooth <- binned && length(positions) >= 4
    if (smooth) {
      grid <- seq(min(predictor[rows]), max(predictor[rows]), length.out = 101)
      # Fixed positive weights keep quartiles ordered and within 0--1.
      log_weights <- -.5 * (outer(grid, positions, "-") / stats::median(diff(positions)))^2
      weights <- exp(log_weights - apply(log_weights, 1, max))
      weights <- weights / rowSums(weights)
      # Smooth complete datasets first; their envelopes are computed afterwards.
      curves <- lapply(curves, function(values) weights %*% values)
      positions <- grid
      graphics::points(predictor[rows], values[rows, 1], pch = 16, cex = .4, col = paste0(check_colours$observed, "20"))
    }
    draw_envelopes(positions, curves, connect = is.numeric(predictor),
                   boxes = !is.numeric(predictor), smooth = smooth)
    plot_check_caption(if (smooth)
      "25th: dashed; median: bold; 75th: dotted.\nCompare each red curve with its matching blue band."
      else "Quartiles: 25th, median (bold), 75th, left to right.\nEach should track its dashed line and blue ranges.")
  }
  ks_distance <- function(x) {
    ordered <- sort(x)
    ranks <- seq_along(x)
    max(ranks / length(x) - ordered, ordered - (ranks - 1) / length(x))
  }
  old_ask <- grDevices::devAskNewPage((is.null(ask) || ask) && grDevices::dev.interactive())
  on.exit(grDevices::devAskNewPage(old_ask), add = TRUE)
  probabilities <- seq(0, 1, length.out = 201)
  breaks <- seq(0, 1, length.out = 21)
  for (composition in compositions) {
    role_rows <- composition$rows
    plot_check_role_page(composition, 4, "Residual checks", {
      for (panel in c("Uniform QQ", "PIT histogram", "Fitted", "Outside simulated range")) {
        for (rows in role_rows) {
          if (!length(rows)) {
            plot_check_empty(panel)
            next
          }
          if (panel == "Uniform QQ") {
            qq <- apply(pit[rows, , drop = FALSE], 2, stats::quantile, probs = probabilities)
            graphics::plot(probabilities, probabilities, type = "n", main = panel,
                           xlab = "Uniform quantile", ylab = "PIT quantile")
            draw_envelopes(probabilities, list(qq))
            graphics::abline(0, 1, lty = 2, col = check_colours$reference)
            plot_check_caption("The red curve should follow the diagonal,\nallowing for the blue variation.")
          } else if (panel == "PIT histogram") {
            densities <- apply(pit[rows, , drop = FALSE], 2,
                               function(x) graphics::hist(x, breaks, plot = FALSE)$density)
            midpoints <- utils::head(breaks, -1) + diff(breaks) / 2
            graphics::plot(midpoints, densities[, 1], type = "n", ylim = c(0, max(densities)),
                           main = panel, xlab = "PIT", ylab = "Density")
            draw_envelopes(midpoints, list(densities), connect = FALSE)
            graphics::abline(h = 1, lty = 2, col = check_colours$reference)
            plot_check_caption("Red frequencies should be roughly flat.\nCompare each point with its blue range.")
          } else if (panel == "Fitted") {
            draw_pattern(rows, predicted, "Fitted", role_rows)
          } else {
            values <- pit[rows, , drop = FALSE]
            plot_check_statistic(colSums(values == 0 | values == 1), panel,
                                 xlab = "Number of observations", counts = TRUE)
          }
        }
      }
    })

    for (predictor_index in seq_along(predictors)) {
      plot_check_role_page(composition, 2, names(predictors)[predictor_index], {
        for (distance in c(FALSE, TRUE)) for (rows in role_rows)
          draw_pattern(rows, predictors[[predictor_index]], names(predictors)[predictor_index],
                       role_rows, distance)
      })
    }
    if (details) {
      plot_check_role_page(composition, 2, "Residual details", {
        for (rows in role_rows) {
          if (!length(rows)) plot_check_empty("Uniformity")
          else plot_check_statistic(apply(pit[rows, , drop = FALSE], 2, ks_distance),
                                    "Uniformity", xlab = "Distance from uniform residuals")
        }
        for (rows in role_rows) draw_pattern(rows, predicted, "Fitted", role_rows, TRUE)
      })
    }
  }
  invisible(pit)
}

# Reference rows are observations, columns are simulations; see the method above.
randomized_pit <- function(reference, observed) {
  below <- unname(rowMeans(reference < observed))
  at_or_below <- unname(rowMeans(reference <= observed))
  tied <- below < at_or_below
  if (any(tied)) below[tied] <- stats::runif(sum(tied), below[tied], at_or_below[tied])
  below
}
