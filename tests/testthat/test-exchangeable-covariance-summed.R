summed_test_block <- function(coefficients, term) {
  list(group = "coupleID", coefficients = coefficients, term = term)
}

shared_sum <- "I(.is_male_x_male + .is_singleton_male)"
difference_sum <- "I(.member_contrast_male_x_male_arbitrary + .is_singleton_male)"

test_that("summed indicators are matched as the indicator itself", {
  blocks <- list(
    summed_test_block(c(shared_sum, paste0(shared_sum, ":time")), "shared"),
    summed_test_block(c(difference_sum, paste0("time:", difference_sum)), "difference")
  )

  pair <- match_exchangeable_residual_blocks(blocks)[[1L]]
  expect_equal(pair$shared_block_index, 1L)
  expect_equal(pair$difference_block_index, 2L)
  expect_equal(pair$shared_indicator, ".is_male_x_male")
  expect_equal(pair$underlying_terms, c("(Intercept)", "time"))
  expect_equal(pair$added_indicators, ".is_singleton_male")
  # The fitted summed columns are the ones whose coding is checked.
  expect_equal(pair$shared_coding_column, shared_sum)
  expect_equal(pair$difference_coding_column, difference_sum)

  # The order of the summands does not matter.
  expect_equal(
    summed_indicator_additions("I(.is_singleton_male + .is_male_x_male)", ".is_male_x_male"),
    ".is_singleton_male"
  )
  expect_null(summed_indicator_additions("I(.is_male_x_male * time)", ".is_male_x_male"))

  # Separate intercept and slope blocks can add the same indicator.
  blocks <- list(
    summed_test_block(shared_sum, "intercept shared"),
    summed_test_block(difference_sum, "intercept difference"),
    summed_test_block(paste0(shared_sum, ":time"), "slope shared"),
    summed_test_block(paste0(difference_sum, ":time"), "slope difference")
  )
  expect_equal(
    lapply(match_exchangeable_residual_blocks(blocks), `[[`, "added_indicators"),
    list(".is_singleton_male", ".is_singleton_male")
  )
})

test_that("added indicators must appear in both blocks and on all terms", {
  only_shared <- list(
    summed_test_block(shared_sum, "shared"),
    summed_test_block(".member_contrast_male_x_male_arbitrary", "difference")
  )
  expect_error(
    match_exchangeable_residual_blocks(only_shared),
    paste0(
      "`.is_singleton_male` appears in the shared block but not in the ",
      "difference block"
    ),
    fixed = TRUE
  )

  # The error names the block each indicator is missing from.
  different <- list(
    summed_test_block(shared_sum, "shared"),
    summed_test_block(
      "I(.member_contrast_male_x_male_arbitrary + .is_male_x_missing)",
      "difference"
    )
  )
  expect_error(
    match_exchangeable_residual_blocks(different),
    paste0(
      "`.is_singleton_male` appears in the shared block but not in the ",
      "difference block, and `.is_male_x_missing` appears in the difference ",
      "block but not in the shared block"
    ),
    fixed = TRUE
  )

  mixed_terms <- list(
    summed_test_block(c(shared_sum, ".is_male_x_male:time"), "shared"),
    summed_test_block(
      c(difference_sum, ".member_contrast_male_x_male_arbitrary:time"),
      "difference"
    )
  )
  expect_error(
    match_exchangeable_residual_blocks(mixed_terms),
    "must add the same indicators to `.is_male_x_male`",
    fixed = TRUE
  )
})

test_that("summed columns are computed when the model frame keeps raw columns", {
  # As in brms, the model frame holds the raw columns, not the sums.
  frame <- data.frame(
    .is_male_x_male = c(1, 1, 0),
    .member_contrast_male_x_male_arbitrary = c(-1, 1, 0),
    .is_singleton_male = c(0, 0, 1)
  )
  blocks <- list(
    summed_test_block(shared_sum, "shared"),
    summed_test_block(difference_sum, "difference")
  )
  expect_no_warning(match_exchangeable_residual_blocks(blocks, frame))

  frame$.is_singleton_male <- c(0, 0, 2)
  expect_error(
    match_exchangeable_residual_blocks(blocks, frame),
    "have incompatible coding",
    fixed = TRUE
  )
})

# Exchangeable male-male dyads plus single men, prepared with `partner_exists`.
summed_test_data <- function() {
  set.seed(1)
  n_dyads <- 60
  n_single <- 30
  dyads <- tibble::tibble(
    dyad_id = rep(seq_len(n_dyads), each = 2),
    person_id = seq_len(2 * n_dyads),
    partnered = TRUE,
    y = rep(stats::rnorm(n_dyads), each = 2) + stats::rnorm(2 * n_dyads)
  )
  singles <- tibble::tibble(
    dyad_id = n_dyads + seq_len(n_single),
    person_id = 2 * n_dyads + seq_len(n_single),
    partnered = FALSE,
    y = stats::rnorm(n_single, sd = sqrt(2))
  )
  prepare_dyad_data(
    dplyr::bind_rows(dyads, singles),
    dyad = dyad_id,
    member = person_id,
    partner_exists = partnered,
    seed = 1
  )
}

fit_summed <- function(formula, data = summed_test_data(), ...) {
  suppressWarnings(glmmTMB::glmmTMB(formula, data = data, ...))
}

test_that("summed indicators recover the same covariance as summed columns", {
  skip_if_not_installed("glmmTMB")
  data <- summed_test_data()

  summed_terms <- fit_summed(
    y ~ 1 +
      (0 + I(.is_exchangeable + .is_singleton) | dyad_id) +
      (0 + I(.member_contrast_arbitrary + .is_singleton) | dyad_id),
    data,
    dispformula = ~0
  )

  # The same model with summed columns created beforehand.
  data$shared_pooled <- data$.is_exchangeable + data$.is_singleton
  data$difference_pooled <- data$.member_contrast_arbitrary + data$.is_singleton
  summed_columns <- fit_summed(
    y ~ 1 + (0 + shared_pooled | dyad_id) + (0 + difference_pooled | dyad_id),
    data,
    dispformula = ~0
  )

  automatic <- recover_exchangeable_covariance(summed_terms)
  supplied <- suppressWarnings(recover_exchangeable_covariance(
    summed_columns,
    block_pairings = list(
      shared_block = "(0 + shared_pooled | dyad_id)",
      difference_block = "(0 + difference_pooled | dyad_id)",
      difference_indicator = "difference_pooled",
      shared_indicator = "shared_pooled"
    )
  ))
  expect_equal(unname(automatic[[1L]]$varcov), unname(supplied[[1L]]$varcov), tolerance = 1e-6)
})

test_that("a difference block alone can add indicators", {
  skip_if_not_installed("glmmTMB")

  # `.is_exchangeable` stays in the model frame through the fixed effects.
  model <- fit_summed(
    y ~ 0 + .is_exchangeable + .is_singleton +
      (0 + I(.member_contrast_arbitrary + .is_singleton) | dyad_id)
  )
  result <- suppressWarnings(recover_exchangeable_covariance(
    model,
    block_pairings = list(
      shared_block = NULL,
      difference_block = "(0 + I(.member_contrast_arbitrary + .is_singleton) | dyad_id)",
      difference_indicator = ".member_contrast_arbitrary",
      shared_indicator = ".is_exchangeable"
    )
  ))
  expect_s3_class(result, "exchangeable_covariance")
})

test_that("the coding of summed columns is checked", {
  skip_if_not_installed("glmmTMB")

  # `.partner_exists` is 1 for dyad members too, so both sums reach 2 there.
  model <- fit_summed(
    y ~ 1 +
      (0 + I(.is_exchangeable + .partner_exists) | dyad_id) +
      (0 + I(.member_contrast_arbitrary + .partner_exists) | dyad_id),
    dispformula = ~0
  )
  expect_error(
    recover_exchangeable_covariance(model),
    "have incompatible coding",
    fixed = TRUE
  )

  # A shared block alone must keep its summed column 0/1 too.
  model <- fit_summed(y ~ 1 + (0 + I(.is_exchangeable + .partner_exists) | dyad_id))
  expect_error(
    suppressWarnings(recover_exchangeable_covariance(
      model,
      block_pairings = list(
        shared_block = "(0 + I(.is_exchangeable + .partner_exists) | dyad_id)",
        difference_block = NULL,
        difference_indicator = ".member_contrast_arbitrary",
        shared_indicator = ".is_exchangeable"
      )
    )),
    "must be 0 or 1 on every row",
    fixed = TRUE
  )

  # Invalid custom coding for complete dyads: both members of a dyad share one
  # sign. Adding an indicator that is 0 everywhere must not hide this.
  data <- summed_test_data()
  data$bad_difference <- ifelse(data$dyad_id %% 2 == 0, 1, -1) * data$.is_exchangeable
  data$always_zero <- 0
  model <- fit_summed(
    y ~ 1 +
      (0 + I(.is_exchangeable + always_zero) | dyad_id) +
      (0 + I(bad_difference + always_zero) | dyad_id),
    data,
    dispformula = ~0
  )
  expect_error(
    recover_exchangeable_covariance(
      model,
      block_pairings = list(
        shared_block = "(0 + I(.is_exchangeable + always_zero) | dyad_id)",
        difference_block = "(0 + I(bad_difference + always_zero) | dyad_id)",
        difference_indicator = "bad_difference",
        shared_indicator = ".is_exchangeable"
      )
    ),
    "group contains both -1 and +1",
    fixed = TRUE
  )
})
