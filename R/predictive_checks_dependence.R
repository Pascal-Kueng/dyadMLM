### Checking partner dependence -----------------------------------------------

#' Check whether a fitted model reproduces partner dependence
#'
#' `r lifecycle::badge("experimental")`
#' A dyadic model should reproduce how much responses vary and how strongly
#' partners' responses are related. This check computes variances and correlations
#' of simulated responses based on the model and compares them to the observed
#' response variances and correlations from the data.
#' This helps identify mismatches in the model's assumptions. The check
#' currently supports cross-sectional dyads only (one response per partner).
#'
#' @param simulations An object returned by [simulate_dyad_responses()].
#' @param dyad The dyad column name. Looked up first
#'   in the fitted model frame, then in `data` if supplied.
#' @param role The role column name. Looked up first
#'   in the fitted model frame, then in `data` if supplied.
#'   `NULL` (default) pools all dyads as exchangeable. Supply roles
#'   even for an exchangeable model to reveal variance or partner-correlation
#'   mismatches that pooling may hide. Each dyad composition (role pair, such as
#'   female-male) is checked separately,
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
#' @param data Optional: the unchanged data frame used to fit the model. Supply
#'   it when `dyad` or `role` is not in the model formulas.
#'
#' @return The comparison plots (shown by default) are the main output. The
#'   function invisibly returns a `dyadMLM_partner_check` object containing the
#'   `compositions` table with pair counts and a statistics tibble for each
#'   composition. Each tibble has one observed row followed by one row per
#'   simulation, identified by `dataset`. `summary` compares each `observed`
#'   statistic with the middle 95% of its simulations (`lower`, `upper`) and marks
#'   those `outside` it. The object includes omission counts and settings, and can
#'   be saved and plotted later.
#'
#' @section Reading the plots:
#' Blue histograms show simulated summaries. Red lines mark observed values.
#' Dashed lines enclose the middle 95% of simulations (no formal confidence
#' intervals).
#' The composition heading follows the same layout as [check_residuals()].
#' Below it are the number of usable dyads and the total across all compositions.
#' The top row shows member SDs and partner correlation. The bottom row shows the same information using dyad averages
#' and partner differences.
#'
#' An observed value far from most simulated values may indicate that the
#' model does not reproduce that feature of the data well.
#' Agreement does not establish that omitted dependence is negligible, especially
#' with few dyads. The [partner-dependence study](https://pascal-kueng.github.io/dyadMLM/articles/partner-dependence-simulation.html)
#' illustrates how sample size affects detection when residual partner
#' correlation is omitted.
#'
#' Checking each composition can reveal differences hidden by pooling.
#' Flags (observed values outside the middle 95%, marked `*` when printed) can
#' occur by chance, especially when checking several summaries.
#' They invite investigation, not formal rejection of the model. The
#' [covariance-pooling study](https://pascal-kueng.github.io/dyadMLM/articles/covariance-pooling.html)
#' illustrates detection and false alarms when checking each composition; 10 to
#' 29% of correctly pooled models had at least one flag.
#'
#' The top row compares:
#' - **Response SDs:** one for each role, or one common SD for exchangeable members.
#' - **Partner correlation:** how strongly partners' responses are related.
#'
#' The bottom row shows:
#' - **Dyad-average SD:** how much dyads differ in their average response.
#' - **Half-difference SD or RMS:** each partner difference is divided by two.
#'   With distinct roles, the SD shows how much signed differences vary
#'   across dyads. For exchangeable members, the RMS (root mean square) shows
#'   their typical size, regardless of
#'   partner order.
#' - **Dyad-average/role-difference correlation:** shown only for distinct roles,
#'   because it depends on how partners are ordered. Positive values indicate
#'   greater variance for the first named role. Negative values indicate greater
#'   variance for the second.
#'
#' These checks are particularly useful when a less restricted model does not
#' converge and so cannot be used for model comparison. They show how well the
#' simpler model
#' reproduces the observed variances and partner correlations.
#'
#' A flexible covariance model will usually reproduce features it estimated from
#' the same data. Agreement alone therefore does not establish good fit.
#' For example, pooled summaries (`role = NULL`) of a Gaussian model with an
#' unconstrained exchangeable covariance, as below, agree almost by construction.
#' Use a suitable model comparison to formally test a specific covariance
#' restriction when both models can be fitted (see [compare_nested_models()]).
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
#' # Composition checks flag differences that the pooled check misses.
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
  ## 3. Warn if any statistics have some simulated values that are undefined.
  ##    Plots and summaries are possible and use only the defined values.
  n_undefined_by_statistic <- n_simulations - n_defined_by_statistic
  if (any(n_undefined_by_statistic > 0L)) {
    warning("Undefined simulated summaries (counts out of ", n_simulations,
            "): ", paste(statistic_descriptions[n_undefined_by_statistic > 0L],
                         n_undefined_by_statistic[n_undefined_by_statistic > 0L],
                         sep = " = ", collapse = "; "),
            ". Plots and summaries use defined values only.", call. = FALSE)
  }

  summary_by_composition <- lapply(checked_composition_indices, function(composition_index) {
    tibble::tibble(
      composition = compositions$label[[composition_index]],
      summarise_partner_statistics(compositions$statistics[[composition_index]])
    )
  })

  check_result <- list(
    compositions = compositions,
    summary = dplyr::bind_rows(summary_by_composition),
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


### Summarising statistics ----------------------------------------------------

# Middle 95% of the defined simulated values, as printed and plotted.
simulated_middle_95 <- function(simulated_values) {
  stats::quantile(simulated_values[is.finite(simulated_values)], c(0.025, 0.975),
                  names = FALSE)
}

# Compare each observed statistic of one composition with its simulations.
# Takes one statistics tibble: a dataset column, then one column per statistic,
# with the observed row first.
summarise_partner_statistics <- function(statistics) {
  statistics <- statistics[, -1]
  observed <- unlist(statistics[1, ], use.names = FALSE)
  limits <- unname(vapply(statistics[-1, ], simulated_middle_95, numeric(2)))
  tibble::tibble(
    statistic = names(statistics),
    observed = observed,
    lower = limits[1, ],
    upper = limits[2, ],
    outside = observed < limits[1, ] | observed > limits[2, ]
  )
}


### Printing results ----------------------------------------------------------

#' Print a summary of the partner-dependence predictive check object
#'
#' Shows each observed statistic with the middle 95% of its simulated values
#' and marks observed values outside that range. Use
#' [plot.dyadMLM_partner_check()] to view the comparisons.
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
print.dyadMLM_partner_check <- function(x, digits = 3L, ...) {
  # Read saved settings; printing does not rerun the check.
  simulation_settings <- attr(x, "dyadMLM")
  cat("<dyadMLM partner-dependence check>\n")
  cat("Response: ", x$response, "\n", sep = "")
  cat("Reference: ", x$n_simulations, " ", simulation_settings$reference, " datasets with ",
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

  for (composition_index in seq_len(nrow(x$compositions))) {
    composition <- x$compositions[composition_index, ]
    cat("\n", composition$label, ": ", composition$n_pairs, " of ", x$n_pairs,
        " usable dyads", sep = "")
    if (is.null(composition$statistics[[1]])) {
      cat("; not checked (fewer than three complete pairs)\n")
      next
    }
    cat("\n")
    rows <- x$summary[x$summary$composition == composition$label, ]
    # One column each for observed, lower, and upper values.
    values <- matrix(formatC(c(rows$observed, rows$lower, rows$upper),
                             format = "f", digits = digits, width = 9), ncol = 3L)
    # Statistic names come last so long names cannot split the table.
    cat(sprintf("%9s %9s %9s    %s\n", "Observed", "2.5%", "97.5%", "Statistic"))
    cat(sprintf("%s %s %s %s  %s\n", values[, 1], values[, 2], values[, 3],
                ifelse(rows$outside, "*", " "), rows$statistic), sep = "")
  }

  n_outside <- sum(x$summary$outside)
  cat("\nOutside the middle 95% of simulations", if (n_outside > 0L) " (*)", ": ",
      n_outside, " of ", nrow(x$summary), " observed statistics.\n",
      if (n_outside > 0L) "Some departures occur by chance; these are descriptive checks, not significance tests.\n" else
        "This does not establish good fit.\n", sep = "")

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
#'   `freq`, `xlim`, `main`, and `sub` are controlled by this
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
  # orNone = TRUE also pauses when the first plot will open an interactive device.
  ask <- ask && grDevices::dev.interactive(orNone = TRUE)

  previous_plot_pause_setting <- grDevices::devAskNewPage(ask)
  on.exit(grDevices::devAskNewPage(previous_plot_pause_setting), add = TRUE)

  n_simulations <- x$n_simulations

  for (composition_index in checked_composition_indices) {
    composition <- x$compositions[composition_index, ]
    # The first row is observed; the remaining rows are simulations.
    composition_statistics <- composition$statistics[[1]][, -1]
    composition_title <- paste0(composition$label, " - ", composition$n_pairs,
                                " of ", x$n_pairs, " usable dyads")
    draw_statistics <- function() {
      # Match observed values and simulations by position, since names may repeat.
      for (statistic_index in seq_along(composition_statistics)) {
        statistic_name <- names(composition_statistics)[[statistic_index]]
        values <- composition_statistics[[statistic_index]]
        simulations_used <- sum(is.finite(values[-1]))
        statistic_type <- sub(" \\(.*", "", statistic_name)
        labels <- switch(statistic_type,
          "SD" = c(paste0(statistic_name, "\n(variability within this role)"),
            "Beyond right: more variability in this role; left: less."),
          "Common member SD" = c("Common member SD\n(pooled variability)",
            "Beyond right: more pooled variability; left: less."),
          "Partner correlation" = c("Partner correlation\n(how partners vary together)",
            "Beyond right: more positive than predicted;\nbeyond left: more negative."),
          "Dyad-average SD" = c("Dyad-average SD\n(variation between dyad averages)",
            "Beyond right: dyad averages vary more; left: less."),
          "Half-difference SD" = c("Half-difference SD\n(variation in partner differences)",
            "Beyond right: partner differences vary more; left: less."),
          "Half-difference RMS" = c("Half-difference RMS\n(size of partner differences)",
            "Beyond right: larger partner differences; left: smaller."),
          "Dyad-average/role-difference correlation" = c(
            "Mean-difference correlation\n(which role varies more)",
            paste0("Positive: ", sub("^SD \\((.*)\\)$", "\\1", names(composition_statistics)[1]),
              " varies more;\nnegative: ",
              sub("^SD \\((.*)\\)$", "\\1", names(composition_statistics)[2]), " varies more.")))
        plot_title <- labels[1]
        if (!panels) plot_title <- paste(composition_title, plot_title, sep = "\n")
        plot_subtitle <- paste0(simulations_used, "/", n_simulations,
                                " simulations used")
        if (!panels) plot_subtitle <- paste(x$response, plot_subtitle, sep = "; ")
        else {
          guide <- paste("Red should usually lie between dashed limits.", labels[2], sep = "\n")
          plot_subtitle <- if (simulations_used == n_simulations) guide else
            paste(guide, plot_subtitle, sep = "\n")
        }
        plot_check_statistic(values, plot_title, sub = plot_subtitle, caption = panels, ...)
      }
    }
    if (panels) {
      plot_check_page(composition$label,
        paste("Partner dependence", paste0(composition$n_pairs, " of ", x$n_pairs,
              " usable dyads"), x$response, sep = " - "),
        c(2, ncol(composition_statistics) / 2), draw_statistics(),
        footer = paste0(n_simulations, " simulations. Red: observed. Blue: simulations. ",
                         "Dashed lines: middle 95%. No significance tests."),
        mar = c(7.8, 4.5, 4, .8))
    } else draw_statistics()
  }
  return(invisible(x))
}
