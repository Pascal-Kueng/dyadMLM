#' Check residual distributions and patterns
#'
#' `r lifecycle::badge("experimental")`
#' A model should reproduce how responses are distributed around its
#' predictions. This check finds where each observed outcome falls among its
#' simulated values (PIT residuals), using complete datasets from
#' [simulate_dyad_responses()]. This helps identify mismatches in the model's
#' assumptions, such as the distribution family, dispersion, or predictor
#' effects.
#' For checks on the outcome scale, also run [check_dyad_outcomes()] with the
#' same simulations.
#' For guidance on how to read the plots, see [plot.dyadMLM_residual_check()].
#'
#' @param simulations An object from [simulate_dyad_responses()] with at least
#'   200 simulated datasets. At least 1,000 are recommended for stable
#'   comparisons.
#' @param predictors Optional quoted column names, e.g. `c("age", "stress")`.
#'   Each adds a page of PIT quartiles across that column, to show effects the
#'   model omits or may misspecify, especially partner effects. Missing or
#'   infinite values are left out of that page only. `NULL` (default) adds no
#'   predictor pages.
#' @param seed Seed for randomized PIT residuals. The caller's random-number
#'   state is restored afterwards. With `NULL`, use and advance the caller's
#'   random-number state.
#' @inheritParams check_partner_dependence
#' @param panels If `TRUE` (default), arrange checks in figures by
#'   composition, with one column per role or a pooled column. If `FALSE`, draw
#'   each check and role separately.
#' @param dyad Dyad ID column, with or without quotes. Required when `role` is
#'   supplied.
#' @param role Role column, with or without quotes, such as gender. `NULL`
#'   (default) pools all observations. Otherwise, each composition (pair of
#'   partners' roles, such as female-male) is checked separately. Each member
#'   must keep the same role.
#' @param member Person ID column, with or without quotes. Required with `role`
#'   when dyads have repeated observations.
#' @param data The unchanged data used to fit the model. Supply it when the
#'   columns you name (such as `role`) are not in the model formulas. Also supply
#'   it when rows were excluded during fitting (e.g., for missing values).
#'   Otherwise, a person whose partner's rows were excluded has an unknown
#'   composition and is omitted.
#' @param quartile_lines Quantile regression lines (`"qgam"`) can show trends
#'   near the ends of a numeric axis more clearly than smoothed bins (`"bins"`,
#'   default). As in DHARMa, they are fitted with the qgam package on ranks of
#'   the axis values. Each dataset gets its own lines, so envelopes and flags
#'   work as with bins. `"qgam"` is much slower and may warn when fits do not
#'   converge.
#'
#' @return Invisibly returns a `dyadMLM_residual_check` list with the `pit` matrix
#'   (after any centring) and calculated summaries in `compositions`. `pit` has
#'   one row per fitted observation and one column per dataset (observed first,
#'   then all simulated). Optionally, suppress plotting with `plot = FALSE` and
#'   draw the saved result later with `plot(result)`, which also takes `ask` and
#'   `panels`.
#'
#' @section Scope:
#' Complete simulated datasets keep the fitted partner and time dependence and
#' any modeled differences in variability between roles. Unlike DHARMa's default
#' (since version 0.5.0), simulations redraw all random effects. Dyadic models
#' often fix the residual variance near zero (`dispformula = ~ 0`) and model the
#' partners' residual variances and covariance as random effects. If held
#' fixed, these random effects would reproduce the data almost exactly.
#' Parameters stay fixed at their fitted values, so parameter uncertainty is not
#' included. These are descriptive checks, not significance tests, and
#' differ from DHARMa's plots and tests (see the
#' [distribution-checks article](https://pascal-kueng.github.io/dyadMLM/articles/distribution-checks.html#why-not-use-dharma-directly)).
#' They do not directly assess serial correlation.
#'
#' Predicted outcomes are mean predictions with random effects set to zero (see
#' [simulate_dyad_responses()]). The checks use the same fitted rows and
#' families as [simulate_dyad_responses()] and weight all observations equally.
#' For cross-sectional data, check partner correlations with
#' [check_partner_dependence()].
#'
#' @section Method and credit:
#' The internal calculation follows the simulation-based PIT approach used in
#' Florian Hartig's DHARMa package and the randomized quantile residual method of
#' Dunn and Smyth (1996). We implement the definition directly and keep the
#' uniform 0--1 scale.
#'
#' At each fitted row, rank the observed and all simulated outcomes together,
#' breaking ties randomly. For rank `r` among `m` datasets, use `(r - U) / m`,
#' where `U` is uniform between 0 and 1.
#'
#' When the model freely estimates an overall location (an intercept or separate
#' role means) and is not ordinal, PIT is centred automatically: each dataset's
#' PIT is transformed to normal scores, centred on its median across all fitted
#' rows, and transformed back. Panels then show residuals relative to this
#' overall location, so all panels can show less of an overall shift. Centring
#' also partly offsets how fitting makes departures look smaller.
#'
#' Global envelopes use extreme-rank-length ordering (Myllymäki et al., 2017).
#'
#' @references
#' Dunn, P. K., & Smyth, G. K. (1996). Randomized quantile residuals.
#' *Journal of Computational and Graphical Statistics, 5*(3), 236--244.
#' \doi{10.2307/1390802}
#'
#' Hartig, F. (2026). *DHARMa: Residual diagnostics for hierarchical
#' (multi-level/mixed) regression models* (Version 0.5.0) \[R package\].
#' \doi{10.32614/CRAN.package.DHARMa}
#'
#' Myllymäki, M., Mrkvička, T., Grabarnik, P., Seijo, H., & Hahn, U. (2017).
#' Global envelope tests for spatial processes. *Journal of the Royal
#' Statistical Society: Series B (Statistical Methodology), 79*(2), 381--404.
#' \doi{10.1111/rssb.12172}
#'
#' @seealso [check_dyad_outcomes()], [check_partner_dependence()]
#' @examplesIf requireNamespace("glmmTMB", quietly = TRUE)
#' example_data <- prepare_dyad_data(
#'   dyads_cross,
#'   dyad = coupleID,
#'   member = personID,
#'   model_types = "none",
#'   seed = 123
#' )
#' # Exchangeable dyads: the two random-effect blocks represent the partners'
#' # residual variances and covariance.
#' model <- glmmTMB::glmmTMB(
#'   closeness ~ gender + provided_support +
#'     us(1 | coupleID) + us(0 + .member_contrast_arbitrary | coupleID),
#'   dispformula = ~ 0,
#'   data = example_data
#' )
#' simulations <- simulate_dyad_responses(
#'   model,
#'   nsim = 200, # Low for a quick example. Use at least 1,000.
#'   seed = 123
#' )
#' check_dyad_residuals(
#'   simulations,
#'   dyad = coupleID,
#'   role = gender,
#'   predictors = "provided_support",
#'   ask = FALSE
#' )
#' # Save a pooled check without drawing, then plot each figure separately.
#' result <- check_dyad_residuals(
#'   simulations,
#'   role = NULL,
#'   predictors = "provided_support",
#'   plot = FALSE
#' )
#' plot(result, panels = FALSE, ask = FALSE)
#' @export
check_dyad_residuals <- function(simulations, dyad = NULL, role = NULL, member = NULL,
                                 predictors = NULL, seed = 123, plot = TRUE,
                                 ask = NULL, panels = TRUE, data = NULL,
                                 quartile_lines = c("bins", "qgam")) {
  if (!inherits(simulations, "dyadMLM_response_simulations"))
    stop("`simulations` must be created by `simulate_dyad_responses()`.", call. = FALSE)
  quartile_lines <- match.arg(quartile_lines)
  if (quartile_lines == "qgam" && !requireNamespace("qgam", quietly = TRUE))
    stop("`quartile_lines = \"qgam\"` needs the qgam package.", call. = FALSE)
  frame <- simulations$model_frame
  # A bare column name would otherwise fail with R's generic "object not found".
  predictors <- tryCatch(predictors, error = function(e) FALSE)
  if (!is.null(predictors) && !is.character(predictors))
    stop("`predictors` must be NULL or quoted column names, e.g. `c(\"age\", \"stress\")`.",
         call. = FALSE)
  predictors <- stats::setNames(lapply(predictors, function(column) {
    resolve_fitted_row_argument(rlang::new_quosure(column), "predictors", frame, data)
  }), predictors)
  if (!is.null(seed)) withr::local_seed(seed)
  observed <- simulations$observed_response
  predicted <- simulations$predicted_response
  draws <- simulations$simulated_responses

  if (length(observed) < 2 || nrow(draws) < 200)
    stop("Use at least two observations and 200 simulated datasets; 1,000 are recommended.", call. = FALSE)

  for (name in names(predictors)) {
    predictor <- predictors[[name]]
    if (!(is.numeric(predictor) || is.factor(predictor) ||
          is.character(predictor) || is.logical(predictor)))
      stop("Each predictor must be numeric or categorical.", call. = FALSE)
    omitted <- sum(!available_check_predictor(predictor))
    if (omitted) warning(name, ": omitted ", omitted,
      " missing or non-finite values from this predictor's panels.", call. = FALSE)
  }

  compositions <- build_check_groups(
    frame, rlang::enquo(dyad), rlang::enquo(role), rlang::enquo(member), data
  )

  # Rows are fitted observations; columns are complete datasets, observed first.
  responses <- cbind(observed, t(draws))
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
  for (i in seq_along(compositions)) {
    role_rows <- compositions[[i]]$rows
    compositions[[i]]$statistics <- lapply(role_rows, function(rows) {
      if (!length(rows)) return(NULL)
      values <- pit[rows, , drop = FALSE]
      list(
        qq = residual_curve_summary(apply(values, 2, stats::quantile, probs = probabilities)),
        mean_distance = colMeans(2 * abs(values - .5))
      )
    })
    compositions[[i]]$patterns <- lapply(c(list(predicted), predictors), function(predictor) {
      lapply(role_rows, function(rows)
        calculate_residual_pattern(pit, predictor, rows, role_rows, quartile_lines))
    })
  }
  result <- list(pit = pit, compositions = compositions, predictors = names(predictors))
  attr(result, "dyadMLM") <- attr(simulations, "dyadMLM")
  class(result) <- c("dyadMLM_residual_check", "list")
  if (missing(role)) message_pooled_roles()
  if (plot) graphics::plot(result, ask = ask, panels = panels)
  invisible(result)
}

available_check_predictor <- function(x) {
  if (is.numeric(x)) is.finite(x) else !is.na(as.character(x))
}

calculate_residual_pattern <- function(pit, predictor, rows, role_rows, quartile_lines) {
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
  quartiles <- lapply(rows_by_group, function(group_rows) {
    apply(pit[intersect(rows, group_rows), , drop = FALSE], 2,
          stats::quantile, probs = c(.25, .5, .75), names = FALSE)
  })
  quartile_curves <- lapply(1:3, function(i) {
    values <- do.call(rbind, lapply(quartiles, function(group) group[i, ]))
    if (smooth) weights %*% values else values
  })
  if (smooth && quartile_lines == "qgam") {
    # As in DHARMa, fit on ranks. Then draw at the matching predictor values.
    ranks <- rank(predictor[rows])
    rank_grid <- seq(min(ranks), max(ranks), length.out = 101)
    grid <- stats::approx(ranks, predictor[rows], rank_grid, ties = mean)$y
    quartile_curves <- qgam_quartiles(pit[rows, , drop = FALSE], ranks, rank_grid)
  }
  # One envelope covers all three quartiles and positions in this panel.
  joint <- residual_curve_summary(do.call(rbind, quartile_curves))
  positions_per_curve <- nrow(quartile_curves[[1]])
  quantiles <- lapply(1:3, function(i) {
    indices <- seq_len(positions_per_curve) + (i - 1L) * positions_per_curve
    lapply(joint, `[`, indices)
  })
  list(positions = if (smooth) grid else positions, labels = labels,
       limits = limits + c(-padding, padding), binned = binned, smooth = smooth,
       numeric = is.numeric(predictor), quantiles = quantiles)
}

# Fit the three PIT quartiles across `x` with qgam, as in DHARMa::testQuantiles().
# Returns one matrix per quartile: `grid` points in rows, datasets in columns.
# Calibrating qgam for every dataset would take far too long, so simulated
# datasets reuse the tuning found for the observed data.
qgam_quartiles <- function(values, x, grid) {
  # mgcv's default basis size, but no more than the distinct values.
  k <- min(length(unique(x)), 10)
  lapply(c(.25, .5, .75), function(q) {
    fit <- function(residuals, ...) {
      utils::capture.output(model <- qgam::qgam(res ~ s(pred, k = k),
        data = data.frame(res = residuals - q, pred = x), qu = q, ...))
      model
    }
    observed <- fit(values[, 1])
    vapply(seq_len(ncol(values)), function(dataset) {
      model <- if (dataset == 1L) observed else fit(values[, dataset],
        lsig = observed$calibr$lsig, err = observed$calibr$err, argGam = list(sp = observed$sp))
      as.numeric(stats::predict(model, data.frame(pred = grid))) + q
    }, numeric(length(grid)))
  })
}

#' @export
print.dyadMLM_residual_check <- function(x, ...) {
  print_check_overview(x, "residual check", x$predictors)
}

#' Read residual check plots
#'
#' How to read the pages drawn by [check_dyad_residuals()] and how to follow up
#' flags. `plot()` redraws a check saved with `plot = FALSE`.
#'
#' @param x A result from [check_dyad_residuals()].
#' @inheritParams check_dyad_residuals
#' @param ... Unused.
#' @return `x`, invisibly.
#'
#' @section Residual check pages:
#' For each composition, the first page shows uniform QQ and mean PIT distance.
#' The second shows PIT quartiles against predicted outcomes. Each supplied
#' predictor gets another page like the second.
#'
#' PIT (probability integral transform) residuals rank each outcome from 0 (low)
#' to 1 (high) relative to its own simulated values. A suitable model should
#' produce ranks roughly evenly spread between 0 and 1, allowing for the
#' variation shown in blue. PIT distance is `2 * abs(PIT - 0.5)`. Blue envelopes
#' are global: they are built so that the whole red curve of a correct model
#' stays inside in a nominal 95% of datasets. This holds within each panel, not
#' across roles, predictors, or pages. Because the model was fitted to these
#' same data, departures often look smaller than they are, as in the settings
#' studied by Robins et al. (2000) and in our simulations.
#'
#' Predicted outcomes and numeric predictors with more than eight distinct values
#' are grouped into up to eight bins per role, with at least about 20
#' observations per bin. With four or more bins, quartiles are smoothed across
#' neighboring bins. `quartile_lines = "qgam"` in [check_dyad_residuals()]
#' replaces these smoothed quartiles with qgam lines. These are full-model
#' residuals, not partial effects. Bins and separate predictors can hide local
#' patterns and interactions.
#'
#'
#' @section Views and compositions:
#' Start with everyone pooled (`role = NULL`), then also inspect meaningful
#' roles, such as gender, even when the model treats partners as exchangeable:
#' role-specific problems show only there. Use `predictors` of
#' [check_dyad_residuals()] to examine other measured characteristics. For
#' separate plots and summaries by a person-level categorical characteristic,
#' use that variable as `role`.
#'
#' Each composition gets one pooled column for same-role partners, or separate
#' columns for distinct roles. Supplying roles does not change the model's
#' assumptions. Observations whose composition or role is unknown, for example
#' because the partner's row is missing and `data` was not supplied, are omitted
#' with a warning.
#'
#' @section Reading flags:
#' A flag is a red curve or point outside its blue envelope or range, or a red
#' line outside its dashed limits. Each panel alone rarely flags a correct
#' model, but flags add up across panels, roles, and predictor pages, so look
#' for a consistent pattern, not any single flag. The
#' [simulation study](https://pascal-kueng.github.io/dyadMLM/articles/distribution-checks.html)
#' reports how often correct and mismatched models were flagged.
#'
#' With about 40 dyads, most mismatches studied were hard to detect, so the
#' absence of flags does not show a good fit. Panels suggest possible problems,
#' not their cause. Neither a flag nor its absence shows whether estimates or
#' standard errors are wrong. After a flag, fit the model the pattern suggests
#' and compare the estimates and standard errors you report. Mismatches showed
#' mainly in these panels of both checks:
#' - Poisson fitted to overdispersed counts: mean PIT distance, number of zeros, QQ.
#' - Extra zeros: QQ and PIT quartiles (the number of zeros less often).
#' - Omitted role means: QQ and PIT quartiles across predicted outcomes, by role.
#' - Different role SDs: response SD and mean PIT distance, by role.
#' - Spread rising with a predictor: largest absolute deviation, mean PIT
#'   distance, QQ, and PIT quartiles across that predictor.
#' - Omitted partner effect: PIT quartiles across the partner's predictor
#'   (supply it in `predictors` of [check_dyad_residuals()]).
#'
#' @references
#' Robins, J. M., van der Vaart, A., & Ventura, V. (2000). Asymptotic
#' distribution of P values in composite null models. *Journal of the American
#' Statistical Association, 95*(452), 1143--1156.
#' \doi{10.1080/01621459.2000.10474310}
#'
#' @seealso [check_dyad_residuals()], [plot.dyadMLM_outcome_check()]
#' @keywords internal
#' @export
plot.dyadMLM_residual_check <- function(x, ask = NULL, panels = TRUE, ...) {
  local_check_paging(ask, panels, if (panels)
    length(x$compositions) * (2L + length(x$predictors)) else
    sum(vapply(x$compositions, function(composition) length(composition$rows), integer(1))) *
      (3L + length(x$predictors)))
  # Blue ranges for the three quartiles, then the red observed quartiles on top.
  draw_quartiles <- function(x, curves, smooth, type) {
    offsets <- if (smooth) rep(0, 3) else
      c(-1, 0, 1) * .12 * min(diff(x), diff(graphics::par("usr")[1:2]) / 4)
    for (i in 1:3) {
      if (smooth) {
        graphics::polygon(c(x, rev(x)), c(curves[[i]]$lower, rev(curves[[i]]$upper)),
                          col = paste0(check_colours$simulated, "40"), border = NA)
        graphics::matlines(x, cbind(curves[[i]]$lower, curves[[i]]$upper),
                           col = check_colours$simulation_line, lty = c(2, 1, 3)[i])
      } else graphics::segments(x + offsets[i], curves[[i]]$lower, x + offsets[i],
                                curves[[i]]$upper, col = check_colours$simulated, lwd = 3)
    }
    for (i in 1:3) graphics::lines(x + offsets[i], curves[[i]]$observed,
      type = if (smooth) "l" else type, pch = 16, cex = .65, lty = if (smooth) c(2, 1, 3)[i] else 1,
      lwd = if (i == 2) 2 else 1, col = check_colours$observed)
  }
  draw_pattern <- function(pattern, name = NULL) {
    title <- if (is.null(name)) "PIT quartiles\n(fit across predicted outcomes)"
      else paste0("PIT quartiles by ", name, "\n(fit across predictor values)")
    if (is.null(pattern)) return(plot_check_empty(title, "No available predictor values"))
    graphics::plot(pattern$positions, rep(.5, length(pattern$positions)), type = "n", ylim = c(0, 1),
      xlim = pattern$limits, xaxt = if (pattern$binned) "s" else "n", yaxt = "n", main = title,
      xlab = if (is.null(name)) "Predicted outcome" else name, ylab = "PIT quartiles")
    if (!pattern$binned) graphics::axis(1, pattern$positions, pattern$labels, cex.axis = .8)
    graphics::axis(2, c(0, .25, .5, .75, 1))
    graphics::abline(h = c(.25, .5, .75), lty = 2, col = check_colours$reference)
    draw_quartiles(pattern$positions, pattern$quantiles, pattern$smooth,
                   if (pattern$numeric) "b" else "p")
    key <- if (pattern$smooth) "25th: dashed; median: bold; 75th: dotted."
      else "Quartiles: 25th, median, 75th, left to right."
    plot_check_caption(paste("Blue ranges form one global envelope for this panel.",
      "Above a range: outcomes higher than simulated; below: lower.", key, sep = "\n"))
  }
  for (composition in x$compositions) {
    draw_check <- function(check, role) {
      statistics <- composition$statistics[[role]]
      title <- if (check == "qq") "Uniform QQ\n(overall residual distribution)" else
        "Mean PIT distance\n(overall residual spread)"
      if (is.null(statistics)) return(plot_check_empty(title))
      if (check == "qq") {
        probabilities <- seq(0, 1, length.out = length(statistics$qq$observed))
        graphics::plot(probabilities, probabilities, type = "n", main = title,
                       xlab = "Uniform quantile", ylab = "PIT quantile")
        graphics::polygon(c(probabilities, rev(probabilities)), c(statistics$qq$lower,
          rev(statistics$qq$upper)), col = check_colours$simulated, border = NA)
        graphics::lines(probabilities, statistics$qq$observed, col = check_colours$observed, lwd = 2)
        graphics::abline(0, 1, lty = 2, col = check_colours$reference)
        plot_check_caption("The red curve should roughly follow the diagonal.\nAbove the diagonal: outcomes higher than simulated; below: lower.\nDepartures outside the blue global envelope suggest a distribution mismatch.")
      } else {
        plot_check_statistic(statistics$mean_distance, title, xlab = "Mean distance from PIT 0.5",
          sub = "Mean of 2 * |PIT - 0.5|. Red should usually lie between the dashed limits.\nBeyond right: more extreme residuals; left: more central residuals.\nLocation and spread errors can both affect this distance.")
      }
    }
    plot_check_role_panels(composition, c("qq", "mean_distance"),
      "Residual distribution", draw_check, panels)
    for (i in seq_along(composition$patterns)) {
      name <- if (i == 1L) NULL else x$predictors[i - 1L]
      plot_check_role_panels(composition, "quartiles",
        paste("Residual patterns:", if (is.null(name)) "predicted outcome" else name),
        function(check, role) draw_pattern(composition$patterns[[i]][[role]], name), panels)
    }
  }
  invisible(x)
}

# Rank each row symmetrically, breaking ties randomly and jittering within ranks.
randomized_pit <- function(responses) {
  ranks <- t(apply(responses, 1, rank, ties.method = "random"))
  (ranks - stats::runif(length(ranks))) / ncol(responses)
}
