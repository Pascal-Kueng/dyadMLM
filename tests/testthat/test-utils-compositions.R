test_that("canonical_composition creates sorted composition labels", {
  expect_equal(
    canonical_composition(c("male", "female")),
    "female__male"
  )

  expect_equal(
    canonical_composition(c(2, 1)),
    "1__2"
  )
})

test_that("canonical_composition supports a custom separator", {
  expect_equal(
    canonical_composition(c("male", "female"), sep = " / "),
    "female / male"
  )
})

test_that("composition_role_label appends roles to composition labels", {
  expect_equal(
    composition_role_label("female__male", "female"),
    "female__male__female"
  )

  expect_equal(
    composition_role_label(
      c("female__male", "female__male"),
      c("female", "male")
    ),
    c("female__male__female", "female__male__male")
  )
})

test_that("composition_role_label supports a custom separator", {
  expect_equal(
    composition_role_label("female / male", "female", sep = " / "),
    "female / male / female"
  )
})
