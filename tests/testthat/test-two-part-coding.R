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

# Dyad 1: the wife (person 1) at waves 1-4, her husband (person 2) answers
# waves 1-2 and skips waves 3-4. Dyad 2 is complete. Dyad 3 is a person without
# a partner at waves 1, 2, and 4.
panel_data <- function() {
  tibble::tibble(
    dyad_id = c(rep(1, 6), 2, 2, 3, 3, 3),
    person_id = c(1, 1, 1, 1, 2, 2, 3, 4, 5, 5, 5),
    wave = c(1:4, 1:2, 1, 1, 1, 2, 4),
    partnered = c(rep(TRUE, 8), FALSE, FALSE, FALSE),
    health = c(11:14, 21:22, 31, 41, 51, 52, 54)
  )
}

prepare <- function(data, ...) {
  prepare_dyad_data(data, dyad = dyad_id, member = person_id, seed = 123, ...)
}

prepare_panel <- function(data = panel_data(), ...) {
  suppressMessages(prepare(data, time = wave, predictors = health, partner_exists = partnered, ...))
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

  expect_match(run$messages, "Partner predictors were set to 0 where no partner existed", fixed = TRUE)
  expect_match(run$messages, "  + .partner_exists  # a partner exists (1) or not (0)\n", fixed = TRUE)
})

test_that("nothing is added or reported when every row has a partner", {
  expect_no_message(prepared <- prepare(cross_sectional_data(), predictors = x, partner_exists = TRUE))
  expect_false(".partner_exists" %in% names(prepared))
})

test_that("lagged partner predictors stay missing at first occasions and after gaps", {
  prepared <- prepare_panel(lag1_predictors = health, temporal_decomposition = "none")
  wife <- prepared[prepared$person_id == 1, ]
  single <- prepared[prepared$person_id == 5, ]

  # The husband skipped waves 3-4, so his values are missing there.
  expect_equal(wife$.health_partner, c(21, 22, NA, NA))
  expect_equal(wife$.health_partner_lag1, c(NA, 21, 22, NA))

  # Without a partner, the values are 0. The lag stays missing at the first
  # occasion and after the gap at wave 3, as it would in a complete dyad.
  expect_equal(single$.health_partner, c(0, 0, 0))
  expect_equal(single$.health_partner_lag1, c(NA, 0, NA))
  expect_false(any(c(".dy_partner_exists", ".dy_partner_exists_lag1") %in% names(prepared)))
})

test_that("previous status is only needed with lags", {
  # Occasion labels need not be numeric when no lags are requested.
  data <- panel_data()
  data$wave <- paste0("w", data$wave)

  expect_no_warning(prepared <- prepare_panel(data, temporal_decomposition = "none"))
  expect_equal(prepared$.health_partner[prepared$person_id == 5], c(0, 0, 0))
})

test_that("structural columns may share names with temporary columns", {
  data <- dplyr::rename(panel_data(), previous_status = dyad_id, status = wave)
  prepared <- suppressMessages(prepare_dyad_data(
    data, dyad = previous_status, member = person_id, time = status,
    predictors = health, lag1_predictors = health, temporal_decomposition = "none",
    partner_exists = partnered, seed = 123
  ))
  single <- prepared[prepared$person_id == 5, ]
  expect_equal(single$.health_partner_lag1, c(NA, 0, NA))
})

test_that("partner_exists cannot be combined with DIM or DSM", {
  expect_error(
    prepare(
      cross_sectional_data(), predictors = x, model_types = c("apim", "dim"), partner_exists = partnered
    ),
    "`partner_exists` cannot be used with DIM or DSM columns. Use `model_types = \"apim\"`",
    fixed = TRUE
  )
})

test_that("former partners who both take part get 0", {
  separated <- tibble::tibble(
    dyad_id = c(1, 1, 1, 1, 2, 2),
    person_id = c(1, 2, 1, 2, 3, 4),
    wave = c(1, 1, 2, 2, 1, 1),
    together = c(FALSE, FALSE, FALSE, FALSE, TRUE, TRUE),
    x = c(1, 2, 3, 4, 5, 6)
  )

  prepared <- suppressMessages(prepare(
    separated, time = wave, predictors = x, temporal_decomposition = "none", partner_exists = together
  ))

  # The former partner's values exist, but are not a partner's values.
  expect_equal(prepared$.x_partner, c(0, 0, 0, 0, 6, 5))
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

test_that("the message lists partner predictors of one decomposition with lags", {
  suggested_for <- function(...) {
    run <- evaluate_promise(prepare(
      panel_data(), time = wave, predictors = health, lag1_predictors = health,
      partner_exists = partnered, ...
    ))
    return(suggested_terms(run$messages))
  }

  expect_equal(suggested_for(), c(
    ".partner_exists", ".health_cwp_partner", ".health_cwp_partner_lag1", ".health_cbp_partner"
  ))
  # Without decomposition: raw values, never next to cwp or cbp columns.
  expect_equal(suggested_for(temporal_decomposition = "none"), c(
    ".partner_exists", ".health_partner", ".health_partner_lag1"
  ))
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
  prepared <- prepare_panel(lag1_predictors = health)
  terms_for <- function(data) two_part_terms(attr(prepared, "dyadMLM"), data)$term

  expect_equal(
    terms_for(tibble::as_tibble(prepared)[c(".partner_exists", ".health_cwp_partner_lag1")]),
    c(".partner_exists", ".health_cwp_partner_lag1")
  )
  # Nothing without the status, or once it is constant (rows with a partner).
  expect_null(terms_for(dplyr::select(tibble::as_tibble(prepared), -".partner_exists")))
  expect_null(terms_for(tibble::as_tibble(prepared)[prepared$.partner_exists == 1, ]))
})

test_that("the message describes the returned rows, not temporary rows", {
  # Person 2 misses wave 2. The temporary row for that occasion would carry
  # partner values that the returned data do not have.
  panel <- tibble::tibble(
    dyad_id = c(1, 1, 1, 2, 2),
    person_id = c(1, 2, 1, 3, 3),
    wave = c(1, 1, 2, 1, 2),
    partnered = c(FALSE, FALSE, FALSE, TRUE, TRUE),
    x = 1:5
  )
  run <- evaluate_promise(prepare_dyad_data(
    panel, dyad = dyad_id, member = person_id, time = wave, predictors = x,
    partner_exists = partnered, temporal_decomposition = "none"
  ))
  expect_equal(run$result$.x_partner, c(0, 0, 0, NA, NA))
  expect_equal(run$messages, "Partner predictors were set to 0 where no partner existed.\n")
})
