test_that("compare_interdep_models compares reparameterized nested models", {
  skip_if_not_installed("glmmTMB")

  full_data <- prepare_interdep_data(
    example_dyadic_crosssectional_mixed,
    group = coupleID,
    member = personID,
    role = gender,
    seed = 123
  )
  restricted_data <- prepare_interdep_data(
    example_dyadic_crosssectional_mixed,
    group = coupleID,
    member = personID,
    role = gender,
    set_exchangeable_compositions = "male-female",
    pool_compositions = list(
      non_female_x_female = c("male-male", "female-male")
    ),
    seed = 123
  )

  full_model <- glmmTMB::glmmTMB(
    satisfaction ~ 0 +
      .i_is_female_x_male_female +
      .i_is_female_x_male_male +
      .i_is_female_x_female +
      .i_is_male_x_male +
      us(
        0 + .i_is_female_x_male_female + .i_is_female_x_male_male |
          coupleID
      ) +
      us(0 + .i_is_female_x_female | coupleID) +
      us(0 + .i_diff_female_x_female_arbitrary | coupleID) +
      us(0 + .i_is_male_x_male | coupleID) +
      us(0 + .i_diff_male_x_male_arbitrary | coupleID),
    dispformula = ~0,
    family = gaussian(),
    data = full_data
  )
  restricted_model <- glmmTMB::glmmTMB(
    satisfaction ~ 0 +
      .i_is_female_x_female +
      .i_is_non_female_x_female +
      us(0 + .i_is_female_x_female | coupleID) +
      us(0 + .i_diff_female_x_female_arbitrary | coupleID) +
      us(0 + .i_is_non_female_x_female | coupleID) +
      us(0 + .i_diff_non_female_x_female_arbitrary | coupleID),
    dispformula = ~0,
    family = gaussian(),
    data = restricted_data
  )

  comparison <- compare_interdep_models(
    full = full_model,
    restricted = restricted_model
  )

  expect_s3_class(comparison, "anova")
  expect_equal(comparison$`Chi Df`[2], 5)
  expect_equal(
    comparison$Chisq[2],
    2 * as.numeric(logLik(full_model) - logLik(restricted_model))
  )
  expect_lt(comparison$`Pr(>Chisq)`[2], 0.001)
})

test_that("compare_interdep_models rejects different original data", {
  skip_if_not_installed("glmmTMB")

  data_one <- prepare_interdep_data(
    example_dyadic_crosssectional,
    group = coupleID,
    member = personID,
    role = gender
  )
  changed <- example_dyadic_crosssectional
  changed$satisfaction[1] <- changed$satisfaction[1] + 1
  data_two <- prepare_interdep_data(
    changed,
    group = coupleID,
    member = personID,
    role = gender
  )

  model_one <- glmmTMB::glmmTMB(
    satisfaction ~ 1 + us(1 | coupleID),
    data = data_one
  )
  model_two <- glmmTMB::glmmTMB(
    satisfaction ~ gender + us(1 | coupleID),
    data = data_two
  )

  expect_error(
    compare_interdep_models(full = model_two, restricted = model_one),
    "Original column `satisfaction` differs"
  )
})

test_that("compare_interdep_models checks row counts and outcome missingness", {
  skip_if_not_installed("glmmTMB")

  complete_data <- prepare_interdep_data(
    example_dyadic_crosssectional,
    group = coupleID,
    member = personID,
    role = gender
  )
  fewer_rows <- example_dyadic_crosssectional[
    example_dyadic_crosssectional$coupleID != 1,
  ]
  shorter_data <- prepare_interdep_data(
    fewer_rows,
    group = coupleID,
    member = personID,
    role = gender
  )
  missing_outcome <- example_dyadic_crosssectional
  missing_outcome$satisfaction[1] <- NA_real_
  missing_data <- prepare_interdep_data(
    missing_outcome,
    group = coupleID,
    member = personID,
    role = gender
  )

  complete_restricted <- glmmTMB::glmmTMB(
    satisfaction ~ 1 + us(1 | coupleID),
    data = complete_data
  )
  complete_full <- glmmTMB::glmmTMB(
    satisfaction ~ gender + us(1 | coupleID),
    data = complete_data
  )
  shorter_full <- glmmTMB::glmmTMB(
    satisfaction ~ gender + us(1 | coupleID),
    data = shorter_data
  )
  missing_full <- glmmTMB::glmmTMB(
    satisfaction ~ gender + us(1 | coupleID),
    data = missing_data
  )

  expect_error(
    compare_interdep_models(
      full = shorter_full,
      restricted = complete_restricted
    ),
    "different numbers of rows"
  )
  expect_error(
    compare_interdep_models(
      full = missing_full,
      restricted = complete_restricted
    ),
    "different numbers of missing outcome values"
  )

  expect_silent(compare_interdep_models(
    full = complete_full,
    restricted = complete_restricted
  ))
})

test_that("compare_interdep_models supports binomial models", {
  skip_if_not_installed("glmmTMB")

  data <- example_dyadic_crosssectional
  data$binary_outcome <- as.integer(
    data$satisfaction > stats::median(data$satisfaction, na.rm = TRUE)
  )
  restricted_data <- prepare_interdep_data(
    data,
    group = coupleID,
    member = personID,
    role = gender
  )
  full_data <- prepare_interdep_data(
    data,
    group = coupleID,
    member = personID,
    role = gender
  )

  restricted_model <- glmmTMB::glmmTMB(
    binary_outcome ~ 1,
    family = stats::binomial(),
    data = restricted_data
  )
  full_model <- glmmTMB::glmmTMB(
    binary_outcome ~ gender,
    family = stats::binomial(),
    data = full_data
  )

  comparison <- compare_interdep_models(
    full = full_model,
    restricted = restricted_model
  )

  expect_s3_class(comparison, "anova")
  expect_equal(comparison$`Chi Df`[2], 1)
  expect_equal(
    comparison$Chisq[2],
    2 * as.numeric(logLik(full_model) - logLik(restricted_model))
  )
})

test_that("compare_interdep_models supports Poisson models", {
  skip_if_not_installed("glmmTMB")

  data <- example_dyadic_crosssectional
  data$count_outcome <- pmax(0L, as.integer(round(data$satisfaction)))
  restricted_data <- prepare_interdep_data(
    data,
    group = coupleID,
    member = personID,
    role = gender
  )
  full_data <- prepare_interdep_data(
    data,
    group = coupleID,
    member = personID,
    role = gender
  )

  restricted_model <- glmmTMB::glmmTMB(
    count_outcome ~ 1,
    family = stats::poisson(),
    data = restricted_data
  )
  full_model <- glmmTMB::glmmTMB(
    count_outcome ~ gender,
    family = stats::poisson(),
    data = full_data
  )

  comparison <- compare_interdep_models(
    full = full_model,
    restricted = restricted_model
  )

  expect_s3_class(comparison, "anova")
  expect_equal(comparison$`Chi Df`[2], 1)
  expect_equal(
    comparison$Chisq[2],
    2 * as.numeric(logLik(full_model) - logLik(restricted_model))
  )
})

test_that("compare_interdep_models agrees with anova.glmmTMB", {
  skip_if_not_installed("glmmTMB")

  model_data <- prepare_interdep_data(
    example_dyadic_crosssectional,
    group = coupleID,
    member = personID,
    role = gender
  )
  restricted_model <- glmmTMB::glmmTMB(
    satisfaction ~ 1 + us(1 | coupleID),
    data = model_data
  )
  full_model <- glmmTMB::glmmTMB(
    satisfaction ~ gender + us(1 | coupleID),
    data = model_data
  )

  reference <- stats::anova(restricted_model, full_model)
  comparison <- compare_interdep_models(
    full = full_model,
    restricted = restricted_model
  )

  expect_equal(comparison$Chisq[2], reference$Chisq[2])
  expect_equal(comparison$`Chi Df`[2], reference$`Chi Df`[2])
  expect_equal(comparison$`Pr(>Chisq)`[2], reference$`Pr(>Chisq)`[2])
  expect_identical(
    comparison$`Pr(>Chisq)`[2] < 0.05,
    reference$`Pr(>Chisq)`[2] < 0.05
  )
  expect_match(
    attr(comparison, "interpretation"),
    "provides evidence that .* fits the data worse"
  )

  printed <- capture.output(print(comparison))
  note <- match(
    "Mathematical nesting is assumed and cannot be verified from the data alone.",
    printed
  )
  expect_equal(printed[note + 1L], "")
})

test_that("a non-significant comparison is not described as equivalent", {
  skip_if_not_installed("glmmTMB")

  data <- example_dyadic_crosssectional
  set.seed(1)
  data$noise <- stats::rnorm(nrow(data))
  restricted_data <- prepare_interdep_data(
    data,
    group = coupleID,
    member = personID,
    role = gender
  )
  full_data <- prepare_interdep_data(
    data,
    group = coupleID,
    member = personID,
    role = gender
  )
  restricted_model <- glmmTMB::glmmTMB(
    satisfaction ~ 1,
    data = restricted_data
  )
  full_model <- glmmTMB::glmmTMB(
    satisfaction ~ noise,
    data = full_data
  )

  comparison <- compare_interdep_models(
    full = full_model,
    restricted = restricted_model
  )
  interpretation <- attr(comparison, "interpretation")

  expect_gte(comparison$`Pr(>Chisq)`[2], 0.05)
  expect_match(interpretation, "does not provide evidence")
  expect_match(interpretation, "does not establish equivalent fit")
})
