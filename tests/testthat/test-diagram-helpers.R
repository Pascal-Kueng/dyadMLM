diagram_helper_candidates <- c(
  testthat::test_path("..", "..", "vignettes", "diagram-helpers.Rinc"),
  testthat::test_path(
    "..", "..", "00_pkg_src", "interdep", "vignettes",
    "diagram-helpers.Rinc"
  ),
  file.path("vignettes", "diagram-helpers.Rinc")
)
diagram_helper <- diagram_helper_candidates[
  file.exists(diagram_helper_candidates)
][1]
if (is.na(diagram_helper)) {
  stop("Could not find vignettes/diagram-helpers.Rinc for diagram tests.")
}
sys.source(diagram_helper, envir = environment())

draw_to_temporary_pdf <- function(code) {
  path <- tempfile(fileext = ".pdf")
  grDevices::pdf(path)
  device <- grDevices::dev.cur()
  on.exit({
    if (grDevices::dev.cur() == device) {
      grDevices::dev.off()
    }
    unlink(path)
  }, add = TRUE)
  force(code)
  grDevices::dev.off()
  invisible(path)
}

test_that("APIM diagrams extract distinguishable and exchangeable fits", {
  skip_if_not_installed("glmmTMB")

  distinguishable_data <- prepare_interdep_data(
    example_dyadic_crosssectional,
    group = coupleID,
    member = personID,
    role = gender,
    predictors = communication
  )
  distinguishable_fit <- glmmTMB::glmmTMB(
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
  distinguishable_values <- .extract_apim_diagram_values(
    distinguishable_fit, "distinguishable"
  )

  expect_named(
    distinguishable_values$estimates,
    c(
      "intercept_female", "intercept_male",
      "actor_female", "actor_male",
      "partner_female", "partner_male"
    )
  )
  expect_named(
    distinguishable_values$residuals,
    c("sd_female", "sd_male", "correlation")
  )
  expect_no_error(draw_to_temporary_pdf(draw_apim_diagram(
    "distinguishable", model = distinguishable_fit
  )))

  exchangeable_data <- prepare_interdep_data(
    example_dyadic_crosssectional,
    group = coupleID,
    member = personID,
    role = gender,
    predictors = communication,
    set_exchangeable_compositions = "female-male"
  )
  exchangeable_fit <- glmmTMB::glmmTMB(
    satisfaction ~ 0 +
      .i_is_female_x_male +
      .i_communication_actor +
      .i_communication_partner +
      us(0 + .i_is_female_x_male | coupleID) +
      us(0 + .i_diff_female_x_male_arbitrary | coupleID),
    dispformula = ~0,
    family = gaussian(),
    data = exchangeable_data
  )
  exchangeable_values <- .extract_apim_diagram_values(
    exchangeable_fit, "exchangeable"
  )

  expect_named(
    exchangeable_values$estimates,
    c("intercept", "actor", "partner")
  )
  expect_named(exchangeable_values$residuals, c("sd", "correlation"))
  expect_no_error(draw_to_temporary_pdf(draw_apim_diagram(
    "exchangeable", model = exchangeable_fit
  )))
  expect_error(
    draw_apim_diagram(
      "exchangeable", model = exchangeable_fit,
      estimates = exchangeable_values$estimates
    ),
    "either `model` or manual"
  )
})

test_that("DIM and DSM diagrams extract fitted glmmTMB objects", {
  skip_if_not_installed("glmmTMB")

  dim_data <- prepare_interdep_data(
    example_dyadic_crosssectional,
    group = coupleID,
    member = personID,
    predictors = communication,
    model_type = "dim",
    seed = 123
  )
  dim_fit <- glmmTMB::glmmTMB(
    satisfaction ~
      .i_communication_dyad_mean_gmc +
      .i_communication_within_dyad_dev +
      us(1 | coupleID) +
      us(0 + .i_diff_assumed_exchangeable_arbitrary | coupleID),
    dispformula = ~0,
    family = gaussian(),
    data = dim_data
  )
  dim_values <- .extract_dim_diagram_values(dim_fit)

  expect_named(dim_values$estimates, c("b0", "b_mean", "b_dev"))
  expect_named(dim_values$residuals, c("sd_mean", "sd_difference"))
  expect_no_error(draw_to_temporary_pdf(draw_dim_diagram(model = dim_fit)))

  dsm_data <- prepare_interdep_data(
    example_dyadic_crosssectional,
    group = coupleID,
    member = personID,
    role = gender,
    predictors = communication,
    model_type = "dsm",
    dsm_role_order = c("female", "male")
  )
  dsm_fit <- glmmTMB::glmmTMB(
    satisfaction ~
      .i_communication_dyad_mean_gmc +
      .i_communication_within_dyad_diff +
      .i_dsm_role_contrast +
      .i_communication_dyad_mean_gmc:.i_dsm_role_contrast +
      .i_communication_within_dyad_diff:.i_dsm_role_contrast +
      us(1 + .i_dsm_role_contrast | coupleID),
    dispformula = ~0,
    family = gaussian(),
    data = dsm_data
  )
  dsm_values <- .extract_dsm_diagram_values(dsm_fit)

  expect_named(
    dsm_values$estimates,
    c("a10", "a11", "a12", "a20", "a21", "a22")
  )
  expect_named(
    dsm_values$residuals,
    c("sd_mean", "sd_difference", "correlation")
  )
  expect_no_error(draw_to_temporary_pdf(draw_dsm_diagram(model = dsm_fit)))
})

test_that("mixed APIM diagrams extract every composition block", {
  skip_if_not_installed("glmmTMB")

  mixed_data <- prepare_interdep_data(
    example_dyadic_crosssectional_mixed,
    group = coupleID,
    member = personID,
    role = gender,
    seed = 123
  )
  mixed_fit <- glmmTMB::glmmTMB(
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
    data = mixed_data
  )
  values <- .extract_mixed_apim_diagram_values(mixed_fit)

  expect_named(
    values$estimates,
    c(
      "intercept_fm_female", "intercept_fm_male",
      "intercept_ff", "intercept_mm"
    )
  )
  expect_named(values$residuals, c("fm", "ff", "mm"))
  expect_no_error(draw_to_temporary_pdf(
    draw_mixed_apim_diagram(model = mixed_fit)
  ))
})

test_that("CFM diagrams extract fitted lavaan objects", {
  skip_if_not_installed("lavaan")

  cfm_source <- as.data.frame(example_dyadic_crosssectional)
  cfm_source$gender <- as.character(cfm_source$gender)
  cfm_data <- stats::reshape(
    cfm_source[
      c("coupleID", "gender", "communication", "satisfaction")
    ],
    idvar = "coupleID",
    timevar = "gender",
    direction = "wide"
  )
  names(cfm_data) <- gsub(".", "_", names(cfm_data), fixed = TRUE)
  cfm_data <- cfm_data[
    c(
      "coupleID",
      "communication_female", "communication_male",
      "satisfaction_female", "satisfaction_male"
    )
  ]
  cfm_model <- '
    communication_level =~
      1 * communication_female + 1 * communication_male
    satisfaction_level =~
      1 * satisfaction_female + 1 * satisfaction_male
    satisfaction_level ~ b_level * communication_level
    communication_female ~~ c_female * satisfaction_female
    communication_male ~~ c_male * satisfaction_male
  '
  cfm_fit <- suppressWarnings(lavaan::sem(
    cfm_model,
    data = cfm_data,
    estimator = "ML",
    missing = "fiml",
    meanstructure = TRUE
  ))
  values <- .extract_cfm_diagram_values(cfm_fit)

  expect_named(
    values,
    c(
      "b_level", "beta_level", "residual_correlations", "r_squared",
      "outcome_residual_variance", "admissible", "labels", "outcome_latent"
    )
  )
  expect_length(values$residual_correlations, 2)
  expect_no_error(draw_to_temporary_pdf(draw_cfm_diagram(
    model = cfm_fit,
    member_ids = c("F", "M"),
    member_names = c("Female", "Male")
  )))
})

test_that("fitted glmmTMB diagrams reject incomplete residual structures", {
  skip_if_not_installed("glmmTMB")

  data <- prepare_interdep_data(
    example_dyadic_crosssectional,
    group = coupleID,
    member = personID,
    predictors = communication,
    model_type = "dim",
    seed = 123
  )
  fit <- glmmTMB::glmmTMB(
    satisfaction ~
      .i_communication_dyad_mean_gmc +
      .i_communication_within_dyad_dev +
      us(1 | coupleID) +
      us(0 + .i_diff_assumed_exchangeable_arbitrary | coupleID),
    family = gaussian(),
    data = data
  )

  expect_error(
    draw_dim_diagram(model = fit),
    "dispformula = ~ 0",
    fixed = TRUE
  )
})

test_that("conceptual diagrams can omit residual components", {
  expect_no_error(draw_to_temporary_pdf(draw_apim_diagram(
    "distinguishable", show_residuals = FALSE
  )))
  expect_no_error(draw_to_temporary_pdf(draw_apim_diagram(
    "exchangeable", show_residuals = FALSE
  )))
  expect_no_error(draw_to_temporary_pdf(draw_dim_diagram(
    show_residuals = FALSE
  )))
  expect_no_error(draw_to_temporary_pdf(draw_dsm_diagram(
    show_residuals = FALSE
  )))
  expect_no_error(draw_to_temporary_pdf(draw_cfm_diagram(
    show_residuals = FALSE
  )))

  expect_error(
    draw_apim_diagram(show_residuals = NA),
    "`show_residuals` must be TRUE or FALSE.",
    fixed = TRUE
  )
})
