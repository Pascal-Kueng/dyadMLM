#' Check whether a fitted model reproduces partner interdependence
#'
#' Compares spread and interdependence in observed cross-sectional partner
#' responses with the same summaries calculated from complete simulated
#' response datasets.
#'
#' This function supports cross-sectional Gaussian `glmmTMB`
#' simulations created by [simulate_dyad_responses()].
#' The interface is experimental and may change as predictive checks expand.
#' With roles, it reports role-specific residual SDs and partner correlation,
#' plus the equivalent dyad-mean and half-difference summaries. Without roles,
#' it reports a pooled residual SD and exchangeability-constrained partner
#' correlation. Exchangeability fixes the signed half-difference mean at zero,
#' so its SD is calculated around zero and remains invariant to member swaps.
#' Observed and simulated responses are centered on the same
#' random-effects-excluded prediction. Modeled random-effect and residual
#' dependence therefore remains in both.
#'
#' An unquoted name defined directly in the calling environment is treated as
#' an external vector; otherwise, a matching fitted-model-frame column is used.
#' A quoted name always selects the model-frame column directly.
#'
#' @param simulations A `dyadMLM_response_simulations` object returned by
#'   [simulate_dyad_responses()].
#' @param dyad An unquoted or quoted column name in the fitted model frame, or
#'   a vector aligned with the fitted rows.
#' @param role An optional unquoted or quoted column name in the fitted model
#'   frame, or a vector aligned with the fitted rows. Defaults to `NULL`.
#' @param plot Logical. If `TRUE`, the default, draw the diagnostic plots.
#'
#' @return Invisibly, a `dyadMLM_partner_check` object containing
#'   `statistics_table`, with one row per summary, and the complete
#'   `replicated_statistics` matrix. The observed quantile gives the observed
#'   statistic's position from 0 to 1 among the replicated values; it is
#'   descriptive and is not a p-value.
#'
#' @references Woody, E., & Sadler, P. (2005). Structural equation models for
#'   interchangeable dyads: Being the same makes a difference. *Psychological
#'   Methods, 10*(2), 139-158.
#'   [doi:10.1037/1082-989X.10.2.139](https://doi.org/10.1037/1082-989X.10.2.139).
#'
#' @export
check_partner_dependence <- function(
  simulations,
  dyad,
  role = NULL,
  plot = TRUE
) {
  check_call <- match.call()

  if (!inherits(simulations, "dyadMLM_response_simulations")) {
    stop(
      "`simulations` must be created by `simulate_dyad_responses()`.",
      call. = FALSE
    )
  }
  if (missing(dyad)) {
    stop("`dyad` must identify the dyad for each fitted row.", call. = FALSE)
  }
  if (!identical(simulations$backend, "glmmTMB")) {
    stop(
      "Partner-dependence checks currently support `glmmTMB` simulations only.",
      call. = FALSE
    )
  }

  n_fitted_rows <- nrow(simulations$model_frame)
  responses_are_aligned <-
    length(simulations$observed_response) == n_fitted_rows &&
    length(simulations$fixed_effect_prediction) == n_fitted_rows &&
    is.matrix(simulations$simulated_responses) &&
    ncol(simulations$simulated_responses) == n_fitted_rows &&
    nrow(simulations$simulated_responses) == simulations$nsim
  if (!responses_are_aligned) {
    stop(
      paste0(
        "The observed responses, fixed-effect predictions, and simulated ",
        "responses are not aligned with the fitted rows."
      ),
      call. = FALSE
    )
  }

  dyad_values <- resolve_fitted_row_argument(
    argument_quo = rlang::enquo(dyad),
    argument_name = "dyad",
    model_frame = simulations$model_frame
  )
  role_values <- resolve_fitted_row_argument(
    argument_quo = rlang::enquo(role),
    argument_name = "role",
    model_frame = simulations$model_frame,
    allow_null = TRUE
  )
  role_specific <- !is.null(role_values)

  # Omit missing identifiers before building one pair map that is reused for
  # the observed response and every complete simulated dataset.
  missing_dyad_rows <- is.na(dyad_values)
  n_missing_dyad_rows <- sum(missing_dyad_rows)

  missing_role_rows <- rep(FALSE, n_fitted_rows)
  if (role_specific) {
    # Rows already missing a dyad ID are counted only as missing dyad rows.
    missing_role_rows <- !missing_dyad_rows & is.na(role_values)
  }
  n_missing_role_rows <- sum(missing_role_rows)

  # First check the fitted cross-sectional structure. Missing roles must not
  # hide a dyad with more than two fitted responses.
  rows_by_dyad <- split(
    which(!missing_dyad_rows),
    dyad_values[!missing_dyad_rows],
    drop = TRUE
  )
  fitted_rows_per_dyad <- lengths(rows_by_dyad)

  if (any(fitted_rows_per_dyad > 2L)) {
    stop(
      paste0(
        "Each dyad must have at most two fitted responses after rows with ",
        "missing dyad IDs are omitted."
      ),
      call. = FALSE
    )
  }

  # Missing roles can make an otherwise complete pair unusable. Keep the
  # original fitted-row indices so the same map applies to every response.
  usable_rows_by_dyad <- lapply(
    rows_by_dyad,
    function(rows) rows[!missing_role_rows[rows]]
  )
  usable_rows_per_dyad <- lengths(usable_rows_by_dyad)
  complete_rows_by_dyad <- usable_rows_by_dyad[usable_rows_per_dyad == 2L]
  n_incomplete_dyads <- sum(usable_rows_per_dyad < 2L)
  if (length(complete_rows_by_dyad) < 3L) {
    stop(
      "At least three complete dyads are required to check partner dependence.",
      call. = FALSE
    )
  }

  paired_row_indices <- complete_rows_by_dyad |>
    unlist(use.names = FALSE) |>
    matrix(ncol = 2L, byrow = TRUE)

  role_order <- NULL
  if (role_specific) {
    role_order <- if (is.factor(role_values)) {
      levels(droplevels(role_values[paired_row_indices]))
    } else {
      sort(unique(role_values[paired_row_indices]), na.last = NA)
    }
    if (length(role_order) != 2L) {
      stop(
        "Exactly two role values are required among the complete dyads.",
        call. = FALSE
      )
    }

    # Orient every pair by role rather than by its order in the fitted data.
    for (pair_index in seq_len(nrow(paired_row_indices))) {
      pair_roles <- role_values[paired_row_indices[pair_index, ]]
      role_positions <- match(role_order, pair_roles)
      if (anyNA(role_positions) || length(unique(pair_roles)) != 2L) {
        stop(
          "Each complete dyad must contain exactly one row for each role value.",
          call. = FALSE
        )
      }
      paired_row_indices[pair_index, ] <-
        paired_row_indices[pair_index, role_positions]
    }
  }

  # Subtract the same fixed-effect prediction from the observed response and
  # every replicate. Newly simulated random-effect dependence remains intact.
  observed_centered_response <-
    simulations$observed_response - simulations$fixed_effect_prediction
  observed_statistics <- calculate_partner_residual_statistics(
    observed_centered_response,
    paired_row_indices,
    role_specific = role_specific
  )

  replicated_statistics <- matrix(
    NA_real_,
    nrow = simulations$nsim,
    ncol = length(observed_statistics),
    dimnames = list(NULL, names(observed_statistics))
  )
  for (simulation_index in seq_len(simulations$nsim)) {
    simulated_centered_response <-
      simulations$simulated_responses[simulation_index, ] -
      simulations$fixed_effect_prediction

    replicated_statistics[simulation_index, ] <-
      calculate_partner_residual_statistics(
        simulated_centered_response,
        paired_row_indices,
        role_specific = role_specific
      )
  }

  if (any(!is.finite(c(observed_statistics, replicated_statistics)))) {
    stop(
      paste0(
        "One or more partner-dependence summaries are undefined because the ",
        "observed response or at least one simulated response has ",
        "insufficient variation."
      ),
      call. = FALSE
    )
  }

  # Map stable statistic names to their parameterization and display label.
  statistics_table <- if (role_specific) {
    half_difference_direction <- paste(
      role_order[[1L]],
      "minus",
      role_order[[2L]]
    )
    data.frame(
      statistic_name = names(observed_statistics),
      parameterization = rep(c("member", "mean_difference"), each = 3L),
      label = c(
        paste0("Residual SD (", role_order[[1L]], ")"),
        paste0("Residual SD (", role_order[[2L]], ")"),
        paste0(
          "Partner correlation (",
          role_order[[1L]], " and ", role_order[[2L]],
          ")"
        ),
        "Dyad-mean SD",
        paste0("Half-difference SD (", half_difference_direction, ")"),
        paste0(
          "Dyad-mean/half-difference correlation (",
          half_difference_direction,
          ")"
        )
      )
    )
  } else {
    data.frame(
      statistic_name = names(observed_statistics),
      parameterization = rep(c("member", "mean_difference"), each = 2L),
      label = c(
        "Pooled residual SD",
        "Partner correlation (exchangeable)",
        "Dyad-mean SD",
        "Half-difference SD"
      )
    )
  }

  statistics_table$observed_value <- unname(observed_statistics)
  statistics_table$replicated_median <- NA_real_
  statistics_table$replicated_lower <- NA_real_
  statistics_table$replicated_upper <- NA_real_
  statistics_table$observed_quantile <- NA_real_

  # Summarize each replicated reference distribution explicitly.
  for (statistic_index in seq_len(nrow(statistics_table))) {
    replicated_values <- replicated_statistics[, statistic_index]
    replicated_interval <- stats::quantile(
      replicated_values,
      probs = c(0.025, 0.975),
      names = FALSE
    )

    statistics_table$replicated_median[[statistic_index]] <-
      stats::median(replicated_values)
    statistics_table$replicated_lower[[statistic_index]] <-
      replicated_interval[[1L]]
    statistics_table$replicated_upper[[statistic_index]] <-
      replicated_interval[[2L]]
    statistics_table$observed_quantile[[statistic_index]] <-
      (1 + sum(replicated_values <= observed_statistics[[statistic_index]])) /
      (simulations$nsim + 1)
  }

  partner_check <- list(
    statistics_table = statistics_table,
    replicated_statistics = replicated_statistics,
    role_order = as.character(role_order),
    n_pairs = nrow(paired_row_indices),
    n_incomplete_dyads = n_incomplete_dyads,
    n_missing_dyad_rows = n_missing_dyad_rows,
    n_missing_role_rows = n_missing_role_rows,
    reference = simulations$reference,
    random_effects = simulations$random_effects,
    nsim = simulations$nsim,
    seed = simulations$seed,
    call = check_call
  )
  class(partner_check) <- c("dyadMLM_partner_check", "list")

  if (plot) {
    graphics::plot(partner_check)
  }

  invisible(partner_check)
}


# Calculate summaries from an already centered response vector.
calculate_partner_residual_statistics <- function(
  centered_response,
  paired_row_indices,
  role_specific
) {
  first_member_residual <- centered_response[paired_row_indices[, 1L]]
  second_member_residual <- centered_response[paired_row_indices[, 2L]]

  # Together these give the equivalent mean-difference representation of the
  # two member responses. With roles, the paired rows follow `role_order`.
  dyad_mean_residual <- (first_member_residual + second_member_residual) / 2
  half_difference_residual <-
    (first_member_residual - second_member_residual) / 2

  if (role_specific) {
    return(c(
      role_1_residual_sd = stats::sd(first_member_residual),
      role_2_residual_sd = stats::sd(second_member_residual),
      partner_correlation = stats::cor(
        first_member_residual,
        second_member_residual
      ),
      dyad_mean_sd = stats::sd(dyad_mean_residual),
      half_difference_sd = stats::sd(half_difference_residual),
      dyad_mean_half_difference_correlation = stats::cor(
        dyad_mean_residual,
        half_difference_residual
      )
    ))
  }

  # Exchangeable members share one mean and variance. Centering both members
  # on their pooled mean gives a correlation invariant to arbitrary swaps.
  pooled_member_residuals <- c(
    first_member_residual,
    second_member_residual
  )
  pooled_residual_mean <- mean(pooled_member_residuals)
  first_member_deviation <- first_member_residual - pooled_residual_mean
  second_member_deviation <- second_member_residual - pooled_residual_mean
  pooled_deviation_sum_of_squares <- sum(
    first_member_deviation^2 + second_member_deviation^2
  )

  c(
    pooled_residual_sd = stats::sd(pooled_member_residuals),
    exchangeable_partner_correlation =
      2 * sum(first_member_deviation * second_member_deviation) /
      pooled_deviation_sum_of_squares,
    dyad_mean_sd = stats::sd(dyad_mean_residual),
    # Exchangeability fixes the signed half-difference mean at zero.
    half_difference_sd = sqrt(mean(half_difference_residual^2))
  )
}


#' @export
print.dyadMLM_partner_check <- function(x, digits = 3, ...) {
  cat("<dyadMLM partner-dependence check>\n")
  cat(
    nrow(x$statistics_table),
    "statistics from",
    x$n_pairs,
    "complete pairs\n"
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
  cat("Replicated reference: median and central 95% interval\n")
  for (statistic_index in seq_len(nrow(x$statistics_table))) {
    statistic <- x$statistics_table[statistic_index, ]
    cat(
      statistic$label,
      "\n  Observed ", sprintf(number_format, statistic$observed_value),
      " | Median ", sprintf(number_format, statistic$replicated_median),
      " | 95% [", sprintf(number_format, statistic$replicated_lower),
      ", ", sprintf(number_format, statistic$replicated_upper), "]",
      " | Obs. quantile ",
      sprintf(number_format, statistic$observed_quantile),
      "\n",
      sep = ""
    )
  }
  invisible(x)
}


#' Plot partner-dependence predictive checks
#'
#' Draws each selected statistic as a separate full-size plot. Both equivalent
#' parameterizations are shown by default.
#'
#' @param x A `dyadMLM_partner_check` object.
#' @param parameterization Which diagnostic view to show: `"both"`,
#'   `"member"`, or `"mean_difference"`.
#' @param ask `NULL` uses interactive, one-plot-at-a-time behavior when more
#'   than one statistic is shown. Supply `TRUE` or `FALSE` to override it.
#' @param ... Additional graphical arguments passed to [graphics::plot()].
#'   `freq`, `xlim`, `ylim`, `main`, `sub`, and `xlab` are controlled by this
#'   method.
#'
#' @return Invisibly, `x`.
#'
#' @export
plot.dyadMLM_partner_check <- function(
  x,
  parameterization = c("both", "member", "mean_difference"),
  ask = NULL,
  ...
) {
  parameterization <- match.arg(parameterization)
  selected_statistics <- if (parameterization == "both") {
    x$statistics_table
  } else {
    x$statistics_table[
      x$statistics_table$parameterization == parameterization,
      ,
      drop = FALSE
    ]
  }

  if (is.null(ask)) {
    ask <- nrow(selected_statistics) > 1L && grDevices::dev.interactive()
  }
  previous_ask <- grDevices::devAskNewPage(ask)
  on.exit(grDevices::devAskNewPage(previous_ask), add = TRUE)

  histogram_breaks <- min(
    100L,
    max(20L, round(nrow(x$replicated_statistics) / 5))
  )

  parameterization_labels <- c(
    member = "Member parameterization",
    mean_difference = "Mean-difference parameterization"
  )
  for (statistic_index in seq_len(nrow(selected_statistics))) {
    statistic_row <- selected_statistics[statistic_index, ]
    replicated_values <-
      x$replicated_statistics[, statistic_row$statistic_name, drop = TRUE]
    plot_range <- range(
      c(statistic_row$observed_value, replicated_values),
      finite = TRUE
    )
    replicated_histogram <- graphics::hist(
      replicated_values,
      breaks = histogram_breaks,
      plot = FALSE
    )
    reference_line_height <- max(replicated_histogram$counts)

    # Reserve a blank band above every plotted element for the legend.
    graphics::plot(
      replicated_histogram,
      freq = TRUE,
      xlim = plot_range,
      ylim = c(0, reference_line_height * 1.25),
      main = statistic_row$label,
      sub = paste0(
        parameterization_labels[[statistic_row$parameterization]],
        "; ",
        x$n_pairs,
        " complete pairs"
      ),
      xlab = "Statistic value",
      ...
    )
    graphics::segments(
      x0 = c(
        statistic_row$replicated_lower,
        statistic_row$replicated_upper
      ),
      y0 = 0,
      x1 = c(
        statistic_row$replicated_lower,
        statistic_row$replicated_upper
      ),
      y1 = reference_line_height,
      lty = 2,
      col = "grey40"
    )
    graphics::segments(
      x0 = statistic_row$observed_value,
      y0 = 0,
      x1 = statistic_row$observed_value,
      y1 = reference_line_height,
      lwd = 2.5,
      col = "red"
    )
    graphics::legend(
      "top",
      legend = c("Observed", "Replicated 95% interval"),
      lty = c(1, 2),
      lwd = c(2.5, 1),
      col = c("red", "grey40"),
      horiz = TRUE,
      bty = "n"
    )
  }

  invisible(x)
}
