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
#' By default, `response = "model-centred"` removes the same row-specific
#' response-prediction pattern from the observed and simulated responses. This
#' focuses the check on the remaining variation and partner dependence. Use
#' `response = "raw"` to keep the responses unchanged.
#'
#' Currently, the function supports cross-sectional `glmmTMB` simulations
#' created by [simulate_dyad_responses()]. Each dyad may have at most two fitted
#' responses, and at least three complete dyads are required. With `role`, each
#' complete dyad must contain one member in each of exactly two roles. Missing
#' identifiers and incomplete dyads are omitted and counted in the result. The
#' interface is experimental.
#'
#' **Technical details.** Model-centred values equal
#' `response - response_center`. The centre is fixed across the observed and
#' simulated datasets, so newly generated random effects remain. The centre is
#' the response prediction returned by `predict(..., re.form = NA)`. These are
#' model-centred response deviations, not conditional or PIT residuals, and the
#' subtraction is not an orthogonal variance decomposition for non-Gaussian
#' families. With roles, the partner-level and dyad mean/half-difference
#' summaries express the same sample covariance information. Without roles,
#' the exchangeable calculation uses a half-difference root mean square about
#' zero to recover the common sample member variance and covariance.
#'
#' An undefined observed statistic cannot be compared with the simulations and
#' causes an error. Undefined simulated values are omitted only from that
#' statistic's reference. One warning reports their counts and proportions;
#' summaries and plots use the defined values only. If a statistic is undefined
#' in every simulation, its reference cannot be calculated and the function
#' causes an error.
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
#'   removes the row-specific response-prediction pattern. `"raw"` leaves
#'   responses unchanged. The same choice is applied to observed and simulated
#'   responses.
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
    identical(simulations$backend, "glmmTMB")
  if (!supported_simulation) {
    stop(
      paste0(
        "Partner-dependence checks currently require cross-sectional ",
        "`glmmTMB` simulations."
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

  # Build one pair map, oriented by role when supplied, and reuse it unchanged
  # for the observed response and every simulation.
  pair_info <- prepare_partner_pairs(dyad_values, role_values)
  paired_row_indices <- pair_info$paired_row_indices
  role_order <- pair_info$role_order

  # Use the same row-specific subtraction for observed and simulated responses.
  # Subtracting zero leaves raw responses unchanged.
  response_values_to_subtract <- if (response == "model-centred") {
    simulations$response_center
  } else {
    rep(0, n_fitted_rows)
  }

  # Observed data: one response value for every fitted row.
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

  # Simulated data: one generated dataset per row, with the same fitted-row
  # order as the observed response. Apply exactly the same summaries to each.
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

  undefined_observed_statistics <- names(observed_statistics)[
    !is.finite(observed_statistics)
  ]
  if (length(undefined_observed_statistics) > 0L) {
    stop(
      paste0(
        "Observed partner-dependence summaries are undefined: ",
        paste(undefined_observed_statistics, collapse = ", "), ". ",
        "The observed response has insufficient variation."
      ),
      call. = FALSE
    )
  }

  n_defined_simulations <- colSums(is.finite(replicated_statistics))
  all_undefined_statistics <- names(n_defined_simulations)[
    n_defined_simulations == 0L
  ]
  if (length(all_undefined_statistics) > 0L) {
    stop(
      paste0(
        "Every simulated value is undefined for: ",
        paste(all_undefined_statistics, collapse = ", "), ". ",
        "A predictive reference cannot be calculated."
      ),
      call. = FALSE
    )
  }

  statistics_table <- summarize_partner_statistics(
    observed_statistics = observed_statistics,
    replicated_statistics = replicated_statistics,
    role_order = role_order
  )

  partner_check_result <- list(
    statistics_table = statistics_table,
    replicated_statistics = replicated_statistics,
    role_order = as.character(role_order),
    n_pairs = nrow(paired_row_indices),
    n_incomplete_dyads = pair_info$n_incomplete_dyads,
    n_missing_dyad_rows = pair_info$n_missing_dyad_rows,
    n_missing_role_rows = pair_info$n_missing_role_rows,
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

  n_undefined_simulations <- simulations$nsim - n_defined_simulations
  if (any(n_undefined_simulations > 0L)) {
    affected_statistics <- which(n_undefined_simulations > 0L)
    n_affected_datasets <- sum(rowSums(!is.finite(replicated_statistics)) > 0L)
    count_and_percentage <- function(count) {
      paste0(
        count, " of ", simulations$nsim, " (",
        sprintf("%.1f", 100 * count / simulations$nsim), "%)"
      )
    }
    affected_statistic_details <- paste0(
      statistics_table$label[affected_statistics], ": ",
      vapply(
        n_undefined_simulations[affected_statistics],
        count_and_percentage,
        character(1)
      )
    )
    warning(
      paste0(
        count_and_percentage(n_affected_datasets),
        " simulated datasets produced at least one undefined ",
        "partner-dependence summary. By statistic: ",
        paste(affected_statistic_details, collapse = "; "), ". ",
        "Reference summaries and plots use only the defined values for each ",
        "statistic. The undefined proportion is itself model-predictive ",
        "information."
      ),
      call. = FALSE
    )
  }

  if (plot) {
    graphics::plot(partner_check_result)
  }

  invisible(partner_check_result)
}


# Find complete dyads and store both partners' fitted-row positions.
prepare_partner_pairs <- function(dyad_values, role_values = NULL) {
  n_fitted_rows <- length(dyad_values)
  role_was_supplied <- !is.null(role_values)

  missing_dyad_rows <- is.na(dyad_values)
  n_missing_dyad_rows <- sum(missing_dyad_rows)

  missing_role_rows <- rep(FALSE, n_fitted_rows)
  if (role_was_supplied) {
    # A row missing both identifiers is counted only as missing its dyad ID.
    missing_role_rows <- !missing_dyad_rows & is.na(role_values)
  }
  n_missing_role_rows <- sum(missing_role_rows)

  rows_by_dyad <- split(
    which(!missing_dyad_rows),
    dyad_values[!missing_dyad_rows],
    drop = TRUE
  )

  # Check this before omitting missing roles, so a missing role cannot hide a
  # dyad with more than two fitted responses.
  if (any(lengths(rows_by_dyad) > 2L)) {
    stop(
      paste0(
        "Each dyad must have at most two fitted responses after rows with ",
        "missing dyad IDs are omitted."
      ),
      call. = FALSE
    )
  }

  usable_rows_by_dyad <- lapply(
    rows_by_dyad,
    function(rows) rows[!missing_role_rows[rows]]
  )

  # After missing roles are removed, exactly two usable rows form a complete
  # dyad. Every other identifiable dyad is counted once as incomplete.
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

  # Each row now represents one complete dyad. The columns contain positions
  # in the fitted data and therefore index every observed or simulated response.
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

    # Give both columns a stable meaning: role 1, then role 2.
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

  list(
    paired_row_indices = paired_row_indices,
    role_order = role_order,
    n_incomplete_dyads = n_incomplete_dyads,
    n_missing_dyad_rows = n_missing_dyad_rows,
    n_missing_role_rows = n_missing_role_rows
  )
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
      partner_correlation = safe_partner_correlation(
        first_member_values,
        second_member_values
      ),
      dyad_mean_sd = stats::sd(dyad_average_values),
      half_difference_sd = stats::sd(half_difference_values),
      dyad_mean_half_difference_correlation = safe_partner_correlation(
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


# Calculate a correlation without warning when either vector has zero spread.
safe_partner_correlation <- function(x, y) {
  x_sd <- stats::sd(x)
  y_sd <- stats::sd(y)
  if (!is.finite(x_sd) || !is.finite(y_sd) || x_sd <= 0 || y_sd <= 0) {
    return(NA_real_)
  }

  stats::cor(x, y)
}


# Combine the observed summaries with their simulated reference distributions.
summarize_partner_statistics <- function(
  observed_statistics,
  replicated_statistics,
  role_order = NULL
) {
  statistic_names <- names(observed_statistics)

  if (!is.null(role_order)) {
    half_difference_direction <- paste(
      role_order[[1L]],
      "minus",
      role_order[[2L]]
    )
    statistic_parameterizations <- c(
      role_1_sd = "member",
      role_2_sd = "member",
      partner_correlation = "member",
      dyad_mean_sd = "mean_difference",
      half_difference_sd = "mean_difference",
      dyad_mean_half_difference_correlation = "mean_difference"
    )
    statistic_labels <- c(
      role_1_sd = paste0("SD (", role_order[[1L]], ")"),
      role_2_sd = paste0("SD (", role_order[[2L]], ")"),
      partner_correlation = paste0(
        "Partner correlation (",
        role_order[[1L]], " and ", role_order[[2L]],
        ")"
      ),
      dyad_mean_sd = "Dyad-average SD",
      half_difference_sd = paste0(
        "Half-difference SD (",
        half_difference_direction,
        ")"
      ),
      dyad_mean_half_difference_correlation = paste0(
        "Dyad-average/role-difference correlation (",
        half_difference_direction,
        ")"
      )
    )
  } else {
    statistic_parameterizations <- c(
      exchangeable_member_sd = "member",
      exchangeable_partner_correlation = "member",
      dyad_mean_sd = "mean_difference",
      half_difference_rms = "mean_difference"
    )
    statistic_labels <- c(
      exchangeable_member_sd = "Common member SD (exchangeable)",
      exchangeable_partner_correlation =
        "Partner correlation (exchangeable)",
      dyad_mean_sd = "Dyad-average SD",
      half_difference_rms = "Half-difference RMS (about zero)"
    )
  }

  # Each column is one statistic across all simulated datasets. Omit occasional
  # undefined values independently for that statistic.
  replicated_reference_points <- vapply(
    seq_along(observed_statistics),
    function(statistic_index) {
      replicated_statistic_values <-
        replicated_statistics[, statistic_index]
      stats::quantile(
        replicated_statistic_values[is.finite(replicated_statistic_values)],
        probs = c(0.025, 0.5, 0.975),
        names = FALSE
      )
    },
    numeric(3)
  )

  # This finite-simulation rank is descriptive; it is not a p-value.
  observed_positions <- vapply(
    seq_along(observed_statistics),
    function(statistic_index) {
      replicated_statistic_values <-
        replicated_statistics[, statistic_index]
      replicated_statistic_values <-
        replicated_statistic_values[is.finite(replicated_statistic_values)]
      (1 + sum(
        replicated_statistic_values <= observed_statistics[[statistic_index]]
      )) / (length(replicated_statistic_values) + 1)
    },
    numeric(1)
  )

  statistics_table <- data.frame(
    statistic_name = statistic_names,
    parameterization = unname(statistic_parameterizations[statistic_names]),
    label = unname(statistic_labels[statistic_names]),
    observed_value = unname(observed_statistics),
    replicated_median = unname(replicated_reference_points[2L, ]),
    replicated_lower = unname(replicated_reference_points[1L, ]),
    replicated_upper = unname(replicated_reference_points[3L, ]),
    observed_quantile = unname(observed_positions)
  )

  statistics_table
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
    n_defined_simulations <- sum(is.finite(
      x$replicated_statistics[, statistic$statistic_name, drop = TRUE]
    ))
    defined_simulations_suffix <- if (n_defined_simulations < x$nsim) {
      paste0(
        " | Defined simulations ", n_defined_simulations, "/", x$nsim
      )
    } else {
      ""
    }
    cat(
      statistic$label,
      "\n  Observed ", sprintf(number_format, statistic$observed_value),
      " | Median ", sprintf(number_format, statistic$replicated_median),
      " | Middle 95% [", sprintf(number_format, statistic$replicated_lower),
      ", ", sprintf(number_format, statistic$replicated_upper), "]",
      " | Observed position ",
      sprintf(number_format, statistic$observed_quantile),
      defined_simulations_suffix,
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
    "Row-specific response prediction removed; dependence retained"
  } else {
    "Raw responses; row-specific prediction pattern retained"
  }
  for (statistic_index in seq_len(nrow(selected_statistics_table))) {
    statistic_row <- selected_statistics_table[statistic_index, ]
    replicated_statistic_values <-
      x$replicated_statistics[, statistic_row$statistic_name, drop = TRUE]
    replicated_statistic_values <-
      replicated_statistic_values[is.finite(replicated_statistic_values)]
    reference_dataset_label <- if (
      length(replicated_statistic_values) < x$nsim
    ) {
      paste0(
        length(replicated_statistic_values), "/", x$nsim,
        " defined datasets"
      )
    } else {
      paste0(x$nsim, " datasets")
    }
    reference_limits <- c(
      statistic_row$replicated_lower,
      statistic_row$replicated_upper
    )
    x_axis_range <- range(
      statistic_row$observed_value,
      replicated_statistic_values,
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
        " reference (", reference_dataset_label, ")"
      ),
      xlab = "Summary value",
      ...
    )
    graphics::segments(
      x0 = reference_limits,
      y0 = 0,
      x1 = reference_limits,
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
