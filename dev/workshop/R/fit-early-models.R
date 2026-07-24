.early_model_variable_names <- function(data, predictor, outcome) {
  predictor <- rlang::as_name(predictor)
  outcome <- rlang::as_name(outcome)

  required <- c("couple_id", "person_id", "role", predictor, outcome)
  missing <- setdiff(required, names(data))
  if (length(missing)) {
    stop(
      "The workshop data is missing: ", paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  if (!is.numeric(data[[predictor]]) || !is.numeric(data[[outcome]])) {
    stop("`predictor` and `outcome` must both be numeric.", call. = FALSE)
  }

  list(predictor = predictor, outcome = outcome)
}

.early_model_formula <- function(outcome, terms) {
  stats::as.formula(
    paste(outcome, "~", paste(terms, collapse = " + ")),
    env = parent.frame()
  )
}

.fit_early_gaussian_model <- function(formula, data) {
  # Give the prepared data a stable name in this function environment. glmmTMB
  # retains that environment with the fitted formula, allowing dyadMLM to
  # recover the data later when two models are compared.
  .early_model_data <- data

  model <- glmmTMB::glmmTMB(
    formula,
    dispformula = ~0,
    family = stats::gaussian(),
    data = .early_model_data
  )
  # Keep the evaluated formula in the returned call so formula(model) remains
  # available after this helper's local objects have gone out of scope.
  model$call$formula <- formula
  model
}

.prepare_early_model_data <- function(
    data, predictor, model_types, exchangeable = FALSE) {
  dyadMLM::prepare_dyad_data(
    data,
    dyad = couple_id,
    member = person_id,
    role = role,
    predictors = !!rlang::sym(predictor),
    model_types = model_types,
    dsm_role_order = if (identical(model_types, "dsm")) {
      c("female", "male")
    },
    # If other compositions are supplied, retain only `female-male` here.
    keep_compositions = "female-male",
    set_exchangeable_compositions = if (exchangeable) "female-male",
    seed = if (exchangeable) 123
  )
}

.grand_mean_center_apim_predictors <- function(data, predictor) {
  actor <- paste0(".dy_", predictor, "_actor")
  partner <- paste0(".dy_", predictor, "_partner")
  complete_pair <- is.finite(data[[actor]]) & is.finite(data[[partner]])

  if (!any(complete_pair)) {
    stop(
      "No complete actor-partner predictor pairs are available for centering.",
      call. = FALSE
    )
  }

  # One common centering constant preserves female-male differences and matches
  # the grand mean used for the DIM/DSM dyad-mean predictor.
  grand_mean <- mean(
    (data[[actor]][complete_pair] + data[[partner]][complete_pair]) / 2
  )
  data[[actor]] <- data[[actor]] - grand_mean
  data[[partner]] <- data[[partner]] - grand_mean
  data
}

# Each public helper draws the fitted diagram and invisibly returns its model.

fit_and_draw_distinguishable_apim <- function(
    data, predictor, outcome, labels = NULL) {
  variables <- .early_model_variable_names(
    data, rlang::ensym(predictor), rlang::ensym(outcome)
  )
  prepared <- .prepare_early_model_data(
    data, variables$predictor, model_types = "apim"
  )
  prepared <- .grand_mean_center_apim_predictors(
    prepared, variables$predictor
  )

  actor <- paste0(".dy_", variables$predictor, "_actor")
  partner <- paste0(".dy_", variables$predictor, "_partner")
  female_indicator <- ".dy_is_female"
  male_indicator <- ".dy_is_male"

  model_formula <- .early_model_formula(
    variables$outcome,
    c(
      "0", female_indicator, male_indicator,
      paste0(female_indicator, ":", actor),
      paste0(male_indicator, ":", actor),
      paste0(female_indicator, ":", partner),
      paste0(male_indicator, ":", partner),
      paste0(
        "us(0 + ", female_indicator, " + ", male_indicator, " | couple_id)"
      )
    )
  )
  model <- .fit_early_gaussian_model(model_formula, prepared)

  draw_apim_diagram(
    "distinguishable", model = model, labels = labels,
    predictors_centered = TRUE
  )
  invisible(model)
}

fit_and_draw_exchangeable_apim <- function(
    data, predictor, outcome, labels = NULL) {
  variables <- .early_model_variable_names(
    data, rlang::ensym(predictor), rlang::ensym(outcome)
  )
  prepared <- .prepare_early_model_data(
    data, variables$predictor, model_types = "apim", exchangeable = TRUE
  )
  prepared <- .grand_mean_center_apim_predictors(
    prepared, variables$predictor
  )

  actor <- paste0(".dy_", variables$predictor, "_actor")
  partner <- paste0(".dy_", variables$predictor, "_partner")
  exchangeable_indicator <- ".dy_is_exchangeable"
  member_contrast <- ".dy_member_contrast_arbitrary"

  model_formula <- .early_model_formula(
    variables$outcome,
    c(
      "0", exchangeable_indicator, actor, partner,
      paste0("us(0 + ", exchangeable_indicator, " | couple_id)"),
      paste0("us(0 + ", member_contrast, " | couple_id)")
    )
  )
  model <- .fit_early_gaussian_model(model_formula, prepared)

  draw_apim_diagram(
    "exchangeable", model = model, labels = labels,
    predictors_centered = TRUE
  )
  invisible(model)
}

fit_and_draw_dim <- function(data, predictor, outcome, labels = NULL) {
  variables <- .early_model_variable_names(
    data, rlang::ensym(predictor), rlang::ensym(outcome)
  )
  prepared <- .prepare_early_model_data(
    data, variables$predictor, model_types = "dim", exchangeable = TRUE
  )

  dyad_mean <- paste0(".dy_", variables$predictor, "_dyad_mean_gmc")
  member_deviation <- paste0(".dy_", variables$predictor, "_within_dyad_dev")
  member_contrast <- ".dy_member_contrast_arbitrary"

  model_formula <- .early_model_formula(
    variables$outcome,
    c(
      "1", dyad_mean, member_deviation, "us(1 | couple_id)",
      paste0("us(0 + ", member_contrast, " | couple_id)")
    )
  )
  model <- .fit_early_gaussian_model(model_formula, prepared)

  draw_dim_diagram(model = model, effect_unit = "dyad", labels = labels)
  invisible(model)
}

fit_and_draw_dsm <- function(data, predictor, outcome, labels = NULL) {
  variables <- .early_model_variable_names(
    data, rlang::ensym(predictor), rlang::ensym(outcome)
  )
  prepared <- .prepare_early_model_data(
    data, variables$predictor, model_types = "dsm"
  )

  mean <- paste0(".dy_", variables$predictor, "_dyad_mean_gmc")
  difference <- paste0(".dy_", variables$predictor, "_within_dyad_diff")
  role <- ".dy_dsm_role_contrast"

  model_formula <- .early_model_formula(
    variables$outcome,
    c(
      "1", mean, difference, role,
      paste0(mean, ":", role), paste0(difference, ":", role),
      paste0("us(1 + ", role, " | couple_id)")
    )
  )
  model <- .fit_early_gaussian_model(model_formula, prepared)

  draw_dsm_diagram(model = model, labels = labels)
  invisible(model)
}
