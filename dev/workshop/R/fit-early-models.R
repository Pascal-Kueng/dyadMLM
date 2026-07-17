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
  model_environment <- new.env(parent = environment(formula))
  model_environment$.early_model_data <- data
  environment(formula) <- model_environment

  model <- glmmTMB::glmmTMB(
    formula,
    dispformula = ~0,
    family = stats::gaussian(),
    data = data
  )
  # Keep the evaluated formula in the returned call so formula(model) remains
  # available after this helper's local objects have gone out of scope.
  model$call$formula <- formula
  model$call$data <- quote(.early_model_data)
  model
}

.prepare_early_model_data <- function(
    data, predictor, model_type, exchangeable = FALSE) {
  interdep::prepare_interdep_data(
    data,
    group = couple_id,
    member = person_id,
    role = role,
    predictors = !!rlang::sym(predictor),
    model_type = model_type,
    dsm_role_order = if (identical(model_type, "dsm")) {
      c("female", "male")
    },
    include_compositions = "female-male",
    set_exchangeable_compositions = if (exchangeable) "female-male",
    seed = if (exchangeable) 123
  )
}

# Each public helper draws the fitted diagram and invisibly returns its model.

fit_and_draw_distinguishable_apim <- function(
    data, predictor, outcome, labels = NULL) {
  variables <- .early_model_variable_names(
    data, rlang::ensym(predictor), rlang::ensym(outcome)
  )
  prepared <- .prepare_early_model_data(
    data, variables$predictor, model_type = "apim"
  )

  actor <- paste0(".i_", variables$predictor, "_actor")
  partner <- paste0(".i_", variables$predictor, "_partner")
  female <- ".i_is_female_x_male_female"
  male <- ".i_is_female_x_male_male"

  model_formula <- .early_model_formula(
    variables$outcome,
    c(
      "0", female, male,
      paste0(female, ":", actor), paste0(male, ":", actor),
      paste0(female, ":", partner), paste0(male, ":", partner),
      paste0("us(0 + ", female, " + ", male, " | couple_id)")
    )
  )
  model <- .fit_early_gaussian_model(model_formula, prepared)

  draw_apim_diagram("distinguishable", model = model, labels = labels)
  invisible(model)
}

fit_and_draw_exchangeable_apim <- function(
    data, predictor, outcome, labels = NULL) {
  variables <- .early_model_variable_names(
    data, rlang::ensym(predictor), rlang::ensym(outcome)
  )
  prepared <- .prepare_early_model_data(
    data, variables$predictor, model_type = "apim", exchangeable = TRUE
  )

  actor <- paste0(".i_", variables$predictor, "_actor")
  partner <- paste0(".i_", variables$predictor, "_partner")
  intercept <- ".i_is_female_x_male"
  difference <- ".i_diff_female_x_male_arbitrary"

  model_formula <- .early_model_formula(
    variables$outcome,
    c(
      "0", intercept, actor, partner,
      paste0("us(0 + ", intercept, " | couple_id)"),
      paste0("us(0 + ", difference, " | couple_id)")
    )
  )
  model <- .fit_early_gaussian_model(model_formula, prepared)

  draw_apim_diagram("exchangeable", model = model, labels = labels)
  invisible(model)
}

fit_and_draw_dim <- function(data, predictor, outcome, labels = NULL) {
  variables <- .early_model_variable_names(
    data, rlang::ensym(predictor), rlang::ensym(outcome)
  )
  prepared <- .prepare_early_model_data(
    data, variables$predictor, model_type = "dim", exchangeable = TRUE
  )

  mean <- paste0(".i_", variables$predictor, "_dyad_mean_gmc")
  deviation <- paste0(".i_", variables$predictor, "_within_dyad_dev")
  difference <- ".i_diff_female_x_male_arbitrary"

  model_formula <- .early_model_formula(
    variables$outcome,
    c(
      "1", mean, deviation, "us(1 | couple_id)",
      paste0("us(0 + ", difference, " | couple_id)")
    )
  )
  model <- .fit_early_gaussian_model(model_formula, prepared)

  draw_dim_diagram(model = model, labels = labels)
  invisible(model)
}

fit_and_draw_dsm <- function(data, predictor, outcome, labels = NULL) {
  variables <- .early_model_variable_names(
    data, rlang::ensym(predictor), rlang::ensym(outcome)
  )
  prepared <- .prepare_early_model_data(
    data, variables$predictor, model_type = "dsm"
  )

  mean <- paste0(".i_", variables$predictor, "_dyad_mean_gmc")
  difference <- paste0(".i_", variables$predictor, "_within_dyad_diff")
  role <- ".i_dsm_role_contrast"

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
