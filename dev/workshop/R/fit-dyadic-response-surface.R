fit_dyadic_response_surface <- function(data) {
  required_columns <- c(
    "couple_id", "person_id", "gender",
    "provided_support", "total_mvpa"
  )
  missing_columns <- setdiff(required_columns, names(data))

  if (length(missing_columns)) {
    stop(
      "The workshop data is missing: ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }

  if (
    !is.numeric(data$provided_support) ||
    !is.numeric(data$total_mvpa)
  ) {
    stop(
      "`provided_support` and `total_mvpa` must be numeric.",
      call. = FALSE
    )
  }

  # 1. Validate the dyadic structure and create each person's actor and partner
  #    support values. For this example, retain female-male couples only.
  prepared <- dyadMLM::prepare_dyad_data(
    data,
    dyad = couple_id,
    member = person_id,
    role = gender,
    predictors = provided_support,
    model_types = "apim",
    keep_compositions = "female-male"
  )

  if (
    any(!is.finite(prepared$provided_support)) ||
    any(!is.finite(prepared$total_mvpa))
  ) {
    stop(
      "This workshop example requires complete support and MVPA observations.",
      call. = FALSE
    )
  }

  # 2. Keep the response-surface axes fixed for both outcome equations:
  #       X = the female partner's support
  #       Y = the male partner's support
  #
  #    The actor and partner columns swap meaning across rows. These two lines
  #    undo that swap, so a male outcome is still modeled on the same X-Y axes
  #    as a female outcome.
  model_data <- prepared |>
    tibble::as_tibble() |>
    dplyr::rename(
      role = gender,
      actor_support = .dy_provided_support_actor,
      partner_support = .dy_provided_support_partner
    ) |>
    dplyr::mutate(
      female_support = dplyr::if_else(
        role == "female",
        actor_support,
        partner_support
      ),
      male_support = dplyr::if_else(
        role == "male",
        actor_support,
        partner_support
      )
    )

  # Both partner predictors use one pooled centering constant. Therefore,
  # X = Y still means that the two partners report the same amount of support.
  support_center <- mean(model_data$actor_support)

  model_data <- model_data |>
    dplyr::mutate(
      female_support_c = female_support - support_center,
      male_support_c = male_support - support_center,
      female_support_sq = female_support_c^2,
      support_product = female_support_c * male_support_c,
      male_support_sq = male_support_c^2
    )

  # 3. Fit both polynomial regressions in one double-intercept model.
  #
  # `role` selects one intercept and one set of five polynomial coefficients
  # for each partner. With observation-level dispersion fixed near zero, the
  # 2 x 2 unstructured dyad block represents the residual variances of female
  # and male MVPA and their residual covariance. This is the multilevel
  # equivalent of the joint Gaussian SEM used by Schönbrodt et al. (2018).
  fit <- glmmTMB::glmmTMB(
    total_mvpa ~ 0 + role +
      role:(
        female_support_c +
        male_support_c +
        female_support_sq +
        support_product +
        male_support_sq
      ) +
      us(0 + role | couple_id),
    dispformula = ~0,
    family = stats::gaussian(),
    REML = FALSE,
    na.action = stats::na.fail,
    data = model_data
  )

  if (
    fit$fit$convergence != 0 ||
    !isTRUE(fit$sdr$pdHess)
  ) {
    stop(
      "The joint dyadic response surface model did not converge cleanly.",
      call. = FALSE
    )
  }

  fixed_effects <- glmmTMB::fixef(fit)$cond

  fixed_effect <- function(term) {
    estimate <- unname(fixed_effects[term])
    if (length(estimate) != 1 || !is.finite(estimate)) {
      stop("Could not recover model coefficient `", term, "`.", call. = FALSE)
    }
    estimate
  }

  # 4. Put the fitted coefficients into standard response-surface notation.
  #    The X and Y meanings do not change between the two outcome equations.
  surface_coefficients <- list(
    female = c(
      b0 = fixed_effect("rolefemale"),
      x = fixed_effect("rolefemale:female_support_c"),
      y = fixed_effect("rolefemale:male_support_c"),
      x2 = fixed_effect("rolefemale:female_support_sq"),
      xy = fixed_effect("rolefemale:support_product"),
      y2 = fixed_effect("rolefemale:male_support_sq")
    ),
    male = c(
      b0 = fixed_effect("rolemale"),
      x = fixed_effect("rolemale:female_support_c"),
      y = fixed_effect("rolemale:male_support_c"),
      x2 = fixed_effect("rolemale:female_support_sq"),
      xy = fixed_effect("rolemale:support_product"),
      y2 = fixed_effect("rolemale:male_support_sq")
    )
  )

  derive_surface_parameters <- function(coefficients) {
    c(
      # Slope and curvature along the line of congruence, X = Y.
      a1 = coefficients[["x"]] + coefficients[["y"]],
      a2 = coefficients[["x2"]] + coefficients[["xy"]] +
        coefficients[["y2"]],
      # Slope and curvature along the line of incongruence, X = -Y.
      a3 = coefficients[["x"]] - coefficients[["y"]],
      a4 = coefficients[["x2"]] - coefficients[["xy"]] +
        coefficients[["y2"]],
      # Difference between the female- and male-score squared terms.
      a5 = coefficients[["x2"]] - coefficients[["y2"]]
    )
  }

  female_surface <- derive_surface_parameters(surface_coefficients$female)
  male_surface <- derive_surface_parameters(surface_coefficients$male)
  surface_parameters <- c(
    stats::setNames(female_surface, paste0(names(female_surface), "f")),
    stats::setNames(male_surface, paste0(names(male_surface), "m"))
  )

  fitted_dyad_covariance <- as.matrix(
    glmmTMB::VarCorr(fit)$cond$couple_id
  )
  outcome_residual_covariance <- matrix(
    as.numeric(fitted_dyad_covariance),
    nrow = 2,
    dimnames = list(c("female", "male"), c("female", "male"))
  )
  diag(outcome_residual_covariance) <-
    diag(outcome_residual_covariance) + stats::sigma(fit)^2
  residual_correlation <-
    outcome_residual_covariance["female", "male"] /
    sqrt(
      outcome_residual_covariance["female", "female"] *
        outcome_residual_covariance["male", "male"]
    )

  # For each outcome, R-squared compares the observed values with predictions
  # from the fixed response surface. Excluding dyad effects is important here:
  # their unstructured covariance is how this model represents residuals.
  fixed_surface_prediction <- stats::predict(
    fit,
    re.form = NA,
    type = "response"
  )
  variance_explained <- function(observed, predicted) {
    1 -
      sum((observed - predicted)^2) /
        sum((observed - mean(observed))^2)
  }
  r2 <- c(
    female_mvpa = variance_explained(
      model_data$total_mvpa[model_data$role == "female"],
      fixed_surface_prediction[model_data$role == "female"]
    ),
    male_mvpa = variance_explained(
      model_data$total_mvpa[model_data$role == "male"],
      fixed_surface_prediction[model_data$role == "male"]
    )
  )

  structure(
    list(
      fit = fit,
      data = model_data,
      support_center = support_center,
      fixed_effects = fixed_effects,
      residual_covariance = outcome_residual_covariance,
      surface_parameters = surface_parameters,
      surface_coefficients = surface_coefficients,
      residual_correlation = residual_correlation,
      r2 = r2
    ),
    class = "workshop_drsa"
  )
}
