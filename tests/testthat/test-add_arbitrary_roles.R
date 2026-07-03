arbitrary_roles_test_data <- function() {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  validated <- validate_interdep_data(data, group = dyad_id, member = person_id)
  infer_dyad_compositions(validated)
}

test_that("add_arbitrary_roles adds role indicators and diff contrast", {
  data <- arbitrary_roles_test_data()

  result <- add_arbitrary_roles(data, seed = 123)

  expect_true(".i_arbitrary_role" %in% names(result))
  expect_true(".i_is_arbitrary_role_1" %in% names(result))
  expect_true(".i_is_arbitrary_role_2" %in% names(result))
  expect_true(".i_diff" %in% names(result))

  expect_equal(
    sort(unique(result$.i_arbitrary_role)),
    c("arbitrary_role_1", "arbitrary_role_2")
  )
  expect_equal(
    result$.i_is_arbitrary_role_1 + result$.i_is_arbitrary_role_2,
    rep(1, nrow(result))
  )
  expect_equal(result$.i_diff[result$.i_arbitrary_role == "arbitrary_role_1"], rep(-1, 2))
  expect_equal(result$.i_diff[result$.i_arbitrary_role == "arbitrary_role_2"], rep(1, 2))

  role_counts <- dplyr::count(
    result,
    .data$dyad_id,
    .data$.i_arbitrary_role
  )
  expect_equal(role_counts$n, rep(1L, 4))
})

test_that("add_arbitrary_roles is stable across longitudinal rows", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    time = c(1, 1, 2, 2, 1, 1, 2, 2)
  )

  validated <- validate_interdep_data(data, group = dyad_id, member = person_id, time = time)
  result <- add_arbitrary_roles(infer_dyad_compositions(validated), seed = 123)

  member_roles <- unique(result[c("dyad_id", "person_id", ".i_arbitrary_role")])

  expect_equal(nrow(member_roles), 4)
  expect_equal(
    dplyr::count(member_roles, .data$dyad_id, .data$.i_arbitrary_role)$n,
    rep(1L, 4)
  )
})

test_that("add_arbitrary_roles zeros model columns for distinguishable dyads", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male")
  )

  validated <- validate_interdep_data(data, group = dyad_id, member = person_id, role = role)
  result <- add_arbitrary_roles(infer_dyad_compositions(validated), seed = 123)

  expect_equal(
    sort(unique(result$.i_arbitrary_role)),
    c("arbitrary_role_1", "arbitrary_role_2")
  )
  expect_equal(result$.i_is_arbitrary_role_1, rep(0, 4))
  expect_equal(result$.i_is_arbitrary_role_2, rep(0, 4))
  expect_equal(result$.i_diff, rep(0, 4))
})

test_that("add_arbitrary_roles is active only for exchangeable dyads", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "female")
  )

  validated <- validate_interdep_data(data, group = dyad_id, member = person_id, role = role)
  result <- add_arbitrary_roles(infer_dyad_compositions(validated), seed = 123)

  distinguishable_rows <- result$dyad_id == 1
  arbitrary_rows <- result$dyad_id == 2

  expect_equal(result$.i_is_arbitrary_role_1[distinguishable_rows], c(0, 0))
  expect_equal(result$.i_is_arbitrary_role_2[distinguishable_rows], c(0, 0))
  expect_equal(result$.i_diff[distinguishable_rows], c(0, 0))

  expect_equal(
    result$.i_is_arbitrary_role_1[arbitrary_rows] +
      result$.i_is_arbitrary_role_2[arbitrary_rows],
    c(1, 1)
  )
  expect_true(all(result$.i_diff[arbitrary_rows] %in% c(-1, 1)))
})

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
