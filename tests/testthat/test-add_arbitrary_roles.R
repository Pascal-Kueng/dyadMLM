arbitrary_roles_test_data <- function() {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  validated <- validate_interdep_data(data, group = dyad_id, member = person_id)
  infer_dyad_compositions(validated)
}

test_that("add_arbitrary_roles restores an existing RNG state", {
  old_seed_exists <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (old_seed_exists) {
    old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  }

  on.exit({
    if (old_seed_exists) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)

  data <- arbitrary_roles_test_data()

  set.seed(99)
  expected <- sample.int(1000, 5)

  set.seed(99)
  invisible(add_arbitrary_roles(data, seed = 123))
  observed <- sample.int(1000, 5)

  expect_identical(observed, expected)
})

test_that("add_arbitrary_roles does not leave an RNG state behind", {
  old_seed_exists <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (old_seed_exists) {
    old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    rm(".Random.seed", envir = .GlobalEnv)
  }

  on.exit({
    if (old_seed_exists) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)

  data <- arbitrary_roles_test_data()

  invisible(add_arbitrary_roles(data, seed = 123))

  expect_false(exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
})
