test_that("validate_interdep_data returns an interdep tibble", {
  data <- data.frame(dyad_id = c(1, 1, 2, 2), x = 1:4)

  result <- validate_interdep_data(data, group = dyad_id)

  expect_s3_class(result, "interdep_data")
  expect_s3_class(result, "tbl_df")
  expect_equal(result$dyad_id, c(1, 1, 2, 2))
  expect_equal(result$x, 1:4)
})

test_that("validate_interdep_data rejects non-data-frame input", {
  expect_error(
    validate_interdep_data(1:3, group = dyad_id),
    "`data` must be a data frame or tibble.",
    fixed = TRUE
  )
})
