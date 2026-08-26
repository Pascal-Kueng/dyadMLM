#' Check whether a fitted model reproduces partner dependence
#'
#' `r lifecycle::badge("experimental")`
#' Checks whether a fitted model reproduces how much partners' responses vary
#' and how strongly they are related. It compares the observed data with
#' datasets generated from the fitted model.
#'
#' **When is this useful?** This check is most useful when the model makes a
#' clear simplifying assumption about the partner pattern. Examples are that
#' there is no remaining relationship between partners' responses, that both
#' roles vary by the same amount. A model that was allowed to learn the same
#' pattern freely from the data will usually reproduce it in simulated data. In
#' that case, close agreement mainly shows that the simulation matches what the
#' model learned; it does not by itself show that the model describes the data
#' well.
#'
#' For each summary, the result shows the observed value, the median and middle
#' 95% of the simulated values, and where the observed value falls among the
#' simulations. A position near 0 or 1 means that the observation is near one
#' edge of what the model generated. This position is a descriptive guide; it
#' is not a p-value.
#'
#' Supply `role` when the two members have meaningful roles. The results then
#' describe each role separately and also show dyad mean/difference summaries.
#' With `role = NULL`, the members are treated as interchangeable, and the
#' summaries do not depend on which member is listed first.
#'
#' By default, `response = "model-centred"` removes the same fitted mean pattern
#' from the observed and simulated responses. This focuses the check on the
#' remaining variation and partner dependence. Use `response = "raw"` to keep
#' the responses unchanged.
#'
#' Currently, the function supports cross-sectional Gaussian identity-link
#' `glmmTMB` simulations created by [simulate_dyad_responses()]. Each dyad may
#' have at most two fitted responses, and at least three complete dyads are
#' required. With `role`, each complete dyad must contain one member in each of
#' exactly two roles. Missing identifiers and incomplete dyads are omitted and
#' counted in the result. The interface is experimental.
#'
#' **Technical details.** Model-centred values equal
#' `response - response_center`. The centre is fixed across the observed and
#' simulated datasets, so newly generated random effects remain. These are
#' model-centred response deviations, not conditional or PIT residuals. With
#' roles, the partner-level and dyad mean/half-difference summaries express the
#' same covariance information. Without roles, the exchangeable calculation
#' uses a half-difference root mean square about zero to recover the common
#' member variance and covariance.
#'
#' For interchangeable members, the calculation follows Woody and Sadler's
#' (2005) between-/within-dyad decomposition. That paper supports the dyadic
#' summary, not the model centring or predictive comparison. This function
#' adapts the replicated-data comparison principle from Gelman, Meng, and Stern
#' (1996). Here, the replicated data form a fixed-estimate plug-in reference,
#' not a posterior predictive distribution.
#'
#' @param simulations A `dyadMLM_response_simulations` object returned by
#'   [simulate_dyad_responses()].
#' @param dyad An unquoted or quoted column name in the fitted model frame, or
#'   a vector aligned with the fitted rows.
#' @param role An optional unquoted or quoted column name in the fitted model
#'   frame, or a vector aligned with the fitted rows. Supply this whenever a
#'   member distinction is substantively meaningful. Use the default `NULL`
#'   only when members are substantively interchangeable.
#' @param plot Logical. If `TRUE`, the default, draw the diagnostic plots.
#' @param response Which values to summarize. `"model-centred"` (the default)
#'   removes the fitted mean pattern. `"raw"` leaves responses unchanged. The
#'   same choice is applied to observed and simulated responses.
#'
#' @return Invisibly, a `dyadMLM_partner_check` object containing the summary
#'   table, all replicated statistics, and the selected `response`. In the
#'   table, `observed_quantile` stores the observed position: the proportion of
#'   simulated values at or below the observed value, with a finite-simulation
#'   correction.
#'
#' @examples
#' if (requireNamespace("glmmTMB", quietly = TRUE)) {
#'   example_data <- dyads_cross[dyads_cross$coupleID <= 40, ]
#'   model <- glmmTMB::glmmTMB(
#'     closeness ~ gender + (1 | coupleID),
#'     data = example_data
#'   )
#'
#'   simulations <- simulate_dyad_responses(model, nsim = 50, seed = 123)
#'   check <- check_partner_dependence(
#'     simulations,
#'     dyad = coupleID,
#'     role = gender,
#'     plot = FALSE
#'   )
#'   check
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
  simulations,
  dyad,
  role = NULL,
  plot = TRUE,
  response = c("model-centred", "raw")
) {
  check_call <- match.call()
  response <- match.arg(response)

  if (!inherits(simulations, "dyadMLM_response_simulations")) {
    stop(
      "`simulations` must be created by `simulate_dyad_responses()`.",
      call. = FALSE
    )
  }
  if (missing(dyad)) {
    stop("`dyad` must identify the dyad for each fitted row.", call. = FALSE)
  }
  supported_simulation <-
    identical(simulations$backend, "glmmTMB") &&
    identical(simulations$family, "gaussian") &&
    identical(simulations$link, "identity")
  if (!supported_simulation) {
    stop(
      paste0(
        "Partner-dependence checks currently require cross-sectional ",
        "Gaussian identity-link `glmmTMB` simulations."
      ),
      call. = FALSE
    )
  }
  n_fitted_rows <- nrow(simulations$model_frame)
  responses_are_aligned <-
    length(simulations$observed_response) == n_fitted_rows &&
    is.numeric(simulations$response_center) &&
    length(simulations$response_center) == n_fitted_rows &&
    all(is.finite(simulations$response_center)) &&
    is.matrix(simulations$simulated_responses) &&
    ncol(simulations$simulated_responses) == n_fitted_rows &&
    nrow(simulations$simulated_responses) == simulations$nsim
  if (!responses_are_aligned) {
    stop(
      paste0(
        "The observed responses, response centres, and simulated ",
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
  role_was_supplied <- !is.null(role_values)

  # Omit missing identifiers before building one pair map that is reused for
  # the observed response and every complete simulated dataset.
  missing_dyad_rows <- is.na(dyad_values)
  n_missing_dyad_rows <- sum(missing_dyad_rows)

  missing_role_rows <- rep(FALSE, n_fitted_rows)
  if (role_was_supplied) {
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
  if (role_was_supplied) {
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

  # Use the same row-specific subtraction for observed and simulated responses.
  # Subtracting zero leaves raw responses unchanged.
  response_values_to_subtract <- if (response == "model-centred") {
    simulations$response_center
  } else {
    rep(0, n_fitted_rows)
  }

  # Apply exactly the same statistic code to the data and every simulation.
  observed_response_values <-
    simulations$observed_response - response_values_to_subtract
  observed_statistics <- calculate_partner_response_statistics(
    observed_response_values,
    paired_row_indices,
    use_role_specific_statistics = role_was_supplied
  )

  replicated_statistics <- matrix(
    NA_real_,
    nrow = simulations$nsim,
    ncol = length(observed_statistics),
    dimnames = list(NULL, names(observed_statistics))
  )
  for (simulation_index in seq_len(simulations$nsim)) {
    simulated_response_values <-
      simulations$simulated_responses[simulation_index, ] -
      response_values_to_subtract

    replicated_statistics[simulation_index, ] <-
      calculate_partner_response_statistics(
        simulated_response_values,
        paired_row_indices,
        use_role_specific_statistics = role_was_supplied
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

  # Map statistic names to parameterizations and display labels.
  statistics_table <- if (role_was_supplied) {
    half_difference_direction <- paste(
      role_order[[1L]],
      "minus",
      role_order[[2L]]
    )
    data.frame(
      statistic_name = names(observed_statistics),
      parameterization = rep(c("member", "mean_difference"), each = 3L),
      label = c(
        paste0("SD (", role_order[[1L]], ")"),
        paste0("SD (", role_order[[2L]], ")"),
        paste0(
          "Partner correlation (",
          role_order[[1L]], " and ", role_order[[2L]],
          ")"
        ),
        "Dyad-average SD",
        paste0(
          "Half-difference SD (",
          half_difference_direction,
          ")"
        ),
        paste0(
          "Dyad-average/role-difference correlation (",
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
        "Common member SD (exchangeable)",
        "Partner correlation (exchangeable)",
        "Dyad-average SD",
        "Half-difference RMS (about zero)"
      )
    )
  }

  statistics_table$observed_value <- unname(observed_statistics)
  statistics_table$replicated_median <- NA_real_
  statistics_table$replicated_lower <- NA_real_
  statistics_table$replicated_upper <- NA_real_
  statistics_table$observed_quantile <- NA_real_

  # Summarize each replicated reference distribution.
  for (statistic_index in seq_len(nrow(statistics_table))) {
    replicated_statistic_values <- replicated_statistics[, statistic_index]
    replicated_95_percent_interval <- stats::quantile(
      replicated_statistic_values,
      probs = c(0.025, 0.975),
      names = FALSE
    )

    statistics_table$replicated_median[[statistic_index]] <-
      stats::median(replicated_statistic_values)
    statistics_table$replicated_lower[[statistic_index]] <-
      replicated_95_percent_interval[[1L]]
    statistics_table$replicated_upper[[statistic_index]] <-
      replicated_95_percent_interval[[2L]]

    # This finite-simulation rank is descriptive; it is not a p-value.
    statistics_table$observed_quantile[[statistic_index]] <-
      (1 + sum(
        replicated_statistic_values <= observed_statistics[[statistic_index]]
      )) /
      (simulations$nsim + 1)
  }

  partner_check_result <- list(
    statistics_table = statistics_table,
    replicated_statistics = replicated_statistics,
    role_order = as.character(role_order),
    n_pairs = nrow(paired_row_indices),
    n_incomplete_dyads = n_incomplete_dyads,
    n_missing_dyad_rows = n_missing_dyad_rows,
    n_missing_role_rows = n_missing_role_rows,
    response = response,
    backend = simulations$backend,
    family = simulations$family,
    link = simulations$link,
    reference = simulations$reference,
    random_effects = simulations$random_effects,
    parameter_uncertainty = simulations$parameter_uncertainty,
    nsim = simulations$nsim,
    seed = simulations$seed,
    call = check_call
  )
  class(partner_check_result) <- c("dyadMLM_partner_check", "list")

  if (plot) {
    graphics::plot(partner_check_result)
  }

  invisible(partner_check_result)
}


# Calculate summaries from one selected response representation.
calculate_partner_response_statistics <- function(
  selected_response_values,
  paired_row_indices,
  use_role_specific_statistics
) {
  first_member_values <-
    selected_response_values[paired_row_indices[, 1L]]
  second_member_values <-
    selected_response_values[paired_row_indices[, 2L]]

  # Re-express each pair as an average and half-difference. With roles, rows
  # have already been ordered by `role_order`.
  dyad_average_values <- (first_member_values + second_member_values) / 2
  half_difference_values <- (first_member_values - second_member_values) / 2

  if (use_role_specific_statistics) {
    # Keep member spreads separate when the two roles are meaningful.
    return(c(
      role_1_sd = stats::sd(first_member_values),
      role_2_sd = stats::sd(second_member_values),
      partner_correlation = stats::cor(
        first_member_values,
        second_member_values
      ),
      dyad_mean_sd = stats::sd(dyad_average_values),
      half_difference_sd = stats::sd(half_difference_values),
      dyad_mean_half_difference_correlation = stats::cor(
        dyad_average_values,
        half_difference_values
      )
    ))
  }

  # Exchangeability sets the expected half-difference to zero, so use its mean
  # square about zero. Dyad averages use the usual sample variance.
  dyad_average_variance <- stats::var(dyad_average_values)
  half_difference_mean_square <- mean(half_difference_values^2)
  exchangeable_member_variance <-
    dyad_average_variance + half_difference_mean_square
  exchangeable_partner_covariance <-
    dyad_average_variance - half_difference_mean_square

  c(
    exchangeable_member_sd = sqrt(exchangeable_member_variance),
    exchangeable_partner_correlation =
      exchangeable_partner_covariance / exchangeable_member_variance,
    dyad_mean_sd = sqrt(dyad_average_variance),
    half_difference_rms = sqrt(half_difference_mean_square)
  )
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
      "\n",
      sep = ""
    )
  }
  invisible(x)
}


#' Plot partner-dependence predictive checks
#'
#' `r lifecycle::badge("experimental")`
#' Shows each observed summary as a red line against the values generated by
#' the fitted model. Dashed lines mark the middle 95% of the simulated values.
#' An observed value near or beyond these limits may indicate that the model
#' does not reproduce that aspect of partner dependence well.
#' The limits are descriptive reference values, not a pass/fail rule.
#'
#' A value near the middle is not automatically evidence of a good model. If
#' the model estimated that same feature from these data, close agreement is
#' expected. These plots add the most information when the model fixes or
#' simplifies the feature shown.
#'
#' By default, the method shows both the partner-level and equivalent dyad
#' mean/difference summaries. The subtitle identifies whether the check uses
#' model-centred or raw responses. These are two views of the same dependence
#' information, not independent checks.
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
#' @export
plot.dyadMLM_partner_check <- function(
  x,
  parameterization = c("both", "member", "mean_difference"),
  ask = NULL,
  ...
) {
  parameterization <- match.arg(parameterization)
  selected_statistics_table <- if (parameterization == "both") {
    x$statistics_table
  } else {
    x$statistics_table[
      x$statistics_table$parameterization == parameterization,
      ,
      drop = FALSE
    ]
  }

  if (is.null(ask)) {
    ask <-
      nrow(selected_statistics_table) > 1L && grDevices::dev.interactive()
  }
  previous_ask <- grDevices::devAskNewPage(ask)
  on.exit(grDevices::devAskNewPage(previous_ask), add = TRUE)

  histogram_breaks <- min(
    100L,
    max(20L, round(nrow(x$replicated_statistics) / 5))
  )

  parameterization_labels <- c(
    member = "Partner-level summaries",
    mean_difference = "Dyad mean/difference summaries"
  )
  response_subtitle <- if (x$response == "model-centred") {
    "Fitted row-specific mean removed; remaining dependence retained"
  } else {
    "Raw responses; fitted mean pattern retained"
  }
  for (statistic_index in seq_len(nrow(selected_statistics_table))) {
    statistic_row <- selected_statistics_table[statistic_index, ]
    replicated_statistic_values <-
      x$replicated_statistics[, statistic_row$statistic_name, drop = TRUE]
    x_axis_range <- range(
      c(statistic_row$observed_value, replicated_statistic_values),
      finite = TRUE
    )
    replicated_histogram <- graphics::hist(
      replicated_statistic_values,
      breaks = histogram_breaks,
      plot = FALSE
    )
    highest_histogram_count <- max(replicated_histogram$counts)

    # Reserve a blank band above every plotted element for the legend.
    graphics::plot(
      replicated_histogram,
      freq = TRUE,
      xlim = x_axis_range,
      ylim = c(0, highest_histogram_count * 1.25),
      main = statistic_row$label,
      sub = paste0(
        response_subtitle,
        "; ",
        parameterization_labels[[statistic_row$parameterization]],
        "; ",
        x$n_pairs,
        " complete pairs; ",
        x$reference,
        " reference (", x$nsim, " datasets)"
      ),
      xlab = "Summary value",
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
      y1 = highest_histogram_count,
      lty = 2,
      col = "grey40"
    )
    graphics::segments(
      x0 = statistic_row$observed_value,
      y0 = 0,
      x1 = statistic_row$observed_value,
      y1 = highest_histogram_count,
      lwd = 2.5,
      col = "red"
    )
    graphics::legend(
      "top",
      legend = c("Observed", "Middle 95% of simulations"),
      lty = c(1, 2),
      lwd = c(2.5, 1),
      col = c("red", "grey40"),
      horiz = TRUE,
      bty = "n"
    )
  }

  invisible(x)
}
