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
#'   observed and simulated statistics (one row per simulation), pair and
#'   omission counts, and settings. Can be saved to plot later.
#'
#' @section Reading the plots:
#' Histograms show simulated summaries. Red lines mark observed values.
#' Dashed lines enclose the middle 95% of simulations (no formal confidence
#' intervals).
#'
#' To display all plots together, use `par(mfcol = c(3, 2))` when supplying
#' roles, or `par(mfcol = c(2, 2))` for exchangeable members.
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
#' The warning lists affected dyad IDs and row positions in the fitted data.
#' Long lists are shortened; counts are also shown when printing the result.
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
#'   closeness ~ 1 + gender + (1 | coupleID),
#'   data = example_data
#' )
#'
#' # Fewer simulations for a quick example (the default is 1000).
#' simulations <- simulate_dyad_responses(
#'   model,
#'   nsim = 50,
#'   seed = 123
#' )
#'
#' # Arrange all six checks in one panel.
#' previous_graphics_settings <- par(no.readonly = TRUE)
#' par(mfcol = c(3, 2), mar = c(5.1, 4.1, 2.5, 1), cex = 0.5, cex.main = 0.9)
#' check_partner_dependence(
#'   simulations,
#'   dyad = coupleID,
#'   role = gender,
#'   ask = FALSE
#' )
#'
#' # Optionally, suppress plot, store object, and plot later.
#' check <- check_partner_dependence(
#'   simulations,
#'   dyad = coupleID,
#'   role = gender,
#'   plot = FALSE
#' )
#'
#' plot(check, ask = FALSE)
#' par(previous_graphics_settings)
#' print(check)
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

    statistics_by_dataset[[dataset_index]] <- calculate_partner_pair_statistics(
      first_partner_responses,
      second_partner_responses,
      role_order = partner_row_map$role_order
    )
  }

  # Object is currently:
  # statistics_by_dataset object is currently a list of 1,001 named vectors
  # [[1]]                     6 observed statistics
  # [[2]]                     6 statistics from simulation 1
  # ...
  # [[1001]]                  6 statistics from simulation 1,000

  observed_statistics <- statistics_by_dataset[[1]]
  simulated_statistics <- do.call(rbind, statistics_by_dataset[-1])

  # now, the object is:
  # observed_statistics         numeric vector of length 6
  #
  # simulated_statistics        numeric matrix: 1,000 rows × 6 columns
  # rows = simulations
  # 6 or 4 columns = 6 or 4 statistics

  # Undefined correlations are possible (e.g. constant counts).
  ## 1. Stop if any observed statistic is undefined: there is no value to compare.
  if (any(!is.finite(observed_statistics))) {
    stop("Observed partner-dependence summaries are undefined: ",
         paste(names(observed_statistics)[!is.finite(observed_statistics)],
               collapse = ", "),
         ". This could be due to zero variance.", call. = FALSE)
  }
  ## 2. Stop if any of the 4 or 6 statistics are **never** defined in any simulation:
  ##    there is no simulation reference for comparison.
  n_defined_by_statistic <- colSums(is.finite(simulated_statistics))
  if (any(n_defined_by_statistic == 0L)) {
    stop("Every simulated value is undefined for: ",
         paste(names(observed_statistics)[n_defined_by_statistic == 0L],
               collapse = ", "),
         ". A predictive reference cannot be calculated.", call. = FALSE)
  }
  ## 3. Warn if any of the 4 or 6 statistics have **some** simulated values that
  ##    are undefined. Plots are possible and use only the defined values.
  n_undefined_by_statistic <- nrow(simulated_statistics) - n_defined_by_statistic
  if (any(n_undefined_by_statistic > 0L)) {
    warning("Undefined simulated summaries (counts out of ", nrow(simulated_statistics),
            "): ", paste(names(observed_statistics)[n_undefined_by_statistic > 0L],
                         n_undefined_by_statistic[n_undefined_by_statistic > 0L],
                         sep = " = ", collapse = "; "),
            ". Plots use defined values only.", call. = FALSE)
  }

  # Store one observed value per statistic and one simulated value per simulation.
  # Each observed value and its simulation column share the same statistic name.
  check_result <- list(
    observed_statistics = observed_statistics, # vector of observed stats
    replicated_statistics = simulated_statistics, # matrix: rows = simulations, columns = statistics
    n_pairs = nrow(partner_row_map$rows),
    n_incomplete_dyads = length(partner_row_map$incomplete_dyad_ids),
    n_missing_dyad_rows = length(partner_row_map$missing_dyad_rows),
    n_missing_role_rows = length(partner_row_map$missing_role_rows),
    response = response
  )

  # Copy the simulation settings to the check result.
  attr(check_result, "dyadMLM") <- attr(simulations, "dyadMLM")

  # Assign custom class
  class(check_result) <- c("dyadMLM_partner_check", "list")

  # List affected dyads and fitted-row numbers, leaving out empty categories.
  omission_details <- c(
    if (check_result$n_incomplete_dyads > 0L) format_group_count(
      partner_row_map$incomplete_dyad_ids,
      singular = "incomplete dyad", plural = "incomplete dyads"
    ),
    if (check_result$n_missing_dyad_rows > 0L) paste0(
      "fitted rows with missing dyad IDs (n = ", check_result$n_missing_dyad_rows,
      "): ", format_group_list(partner_row_map$missing_dyad_rows)
    ),
    if (check_result$n_missing_role_rows > 0L) paste0(
      "fitted rows with missing roles (n = ", check_result$n_missing_role_rows,
      "): ", format_group_list(partner_row_map$missing_role_rows)
    )
  )
  if (length(omission_details) > 0L) {
    warning("Omitted: ", paste(omission_details, collapse = "; "), ".", call. = FALSE)
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

  # Keep omitted IDs and fitted-row numbers for the warning and omission counts.
  # Include known dyads that lost both rows when missing roles were removed.
  return(list(
    rows = partner_row_indices, role_order = role_order,
    incomplete_dyad_ids = unique(dyad_ids[
      !is_dyad_id_missing & !dyad_ids %in% dyad_ids[partner_row_indices]
    ]),
    missing_dyad_rows = which(is_dyad_id_missing),
    # Report missing roles only on rows with a known dyad ID.
    missing_role_rows = which(is_role_missing & !is_dyad_id_missing)
  ))
}


### Calculating paired statistics ---------------------------------------------

# Partner responses are paired numeric vectors: one value per complete dyad.
# They already use the selected response mode (raw or model-centred).
# Returned names identify observed statistics and their simulation columns.
calculate_partner_pair_statistics <- function(
  first_partner_responses,
  second_partner_responses,
  role_order = NULL
) {
  dyad_mean_responses <- (first_partner_responses + second_partner_responses) / 2
  half_partner_differences <- (first_partner_responses - second_partner_responses) / 2
  if (!is.null(role_order)) {
    statistics <- c(
      stats::sd(first_partner_responses),
      stats::sd(second_partner_responses),
      suppressWarnings(stats::cor(
        first_partner_responses, second_partner_responses
        # Undefined correlations are reported together after processing all simulations.
        # To avoid repetitive warnings they are suppressed here.
      )),
      stats::sd(dyad_mean_responses),
      stats::sd(half_partner_differences),
      suppressWarnings(stats::cor(
        dyad_mean_responses, half_partner_differences
      ))
    )

    # Assign meaningful names to the observed vector, simulation columns, and plot titles.
    role_difference_label <- paste(role_order[[1L]], "minus", role_order[[2L]])
    names(statistics) <- c(
      paste0("SD (", role_order, ")"),
      paste0("Partner correlation (", role_order[[1L]], " and ", role_order[[2L]], ")"),
      "Dyad-average SD",
      paste0("Half-difference SD (", role_difference_label, ")"),
      paste0("Dyad-average/role-difference correlation (", role_difference_label, ")")
    )
    return(statistics)
  }

  # In case there is no role provided:

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
    "Common member SD (exchangeable)" = sqrt(common_member_variance),
    "Partner correlation (exchangeable)" =
      (dyad_mean_variance - half_difference_mean_square) / common_member_variance,
    "Dyad-average SD" = sqrt(dyad_mean_variance),
    "Half-difference RMS (about zero)" = sqrt(half_difference_mean_square)
  ))
}


### Printing results ----------------------------------------------------------

#' Print a summary of the partner-dependence predictive check object.
#'
#' Use [plot.dyadMLM_partner_check()] to view the comparisons.
#'
#' @param x An object returned by [check_partner_dependence()].
#' @param ... Not used.
#'
#' @return `x`, invisibly.
#'
#' @keywords internal
#'
#' @export
print.dyadMLM_partner_check <- function(x, ...) {
  # Read saved settings; printing does not rerun the check.
  simulation_settings <- attr(x, "dyadMLM")
  # replicated_statistics is a matrix with one row per simulation.
  n_simulations <- nrow(x$replicated_statistics)
  cat("<dyadMLM partner-dependence check>\n")
  cat(length(x$observed_statistics), "statistics using", x$n_pairs, "complete pairs\n")
  cat("Response: ", x$response, "\n", sep = "")
  cat("Reference: ", n_simulations, " ", simulation_settings$reference, " datasets with ",
      simulation_settings$random_effects, " random effects\n", sep = "")

  # A named vector of counts: dyads for the first entry, rows for the others.
  omitted_counts <- c(
    "incomplete dyads" = x$n_incomplete_dyads,
    "rows with missing dyad IDs" = x$n_missing_dyad_rows,
    "rows with missing roles" = x$n_missing_role_rows
  )
  # Keep only nonzero counts, retaining their names for the printed labels.
  omitted_counts <- omitted_counts[omitted_counts > 0L]
  if (length(omitted_counts) > 0L) {
    # Join the entries into one line, e.g. "incomplete dyads: 2; rows with missing roles: 1".
    cat("Omitted: ", paste0(names(omitted_counts), ": ", omitted_counts,
                           collapse = "; "), "\n", sep = "")
  }

  cat("Use plot(x) to view the comparisons.\n")
  # Return the same check object without displaying the full list.
  return(invisible(x))
}


### Plotting results ----------------------------------------------------------

#' Plot a saved partner-dependence check
#'
#' `r lifecycle::badge("experimental")`
#' Draws the comparison plots without repeating simulations.
#'
#' See [check_partner_dependence()] for interpretation, panel layouts, and
#' technical details.
#'
#' @param x A `dyadMLM_partner_check` object.
#' @param ask `TRUE` pauses before the next plot. `FALSE` draws all plots
#'   without pausing. `NULL` (default) chooses automatically.
#' @param ... Additional graphical arguments passed to [graphics::plot()].
#'   `freq`, `xlim`, `ylim`, `main`, `sub`, and `xlab` are controlled by this
#'   method.
#'
#' @return Invisibly, `x`.
#'
#' @examplesIf requireNamespace("glmmTMB", quietly = TRUE)
#' example_data <- dyads_cross[dyads_cross$coupleID <= 40, ]
#'
#' model <- glmmTMB::glmmTMB(
#'   closeness ~ 1 + gender + (1 | coupleID),
#'   data = example_data
#' )
#'
#' simulations <- simulate_dyad_responses(
#'   model,
#'   nsim = 50,
#'   seed = 123
#' )
#'
#' check <- check_partner_dependence(
#'   simulations,
#'   dyad = coupleID,
#'   role = gender,
#'   plot = FALSE
#' )
#'
#' previous_graphics_settings <- par(no.readonly = TRUE)
#' par(mfcol = c(3, 2), mar = c(5.1, 4.1, 2.5, 1), cex = 0.5, cex.main = 0.9)
#' plot(check, ask = FALSE)
#' par(previous_graphics_settings)
#'
#' @export
plot.dyadMLM_partner_check <- function(x, ask = NULL, ...) {

  if (is.null(ask)) {
    ask <- length(x$observed_statistics) > 1L && grDevices::dev.interactive()
  }

  previous_plot_pause_setting <- grDevices::devAskNewPage(ask)

  on.exit(grDevices::devAskNewPage(previous_plot_pause_setting), add = TRUE)

  n_simulations <- nrow(x$replicated_statistics)
  suggested_histogram_bins <- min(100L, max(20L, round(n_simulations / 5)))

  # Match observed values and simulation columns by position. Names are plot labels.
  for (statistic_index in seq_along(x$observed_statistics)) {
    statistic_name <- names(x$observed_statistics)[[statistic_index]]
    observed_statistic_value <- x$observed_statistics[[statistic_index]]

    simulated_statistic_values <-
      x$replicated_statistics[, statistic_index]
    simulated_statistic_values <-
      simulated_statistic_values[is.finite(simulated_statistic_values)]

    middle_95_simulation_limits <- stats::quantile(
      simulated_statistic_values, c(0.025, 0.975), names = FALSE
    )

    simulated_statistic_histogram <- graphics::hist(
      simulated_statistic_values,
      breaks = suggested_histogram_bins, plot = FALSE
    )

    maximum_bin_count <- max(simulated_statistic_histogram$counts)

    # Keep complete bars visible and reserve a band above them for the legend.
    graphics::plot(
      simulated_statistic_histogram, freq = TRUE,
      xlim = range(observed_statistic_value, simulated_statistic_histogram$breaks),
      ylim = c(0, maximum_bin_count * 1.25), main = statistic_name,
      sub = paste0(x$response, "; ", x$n_pairs, " pairs; ",
                   length(simulated_statistic_values), "/", n_simulations,
                   " defined simulations"),
      xlab = "Summary value", ...
    )

    graphics::segments(middle_95_simulation_limits, 0, middle_95_simulation_limits,
                       maximum_bin_count, lty = 2, col = "grey40")

    graphics::segments(observed_statistic_value, 0,
                       observed_statistic_value, maximum_bin_count,
                       lwd = 2.5, col = "red")

    graphics::legend(
      "top", legend = c("Observed", "Middle 95% of simulations"),
      lty = c(1, 2), lwd = c(2.5, 1), col = c("red", "grey40"),
      horiz = TRUE, bty = "n"
    )
  }
  return(invisible(x))
}
