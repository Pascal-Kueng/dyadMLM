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

test_that("compare_interdep_models requires exact original data", {
  skip_if_not_installed("glmmTMB")

  data_one <- prepare_interdep_data(
    example_dyadic_crosssectional,
    group = coupleID,
    member = personID,
    role = gender
  )
  changed <- example_dyadic_crosssectional
  changed$satisfaction[1] <- changed$satisfaction[1] + 1e-10
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

test_that("compare_interdep_models checks source and fitted rows", {
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
  predictor_missing <- example_dyadic_crosssectional
  predictor_missing$extra_predictor <- seq_len(nrow(predictor_missing))
  predictor_missing$extra_predictor[1] <- NA_real_
  row_data <- prepare_interdep_data(
    predictor_missing,
    group = coupleID,
    member = personID,
    role = gender
  )

  complete_restricted <- glmmTMB::glmmTMB(
    satisfaction ~ 1 + us(1 | coupleID),
    data = complete_data
  )
  shorter_full <- glmmTMB::glmmTMB(
    satisfaction ~ gender,
    data = shorter_data
  )
  row_restricted <- glmmTMB::glmmTMB(
    satisfaction ~ 1,
    data = row_data
  )
  row_full <- glmmTMB::glmmTMB(
    satisfaction ~ gender + extra_predictor,
    data = row_data
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
      full = row_full,
      restricted = row_restricted
    ),
    "different observation rows"
  )
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
  expect_error(
    compare_interdep_models(
      full = restricted_model,
      restricted = full_model
    ),
    "`full` must have more estimated parameters"
  )

  printed <- capture.output(print(comparison))
  note <- match(
    "Mathematical nesting is assumed and cannot be verified from the data alone.",
    printed
  )
  expect_equal(printed[note + 1L], "")
})

test_that("compare_interdep_models rejects transformed and changed outcomes", {
  skip_if_not_installed("glmmTMB")

  model_data <- prepare_interdep_data(
    example_dyadic_crosssectional,
    group = coupleID,
    member = personID,
    role = gender
  )
  restricted_model <- glmmTMB::glmmTMB(
    satisfaction ~ 1,
    data = model_data
  )
  transformed_model <- glmmTMB::glmmTMB(
    I(satisfaction) ~ gender,
    data = model_data
  )

  expect_error(
    compare_interdep_models(
      full = transformed_model,
      restricted = restricted_model
    ),
    "Only an untransformed outcome"
  )

  model_data$satisfaction <- model_data$satisfaction + 1
  changed_model <- glmmTMB::glmmTMB(
    satisfaction ~ gender,
    data = model_data
  )
  expect_error(
    compare_interdep_models(
      full = changed_model,
      restricted = restricted_model
    ),
    "fitted outcome values differ"
  )
})

test_that("compare_interdep_models recovers local model data", {
  skip_if_not_installed("glmmTMB")

  fit_models <- function() {
    local_data <- prepare_interdep_data(
      example_dyadic_crosssectional,
      group = coupleID,
      member = personID,
      role = gender
    )
    list(
      restricted = glmmTMB::glmmTMB(satisfaction ~ 1, data = local_data),
      full = glmmTMB::glmmTMB(satisfaction ~ gender, data = local_data)
    )
  }

  models <- fit_models()
  comparison <- compare_interdep_models(
    full = models$full,
    restricted = models$restricted
  )

  expect_s3_class(comparison, "anova")
})

test_that("compare_interdep_models checks weights and offsets", {
  skip_if_not_installed("glmmTMB")

  data <- example_dyadic_crosssectional
  data$observation_weight <- 2
  data$observation_offset <- 0.25
  model_data <- prepare_interdep_data(
    data,
    group = coupleID,
    member = personID,
    role = gender
  )

  full_model <- glmmTMB::glmmTMB(
    satisfaction ~ gender,
    data = model_data
  )
  weighted_model <- glmmTMB::glmmTMB(
    satisfaction ~ 1,
    weights = observation_weight,
    data = model_data
  )
  offset_model <- glmmTMB::glmmTMB(
    satisfaction ~ 1,
    offset = observation_offset,
    data = model_data
  )

  expect_error(
    compare_interdep_models(full_model, weighted_model),
    "different observation weights"
  )
  expect_error(
    compare_interdep_models(full_model, offset_model),
    "different offsets"
  )
})
