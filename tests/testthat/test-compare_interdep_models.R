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

  comparison <- compare_interdep_models(restricted_model, full_model)

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
    compare_interdep_models(model_one, model_two),
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
    compare_interdep_models(complete_restricted, shorter_full),
    "different numbers of rows"
  )
  expect_error(
    compare_interdep_models(row_restricted, row_full),
    "different observation rows"
  )
})

test_that("compare_interdep_models supports and checks model families", {
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
  gaussian_model <- glmmTMB::glmmTMB(
    binary_outcome ~ gender,
    family = stats::gaussian(),
    data = full_data
  )

  comparison <- compare_interdep_models(restricted_model, full_model)

  expect_s3_class(comparison, "anova")
  expect_equal(comparison$`Chi Df`[2], 1)
  expect_equal(
    comparison$Chisq[2],
    2 * as.numeric(logLik(full_model) - logLik(restricted_model))
  )
  expect_error(
    compare_interdep_models(restricted_model, gaussian_model),
    "same family and link"
  )
})

test_that("compare_interdep_models compares APIM, DIM, and DSM models", {
  skip_if_not_installed("glmmTMB")

  distinguishable_data <- prepare_interdep_data(
    example_dyadic_crosssectional,
    group = coupleID,
    member = personID,
    role = gender,
    predictors = communication,
    model_type = c("apim", "dsm"),
    dsm_role_order = c("female", "male")
  )
  exchangeable_data <- prepare_interdep_data(
    example_dyadic_crosssectional,
    group = coupleID,
    member = personID,
    role = gender,
    predictors = communication,
    model_type = c("apim", "dim"),
    set_exchangeable_compositions = "female-male",
    seed = 123
  )

  distinguishable_dsm <- glmmTMB::glmmTMB(
    satisfaction ~ 1 +
      .i_communication_dyad_mean_gmc +
      .i_communication_within_dyad_diff +
      .i_dsm_role_contrast +
      .i_communication_dyad_mean_gmc:.i_dsm_role_contrast +
      .i_communication_within_dyad_diff:.i_dsm_role_contrast +
      us(1 + .i_dsm_role_contrast | coupleID),
    dispformula = ~0,
    family = gaussian(),
    data = distinguishable_data
  )
  exchangeable_apim <- glmmTMB::glmmTMB(
    satisfaction ~ 0 + .i_is_female_x_male +
      .i_communication_actor +
      .i_communication_partner +
      us(0 + .i_is_female_x_male | coupleID) +
      us(0 + .i_diff_female_x_male_arbitrary | coupleID),
    dispformula = ~0,
    family = gaussian(),
    data = exchangeable_data
  )
  distinguishable_apim <- glmmTMB::glmmTMB(
    satisfaction ~ 0 +
      .i_is_female_x_male_female +
      .i_is_female_x_male_male +
      .i_is_female_x_male_female:.i_communication_actor +
      .i_is_female_x_male_male:.i_communication_actor +
      .i_is_female_x_male_female:.i_communication_partner +
      .i_is_female_x_male_male:.i_communication_partner +
      us(
        0 + .i_is_female_x_male_female + .i_is_female_x_male_male |
          coupleID
      ),
    dispformula = ~0,
    family = gaussian(),
    data = distinguishable_data
  )
  exchangeable_dim <- glmmTMB::glmmTMB(
    satisfaction ~ 1 +
      .i_communication_dyad_mean_gmc +
      .i_communication_within_dyad_dev +
      us(1 | coupleID) +
      us(0 + .i_diff_female_x_male_arbitrary | coupleID),
    dispformula = ~0,
    family = gaussian(),
    data = exchangeable_data
  )

  dsm_comparison <- compare_interdep_models(
    distinguishable_dsm,
    exchangeable_apim
  )
  apim_dim_comparison <- compare_interdep_models(
    distinguishable_apim,
    exchangeable_dim
  )

  expect_equal(dsm_comparison$`Chi Df`[2], 4)
  expect_equal(apim_dim_comparison$`Chi Df`[2], 4)
  expect_equal(dsm_comparison$Chisq[2], apim_dim_comparison$Chisq[2])
})

test_that("compare_interdep_models directs ordinary models to anova", {
  skip_if_not_installed("glmmTMB")

  plain_data <- example_dyadic_crosssectional
  smaller_model <- glmmTMB::glmmTMB(satisfaction ~ 1, data = plain_data)
  larger_model <- glmmTMB::glmmTMB(satisfaction ~ gender, data = plain_data)

  expect_error(
    compare_interdep_models(smaller_model, larger_model),
    "Use `stats::anova()`",
    fixed = TRUE
  )
})

test_that("compare_interdep_models sorts models and agrees with anova.glmmTMB", {
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
  comparison <- compare_interdep_models(restricted_model, full_model)
  reversed <- compare_interdep_models(full_model, restricted_model)

  expect_equal(comparison$Chisq[2], reference$Chisq[2])
  expect_equal(comparison$`Chi Df`[2], reference$`Chi Df`[2])
  expect_equal(comparison$`Pr(>Chisq)`[2], reference$`Pr(>Chisq)`[2])
  expect_identical(reversed, comparison)
  expect_identical(row.names(comparison), c("restricted_model", "full_model"))
  expect_identical(
    comparison$`Pr(>Chisq)`[2] < 0.05,
    reference$`Pr(>Chisq)`[2] < 0.05
  )
  expect_error(
    compare_interdep_models(restricted_model, restricted_model),
    "different numbers of estimated parameters"
  )

  printed <- capture.output(print(comparison))
  note <- match(
    paste0(
      "Assumes mathematical nesting and an appropriate chi-squared ",
      "reference distribution."
    ),
    printed
  )
  expect_equal(printed[note + 1L], "")
  expect_match(
    tail(printed, 1L),
    "`full_model` fits better than `restricted_model`",
    fixed = TRUE
  )
  expect_match(
    tail(printed, 1L),
    format.pval(comparison$`Pr(>Chisq)`[2], digits = 3, eps = 0.001),
    fixed = TRUE
  )

  set.seed(194)
  model_data$noise <- stats::rnorm(nrow(model_data))
  smaller_model <- glmmTMB::glmmTMB(satisfaction ~ 1, data = model_data)
  larger_model <- glmmTMB::glmmTMB(satisfaction ~ noise, data = model_data)
  no_clear_improvement <- compare_interdep_models(smaller_model, larger_model)
  printed <- capture.output(print(no_clear_improvement))

  expect_gt(no_clear_improvement$`Pr(>Chisq)`[2], 0.05)
  expect_match(
    tail(printed, 1L),
    "finds no clear improvement from `smaller_model` to `larger_model`",
    fixed = TRUE
  )
  expect_match(
    tail(printed, 1L),
    "This does not establish equal fit",
    fixed = TRUE
  )
  expect_match(
    tail(printed, 1L),
    format.pval(
      no_clear_improvement$`Pr(>Chisq)`[2],
      digits = 3,
      eps = 0.001
    ),
    fixed = TRUE
  )
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
    compare_interdep_models(restricted_model, transformed_model),
    "Only an untransformed outcome"
  )

  model_data$satisfaction <- model_data$satisfaction + 1
  changed_model <- glmmTMB::glmmTMB(
    satisfaction ~ gender,
    data = model_data
  )
  expect_error(
    compare_interdep_models(restricted_model, changed_model),
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
  comparison <- compare_interdep_models(models$restricted, models$full)

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
