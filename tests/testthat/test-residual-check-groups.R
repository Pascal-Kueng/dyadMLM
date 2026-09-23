residual_check_groups <- function(frame, dyad = NULL, role = NULL, member = NULL,
                                  data = NULL) {
  build_residual_check_groups(frame, rlang::enquo(dyad), rlang::enquo(role),
                              rlang::enquo(member), data)
}

test_that("omitting role retains every fitted observation without requiring IDs", {
  frame <- data.frame(dyad = c(1, 1, 2, NA), role = c("A", "B", "A", NA))
  groups <- residual_check_groups(frame)
  expect_equal(groups, list(list(label = "All observations",
                                rows = list(Pooled = 1:4), n_dyads = NULL)))
  expect_equal(residual_check_groups(frame, dyad)[[1]]$n_dyads, 2)
  expect_equal(residual_check_groups(frame, dyad)[[1]]$rows$Pooled, 1:4)
})

test_that("compositions use one pooled or two role columns in role order", {
  frame <- data.frame(
    dyad = rep(1:4, each = 2),
    role = factor(c("A", "B", "A", "A", "B", "B", "B", "A"),
                  levels = c("B", "A", "unused"))
  )
  groups <- residual_check_groups(frame, dyad, role)
  expect_equal(vapply(groups, `[[`, "", "label"), c("B - B", "B - A", "A - A"))
  expect_equal(groups[[1]]$rows, list(Pooled = 5:6))
  expect_equal(groups[[2]]$rows, list(B = c(2L, 7L), A = c(1L, 8L)))
  expect_equal(groups[[3]]$rows, list(Pooled = 3:4))
  expect_equal(vapply(groups, `[[`, 0L, "n_dyads"), c(1L, 2L, 1L))
  expect_equal(residual_check_groups(frame, "dyad", "role"), groups)
})

test_that("an original roster keeps lone responses with known compositions", {
  data <- data.frame(dyad = rep(1:3, each = 2),
                     role = c("A", "B", "A", "A", "B", "B"),
                     y = c(1, NA, NA, 4, 5, NA))
  frame <- data[c(1, 4, 5), ]
  groups <- residual_check_groups(frame, dyad, role, data = data)
  expect_equal(vapply(groups, `[[`, "", "label"), c("A - A", "A - B", "B - B"))
  expect_equal(groups[[1]]$rows, list(Pooled = 2L))
  expect_equal(groups[[2]]$rows, list(A = 1L, B = integer()))
  expect_equal(groups[[3]]$rows, list(Pooled = 3L))
  expect_equal(vapply(groups, `[[`, 0L, "n_dyads"), rep(1L, 3))
  expect_error(residual_check_groups(frame, dyad, role), "No fitted observations")
})

test_that("member IDs identify compositions across uneven repeated observations", {
  data <- data.frame(
    dyad = c(rep(1, 5), rep(2, 3)), member = c("a", "a", "a", "b", "b", "a", "a", "b"),
    role = c("A", NA, "A", "B", "B", "A", "A", "A"), y = seq_len(8)
  )
  frame <- data[c(2, 3, 5, 6, 7), ]
  groups <- residual_check_groups(frame, dyad, role, member, data)
  expect_equal(groups[[1]]$rows, list(Pooled = c(4L, 5L)))
  expect_equal(groups[[2]]$rows, list(A = c(1L, 2L), B = 3L))
  expect_equal(vapply(groups, `[[`, 0L, "n_dyads"), c(1L, 1L))
  expect_error(residual_check_groups(frame, dyad, role, data = data), "Supply `member`")

  changed_role <- data
  changed_role$role[2] <- "B"
  expect_error(residual_check_groups(changed_role, dyad, role, member), "same role")
  third_member <- data
  third_member$member[3] <- "c"
  expect_error(residual_check_groups(third_member, dyad, role, member), "at most two")
})

test_that("unknown compositions omit only their fitted rows", {
  frame <- data.frame(dyad = c(1, 1, 2, 3, 3, NA),
                      member = c(1, 2, 1, 1, 2, 1),
                      role = c("A", "B", "A", "A", NA, "A"))
  expect_warning(groups <- residual_check_groups(frame, dyad, role, member),
                 "4 fitted observations omitted")
  expect_equal(groups[[1]]$rows, list(A = 1L, B = 2L))
  expect_equal(groups[[1]]$n_dyads, 1L)
})

test_that("explicit NA factor levels remain missing IDs and roles", {
  frame <- data.frame(
    dyad = factor(c(1, 1, 2, 2, 3, 3, NA, NA), exclude = NULL),
    member = factor(c("a", "b", "a", NA, "a", "b", "a", "b"), exclude = NULL),
    role = factor(c("A", "B", "A", "B", "A", NA, "A", "B"), exclude = NULL)
  )
  expect_warning(groups <- residual_check_groups(frame, dyad, role, member),
                 "6 fitted observations omitted")
  expect_equal(groups[[1]]$rows, list(A = 1L, B = 2L))
  expect_equal(groups[[1]]$n_dyads, 1L)
})

test_that("original data and column arguments preserve fitted-row alignment", {
  data <- data.frame(dyad = c(1, 1, 2, 2), role = c("A", "B", "A", "B"), y = 1:4)
  frame <- data[c(1, 3, 4), "y", drop = FALSE]
  expect_equal(residual_check_groups(frame, dyad, role, data = data)[[1]]$rows,
               list(A = c(1L, 2L), B = 3L))
  changed <- data
  changed$y[1] <- 99
  expect_error(residual_check_groups(frame, dyad, role, data = changed),
               "does not match the fitted rows")
  row.names(changed) <- letters[1:4]
  expect_error(residual_check_groups(frame, dyad, role, data = changed),
               "Could not match the fitted rows")
  expect_error(residual_check_groups(data, role = role), "`dyad` is required")
  expect_error(residual_check_groups(data, data$dyad, role), "must be a column name")
  expect_error(residual_check_groups(data, dyad, unknown), "was not found")
  expect_error(residual_check_groups(frame, dyad, role, data = 1), "data frame")
})

test_that("roster checks concern only dyads represented in the fit", {
  data <- data.frame(dyad = c(1, 1, 2, 2, 2), member = c(1, 2, 1, 2, 3),
                     role = c("A", "B", "C", "D", "E"))
  expect_equal(residual_check_groups(data[1:2, ], dyad, role, data = data)[[1]]$rows,
               list(A = 1L, B = 2L))
  expect_equal(residual_check_groups(data[1:2, ], dyad, role, member, data)[[1]]$rows,
               list(A = 1L, B = 2L))
})
