# Example negative-binomial dyadic data with multiple dyad compositions.
#
# Run data-raw/dyads.R first. This dataset uses exactly the same dyads, members,
# and diary days as the Gaussian data, but provides a count outcome and a
# different predictor for generalized-model examples.

load(file.path("data", "dyads_ild.rda"))

###############################################################################
### STRUCTURE
###############################################################################

diary_days <- sort(unique(dyads_ild$diaryday))
couples <- dyads_ild |>
  dplyr::distinct(coupleID, dyad_composition) |>
  dplyr::arrange(coupleID)

# `member_position` and `member_contrast` are simulation-only columns.
panel <- dyads_ild |>
  dplyr::select(
    personID,
    coupleID,
    diaryday,
    gender,
    dyad_composition
  ) |>
  dplyr::mutate(
    member_position = ifelse(personID %% 2L == 1L, 1L, 2L),
    member_contrast = ifelse(member_position == 1L, 1, -1),
    role_key = dplyr::case_when(
      dyad_composition == "female_x_male" & gender == "female" ~
        "female_x_male_female",
      dyad_composition == "female_x_male" & gender == "male" ~
        "female_x_male_male",
      dyad_composition == "female_x_female" ~ "female_x_female",
      dyad_composition == "male_x_male" ~ "male_x_male"
    )
  )

###############################################################################
### STRESS AND LATENT RANDOM EFFECTS
###############################################################################

simulation_parameters <- tibble::tribble(
  ~dyad_composition, ~stress_mean, ~stress_difference, ~simulation_seed,
  "female_x_male",            5.0,               0.10,            91026L,
  "female_x_female",          4.8,               0.00,            91027L,
  "male_x_male",              5.2,               0.00,            91028L
)

shared_stable_covariance <- matrix(
  c(
    0.28^2,
    0.15 * 0.28 * 0.07,
    0.15 * 0.28 * 0.07,
    0.07^2
  ),
  nrow = 2L
)
difference_stable_covariance <- matrix(
  c(
    0.18^2,
    -0.10 * 0.18 * 0.05,
    -0.10 * 0.18 * 0.05,
    0.05^2
  ),
  nrow = 2L
)

stress_mean_rows <- vector("list", nrow(simulation_parameters))
stress_day_rows <- vector("list", nrow(simulation_parameters))
stable_effect_rows <- vector("list", nrow(simulation_parameters))
occasion_effect_rows <- vector("list", nrow(simulation_parameters))

for (composition_index in seq_len(nrow(simulation_parameters))) {
  parameters <- simulation_parameters[composition_index, ]
  couple_ids <- couples$coupleID[
    couples$dyad_composition == parameters$dyad_composition
  ]
  set.seed(parameters$simulation_seed)

  stress_mean_rows[[composition_index]] <- tibble::tibble(
    coupleID = couple_ids,
    stress_shared_mean = stats::rnorm(
      length(couple_ids),
      parameters$stress_mean,
      0.70
    ),
    stress_difference_mean = stats::rnorm(
      length(couple_ids),
      parameters$stress_difference,
      0.40
    )
  )

  # Shape: one row per couple x day for the current composition.
  composition_days <- expand.grid(
    diaryday = diary_days,
    coupleID = couple_ids
  ) |>
    tibble::as_tibble() |>
    dplyr::select(coupleID, diaryday)

  stress_day_rows[[composition_index]] <- composition_days |>
    dplyr::mutate(
      stress_shared_within = stats::rnorm(dplyr::n(), 0, 0.55),
      stress_difference_within = stats::rnorm(dplyr::n(), 0, 0.45)
    )

  shared_stable_effects <- MASS::mvrnorm(
    n = length(couple_ids),
    mu = c(0, 0),
    Sigma = shared_stable_covariance
  )
  difference_stable_effects <- MASS::mvrnorm(
    n = length(couple_ids),
    mu = c(0, 0),
    Sigma = difference_stable_covariance
  )
  stable_effect_rows[[composition_index]] <- tibble::tibble(
    coupleID = couple_ids,
    shared_intercept = shared_stable_effects[, 1L],
    shared_actor_slope = shared_stable_effects[, 2L],
    difference_intercept = difference_stable_effects[, 1L],
    difference_actor_slope = difference_stable_effects[, 2L]
  )

  occasion_effect_rows[[composition_index]] <- composition_days |>
    dplyr::mutate(
      occasion_shared = stats::rnorm(dplyr::n(), 0, 0.12),
      occasion_difference = stats::rnorm(dplyr::n(), 0, 0.08)
    )
}

stress_means <- dplyr::bind_rows(stress_mean_rows)
stress_by_day <- dplyr::bind_rows(stress_day_rows)
stable_effects <- dplyr::bind_rows(stable_effect_rows)
occasion_effects <- dplyr::bind_rows(occasion_effect_rows)

###############################################################################
### CONDITIONAL LOG-MEAN
###############################################################################

fixed_effects <- tibble::tribble(
  ~role_key,              ~intercept, ~time, ~between_actor, ~between_partner, ~within_actor, ~within_partner,
  "female_x_male_female",      1.00,  0.004,           0.18,             0.08,          0.24,            0.10,
  "female_x_male_male",        1.18,  0.002,           0.15,             0.06,          0.20,            0.08,
  "female_x_female",           1.05,  0.003,           0.17,             0.07,          0.22,            0.09,
  "male_x_male",               1.22,  0.001,           0.14,             0.05,          0.18,            0.07
)

panel <- panel |>
  dplyr::left_join(stress_means, by = "coupleID") |>
  dplyr::left_join(stress_by_day, by = c("coupleID", "diaryday")) |>
  dplyr::mutate(
    stress =
      stress_shared_mean +
      member_contrast * stress_difference_mean +
      stress_shared_within +
      member_contrast * stress_difference_within
  ) |>
  dplyr::group_by(personID) |>
  dplyr::mutate(
    stress_person_mean = mean(stress),
    stress_actor_within = stress - stress_person_mean
  ) |>
  dplyr::ungroup() |>
  dplyr::mutate(
    stress_actor_between = stress_person_mean - mean(stress_person_mean)
  ) |>
  dplyr::group_by(coupleID, diaryday) |>
  dplyr::mutate(
    stress_partner_within = stress_actor_within[3L - member_position],
    stress_partner_between = stress_actor_between[3L - member_position]
  ) |>
  dplyr::ungroup() |>
  dplyr::left_join(fixed_effects, by = "role_key") |>
  dplyr::left_join(stable_effects, by = "coupleID") |>
  dplyr::left_join(occasion_effects, by = c("coupleID", "diaryday")) |>
  dplyr::mutate(
    member_stable_intercept =
      shared_intercept + member_contrast * difference_intercept,
    member_actor_slope =
      shared_actor_slope + member_contrast * difference_actor_slope,
    log_expected_conflicts =
      intercept + member_stable_intercept +
      time * diaryday +
      between_actor * stress_actor_between +
      between_partner * stress_partner_between +
      (within_actor + member_actor_slope) * stress_actor_within +
      within_partner * stress_partner_within +
      occasion_shared + member_contrast * occasion_difference
  )

###############################################################################
### FINAL PACKAGE DATA
###############################################################################

nbinom_size <- 5

set.seed(92001)
dyads_nbinom_ild <- panel |>
  dplyr::mutate(
    conflict_count = stats::rnbinom(
      dplyr::n(),
      mu = exp(log_expected_conflicts),
      size = nbinom_size
    )
  ) |>
  dplyr::select(
    personID,
    coupleID,
    diaryday,
    gender,
    dyad_composition,
    conflict_count,
    stress
  ) |>
  dplyr::arrange(coupleID, diaryday, personID)

# The cross-sectional predictor is each person's average stress across all 14
# days. Its count outcome is a new NB2 draw, not an average or sum of the daily
# counts. Conditional on its mean, Var(Y) = mu + mu^2 / nbinom_size.
dyads_nbinom_cross <- panel |>
  dplyr::transmute(
    personID,
    coupleID,
    gender,
    dyad_composition,
    stress = stress_person_mean,
    log_expected_conflicts_cross =
      intercept + member_stable_intercept +
      between_actor * stress_actor_between +
      between_partner * stress_partner_between
  ) |>
  dplyr::distinct()

set.seed(92002)
dyads_nbinom_cross <- dyads_nbinom_cross |>
  dplyr::mutate(
    conflict_count = stats::rnbinom(
      dplyr::n(),
      mu = exp(log_expected_conflicts_cross),
      size = nbinom_size
    )
  ) |>
  dplyr::select(
    personID,
    coupleID,
    gender,
    dyad_composition,
    conflict_count,
    stress
  ) |>
  dplyr::arrange(coupleID, personID)

usethis::use_data(dyads_nbinom_cross, overwrite = TRUE)
usethis::use_data(dyads_nbinom_ild, overwrite = TRUE)
