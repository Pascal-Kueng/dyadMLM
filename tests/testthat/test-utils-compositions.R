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

test_that("make_dyad_suffixes sanitizes labels and rejects collisions", {
  expect_equal(
    make_dyad_suffixes(c("female partner", "male-partner")),
    c("female partner" = "female_partner", "male-partner" = "male_partner")
  )

  expect_error(
    make_dyad_suffixes(c("female partner", "female-partner")),
    "same generated column-name suffix",
    fixed = TRUE
  )
})

test_that("resolve_composition_references accepts supported composition aliases", {
  expect_equal(
    resolve_composition_references(
      references = c(
        "male-female",
        "female_male",
        " female   male ",
        "female_x_male",
        "older younger"
      ),
      observed_compositions = c("female_x_male", "older_x_younger"),
      arg_name = "set_exchangeable_compositions"
    ),
    c("female_x_male", "older_x_younger")
  )
})

test_that("resolve_composition_references uses the supplied argument name in errors", {
  expect_error(
    resolve_composition_references(
      references = list("female-male"),
      observed_compositions = "female_x_male",
      arg_name = "set_exchangeable_compositions"
    ),
    "`set_exchangeable_compositions` must be a character vector",
    fixed = TRUE
  )

  expect_error(
    resolve_composition_references(
      references = "female-female",
      observed_compositions = "female_x_male",
      arg_name = "pool_compositions"
    ),
    "`pool_compositions` contains unknown dyad composition(s): female_x_female",
    fixed = TRUE
  )
})

test_that("resolve_composition_references rejects empty references", {
  expect_error(
    resolve_composition_references(
      references = c("female-male", ""),
      observed_compositions = "female_x_male",
      arg_name = "set_exchangeable_compositions"
    ),
    "`set_exchangeable_compositions` must contain non-empty dyad composition references.",
    fixed = TRUE
  )
})
