#' Check whether a fitted model reproduces partner interdependence
#'
#' Compares same-occasion partner interdependence in the observed fitted responses
#' with the same statistic calculated from complete simulated response datasets.
#'
#' This function supports cross-sectional Gaussian `glmmTMB`
#' simulations created by [simulate_dyad_responses()].
#'
#' @param simulations A `dyadMLM_response_simulations` object returned by
#'   [simulate_dyad_responses()].
#' @param dyad One character string naming the dyad identifier in the fitted
#'   model frame, or a vector aligned with the fitted rows.
#' @param role An optional character string naming the role variable
#'   in the fitted model frame, or a vector aligned with the fitted rows. Defaults
#'   to `NULL`.
#'
#' @return A `dyadMLM_partner_check` object containing the observed and
#'   replicated partner-dependence statistics.
#'
#' @export
check_partner_dependence <- function(simulations, dyad, role = NULL) {
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
    length(simulations$fitted_response) == n_fitted_rows &&
    is.matrix(simulations$simulated_responses) &&
    ncol(simulations$simulated_responses) == n_fitted_rows &&
    nrow(simulations$simulated_responses) == simulations$nsim
  if (!responses_are_aligned) {
    stop(
      "The observed, fitted, and simulated responses are not aligned with the fitted rows.",
      call. = FALSE
    )
  }

  dyad_values <- resolve_fitted_row_values(
    dyad,
    argument = "dyad",
    model_frame = simulations$model_frame
  )
  role_supplied <- !is.null(role)
  if (role_supplied) {
    role_values <- resolve_fitted_row_values(
      role,
      argument = "role",
      model_frame = simulations$model_frame
    )
  }

  # Omit missing identifiers before building one pair map that is reused for
  # the observed response and every complete simulated dataset.
  missing_dyad_rows <- is.na(dyad_values)
  n_missing_id_rows <- sum(missing_dyad_rows)

  missing_role_rows <- rep(FALSE, n_fitted_rows)
  if (role_supplied) {
    # Rows already missing a dyad ID are counted only in n_missing_id_rows.
    missing_role_rows <- !missing_dyad_rows & is.na(role_values)
  }
  n_missing_role_rows <- sum(missing_role_rows)

  # First check the fitted cross-sectional structure. Missing roles must not
  # hide a dyad that actually has more than one pair of fitted responses.
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
  complete_pairs <- usable_rows_by_dyad[usable_rows_per_dyad == 2L]
  n_incomplete_dyads <- sum(
    fitted_rows_per_dyad == 1L |
      (fitted_rows_per_dyad == 2L & usable_rows_per_dyad == 1L)
  )
  if (length(complete_pairs) < 3L) {
    stop(
      "At least three complete dyads are required to check partner dependence.",
      call. = FALSE
    )
  }

  pair_rows <- complete_pairs |>
    unlist(use.names = FALSE) |>
    matrix(ncol = 2L, byrow = TRUE)

  if (role_supplied) {
    retained_roles <- unique(role_values[pair_rows])
    if (length(retained_roles) != 2L) {
      stop(
        "Exactly two role values are required among the complete dyads.",
        call. = FALSE
      )
    }

    # Orient every pair by role rather than by its order in the fitted data.
    for (pair_index in seq_len(nrow(pair_rows))) {
      pair_roles <- role_values[pair_rows[pair_index, ]]
      role_positions <- match(retained_roles, pair_roles)
      if (anyNA(role_positions) || length(unique(pair_roles)) != 2L) {
        stop(
          "Each complete dyad must contain exactly one row for each role value.",
          call. = FALSE
        )
      }
      pair_rows[pair_index, ] <- pair_rows[pair_index, role_positions]
    }
  }

  observed_centered_response <-
    simulations$observed_response - simulations$fitted_response
  observed_statistic <- calculate_partner_dependence(
    observed_centered_response,
    pair_rows,
    role_oriented = role_supplied
  )

  replicated_statistics <- numeric(simulations$nsim)
  for (simulation_index in seq_len(simulations$nsim)) {
    simulated_centered_response <-
      simulations$simulated_responses[simulation_index, ] -
      simulations$fitted_response

    replicated_statistics[[simulation_index]] <- calculate_partner_dependence(
      simulated_centered_response,
      pair_rows,
      role_oriented = role_supplied
    )
  }

  if (any(!is.finite(c(observed_statistic, replicated_statistics)))) {
    stop(
      paste0(
        "Partner dependence is undefined because the observed response or at ",
        "least one simulated response has insufficient variation."
      ),
      call. = FALSE
    )
  }

  replicated_interval <- stats::quantile(
    replicated_statistics,
    probs = c(0.025, 0.975),
    names = FALSE
  )
  names(replicated_interval) <- c("2.5%", "97.5%")

  check_results <- list(
    statistic = if (role_supplied) {
      "Pearson correlation between roles"
    } else {
      "symmetric partner-dependence coefficient"
    },
    observed_statistic = observed_statistic,
    replicated_statistics = replicated_statistics,
    replicated_median = stats::median(replicated_statistics),
    replicated_interval = replicated_interval,
    observed_percentile =
      (1 + sum(replicated_statistics <= observed_statistic)) /
      (simulations$nsim + 1),
    n_pairs = nrow(pair_rows),
    n_incomplete_dyads = n_incomplete_dyads,
    n_missing_id_rows = n_missing_id_rows,
    n_missing_role_rows = n_missing_role_rows,
    reference = simulations$reference,
    random_effects = simulations$random_effects,
    nsim = simulations$nsim,
    seed = simulations$seed,
    call = check_call
  )
  class(check_results) <- c("dyadMLM_partner_check", "list")

  return(check_results)
}


# Resolve either a fitted-model-frame column name or an aligned explicit vector.
resolve_fitted_row_values <- function(value, argument, model_frame) {
  if (is.character(value) && length(value) == 1L) {
    if (!value %in% names(model_frame)) {
      stop(
        sprintf("`%s` does not name a column in the fitted model frame.", value),
        call. = FALSE
      )
    }
    return(model_frame[[value]])
  }

  if (!is.atomic(value) || !is.null(dim(value)) ||
      length(value) != nrow(model_frame)) {
    stop(
      sprintf(
        "`%s` must be one fitted-model-frame column name or a vector of length %d.",
        argument,
        nrow(model_frame)
      ),
      call. = FALSE
    )
  }

  return(value)
}


# Calculate the same statistic for the observed and each simulated response.
calculate_partner_dependence <- function(response, pair_rows, role_oriented) {
  member_1 <- response[pair_rows[, 1L]]
  member_2 <- response[pair_rows[, 2L]]

  if (role_oriented) {
    member_1_sd <- stats::sd(member_1)
    member_2_sd <- stats::sd(member_2)
    if (!is.finite(member_1_sd) || !is.finite(member_2_sd) ||
        member_1_sd == 0 || member_2_sd == 0) {
      return(NA_real_)
    }
    return(stats::cor(member_1, member_2))
  }

  denominator <- sum(member_1^2 + member_2^2)
  if (!is.finite(denominator) || denominator <= 0) {
    return(NA_real_)
  }

  return(2 * sum(member_1 * member_2) / denominator)
}


#' @export
print.dyadMLM_partner_check <- function(x, ...) {
  cat("Partner-dependence predictive check\n")
  cat("Statistic:", x$statistic, "\n")
  cat(sprintf("Observed: %.3f\n", x$observed_statistic))
  cat(sprintf(
    "Replicated median: %.3f (95%% interval: %.3f to %.3f)\n",
    x$replicated_median,
    x$replicated_interval[[1L]],
    x$replicated_interval[[2L]]
  ))
  cat(sprintf("Observed percentile: %.3f\n", x$observed_percentile))
  cat("Complete pairs:", x$n_pairs, "\n")

  omitted_counts <- c(
    "incomplete dyads" = x$n_incomplete_dyads,
    "rows with missing dyad IDs" = x$n_missing_id_rows,
    "rows with missing roles" = x$n_missing_role_rows
  )
  omitted_counts <- omitted_counts[omitted_counts > 0]
  if (length(omitted_counts) > 0L) {
    omitted_text <- paste(
      paste(names(omitted_counts), omitted_counts, sep = ": "),
      collapse = "; "
    )
    cat("Omitted:", omitted_text, "\n")
  }

  cat("Reference:", x$reference, "\n")
  invisible(x)
}


#' @export
plot.dyadMLM_partner_check <- function(x, ...) {
  plot_range <- range(
    c(x$observed_statistic, x$replicated_statistics),
    finite = TRUE
  )

  graphics::hist(
    x$replicated_statistics,
    xlim = plot_range,
    main = "Partner-dependence predictive check",
    sub = paste(x$n_pairs, "complete pairs;", x$reference),
    xlab = x$statistic,
    ...
  )
  graphics::abline(
    v = x$replicated_interval,
    lty = 2,
    col = "grey40"
  )
  graphics::abline(v = x$observed_statistic, lwd = 2)
  graphics::legend(
    "topright",
    legend = c("Observed", "Replicated 95% interval"),
    lty = c(1, 2),
    lwd = c(2, 1),
    col = c("black", "grey40"),
    bty = "n"
  )

  invisible(x)
}
