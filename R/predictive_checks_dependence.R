#' Check whether a fitted model reproduces partner dependence
#'
#' `r lifecycle::badge("experimental")`
#' Checks whether a fitted model reproduces how much partners' responses vary
#' and how strongly they are related. It compares the observed data with
#' datasets generated from the fitted model.
#'
#' @param simulations An object returned by [simulate_dyad_responses()].
#' @param dyad An unquoted or quoted column name in the fitted data, or a
#'   vector identifying the dyad for each fitted row. See Technical details.
#' @param role Member roles, supplied in the same way as `dyad`. Use `NULL`
#'   (the default) only when members can be treated as interchangeable.
#' @param plot Logical. If `TRUE` (the default), draw the diagnostic plots.
#' @param response `"model-centred"` (the default) subtracts the model's
#'   prediction with random effects set to zero. `"raw"` uses responses
#'   unchanged. The same choice applies to observed and simulated data.
#'
#' @return A `dyadMLM_partner_check` object, returned invisibly. Assign it to
#'   a variable, print it for numeric summaries, or plot it again without
#'   repeating the simulations.
#'
#' @section Quick start:
#' For a fitted model containing `coupleID` and `gender` columns:
#' \preformatted{
#' simulations <- simulate_dyad_responses(model, seed = 123)
#' check <- check_partner_dependence(simulations, dyad = coupleID, role = gender)
#' check
#' }
#' This draws the plots and prints the comparison. Set `plot = FALSE` to save
#' the result without plotting. A complete fitting example appears below.
#'
#' @section Reading the result:
#' The histogram shows simulated values, the red line marks the observed value,
#' and dashed lines enclose the middle 95% of simulations. The printed table
#' also gives the observed position among simulations on a 0–1 scale.
#' A position near either end may flag poor agreement, but ties can also give
#' a position near 1. Read it alongside the histogram. These comparisons are
#' descriptive, not p-values, confidence intervals, or a pass/fail test.
#'
#' The check is most useful for assumptions such as equal variation in both
#' roles or no remaining partner relationship. If the model freely estimated
#' a feature from these data, close agreement is expected and alone provides
#' little evidence of fit.
#'
#' @section Roles and data:
#' Supply `role` when the member distinction is meaningful. Without it,
#' summaries treat members as interchangeable and are unchanged by swapping
#' their positions within any dyad.
#'
#' Use cross-sectional simulations from [simulate_dyad_responses()], with at
#' most two fitted rows per dyad and at least three complete dyads. With roles,
#' each complete dyad must contain one member of each of exactly two roles.
#' Missing identifiers and incomplete dyads are omitted and counted.
#'
#' @section Technical details:
#' **Reference and centring.** Fitted parameters and predictors stay fixed;
#' every simulation redraws random effects and responses. The model is not
#' refitted and parameter uncertainty is excluded (a plug-in predictive
#' reference). Model-centred values are `response - response_center`, using the
#' same zero-random-effect prediction in every dataset. Random-effect variation
#' remains. These are not conditional or PIT residuals. With nonlinear links,
#' the centre is generally not the mean averaged over random effects, and the
#' subtraction does not provide a residual covariance decomposition.
#'
#' **Summaries.** With roles, the six summaries are each role's SD, their
#' correlation, the SDs of dyad means and half-differences, and the
#' mean/half-difference correlation. The half-difference is `(role1 - role2) / 2`.
#' Roles follow factor-level order, or sorted values otherwise; reversing them
#' reverses the last correlation.
#'
#' Without roles, the four summaries are common member SD, partner correlation,
#' dyad-mean SD, and half-difference RMS about zero. For dyad means `M` and
#' half-differences `D`, the common variance is `var(M) + mean(D^2)` and partner
#' covariance is `var(M) - mean(D^2)`. Covariance divided by variance gives
#' partner correlation.
#' This follows Woody and Sadler (2005). Both views express the same covariance
#' information and are not independent checks. The predictive comparison
#' follows the replicated-data principle of Gelman, Meng, and Stern (1996).
#'
#' **Output and undefined values.** `statistics_table` contains one row per
#' summary; `replicated_statistics` is a matrix with `nsim` rows and one column
#' per summary. Each table row gives the observed value, simulated median and
#' middle 95% limits, the count `n_defined`, and `observed_quantile`:
#' `(1 + sum(defined_simulations <= observed)) / (n_defined + 1)`.
#' Undefined simulated values remain in the matrix. Partially undefined
#' summaries produce one warning and use only defined draws for each reference.
#' This occurs with sparse responses; interpret the reference alongside its
#' count. An undefined observed summary or entirely undefined reference causes
#' an error. The object also records roles, pair and omission counts, the
#' response choice, model metadata, and seed.
#'
#' **Identifier arguments.** Columns in the fitted model frame take precedence
#' over names in the calling environment. Use `.data$column` or
#' `.data[[column_name]]` for explicit column selection, and `.env$vector` for
#' an external vector already aligned with retained fitted rows. Wrappers can
#' forward arguments with `{{ dyad }}` and `{{ role }}`.
#'
#' @examples
#' if (requireNamespace("glmmTMB", quietly = TRUE)) {
#'   example_data <- dyads_cross[dyads_cross$coupleID <= 40, ]
#'   model <- glmmTMB::glmmTMB(
#'     closeness ~ gender + (1 | coupleID),
#'     data = example_data
#'   )
#'
#'   # Use fewer simulations for a quick example; the default is 1000.
#'   simulations <- simulate_dyad_responses(model, nsim = 50, seed = 123)
#'   check <- check_partner_dependence(
#'     simulations,
#'     dyad = coupleID,
#'     role = gender,
#'     plot = FALSE
#'   )
#'   print(check)
#'   plot(check, parameterization = "member", ask = FALSE)
#' }
#'
#' @references Woody, E., & Sadler, P. (2005). Structural equation models for
#'   interchangeable dyads: Being the same makes a difference. *Psychological
#'   Methods, 10*(2), 139-158.
#'   \doi{10.1037/1082-989X.10.2.139}.
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

  # center is a fitted-row vector, or scalar 0 for raw responses. This closure
  # applies the same subtraction and fixed pair map to every response dataset.
  center <- if (response == "model-centred") simulations$response_center else 0
  statistic <- function(y) {
    y <- y - center
    calculate_partner_pair_statistics(
      y[pairs$paired_row_indices[, 1]], y[pairs$paired_row_indices[, 2]],
      role_specific = length(pairs$role_order) > 0L
    )
  }
  # observed is a named vector of 4 (exchangeable) or 6 (role-specific) summaries.
  # replicated has nsim rows and matching summary columns, including undefined values.
  observed <- statistic(simulations$observed_response)
  replicated <- t(vapply(seq_len(simulations$nsim), function(i) {
    statistic(simulations$simulated_responses[i, ])
  }, observed))

  # cbind() matches by position: labels and numerical summaries must share an order.
  # The table supplies plot labels/limits; replicated columns supply the plotted draws.
  result <- structure(list(
    statistics_table = cbind(partner_statistic_schema(pairs$role_order),
                             summarize_simulation_reference(observed, replicated)),
    replicated_statistics = replicated, role_order = as.character(pairs$role_order),
    n_pairs = nrow(pairs$paired_row_indices),
    n_incomplete_dyads = pairs$n_incomplete_dyads,
    n_missing_dyad_rows = pairs$n_missing_dyad_rows,
    n_missing_role_rows = pairs$n_missing_role_rows,
    response = response, backend = simulations$backend,
    family = simulations$family, link = simulations$link,
    reference = simulations$reference, random_effects = simulations$random_effects,
    parameter_uncertainty = simulations$parameter_uncertainty,
    nsim = simulations$nsim, seed = simulations$seed, call = match.call()
  ), class = c("dyadMLM_partner_check", "list"))
  if (plot) graphics::plot(result)
  invisible(result)
}


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
  # pairs is n_pairs x 2, indexing retained responses, not original-data row numbers.
  # When roles are supplied, the loop below aligns its columns with role_order.
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
    for (i in seq_len(nrow(pairs))) {
      order <- match(role_order, role_values[pairs[i, ]])
      if (anyNA(order)) {
        stop("Each complete dyad must contain exactly one row for each role value.",
             call. = FALSE)
      }
      pairs[i, ] <- pairs[i, order]
    }
  }
  list(paired_row_indices = pairs, role_order = role_order,
       n_incomplete_dyads = n_incomplete, n_missing_dyad_rows = sum(missing_dyad),
       n_missing_role_rows = sum(missing_role))
}


# first and second are paired numeric vectors: one value per complete dyad.
# Returned names identify table rows and replicated-statistic columns.
# Zero-spread correlations are undefined; the reference summary reports them once.
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
  c(
    exchangeable_member_sd = sqrt(member_variance),
    exchangeable_partner_correlation =
      (dyad_mean_variance - half_difference_mean_square) / member_variance,
    dyad_mean_sd = sqrt(dyad_mean_variance),
    half_difference_rms = sqrt(half_difference_mean_square)
  )
}


# One table row per summary, in calculate_partner_pair_statistics() order.
# The first half belongs to the member view; the second to the mean/difference view.
partner_statistic_schema <- function(role_order = NULL) {
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

  data.frame(
    statistic_name = names(labels),
    parameterization = rep(
      c("member", "mean_difference"), each = length(labels) / 2L
    ),
    label = unname(labels)
  )
}


# observed_statistics is a named length-K vector; replicated_statistics is nsim x K.
# Their statistic order agrees; each returned table row summarizes one reference.
summarize_simulation_reference <- function(observed_statistics, replicated_statistics) {
  if (any(!is.finite(observed_statistics))) {
    stop("Observed partner-dependence summaries are undefined: ",
         paste(names(observed_statistics)[!is.finite(observed_statistics)], collapse = ", "),
         ". The observed response has insufficient variation.", call. = FALSE)
  }
  # A length-K list of finite draws; elements may differ in length. Filtering
  # separately keeps usable draws for other statistics when one is undefined.
  defined <- lapply(seq_along(observed_statistics), function(i) {
    values <- replicated_statistics[, i]
    values[is.finite(values)]
  })
  n_defined <- lengths(defined)
  if (any(n_defined == 0L)) {
    stop("Every simulated value is undefined for: ",
         paste(names(observed_statistics)[n_defined == 0L], collapse = ", "),
         ". A predictive reference cannot be calculated.", call. = FALSE)
  }
  n_undefined <- nrow(replicated_statistics) - n_defined
  if (any(n_undefined > 0L)) {
    warning("Undefined simulated summaries (counts out of ", nrow(replicated_statistics),
            "): ", paste(names(observed_statistics)[n_undefined > 0L],
                         n_undefined[n_undefined > 0L],
                         sep = " = ", collapse = "; "),
            ". References use defined values only; inspect their counts.", call. = FALSE)
  }
  # quantiles is 3 x K (lower, median, upper); positions is a length-K vector.
  quantiles <- vapply(defined, stats::quantile, numeric(3),
                   probs = c(0.025, 0.5, 0.975), names = FALSE)
  positions <- vapply(seq_along(defined), function(i) {
    (1 + sum(defined[[i]] <= observed_statistics[[i]])) / (n_defined[[i]] + 1)
  }, numeric(1))
  data.frame(observed_value = unname(observed_statistics),
             replicated_median = quantiles[2, ], replicated_lower = quantiles[1, ],
             replicated_upper = quantiles[3, ], observed_quantile = positions,
             n_defined = n_defined)
}


#' Print a partner-dependence predictive check
#'
#' Prints each observed summary alongside the simulated median, middle 95%,
#' and observed position.
#'
#' @param x An object returned by [check_partner_dependence()].
#' @param digits Number of decimal places to print.
#' @param ... Not used.
#'
#' @return `x`, invisibly.
#'
#' @keywords internal
#'
#' @export
print.dyadMLM_partner_check <- function(x, digits = 3, ...) {
  cat("<dyadMLM partner-dependence check>\n")
  cat(
    nrow(x$statistics_table), "statistics using",
    x$n_pairs,
    "complete pairs\n"
  )
  cat("Response: ", x$response, "\n", sep = "")
  cat(
    "Reference: ", x$nsim, " ", x$reference,
    " datasets with ", x$random_effects, " random effects\n",
    sep = ""
  )

  omitted_counts <- c(
    "incomplete dyads" = x$n_incomplete_dyads,
    "rows with missing dyad IDs" = x$n_missing_dyad_rows,
    "rows with missing roles" = x$n_missing_role_rows
  )
  omitted_counts <- omitted_counts[omitted_counts > 0L]
  if (length(omitted_counts) > 0L) {
    cat(
      "Omitted: ",
      paste0(names(omitted_counts), ": ", omitted_counts, collapse = "; "),
      "\n",
      sep = ""
    )
  }

  number_format <- paste0("%.", digits, "f")
  cat("Simulated datasets: median and middle 95% of values\n")
  for (statistic_index in seq_len(nrow(x$statistics_table))) {
    statistic <- x$statistics_table[statistic_index, ]
    cat(
      statistic$label,
      "\n  Observed ", sprintf(number_format, statistic$observed_value),
      " | Median ", sprintf(number_format, statistic$replicated_median),
      " | Middle 95% [", sprintf(number_format, statistic$replicated_lower),
      ", ", sprintf(number_format, statistic$replicated_upper), "]",
      " | Observed position ",
      sprintf(number_format, statistic$observed_quantile),
      " | Defined simulations ", statistic$n_defined, "/", x$nsim,
      "\n",
      sep = ""
    )
  }
  invisible(x)
}


#' Plot partner-dependence predictive checks
#'
#' `r lifecycle::badge("experimental")`
#' Plots a saved [check_partner_dependence()] result. Each histogram shows
#' simulated summary values; the red line marks the observed value and dashed
#' lines mark the middle 95% of simulations.
#'
#' @param x A `dyadMLM_partner_check` object.
#' @param parameterization Which diagnostic view to show: `"both"`, partner-
#'   level summaries (`"member"`), or dyad mean/difference summaries
#'   (`"mean_difference"`).
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
#' plot(check, parameterization = "member", ask = FALSE)
#' }
#' Use `"mean_difference"` for dyad mean/difference summaries or `"both"` (the
#' default) for both views. The subtitle identifies model-centred or raw
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
plot.dyadMLM_partner_check <- function(
  x, parameterization = c("both", "member", "mean_difference"), ask = NULL, ...
) {
  parameterization <- match.arg(parameterization)
  rows <- which(parameterization == "both" |
                x$statistics_table$parameterization == parameterization)
  if (is.null(ask)) {
    ask <- length(rows) > 1L && grDevices::dev.interactive()
  }
  previous_ask <- grDevices::devAskNewPage(ask)
  on.exit(grDevices::devAskNewPage(previous_ask), add = TRUE)
  breaks <- min(100L, max(20L, round(nrow(x$replicated_statistics) / 5)))

  # Each table row names a replicated_statistics column: one scalar per simulation.
  for (i in rows) {
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
                   statistic$n_defined, "/", x$nsim, " defined simulations"),
      xlab = "Summary value", ...
    )
    graphics::segments(
      x0 = limits, y0 = 0, x1 = limits, y1 = height, lty = 2, col = "grey40"
    )
    graphics::segments(
      x0 = statistic$observed_value, y0 = 0,
      x1 = statistic$observed_value, y1 = height, lwd = 2.5, col = "red"
    )
    graphics::legend(
      "top", legend = c("Observed", "Middle 95% of simulations"),
      lty = c(1, 2), lwd = c(2.5, 1), col = c("red", "grey40"),
      horiz = TRUE, bty = "n"
    )
  }
  invisible(x)
}
