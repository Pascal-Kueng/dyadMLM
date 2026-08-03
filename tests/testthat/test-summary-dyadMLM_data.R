test_that("dyadMLM summary describes structure and summarizes all columns", {
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
  returned_names <- trimws(colnames(returned))

  expect_true(any(grepl("# Summary of dyadMLM data", printed, fixed = TRUE)))
  expect_true(any(grepl("# Column summaries:", printed, fixed = TRUE)))
  expect_true("score" %in% returned_names)
  generated_columns <- dyad_generated_columns(attr(result, "dyadMLM"))$column
  expect_true(all(generated_columns %in% returned_names))
  expect_false("include_generated" %in% names(formals(summary.dyadMLM_data)))
})
