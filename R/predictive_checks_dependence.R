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
#' @param ask Whether to pause between plots. `NULL` (default) chooses
#'   automatically; `TRUE` pauses and `FALSE` draws without pausing.
#'   Ignored when `plot = FALSE`.
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
  simulations,
  dyad,
  role = NULL,
  plot = TRUE,
  response = c("model-centred", "raw"),
  ask = NULL
) {
  if (!inherits(simulations, "dyadMLM_response_simulations")) {
    stop("`simulations` must be created by `simulate_dyad_responses()`.", call. = FALSE)
  }
  if (missing(dyad)) {
    stop("`dyad` must identify the dyad for each fitted row.", call. = FALSE)
  }

  response <- match.arg(response)
  fitted_model_frame <- simulations$model_frame

  # partner_row_map$rows has one row per complete dyad and one column per partner.
  partner_row_map <- prepare_partner_pairs(
    resolve_fitted_row_argument(rlang::enquo(dyad), "dyad", fitted_model_frame),
    resolve_fitted_row_argument(rlang::enquo(role), "role", fitted_model_frame,
                                allow_null = TRUE)
  )
  has_role <- !is.null(partner_row_map$role_order)

  # Combine the observed and simulated response vectors into one large matrix.
  responses_by_dataset <- rbind(
    simulations$observed_response, unname(simulations$simulated_responses)
  )

  # For each response vector we need to compute the test statistic.
  # First, we reserve one list entry for each response vector for efficiency.
  statistics_by_dataset <- vector("list", nrow(responses_by_dataset))
  for (dataset_index in seq_len(nrow(responses_by_dataset))) {
    dataset_responses <- responses_by_dataset[dataset_index, ]
    if (response == "model-centred") {
      dataset_responses <- dataset_responses - simulations$predicted_response
    }

    first_partner_responses <- dataset_responses[partner_row_map$rows[, 1]]
    second_partner_responses <- dataset_responses[partner_row_map$rows[, 2]]

    #### continue review here!
    statistics_by_dataset[[dataset_index]] <- calculate_partner_pair_statistics(
      first_partner_responses,
      second_partner_responses,
      compute_role_specific_statistics = has_role
    )
  }

  # Each list entry contains 4 or 6 named statistics. Keep the observed vector;
  # stack the remaining entries into a matrix with one row per simulation.
  observed_statistics <- statistics_by_dataset[[1]]
  simulated_statistics <- do.call(rbind, statistics_by_dataset[-1])

  # Table rows and simulation columns use the same statistic order.
  # Keep both: the table supplies labels/limits, the matrix supplies histograms.
  check_result <- list(
    statistics_table = cbind(
      partner_statistic_info(partner_row_map$role_order),
      summarize_simulation_reference(observed_statistics, simulated_statistics)
    ),
    replicated_statistics = simulated_statistics,
    role_order = as.character(partner_row_map$role_order),
    n_pairs = nrow(partner_row_map$rows),
    n_incomplete_dyads = partner_row_map$n_incomplete_dyads,
    n_missing_dyad_rows = partner_row_map$n_missing_dyad_rows,
    n_missing_role_rows = partner_row_map$n_missing_role_rows,
    response = response
  )
  attr(check_result, "dyadMLM") <- attr(simulations, "dyadMLM")
  class(check_result) <- c("dyadMLM_partner_check", "list")
  if (any(c(check_result$n_incomplete_dyads, check_result$n_missing_dyad_rows,
            check_result$n_missing_role_rows) > 0)) {
    warning("Incomplete dyads or rows with missing IDs or roles were omitted. ",
            "Print the result for counts.", call. = FALSE)
  }
  if (missing(role)) {
    message("No role supplied: summaries pool partners. Supply `role` to check ",
            "each role's variance separately, even if the model did not include it. ",
            "Use `role = NULL` to pool without this message.")
  }
  if (plot) graphics::plot(check_result, ask = ask)
  return(invisible(check_result))
}


### Matching partners ---------------------------------------------------------

# Build the pair map. Reusable for observed and simulated responses.
prepare_partner_pairs <- function(dyad_ids, role_values = NULL) {

  # Treat missing factor labels as missing values too. (e.g., level = c('male', NA)))
  is_dyad_id_missing <- is.na(dyad_ids) | is.na(as.character(dyad_ids))

  partner_rows <- data.frame(
    fitted_row = seq_along(dyad_ids), # (to later re-align dyads with the response vectors by index)
    dyad_number = match(dyad_ids, unique(dyad_ids)),
    role = if (is.null(role_values)) rep(NA, length(dyad_ids)) else role_values,
    row.names = NULL
  )

  # Only check for missing roles when the user supplied a role colname or vector
  is_role_missing <- !is.null(role_values) &
    (is.na(partner_rows$role) | is.na(as.character(partner_rows$role)))

  # Count before dropping missing roles so repeated observations cannot be hidden.
  original_dyad_sizes <- table(partner_rows$dyad_number[!is_dyad_id_missing])
  if (any(original_dyad_sizes > 2L)) {
    stop("Each dyad must have at most two fitted responses after rows with ",
         "missing dyad IDs are omitted.", call. = FALSE)
  }

  # Remove rows with missing dyad IDs or (if supplied) missing roles.
  # Then keep only dyads with two usable rows.
  partner_rows <- partner_rows[!is_dyad_id_missing & !is_role_missing, ]
  partner_rows <- dplyr::filter(partner_rows, dplyr::n() == 2L, .by = "dyad_number")

  if (nrow(partner_rows) / 2 < 3L) {
    stop("At least three complete dyads are required to check partner dependence.",
         call. = FALSE) #kinda arbitrary and maybe too small, but we shall leave
     # the responsibility of what is sensible with the user.
  }

  # Role order only matters if supplied. Otherwise role_order also stays NULL throughout
  role_order <- NULL
  if (!is.null(role_values)) {
    # Use factor-level order for factors, otherwise sort the role values.
    role_order <- sort(unique(partner_rows$role))
    if (length(role_order) != 2L) {
      stop("Currently, exactly two role values are required among the complete dyads.", call. = FALSE)
    }
    if (any(duplicated(partner_rows[c("dyad_number", "role")]))) {
      stop("Each complete dyad must contain exactly one row for each role value.",
           call. = FALSE)
    }
  }

  # Put partners next to each other, in role order (or row order without roles).
  partner_rows <- partner_rows[order(partner_rows$dyad_number, partner_rows$role), ]
  partner_row_indices <- matrix(partner_rows$fitted_row, ncol = 2L, byrow = TRUE)
  # This reshapes:
  # partner_rows$fitted_row
  # 1 3 4 2
  #
  # into: partner_row_indices
  #      [,1] [,2]
  #[1,]    1    3
  #[2,]    4    2

  # Compare dyad counts before and after filtering, including dyads losing both rows.
  return(list(
    rows = partner_row_indices, role_order = role_order,
    n_incomplete_dyads = length(original_dyad_sizes) - nrow(partner_row_indices),
    n_missing_dyad_rows = sum(is_dyad_id_missing),
    # Count missing roles only on rows with a known dyad ID.
    n_missing_role_rows = sum(is_role_missing & !is_dyad_id_missing)
  ))
}


### Calculating paired statistics ---------------------------------------------

# Partner responses are paired numeric vectors: one value per complete dyad.
# They already use the selected response mode (raw or model-centred).
# Returned names identify table rows and replicated-statistic columns.
calculate_partner_pair_statistics <- function(
  first_partner_responses,
  second_partner_responses,
  compute_role_specific_statistics
) {
  dyad_mean_responses <- (first_partner_responses + second_partner_responses) / 2
  half_partner_differences <- (first_partner_responses - second_partner_responses) / 2
  if (compute_role_specific_statistics) {
    return(c(
      role_1_sd = stats::sd(first_partner_responses),
      role_2_sd = stats::sd(second_partner_responses),
      partner_correlation = suppressWarnings(stats::cor(
        first_partner_responses, second_partner_responses
        # Undefined correlations are reported together after processing all simulations.
        # To avoid repetitive warnings they are suppressed here.
      )),
      dyad_mean_sd = stats::sd(dyad_mean_responses),
      half_difference_sd = stats::sd(half_partner_differences),
      dyad_mean_half_difference_correlation = suppressWarnings(stats::cor(
        dyad_mean_responses, half_partner_differences
      ))
    ))
  }

  # Exchangeability sets the expected half-difference to zero. Its mean square
  # about zero is unchanged by arbitrary within-dyad member swaps.
  dyad_mean_variance <- stats::var(dyad_mean_responses)
  half_difference_mean_square <- mean(half_partner_differences^2)
  common_member_variance <- dyad_mean_variance + half_difference_mean_square
  # common_member_variance here is then equivalent to computing:
  # var(c(member1, member2)) + partner_covariance / (2 * n - 1)
  # so finite sample correction is "built in".
  # Here n is the number of dyads, and partner_covariance is
  # dyad_mean_variance - half_difference_mean_square.

  return(c(
    exchangeable_member_sd = sqrt(common_member_variance),
    exchangeable_partner_correlation =
      (dyad_mean_variance - half_difference_mean_square) / common_member_variance,
    dyad_mean_sd = sqrt(dyad_mean_variance),
    half_difference_rms = sqrt(half_difference_mean_square)
  ))
}


### Statistic labels ----------------------------------------------------------

# One table row per summary, in calculate_partner_pair_statistics() order.
# The first half belongs to the member view; the second to the mean/difference view.
partner_statistic_info <- function(role_order = NULL) {
  statistic_labels <- if (is.null(role_order)) {
    c(
      exchangeable_member_sd = "Common member SD (exchangeable)",
      exchangeable_partner_correlation = "Partner correlation (exchangeable)",
      dyad_mean_sd = "Dyad-average SD",
      half_difference_rms = "Half-difference RMS (about zero)"
    )
  } else {
    role_difference_label <- paste(role_order[[1L]], "minus", role_order[[2L]])
    c(
      role_1_sd = paste0("SD (", role_order[[1L]], ")"),
      role_2_sd = paste0("SD (", role_order[[2L]], ")"),
      partner_correlation = paste0(
        "Partner correlation (", role_order[[1L]], " and ", role_order[[2L]], ")"
      ),
      dyad_mean_sd = "Dyad-average SD",
      half_difference_sd = paste0("Half-difference SD (", role_difference_label, ")"),
      dyad_mean_half_difference_correlation = paste0(
        "Dyad-average/role-difference correlation (", role_difference_label, ")"
      )
    )
  }

  return(data.frame(
    statistic_name = names(statistic_labels),
    parameterization = rep(
      c("member", "mean_difference"), each = length(statistic_labels) / 2L
    ),
    label = unname(statistic_labels)
  ))
}


### Summarizing the simulation reference ---------------------------------------

# Finite responses can still give undefined correlations (e.g. constant counts).
# Summarize each statistic using its defined draws, and report how many remain.
summarize_simulation_reference <- function(observed_statistics, simulated_statistics) {
  if (any(!is.finite(observed_statistics))) {
    stop("Observed partner-dependence summaries are undefined: ",
         paste(names(observed_statistics)[!is.finite(observed_statistics)],
               collapse = ", "),
         ". This can occur with zero variance.", call. = FALSE)
  }
  n_statistics <- length(observed_statistics)
  n_defined_values_by_statistic <- integer(n_statistics)
  observed_statistic_positions <- numeric(n_statistics)
  # Each column holds one statistic's simulated 2.5%, 50%, and 97.5% quantiles.
  simulated_statistic_quantiles <- matrix(
    NA_real_, nrow = 3, ncol = n_statistics
  )
  for (statistic_index in seq_len(n_statistics)) {
    simulated_statistic_values <- simulated_statistics[, statistic_index]
    simulated_statistic_values <-
      simulated_statistic_values[is.finite(simulated_statistic_values)]
    n_defined_values_by_statistic[statistic_index] <- length(simulated_statistic_values)
    # Collect all counts before reporting any empty simulation references below.
    if (n_defined_values_by_statistic[statistic_index] == 0L) next

    simulated_statistic_quantiles[, statistic_index] <- stats::quantile(
      simulated_statistic_values, probs = c(0.025, 0.5, 0.975), names = FALSE
    )
    observed_statistic_positions[statistic_index] <-
      (1 + sum(simulated_statistic_values <= observed_statistics[statistic_index])) /
      (n_defined_values_by_statistic[statistic_index] + 1)
  }
  if (any(n_defined_values_by_statistic == 0L)) {
    stop("Every simulated value is undefined for: ",
         paste(names(observed_statistics)[n_defined_values_by_statistic == 0L],
               collapse = ", "),
         ". A predictive reference cannot be calculated.", call. = FALSE)
  }
  n_undefined_values_by_statistic <-
    nrow(simulated_statistics) - n_defined_values_by_statistic
  if (any(n_undefined_values_by_statistic > 0L)) {
    warning("Undefined simulated summaries (counts out of ", nrow(simulated_statistics),
            "): ", paste(names(observed_statistics)[n_undefined_values_by_statistic > 0L],
                         n_undefined_values_by_statistic[n_undefined_values_by_statistic > 0L],
                         sep = " = ", collapse = "; "),
            ". References use defined values only; inspect their counts.", call. = FALSE)
  }
  return(data.frame(
    observed_value = unname(observed_statistics),
    replicated_median = simulated_statistic_quantiles[2, ],
    replicated_lower = simulated_statistic_quantiles[1, ],
    replicated_upper = simulated_statistic_quantiles[3, ],
    observed_quantile = observed_statistic_positions,
    n_defined = n_defined_values_by_statistic
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
  simulation_settings <- attr(x, "dyadMLM")
  n_simulations <- nrow(x$replicated_statistics)
  statistics_table <- x$statistics_table
  cat("<dyadMLM partner-dependence check>\n")
  cat(nrow(statistics_table), "statistics using", x$n_pairs, "complete pairs\n")
  cat("Response: ", x$response, "\n", sep = "")
  cat("Reference: ", n_simulations, " ", simulation_settings$reference, " datasets with ",
      simulation_settings$random_effects, " random effects\n", sep = "")

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

  statistics_to_print <- statistics_table[c(
    "observed_value", "replicated_median", "replicated_lower",
    "replicated_upper", "observed_quantile", "n_defined"
  )]
  names(statistics_to_print) <- c(
    "Observed", "Median", "2.5%", "97.5%", "Position", "Defined"
  )
  # One small table per statistic keeps long labels out of the numeric columns.
  statistic_print_tables <- split(round(statistics_to_print, digits),
                                   seq_len(nrow(statistics_to_print)))
  names(statistic_print_tables) <- statistics_table$label
  print(statistic_print_tables)
  return(invisible(x))
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
  previous_plot_pause_setting <- grDevices::devAskNewPage(ask)
  on.exit(grDevices::devAskNewPage(previous_plot_pause_setting), add = TRUE)
  n_simulations <- nrow(x$replicated_statistics)
  suggested_histogram_bins <- min(100L, max(20L, round(n_simulations / 5)))

  # Each table row names a replicated_statistics column: one scalar per simulation.
  for (statistic_index in seq_len(nrow(x$statistics_table))) {
    statistic_summary <- x$statistics_table[statistic_index, ]
    simulated_statistic_values <-
      x$replicated_statistics[, statistic_summary$statistic_name]
    simulated_statistic_histogram <- graphics::hist(
      simulated_statistic_values[is.finite(simulated_statistic_values)],
      breaks = suggested_histogram_bins, plot = FALSE
    )
    maximum_bin_count <- max(simulated_statistic_histogram$counts)
    middle_95_simulation_limits <- c(statistic_summary$replicated_lower,
                                     statistic_summary$replicated_upper)

    # Keep complete bars visible and reserve a band above them for the legend.
    graphics::plot(
      simulated_statistic_histogram, freq = TRUE,
      xlim = range(statistic_summary$observed_value, simulated_statistic_histogram$breaks),
      ylim = c(0, maximum_bin_count * 1.25), main = statistic_summary$label,
      sub = paste0(x$response, "; ", x$n_pairs, " pairs; ",
                   statistic_summary$n_defined, "/", n_simulations,
                   " defined simulations"),
      xlab = "Summary value", ...
    )
    graphics::segments(middle_95_simulation_limits, 0, middle_95_simulation_limits,
                       maximum_bin_count, lty = 2, col = "grey40")
    graphics::segments(statistic_summary$observed_value, 0,
                       statistic_summary$observed_value, maximum_bin_count,
                       lwd = 2.5, col = "red")
    graphics::legend(
      "top", legend = c("Observed", "Middle 95% of simulations"),
      lty = c(1, 2), lwd = c(2.5, 1), col = c("red", "grey40"),
      horiz = TRUE, bty = "n"
    )
  }
  return(invisible(x))
}
