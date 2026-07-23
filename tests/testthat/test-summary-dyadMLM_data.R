test_that("dyadMLM summary describes structure and summarizes original columns", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2),
    person_id = 1:4,
    score = c(1, NA, 3, 4)
  )
  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    seed = 123
  )

  printed <- capture.output(returned <- summary(result))

  expect_true(any(grepl("# Summary of dyadMLM data", printed, fixed = TRUE)))
  expect_true(any(grepl("# Generated columns:", printed, fixed = TRUE)))
  expect_true(any(grepl("print(result)", printed, fixed = TRUE)))
  expect_true(any(grepl(
    "summary(result, include_generated = TRUE)",
    printed,
    fixed = TRUE
  )))
  expect_true(any(grepl("# Original-column summaries:", printed, fixed = TRUE)))
  expect_true("score" %in% trimws(colnames(returned)))
  expect_false(any(startsWith(trimws(colnames(returned)), ".dy_")))
})

test_that("dyadMLM summary can include generated columns", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 2),
    person_id = 1:4
  )
  result <- prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    seed = 123
  )

  printed <- capture.output(
    returned <- summary(result, include_generated = TRUE)
  )

  expect_true(any(grepl("# All-column summaries:", printed, fixed = TRUE)))
  expect_false(any(grepl("include_generated = TRUE", printed, fixed = TRUE)))
  expect_true(any(startsWith(trimws(colnames(returned)), ".dy_")))
  expect_error(
    summary(result, include_generated = NA),
    "`include_generated` must be `TRUE` or `FALSE`",
    fixed = TRUE
  )
})
