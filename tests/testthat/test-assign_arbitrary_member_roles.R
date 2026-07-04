test_that("assign_arbitrary_member_roles returns one role per member", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    time = c(1, 1, 2, 2, 1, 1, 2, 2)
  )

  result <- assign_arbitrary_member_roles(
    data,
    group_name = "dyad_id",
    member_name = "person_id",
    seed = 123
  )

  expect_equal(nrow(result), 4)
  expect_equal(
    sort(unique(result[[interdep_arbitrary_role_col]])),
    c("arbitrary_1", "arbitrary_2")
  )
  expect_equal(
    dplyr::count(result, .data$dyad_id, .data[[interdep_arbitrary_role_col]])$n,
    rep(1L, 4)
  )
})

test_that("assign_arbitrary_member_roles restores an existing RNG state", {
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

  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  set.seed(99)
  expected <- sample.int(1000, 5)

  set.seed(99)
  invisible(assign_arbitrary_member_roles(data, "dyad_id", "person_id", seed = 123))
  observed <- sample.int(1000, 5)

  expect_identical(observed, expected)
})

test_that("assign_arbitrary_member_roles does not leave an RNG state behind", {
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

  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  invisible(assign_arbitrary_member_roles(data, "dyad_id", "person_id", seed = 123))

  expect_false(exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
})
