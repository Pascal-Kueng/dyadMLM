library(dplyr)

workshop_dir <- if (dir.exists(file.path("dev", "workshop"))) {
  file.path("dev", "workshop")
} else {
  "."
}

daily_file <- file.path(workshop_dir, "dyadic-data.rds")
full_file <- file.path(workshop_dir, "long.rds")

daily <- readRDS(daily_file)
full <- readRDS(full_file)

standardize_efficacy_name <- function(data, candidates) {
  if ("efficacy" %in% names(data)) {
    return(data)
  }

  source <- candidates[candidates %in% names(data)]
  if (length(source) != 1) {
    stop("Could not identify exactly one efficacy variable.")
  }

  names(data)[names(data) == source] <- "efficacy"
  data
}

daily <- standardize_efficacy_name(daily, "self_efficacy")
full <- standardize_efficacy_name(full, c("self_efficacy", "ss_eff"))

recode_gender <- function(x) {
  x <- as.character(x)
  x[x == "1"] <- "female"
  x[x == "2"] <- "male"
  factor(x, levels = c("female", "male"))
}

couple_ids <- sort(unique(full$coupleID))
person_ids <- sort(unique(full$userID))

if (all(c("coupleID", "personID") %in% names(daily))) {
  stopifnot(
    setequal(unique(daily$coupleID), couple_ids),
    setequal(unique(daily$personID), person_ids)
  )

  daily <- daily |>
    mutate(
      couple_id = match(coupleID, couple_ids),
      person_id = match(personID, person_ids),
      gender = recode_gender(gender)
    ) |>
    select(
      couple_id, person_id, diaryday, gender,
      everything(), -coupleID, -personID
    )
} else {
  daily <- daily |>
    mutate(gender = recode_gender(gender))
}

full <- full |>
  mutate(
    couple_id = match(coupleID, couple_ids),
    person_id = match(userID, person_ids),
    gender = recode_gender(gender)
  ) |>
  relocate(couple_id, person_id, gender)

mixed_gender_couples <- full |>
  distinct(couple_id, person_id, gender) |>
  group_by(couple_id) |>
  summarise(
    n_people = n(),
    n_female = sum(gender == "female"),
    n_male = sum(gender == "male"),
    .groups = "drop"
  ) |>
  filter(n_people == 2, n_female == 1, n_male == 1) |>
  pull(couple_id)

daily <- daily |>
  filter(couple_id %in% mixed_gender_couples)

full <- full |>
  filter(couple_id %in% mixed_gender_couples)

retained_couple_ids <- sort(unique(full$couple_id))
retained_person_ids <- sort(unique(full$person_id))

daily <- daily |>
  mutate(
    couple_id = match(couple_id, retained_couple_ids),
    person_id = match(person_id, retained_person_ids)
  )

full <- full |>
  mutate(
    couple_id = match(couple_id, retained_couple_ids),
    person_id = match(person_id, retained_person_ids)
  )

generate_sedentary <- function(data, seed = 20260728L, skew = 0.01) {
  required_columns <- c(
    "couple_id", "person_id", "diaryday", "gender",
    "provided_support", "total_mvpa"
  )
  missing_columns <- setdiff(required_columns, names(data))
  if (length(missing_columns) > 0L) {
    stop(
      "Missing columns: ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }

  simulation_data <- data |>
    mutate(.original_row = row_number()) |>
    arrange(couple_id, diaryday, person_id)

  rows_per_dyad_day <- simulation_data |>
    count(couple_id, diaryday, name = "number_of_rows")
  if (any(rows_per_dyad_day$number_of_rows != 2L)) {
    stop("Every dyad-day must contain exactly two members.", call. = FALSE)
  }

  support_means <- simulation_data |>
    summarise(
      support_mean = mean(provided_support, na.rm = TRUE),
      .by = c(couple_id, person_id)
    )
  if (any(!is.finite(support_means$support_mean))) {
    stop("Every person needs an observed support value.", call. = FALSE)
  }

  simulation_data <- simulation_data |>
    left_join(
      support_means,
      by = c("couple_id", "person_id"),
      relationship = "many-to-one"
    ) |>
    mutate(
      support_cwp_actor = provided_support - support_mean
    ) |>
    group_by(couple_id, diaryday) |>
    mutate(
      support_cwp_partner = rev(support_cwp_actor),
      member_contrast = c(1, -1)
    ) |>
    ungroup()

  set.seed(seed)

  dyads <- sort(unique(simulation_data$couple_id))
  stable_effects <- data.frame(
    couple_id = dyads,
    stable_shared = rnorm(length(dyads), 0, 32),
    stable_difference = rnorm(length(dyads), 0, 24)
  )

  day_member_sd <- sqrt(52^2 + 44^2)

  simulation_data <- simulation_data |>
    left_join(
      stable_effects,
      by = "couple_id",
      relationship = "many-to-one"
    ) |>
    mutate(
      fixed_and_stable = (
        540 -
          8 * coalesce(support_cwp_actor, 0) -
          4 * coalesce(support_cwp_partner, 0) +
          stable_shared +
          member_contrast * stable_difference
      )
    )

  dyad_day <- interaction(
    simulation_data$couple_id,
    simulation_data$diaryday,
    drop = TRUE
  )
  dyad_day_rows <- split(seq_len(nrow(simulation_data)), dyad_day)
  day_rough <- numeric(nrow(simulation_data))
  generation_attempts <- integer(length(dyad_day_rows))

  for (i in seq_along(dyad_day_rows)) {
    rows <- dyad_day_rows[[i]]
    accepted <- FALSE

    while (!accepted && generation_attempts[[i]] < 10000L) {
      generation_attempts[[i]] <- generation_attempts[[i]] + 1L
      day_shared <- rnorm(1, 0, 52)
      day_difference <- rnorm(1, 0, 44)
      day_normal <- day_shared +
        simulation_data$member_contrast[rows] * day_difference
      day_standardized <- day_normal / day_member_sd
      candidate_day_rough <- day_member_sd * (
        day_standardized +
          skew * (day_standardized^2 - 1)
      ) / sqrt(1 + 2 * skew^2)
      candidate_sedentary <- round(
        simulation_data$fixed_and_stable[rows] +
          candidate_day_rough
      )

      constrained <- !is.na(simulation_data$total_mvpa[rows])
      accepted <- all(
        candidate_sedentary[constrained] >= 0 &
          candidate_sedentary[constrained] +
            simulation_data$total_mvpa[rows][constrained] <=
            19 * 60
      )
    }

    if (!accepted) {
      stop(
        "Could not generate a valid sedentary value for one dyad-day.",
        call. = FALSE
      )
    }
    day_rough[rows] <- candidate_day_rough
  }

  simulation_data |>
    mutate(
      sedentary = round(fixed_and_stable + day_rough),
      sedentary = if_else(
        is.na(total_mvpa),
        NA_real_,
        sedentary
      )
    ) |>
    arrange(.original_row) |>
    pull(sedentary)
}

daily <- daily |>
  select(-any_of("sedentary"))
full <- full |>
  select(-any_of("sedentary"))

daily$sedentary <- generate_sedentary(daily)

daily_key <- paste(
  daily$couple_id,
  daily$person_id,
  daily$diaryday
)
full_key <- paste(
  full$couple_id,
  full$person_id,
  full$day
)
sedentary_index <- match(full_key, daily_key)
if (anyNA(sedentary_index)) {
  stop("Could not align all full-data rows to the daily data.", call. = FALSE)
}
full$sedentary <- daily$sedentary[sedentary_index]

couple_ids <- sort(unique(full$couple_id))
person_ids <- sort(unique(full$person_id))

genders_per_person <- daily |>
  distinct(couple_id, person_id, gender) |>
  count(couple_id, person_id, name = "n_genders")

person_means <- daily |>
  select(
    couple_id,
    person_id,
    gender,
    provided_support,
    received_support,
    collaborative_planning,
    exerted_persuasion,
    experienced_persuasion,
    efficacy,
    solo_mvpa,
    joint_mvpa,
    total_mvpa,
    sedentary
  ) |>
  group_by(couple_id, person_id) |>
  summarise(
    gender = first(gender),
    across(where(is.numeric), ~ mean(.x, na.rm = TRUE)),
    .groups = "drop"
  )

numeric_columns <- person_means[vapply(person_means, is.numeric, logical(1))]
observed_sedentary <- daily$sedentary[is.finite(daily$sedentary)]
sedentary_skewness <- mean(
  (observed_sedentary - mean(observed_sedentary))^3
) / sd(observed_sedentary)^3
jointly_observed_time <- is.finite(daily$sedentary) &
  is.finite(daily$total_mvpa)

stopifnot(
  all(genders_per_person$n_genders == 1),
  identical(sort(unique(daily$couple_id)), seq_len(length(couple_ids))),
  identical(sort(unique(daily$person_id)), seq_len(length(person_ids))),
  identical(sort(unique(full$couple_id)), seq_len(length(couple_ids))),
  identical(sort(unique(full$person_id)), seq_len(length(person_ids))),
  !anyDuplicated(person_means[c("couple_id", "person_id")]),
  all(table(person_means$couple_id) == 2),
  all(table(person_means$couple_id, person_means$gender) == 1),
  all(!is.na(person_means$gender)),
  all(!is.na(daily$gender)),
  all(!is.na(full$gender)),
  "efficacy" %in% names(daily),
  "efficacy" %in% names(full),
  "efficacy" %in% names(person_means),
  "sedentary" %in% names(daily),
  "sedentary" %in% names(full),
  "sedentary" %in% names(person_means),
  !any(c("self_efficacy", "ss_eff") %in% names(daily)),
  !any(c("self_efficacy", "ss_eff") %in% names(full)),
  !any(c("self_efficacy", "ss_eff") %in% names(person_means)),
  identical(daily$sedentary[sedentary_index], full$sedentary),
  all(observed_sedentary >= 0),
  mean(observed_sedentary) > 500,
  mean(observed_sedentary) < 580,
  sd(observed_sedentary) > 60,
  sd(observed_sedentary) < 110,
  sedentary_skewness > 0,
  sedentary_skewness < 0.5,
  all(
    daily$sedentary[jointly_observed_time] +
      daily$total_mvpa[jointly_observed_time] <=
      19 * 60
  ),
  all(vapply(numeric_columns, \(x) all(is.finite(x)), logical(1)))
)

saveRDS(daily, daily_file)
saveRDS(full, full_file)
saveRDS(
  person_means,
  file.path(workshop_dir, "dyadic-person-means.rds")
)
