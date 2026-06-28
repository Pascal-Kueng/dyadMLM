test_that("validate_interdep_data accepts a data frame", {
  data <- data.frame(x = 1:3, y = c("a", "b", "c"))

  result <- validate_interdep_data(data)

  expect_s3_class(result, "interdep_data")
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 3)
  expect_equal(names(result), c("x", "y"))
})

test_that("validate_interdep_data accepts a tibble", {
  data <- tibble::tibble(x = 1:3)

  result <- validate_interdep_data(data)

  expect_s3_class(result, "interdep_data")
  expect_s3_class(result, "tbl_df")
})

test_that("validate_interdep_data rejects non-data-frame input", {
  expect_error(
    validate_interdep_data(1:3),
    "`data` must be a data frame or tibble.",
    fixed = TRUE
  )
})
