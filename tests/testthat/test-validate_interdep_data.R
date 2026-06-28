test_that("validate_interdep_data returns an interdep tibble", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c(1, 2, 3, 4),
    x = 1:4
  )

  result <- validate_interdep_data(data, group = dyad_id, member = person_id)

  expect_s3_class(result, "interdep_data")
  expect_s3_class(result, "tbl_df")
  expect_equal(result$dyad_id, c(1, 1, 2, 2))
  expect_equal(result$person_id, c(1, 2, 3, 4))
  expect_equal(result$x, 1:4)
})

test_that("validate_interdep_data rejects non-data-frame input", {
  expect_error(
    validate_interdep_data(1:3, group = dyad_id, member = person_id),
    "`data` must be a data frame or tibble.",
    fixed = TRUE
  )
})

test_that("validate_interdep_data rejects duplicate members within group-time", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2),
    person_id = c("A", "B", "A", "A", "C", "D"),
    time = c(1, 1, 2, 2, 1, 1)
  )

  expect_error(
    validate_interdep_data(data, group = dyad_id, member = person_id, time = time),
    "Each `member` must appear at most once per `group`-`time` combination.",
    fixed = TRUE
  )
})

test_that("validate_interdep_data rejects groups without two unique members", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "A", "C", "D")
  )

  expect_error(
    validate_interdep_data(data, group = dyad_id, member = person_id),
    "Each `group` must contain exactly two unique members.",
    fixed = TRUE
  )
})

test_that("validate_interdep_data rejects cross-sectional groups with more than two rows", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 2, 2),
    person_id = c("A", "B", "A", "C", "D")
  )

  expect_error(
    validate_interdep_data(data, group = dyad_id, member = person_id),
    "Each `group` must contain exactly two rows. For longitudinal data specify `time`.",
    fixed = TRUE
  )
})

test_that("validate_interdep_data allows one missing member within group-time", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 2, 2, 2),
    person_id = c("A", "B", "A", "C", "D", "C"),
    time = c(1, 1, 2, 1, 1, 2)
  )

  result <- validate_interdep_data(data, group = dyad_id, member = person_id, time = time)

  expect_s3_class(result, "interdep_data")
  expect_equal(nrow(result), 6)
})
