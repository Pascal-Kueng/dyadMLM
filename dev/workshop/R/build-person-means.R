library(dplyr)

workshop_dir <- if (dir.exists(file.path("dev", "workshop"))) {
  file.path("dev", "workshop")
} else {
  "."
}

daily <- readRDS(file.path(workshop_dir, "dyadic-data.rds"))

roles_per_person <- daily |>
  distinct(coupleID, personID, gender) |>
  count(coupleID, personID, name = "n_roles")

person_means <- daily |>
  transmute(
    couple_id = coupleID,
    person_id = personID,
    role = factor(gender, levels = c(1, 2), labels = c("female", "male")),
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
    role = first(role),
    across(where(is.numeric), ~ mean(.x, na.rm = TRUE)),
    .groups = "drop"
  )

numeric_columns <- person_means[vapply(person_means, is.numeric, logical(1))]

stopifnot(
  all(roles_per_person$n_roles == 1),
  !anyDuplicated(person_means[c("couple_id", "person_id")]),
  all(table(person_means$couple_id) == 2),
  all(!is.na(person_means$role)),
  all(vapply(numeric_columns, \(x) all(is.finite(x)), logical(1)))
)

saveRDS(
  person_means,
  file.path(workshop_dir, "dyadic-person-means.rds")
)
