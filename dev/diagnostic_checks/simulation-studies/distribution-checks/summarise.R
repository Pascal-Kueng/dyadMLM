# Failed checks retain their standard statistic rows with NA flags. Category rows
# are conditional on the category being displayed in that dataset's outcome plot.
summarise_distribution_study <- function(conditions, fits, statistics) {
  fit_counts <- fits |>
    dplyr::group_by(condition, reference) |>
    dplyr::summarise(
      attempted = dplyr::n(), usable = sum(usable, na.rm = TRUE),
      with_warnings = sum(!is.na(warnings) & nzchar(warnings)),
      fit_errors = sum(status == "fit_error", na.rm = TRUE),
      fit_problems = sum(status == "fit_problem", na.rm = TRUE),
      check_errors = sum(status == "check_error", na.rm = TRUE),
      fit_seconds = sum(fit_seconds, na.rm = TRUE),
      check_seconds = sum(check_seconds, na.rm = TRUE), .groups = "drop")
  fit_summary <- dplyr::left_join(conditions, fit_counts, by = "condition")

  summary <- statistics |>
    dplyr::group_by(condition, reference, view, role, check, statistic) |>
    dplyr::summarise(
      checked = sum(!is.na(flagged)), flagged = sum(flagged, na.rm = TRUE),
      below = sum(below, na.rm = TRUE), above = sum(above, na.rm = TRUE),
      .groups = "drop") |>
    dplyr::mutate(
      rate = dplyr::if_else(checked > 0, flagged / checked, NA_real_),
      mcse = sqrt(rate * (1 - rate) / checked),
      interval_center = (rate + qnorm(0.975)^2 / (2 * checked)) /
        (1 + qnorm(0.975)^2 / checked),
      interval_half_width = qnorm(0.975) *
        sqrt(rate * (1 - rate) / checked + qnorm(0.975)^2 / (4 * checked^2)) /
        (1 + qnorm(0.975)^2 / checked),
      rate_lower = pmax(0, interval_center - interval_half_width),
      rate_upper = pmin(1, interval_center + interval_half_width),
      fit_reference = dplyr::if_else(reference == "known", "known", "fitted")) |>
    dplyr::select(-interval_center, -interval_half_width) |>
    dplyr::left_join(dplyr::select(fit_counts, condition, reference, attempted, usable),
      by = c("condition", "fit_reference" = "reference")) |>
    dplyr::select(-fit_reference) |>
    dplyr::left_join(conditions, by = "condition") |>
    dplyr::relocate(dplyr::all_of(names(conditions)))

  paired_comparison <- statistics |>
    dplyr::filter(reference %in% c("fitted-centred", "fitted-uncentred"),
      check %in% c("residual", "both")) |>
    dplyr::select(condition, repetition, view, role, check, statistic, reference, flagged) |>
    dplyr::mutate(reference = factor(reference,
      levels = c("fitted-centred", "fitted-uncentred"))) |>
    tidyr::pivot_wider(names_from = reference, values_from = flagged, names_expand = TRUE) |>
    dplyr::mutate(difference = as.integer(.data[["fitted-centred"]]) -
      as.integer(.data[["fitted-uncentred"]])) |>
    dplyr::group_by(condition, view, role, check, statistic) |>
    dplyr::summarise(
      checked = sum(!is.na(difference)),
      centred_only = sum(difference == 1, na.rm = TRUE),
      uncentred_only = sum(difference == -1, na.rm = TRUE),
      both = sum(.data[["fitted-centred"]] & .data[["fitted-uncentred"]], na.rm = TRUE),
      neither = sum(!.data[["fitted-centred"]] & !.data[["fitted-uncentred"]], na.rm = TRUE),
      centred_minus_uncentred = if (checked > 0) mean(difference, na.rm = TRUE) else NA_real_,
      difference_mcse = stats::sd(difference, na.rm = TRUE) / sqrt(checked),
      .groups = "drop") |>
    dplyr::left_join(fit_counts |>
      dplyr::filter(reference == "fitted") |>
      dplyr::select(condition, attempted, usable), by = "condition") |>
    dplyr::left_join(conditions, by = "condition") |>
    dplyr::relocate(dplyr::all_of(names(conditions)))

  list(summary = summary, paired_comparison = paired_comparison, fit_summary = fit_summary)
}
