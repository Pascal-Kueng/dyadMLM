test_that("interdep data prints a header before the tibble", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2),
    person_id = c(1, 2, 3, 4),
    role = c("female", "male", "female", "female")
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role
  )

  printed <- capture.output(print(result))

  expect_true(any(grepl("# interdep data", printed, fixed = TRUE)))
  expect_true(any(grepl("# A tibble:", printed, fixed = TRUE)))
})

test_that("interdep data prints dropped incomplete dyads", {
  data <- tibble::tibble(
    dyad_id = c(1, 2, 2, 3, 3),
    person_id = c("A", "B", "C", "D", "E")
  )

  expect_message(
    result <- prepare_interdep_data(
      data,
      group = dyad_id,
      member = person_id,
      incomplete_dyads = "drop",
      seed = 123
    ),
    "Dropped 1 incomplete dyad, with ID: 1.",
    fixed = TRUE
  )

  printed <- capture.output(print(result))

  expect_true(any(grepl("# Dropped incomplete dyads:", printed, fixed = TRUE)))
  expect_true(any(grepl("with ID: 1", printed, fixed = TRUE)))
})
