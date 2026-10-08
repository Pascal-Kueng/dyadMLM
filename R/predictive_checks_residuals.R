#' Check residual distributions and patterns
#'
#' `r lifecycle::badge("experimental")`
#' Check where each observed outcome falls among its simulated values, using
#' complete datasets from [simulate_dyad_responses()].
#' For checks on the outcome scale, use [check_dyad_outcomes()].
#'
#' @param simulations An object from [simulate_dyad_responses()]. At least 200
#'   datasets are required; 1,000 or more are recommended.
#' @param predictors Optional column names, e.g. `c("age", "stress")`, looked up
#'   in the model frame or `data`. Pass predictors the model omits or may
#'   misspecify, especially the partner's. `NULL` (default) omits additional
#'   predictor pages. Missing or infinite values are omitted only from that
#'   predictor's plots.
#' @param seed Seed for randomized PIT residuals. The caller's random-number
#'   state is restored afterwards. With `NULL`, use and advance the caller's RNG.
#' @inheritParams check_partner_dependence
#' @param panels If `TRUE` (default), arrange checks in complete panels by
#'   composition, with one column per role or a pooled column. If `FALSE`, draw
#'   each check and role separately.
#' @param dyad,role,member Column names, with or without quotes, identifying
#'   dyads, roles, and members within dyads. Looked up in the fitted model frame
#'   or `data`. With `role = NULL`, all observations are pooled. Otherwise supply
#'   `dyad`; also supply `member` for repeated observations, with `role` unchanged
#'   within each member.
#' @param data The unchanged data used to fit the model. Supply it when required
#'   columns are absent from the model frame, or to identify compositions using
#'   partners whose responses were excluded during fitting.
#'
#' @return Invisibly returns a `dyadMLM_residual_check` list with the `pit` matrix
#'   and calculated summaries in `compositions`. PIT rows are fitted observations;
#'   columns are observed data followed by all simulated datasets.
#'   Save it with `plot = FALSE` and draw it later with `plot(result)`.
#'
#' @section Reading the plots:
#' Start with everyone pooled (`role = NULL`), then also inspect meaningful
#' roles, such as gender, even when the model treats partners as exchangeable:
#' role-specific problems show only there. Use `predictors` to examine other
#' measured characteristics. For separate QQ plots and summaries by a categorical
#' characteristic, use that variable as `role`.
#'
#' A composition is the combination of partners' roles. Each composition gets
#' one pooled column for same-role partners, or separate columns for distinct
#' roles. Supplying roles does not change the model's assumptions. Unknown
#' compositions are omitted with a warning.
#'
#' The first page shows uniform QQ and mean PIT distance. The second shows PIT
#' quartiles against predicted outcomes. Each supplied predictor gets another
#' page like the second.
#'
#' PIT (probability integral transform) residuals rank each outcome from 0 (low)
#' to 1 (high) relative to its own simulated values. A suitable model should
#' produce ranks roughly evenly spread between 0 and 1, allowing for the
#' variation shown in blue. PIT distance is `2 * abs(PIT - 0.5)`. Blue curve
#' envelopes are nominal 95% global envelopes within each panel, not across
#' roles, predictors, or pages. Because the model was fitted to these same data,
#' departures often look smaller than they are, as in the settings studied by
#' Robins et al. (2000) and in our simulations.
#'
#' Predicted outcomes and numeric predictors with more than eight distinct values
#' are grouped into up to eight bins per role, with at least about 20
#' observations per bin; with four or more bins, quartiles are smoothed across
#' neighboring bins. These are full-model residuals, not partial effects; bins
#' and separate predictors can hide local patterns and interactions.
#'
#' @section Reading flags:
#' A flag is a red value or curve outside its blue range or limits. Each panel
#' alone rarely flags a correct model, but flags add up across panels. In our
#' [simulations](https://pascal-kueng.github.io/dyadMLM/articles/distribution-checks.html)
#' (also used to choose these panels), at least one panel of the residual and
#' outcome checks (ECDFs and category bars not counted) flagged about 6--11% of
#' correct Gaussian and count models when pooled, 16--23% in either role, and
#' 24--31% in either role with actor and partner predictor pages; ordinal models
#' were flagged less often. So look
#' for a consistent pattern, not any single flag. With about 40 dyads, most
#' mismatches studied were hard to detect; no flag does not show a good fit.
#' Panels suggest possible problems, not their cause. Neither a flag nor its
#' absence shows whether estimates or standard errors are wrong: fit the model
#' the pattern suggests and compare the estimates and standard errors you
#' report. Mismatches showed mainly in these panels:
#' - Poisson fitted to overdispersed counts: mean PIT distance, number of zeros, QQ.
#' - Extra zeros: QQ and PIT quartiles; the number of zeros less often.
#' - Omitted role means: QQ and PIT quartiles across predicted outcomes, by role.
#' - Different role SDs: response SD and mean PIT distance, by role.
#' - Spread rising with a predictor: largest absolute deviation, mean PIT distance, QQ.
#' - Omitted partner effect: PIT quartiles across the partner's predictor
#'   (supply it in `predictors` of [check_dyad_residuals()]).
#'
#' @section Scope:
#' Complete simulated datasets keep the fitted partner and time dependence and
#' any modeled differences in variability between roles. Unlike DHARMa's default
#' (since version 0.5.0), simulations redraw all random effects: if held fixed,
#' random effects that absorb all residual variation would reproduce the data
#' almost exactly. Parameters stay fixed at their fitted values; parameter
#' uncertainty is not included. These are descriptive checks, not significance tests, and
#' differ from DHARMa's plots and tests (see the
#' [article](https://pascal-kueng.github.io/dyadMLM/articles/distribution-checks.html#why-not-use-dharma-directly)).
#' They do not directly assess serial correlation.
#'
#' Predicted outcomes set random effects to zero, which differs from averaging
#' over random effects for nonlinear links. Uses the families and fitted rows
#' supported by [simulate_dyad_responses()]; observations have equal weight. For
#' cross-sectional data, check partner correlations with
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
#' role means; not ordinal models), PIT is centred automatically: each dataset's
#' PIT is transformed to normal scores, centred on its median across all fitted
#' rows, and transformed back. Panels then show residuals relative to this
#' overall location, so QQ and mean PIT distance can show less of an overall
#' shift. This offsets part of the conservativeness caused by fitting.
#'
#' Global envelopes use extreme-rank-length ordering (Myllymäki et al., 2017).
#'
#' @references
#' Hartig, F. (2026). DHARMa: Residual Diagnostics for Hierarchical (Multi-Level /
#' Mixed) Regression Models. R package version 0.5.0.
#' \doi{10.32614/CRAN.package.DHARMa}.
#'
#' Dunn, P. K., & Smyth, G. K. (1996). Randomized quantile residuals.
#' *Journal of Computational and Graphical Statistics*, 5(3), 236--244.
#' \doi{10.2307/1390802}.
#'
#' Myllymäki, M., Mrkvička, T., Grabarnik, P., Seijo, H., & Hahn, U. (2017).
#' Global envelope tests for spatial processes. *Journal of the Royal
#' Statistical Society: Series B*, 79(2), 381--404. \doi{10.1111/rssb.12172}.
#'
#' Robins, J. M., van der Vaart, A., & Ventura, V. (2000). Asymptotic
#' distribution of P values in composite null models. *Journal of the American
#' Statistical Association*, 95(452), 1143--1156.
#' \doi{10.1080/01621459.2000.10474310}.
#'
#' @seealso [check_dyad_outcomes()], [check_partner_dependence()]
#' @examplesIf requireNamespace("glmmTMB", quietly = TRUE)
#' model <- glmmTMB::glmmTMB(
#'   closeness ~ gender + provided_support + (1 | coupleID), data = dyads_cross
#' )
#' # Use at least 1,000 simulations when checking a model.
#' simulations <- simulate_dyad_responses(model, nsim = 200, seed = 123)
#' check_dyad_residuals(simulations, dyad = coupleID, role = gender,
#'                      predictors = "provided_support", ask = FALSE)
#' # Save a pooled check without drawing, then plot each figure separately.
#' result <- check_dyad_residuals(simulations, role = NULL,
#'                                predictors = "provided_support", plot = FALSE)
#' plot(result, panels = FALSE, ask = FALSE)
#' @export
check_dyad_residuals <- function(simulations, dyad = NULL, role = NULL, member = NULL,
                                 predictors = NULL, seed = 123, plot = TRUE,
                                 ask = NULL, panels = TRUE, data = NULL) {
  if (!inherits(simulations, "dyadMLM_response_simulations"))
    stop("`simulations` must be created by `simulate_dyad_responses()`.", call. = FALSE)
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
        calculate_residual_pattern(pit, predictor, rows, role_rows))
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

calculate_residual_pattern <- function(pit, predictor, rows, role_rows) {
  # Experiment only: "current", "ranked_bins" (A), "kernel" (B) or "qgam" (C); see
  # also the option dyadMLM.kernel_bandwidth below.
  smoother <- getOption("dyadMLM.residual_smoother", "current")
  available <- available_check_predictor(predictor)
  composition_rows <- unlist(role_rows, use.names = FALSE)
  composition_rows <- composition_rows[available[composition_rows]]
  rows <- rows[available[rows]]
  if (!length(rows)) return(NULL)
  available_values <- predictor[composition_rows]
  binned <- is.numeric(predictor) && length(unique(available_values)) > 8
  ranked <- binned && smoother != "current"
  if (ranked) {
    # Ranks shared by all roles spread observations evenly along the axis, so
    # the long tail of a skewed predictor does not take up most of it.
    ticks <- signif(stats::quantile(available_values, 0:4 / 4, names = FALSE), 2)
    ticks[duplicated(ticks)] <- ""
    available_values <- (rank(available_values) - .5) / length(available_values)
    predictor[composition_rows] <- available_values
  }
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
  labels <- if (ranked) ticks else if (is.numeric(predictor)) format(positions, trim = TRUE)
    else names(rows_by_group)
  limits <- if (is.numeric(predictor)) range(available_values) else range(positions)
  padding <- if (is.numeric(predictor)) {
    if (!binned && length(positions) > 1) .2 * min(diff(positions)) else 0
  } else .45
  # (C) uses the same rule and grid as (B).
  kernel <- ranked && smoother %in% c("kernel", "qgam")
  # (B) needs no bins, only enough observations and more than one value.
  smooth <- binned && (if (kernel) length(rows) >= 80 && length(positions) > 1
                       else length(positions) >= 4)
  if (smooth) {
    grid <- seq(min(predictor[rows]), max(predictor[rows]), length.out = 101)
    # (B) weights each observation, with a bandwidth that is a fixed share of the
    # role's rank range; otherwise bin quartiles are weighted, with the bin spacing.
    centres <- if (kernel) predictor[rows] else positions
    bandwidth <- if (kernel) getOption("dyadMLM.kernel_bandwidth", .2) * diff(range(grid))
      else stats::median(diff(positions))
    # Fixed positive weights keep quartiles ordered and within 0--1.
    log_weights <- -.5 * (outer(grid, centres, "-") / bandwidth)^2
    weights <- exp(log_weights - apply(log_weights, 1, max))
    weights <- weights / rowSums(weights)
  }
  curves <- if (smooth && smoother == "qgam") {
    qgam_quartiles(pit[rows, , drop = FALSE], predictor[rows], grid)
  } else if (smooth && kernel) {
    # A light second pass over about three grid steps removes small steps where
    # residuals near a quartile are sparse.
    second <- exp(-.5 * (outer(seq_along(grid), seq_along(grid), "-") / 3)^2)
    kronecker(diag(3), second / rowSums(second)) %*%
      kernel_quartiles(pit[rows, , drop = FALSE], weights)
  } else {
    quartiles <- lapply(rows_by_group, function(group_rows) {
      apply(pit[intersect(rows, group_rows), , drop = FALSE], 2,
            stats::quantile, probs = c(.25, .5, .75), names = FALSE)
    })
    do.call(rbind, lapply(1:3, function(i) {
      values <- do.call(rbind, lapply(quartiles, function(group) group[i, ]))
      if (smooth) weights %*% values else values
    }))
  }
  # One envelope covers all three quartiles and positions in this panel.
  joint <- residual_curve_summary(curves)
  positions_per_curve <- nrow(curves) / 3
  quantiles <- lapply(1:3, function(i) {
    indices <- seq_len(positions_per_curve) + (i - 1L) * positions_per_curve
    lapply(joint, `[`, indices)
  })
  list(positions = if (smooth) grid else positions, labels = labels,
       limits = limits + c(-padding, padding), binned = binned, smooth = smooth,
       numeric = is.numeric(predictor), ranked = ranked, quantiles = quantiles)
}

# Weighted quartiles of each dataset (columns of `values`) at each grid point
# (rows of `weights`, each summing to one). As for type 5 quantiles, each sorted
# value sits at the middle of its weight, and quartiles interpolate between values.
kernel_quartiles <- function(values, weights) {
  weights <- t(weights)
  n <- nrow(weights)
  points <- rep(seq_len(ncol(weights)), 3)
  probabilities <- rep(c(.25, .5, .75), each = ncol(weights))
  # One running sum over all columns; earlier columns add one each.
  earlier <- rep(seq_len(ncol(weights)) - 1, each = n)
  apply(values, 2, function(x) {
    order <- order(x)
    x <- x[order]
    sorted <- weights[order, , drop = FALSE]
    middle <- cumsum(sorted) - earlier - sorted / 2
    below <- c(colSums(middle < .25), colSums(middle < .5), colSums(middle < .75))
    k <- pmin(pmax(below, 1), n - 1)
    lower <- middle[cbind(k, points)]
    fraction <- (probabilities - lower) / (middle[cbind(k + 1, points)] - lower)
    x[k] + pmin(pmax(fraction, 0), 1) * (x[k + 1] - x[k])
  })
}

# (C) DHARMa's quantile lines (DHARMa::testQuantiles with rank = TRUE): qgam fitted
# to the observed residuals with its own tuning. Simulated datasets reuse that
# tuning: learning rate (lsig), err and smoothing parameter (sp). Returns the
# three quartile lines stacked, one column per dataset.
qgam_quartiles <- function(values, x, grid) {
  k <- min(length(unique(x)), 10)
  do.call(rbind, lapply(c(.25, .5, .75), function(q) {
    fit <- function(residuals, ...) {
      utils::capture.output(model <- qgam::qgam(res ~ s(pred, k = k),
        data = data.frame(res = residuals - q, pred = x), qu = q, ...))
      model
    }
    observed <- fit(values[, 1])
    vapply(seq_len(ncol(values)), function(dataset) {
      model <- if (dataset == 1L) observed else fit(values[, dataset], lsig = observed$calibr$lsig,
        err = observed$calibr$err, argGam = list(sp = observed$sp))
      as.numeric(stats::predict(model, data.frame(pred = grid))) + q
    }, numeric(length(grid)))
  }))
}

#' @export
print.dyadMLM_residual_check <- function(x, ...) {
  print_check_overview(x, "residual check", x$predictors)
}

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
      xlim = pattern$limits, xaxt = if (pattern$binned && !pattern$ranked) "s" else "n",
      yaxt = "n", main = title, ylab = "PIT quartiles",
      xlab = paste0(if (is.null(name)) "Predicted outcome" else name, if (pattern$ranked) " (ranked)"))
    if (!pattern$binned) graphics::axis(1, pattern$positions, pattern$labels, cex.axis = .8)
    if (pattern$ranked) graphics::axis(1, 0:4 / 4, pattern$labels)
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
          sub = "Mean of 2 * |PIT - 0.5|; red should usually lie between the dashed limits.\nBeyond right: more extreme residuals; left: more central residuals.\nLocation and spread errors can both affect this distance.")
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
