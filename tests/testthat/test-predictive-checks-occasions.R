# Explicit series keep these checks independent of fitted-model convergence.
# Rows are ordered by dyad, member, and time, so each member's series is one
# column of matrix(responses, nrow = 4), with members a and b alternating.
occasion_check_simulations <- function() {
  frame <- expand.grid(
    time = 1:4, member = c("a", "b"), dyad = 1:4,
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  frame$role <- factor(frame$member, levels = c("a", "b"))
  signal <- c(
    1, 4, 2, 7, 2, 3, 8, 4,
    3, 8, 4, 6, 9, 6, 7, 13,
    10, 8, 13, 9, 4, 11, 7, 9,
    6, 13, 9, 12, 15, 10, 14, 18
  )
  predicted <- 0.3 * frame$dyad + 0.2 * frame$time +
    0.1 * (frame$member == "b") * frame$time^2
  row <- seq_along(signal)
  simulated_signal <- rbind(
    signal * 0.8 + sin(row),
    signal * 1.2 + cos(row / 2),
    signal + 2 * sin(row / 3)
  )
  structure(list(
    observed_response = signal + predicted,
    simulated_responses = sweep(simulated_signal, 2, predicted, "+"),
    predicted_response = predicted,
    model_frame = frame
  ), class = c("dyadMLM_response_simulations", "list"), dyadMLM = list(
    backend = "glmmTMB", family = "gaussian", link = "identity",
    reference = "plug-in predictive", random_effects = "new",
    parameter_uncertainty = "excluded", seed = 123L
  ))
}

keep_simulation_rows <- function(simulations, rows) {
  simulations$observed_response <- simulations$observed_response[rows]
  simulations$predicted_response <- simulations$predicted_response[rows]
  simulations$simulated_responses <- simulations$simulated_responses[, rows, drop = FALSE]
  simulations$model_frame <- simulations$model_frame[rows, , drop = FALSE]
  simulations
}

# Independent versions of the paired statistics.
expected_pair_summaries <- function(first, second, with_roles = TRUE) {
  average <- (first + second) / 2
  difference <- (first - second) / 2
  if (with_roles) {
    return(c(sd(first), sd(second), cor(first, second), sd(average),
             sd(difference), cor(average, difference)))
  }
  average_variance <- var(average)
  difference_mean_square <- mean(difference^2)
  c(sqrt(average_variance + difference_mean_square),
    (average_variance - difference_mean_square) /
      (average_variance + difference_mean_square),
    sqrt(average_variance), sqrt(difference_mean_square))
}

check_occasions <- function(simulations, ...) {
  check_partner_dependence(simulations, dyad = "dyad", member = "member",
                           time = "time", plot = FALSE, ...)
}

statistics_matrix <- function(check, composition_index) {
  unname(as.matrix(check$compositions$statistics[[composition_index]][, -1]))
}


test_that("repeated occasions compare member means and same-occasion deviations", {
  simulations <- occasion_check_simulations()
  datasets <- rbind(simulations$observed_response, simulations$simulated_responses)

  for (response in c("raw", "model-centred")) {
    for (with_roles in c(TRUE, FALSE)) {
      role_column <- if (with_roles) "role" else NULL
      check <- check_occasions(simulations, role = !!role_column, response = response)
      expected_between <- expected_within <- NULL
      for (dataset_index in seq_len(nrow(datasets))) {
        responses <- datasets[dataset_index, ]
        if (response == "model-centred") {
          responses <- responses - simulations$predicted_response
        }
        member_series <- matrix(responses, nrow = 4)
        member_means <- colMeans(member_series)
        deviations <- sweep(member_series, 2, member_means)
        expected_between <- rbind(expected_between, expected_pair_summaries(
          member_means[c(1, 3, 5, 7)], member_means[c(2, 4, 6, 8)], with_roles
        ))
        expected_within <- rbind(expected_within, expected_pair_summaries(
          as.vector(deviations[, c(1, 3, 5, 7)]), as.vector(deviations[, c(2, 4, 6, 8)]),
          with_roles
        ))
      }
      expect_identical(check$compositions$level, c("between", "within"))
      expect_equal(statistics_matrix(check, 1), unname(expected_between))
      expect_equal(statistics_matrix(check, 2), unname(expected_within))
    }
  }
  expect_named(check$compositions, c("level", "label", "n_pairs", "statistics"))
  expect_identical(check$compositions$label, c("All dyads (between)", "All dyads (within)"))
  expect_identical(check$compositions$n_pairs, c(4L, 4L))
  expect_identical(check$n_pairs, 4L)
  expect_identical(unique(check$summary$composition), check$compositions$label)
})

test_that("member means use all occasions and within pairs need both partners", {
  # Remove member a on occasion 2 in dyad 1, member b on occasion 3 in dyad 2,
  # and occasions 2 to 4 of member a in dyad 4.
  simulations <- keep_simulation_rows(occasion_check_simulations(),
                                      setdiff(1:32, c(2, 15, 26:28)))
  expect_no_warning(check <- check_occasions(simulations, role = "role"))

  first_member_means <- c(10 / 3, 21 / 4, 10, 6)
  second_member_means <- c(17 / 4, 28 / 3, 31 / 4, 57 / 4)
  expect_equal(statistics_matrix(check, 1)[1, ],
               expected_pair_summaries(first_member_means, second_member_means))
  first_deviations <- c(c(1, 2, 7) - 10 / 3, c(3, 8, 6) - 21 / 4,
                        c(10, 8, 13, 9) - 10, 0)
  second_deviations <- c(c(2, 8, 4) - 17 / 4, c(9, 6, 13) - 28 / 3,
                         c(4, 11, 7, 9) - 31 / 4, 15 - 57 / 4)
  expect_equal(statistics_matrix(check, 2)[1, ],
               expected_pair_summaries(first_deviations, second_deviations))
  expect_identical(check$compositions$n_pairs, c(4L, 4L))
})

test_that("results do not depend on row order, member labels, or key collisions", {
  simulations <- occasion_check_simulations()
  relabelled <- simulations
  # Swap the member labels in dyads 1 and 3; roles stay with their rows.
  swapped_rows <- relabelled$model_frame$dyad %in% c(1, 3)
  relabelled$model_frame$member[swapped_rows] <- ifelse(
    relabelled$model_frame$member[swapped_rows] == "a", "b", "a"
  )
  # Pasting these dyad, member, or time labels with ":" would merge groups.
  relabelled$model_frame$dyad <- c("x", "x:y", "third", "fourth")[relabelled$model_frame$dyad]
  relabelled$model_frame$member <- unname(c(a = "y:z", b = "z")[relabelled$model_frame$member])
  relabelled$model_frame$time <- c("y:z", "z", "t3", "t4")[relabelled$model_frame$time]
  relabelled <- keep_simulation_rows(relabelled, c(seq(2, 32, 2), seq(31, 1, -2)))

  for (with_roles in c(TRUE, FALSE)) {
    role_column <- if (with_roles) "role" else NULL
    original <- check_occasions(simulations, role = !!role_column)
    reordered <- check_occasions(relabelled, role = !!role_column)
    expect_equal(reordered$compositions$statistics, original$compositions$statistics)
    expect_identical(reordered$compositions$n_pairs, original$compositions$n_pairs)
  }

  # Numeric dyad IDs that print alike must stay separate.
  close_ids <- simulations
  close_ids$model_frame$dyad <- c(1, 1 + 2^-52, 2, 3)[close_ids$model_frame$dyad]
  expect_equal(check_occasions(close_ids, role = "role")$compositions$statistics,
               check_occasions(simulations, role = "role")$compositions$statistics)
})

test_that("repeated occasions reject changing member roles regardless of row order", {
  simulations <- occasion_check_simulations()
  simulations$model_frame$role[1] <- NA
  simulations$model_frame$role[2] <- "b"
  for (rows in list(1:32, 32:1)) {
    reordered <- keep_simulation_rows(simulations, rows)
    expect_error(check_occasions(reordered, role = "role"),
                 "Each member must have the same role throughout the data.", fixed = TRUE)
    expect_no_warning(check_occasions(reordered, role = NULL))
  }
})

test_that("rows with missing dyad IDs or roles are left out of both levels", {
  simulations <- occasion_check_simulations()
  with_missing <- simulations
  with_missing$model_frame$dyad[5] <- NA
  with_missing$model_frame$role[12] <- NA

  expect_warning(
    check <- check_occasions(with_missing, role = "role"),
    "fitted rows with missing dyad IDs (n = 1): 5; fitted rows with missing roles (n = 1): 12",
    fixed = TRUE
  )
  without_rows <- check_occasions(keep_simulation_rows(simulations, -c(5, 12)), role = "role")
  expect_equal(check$compositions$statistics, without_rows$compositions$statistics)
  expect_identical(c(check$n_missing_dyad_rows, check$n_missing_role_rows), c(1L, 1L))
})

test_that("dyads that lose all rows to missing roles count as incomplete", {
  simulations <- occasion_check_simulations()
  simulations$model_frame$role[simulations$model_frame$dyad == 4] <- NA

  expect_warning(
    check <- check_occasions(simulations, role = "role"),
    "Omitted: 1 incomplete dyad, with ID: 4; fitted rows with missing roles (n = 8)",
    fixed = TRUE
  )
  expect_identical(check$n_incomplete_dyads, 1L)
  expect_identical(check$n_pairs, 3L)
})

test_that("repeated occasions need member and time, and one row per member and occasion", {
  simulations <- occasion_check_simulations()
  expect_error(check_partner_dependence(simulations, "dyad", time = "time", plot = FALSE),
               "`time` requires `member` to be supplied.", fixed = TRUE)
  # Without `time`, `member` is ignored, so repeated rows still point to `time`.
  expect_error(check_partner_dependence(simulations, "dyad", role = NULL, member = "member",
                                        plot = FALSE),
               "For repeated occasions, supply `member` and `time`", fixed = TRUE)

  # Cross-sectional checks ignore `member`, even a column that does not exist.
  one_occasion <- keep_simulation_rows(simulations, which(simulations$model_frame$time == 1))
  expect_identical(
    check_partner_dependence(one_occasion, "dyad", role = NULL, member = "not_a_column",
                             plot = FALSE),
    check_partner_dependence(one_occasion, "dyad", role = NULL, plot = FALSE)
  )

  repeated_occasion <- simulations
  repeated_occasion$model_frame$time[2] <- 1L
  expect_error(check_occasions(repeated_occasion),
               "Each member can have at most one fitted row per `time`.", fixed = TRUE)

  missing_time <- simulations
  missing_time$model_frame$time[3] <- NA
  expect_error(check_occasions(missing_time),
               "`member` and `time` must be known for every fitted row.", fixed = TRUE)

  third_member <- simulations
  third_member$model_frame$member[4] <- "c"
  expect_error(check_occasions(third_member),
               "Each dyad must have at most two members.", fixed = TRUE)

  # The structure is checked before rows with missing roles are dropped.
  repeated_occasion$model_frame$role[2] <- NA
  expect_error(check_occasions(repeated_occasion, role = "role"),
               "Each member can have at most one fitted row per `time`.", fixed = TRUE)
  third_member$model_frame$role[4] <- NA
  expect_error(check_occasions(third_member, role = "role"),
               "Each dyad must have at most two members.", fixed = TRUE)
})

test_that("the within level needs three dyads that share an occasion", {
  simulations <- occasion_check_simulations()
  # Partners in dyads 3 and 4 never respond on the same occasion.
  later_rows <- simulations$model_frame$dyad %in% 3:4 &
    simulations$model_frame$member == "b"
  simulations$model_frame$time[later_rows] <- simulations$model_frame$time[later_rows] + 4L

  expect_warning(
    check <- check_occasions(simulations, role = NULL),
    "Not checked (fewer than three complete pairs): All dyads (within) (n = 2).",
    fixed = TRUE
  )
  expect_identical(check$compositions$n_pairs, c(4L, 2L))
  expect_null(check$compositions$statistics[[2]])
  expect_identical(unique(check$summary$composition), "All dyads (between)")
  expect_output(print(check), "All dyads (within): 2 of 4 usable dyads; not checked",
                fixed = TRUE)
})

test_that("printed and plotted headings name each level", {
  check <- check_occasions(occasion_check_simulations(), role = "role")
  expect_output(print(check), "a - b (between): 4 of 4 usable dyads", fixed = TRUE)
  expect_output(print(check), "a - b (within): 4 of 4 usable dyads", fixed = TRUE)

  headings <- character()
  local_mocked_bindings(mtext = function(text, ...) {
    headings <<- c(headings, text)
  }, .package = "graphics")
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  plot(check, ask = FALSE)
  # Check only the composition labels, in order, since other plot text may change.
  composition_labels <- regmatches(headings, regexpr("a - b \\((between|within)\\)", headings))
  expect_identical(composition_labels, c("a - b (between)", "a - b (within)"))
})

test_that("a fitted diary model is checked at both levels", {
  skip_if_not_installed("glmmTMB")
  # Couples 1 to 40 are female-male dyads.
  diary_data <- prepare_dyad_data(
    dyads_ild[dyads_ild$coupleID <= 40, ], dyad = coupleID, member = personID,
    role = gender, time = diaryday, model_types = "none", seed = 123
  )
  model <- glmmTMB::glmmTMB(
    closeness ~ 0 + gender + gender:diaryday +
      us(0 + gender | coupleID) + us(0 + gender | coupleID:diaryday),
    dispformula = ~ 0, data = diary_data
  )
  simulations <- simulate_dyad_responses(model, nsim = 20, seed = 123)
  # personID is not in the model formula, so it comes from the fitting data.
  check <- check_partner_dependence(
    simulations, dyad = coupleID, role = gender, member = personID, time = diaryday,
    data = diary_data, plot = FALSE
  )
  expect_identical(check$compositions$label,
                   c("female - male (between)", "female - male (within)"))
  expect_identical(check$compositions$n_pairs, c(40L, 40L))
  expect_identical(dim(check$compositions$statistics[[2]]), c(21L, 7L))
})
