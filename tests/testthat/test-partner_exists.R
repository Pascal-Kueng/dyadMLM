# Two complete dyads and two people observed alone (dyads 3 and 4).
partner_data <- function() {
  tibble::tibble(
    dyad_id = c(1, 1, 2, 2, 3, 4),
    person_id = 1:6,
    partnered = c(TRUE, TRUE, TRUE, TRUE, FALSE, TRUE),
    single = !c(TRUE, TRUE, TRUE, TRUE, FALSE, TRUE)
  )
}

validate_partner_exists_data <- function(data, ...) {
  validate_dyad_data(data, dyad = dyad_id, member = person_id, ...)
}

stored_status <- function(validated) {
  validated[[dyad_partner_exists_col]]
}

test_that("partner_exists = NULL keeps the current one-person dyad error", {
  expect_error(
    validate_partner_exists_data(partner_data()),
    "dyads with only one person"
  )
})

test_that("a constant partner_exists describes people observed alone", {
  validated <- validate_partner_exists_data(partner_data(), partner_exists = FALSE)

  expect_equal(nrow(validated), 6L)
  expect_equal(stored_status(validated), c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE))
  expect_equal(attr(validated, "dyadMLM")$partner_exists, "FALSE")
  expect_length(attr(validated, "dyadMLM")$dropped_incomplete_dyads, 0L)

  validated <- validate_partner_exists_data(partner_data(), partner_exists = TRUE)
  expect_true(all(stored_status(validated)))
})

test_that("partner_exists accepts a column, an expression, or 1/0 values", {
  expected <- partner_data()$partnered

  by_column <- validate_partner_exists_data(partner_data(), partner_exists = partnered)
  by_quoted_name <- validate_partner_exists_data(partner_data(), partner_exists = "partnered")
  by_expression <- validate_partner_exists_data(partner_data(), partner_exists = !single)
  by_numbers <- validate_partner_exists_data(
    dplyr::mutate(partner_data(), partnered = as.numeric(partnered)),
    partner_exists = partnered
  )

  expect_equal(stored_status(by_column), expected)
  expect_equal(stored_status(by_quoted_name), expected)
  # Stored without quotes, as for a column.
  expect_equal(attr(by_quoted_name, "dyadMLM")$partner_exists, "partnered")
  expect_equal(stored_status(by_expression), expected)
  expect_equal(stored_status(by_numbers), expected)
})

test_that("partner_exists rejects invalid values", {
  invalid_values <- list(
    unknown_name = "not_a_column",
    missing_constant = NA,
    other_numbers = c(0, 1, 2, 1, 0, 1),
    text_numbers = c("1", "1", "1", "1", "0", "1"),
    wrong_length = c(TRUE, FALSE)
  )

  for (value in invalid_values) {
    expect_error(
      validate_partner_exists_data(partner_data(), partner_exists = value),
      "`partner_exists` must be `TRUE`, `FALSE`, or a column or expression",
      fixed = TRUE
    )
  }
})

test_that("partner_exists rejects missing values per row", {
  data <- partner_data()
  data$partnered[5] <- NA

  expect_error(
    validate_partner_exists_data(data, partner_exists = partnered),
    "`partner_exists` is missing in 1 row(s), in 1 dyad, with ID: 3.",
    fixed = TRUE
  )
})

test_that("partner_exists cannot be combined with dropping incomplete dyads", {
  expect_error(
    validate_partner_exists_data(partner_data(), partner_exists = FALSE, incomplete_dyads = "drop"),
    "`partner_exists` keeps everyone observed alone, so it cannot be combined",
    fixed = TRUE
  )
})

test_that("both members must agree on partner status at the same occasion", {
  diary <- tibble::tibble(
    dyad_id = c(1, 1, 1, 1, 1, 2, 2),
    person_id = c(1, 2, 1, 2, 1, 3, 4),
    day = c(1, 1, 2, 2, 3, 1, 1),
    together = c(TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE)
  )

  expect_error(
    validate_partner_exists_data(diary, time = day, partner_exists = together),
    "in dyad(s): 1 (day 2).",
    fixed = TRUE
  )

  # Both members FALSE (e.g., former partners who both take part) and FALSE
  # without a partner row at that occasion are both allowed.
  diary$together[1:5] <- FALSE
  validated <- validate_partner_exists_data(diary, time = day, partner_exists = together)
  expect_equal(
    stored_status(validated),
    c(FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, TRUE)
  )
})

test_that("partner status must stay the same within a dyad over time", {
  # Dyad 1 stays together, dyad 2 lives alone, and dyad 3 has a partner who
  # never takes part.
  constant <- tibble::tibble(
    dyad_id = c(1, 1, 1, 1, 2, 2, 3, 3),
    person_id = c(1, 2, 1, 2, 3, 3, 4, 4),
    wave = c(1, 1, 2, 2, 1, 2, 1, 2),
    together = c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE, TRUE)
  )
  expect_no_error(validate_partner_exists_data(constant, time = wave, partner_exists = together))

  changes <- list(
    # Person 2 dies after wave 1.
    death = dplyr::mutate(constant[-4, ], together = c(TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, TRUE)),
    # Both keep taking part after separating.
    separation = dplyr::mutate(constant, together = c(TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, TRUE)),
    # Person 3 finds a partner who does not take part.
    formation = dplyr::mutate(constant, together = c(TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE))
  )
  changing_dyad <- c(death = 1, separation = 1, formation = 2)
  for (change in names(changes)) {
    expect_error(
      validate_partner_exists_data(changes[[change]], time = wave, partner_exists = together),
      paste0(
        "`partner_exists` changes over time in 1 dyad, with ID: ", changing_dyad[[change]],
        ". Changes in partner status within a dyad"
      ),
      fixed = TRUE
    )
  }
})

test_that("the role value \"missing\" is reserved when partner_exists is supplied", {
  data <- partner_data()
  data$gender <- c("female", "male", "female", "missing", "female", "male")

  expect_error(
    validate_partner_exists_data(data, role = gender, partner_exists = partnered),
    "`role` must not be \"missing\" when `partner_exists` is supplied",
    fixed = TRUE
  )
})

test_that("prepare_dyad_data passes partner_exists on and removes the status column", {
  complete <- partner_data()[1:4, ]
  prepared <- prepare_dyad_data(
    complete, dyad = dyad_id, member = person_id, partner_exists = partnered, seed = 123
  )

  expect_false(dyad_partner_exists_col %in% names(prepared))
  expect_equal(attr(prepared, "dyadMLM")$partner_exists, "partnered")
  expect_s3_class(prepared, "dyadMLM_data")
  expect_match(capture.output(print(prepared)), "partner_exists = partnered", fixed = TRUE, all = FALSE)
})
