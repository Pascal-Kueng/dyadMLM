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

test_that("partner predictors are 0 where no partner existed", {
  expect_message(
    prepared <- prepare_dyad_data(
      cross_sectional_data(),
      dyad = dyad_id,
      member = person_id,
      predictors = x,
      partner_exists = partnered,
      seed = 123
    ),
    "Partner predictors were set to 0 where no partner existed",
    fixed = TRUE
  )

  # Complete dyads keep the partner's value, the person without a partner gets
  # 0, and the person whose partner is not in the data keeps a missing value.
  expect_equal(prepared$.x_partner, c(2, 1, 4, 3, 0, NA))
  expect_equal(prepared$.x_actor, cross_sectional_data()$x)
})

test_that("centering happens before partner predictors are set to 0", {
  prepared <- suppressMessages(prepare_dyad_data(
    cross_sectional_data(),
    dyad = dyad_id,
    member = person_id,
    predictors = x,
    partner_exists = partnered,
    add_apim_gmc_predictors = TRUE,
    seed = 123
  ))

  # The grand mean includes everyone (mean of 1 to 6 = 3.5).
  expect_equal(prepared$.x_gmc_partner, c(-1.5, -2.5, 0.5, -0.5, 0, NA))
})

test_that("lagged partner predictors follow the status at the previous occasion", {
  prepared <- suppressMessages(prepare_dyad_data(
    panel_data(),
    dyad = dyad_id,
    member = person_id,
    time = wave,
    predictors = health,
    lag1_predictors = health,
    temporal_decomposition = "none",
    partner_exists = alive,
    seed = 123
  ))
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

test_that("the message names the status columns to include", {
  expect_message(
    prepare_dyad_data(
      panel_data(),
      dyad = dyad_id,
      member = person_id,
      time = wave,
      predictors = health,
      lag1_predictors = health,
      temporal_decomposition = "none",
      partner_exists = alive,
      seed = 123
    ),
    "You must include `.partner_exists` as a fixed effect in the model (and `.partner_exists_lag1` for lagged partner predictors)",
    fixed = TRUE
  )
})

test_that("the message names the lagged status only with lags", {
  message_text <- conditionMessage(rlang::catch_cnd(
    prepare_dyad_data(
      cross_sectional_data(),
      dyad = dyad_id,
      member = person_id,
      predictors = x,
      partner_exists = partnered,
      seed = 123
    ),
    classes = "message"
  ))
  expect_match(message_text, "You must include `.partner_exists`", fixed = TRUE)
  expect_no_match(message_text, ".partner_exists_lag1", fixed = TRUE)
})

test_that(".partner_exists is only added when the status varies", {
  prepared <- prepare_dyad_data(
    cross_sectional_data(),
    dyad = dyad_id,
    member = person_id,
    predictors = x,
    partner_exists = TRUE,
    seed = 123
  )
  expect_false(".partner_exists" %in% names(prepared))

  prepared <- suppressMessages(prepare_dyad_data(
    cross_sectional_data(),
    dyad = dyad_id,
    member = person_id,
    partner_exists = partnered,
    seed = 123
  ))
  expect_equal(prepared$.partner_exists, c(1, 1, 1, 1, 0, 1))
  expect_false(".partner_exists_lag1" %in% names(prepared))
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
    prepare_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      time = wave,
      partner_exists = together,
      seed = 123
    ),
    "`partner_exists` returns to TRUE after FALSE in 1 dyad (1).",
    fixed = TRUE
  )
})

test_that("partner_exists cannot be combined with DIM or DSM", {
  expect_error(
    prepare_dyad_data(
      cross_sectional_data(),
      dyad = dyad_id,
      member = person_id,
      predictors = x,
      model_types = c("apim", "dim"),
      partner_exists = partnered,
      seed = 123
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

  prepared <- suppressMessages(prepare_dyad_data(
    separated,
    dyad = dyad_id,
    member = person_id,
    time = wave,
    predictors = x,
    temporal_decomposition = "none",
    partner_exists = together,
    seed = 123
  ))

  # The former partner's value exists at wave 2, but is not a partner's value.
  expect_equal(prepared$.x_partner, c(2, 1, 0, 0, 6, 5))
})

test_that("non-numeric partner predictors are missing where no partner existed", {
  data <- cross_sectional_data()
  data$x <- c("a", "b", "c", "d", "e", "f")

  expect_warning(
    prepared <- prepare_dyad_data(
      data,
      dyad = dyad_id,
      member = person_id,
      predictors = x,
      partner_exists = partnered,
      seed = 123
    ),
    "so they are missing (NA) there: `x`.",
    fixed = TRUE
  )
  expect_equal(prepared$.x_partner, c("b", "a", "d", "c", NA, NA))
})

test_that("partner predictors keep their class", {
  data <- cross_sectional_data()
  data$x <- structure(data$x, class = "measured")

  prepared <- suppressMessages(prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    predictors = x,
    partner_exists = partnered,
    seed = 123
  ))
  expect_s3_class(prepared$.x_partner, "measured")
  expect_equal(unclass(prepared$.x_partner), c(2, 1, 4, 3, 0, NA))
})

test_that("integer partner predictors stay integer", {
  data <- cross_sectional_data()
  data$x <- as.integer(data$x)

  prepared <- suppressMessages(prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    predictors = x,
    partner_exists = partnered,
    seed = 123
  ))
  expect_type(prepared$.x_partner, "integer")
  expect_equal(prepared$.x_partner, c(2L, 1L, 4L, 3L, 0L, NA))
})

test_that("nothing is reported when every row has a partner", {
  data <- cross_sectional_data()

  expect_no_message(prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    predictors = x,
    partner_exists = TRUE,
    seed = 123
  ))
})

test_that("previous status is only needed with lags", {
  # Occasion labels need not be numeric when no lags are requested.
  data <- panel_data()
  data$wave <- paste0("w", data$wave)

  prepared <- suppressMessages(prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    time = wave,
    predictors = health,
    temporal_decomposition = "none",
    partner_exists = alive,
    seed = 123
  ))
  expect_equal(prepared$.health_partner[prepared$person_id == 1], c(21, 22, 23, NA, 0, 0))
})

test_that("structural columns may share names with temporary columns", {
  data <- dplyr::rename(panel_data(), previous_status = dyad_id, status = wave)

  prepared <- suppressMessages(prepare_dyad_data(
    data,
    dyad = previous_status,
    member = person_id,
    time = status,
    predictors = health,
    lag1_predictors = health,
    temporal_decomposition = "none",
    partner_exists = alive,
    seed = 123
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
      returning,
      dyad = n_partner_periods,
      member = person_id,
      time = status,
      partner_exists = together,
      seed = 123
    ),
    "returns to TRUE after FALSE in 1 dyad (1).",
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

  expect_no_message(prepare_dyad_data(
    data,
    dyad = dyad_id,
    member = person_id,
    time = wave,
    partner_exists = together,
    seed = 123
  ))
})
