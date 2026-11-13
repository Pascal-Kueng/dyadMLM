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

# Returns the first collation locale that this machine can switch to and that
# sorts mixed-case labels differently from the C locale, or NULL if none exists.
find_non_c_collation <- function() {
  candidates <- c(
    "en_US.UTF-8", "en_US.utf8", "en_GB.UTF-8", "de_DE.UTF-8",
    "English_United States.1252", "en-US"
  )
  for (locale in candidates) {
    sorted <- suppressWarnings(withr::with_collate(
      locale,
      if (identical(Sys.getlocale("LC_COLLATE"), locale)) {
        sort(c("Male", "female"))
      } else {
        NULL
      }
    ))
    if (identical(sorted, c("female", "Male"))) {
      return(locale)
    }
  }
  NULL
}

test_that("canonical_composition sorts mixed-case roles ignoring case", {
  expect_equal(sort_dyad_labels(c("male", "Male", "female")), c("female", "Male", "male"))
  expect_equal(
    withr::with_collate("C", canonical_composition(c("Male", "female"))),
    "female_x_Male"
  )

  locale <- find_non_c_collation()
  skip_if(is.null(locale), "No non-C collation locale is available.")

  expect_equal(
    withr::with_collate(locale, canonical_composition(c("Male", "female"))),
    "female_x_Male"
  )
})

test_that("generated labels do not depend on the collation locale (#174)", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2, 3, 3, 4, 4),
    person_id = c("A", "B", "C", "D", "E", "F", "G", "H"),
    role = c("Male", "female", "female", "Male", "female", "female",
             "Male", "Male")
  )

  prepare_in <- function(locale) {
    withr::with_collate(locale, {
      validated <- validate_dyad_data(
        data,
        dyad = dyad_id,
        member = person_id,
        role = role
      )
      infer_dyad_compositions(validated, seed = 123)
    })
  }

  result_c <- prepare_in("C")
  expect_equal(
    levels(result_c$.composition),
    c("female_x_female", "female_x_Male", "Male_x_Male")
  )
  expect_true(".is_female_x_Male_Male" %in% names(result_c))
  expect_true(".is_female_x_Male_female" %in% names(result_c))
  expect_false(any(grepl("Male_x_female", names(result_c), fixed = TRUE)))

  locale <- find_non_c_collation()
  skip_if(is.null(locale), "No non-C collation locale is available.")

  result_other <- prepare_in(locale)
  expect_identical(names(result_other), names(result_c))
  expect_identical(
    levels(result_other$.composition),
    levels(result_c$.composition)
  )
  expect_identical(
    levels(result_other$.composition_role),
    levels(result_c$.composition_role)
  )
  expect_identical(
    as.character(result_other$.composition),
    as.character(result_c$.composition)
  )
})
