# Positive and negative conditions count only flags in the expected direction.
# With zero correlation, either tail counts because there is no expected direction.
summarise_family_comparison <- function(statistics, completion) {
  statistics <- statistics |>
    dplyr::mutate(
      comparison_defined = is.finite(observed) & is.finite(reference_lower) & is.finite(reference_upper),
      expected_direction_flag = dplyr::case_when(
        !comparison_defined | target_correlation == 0 ~ NA,
        target_correlation > 0 ~ observed > reference_upper,
        TRUE ~ observed < reference_lower),
      opposite_direction_flag = dplyr::case_when(
        !comparison_defined | target_correlation == 0 ~ NA,
        target_correlation > 0 ~ observed < reference_lower,
        TRUE ~ observed > reference_upper),
      counted_flag = dplyr::if_else(target_correlation == 0,
        dplyr::if_else(comparison_defined, flagged, NA), expected_direction_flag))

  statistic_counts <- statistics |>
    dplyr::group_by(family, condition, n_dyads, target_correlation, response) |>
    dplyr::summarise(checked = sum(!is.na(counted_flag)), flagged = sum(flagged, na.rm = TRUE),
      detected = sum(expected_direction_flag, na.rm = TRUE),
      opposite_direction = sum(opposite_direction_flag, na.rm = TRUE),
      counted = sum(counted_flag, na.rm = TRUE),
      undefined_draws = sum(undefined_draws), .groups = "drop")
  summary <- tidyr::crossing(completion, response = c("model-centred", "raw")) |>
    dplyr::left_join(statistic_counts, by = c("family", "condition", "n_dyads", "target_correlation", "response")) |>
    tidyr::replace_na(list(checked = 0L, flagged = 0L, detected = 0L,
      opposite_direction = 0L, counted = 0L, undefined_draws = 0L)) |>
    dplyr::mutate(
      detected = dplyr::if_else(target_correlation == 0, NA_integer_, detected),
      opposite_direction = dplyr::if_else(target_correlation == 0, NA_integer_, opposite_direction),
      frequency = counted / checked,
      interval_center = (frequency + qnorm(0.975)^2 / (2 * checked)) / (1 + qnorm(0.975)^2 / checked),
      interval_half_width = qnorm(0.975) *
        sqrt(frequency * (1 - frequency) / checked + qnorm(0.975)^2 / (4 * checked^2)) /
        (1 + qnorm(0.975)^2 / checked),
      frequency_lower = pmax(0, interval_center - interval_half_width),
      frequency_upper = pmin(1, interval_center + interval_half_width)) |>
    dplyr::select(-interval_center, -interval_half_width)

  paired_comparison <- statistics |>
    dplyr::select(family, condition, n_dyads, target_correlation, repetition, response, counted_flag) |>
    tidyr::pivot_wider(names_from = response, values_from = counted_flag) |>
    dplyr::filter(!is.na(raw), !is.na(.data[["model-centred"]])) |>
    dplyr::mutate(difference = as.integer(raw) - as.integer(.data[["model-centred"]])) |>
    dplyr::group_by(family, condition, n_dyads, target_correlation) |>
    dplyr::summarise(checked = dplyr::n(), raw_only = sum(difference == 1), centred_only = sum(difference == -1),
      raw_minus_centred = mean(difference), difference_mcse = sd(difference) / sqrt(checked), .groups = "drop")
  list(summary = summary, paired_comparison = paired_comparison)
}
