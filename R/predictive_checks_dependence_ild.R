# Internal Gaussian ILD partner-dependence prototype.
#
# ILD adds only two steps to the cross-sectional check: average each member's
# series, then build exact same-occasion and lagged pairs. Every pair is passed
# to the shared cross-sectional statistics kernel.


check_ild_partner_dependence <- function(
  simulations,
  dyad_values,
  member_values,
  role_values,
  time_values,
  lags,
  weighting,
  response,
  check_call,
  plot
) {
  lags <- normalize_ild_lags(lags)
  design <- prepare_ild_design(
    dyad_values,
    member_values,
    role_values,
    time_values,
    lags
  )
  response_shift <- if (response == "model-centred") {
    simulations$response_center
  } else {
    rep(0, nrow(simulations$model_frame))
  }

  observed_statistics <- calculate_ild_statistics(
    simulations$observed_response - response_shift,
    design,
    weighting
  )
  replicated_statistics <- matrix(
    NA_real_,
    nrow = simulations$nsim,
    ncol = length(observed_statistics),
    dimnames = list(NULL, names(observed_statistics))
  )
  for (simulation in seq_len(simulations$nsim)) {
    replicated_statistics[simulation, ] <- calculate_ild_statistics(
      simulations$simulated_responses[simulation, ] - response_shift,
      design,
      weighting
    )
  }

  definitions <- build_ild_statistic_definitions(design, weighting)
  statistics_table <- summarize_ild_statistics(
    observed_statistics,
    replicated_statistics,
    definitions
  )
  profile_maps <- lapply(
    design$profiles,
    function(profile) profile$edges
  )

  result <- list(
    statistics_table = statistics_table,
    replicated_statistics = replicated_statistics,
    maps = list(
      rows = design$rows,
      concurrent = design$concurrent,
      profiles = profile_maps
    ),
    role_order = as.character(design$role_order),
    time_levels = design$time_levels,
    lags = design$lags,
    weighting = weighting,
    n_dyads = design$n_dyads,
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
  class(result) <- c(
    "dyadMLM_ild_partner_check",
    "dyadMLM_partner_check",
    "list"
  )

  if (plot) {
    graphics::plot(result)
  }
  invisible(result)
}


normalize_ild_lags <- function(lags) {
  if (is.null(lags)) {
    return(1:5)
  }
  valid <- is.numeric(lags) &&
    length(lags) > 0L &&
    !anyNA(lags) &&
    all(is.finite(lags)) &&
    all(lags > 0) &&
    all(lags %% 1 == 0) &&
    all(lags <= .Machine$integer.max) &&
    !anyDuplicated(lags)
  if (!valid) {
    stop(
      "On the ILD path, lags must contain distinct positive whole numbers.",
      call. = FALSE
    )
  }
  sort(as.integer(lags))
}


# Validate identifiers and give the two members of every dyad stable slots.
prepare_ild_design <- function(
  dyad_values,
  member_values,
  role_values,
  time_values,
  lags
) {
  n_rows <- length(dyad_values)
  lengths <- c(
    length(member_values),
    length(time_values),
    if (is.null(role_values)) n_rows else length(role_values)
  )
  if (any(lengths != n_rows)) {
    stop(
      "ILD identifiers must remain aligned with the fitted response rows.",
      call. = FALSE
    )
  }
  if (!is.factor(time_values)) {
    stop(
      paste0(
        "On the ILD path, time must be a factor whose complete level ",
        "sequence represents equally spaced scheduled occasions."
      ),
      call. = FALSE
    )
  }
  if (nlevels(time_values) < 2L) {
    stop("At least two scheduled time levels are required.", call. = FALSE)
  }
  missing_identifiers <-
    has_missing_identifier_values(dyad_values) ||
    has_missing_identifier_values(member_values) ||
    has_missing_identifier_values(
      time_values,
      include_unused_factor_levels = TRUE
    ) ||
    (
      !is.null(role_values) &&
        has_missing_identifier_values(role_values)
    )
  if (missing_identifiers) {
    stop(
      paste0(
        "ILD fitted rows cannot have missing dyad, member, role, or time ",
        "identifiers."
      ),
      call. = FALSE
    )
  }

  dyad_levels <- unique(dyad_values)
  dyad_index <- match(dyad_values, dyad_levels)
  n_dyads <- length(dyad_levels)
  if (n_dyads < 3L) {
    stop(
      "At least three dyads are required for an ILD partner-dependence check.",
      call. = FALSE
    )
  }

  role_order <- NULL
  if (!is.null(role_values)) {
    role_order <- if (is.factor(role_values)) {
      levels(droplevels(role_values))
    } else {
      sort(unique(role_values), na.last = NA)
    }
    if (length(role_order) != 2L) {
      stop(
        "Exactly two role values are required on the distinguishable ILD path.",
        call. = FALSE
      )
    }
  }

  member_text <- as.character(member_values)
  role_text <- as.character(role_values)
  member_slot <- integer(n_rows)
  for (dyad in seq_len(n_dyads)) {
    rows <- which(dyad_index == dyad)
    members <- unique(member_text[rows])
    if (length(members) != 2L) {
      stop(
        "Every included dyad must contain exactly two stable member identities.",
        call. = FALSE
      )
    }

    if (!is.null(role_values)) {
      member_roles <- character(2L)
      for (member in 1:2) {
        roles <- unique(role_text[rows][member_text[rows] == members[member]])
        if (length(roles) != 1L) {
          stop(
            "Each member must keep one stable role over the full fitted series.",
            call. = FALSE
          )
        }
        member_roles[member] <- roles
      }
      order_by_role <- match(as.character(role_order), member_roles)
      if (anyNA(order_by_role) || anyDuplicated(member_roles)) {
        stop(
          "Every dyad must contain exactly one member in each role.",
          call. = FALSE
        )
      }
      members <- members[order_by_role]
    } else if (is.factor(member_values)) {
      members <- members[order(match(members, levels(member_values)))]
    } else {
      members <- sort(members)
    }
    member_slot[rows] <- match(member_text[rows], members)
  }

  time_index <- as.integer(time_values)
  if (anyDuplicated(data.frame(dyad_index, member_slot, time_index))) {
    stop(
      "Each dyad-member-time key must identify at most one fitted response row.",
      call. = FALSE
    )
  }

  rows <- data.frame(
    fitted_row = seq_len(n_rows),
    dyad_index = dyad_index,
    dyad = as.character(dyad_values),
    member_slot = member_slot,
    member = member_text,
    member_id = (dyad_index - 1L) * 2L + member_slot,
    role = if (is.null(role_values)) NA_character_ else role_text,
    time_index = time_index,
    time = as.character(time_values),
    stringsAsFactors = FALSE
  )
  concurrent <- make_ild_edges(rows, lag = 0L, from = 1L, to = 2L)

  list(
    rows = rows,
    stable_pairs = matrix(
      seq_len(2L * n_dyads),
      ncol = 2L,
      byrow = TRUE
    ),
    concurrent = concurrent,
    profiles = make_ild_profiles(rows, lags, role_order),
    role_order = role_order,
    time_levels = levels(time_values),
    lags = lags,
    n_dyads = n_dyads
  )
}


# Match only rows whose factor-level positions differ by exactly lag.
make_ild_edges <- function(rows, lag, from, to) {
  keys <- c("dyad_index", "time_index")
  start <- rows[
    rows$member_slot == from,
    c(keys, "fitted_row"),
    drop = FALSE
  ]
  end <- rows[
    rows$member_slot == to,
    c(keys, "fitted_row"),
    drop = FALSE
  ]
  names(start)[3L] <- "start_row"
  names(end)[3L] <- "end_row"
  start$time_index <- as.double(start$time_index) + lag

  edges <- merge(start, end, by = keys, sort = FALSE)
  edges[c("dyad_index", "start_row", "end_row")]
}


ild_profile_specs <- function(role_order) {
  if (!is.null(role_order)) {
    return(list(
      list(
        component = "own_lag",
        id = "role_1",
        curve = as.character(role_order[[1L]]),
        from = 1L,
        to = 1L
      ),
      list(
        component = "own_lag",
        id = "role_2",
        curve = as.character(role_order[[2L]]),
        from = 2L,
        to = 2L
      ),
      list(
        component = "cross_lag",
        id = "role_1_to_role_2",
        curve = paste(role_order[[1L]], "->", role_order[[2L]]),
        from = 1L,
        to = 2L
      ),
      list(
        component = "cross_lag",
        id = "role_2_to_role_1",
        curve = paste(role_order[[2L]], "->", role_order[[1L]]),
        from = 2L,
        to = 1L
      )
    ))
  }

  list(
    list(
      component = "own_lag",
      id = "pooled_members",
      curve = "Pooled members",
      from = 1:2,
      to = 1:2
    ),
    list(
      component = "cross_lag",
      id = "pooled_directions",
      curve = "Pooled directions",
      from = 1:2,
      to = 2:1
    )
  )
}


make_ild_profiles <- function(rows, lags, role_order) {
  profiles <- list()
  specs <- ild_profile_specs(role_order)
  for (lag in lags) {
    for (spec in specs) {
      parts <- vector("list", length(spec$from))
      for (direction in seq_along(spec$from)) {
        parts[[direction]] <- make_ild_edges(
          rows,
          lag,
          spec$from[[direction]],
          spec$to[[direction]]
        )
      }
      id <- paste(
        spec$component,
        spec$id,
        paste0("lag", lag),
        sep = "__"
      )
      profiles[[id]] <- list(
        id = id,
        component = spec$component,
        curve = spec$curve,
        lag = lag,
        edges = do.call(rbind, parts)
      )
    }
  }
  profiles
}


# Separate stable member means from within-member occasion deviations.
decompose_ild_response <- function(values, design) {
  if (
    !is.numeric(values) ||
      length(values) != nrow(design$rows) ||
      any(!is.finite(values))
  ) {
    stop(
      paste0(
        "Every ILD observed or simulated response must be finite and ",
        "fitted-row aligned."
      ),
      call. = FALSE
    )
  }

  member_id <- design$rows$member_id
  n_members <- 2L * design$n_dyads
  member_means <-
    drop(rowsum(values, member_id, reorder = TRUE)) /
    tabulate(member_id, nbins = n_members)

  list(
    member_means = member_means,
    within = values - member_means[member_id]
  )
}


calculate_ild_statistics <- function(values, design, weighting) {
  decomposition <- decompose_ild_response(values, design)
  role_specific <- !is.null(design$role_order)

  stable <- suppressWarnings(calculate_partner_response_statistics(
    decomposition$member_means,
    design$stable_pairs,
    role_specific
  ))
  names(stable) <- paste("stable", names(stable), sep = "__")

  edges <- design$concurrent
  concurrent <- calculate_partner_pair_statistics(
    decomposition$within[edges$start_row],
    decomposition$within[edges$end_row],
    edges$dyad_index,
    weighting,
    role_specific
  )
  names(concurrent) <- paste("concurrent", names(concurrent), sep = "__")

  profiles <- numeric(length(design$profiles))
  for (profile in seq_along(design$profiles)) {
    edges <- design$profiles[[profile]]$edges
    profiles[[profile]] <- calculate_pair_moments(
      decomposition$within[edges$start_row],
      decomposition$within[edges$end_row],
      edges$dyad_index,
      weighting
    )[[ "correlation" ]]
  }
  names(profiles) <- paste(names(design$profiles), "correlation", sep = "__")

  c(stable, concurrent, profiles)
}


ild_edge_support <- function(edges) {
  n_dyads <- length(unique(edges$dyad_index))
  list(
    n_dyads = n_dyads,
    n_edges = nrow(edges),
    structural_reason = if (n_dyads < 3L) {
      "fewer than three contributing dyads"
    } else {
      NA_character_
    }
  )
}


build_ild_statistic_definitions <- function(design, weighting) {
  schema <- partner_statistic_schema(design$role_order)
  pair_definitions <- function(component, title, support, pair_weighting) {
    data.frame(
      statistic_id = paste(component, schema$statistic, sep = "__"),
      component = component,
      curve = "partner",
      lag = NA_integer_,
      statistic = schema$statistic,
      parameterization = schema$parameterization,
      label = paste0(title, ": ", schema$label),
      weighting = pair_weighting,
      n_dyads = support$n_dyads,
      n_edges = support$n_edges,
      structural_reason = support$structural_reason,
      stringsAsFactors = FALSE
    )
  }

  stable <- list(
    n_dyads = design$n_dyads,
    n_edges = design$n_dyads,
    structural_reason = NA_character_
  )
  definitions <- list(
    pair_definitions(
      "stable",
      "Stable",
      stable,
      "one pair per dyad"
    ),
    pair_definitions(
      "concurrent",
      "Concurrent",
      ild_edge_support(design$concurrent),
      weighting
    )
  )

  for (profile in design$profiles) {
    support <- ild_edge_support(profile$edges)
    definitions[[length(definitions) + 1L]] <- data.frame(
      statistic_id = paste(profile$id, "correlation", sep = "__"),
      component = profile$component,
      curve = profile$curve,
      lag = profile$lag,
      statistic = "correlation",
      parameterization = "profile",
      label = paste0(
        if (profile$component == "own_lag") {
          "Own-member lag "
        } else {
          "Cross-member lag "
        },
        profile$lag,
        ": ",
        profile$curve
      ),
      weighting = weighting,
      n_dyads = support$n_dyads,
      n_edges = support$n_edges,
      structural_reason = support$structural_reason,
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, definitions)
}


summarize_ild_statistics <- function(
  observed_statistics,
  replicated_statistics,
  definitions
) {
  statistic_ids <- definitions$statistic_id
  observed_statistics <- observed_statistics[statistic_ids]
  replicated_statistics <-
    replicated_statistics[, statistic_ids, drop = FALSE]
  minimum_defined <- max(
    20L,
    as.integer(ceiling(0.95 * nrow(replicated_statistics)))
  )
  reference <- summarize_simulation_reference(
    observed_statistics,
    replicated_statistics,
    minimum_defined
  )
  observed_reason <- ifelse(
    is.finite(reference$observed_value),
    NA_character_,
    ifelse(
      is.na(definitions$structural_reason),
      "zero variance or numerical degeneracy",
      definitions$structural_reason
    )
  )
  reference_reason <- ifelse(
    reference$n_defined_simulations >=
      reference$minimum_defined_simulations,
    NA_character_,
    "too few defined simulated statistics"
  )

  result <- cbind(
    definitions,
    reference,
    observed_reason,
    reference_reason
  )
  rownames(result) <- NULL
  result
}


#' Print an intensive-longitudinal partner-dependence check
#'
#' @param x An intensive-longitudinal result returned by
#'   check_partner_dependence().
#' @param digits Number of decimal places to print.
#' @param ... Not used.
#'
#' @return x, invisibly.
#'
#' @keywords internal
#' @export
print.dyadMLM_ild_partner_check <- function(x, digits = 3, ...) {
  cat("<dyadMLM ILD partner-dependence check>\n")
  cat(
    x$n_dyads,
    "dyads across",
    length(x$time_levels),
    "scheduled time levels\n"
  )
  cat(
    "Response: ", x$response,
    " | Weighting: ", x$weighting,
    " (stable: one pair per dyad)",
    " | Requested lags: ", paste(x$lags, collapse = ", "),
    "\n",
    sep = ""
  )
  cat(
    "Reference: ", x$nsim, " ", x$reference,
    " datasets requested with ", x$random_effects, " random effects",
    " (defined counts are statistic-specific)\n",
    sep = ""
  )

  rows_to_print <-
    x$statistics_table$parameterization %in% c("member", "profile")
  table_to_print <- x$statistics_table[rows_to_print, , drop = FALSE]
  number_format <- paste0("%.", digits, "f")

  for (component in unique(table_to_print$component)) {
    cat("\n", ild_component_label(component), "\n", sep = "")
    component_rows <- table_to_print$component == component
    for (row_index in which(component_rows)) {
      statistic <- table_to_print[row_index, , drop = FALSE]
      support_text <- paste0(
        statistic$n_dyads,
        " dyads, ",
        statistic$n_edges,
        if (statistic$n_edges == 1L) " pair/edge" else " pairs/edges",
        "; ",
        statistic$n_defined_simulations,
        "/",
        x$nsim,
        " defined simulations"
      )
      if (!is.finite(statistic$observed_value)) {
        cat(
          statistic$label,
          "\n  Not estimable: ",
          statistic$observed_reason,
          " (", support_text, ")\n",
          sep = ""
        )
      } else if (!is.finite(statistic$replicated_median)) {
        cat(
          statistic$label,
          "\n  Observed ",
          sprintf(number_format, statistic$observed_value),
          " | Reference unavailable: ",
          statistic$reference_reason,
          " (", support_text, ")\n",
          sep = ""
        )
      } else {
        cat(
          statistic$label,
          "\n  Observed ", sprintf(number_format, statistic$observed_value),
          " | Median ", sprintf(number_format, statistic$replicated_median),
          " | Middle 95% [",
          sprintf(number_format, statistic$replicated_lower),
          ", ", sprintf(number_format, statistic$replicated_upper), "]",
          " | Observed position ",
          sprintf(number_format, statistic$observed_quantile),
          " (", support_text, ")\n",
          sep = ""
        )
      }
    }
  }
  invisible(x)
}


ild_component_label <- function(component) {
  unname(c(
    stable = "Stable partner dependence",
    concurrent = "Concurrent within-member partner dependence",
    own_lag = "Own-member lag profile",
    cross_lag = "Cross-member lag profile"
  )[[component]])
}


#' Plot an intensive-longitudinal partner-dependence check
#'
#' The profile view shows observed correlations, simulated medians, and
#' pointwise middle 50 and 95 percent simulation intervals. The static view
#' shows the stable and concurrent member-level summaries as histograms. The
#' default all view draws both sections.
#'
#' @param x An intensive-longitudinal result returned by
#'   check_partner_dependence().
#' @param view Which sections to draw: all, profiles, or static.
#' @param ask Whether to pause before each plot. NULL chooses automatically.
#' @param ... Additional graphical arguments passed to base plotting methods.
#'   `main`, `sub`, `xlab`, `xlim`, `ylim`, and `freq` are controlled by this
#'   method.
#'
#' @return x, invisibly.
#'
#' @keywords internal
#' @export
plot.dyadMLM_ild_partner_check <- function(
  x,
  view = c("all", "profiles", "static"),
  ask = NULL,
  ...
) {
  view <- match.arg(view)
  components <- switch(
    view,
    profiles = c("own_lag", "cross_lag"),
    static = c("stable", "concurrent"),
    all = c("stable", "concurrent", "own_lag", "cross_lag")
  )
  if (is.null(ask)) {
    ask <- length(components) > 1L && grDevices::dev.interactive()
  }
  previous_ask <- grDevices::devAskNewPage(ask)
  on.exit(grDevices::devAskNewPage(previous_ask), add = TRUE)

  for (component in components) {
    if (component %in% c("own_lag", "cross_lag")) {
      plot_ild_profile_component(x, component, ...)
    } else {
      plot_ild_static_component(x, component, ...)
    }
  }
  invisible(x)
}


plot_ild_profile_component <- function(x, component, ...) {
  profile <- x$statistics_table[
    x$statistics_table$component == component &
      x$statistics_table$statistic == "correlation",
    ,
    drop = FALSE
  ]
  curves <- unique(profile$curve)
  curve_colours <- seq_along(curves)
  support_summary <- vapply(
    curves,
    function(curve) {
      curve_data <- profile[profile$curve == curve, , drop = FALSE]
      curve_data <- curve_data[order(curve_data$lag), , drop = FALSE]
      paste0(
        curve,
        " ",
        paste0(
          curve_data$lag,
          ":",
          curve_data$n_dyads,
          "/",
          curve_data$n_edges,
          collapse = ","
        )
      )
    },
    character(1)
  )
  plotted_values <- c(
    profile$observed_value,
    profile$replicated_median,
    profile$replicated_lower,
    profile$replicated_upper
  )
  plotted_values <- plotted_values[is.finite(plotted_values)]
  y_limits <- if (length(plotted_values) == 0L) {
    c(-1, 1)
  } else {
    range(c(-1, 1, plotted_values))
  }
  x_limits <- range(x$lags)
  if (diff(x_limits) == 0) {
    x_limits <- x_limits + c(-0.5, 0.5)
  }

  graphics::plot(
    NA_real_,
    xlim = x_limits,
    ylim = y_limits,
    xlab = "Positive lag (scheduled occasion steps)",
    ylab = "Correlation",
    main = ild_component_label(component),
    sub = paste0(
      x$weighting,
      " weighting; pointwise simulation intervals; ",
      x$response,
      " responses\nSupport K/E by lag: ",
      paste(support_summary, collapse = "; ")
    ),
    ...
  )
  graphics::abline(h = 0, col = "grey85")

  for (curve_index in seq_along(curves)) {
    curve_rows <- profile$curve == curves[[curve_index]]
    curve_data <- profile[curve_rows, , drop = FALSE]
    curve_data <- curve_data[order(curve_data$lag), , drop = FALSE]
    colour <- curve_colours[[curve_index]]

    finite_95 <- is.finite(curve_data$replicated_lower) &
      is.finite(curve_data$replicated_upper)
    graphics::segments(
      x0 = curve_data$lag[finite_95],
      y0 = curve_data$replicated_lower[finite_95],
      x1 = curve_data$lag[finite_95],
      y1 = curve_data$replicated_upper[finite_95],
      col = grDevices::adjustcolor(colour, alpha.f = 0.35),
      lwd = 2
    )
    finite_50 <- is.finite(curve_data$replicated_lower_50) &
      is.finite(curve_data$replicated_upper_50)
    graphics::segments(
      x0 = curve_data$lag[finite_50],
      y0 = curve_data$replicated_lower_50[finite_50],
      x1 = curve_data$lag[finite_50],
      y1 = curve_data$replicated_upper_50[finite_50],
      col = colour,
      lwd = 4
    )
    graphics::lines(
      curve_data$lag,
      curve_data$replicated_median,
      col = colour,
      lty = 2,
      lwd = 1.5
    )
    graphics::lines(
      curve_data$lag,
      curve_data$observed_value,
      col = colour,
      lwd = 2.5
    )
    graphics::points(
      curve_data$lag,
      curve_data$observed_value,
      col = colour,
      pch = 16
    )
  }

  graphics::legend(
    "topright",
    legend = curves,
    col = curve_colours,
    lty = 1,
    lwd = 2,
    pch = 16,
    bty = "n"
  )
  graphics::legend(
    "bottomright",
    legend = c("Observed", "Simulated median", "Middle 50% / 95%"),
    col = c("black", "black", "grey50"),
    lty = c(1, 2, 1),
    lwd = c(2.5, 1.5, 3),
    bty = "n"
  )
}


plot_ild_static_component <- function(x, component, ...) {
  static_table <- x$statistics_table[
    x$statistics_table$component == component &
      x$statistics_table$parameterization == "member",
    ,
    drop = FALSE
  ]

  for (row_index in seq_len(nrow(static_table))) {
    statistic <- static_table[row_index, , drop = FALSE]
    if (!is.finite(statistic$replicated_median)) {
      graphics::plot.new()
      graphics::title(
        main = statistic$label,
        sub = paste("Reference unavailable:", statistic$reference_reason)
      )
      next
    }
    plot_reference_histogram(
      replicated = x$replicated_statistics[
        , statistic$statistic_id, drop = TRUE
      ],
      statistic = statistic,
      subtitle = paste0(
        statistic$n_dyads,
        " dyads; ",
        statistic$n_edges,
        " pairs; ",
        if (component == "stable") {
          "one pair per dyad (weighting invariant)"
        } else {
          paste0(x$weighting, " weighting")
        }
      ),
      ...
    )
  }
}
