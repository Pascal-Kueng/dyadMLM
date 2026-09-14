### Checking partner dependence -----------------------------------------------

#' Check whether a fitted model reproduces partner dependence
#'
#' `r lifecycle::badge("experimental")`
#' A dyadic model should reproduce how much responses vary and how strongly
#' partners' responses are related. This check computes variances and correlations
#' of simulated responses based on the model and compares them to the observed
#' response variances and correlations from the data.
#' This helps identify mismatches in the model's assumptions.
#'
#' @param simulations An object returned by [simulate_dyad_responses()].
#' @param dyad A column name in the fitted data, or a vector
#'   of dyad IDs in the same row order. Columns take precedence. You may use
#'   `.env$ids` to select an external vector explicitly.
#' @param role A column name in the fitted data, or a vector of roles in the
#'   same row order. Use `NULL` (default) when members should be treated as
#'   exchangeable. Roles can be supplied even if they were not included
#'   in the model, to check for mismatches in each role's variance and
#'   the partner correlation.
#' @param plot If `TRUE` (default), draw the comparison plots for visual checks.
#' @param response `"model-centred"` (default) subtracts the same model predictions
#'   from observed and simulated responses. The predictive check then assesses
#'   whether the model reproduces the variance and partner correlations remaining
#'   after accounting for its fixed-effect predictions. This includes random
#'   effects and observation-level noise. With `"raw"`, the predictive check
#'   assesses whether the full model, including fixed effects, reproduces the
#'   overall response variances and partner correlations.
#'   See [simulate_dyad_responses()] for how predictions are defined.
#'
#' @return The comparison plots (shown by default) are the main output. The
#'   function invisibly returns a `dyadMLM_partner_check` object containing the
#'   statistics, pair and omission counts, and settings. The returned object
#'   can be stored and plotted again later.
#'   See [print.dyadMLM_partner_check()] for details of the numerical output.
#'
#' @section Reading the plots:
#' Histograms show simulated summaries. Red lines mark observed values.
#' Dashed lines enclose the middle 95% of simulations (no formal confidence
#' intervals).
#'
#' An observed value far from most simulated values may indicate that the
#' model does not reproduce that feature of the data well.
#'
#' The first set of plots compares:
#' - **Response SDs:** one for each role, or one common SD for exchangeable members.
#' - **Partner correlation:** how strongly partners' responses are related.
#'
#' The second set shows *the same information* using dyad averages and partner
#' differences:
#' - **Dyad-average SD:** how much dyads differ in their average response.
#' - **Half-difference SD or RMS:** each partner difference is divided by two.
#'   With roles, the SD shows how much these signed differences vary across
#'   dyads. Without roles, the RMS shows their typical size, regardless of
#'   partner order.
#' - **Mean/difference correlation:** plotted only when roles are supplied,
#'   because it depends on how partners are ordered. Positive values indicate
#'   greater variance for the first named role. Negative values indicate greater
#'   variance for the second.
#'
#' These checks are particularly useful when a simpler model is needed and a
#' less restricted model does not converge and can't be
#' used for model comparison. It shows how well the simpler model
#' reproduces the observed variances and partner correlations.
#'
#' Rows with missing IDs or roles and incomplete dyads are omitted with a warning.
#' Their counts are shown when printing the result.
#'
#' @section Technical details:
#' After any centring, paired responses `a` and `b` are used to compute
#' dyad averages `M = (a + b) / 2` and half-differences `D = (a - b) / 2`.
#' Roles follow factor levels or sorted values.
#'
#' Without roles, common member variance is `var(M) + mean(D^2)` and
#' partner covariance is `var(M) - mean(D^2)`. Partner correlation is
#' covariance divided by variance. Half-difference RMS is `sqrt(mean(D^2))`.
#'
#' The variance and covariance calculations for exchangeable dyads follow
#' Woody and Sadler (2005).
#'
#' @examplesIf requireNamespace("glmmTMB", quietly = TRUE)
#' example_data <- dyads_cross[dyads_cross$coupleID <= 40, ]
#'
#' model <- glmmTMB::glmmTMB(
#' closeness ~ 1 + gender + (1 | coupleID),
#'   data = example_data
#' )
#'
#' # Fewer simulations for a quick example (the default is 1000).
#' simulations <- simulate_dyad_responses(model, nsim = 50, seed = 123)
#'
#' check <- check_partner_dependence(
#'   simulations,
#'   dyad = coupleID,
#'   role = gender,
#'   plot = FALSE
#' )
#'
#' print(check)
#' plot(check, ask = FALSE)
#'
#' @references Woody, E., & Sadler, P. (2005). Structural equation models for
#'   interchangeable dyads: Being the same makes a difference. *Psychological
#'   Methods, 10*(2), 139-158. \doi{10.1037/1082-989X.10.2.139}.
#'
#' Gelman, A., Meng, X.-L., & Stern, H. S. (1996). Posterior predictive
#' assessment of model fitness via realized discrepancies. *Statistica Sinica,
#' 6*, 733-807.
#'
#' @export
check_partner_dependence <- function(
  simulations, dyad, role = NULL, plot = TRUE,
  response = c("model-centred", "raw")
) {
  if (!inherits(simulations, "dyadMLM_response_simulations")) {
    stop("`simulations` must be created by `simulate_dyad_responses()`.", call. = FALSE)
  }
  if (missing(dyad)) {
    stop("`dyad` must identify the dyad for each fitted row.", call. = FALSE)
  }
  response <- match.arg(response)
  frame <- simulations$model_frame
  pairs <- prepare_partner_pairs(
    resolve_fitted_row_argument(rlang::enquo(dyad), "dyad", frame),
    resolve_fitted_row_argument(rlang::enquo(role), "role", frame, allow_null = TRUE)
  )

  # pairs$rows has one row per complete dyad and one column per partner.
  # Subtract the same fitted-row predictions from every dataset (or 0 for raw).
  center <- if (response == "model-centred") simulations$predicted_response else 0
  statistic <- function(y) {
    y <- y - center
    return(calculate_partner_pair_statistics(
      y[pairs$rows[, 1]], y[pairs$rows[, 2]],
      role_specific = !is.null(pairs$role_order)
    ))
  }
  # Apply the same statistic to observed responses and each simulation.
  # observed has 4 or 6 named values; replicated has one row per simulation.
  observed <- statistic(simulations$observed_response)
  replicated <- t(apply(unname(simulations$simulated_responses), 1, statistic))

  # Table rows and simulation columns use the same statistic order.
  # Keep both: the table supplies labels/limits, the matrix supplies histograms.
  result <- list(
    statistics_table = cbind(partner_statistic_info(pairs$role_order),
                             summarize_simulation_reference(observed, replicated)),
    replicated_statistics = replicated, role_order = as.character(pairs$role_order),
    n_pairs = nrow(pairs$rows),
    n_incomplete_dyads = pairs$n_incomplete_dyads,
    n_missing_dyad_rows = pairs$n_missing_dyad_rows,
    n_missing_role_rows = pairs$n_missing_role_rows,
    response = response
  )
  attr(result, "dyadMLM") <- attr(simulations, "dyadMLM")
  class(result) <- c("dyadMLM_partner_check", "list")
  if (any(c(result$n_incomplete_dyads, result$n_missing_dyad_rows,
            result$n_missing_role_rows) > 0)) {
    warning("Incomplete dyads or rows with missing IDs or roles were omitted. ",
            "Print the result for counts.", call. = FALSE)
  }
  if (plot) graphics::plot(result)
  return(invisible(result))
}


### Matching partners ---------------------------------------------------------

# Build the pair map once; reuse it for observed and simulated responses.
prepare_partner_pairs <- function(dyad_values, role_values = NULL) {
  # Also recognize explicit NA factor levels without dropping unused levels.
  missing_dyad <- is.na(dyad_values) | is.na(as.character(dyad_values))
  missing_role <- if (is.null(role_values)) rep(FALSE, length(dyad_values)) else
    !missing_dyad & (is.na(role_values) | is.na(as.character(role_values)))
  # Match IDs directly; factor labels can round distinct large numeric IDs alike.
  dyad_id <- match(dyad_values, unique(dyad_values))
  # rows is a list of fitted-row positions per dyad, e.g. list(c(1, 4), c(2, 3)).
  rows <- split(which(!missing_dyad), dyad_id[!missing_dyad])
  # Check before dropping missing roles, which must not hide repeated observations.
  if (any(lengths(rows) > 2L)) {
    stop("Each dyad must have at most two fitted responses after rows with ",
         "missing dyad IDs are omitted.", call. = FALSE)
  }
  rows <- lapply(rows, function(i) i[!missing_role[i]])
  n_incomplete <- sum(lengths(rows) < 2L)
  rows <- rows[lengths(rows) == 2L]
  if (length(rows) < 3L) {
    stop("At least three complete dyads are required to check partner dependence.",
         call. = FALSE)
  }
  # pairs indexes retained fitting rows, not row numbers in the original data.
  pairs <- matrix(unlist(rows, use.names = FALSE), ncol = 2L, byrow = TRUE)

  role_order <- NULL
  if (!is.null(role_values)) {
    role_order <- if (is.factor(role_values)) {
      levels(droplevels(role_values[pairs]))
    } else {
      sort(unique(role_values[pairs]))
    }
    if (length(role_order) != 2L) {
      stop("Exactly two role values are required among the complete dyads.", call. = FALSE)
    }
    if (any(role_values[pairs[, 1]] == role_values[pairs[, 2]])) {
      stop("Each complete dyad must contain exactly one row for each role value.",
           call. = FALSE)
    }
    # Each pair has both roles; put the first role in column 1.
    reverse <- role_values[pairs[, 1]] != role_order[1]
    pairs[reverse, ] <- pairs[reverse, 2:1, drop = FALSE]
  }
  return(list(
    rows = pairs, role_order = role_order,
    n_incomplete_dyads = n_incomplete, n_missing_dyad_rows = sum(missing_dyad),
    n_missing_role_rows = sum(missing_role)
  ))
}


### Calculating paired statistics ---------------------------------------------

# first and second are paired numeric vectors: one value per complete dyad.
# Returned names identify table rows and replicated-statistic columns.
# Correlations are undefined with zero variance; the reference summary reports
# them once.
calculate_partner_pair_statistics <- function(first, second, role_specific) {
  dyad_mean <- (first + second) / 2
  half_difference <- (first - second) / 2
  if (role_specific) {
    return(c(
      role_1_sd = stats::sd(first),
      role_2_sd = stats::sd(second),
      partner_correlation = suppressWarnings(stats::cor(first, second)),
      dyad_mean_sd = stats::sd(dyad_mean),
      half_difference_sd = stats::sd(half_difference),
      dyad_mean_half_difference_correlation = suppressWarnings(stats::cor(
        dyad_mean, half_difference
      ))
    ))
  }

  # Exchangeability sets the expected half-difference to zero. Its mean square
  # about zero is unchanged by arbitrary within-dyad member swaps.
  dyad_mean_variance <- stats::var(dyad_mean)
  half_difference_mean_square <- mean(half_difference^2)
  member_variance <- dyad_mean_variance + half_difference_mean_square
  return(c(
    exchangeable_member_sd = sqrt(member_variance),
    exchangeable_partner_correlation =
      (dyad_mean_variance - half_difference_mean_square) / member_variance,
    dyad_mean_sd = sqrt(dyad_mean_variance),
    half_difference_rms = sqrt(half_difference_mean_square)
  ))
}


### Statistic labels ----------------------------------------------------------

# One table row per summary, in calculate_partner_pair_statistics() order.
# The first half belongs to the member view; the second to the mean/difference view.
partner_statistic_info <- function(role_order = NULL) {
  labels <- if (is.null(role_order)) {
    c(
      exchangeable_member_sd = "Common member SD (exchangeable)",
      exchangeable_partner_correlation = "Partner correlation (exchangeable)",
      dyad_mean_sd = "Dyad-average SD",
      half_difference_rms = "Half-difference RMS (about zero)"
    )
  } else {
    difference <- paste(role_order[[1L]], "minus", role_order[[2L]])
    c(
      role_1_sd = paste0("SD (", role_order[[1L]], ")"),
      role_2_sd = paste0("SD (", role_order[[2L]], ")"),
      partner_correlation = paste0(
        "Partner correlation (", role_order[[1L]], " and ", role_order[[2L]], ")"
      ),
      dyad_mean_sd = "Dyad-average SD",
      half_difference_sd = paste0("Half-difference SD (", difference, ")"),
      dyad_mean_half_difference_correlation = paste0(
        "Dyad-average/role-difference correlation (", difference, ")"
      )
    )
  }

  return(data.frame(
    statistic_name = names(labels),
    parameterization = rep(
      c("member", "mean_difference"), each = length(labels) / 2L
    ),
    label = unname(labels)
  ))
}


### Summarizing the simulation reference ---------------------------------------

# Finite responses can still give undefined correlations (e.g. constant counts).
# Summarize each statistic using its defined draws, and report how many remain.
summarize_simulation_reference <- function(observed, replicated) {
  if (any(!is.finite(observed))) {
    stop("Observed partner-dependence summaries are undefined: ",
         paste(names(observed)[!is.finite(observed)], collapse = ", "),
         ". This can occur with zero variance.", call. = FALSE)
  }
  # One vector per statistic; lengths can differ when some draws are undefined.
  defined <- lapply(seq_along(observed), function(i) {
    values <- replicated[, i]
    return(values[is.finite(values)])
  })
  n_defined <- lengths(defined)
  if (any(n_defined == 0L)) {
    stop("Every simulated value is undefined for: ",
         paste(names(observed)[n_defined == 0L], collapse = ", "),
         ". A predictive reference cannot be calculated.", call. = FALSE)
  }
  n_undefined <- nrow(replicated) - n_defined
  if (any(n_undefined > 0L)) {
    warning("Undefined simulated summaries (counts out of ", nrow(replicated),
            "): ", paste(names(observed)[n_undefined > 0L],
                         n_undefined[n_undefined > 0L],
                         sep = " = ", collapse = "; "),
            ". References use defined values only; inspect their counts.", call. = FALSE)
  }
  # Each quantiles column contains lower, median, upper for one statistic.
  quantiles <- matrix(NA_real_, nrow = 3, ncol = length(defined))
  positions <- numeric(length(defined))
  for (i in seq_along(defined)) {
    values <- defined[[i]]
    quantiles[, i] <- stats::quantile(values, probs = c(0.025, 0.5, 0.975), names = FALSE)
    positions[i] <- (1 + sum(values <= observed[i])) / (n_defined[i] + 1)
  }
  return(data.frame(
    observed_value = unname(observed),
    replicated_median = quantiles[2, ], replicated_lower = quantiles[1, ],
    replicated_upper = quantiles[3, ], observed_quantile = positions,
    n_defined = n_defined
  ))
}


### Printing results ----------------------------------------------------------

#' Print a partner-dependence predictive check
#'
#' Prints a named list of summaries, each showing the observed value,
#' simulated median, middle 95% limits, observed position, and simulation count.
#'
#' @param x An object returned by [check_partner_dependence()].
#' @param digits Number of decimal places used for rounding.
#' @param ... Not used.
#'
#' @return `x`, invisibly.
#'
#' @section Observed position:
#' `observed_quantile` describes the observed value's position among the defined
#' simulated values for each summary. It is calculated as
#' `(1 + sum(simulated <= observed)) / (n_defined + 1)`, where `n_defined`
#' counts these simulated values. This is not a p-value. Ties can give high
#' positions even with good agreement.
#'
#' @keywords internal
#'
#' @export
print.dyadMLM_partner_check <- function(x, digits = 3, ...) {
  meta <- attr(x, "dyadMLM")
  nsim <- nrow(x$replicated_statistics)
  table <- x$statistics_table
  cat("<dyadMLM partner-dependence check>\n")
  cat(nrow(table), "statistics using", x$n_pairs, "complete pairs\n")
  cat("Response: ", x$response, "\n", sep = "")
  cat("Reference: ", nsim, " ", meta$reference, " datasets with ",
      meta$random_effects, " random effects\n", sep = "")

  omitted_counts <- c(
    "incomplete dyads" = x$n_incomplete_dyads,
    "rows with missing dyad IDs" = x$n_missing_dyad_rows,
    "rows with missing roles" = x$n_missing_role_rows
  )
  omitted_counts <- omitted_counts[omitted_counts > 0L]
  if (length(omitted_counts) > 0L) {
    cat("Omitted: ", paste0(names(omitted_counts), ": ", omitted_counts,
                           collapse = "; "), "\n", sep = "")
  }

  values <- table[c("observed_value", "replicated_median", "replicated_lower",
                    "replicated_upper", "observed_quantile", "n_defined")]
  names(values) <- c("Observed", "Median", "2.5%", "97.5%", "Position", "Defined")
  # One small table per statistic keeps long labels out of the numeric columns.
  summaries <- split(round(values, digits), seq_len(nrow(values)))
  names(summaries) <- table$label
  print(summaries)
  invisible(x)
}


### Plotting results ----------------------------------------------------------

#' Plot partner-dependence predictive checks
#'
#' `r lifecycle::badge("experimental")`
#' Plots all summaries in a saved [check_partner_dependence()] result.
#' Each histogram shows simulated summary values; the red line marks the
#' observed value and dashed lines mark the middle 95% of simulations.
#'
#' @param x A `dyadMLM_partner_check` object.
#' @param ask Whether to pause before drawing the next plot. `NULL` chooses
#'   automatically in interactive sessions. Supply `TRUE` or `FALSE` to
#'   override it.
#' @param ... Additional graphical arguments passed to [graphics::plot()].
#'   `freq`, `xlim`, `ylim`, `main`, `sub`, and `xlab` are controlled by this
#'   method.
#'
#' @return Invisibly, `x`.
#'
#' @section Quick start:
#' With a result saved as `check`:
#' \preformatted{
#' plot(check, ask = FALSE)
#' }
#' Both views are shown. The subtitle identifies model-centred or raw
#' responses. Set `ask = FALSE` to draw without pausing between plots.
#'
#' @section Interpretation:
#' Values near or beyond the dashed lines may flag poor agreement. This is a
#' descriptive comparison, not a pass/fail test. Close agreement is expected
#' for features the model freely estimated. See [check_partner_dependence()]
#' for interpretation and a complete example.
#'
#' @section Technical details:
#' Plots use stored summary values; they do not simulate or refit the model.
#' The two views express the same covariance information, so they are not
#' independent checks.
#'
#' @export
plot.dyadMLM_partner_check <- function(x, ask = NULL, ...) {
  if (is.null(ask)) {
    ask <- nrow(x$statistics_table) > 1L && grDevices::dev.interactive()
  }
  previous_ask <- grDevices::devAskNewPage(ask)
  on.exit(grDevices::devAskNewPage(previous_ask), add = TRUE)
  nsim <- nrow(x$replicated_statistics)
  breaks <- min(100L, max(20L, round(nsim / 5)))

  # Each table row names a replicated_statistics column: one scalar per simulation.
  for (i in seq_len(nrow(x$statistics_table))) {
    statistic <- x$statistics_table[i, ]
    draws <- x$replicated_statistics[, statistic$statistic_name]
    histogram <- graphics::hist(draws[is.finite(draws)], breaks = breaks, plot = FALSE)
    height <- max(histogram$counts)
    limits <- c(statistic$replicated_lower, statistic$replicated_upper)

    # Keep complete bars visible and reserve a band above them for the legend.
    graphics::plot(
      histogram, freq = TRUE,
      xlim = range(statistic$observed_value, histogram$breaks),
      ylim = c(0, height * 1.25), main = statistic$label,
      sub = paste0(x$response, "; ", x$n_pairs, " pairs; ",
                   statistic$n_defined, "/", nsim, " defined simulations"),
      xlab = "Summary value", ...
    )
    graphics::segments(limits, 0, limits, height, lty = 2, col = "grey40")
    graphics::segments(statistic$observed_value, 0, statistic$observed_value,
                       height, lwd = 2.5, col = "red")
    graphics::legend(
      "top", legend = c("Observed", "Middle 95% of simulations"),
      lty = c(1, 2), lwd = c(2.5, 1), col = c("red", "grey40"),
      horiz = TRUE, bty = "n"
    )
  }
  invisible(x)
}
