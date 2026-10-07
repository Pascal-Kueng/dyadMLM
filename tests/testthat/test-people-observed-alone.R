# Two female-male dyads, one male-male dyad, and three people observed alone:
# two without a partner (dyads 4 and 5) and one whose partner is not in the
# data (dyad 6).
alone_data <- function() {
  tibble::tibble(
    dyad_id = c(1, 1, 2, 2, 3, 3, 4, 5, 6),
    person_id = 1:9,
    gender = c("female", "male", "female", "male", "male", "male", "male", "female", "male"),
    partnered = c(TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE)
  )
}

prepare_alone <- function(data = alone_data(), ...) {
  prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    partner_exists = partnered,
    seed = 123,
    ...
  )
}

test_that("people observed alone get their own labels and indicators", {
  prepared <- prepare_alone(role = gender)

  expect_equal(
    as.character(prepared$.composition[7:9]),
    c("singleton_male", "singleton_female", "male_x_missing")
  )
  expect_equal(prepared$.is_singleton_male, c(0, 0, 0, 0, 0, 0, 1, 0, 0))
  expect_equal(prepared$.is_singleton_female, c(0, 0, 0, 0, 0, 0, 0, 1, 0))
  expect_equal(prepared$.is_male_x_missing, c(0, 0, 0, 0, 0, 0, 0, 0, 1))

  # They have no member contrast and do not change those of complete dyads.
  complete_only <- prepare_alone(alone_data()[1:6, ], role = gender)
  expect_equal(
    prepared$.member_contrast_male_x_male_arbitrary,
    c(complete_only$.member_contrast_male_x_male_arbitrary, 0, 0, 0)
  )

  compositions <- attr(prepared, "dyadMLM")$dyad_compositions
  expect_equal(
    compositions$dyad_type[match(
      c("singleton_male", "singleton_female", "male_x_missing"),
      compositions$composition
    )],
    c("singleton", "singleton", "partner_missing")
  )
})

test_that("people observed alone are labeled without a role column", {
  prepared <- prepare_alone()

  expect_equal(
    as.character(prepared$.composition[7:9]),
    c("singleton", "singleton", "missing_partner")
  )
  expect_equal(prepared$.is_singleton, c(0, 0, 0, 0, 0, 0, 1, 1, 0))
  expect_equal(prepared$.is_missing_partner, c(0, 0, 0, 0, 0, 0, 0, 0, 1))
  expect_equal(prepared$.is_exchangeable, c(1, 1, 1, 1, 1, 1, 0, 0, 0))

  complete_only <- prepare_alone(alone_data()[1:6, ])
  expect_equal(
    prepared$.member_contrast_arbitrary,
    c(complete_only$.member_contrast_arbitrary, 0, 0, 0)
  )
})

test_that("people observed alone do not prevent short column names", {
  female_male_only <- alone_data()[alone_data()$dyad_id != 3, ]
  prepared <- prepare_alone(female_male_only, role = gender)

  expect_true(all(
    c(".is_female", ".is_male", ".is_singleton_male", ".is_male_x_missing") %in%
      names(prepared)
  ))
})

test_that("keep_compositions accepts labels of people observed alone", {
  prepared <- prepare_alone(
    role = gender,
    keep_compositions = c("male-male", "singleton male", "male-missing")
  )

  expect_setequal(
    unique(as.character(prepared$.composition)),
    c("male_x_male", "singleton_male", "male_x_missing")
  )
})

test_that("people observed alone cannot be pooled or set exchangeable", {
  expect_error(
    prepare_alone(role = gender, pool_compositions = list(men = c("male-male", "male_x_missing"))),
    "`pool_compositions` cannot include people observed alone (male_x_missing).",
    fixed = TRUE
  )

  expect_error(
    prepare_alone(role = gender, set_exchangeable_compositions = "singleton_male"),
    "`set_exchangeable_compositions` cannot include people observed alone (singleton_male).",
    fixed = TRUE
  )

  # A label that is not in the data is named as such, not split into roles.
  expect_error(
    prepare_alone(role = gender, pool_compositions = list(men = c("male-male", "female_x_missing"))),
    paste0(
      "`pool_compositions` reference \"female_x_missing\" is not in the data. ",
      "Observed compositions: female_x_male, male_x_male. Labels of people ",
      "observed alone: singleton_male, singleton_female, male_x_missing."
    ),
    fixed = TRUE
  )

  # Reversed labels get the same message, not a misleading role pair.
  expect_error(
    prepare_alone(role = gender, pool_compositions = list(men = c("male-male", "male-singleton"))),
    "`pool_compositions` reference \"male-singleton\" is not in the data.",
    fixed = TRUE
  )

  # Rejected before the advice to add them to `keep_compositions`.
  expect_error(
    prepare_alone(
      role = gender,
      keep_compositions = c("male-male", "female-male"),
      pool_compositions = list(men = c("male-male", "male_x_missing"))
    ),
    "`pool_compositions` cannot include people observed alone (male_x_missing).",
    fixed = TRUE
  )
})

test_that("a reference matching a dyad and people observed alone is ambiguous", {
  # Roles "singleton" and "twin": dyads singleton_x_twin and twins without a
  # partner (singleton_twin).
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2, 3, 4, 5, 5),
    person_id = 1:8,
    kind = c("singleton", "twin", "singleton", "twin", "twin", "twin", "twin", "twin"),
    partnered = c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE, TRUE)
  )

  expect_error(
    prepare_alone(data, role = kind, keep_compositions = "singleton-twin"),
    "reference \"singleton-twin\" matches both singleton_x_twin and singleton_twin",
    fixed = TRUE
  )
  prepared <- prepare_alone(data, role = kind, keep_compositions = c("twin-singleton", "twin-twin"))
  expect_setequal(as.character(prepared$.composition), c("singleton_x_twin", "twin_x_twin"))
})

test_that("indicators of people observed alone are listed with cleaned names", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2, 3, 4),
    person_id = 1:6,
    role = "Partner A",
    partnered = c(TRUE, TRUE, TRUE, TRUE, FALSE, TRUE)
  )
  prepared <- prepare_alone(data, role = role)
  patterns <- dyad_generated_columns(attr(prepared, "dyadMLM"))$column_pattern
  expect_true(all(c(".is_singleton_Partner_A", ".is_Partner_A_x_missing") %in% patterns))
  expect_false(".is_{role}" %in% patterns)
})

test_that("roles named like labels of people observed alone still match", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2, 3, 3),
    person_id = 1:6,
    kind = c("singleton", "zebra", "singleton", "zebra", "zebra", "zebra")
  )
  for (reference in c("singleton-zebra", "zebra-singleton", "singleton_x_zebra")) {
    prepared <- prepare_dyad_data(
      data, dyad = dyad_id, member = person_id, role = kind,
      keep_compositions = reference, seed = 123
    )
    expect_equal(unique(as.character(prepared$.composition)), "singleton_x_zebra")
  }
})

test_that("different groups cannot get the same label", {
  # Role "singleton" with a missing partner and role "x_missing" without a
  # partner would both become "singleton_x_missing".
  data <- alone_data()
  data$gender[7:9] <- c("x_missing", "female", "singleton")
  data$partnered[9] <- TRUE

  expect_error(
    prepare_alone(data, role = gender),
    "Different groups would get the same label: singleton_x_missing.",
    fixed = TRUE
  )
})

test_that("exact labels win over labels with other separators", {
  data <- alone_data()
  data$gender[8] <- "x_male"
  data$partnered[8] <- FALSE

  # Both "singleton_male" and "singleton_x_male" normalize to the same alias.
  prepared <- prepare_alone(data, role = gender, keep_compositions = c("female-male", "singleton_male"))
  expect_setequal(
    unique(as.character(prepared$.composition)),
    c("female_x_male", "singleton_male")
  )

  expect_error(
    prepare_alone(data, role = gender, keep_compositions = "singleton male"),
    "matches several labels of people observed alone",
    fixed = TRUE
  )
})

test_that("a dyad column named like a temporary summary still works", {
  data <- dplyr::rename(alone_data(), role = dyad_id)

  prepared <- prepare_dyad_data(
    data, dyad = role, member = person_id, partner_exists = partnered, seed = 123
  )
  expect_equal(as.character(prepared$.composition[7]), "singleton")
})

test_that("labels of people observed alone do not clash with composition labels", {
  # A complete "singleton"-"zebra" dyad has the label "singleton_x_zebra",
  # which also looks like "singleton_" plus role "x_zebra". The exact
  # composition label wins.
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2, 3),
    person_id = 1:5,
    gender = c("singleton", "zebra", "singleton", "zebra", "zebra"),
    partnered = c(TRUE, TRUE, TRUE, TRUE, FALSE)
  )
  prepared <- prepare_alone(data, role = gender, keep_compositions = "singleton_x_zebra")
  expect_equal(unique(as.character(prepared$.composition)), "singleton_x_zebra")

  # The dyad member with role "singleton" gets the indicator
  # "singleton_x_zebra_singleton". So would a person observed alone with role
  # "x_zebra_singleton".
  data$gender[5] <- "x_zebra_singleton"
  expect_error(
    prepare_alone(data, role = gender),
    "Different groups would get the same label: singleton_x_zebra_singleton.",
    fixed = TRUE
  )
})
