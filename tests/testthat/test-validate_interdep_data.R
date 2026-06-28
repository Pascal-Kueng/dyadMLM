test_that("validate_interdep_data returns an interdep tibble", {
  data <- data.frame(x = 1:3, y = c("a", "b", "c"))

  result <- validate_interdep_data(data)

  expect_s3_class(result, "interdep_data")
  expect_s3_class(result, "tbl_df")
  expect_equal(result$x, 1:3)
  expect_equal(result$y, c("a", "b", "c"))
})

test_that("validate_interdep_data rejects non-data-frame input", {
  expect_error(
    validate_interdep_data(1:3),
    "`data` must be a data frame or tibble.",
    fixed = TRUE
  )
})
