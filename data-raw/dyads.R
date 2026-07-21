# Example Gaussian dyadic data with multiple dyad compositions.
#
# The same simulation provides an intensive longitudinal panel and a separate
# cross-sectional dataset formed by averaging each person's 14 observations.

###############################################################################
### DESIGN
###############################################################################

dyads_per_composition <- 120L
diary_days <- 0:13

couples <- tibble::tibble(
  coupleID = seq_len(3L * dyads_per_composition),
  dyad_composition = rep(
    c("female_x_male", "female_x_female", "male_x_male"),
    each = dyads_per_composition
  ),
  member_1_gender = rep(
    c("female", "female", "male"),
    each = dyads_per_composition
  ),
  member_2_gender = rep(
    c("male", "female", "male"),
    each = dyads_per_composition
  )
)

# One row per person. `member_position` is used only by this simulation to give
# the two members opposite signs for member-contrast random effects.
persons <- dplyr::bind_rows(
  dplyr::transmute(
    couples,
    coupleID,
    dyad_composition,
    member_position = 1L,
    gender = member_1_gender
  ),
  dplyr::transmute(
    couples,
    coupleID,
    dyad_composition,
    member_position = 2L,
    gender = member_2_gender
  )
) |>
  dplyr::arrange(coupleID, member_position) |>
  dplyr::mutate(
    personID = as.integer(2L * coupleID - 2L + member_position),
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
### PROVIDED SUPPORT
###############################################################################

# Each person's usual support is a shared dyad level plus an equal-and-opposite
# member difference. This directly represents the two exchangeable components.
support_mean_parameters <- tibble::tribble(
  ~dyad_composition, ~shared_mean, ~difference_mean, ~simulation_seed,
  "female_x_male",             4.9,             0.10,            81026L,
  "female_x_female",           5.2,             0.00,            81027L,
  "male_x_male",               4.6,             0.00,            81028L
)

# The shared block and member-contrast block each contain an intercept and a
# within-person actor slope. Both slope variances are deliberately nonzero so
# the APIM vignette can fit and compare the full and constrained structures.
shared_stable_sds <- c(intercept = 0.70, actor_slope = 0.24)
shared_stable_correlation <- 0.20
shared_stable_covariance <- matrix(
  c(
    shared_stable_sds[["intercept"]]^2,
    shared_stable_correlation * prod(shared_stable_sds),
    shared_stable_correlation * prod(shared_stable_sds),
    shared_stable_sds[["actor_slope"]]^2
  ),
  nrow = 2L
)

difference_stable_sds <- c(intercept = 0.50, actor_slope = 0.30)
difference_stable_correlation <- -0.15
difference_stable_covariance <- matrix(
  c(
    difference_stable_sds[["intercept"]]^2,
    difference_stable_correlation * prod(difference_stable_sds),
    difference_stable_correlation * prod(difference_stable_sds),
    difference_stable_sds[["actor_slope"]]^2
  ),
  nrow = 2L
)

# Generate all random components for one composition at a time. Separate seeds
# make each composition reproducible even if another composition changes later.
support_mean_rows <- vector("list", nrow(support_mean_parameters))
support_day_rows <- vector("list", nrow(support_mean_parameters))
stable_effect_rows <- vector("list", nrow(support_mean_parameters))
residual_rows <- vector("list", nrow(support_mean_parameters))

for (composition_index in seq_len(nrow(support_mean_parameters))) {
  parameters <- support_mean_parameters[composition_index, ]
  couple_ids <- couples$coupleID[
    couples$dyad_composition == parameters$dyad_composition
  ]
  set.seed(parameters$simulation_seed)

  support_mean_rows[[composition_index]] <- tibble::tibble(
    coupleID = couple_ids,
    support_shared_mean = stats::rnorm(
      length(couple_ids),
      mean = parameters$shared_mean,
      sd = 0.70
    ),
    support_difference_mean = stats::rnorm(
      length(couple_ids),
      mean = parameters$difference_mean,
      sd = 0.40
    )
  )

  # Shape: one row per couple x day for the current composition.
  composition_days <- expand.grid(
    diaryday = diary_days,
    coupleID = couple_ids
  ) |>
    tibble::as_tibble() |>
    dplyr::select(coupleID, diaryday)

  # Occasion-specific support has the same shared/difference shape.
  support_day_rows[[composition_index]] <- composition_days |>
    dplyr::mutate(
      support_shared_within = stats::rnorm(dplyr::n(), 0, 0.55),
      support_difference_within = stats::rnorm(dplyr::n(), 0, 0.45)
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

  # These two components exactly match the two same-occasion blocks in the
  # fitted exchangeable model.
  residual_rows[[composition_index]] <- composition_days |>
    dplyr::mutate(
      shared_residual = stats::rnorm(dplyr::n(), 0, 0.60),
      difference_residual = stats::rnorm(dplyr::n(), 0, 0.42)
    )
}

support_mean_effects <- dplyr::bind_rows(support_mean_rows)
support_by_day <- dplyr::bind_rows(support_day_rows)
stable_effects <- dplyr::bind_rows(stable_effect_rows)
residual_process <- dplyr::bind_rows(residual_rows)

###############################################################################
### OUTCOME FIXED EFFECTS
###############################################################################

# Female-male members have role-specific effects. Members of each same-gender
# composition share the same effects, as exchangeability requires.
fixed_effects <- tibble::tribble(
  ~role_key,              ~intercept, ~time, ~between_actor, ~between_partner, ~within_actor, ~within_partner,
  "female_x_male_female",      5.50,  0.012,           1.35,             0.45,          0.40,            0.18,
  "female_x_male_male",        4.65, -0.006,           1.00,             0.25,          0.22,            0.08,
  "female_x_female",           5.40,  0.010,           1.15,             0.35,          0.27,            0.21,
  "male_x_male",               4.35, -0.002,           0.90,             0.22,          0.20,            0.07
)

###############################################################################
### BUILD THE PERSON-DAY PANEL AND CONDITIONAL MEAN
###############################################################################

# Shape: one row per couple x day x member.
panel <- expand.grid(
  coupleID = couples$coupleID,
  diaryday = diary_days,
  member_position = 1:2
) |>
  tibble::as_tibble() |>
  dplyr::arrange(coupleID, diaryday, member_position) |>
  dplyr::left_join(persons, by = c("coupleID", "member_position")) |>
  dplyr::left_join(support_mean_effects, by = "coupleID") |>
  dplyr::left_join(support_by_day, by = c("coupleID", "diaryday")) |>
  dplyr::mutate(
    support_generating_mean = support_shared_mean +
      member_contrast * support_difference_mean,
    provided_support =
      support_generating_mean +
      support_shared_within +
      member_contrast * support_difference_within
  ) |>
  dplyr::group_by(personID) |>
  dplyr::mutate(
    # These are the exact components that prepare_dyad_data() will construct.
    support_person_mean = mean(provided_support),
    support_actor_within = provided_support - support_person_mean
  ) |>
  dplyr::ungroup() |>
  dplyr::mutate(
    support_actor_between = support_person_mean -
      mean(support_person_mean)
  ) |>
  dplyr::group_by(coupleID, diaryday) |>
  dplyr::mutate(
    support_partner_within = support_actor_within[3L - member_position],
    support_partner_between = support_actor_between[3L - member_position]
  ) |>
  dplyr::ungroup()

panel <- panel |>
  dplyr::left_join(fixed_effects, by = "role_key") |>
  dplyr::left_join(stable_effects, by = "coupleID") |>
  dplyr::mutate(
    member_stable_intercept =
      shared_intercept + member_contrast * difference_intercept,
    member_actor_slope =
      shared_actor_slope + member_contrast * difference_actor_slope,
    expected_closeness =
      intercept + member_stable_intercept +
      time * diaryday +
      between_actor * support_actor_between +
      between_partner * support_partner_between +
      (within_actor + member_actor_slope) * support_actor_within +
      within_partner * support_partner_within
  )

###############################################################################
### FINAL PACKAGE DATA
###############################################################################

dyads_ild <- panel |>
  dplyr::left_join(residual_process, by = c("coupleID", "diaryday")) |>
  dplyr::mutate(
    closeness = expected_closeness + shared_residual +
      member_contrast * difference_residual,
    gender = factor(gender, levels = c("female", "male")),
    dyad_composition = factor(
      dyad_composition,
      levels = c("female_x_male", "female_x_female", "male_x_male")
    )
  ) |>
  dplyr::select(
    personID,
    coupleID,
    diaryday,
    gender,
    dyad_composition,
    closeness,
    provided_support
  ) |>
  dplyr::arrange(coupleID, diaryday, personID)

# Average each person's observed values across all 14 days. The resulting data
# have one row per member and no time column.
dyads_cross <- dyads_ild |>
  dplyr::group_by(
    personID,
    coupleID,
    gender,
    dyad_composition
  ) |>
  dplyr::summarise(
    closeness = mean(closeness),
    provided_support = mean(provided_support),
    .groups = "drop"
  ) |>
  dplyr::arrange(coupleID, personID)

usethis::use_data(dyads_cross, overwrite = TRUE)
usethis::use_data(dyads_ild, overwrite = TRUE)
