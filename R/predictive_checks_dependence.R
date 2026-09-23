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
#' @param dyad The dyad column name. Looked up first
#'   in the fitted model frame, then in `data` if supplied.
#' @param role The role column name. Looked up first
#'   in the fitted model frame, then in `data` if supplied.
#'   `NULL` (default) pools all dyads as exchangeable. Supply roles
#'   even for an exchangeable model to reveal variance or partner-correlation
#'   mismatches that pooling may hide. Each role pair is checked separately,
#'   using exchangeable summaries for same-role pairs and role-specific
#'   summaries otherwise.
#' @param plot If `TRUE` (default), draw the comparison plots for visual checks.
#'   If `FALSE`, `ask` and `panels` are ignored.
#' @param response `"model-centred"` (default) subtracts the same model predictions
#'   from observed and simulated responses. The predictive check then assesses
#'   whether the model reproduces the variance and partner correlations remaining
#'   after accounting for its fixed-effect predictions. This includes random
#'   effects and observation-level noise. With `"raw"`, the predictive check
#'   assesses whether the full model, including fixed effects, reproduces the
#'   overall response variances and partner correlations.
#'   See [simulate_dyad_responses()] for how predictions are defined.
#' @param ask Whether to pause between figures on an interactive device.
#'   `NULL` (default) pauses when there is more than one figure, `TRUE` pauses
#'   and `FALSE` draws without pausing. In panel mode, each composition is one
#'   figure. File devices never pause.
#' @param panels If `TRUE` (default), show each composition in one figure, with
#'   two rows and up to three columns. If `FALSE`, draw each statistic separately.
#'   Graphics settings are restored afterwards.
#' @param data Optional data frame used to fit the model. Supply it when `dyad`
#'   or `role` is absent from the fitted model frame. Use the exact unchanged
#'   data that was passed to the model when fitting.
#'
#' @return The comparison plots (shown by default) are the main output. The
#'   function invisibly returns a `dyadMLM_partner_check` object containing the
#'   `compositions` table with pair counts and a statistics tibble for each
#'   composition. Each tibble has one observed row followed by one row per
#'   simulation, identified by `dataset`. The object includes omission counts
#'   and settings, and can be saved and plotted later.
#'
#' @section Reading the plots:
#' Histograms show simulated summaries. Red lines mark observed values.
#' Dashed lines enclose the middle 95% of simulations (no formal confidence
#' intervals).
#' The heading shows the dyad composition, its number of usable dyads, and the
#' total across all compositions. The top row shows member SDs and partner
#' correlation. The bottom row shows the same information using dyad averages
#' and partner differences.
#'
#' An observed value far from most simulated values may indicate that the
#' model does not reproduce that feature of the data well.
#' Agreement does not establish that omitted dependence is negligible, especially
#' with few dyads. The [simulation study](https://pascal-kueng.github.io/dyadMLM/articles/partner-dependence-simulation.html)
#' illustrates how sample size affects detection when residual partner
#' correlation is omitted.
#'
#' The first set of plots compares:
#' - **Response SDs:** one for each role, or one common SD for exchangeable members.
#' - **Partner correlation:** how strongly partners' responses are related.
#'
#' The second set shows *the same information* using dyad averages and partner
#' differences:
#' - **Dyad-average SD:** how much dyads differ in their average response.
#' - **Half-difference SD or RMS:** each partner difference is divided by two.
#'   With distinct roles, the SD shows how much signed differences vary
#'   across dyads. For exchangeable members, the RMS shows their typical size, regardless of
#'   partner order.
#' - **Mean/difference correlation:** plotted only for distinct roles,
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
#'
#' @section Technical details:
#' After any centring, paired responses `a` and `b` are used to compute
#' dyad averages `M = (a + b) / 2` and half-differences `D = (a - b) / 2`.
#' Roles follow factor levels or sorted values.
#'
#' For exchangeable members, common member variance is `var(M) + mean(D^2)` and
#' partner covariance is `var(M) - mean(D^2)`. Partner correlation is
#' covariance divided by variance. Half-difference RMS is `sqrt(mean(D^2))`.
#'
#' The variance and covariance calculations for exchangeable dyads follow
#' Woody and Sadler (2005).
#'
#' @examplesIf requireNamespace("glmmTMB", quietly = TRUE)
#' # Data contains three compositions: female-female, female-male, and male-male.
#' example_data <- prepare_dyad_data(
#'   dyads_cross,
#'   dyad = coupleID,
#'   member = personID,
#'   model_types = "none",
#'   seed = 123
#' )
#'
#' # This model pools all compositions and treats every dyad as exchangeable.
#' model <- glmmTMB::glmmTMB(
#'   closeness ~ 1 +
#'     us(1 | coupleID) +
#'     us(0 + .member_contrast_arbitrary | coupleID),
#'   dispformula = ~ 0,
#'   data = example_data
#' )
#'
#' # Fewer simulations for a quick example (the default is 1000).
#' simulations <- simulate_dyad_responses(
#'   model,
#'   nsim = 100,
#'   seed = 123
#' )
#'
#' check_partner_dependence(
#'   simulations,
#'   dyad = coupleID,
#'   role = gender,
#'   # Supply the fitting data because gender is not in the model formula.
#'   data = example_data
#' )
#'
#' # Optionally, suppress plot, store object, and plot later.
#' check <- check_partner_dependence(
#'   simulations,
#'   dyad = coupleID,
#'   role = gender,
#'   data = example_data,
#'   plot = FALSE
#' )
#'
#' # Check how well the model reproduces variances and partner correlations
#' # within each dyad composition.
#' plot(check, ask = FALSE, panels = TRUE)
#' print(check)
#'
#'
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
  ask = NULL,
  panels = TRUE,
  data = NULL
) {
  if (!inherits(simulations, "dyadMLM_response_simulations")) {
    stop("`simulations` must be created by `simulate_dyad_responses()`.", call. = FALSE)
  }
  if (missing(dyad)) {
    stop("`dyad` must identify the dyad for each fitted row.", call. = FALSE)
  }

  response <- match.arg(response)
  fitted_model_frame <- simulations$model_frame

  # The pair table identifies both partners' positions in the fitted data.
  partner_row_map <- prepare_partner_pairs(
    resolve_fitted_row_argument(rlang::enquo(dyad), "dyad", fitted_model_frame, data),
    resolve_fitted_row_argument(rlang::enquo(role), "role", fitted_model_frame,
                                data, allow_null = TRUE)
  )
  compositions <- partner_row_map$compositions
  checked_composition_indices <- which(compositions$n_pairs >= 3L)
  skipped_composition_indices <- which(compositions$n_pairs < 3L)
  compositions$statistics <- vector("list", nrow(compositions))
  n_simulations <- nrow(simulations$simulated_responses)

  # Combine the observed and simulated response vectors into one large matrix.
  responses_by_dataset <- rbind(
    simulations$observed_response, unname(simulations$simulated_responses)
  )
  if (response == "model-centred") {
    responses_by_dataset <- sweep(responses_by_dataset, 2, simulations$predicted_response, "-")
  }
  dataset_labels <- c("observed", paste0("simulation_", seq_len(n_simulations)))

  # Collect diagnostics so each message covers all compositions.
  statistic_diagnostics_by_composition <- vector("list", nrow(compositions))
  for (current_composition_index in checked_composition_indices) {
    composition_pair_rows <- partner_row_map$pairs |>
      dplyr::filter(.data$composition_index == current_composition_index)
    statistics_by_dataset <- vector("list", nrow(responses_by_dataset))
    for (dataset_index in seq_len(nrow(responses_by_dataset))) {
      dataset_responses <- responses_by_dataset[dataset_index, ]
      first_partner_responses <- dataset_responses[composition_pair_rows$first_partner_row]
      second_partner_responses <- dataset_responses[composition_pair_rows$second_partner_row]

      statistics_by_dataset[[dataset_index]] <- calculate_partner_pair_statistics(
        first_partner_responses,
        second_partner_responses,
        role_order = partner_row_map$role_orders[[current_composition_index]]
      )
    }
    composition_statistics <- do.call(rbind, statistics_by_dataset)
    compositions$statistics[[current_composition_index]] <- composition_statistics |>
      tibble::as_tibble(.name_repair = "minimal") |>
      tibble::add_column(dataset = dataset_labels, .before = 1, .name_repair = "minimal") # .name_repair = "minimal" preserves the statistic names exactly, including duplicates that can arise when distinct roles have identical printed labels.

    observed_statistics <- composition_statistics[1, ]
    simulated_statistics <- composition_statistics[-1, , drop = FALSE]
    statistic_diagnostics_by_composition[[current_composition_index]] <- tibble::tibble(
      description = paste(compositions$label[current_composition_index],
                          names(observed_statistics), sep = ": "),
      observed_is_defined = is.finite(observed_statistics),
      n_defined_simulations = colSums(is.finite(simulated_statistics))
    )
  }
  statistic_diagnostics <- dplyr::bind_rows(statistic_diagnostics_by_composition)
  statistic_descriptions <- statistic_diagnostics$description

  # Undefined correlations are possible (e.g. constant counts).
  ## 1. Stop if any observed statistic is undefined: there is no value to compare.
  if (any(!statistic_diagnostics$observed_is_defined)) {
    stop("Observed partner-dependence summaries are undefined: ",
         paste(statistic_descriptions[!statistic_diagnostics$observed_is_defined],
               collapse = ", "),
         ". This could be due to zero variance.", call. = FALSE)
  }
  ## 2. Stop if a statistic is never defined in any simulation:
  ##    there is no simulation reference for comparison.
  n_defined_by_statistic <- statistic_diagnostics$n_defined_simulations
  if (any(n_defined_by_statistic == 0L)) {
    stop("Every simulated value is undefined for: ",
         paste(statistic_descriptions[n_defined_by_statistic == 0L], collapse = ", "),
         ". A predictive reference cannot be calculated.", call. = FALSE)
  }
  ## 3. Warn if any statistics have some simulated values that
  ##    are undefined. Plots are possible and use only the defined values.
  n_undefined_by_statistic <- n_simulations - n_defined_by_statistic
  if (any(n_undefined_by_statistic > 0L)) {
    warning("Undefined simulated summaries (counts out of ", n_simulations,
            "): ", paste(statistic_descriptions[n_undefined_by_statistic > 0L],
                         n_undefined_by_statistic[n_undefined_by_statistic > 0L],
                         sep = " = ", collapse = "; "),
            ". Plots use defined values only.", call. = FALSE)
  }

  check_result <- list(
    compositions = compositions,
    n_pairs = nrow(partner_row_map$pairs),
    n_simulations = n_simulations,
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
  if (length(skipped_composition_indices) > 0L) {
    warning("Not checked (fewer than three complete pairs): ",
            paste0(compositions$label[skipped_composition_indices], " (n = ",
                   compositions$n_pairs[skipped_composition_indices], ")",
                   collapse = "; "), ".", call. = FALSE)
  }
  if (missing(role)) {
    message("No role supplied: summaries pool partners. Supply `role` to check ",
            "each composition separately, even if the model did not include it. ",
            "Use `role = NULL` to pool without this message.")
  }
  if (plot) graphics::plot(check_result, ask = ask, panels = panels)
  return(invisible(check_result))
}


### Matching partners ---------------------------------------------------------

# Build the pair map. Reusable for observed and simulated responses.
prepare_partner_pairs <- function(dyad_ids, role_values = NULL) {

  # Treat missing factor labels as missing values too. (e.g., level = c('male', NA)))
  is_dyad_id_missing <- is.na(dyad_ids) | is.na(as.character(dyad_ids))

  partner_rows <- tibble::tibble(
    fitted_row = seq_along(dyad_ids), # (to later re-align dyads with the response vectors by index)
    dyad_number = match(dyad_ids, unique(dyad_ids)),
    role = if (is.null(role_values)) rep(NA, length(dyad_ids)) else role_values
  )

  # Only check for missing roles when roles were supplied.
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
  partner_rows <- partner_rows |>
    dplyr::filter(!is_dyad_id_missing & !is_role_missing) |>
    dplyr::filter(dplyr::n() == 2L, .by = "dyad_number")

  if (nrow(partner_rows) / 2 < 3L) {
    stop("At least three complete dyads are required to check partner dependence.",
         call. = FALSE) #kinda arbitrary and maybe too small, but we shall leave
     # the responsibility of what is sensible with the user.
  }

  # Integer role codes keep different values separate even if labels look alike.
  # Factors keep their level order; other roles use sorted values.
  ordered_role_values <- sort(unique(partner_rows$role))
  # Build one row per dyad, with partners in role order (or row order without roles).
  pairs <- partner_rows |>
    dplyr::mutate(
      role_index = if (is.null(role_values)) 0L else match(.data$role, ordered_role_values)
    ) |>
    dplyr::arrange(.data$dyad_number, .data$role_index) |>
    dplyr::summarise(
      first_partner_row = dplyr::first(.data$fitted_row),
      second_partner_row = dplyr::last(.data$fitted_row),
      first_partner_role_index = dplyr::first(.data$role_index),
      second_partner_role_index = dplyr::last(.data$role_index),
      .by = "dyad_number"
    ) |>
    # Give identical role pairs the same composition number, in role order.
    dplyr::mutate(composition_index = dplyr::dense_rank(
      dplyr::pick("first_partner_role_index", "second_partner_role_index")
    ))
  compositions <- tibble::tibble(
    label = "All dyads", # will be overwritten / re-assigned later per composition
    n_pairs = tabulate(pairs$composition_index)
  )
  role_orders <- vector("list", nrow(compositions))
  if (!is.null(role_values)) {
    for (composition_index in seq_len(nrow(compositions))) {
      first_pair_index <- match(composition_index, pairs$composition_index)
      composition_role_indices <- c(pairs$first_partner_role_index[first_pair_index],
                                    pairs$second_partner_role_index[first_pair_index])
      composition_roles <- ordered_role_values[composition_role_indices]
      compositions$label[composition_index] <- paste(composition_roles, collapse = " - ")
      if (composition_role_indices[1] != composition_role_indices[2]) {
        role_orders[[composition_index]] <- composition_roles
      }
      # Same-role pairs keep NULL, selecting the exchangeable statistics.
    }
  }
  if (!any(compositions$n_pairs >= 3L)) {
    stop("At least one composition must contain three complete dyads.", call. = FALSE)
  }

  # Keep omitted IDs and fitted-row numbers for the warning and omission counts.
  # Include known dyads that lost both rows when missing roles were removed.
  return(list(
    pairs = dplyr::select(pairs, "composition_index", "first_partner_row", "second_partner_row"),
    role_orders = role_orders, compositions = compositions,
    incomplete_dyad_ids = unique(dyad_ids[
      !is_dyad_id_missing & !dyad_ids %in% dyad_ids[partner_rows$fitted_row]
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

  # Without distinct roles, use the exchangeable summaries.

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
  # Each table has one dataset column followed by the statistics.
  n_statistics <- sum(vapply(x$compositions$statistics,
    function(statistics) if (is.null(statistics)) 0L else ncol(statistics) - 1L, integer(1)))
  cat("<dyadMLM partner-dependence check>\n")
  cat(n_statistics, "statistics;", x$n_pairs, "usable complete pairs\n")
  cat("Response: ", x$response, "\n", sep = "")
  cat("Reference: ", x$n_simulations, " ", simulation_settings$reference, " datasets with ",
      simulation_settings$random_effects, " random effects\n", sep = "")

  for (composition_index in seq_len(nrow(x$compositions))) {
    composition <- x$compositions[composition_index, ]
    cat(composition$label, ": ", composition$n_pairs, " of ", x$n_pairs,
        " usable dyads", sep = "")
    if (is.null(composition$statistics[[1]])) {
      cat("; not checked (fewer than three complete pairs)")
    }
    cat("\n")
  }

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
#' @keywords internal
#'
#' @param x A `dyadMLM_partner_check` object.
#' @inheritParams check_partner_dependence
#' @param ... Additional graphical arguments passed to [graphics::plot()].
#'   `freq`, `xlim`, `ylim`, `main`, `sub`, and `xlab` are controlled by this
#'   method.
#'
#' @return Invisibly, `x`.
#'
#' @examplesIf requireNamespace("glmmTMB", quietly = TRUE)
#' example_data <- prepare_dyad_data(
#'   dyads_cross[dyads_cross$coupleID <= 40, ],
#'   dyad = coupleID,
#'   member = personID,
#'   model_types = "none",
#'   seed = 123
#' )
#'
#' model <- glmmTMB::glmmTMB(
#'   closeness ~ 1 +
#'     us(1 | coupleID) +
#'     us(0 + .member_contrast_arbitrary | coupleID),
#'   dispformula = ~ 0,
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
#'   data = example_data,
#'   plot = FALSE
#' )
#'
#' plot(check, ask = FALSE)
#'
#' @export
plot.dyadMLM_partner_check <- function(x, ask = NULL, panels = TRUE, ...) {

  checked_composition_indices <- which(x$compositions$n_pairs >= 3L)
  number_of_figures <- if (panels) length(checked_composition_indices) else
    sum(vapply(x$compositions$statistics[checked_composition_indices], ncol, integer(1)) - 1L)
  if (is.null(ask)) {
    ask <- number_of_figures > 1L
  }
  # File devices and report rendering should never wait for keyboard input.
  ask <- ask && grDevices::dev.interactive()

  if (panels) {
    previous_graphics_settings <- graphics::par(no.readonly = TRUE)
    on.exit({
      graphics::par(previous_graphics_settings)
      # Restoring the layout resets scaling; scaling changes the plot region.
      graphics::par(previous_graphics_settings[c("cex", "mex", "plt")])
    }, add = TRUE)
  }
  previous_plot_pause_setting <- grDevices::devAskNewPage(ask)
  on.exit(grDevices::devAskNewPage(previous_plot_pause_setting), add = TRUE)

  n_simulations <- x$n_simulations
  suggested_histogram_bins <- min(100L, max(20L, round(n_simulations / 5)))

  for (composition_index in checked_composition_indices) {
    composition <- x$compositions[composition_index, ]
    # The first row is observed; the remaining rows are simulations.
    composition_statistics <- composition$statistics[[1]][, -1]
    composition_title <- paste0(composition$label, " - ", composition$n_pairs,
                                " of ", x$n_pairs, " usable dyads")
    if (panels) {
      graphics::par(mfrow = c(2, ncol(composition_statistics) / 2),
                    mar = c(5.1, 4.1, 4, 1), oma = c(0, 0, 3, 0),
                    cex = 0.7, cex.main = 1)
    }

    # Match observed values and simulations by position, since names may repeat.
    for (statistic_index in seq_along(composition_statistics)) {
      statistic_name <- names(composition_statistics)[[statistic_index]]
      observed_statistic_value <- composition_statistics[[statistic_index]][1]

      simulated_statistic_values <-
        composition_statistics[[statistic_index]][-1]
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
      plot_title <- paste(strwrap(statistic_name, width = if (panels) 30 else 60),
                          collapse = "\n")
      if (!panels) plot_title <- paste(composition_title, plot_title, sep = "\n")
      plot_subtitle <- paste0(length(simulated_statistic_values), "/", n_simulations,
                              " simulations used")
      if (!panels) plot_subtitle <- paste(x$response, plot_subtitle, sep = "; ")
      graphics::plot(
        simulated_statistic_histogram, freq = TRUE,
        xlim = range(observed_statistic_value, simulated_statistic_histogram$breaks),
        ylim = c(0, maximum_bin_count * if (panels) 1.4 else 1.25),
        main = plot_title,
        sub = plot_subtitle,
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
        horiz = !panels, cex = if (panels) 0.85 else 1, bty = "n"
      )
    }
    if (panels) {
      graphics::mtext(paste(composition_title, x$response, sep = "; "),
                      side = 3, outer = TRUE, line = 1, cex = 1, font = 2)
    }
  }
  return(invisible(x))
}
