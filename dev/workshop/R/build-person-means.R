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
    self_efficacy,
    solo_mvpa,
    joint_mvpa,
    total_mvpa
  ) |>
  group_by(couple_id, person_id) |>
  summarise(
    gender = first(gender),
    across(where(is.numeric), ~ mean(.x, na.rm = TRUE)),
    .groups = "drop"
  )

numeric_columns <- person_means[vapply(person_means, is.numeric, logical(1))]

stopifnot(
  all(genders_per_person$n_genders == 1),
  identical(sort(unique(daily$couple_id)), seq_len(length(couple_ids))),
  identical(sort(unique(daily$person_id)), seq_len(length(person_ids))),
  identical(sort(unique(full$couple_id)), seq_len(length(couple_ids))),
  identical(sort(unique(full$person_id)), seq_len(length(person_ids))),
  !anyDuplicated(person_means[c("couple_id", "person_id")]),
  all(table(person_means$couple_id) == 2),
  all(!is.na(person_means$gender)),
  all(!is.na(daily$gender)),
  all(!is.na(full$gender)),
  all(vapply(numeric_columns, \(x) all(is.finite(x)), logical(1)))
)

saveRDS(daily, daily_file)
saveRDS(full, full_file)
saveRDS(
  person_means,
  file.path(workshop_dir, "dyadic-person-means.rds")
)
