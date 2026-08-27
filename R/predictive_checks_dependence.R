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
#' Supplying both `member` and factor-valued `time` activates the
#' intensive-longitudinal prototype. It separates stable member means,
#' same-occasion within-member partner dependence, own-member lag profiles,
#' and cross-member lag profiles. Cross-member profiles are role-directed when
#' `role` is supplied and pool both directions otherwise. Lag edges use
#' differences in the complete factor-level sequence, never adjacency between
#' observed rows.
#'
#' Currently, the function supports Gaussian identity-link `glmmTMB`
#' simulations created by [simulate_dyad_responses()]. Cross-sectional dyads
#' may have at most two fitted responses. The ILD prototype requires exactly
#' two stable members per dyad, at least three dyads, unique dyad-member-time
#' keys, a regular scheduled occasion scale stored as a factor, and one
#' substantively coherent dyad composition per call. Composition is not
#' inferred when `role = NULL`, so mixed data must be subset by the caller.
#' With `role`, every dyad must contain one stable member in each of
#' exactly two roles. The interface is experimental.
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
#' The ILD decomposition and every lag statistic are recalculated separately
#' for the observed response and every simulated dataset. An ILD reference
#' interval is shown only when at least 20 and at least 95 percent of the
#' requested simulated statistics are defined. Unsupported lags and undefined
#' correlations remain in the returned statistics table with their support and
#' reason for being undefined.
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
#' @param member For an ILD check, an unquoted or quoted member-identifier
#'   column in the fitted model frame, or a vector aligned with fitted rows.
#'   It is required when `time` is supplied. Cross-sectionally it may be
#'   supplied to verify that each pair contains two distinct members.
#' @param time `NULL` for the established cross-sectional check, or a factor
#'   aligned with fitted rows for the ILD prototype. Its complete level
#'   sequence defines equally spaced scheduled occasions. An aligned external
#'   factor may retain a globally unobserved level for the diagnostic map, but
#'   cannot restore a time state already dropped while fitting an AR(1) model.
#'   For AR(1) references, every scheduled level must therefore be represented
#'   in the fitted structure; use a genuinely gap-aware structure such as
#'   `ou()` with `numFactor()` when appropriate.
#' @param lags `NULL` or distinct positive whole-number lags. On the ILD path,
#'   `NULL` uses lags 1 through 5. Lags are differences in factor-level
#'   position.
#' @param weighting How repeated same-occasion pairs and lag edges contribute:
#'   `"dyad"` gives every eligible dyad total weight one within each reported
#'   statistic; pooled exchangeable directions share that total weight.
#'   `"edge"` gives every eligible pair or lag edge equal weight. Stable
#'   member-mean summaries always contain one pair per dyad.
#'
#' @return Invisibly, a `dyadMLM_partner_check` object containing the summary
#'   table, all replicated statistics, and the selected `response`. ILD calls
#'   add the subclass `dyadMLM_ild_partner_check`, support and reasons directly
#'   to the statistics table, and auditable row and edge maps in `maps`. In the
#'   table, `observed_quantile` stores the observed position: the proportion of
#'   simulated values at or below the observed value, with a finite-simulation
#'   correction.
#'
#' @examples
#' if (requireNamespace("glmmTMB", quietly = TRUE)) {
#'   example_data <- dyads_cross[dyads_cross$coupleID <= 20, ]
#'   model <- glmmTMB::glmmTMB(
#'     closeness ~ gender + (1 | coupleID),
#'     data = example_data
#'   )
#'
#'   simulations <- simulate_dyad_responses(model, nsim = 20, seed = 123)
#'   check <- check_partner_dependence(
#'     simulations,
#'     dyad = coupleID,
#'     role = gender,
#'     plot = FALSE
#'   )
#'   check
#'   plot(check, parameterization = "member", ask = FALSE)
#'
#'   # Intensive-longitudinal prototype for one dyad composition.
#'   ild_data <- dyads_ild[dyads_ild$coupleID <= 6, ]
#'   ild_data$time_f <- factor(ild_data$diaryday, levels = 0:13)
#'   ild_data$series <- interaction(
#'     ild_data$coupleID,
#'     ild_data$personID,
#'     drop = TRUE
#'   )
#'   ild_model <- glmmTMB::glmmTMB(
#'     closeness ~
#'       gender +
#'       (1 | coupleID) +
#'       ar1(0 + time_f | series),
#'     data = ild_data
#'   )
#'   ild_simulations <- simulate_dyad_responses(
#'     ild_model,
#'     nsim = 20,
#'     seed = 124
#'   )
#'   ild_check <- check_partner_dependence(
#'     ild_simulations,
#'     dyad = ild_data$coupleID,
#'     role = ild_data$gender,
#'     member = ild_data$personID,
#'     time = ild_data$time_f,
#'     lags = 1,
#'     plot = FALSE
#'   )
#'   ild_check
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
  response = c("model-centred", "raw"),
  member = NULL,
  time = NULL,
  lags = NULL,
  weighting = c("dyad", "edge")
) {
  check_call <- match.call()
  response <- match.arg(response)
  weighting <- match.arg(weighting)

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
        "Partner-dependence checks currently require Gaussian identity-link ",
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
  member_values <- resolve_fitted_row_argument(
    argument_quo = rlang::enquo(member),
    argument_name = "member",
    model_frame = simulations$model_frame,
    allow_null = TRUE
  )
  time_values <- resolve_fitted_row_argument(
    argument_quo = rlang::enquo(time),
    argument_name = "time",
    model_frame = simulations$model_frame,
    allow_null = TRUE
  )
  role_was_supplied <- !is.null(role_values)

  if (!is.null(time_values)) {
    if (is.null(member_values)) {
      stop(
        "Supplying time for an ILD check also requires member.",
        call. = FALSE
      )
    }
    return(check_ild_partner_dependence(
      simulations = simulations,
      dyad_values = dyad_values,
      member_values = member_values,
      role_values = role_values,
      time_values = time_values,
      lags = lags,
      weighting = weighting,
      response = response,
      check_call = check_call,
      plot = plot
    ))
  }
  if (!is.null(lags)) {
    stop("lags can be supplied only together with time.", call. = FALSE)
  }

  # Build one pair map, oriented by role when supplied, and reuse it unchanged
  # for the observed response and every simulation.
  pair_info <- prepare_partner_pairs(dyad_values, role_values)
  paired_row_indices <- pair_info$paired_row_indices
  role_order <- pair_info$role_order
  if (!is.null(member_values)) {
    paired_member_vector <-
      member_values[as.vector(t(paired_row_indices))]
    if (has_missing_identifier_values(paired_member_vector)) {
      stop(
        "Member identifiers cannot be missing in complete cross-sectional dyads.",
        call. = FALSE
      )
    }
    paired_member_values <- matrix(
      as.character(paired_member_vector),
      ncol = 2L,
      byrow = TRUE
    )
    if (any(paired_member_values[, 1L] == paired_member_values[, 2L])) {
      stop(
        "Each complete cross-sectional dyad must contain two distinct members.",
        call. = FALSE
      )
    }
  }

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
        "Repeated fitted responses were detected within a dyad. For ILD ",
        "data, supply both member and factor-valued time; otherwise each ",
        "dyad must have at most two fitted responses after rows with missing ",
        "dyad IDs are omitted."
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
  calculate_partner_pair_statistics(
    first = selected_response_values[paired_row_indices[, 1L]],
    second = selected_response_values[paired_row_indices[, 2L]],
    cluster = seq_len(nrow(paired_row_indices)),
    weighting = "dyad",
    role_specific = use_role_specific_statistics
  )
}


# Calculate the same pair summaries for cross-sectional or repeated pairs.
calculate_partner_pair_statistics <- function(
  first,
  second,
  cluster,
  weighting,
  role_specific
) {
  dyad_mean <- (first + second) / 2
  half_difference <- (first - second) / 2
  transformed_moments <- calculate_pair_moments(
    dyad_mean, half_difference, cluster, weighting
  )

  if (role_specific) {
    member_moments <- calculate_pair_moments(
      first, second, cluster, weighting
    )
    return(c(
      role_1_sd = safe_pair_sqrt(member_moments[["variance_x"]]),
      role_2_sd = safe_pair_sqrt(member_moments[["variance_y"]]),
      partner_correlation = member_moments[["correlation"]],
      dyad_mean_sd = safe_pair_sqrt(
        transformed_moments[["variance_x"]]
      ),
      half_difference_sd = safe_pair_sqrt(
        transformed_moments[["variance_y"]]
      ),
      dyad_mean_half_difference_correlation =
        transformed_moments[["correlation"]]
    ))
  }

  weights <- make_pair_weights(cluster, weighting)
  half_difference_mean_square <- if (is.null(weights)) {
    NA_real_
  } else {
    sum(weights$values * half_difference^2)
  }
  member_variance <-
    transformed_moments[["variance_x"]] + half_difference_mean_square
  partner_covariance <-
    transformed_moments[["variance_x"]] - half_difference_mean_square
  partner_correlation <- if (
    is.finite(member_variance) && member_variance > 0
  ) {
    partner_covariance / member_variance
  } else {
    NA_real_
  }

  c(
    exchangeable_member_sd = safe_pair_sqrt(member_variance),
    exchangeable_partner_correlation = partner_correlation,
    dyad_mean_sd = safe_pair_sqrt(
      transformed_moments[["variance_x"]]
    ),
    half_difference_rms = safe_pair_sqrt(half_difference_mean_square)
  )
}


# Weighted sample moments. Clusters, rather than edges, set the correction.
calculate_pair_moments <- function(x, y, cluster, weighting) {
  undefined <- c(
    variance_x = NA_real_,
    variance_y = NA_real_,
    covariance = NA_real_,
    correlation = NA_real_
  )
  if (
    length(x) != length(y) ||
      length(x) != length(cluster) ||
      any(!is.finite(x)) ||
      any(!is.finite(y))
  ) {
    return(undefined)
  }

  weights <- make_pair_weights(cluster, weighting)
  if (is.null(weights)) {
    return(undefined)
  }

  covariance <- stats::cov.wt(
    cbind(x, y),
    wt = weights$values,
    method = "ML"
  )$cov * weights$n_clusters / (weights$n_clusters - 1)
  correlation <- if (
    all(is.finite(diag(covariance))) && all(diag(covariance) > 0)
  ) {
    covariance[1L, 2L] / sqrt(prod(diag(covariance)))
  } else {
    NA_real_
  }

  c(
    variance_x = covariance[1L, 1L],
    variance_y = covariance[2L, 2L],
    covariance = covariance[1L, 2L],
    correlation = correlation
  )
}


make_pair_weights <- function(cluster, weighting) {
  weighting <- match.arg(weighting, c("dyad", "edge"))
  if (length(cluster) < 3L || anyNA(cluster)) {
    return(NULL)
  }

  cluster <- match(cluster, unique(cluster))
  n_clusters <- max(cluster)
  if (n_clusters < 3L) {
    return(NULL)
  }

  values <- if (weighting == "dyad") {
    counts <- tabulate(cluster, nbins = n_clusters)
    1 / (n_clusters * counts[cluster])
  } else {
    rep(1 / length(cluster), length(cluster))
  }
  list(values = values, n_clusters = n_clusters)
}


safe_pair_sqrt <- function(value) {
  if (length(value) != 1L || !is.finite(value) || value < 0) {
    return(NA_real_)
  }
  sqrt(value)
}


# Labels shared by cross-sectional and ILD partner summaries.
partner_statistic_schema <- function(role_order = NULL) {
  if (is.null(role_order)) {
    return(data.frame(
      statistic = c(
        "exchangeable_member_sd",
        "exchangeable_partner_correlation",
        "dyad_mean_sd",
        "half_difference_rms"
      ),
      parameterization = c(
        "member", "member", "mean_difference", "mean_difference"
      ),
      label = c(
        "Common member SD (exchangeable)",
        "Partner correlation (exchangeable)",
        "Dyad-average SD",
        "Half-difference RMS (about zero)"
      )
    ))
  }

  difference <- paste(role_order[[1L]], "minus", role_order[[2L]])
  data.frame(
    statistic = c(
      "role_1_sd",
      "role_2_sd",
      "partner_correlation",
      "dyad_mean_sd",
      "half_difference_sd",
      "dyad_mean_half_difference_correlation"
    ),
    parameterization = c(
      "member", "member", "member",
      "mean_difference", "mean_difference", "mean_difference"
    ),
    label = c(
      paste0("SD (", role_order[[1L]], ")"),
      paste0("SD (", role_order[[2L]], ")"),
      paste0(
        "Partner correlation (",
        role_order[[1L]], " and ", role_order[[2L]], ")"
      ),
      "Dyad-average SD",
      paste0("Half-difference SD (", difference, ")"),
      paste0(
        "Dyad-average/role-difference correlation (", difference, ")"
      )
    )
  )
}


# Summarize each simulated reference column, retaining undefined values.
summarize_simulation_reference <- function(
  observed_statistics,
  replicated_statistics,
  minimum_defined = nrow(replicated_statistics)
) {
  result <- matrix(
    NA_real_,
    nrow = length(observed_statistics),
    ncol = 9L,
    dimnames = list(NULL, c(
      "observed_value",
      "replicated_median",
      "replicated_lower_50",
      "replicated_upper_50",
      "replicated_lower",
      "replicated_upper",
      "observed_quantile",
      "n_defined_simulations",
      "minimum_defined_simulations"
    ))
  )

  for (statistic in seq_along(observed_statistics)) {
    observed <- observed_statistics[[statistic]]
    simulated <- replicated_statistics[, statistic]
    simulated <- simulated[is.finite(simulated)]
    n_defined <- length(simulated)

    result[statistic, "observed_value"] <- observed
    result[statistic, "n_defined_simulations"] <- n_defined
    result[statistic, "minimum_defined_simulations"] <- minimum_defined
    if (n_defined < minimum_defined) {
      next
    }

    intervals <- stats::quantile(
      simulated,
      c(0.025, 0.25, 0.5, 0.75, 0.975),
      names = FALSE
    )
    result[statistic, c(
      "replicated_lower",
      "replicated_lower_50",
      "replicated_median",
      "replicated_upper_50",
      "replicated_upper"
    )] <- intervals
    if (is.finite(observed)) {
      result[statistic, "observed_quantile"] <-
        (1 + sum(simulated <= observed)) / (n_defined + 1)
    }
  }

  result <- as.data.frame(result)
  result$n_defined_simulations <- as.integer(
    result$n_defined_simulations
  )
  result$minimum_defined_simulations <- as.integer(
    result$minimum_defined_simulations
  )
  result
}


# Combine cross-sectional summaries with their simulated reference.
summarize_partner_statistics <- function(
  observed_statistics,
  replicated_statistics,
  role_order = NULL
) {
  schema <- partner_statistic_schema(role_order)
  schema <- schema[match(names(observed_statistics), schema$statistic), ]
  reference <- summarize_simulation_reference(
    observed_statistics,
    replicated_statistics
  )

  data.frame(
    statistic_name = schema$statistic,
    parameterization = schema$parameterization,
    label = schema$label,
    observed_value = reference$observed_value,
    replicated_median = reference$replicated_median,
    replicated_lower = reference$replicated_lower,
    replicated_upper = reference$replicated_upper,
    observed_quantile = reference$observed_quantile
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


plot_reference_histogram <- function(
  replicated,
  statistic,
  subtitle,
  show_legend = FALSE,
  ...
) {
  replicated <- replicated[is.finite(replicated)]
  if (length(replicated) == 0L) {
    graphics::plot.new()
    graphics::title(
      main = statistic$label,
      sub = "No defined simulated reference values"
    )
    return(invisible())
  }

  histogram <- graphics::hist(
    replicated,
    breaks = min(100L, max(20L, round(length(replicated) / 5))),
    plot = FALSE
  )
  height <- max(histogram$counts)
  graphics::plot(
    histogram,
    freq = TRUE,
    xlim = range(c(replicated, statistic$observed_value), finite = TRUE),
    ylim = c(0, height * if (show_legend) 1.25 else 1.2),
    main = statistic$label,
    sub = subtitle,
    xlab = "Summary value",
    ...
  )
  graphics::segments(
    x0 = c(statistic$replicated_lower, statistic$replicated_upper),
    y0 = 0,
    x1 = c(statistic$replicated_lower, statistic$replicated_upper),
    y1 = height,
    lty = 2,
    col = "grey40"
  )
  if (is.finite(statistic$observed_value)) {
    graphics::segments(
      x0 = statistic$observed_value,
      y0 = 0,
      x1 = statistic$observed_value,
      y1 = height,
      lwd = 2.5,
      col = "red"
    )
  }
  if (show_legend) {
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
  invisible()
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
    plot_reference_histogram(
      replicated = x$replicated_statistics[
        , statistic_row$statistic_name, drop = TRUE
      ],
      statistic = statistic_row,
      subtitle = paste0(
        response_subtitle,
        "; ",
        parameterization_labels[[statistic_row$parameterization]],
        "; ",
        x$n_pairs,
        " complete pairs; ",
        x$reference,
        " reference (", x$nsim, " datasets)"
      ),
      show_legend = TRUE,
      ...
    )
  }

  invisible(x)
}
