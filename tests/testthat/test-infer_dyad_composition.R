test_that("infer_dyad_composition counts role compositions", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2, 3, 3, 4, 4),
    person_id = c("A", "B", "C", "D", "E", "F", "G", "H"),
    role = c("female", "male", "female", "male", "female", "female", "male", "male")
  )

  validated <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role
  )

  result <- infer_dyad_composition(validated)
  result <- result[order(result$composition), ]

  expect_equal(
    result$composition,
    c("female-female", "female-male", "male-male")
  )
  expect_equal(
    result$dyad_type,
    c("exchangeable", "distinguishable", "exchangeable")
  )
  expect_equal(result$n_dyads, c(1L, 2L, 1L))
})

test_that("infer_dyad_composition is not inflated by longitudinal rows", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    role = c("female", "male", "female", "male", "female", "female", "female", "female"),
    time = c(1, 1, 2, 2, 1, 1, 2, 2)
  )

  validated <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role,
    time = time
  )

  result <- infer_dyad_composition(validated)
  result <- result[order(result$composition), ]

  expect_equal(result$composition, c("female-female", "female-male"))
  expect_equal(result$dyad_type, c("exchangeable", "distinguishable"))
  expect_equal(result$n_dyads, c(1L, 1L))
})

test_that("infer_dyad_composition treats missing role metadata as unclassified", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  validated <- validate_interdep_data(data, group = dyad_id, member = person_id)

  expect_equal(
    infer_dyad_composition(validated),
    tibble::tibble(
      composition = "unclassified",
      dyad_type = "exchangeable",
      n_dyads = 2L
    )
  )
})
