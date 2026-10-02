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

composition_of <- function(prepared, dyad) {
  as.character(prepared$.composition[prepared$dyad_id == dyad])
}

test_that("people observed alone get their own labels and indicators", {
  prepared <- prepare_alone(role = gender)

  expect_equal(composition_of(prepared, 4), "singleton_male")
  expect_equal(composition_of(prepared, 5), "singleton_female")
  expect_equal(composition_of(prepared, 6), "male_x_missing")
  expect_equal(prepared$.is_singleton_male, c(0, 0, 0, 0, 0, 0, 1, 0, 0))
  expect_equal(prepared$.is_singleton_female, c(0, 0, 0, 0, 0, 0, 0, 1, 0))
  expect_equal(prepared$.is_male_x_missing, c(0, 0, 0, 0, 0, 0, 0, 0, 1))

  # They have no member contrast.
  expect_equal(prepared$.member_contrast_male_x_male_arbitrary[7:9], c(0, 0, 0))

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

  expect_equal(composition_of(prepared, 4), "singleton")
  expect_equal(composition_of(prepared, 6), "missing_partner")
  expect_equal(prepared$.is_singleton, c(0, 0, 0, 0, 0, 0, 1, 1, 0))
  expect_equal(prepared$.is_missing_partner, c(0, 0, 0, 0, 0, 0, 0, 0, 1))
  expect_equal(prepared$.is_exchangeable, c(1, 1, 1, 1, 1, 1, 0, 0, 0))
  expect_equal(prepared$.member_contrast_arbitrary[7:9], c(0, 0, 0))
})

test_that("people observed alone do not change complete dyads' contrasts", {
  complete_only <- alone_data()[1:6, ]

  without_alone <- prepare_alone(complete_only, role = gender)
  with_alone <- prepare_alone(role = gender)
  expect_equal(
    with_alone$.member_contrast_male_x_male_arbitrary[1:6],
    without_alone$.member_contrast_male_x_male_arbitrary
  )

  without_alone <- prepare_alone(complete_only)
  with_alone <- prepare_alone()
  expect_equal(
    with_alone$.member_contrast_arbitrary[1:6],
    without_alone$.member_contrast_arbitrary
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
    prepare_alone(
      role = gender,
      pool_compositions = list(men = c("male-male", "male_x_missing"))
    ),
    "`pool_compositions` cannot include people observed alone (male_x_missing).",
    fixed = TRUE
  )

  expect_error(
    prepare_alone(role = gender, set_exchangeable_compositions = "singleton_male"),
    "`set_exchangeable_compositions` cannot include people observed alone (singleton_male).",
    fixed = TRUE
  )
})

test_that("different groups cannot get the same label", {
  # Role "singleton" with a missing partner and role "x_missing" without a
  # partner would both become "singleton_x_missing".
  data <- alone_data()
  data$gender[7:9] <- c("x_missing", "female", "singleton")
  data$partnered[9] <- TRUE

  expect_error(
    prepare_alone(data, role = gender),
    "Different groups would get the same composition label: singleton_x_missing.",
    fixed = TRUE
  )
})

test_that("exact labels win over labels with other separators", {
  data <- alone_data()
  data$gender[8] <- "x_male"
  data$partnered[8] <- FALSE

  # Both "singleton_male" and "singleton_x_male" normalize to the same alias.
  prepared <- prepare_alone(
    data,
    role = gender,
    keep_compositions = c("female-male", "singleton_male")
  )
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
    data,
    dyad = role,
    member = person_id,
    partner_exists = partnered,
    seed = 123
  )
  expect_equal(as.character(prepared$.composition[7]), "singleton")
})
