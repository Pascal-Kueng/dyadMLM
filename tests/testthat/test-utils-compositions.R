test_that("canonical_composition creates sorted composition labels", {
  expect_equal(
    canonical_composition(c("male", "female")),
    "female_x_male"
  )

  expect_equal(
    canonical_composition(c(2, 1)),
    "1_x_2"
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
    composition_role_label("female_x_male", "female"),
    "female_x_male_female"
  )

  expect_equal(
    composition_role_label(
      c("female_x_male", "female_x_male"),
      c("female", "male")
    ),
    c("female_x_male_female", "female_x_male_male")
  )
})

test_that("composition_role_label supports a custom separator", {
  expect_equal(
    composition_role_label("female / male", "female", sep = " / "),
    "female / male / female"
  )
})

test_that("make_interdep_suffixes sanitizes labels and rejects collisions", {
  expect_equal(
    make_interdep_suffixes(c("female partner", "male-partner")),
    c("female partner" = "female_partner", "male-partner" = "male_partner")
  )

  expect_error(
    make_interdep_suffixes(c("female partner", "female-partner")),
    "same generated column name",
    fixed = TRUE
  )
})
