# Two complete dyads, one person without a partner (dyad 3), and one person
# whose partner is not in the data (dyad 4).
cross_sectional_data <- function() {
  tibble::tibble(
    dyad_id = c(1, 1, 2, 2, 3, 4),
    person_id = 1:6,
    partnered = c(TRUE, TRUE, TRUE, TRUE, FALSE, TRUE),
    x = c(1, 2, 3, 4, 5, 6)
  )
}

# Wife (person 1) at waves 1-6; her husband (person 2) answers waves 1-3,
# skips wave 4, and dies before wave 5. Dyad 2 is complete.
panel_data <- function() {
  tibble::tibble(
    dyad_id = c(rep(1, 9), rep(2, 4)),
    person_id = c(rep(1, 6), rep(2, 3), 3, 4, 3, 4),
    wave = c(1:6, 1:3, 1, 1, 2, 2),
    alive = c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, rep(TRUE, 7)),
    health = c(11:16, 21:23, 31, 41, 32, 42)
  )
}

# Dyad 1: the wife (person 1) at waves 1-4, her husband (person 2) at waves
# 1-2, who dies before wave 3. Dyad 2: person 3 alone at wave 1, partnered
# with person 4 from wave 2. Dyad 3: a stable couple. Dyad 4: a singleton.
status_change_data <- function() {
  tibble::tibble(
    dyad_id = c(1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4),
    person_id = c(1, 1, 1, 1, 2, 2, 3, 3, 3, 4, 4, 5, 6, 5, 6, 7, 7),
    wave = c(1, 2, 3, 4, 1, 2, 1, 2, 3, 2, 3, 1, 1, 2, 2, 1, 2),
    partnered = c(TRUE, TRUE, FALSE, FALSE, TRUE, TRUE, FALSE, TRUE, TRUE,
                  TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE),
    x = c(1, 2, 3, 4, 10, 12, 5, 6, 7, 20, 22, 30, 40, 31, 41, 50, 51)
  )
}

prepare <- function(data, ...) {
  prepare_dyad_data(data, dyad = dyad_id, member = person_id, seed = 123, ...)
}

prepare_status_change <- function(data = status_change_data(), ...) {
  suppressMessages(prepare(data, time = wave, predictors = x, partner_exists = partnered, ...))
}

# The terms suggested in the message, e.g. ".partner_exists".
suggested_terms <- function(message_text) {
  term_lines <- grep("^  \\+ ", strsplit(message_text, "\n")[[1]], value = TRUE)
  return(sub("^  \\+ (\\S+).*", "\\1", term_lines))
}

test_that("partner predictors are 0 where no partner existed, after centering", {
  run <- evaluate_promise(prepare(
    cross_sectional_data(), predictors = x, partner_exists = partnered, add_apim_gmc_predictors = TRUE
  ))
  prepared <- run$result

  # Complete dyads keep the partner's value, the person without a partner gets
  # 0, and the person whose partner is not in the data keeps a missing value.
  expect_equal(prepared$.x_partner, c(2, 1, 4, 3, 0, NA))
  expect_equal(prepared$.x_actor, cross_sectional_data()$x)
  # The grand mean includes everyone (mean of 1 to 6 = 3.5).
  expect_equal(prepared$.x_gmc_partner, c(-1.5, -2.5, 0.5, -0.5, 0, NA))
  expect_equal(prepared$.partner_exists, c(1, 1, 1, 1, 0, 1))
  expect_false(".partner_exists_lag1" %in% names(prepared))

  # Without lags, the message names only the current status.
  expect_match(run$messages, "Partner predictors were set to 0 where no partner existed", fixed = TRUE)
  expect_match(run$messages, "  + .partner_exists  # a partner exists (1) or not (0)\n", fixed = TRUE)
  expect_no_match(run$messages, ".partner_exists_lag1", fixed = TRUE)
})

test_that("nothing is added or reported when every row has a partner", {
  expect_no_message(prepared <- prepare(cross_sectional_data(), predictors = x, partner_exists = TRUE))
  expect_false(".partner_exists" %in% names(prepared))
})

test_that("lagged partner predictors follow the status at the previous occasion", {
  expect_message(
    prepared <- prepare(
      panel_data(), time = wave, predictors = health, lag1_predictors = health,
      temporal_decomposition = "none", partner_exists = alive
    ),
    "  + .partner_exists       # a partner exists (1) or not (0)\n  + .partner_exists_lag1  # a partner existed at the previous occasion\n",
    fixed = TRUE
  )
  wife <- prepared[prepared$person_id == 1, ]

  # Wave 4: husband skipped (missing). Waves 5-6: no partner (0). The wave-5
  # lag is missing because he skipped wave 4; at wave 6 no partner existed at
  # the previous occasion, so the lag is 0.
  expect_equal(wife$.health_partner, c(21, 22, 23, NA, 0, 0))
  expect_equal(wife$.health_partner_lag1, c(NA, 21, 22, 23, NA, 0))

  # The status columns mark where no partner existed, now and at the previous
  # occasion.
  expect_equal(wife$.partner_exists, c(1, 1, 1, 1, 0, 0))
  expect_equal(wife$.partner_exists_lag1, c(NA, 1, 1, 1, 1, 0))
  expect_false(any(c(".dy_partner_exists", ".dy_partner_exists_lag1") %in% names(prepared)))
})

test_that("previous status is only needed with lags", {
  # Occasion labels need not be numeric when no lags are requested.
  data <- panel_data()
  data$wave <- paste0("w", data$wave)

  # Character time cannot split before and after, which gives a warning.
  prepared <- suppressWarnings(suppressMessages(prepare(
    data, time = wave, predictors = health, temporal_decomposition = "none", partner_exists = alive
  )))
  expect_equal(prepared$.health_partner[prepared$person_id == 1], c(21, 22, 23, NA, 0, 0))
})

test_that("a partner returning after FALSE is reported", {
  data <- tibble::tibble(
    dyad_id = c(rep(1, 3), rep(2, 3), 3, 3),
    person_id = c(1, 1, 1, 2, 2, 2, 3, 4),
    wave = c(1:3, 1:3, 1, 1),
    together = c(TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE)
  )

  # Dyad 1 (TRUE, FALSE, TRUE) is reported; dyad 2 (FALSE, TRUE) is not.
  expect_message(
    prepare(data, time = wave, partner_exists = together),
    "`partner_exists` returns to TRUE after FALSE in 1 dyad (1).",
    fixed = TRUE
  )
})

test_that("returning partners are only reported with numeric time", {
  # The partner is lost at w10. Sorted alphabetically (w1, w10, w2), the
  # partner would seem to return at w2.
  data <- tibble::tibble(
    dyad_id = c(1, 1, 1, 2, 2),
    person_id = c(1, 1, 1, 2, 3),
    wave = c("w1", "w2", "w10", "w1", "w1"),
    together = c(TRUE, TRUE, FALSE, TRUE, TRUE)
  )

  expect_no_message(suppressWarnings(prepare(data, time = wave, partner_exists = together)))
})

test_that("structural columns may share names with temporary columns", {
  data <- dplyr::rename(panel_data(), previous_status = dyad_id, status = wave)
  prepared <- suppressMessages(prepare_dyad_data(
    data, dyad = previous_status, member = person_id, time = status,
    predictors = health, lag1_predictors = health, temporal_decomposition = "none",
    partner_exists = alive, seed = 123
  ))
  wife <- prepared[prepared$person_id == 1, ]
  expect_equal(wife$.partner_exists_lag1, c(NA, 1, 1, 1, 1, 0))
  expect_equal(wife$.health_partner_lag1, c(NA, 21, 22, 23, NA, 0))

  returning <- tibble::tibble(
    n_partner_periods = c(1, 1, 1, 2, 2, 2),
    person_id = c(1, 1, 1, 2, 2, 2),
    status = c(1:3, 1:3),
    together = c(TRUE, FALSE, TRUE, TRUE, TRUE, TRUE)
  )
  expect_message(
    prepare_dyad_data(
      returning, dyad = n_partner_periods, member = person_id, time = status,
      partner_exists = together, seed = 123
    ),
    "returns to TRUE after FALSE in 1 dyad (1).",
    fixed = TRUE
  )
})

test_that("partner_exists cannot be combined with DIM or DSM", {
  expect_error(
    prepare(
      cross_sectional_data(), predictors = x, model_types = c("apim", "dim"), partner_exists = partnered
    ),
    "`partner_exists` cannot be used with DIM or DSM columns yet. Use `model_types = \"apim\"`",
    fixed = TRUE
  )
})

test_that("former partners who both keep taking part get 0", {
  separated <- tibble::tibble(
    dyad_id = c(1, 1, 1, 1, 2, 2),
    person_id = c(1, 2, 1, 2, 3, 4),
    wave = c(1, 1, 2, 2, 1, 1),
    together = c(TRUE, TRUE, FALSE, FALSE, TRUE, TRUE),
    x = c(1, 2, 3, 4, 5, 6)
  )

  prepared <- suppressMessages(prepare(
    separated, time = wave, predictors = x, temporal_decomposition = "none", partner_exists = together
  ))

  # The former partner's value exists at wave 2, but is not a partner's value.
  expect_equal(prepared$.x_partner, c(2, 1, 0, 0, 6, 5))
})

test_that("non-numeric partner predictors stop where no partner existed", {
  data <- cross_sectional_data()
  data$g <- c("a", "b", "c", "d", "e", "f")
  expect_error(
    prepare(data, predictors = c(x, g), partner_exists = partnered),
    "cannot be set to 0 where no partner existed: `g`. Recode them as numeric",
    fixed = TRUE
  )
  # Without rows lacking a partner, nothing needs to be set to 0.
  expect_no_error(prepare(data, predictors = c(x, g), partner_exists = TRUE))
})

test_that("partner predictors keep their type and class", {
  data <- cross_sectional_data()
  data$count <- as.integer(data$x)
  data$score <- structure(data$x, class = "measured")

  prepared <- suppressMessages(prepare(data, predictors = c(count, score), partner_exists = partnered))
  expect_identical(prepared$.count_partner, c(2L, 1L, 4L, 3L, 0L, NA))
  expect_s3_class(prepared$.score_partner, "measured")
  expect_equal(unclass(prepared$.score_partner), c(2, 1, 4, 3, 0, NA))
})

test_that("a status change splits the status and the partner's usual level", {
  run <- evaluate_promise(prepare(
    status_change_data(), time = wave, predictors = x, partner_exists = partnered
  ))
  prepared <- run$result
  person <- prepared$person_id

  # Shares of occasions with a partner: person 1 0.5, persons 2, 4, 5 and 6
  # 1, person 3 2/3, person 7 0.
  shares <- c(0.5, 1, 2 / 3, 1, 1, 1, 0)
  expect_equal(prepared$.partner_exists_cwp, prepared$.partner_exists - shares[person])
  expect_equal(prepared$.partner_exists_cbp, shares[person] - mean(shares))
  expect_true(".partner_exists" %in% names(prepared))

  # Person 3 is alone at wave 1 before the relationship. Person 1 loses her
  # partner, so both states occur and need their own indicator.
  expect_equal(prepared$.partner_before_exists, as.numeric(person == 3 & prepared$wave == 1))

  # Usual levels: person means minus the mean of person means.
  means <- c(2.5, 11, 6, 21, 30.5, 40.5, 50.5)
  usual_level <- means - mean(means)
  wife <- prepared[person == 1, ]
  formed <- prepared[person == 3, ]
  singleton <- prepared[person == 7, ]

  expect_false(".x_cbp_partner" %in% names(prepared))
  # The wife: her husband's usual level while he lives, then after his death.
  expect_equal(wife$.x_cbp_partner_when_exists, c(rep(usual_level[2], 2), 0, 0))
  expect_equal(wife$.x_cbp_partner_after_exists, c(0, 0, rep(usual_level[2], 2)))
  expect_equal(wife$.x_cbp_partner_before_exists, c(0, 0, 0, 0))
  # Person 3: the future partner's usual level before the relationship.
  expect_equal(formed$.x_cbp_partner_before_exists, c(usual_level[4], 0, 0))
  expect_equal(formed$.x_cbp_partner_when_exists, c(0, rep(usual_level[4], 2)))
  # The singleton has no partner: 0 everywhere.
  expect_equal(singleton$.x_cbp_partner_when_exists, c(0, 0))
  expect_equal(singleton$.x_cbp_partner_after_exists, c(0, 0))

  # The metadata use the new names.
  meta <- attr(prepared, "dyadMLM")
  expect_true(".x_cbp_partner_when_exists" %in% meta$apim_predictors$partner_column)
  expect_true(".x_cbp_partner_when_exists" %in% meta$zeroed_partner_columns$column)

  # The message lists the split terms. The singleton needs its own intercept:
  # the split columns are 0 for them.
  expect_equal(suggested_terms(run$messages), c(
    ".partner_exists_cwp", ".partner_exists_cbp", ".partner_before_exists", ".is_singleton",
    ".x_cwp_partner",
    ".x_cbp_partner_when_exists", ".x_cbp_partner_before_exists", ".x_cbp_partner_after_exists"
  ))
  expect_match(run$messages, "\\.is_singleton +# no partner at any occasion \\(own intercept\\)")
  expect_match(run$messages, "The partner's usual level (`cbp`) is split by partner status", fixed = TRUE)

  # Without a formation, the indicator for occasions before is not needed.
  losses_only <- status_change_data()
  losses_only$partnered[losses_only$person_id == 3] <- TRUE
  expect_false(".partner_before_exists" %in% names(prepare_status_change(losses_only)))
})

test_that("a usual level that applies but is unknown stays missing", {
  data <- status_change_data()
  data$x[data$person_id == 2] <- NA
  prepared <- prepare_status_change(data)
  wife <- prepared[prepared$person_id == 1, ]

  expect_equal(wife$.x_cbp_partner_when_exists, c(NA, NA, 0, 0))
  expect_equal(wife$.x_cbp_partner_after_exists, c(0, 0, NA, NA))
})

test_that("gaps in on-off relationships count as after a partnership", {
  data <- tibble::tibble(
    dyad_id = c(1, 1, 1, 1, 1, 2, 2),
    person_id = c(1, 1, 1, 2, 2, 3, 4),
    wave = c(1, 2, 3, 1, 3, 1, 1),
    partnered = c(TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE),
    x = c(1, 2, 3, 10, 12, 5, 6)
  )
  prepared <- prepare_status_change(data)
  person_1 <- prepared[prepared$person_id == 1, ]

  expect_false(".x_cbp_partner_before_exists" %in% names(prepared))
  expect_equal(person_1$.x_cbp_partner_after_exists != 0, c(FALSE, TRUE, FALSE))
})

test_that("nothing is split or lagged without status changes", {
  # Singletons and stable couples: the lagged status would equal the status.
  stable <- status_change_data()
  stable$partnered[stable$dyad_id != 4] <- TRUE
  prepared <- prepare_status_change(stable, lag1_predictors = x)
  expect_true(all(c(".partner_exists", ".x_cbp_partner") %in% names(prepared)))
  expect_false(any(grepl("_when_exists|_exists_c[wb]p|_exists_lag1", names(prepared))))

  # Nothing is split without temporal decomposition either.
  prepared <- prepare_status_change(temporal_decomposition = "none")
  expect_false(any(grepl("_when_exists|_exists_c[wb]p", names(prepared))))
})

test_that("the message lists partner predictors of one decomposition with lags", {
  prepare_lagged <- function(...) {
    evaluate_promise(prepare(
      status_change_data(), time = wave, predictors = x, lag1_predictors = x,
      partner_exists = partnered, ...
    ))
  }

  run <- prepare_lagged()
  expect_true(".partner_exists_lag1" %in% names(run$result))
  expect_equal(suggested_terms(run$messages), c(
    ".partner_exists_cwp", ".partner_exists_cbp", ".partner_exists_lag1", ".partner_before_exists",
    ".is_singleton", ".x_cwp_partner", ".x_cwp_partner_lag1",
    ".x_cbp_partner_when_exists", ".x_cbp_partner_before_exists", ".x_cbp_partner_after_exists"
  ))
  # Without decomposition: raw values, never next to cwp or cbp columns.
  expect_equal(suggested_terms(prepare_lagged(temporal_decomposition = "none")$messages), c(
    ".partner_exists", ".partner_exists_lag1", ".partner_before_exists", ".x_partner", ".x_partner_lag1"
  ))
})

test_that("a status change within the dyad counts even if no person changes", {
  # Person 1 answers only while partnered (waves 1-2), person 2 only after
  # the separation (waves 3-4). No person changes status, but the dyad does.
  data <- tibble::tibble(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c(1, 1, 2, 2, 3, 4, 3, 4),
    wave = c(1, 2, 3, 4, 1, 1, 2, 2),
    partnered = c(TRUE, TRUE, FALSE, FALSE, TRUE, TRUE, TRUE, TRUE),
    x = 1:8
  )
  prepared <- prepare_status_change(data, lag1_predictors = x)

  expect_true(all(c(".partner_exists_lag1", ".partner_exists_cwp") %in% names(prepared)))
  person_2 <- prepared[prepared$person_id == 2, ]
  expect_equal(person_2$.partner_exists_lag1, c(1, 0))
})

test_that("before and after are not split without numeric time", {
  data <- status_change_data()
  data$wave <- paste0("w", data$wave)

  expect_warning(
    prepared <- prepare_status_change(data),
    "`time` is not numeric, so dyadMLM cannot tell which occasions come before or after",
    fixed = TRUE
  )
  expect_true(".x_cbp_partner" %in% names(prepared))
  expect_false(any(grepl("_exists$", names(prepared)) & names(prepared) != ".partner_exists"))
})

test_that("the message only mentions an indicator that exists", {
  # Only single men remain, so no status column is created.
  data <- tibble::tibble(
    dyad_id = c(1, 1, 2, 3),
    person_id = 1:4,
    gender = c("female", "male", "male", "male"),
    partnered = c(TRUE, TRUE, FALSE, FALSE),
    x = 1:4
  )
  run <- evaluate_promise(prepare(
    data, role = gender, predictors = x, partner_exists = partnered,
    keep_compositions = "singleton_male"
  ))
  expect_equal(run$messages, "Partner predictors were set to 0 where no partner existed.\n")
})

test_that("terms are suggested for the status and partner columns that remain", {
  raw <- prepare_status_change(lag1_predictors = x, temporal_decomposition = "none")
  split <- prepare_status_change(lag1_predictors = x)
  terms_for <- function(prepared, columns) {
    two_part_terms(attr(prepared, "dyadMLM"), tibble::as_tibble(prepared)[columns])$term
  }

  # Lag only.
  expect_equal(
    terms_for(raw, c(".partner_exists_lag1", ".x_partner_lag1")),
    c(".partner_exists_lag1", ".x_partner_lag1")
  )
  # A split usual level only.
  expect_equal(
    terms_for(split, c(".partner_exists_cwp", ".partner_exists_cbp", ".x_cbp_partner_after_exists")),
    c(".partner_exists_cwp", ".partner_exists_cbp", ".x_cbp_partner_after_exists")
  )
  # Never one status part alone, and nothing without a status term.
  expect_null(terms_for(split, c(".partner_exists_cwp", ".x_cbp_partner_after_exists")))
  expect_null(terms_for(split, ".x_cbp_partner_after_exists"))

  # Without the current status, only lagged terms are suggested. With split
  # usual levels, the singleton term is not added without them.
  expect_equal(
    terms_for(split, setdiff(
      names(split), c(".partner_exists", ".partner_exists_cwp", ".partner_exists_cbp")
    )),
    c(".partner_exists_lag1", ".x_cwp_partner_lag1")
  )
  expect_equal(
    terms_for(raw, c(".partner_exists_lag1", ".x_partner", ".x_partner_lag1")),
    c(".partner_exists_lag1", ".x_partner_lag1")
  )
  expect_null(terms_for(raw, c(".partner_before_exists", ".x_partner")))
})
