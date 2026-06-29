test_that("prepare_interdep_data returns validated data with dyad composition metadata", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2, 3, 3),
    person_id = c("A", "B", "C", "D", "E", "F"),
    role = c("female", "male", "female", "female", "male", "male")
  )

  result <- prepare_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role
  )

  expect_s3_class(result, "interdep_data")
  expect_s3_class(result, "tbl_df")

  meta <- attr(result, "interdep")
  expect_equal(meta$group, "dyad_id")
  expect_equal(meta$member, "person_id")
  expect_equal(meta$role, "role")
  expect_equal(meta$n_dyads, 3L)

  dyad_compositions <- meta$dyad_compositions
  dyad_compositions <- dyad_compositions[order(dyad_compositions$composition), ]

  expect_equal(
    dyad_compositions$composition,
    c("female-female", "female-male", "male-male")
  )
  expect_equal(
    dyad_compositions$dyad_type,
    c("exchangeable", "distinguishable", "exchangeable")
  )
  expect_equal(dyad_compositions$n_dyads, c(1L, 1L, 1L))
})

test_that("prepare_interdep_data treats data without role as unclassified exchangeable dyads", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  result <- prepare_interdep_data(data, group = dyad_id, member = person_id)

  expect_equal(
    attr(result, "interdep")$dyad_compositions,
    tibble::tibble(
      composition = "unclassified",
      dyad_type = "exchangeable",
      n_dyads = 2L
    )
  )
})
