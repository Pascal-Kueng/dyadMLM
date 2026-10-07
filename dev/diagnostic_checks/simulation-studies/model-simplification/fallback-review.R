# Reaggregate completed checkpoints only; no models are fitted or simulated.
# Run from the repository root with Rscript or source() and run_fallback_review().

fallback_rate_intervals <- function(counts) {
  z <- qnorm(0.975)
  counts |>
    dplyr::mutate(rate = flagged / checked,
      centre = (flagged + z^2 / 2) / (checked + z^2),
      half_width = z * sqrt(checked * rate * (1 - rate) + z^2 / 4) / (checked + z^2),
      lower = pmax(0, centre - half_width), upper = pmin(1, centre + half_width)) |>
    dplyr::select(-centre, -half_width)
}

run_fallback_review <- function(
    input_directory = "dev/diagnostic_checks/simulation-studies/results/generalized-covariance-pooling/500-datasets-1000-draws",
    report_directory = "dev/diagnostic_checks/simulation-studies/report-data/generalized-covariance-pooling",
    output_directory = "dev/diagnostic_checks/simulation-studies/results/model-simplification/fallback-review") {
  conditions <- read.csv(file.path(input_directory, "conditions.csv"))
  keys <- c("family", "condition", "repetition")
  checkpoint_files <- file.path(input_directory,
    paste0(conditions$family, "-condition-", conditions$condition, ".rds"))
  export_names <- c("summary", "fits", "stats-summary", "conditions", "settings", "screening")
  input_files <- c(checkpoint_files, file.path(input_directory, paste0(export_names, ".csv")),
    file.path(report_directory, paste0(export_names, ".csv")))
  input_hashes <- tools::md5sum(input_files)
  stopifnot(nrow(conditions) == 90L, all(conditions$repetitions == 500L),
    all(conditions$reference_draws == 1000L), !anyDuplicated(conditions[c("family", "condition")]),
    !anyNA(input_hashes))

  all_fits <- all_outcomes <- all_statistics <- vector("list", nrow(conditions))
  for (index in seq_len(nrow(conditions))) {
    records <- readRDS(checkpoint_files[index])
    condition <- conditions[index, ]
    stopifnot(length(records) == condition$repetitions)
    fits <- dplyr::bind_rows(lapply(records, `[[`, "fits"))
    outcomes <- dplyr::bind_rows(lapply(records, `[[`, "outcomes"))
    statistics <- dplyr::bind_rows(lapply(records, `[[`, "statistics"))
    stopifnot(nrow(fits) == 2L * nrow(outcomes),
      identical(outcomes$repetition, seq_len(condition$repetitions)),
      all(outcomes$family == condition$family & outcomes$condition == condition$condition),
      all(fits$family == condition$family & fits$condition == condition$condition),
      !anyDuplicated(fits[c(keys, "model")]),
      all(table(fits$model) == condition$repetitions),
      setequal(fits$model, c("pooled", "composition")))

    # Verify the saved flags directly against the saved statistic limits.
    stopifnot(identical(statistics$flagged, statistics$below | statistics$above),
      identical(statistics$below, statistics$observed < statistics$lower),
      identical(statistics$above, statistics$observed > statistics$upper))
    expected_flags <- statistics |>
      dplyr::mutate(method = ifelse(model == "composition", "full_any",
        ifelse(check_type == "composition", "composition_any", "pooled_any"))) |>
      dplyr::summarise(expected = any(flagged), .by = dplyr::all_of(c(keys, "method")))
    actual_flags <- outcomes |>
      tidyr::pivot_longer(c(pooled_any, composition_any, full_any),
        names_to = "method", values_to = "actual") |>
      dplyr::left_join(expected_flags, by = c(keys, "method"))
    stopifnot(identical(actual_flags$actual, actual_flags$expected))

    all_fits[[index]] <- fits
    all_outcomes[[index]] <- outcomes
    all_statistics[[index]] <- statistics |>
      dplyr::summarise(checked = sum(!is.na(flagged)), flagged = sum(flagged, na.rm = TRUE),
        below = sum(below, na.rm = TRUE), above = sum(above, na.rm = TRUE),
        undefined_draws = sum(undefined_draws),
        .by = c(family, condition, model, check_type, composition, statistic))
  }
  fits <- dplyr::bind_rows(all_fits)
  outcomes <- dplyr::bind_rows(all_outcomes)
  stopifnot(nrow(outcomes) == 45000L, nrow(fits) == 90000L,
    !anyDuplicated(outcomes[keys]), !anyNA(fits$usable))

  # Reconstruct every numerical summary in the original public report first.
  reconstructed <- list(
    summary = outcomes |>
      tidyr::pivot_longer(-dplyr::all_of(keys), names_to = "method", values_to = "flag") |>
      dplyr::summarise(checked = sum(!is.na(flag)), flagged = sum(flag, na.rm = TRUE),
        .by = c(family, condition, method)) |> fallback_rate_intervals(),
    fits = fits |>
      dplyr::summarise(attempted = dplyr::n(), usable = sum(usable),
        with_warnings = sum(warnings != ""), check_failures = sum(check_error != ""),
        check_warnings = sum(check_warnings != ""), comparison_failures = sum(comparison_error != ""),
        .by = c(family, condition, model)),
    `stats-summary` = dplyr::bind_rows(all_statistics) |> fallback_rate_intervals())
  sort_keys <- list(summary = c("family", "condition", "method"),
    fits = c("family", "condition", "model"),
    `stats-summary` = c("family", "condition", "model", "check_type", "composition", "statistic"))
  for (name in names(reconstructed)) {
    saved <- read.csv(file.path(input_directory, paste0(name, ".csv"))) |>
      dplyr::arrange(dplyr::across(dplyr::all_of(sort_keys[[name]])))
    rebuilt <- reconstructed[[name]] |>
      dplyr::arrange(dplyr::across(dplyr::all_of(sort_keys[[name]])))
    stopifnot(isTRUE(all.equal(saved, as.data.frame(rebuilt),
      tolerance = 1e-12, check.attributes = FALSE)))
  }
  for (name in export_names) {
    stopifnot(identical(unname(tools::md5sum(file.path(input_directory, paste0(name, ".csv")))),
      unname(tools::md5sum(file.path(report_directory, paste0(name, ".csv"))))))
  }

  statuses <- fits |>
    dplyr::select(dplyr::all_of(keys), model, usable, error, warnings, convergence,
      positive_hessian, check_error, check_warnings, comparison_error) |>
    tidyr::pivot_wider(names_from = model, values_from = -dplyr::all_of(c(keys, "model")),
      names_glue = "{model}_{.value}")
  datasets <- dplyr::left_join(outcomes, statuses, by = keys) |>
    dplyr::left_join(conditions, by = c("family", "condition")) |>
    dplyr::mutate(full_fit = ifelse(composition_usable, "usable", "unusable"))
  stopifnot(nrow(datasets) == 45000L, !anyNA(datasets$pooled_usable),
    !anyNA(datasets$composition_usable),
    all(is.na(datasets$composition_any) | datasets$pooled_usable))

  # All attempted datasets stay in the table; check rates use defined checks only.
  # The full-fit split describes a fitted-data subset, not a randomized comparison.
  rates <- dplyr::bind_rows(datasets, dplyr::mutate(datasets, full_fit = "all")) |>
    dplyr::summarise(attempted = dplyr::n(),
      pooled_fit_failures = sum(!pooled_usable),
      pooled_check_errors = sum(pooled_check_error != ""),
      unavailable_checks_after_usable_fit = sum(pooled_usable & is.na(composition_any)),
      checked = sum(!is.na(composition_any)), flagged = sum(composition_any, na.rm = TRUE),
      full_usable = sum(composition_usable), lrt_available = sum(!is.na(likelihood_ratio)),
      pooled_usable = sum(pooled_usable),
      .by = c(family, condition, n_dyads, scenario, full_fit)) |>
    fallback_rate_intervals() |>
    dplyr::mutate(mcse = sqrt(rate * (1 - rate) / checked),
      usable_fraction = pooled_usable / attempted,
      check_available_fraction = checked / attempted,
      flagged_per_attempt = flagged / attempted) |>
    dplyr::arrange(family, n_dyads, scenario, full_fit)
  stopifnot(all(rates$pooled_usable + rates$pooled_fit_failures == rates$attempted),
    all(rates$checked + rates$unavailable_checks_after_usable_fit == rates$pooled_usable))
  failures <- fits |>
    dplyr::filter(!usable | error != "" | warnings != "" | check_error != "" |
      check_warnings != "" | comparison_error != "") |>
    dplyr::count(family, condition, model, usable, convergence, positive_hessian,
      error, warnings, check_error, check_warnings, comparison_error, name = "datasets")
  totals <- datasets |>
    dplyr::summarise(attempted = dplyr::n(),
      full_usable = sum(composition_usable), both_usable = sum(pooled_usable & composition_usable),
      pooled_only = sum(pooled_usable & !composition_usable),
      neither_usable = sum(!pooled_usable & !composition_usable),
      checks_defined = sum(!is.na(composition_any)), pooled_usable = sum(pooled_usable),
      .by = c(family, n_dyads))

  # Protect the old run and its report tables from accidental changes.
  stopifnot(identical(input_hashes, tools::md5sum(input_files)))
  dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)
  for (name in c("rates", "failures", "totals", "conditions")) {
    write.csv(get(name), file.path(output_directory, paste0(name, ".csv")), row.names = FALSE)
  }
  saveRDS(datasets, file.path(output_directory, "datasets.rds"))
  write.csv(data.frame(path = names(input_hashes), md5 = unname(input_hashes)),
    file.path(output_directory, "input-fingerprints.csv"), row.names = FALSE)
  writeLines(c("Completed checkpoint reaggregation; no new fits or simulations.",
    "90 conditions, 45000 datasets, 90000 fit attempts.",
    "All three original numerical summaries reconstructed within 1e-12.",
    "All six original report exports match their saved copies; all input hashes unchanged.",
    "Full-fit availability means original convergence/Hessian/log-likelihood criteria passed.",
    "rate is flagged/checked; flagged_per_attempt is flagged/attempted and is not a sensitivity estimate.",
    "Flags use the original saved middle-95-percent quantile limits, not a later rank-based rule.",
    "The saved reference limits do not contain the tail ranks needed to reconstruct a rank rule.",
    "The full-fit availability strata are descriptive subsets, not causal comparisons.",
    "These records contain no coefficient estimates: inference consequences require new fits.",
    "Selected families passed the original latent-model screen; difficult excluded families remain untested.",
    "", capture.output(print(totals, n = Inf)), "", capture.output(sessionInfo())),
    file.path(output_directory, "validation.txt"))
  message("Saved fallback review: ", output_directory)
  invisible(list(rates = rates, totals = totals, failures = failures))
}

if (sys.nframe() == 0L) run_fallback_review()
