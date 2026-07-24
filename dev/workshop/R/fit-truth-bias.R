fit_truth_bias <- function(data) {
  required_columns <- c(
    "couple_id", "person_id", "gender",
    "provided_support", "received_support"
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
    !is.numeric(data$received_support)
  ) {
    stop(
      "`provided_support` and `received_support` ",
      "must be numeric.",
      call. = FALSE
    )
  }

  # Each row is a perceiver. The perceiver's received-support report is the
  # judgment, their own provided support is the assumed-similarity predictor,
  # and their partner's provided support is the operational truth criterion.
  prepared <- dyadMLM::prepare_dyad_data(
    data,
    dyad = couple_id,
    member = person_id,
    role = gender,
    predictors = provided_support,
    model_types = "apim",
    keep_compositions = "female-male"
  )

  model_data <- prepared |>
    tibble::as_tibble() |>
    dplyr::rename(
      role = gender,
      own_provided_support = .dy_provided_support_actor,
      partner_provided_support = .dy_provided_support_partner
    )

  analysis_columns <- c(
    "provided_support", "received_support",
    "own_provided_support", "partner_provided_support"
  )
  columns_are_complete <- vapply(
    model_data[analysis_columns],
    function(variable) all(is.finite(variable)),
    logical(1)
  )
  if (!all(columns_are_complete)) {
    stop(
      "This workshop example requires complete provided- and received-support ",
      "observations for both partners.",
      call. = FALSE
    )
  }

  dyad_sizes <- dplyr::count(model_data, couple_id, name = "members")
  if (any(dyad_sizes$members != 2L)) {
    stop(
      "This workshop example requires exactly two observations per couple.",
      call. = FALSE
    )
  }

  # West and Kenny's centering is essential for the intercept interpretation:
  # subtract the same pooled truth mean from the judgment (J), truth predictor
  # (T), and bias predictor (B). Do not center received support on its own mean.
  truth_mean <- mean(model_data$provided_support)

  model_data <- model_data |>
    dplyr::mutate(
      received_support_c = received_support - truth_mean,
      own_provided_support_c = own_provided_support - truth_mean,
      partner_provided_support_c = partner_provided_support - truth_mean
    )

  # This is the distinguishable cross-sectional Truth and Bias model written as
  # one double-intercept multilevel model. The unstructured dyad block supplies
  # the two judgment-residual variances and their covariance; it is not a
  # substantive random-intercept process in this two-row-per-couple example.
  fit <- glmmTMB::glmmTMB(
    received_support_c ~ 0 + role +
      role:own_provided_support_c +
      role:partner_provided_support_c +
      us(0 + role | couple_id),
    dispformula = ~0,
    family = stats::gaussian(),
    REML = FALSE,
    na.action = stats::na.fail,
    data = model_data
  )

  if (fit$fit$convergence != 0 || !isTRUE(fit$sdr$pdHess)) {
    stop(
      "The cross-sectional Truth and Bias model did not converge cleanly.",
      call. = FALSE
    )
  }

  coefficient_table <- summary(fit)$coefficients$cond

  coefficient_value <- function(term, column) {
    value <- coefficient_table[term, column]
    if (length(value) != 1L || !is.finite(value)) {
      stop(
        "Could not recover `", column, "` for model term `", term, "`.",
        call. = FALSE
      )
    }
    unname(value)
  }

  fixed_terms <- c(
    intercept_female = "rolefemale",
    intercept_male = "rolemale",
    bias_female = "rolefemale:own_provided_support_c",
    bias_male = "rolemale:own_provided_support_c",
    truth_female = "rolefemale:partner_provided_support_c",
    truth_male = "rolemale:partner_provided_support_c"
  )
  estimates <- vapply(
    fixed_terms,
    coefficient_value,
    numeric(1),
    column = "Estimate"
  )
  p_values <- vapply(
    fixed_terms,
    coefficient_value,
    numeric(1),
    column = "Pr(>|z|)"
  )

  # glmmTMB conditions on the predictors, so actual similarity is calculated
  # once per couple as the raw correlation between partners' provided support.
  provided_support_by_role <- model_data |>
    dplyr::select(couple_id, role, provided_support) |>
    tidyr::pivot_wider(
      names_from = role,
      values_from = provided_support
    )
  actual_similarity_test <- stats::cor.test(
    provided_support_by_role$female,
    provided_support_by_role$male,
    method = "pearson"
  )

  # The correlation describes actual similarity, but the indirect-accuracy
  # decomposition needs an unstandardized path a. Its direction differs by
  # perceiver: the perceiver's own provision (B) is regressed on the partner's
  # provision (T). Indirect accuracy is a * b; total accuracy is t + a * b.
  actual_similarity_paths <- c(
    female = unname(stats::coef(stats::lm(
      female ~ male,
      data = provided_support_by_role
    ))[["male"]]),
    male = unname(stats::coef(stats::lm(
      male ~ female,
      data = provided_support_by_role
    ))[["female"]])
  )
  indirect_accuracy <- c(
    female = actual_similarity_paths[["female"]] *
      estimates[["bias_female"]],
    male = actual_similarity_paths[["male"]] * estimates[["bias_male"]]
  )
  total_accuracy <- c(
    female = estimates[["truth_female"]] + indirect_accuracy[["female"]],
    male = estimates[["truth_male"]] + indirect_accuracy[["male"]]
  )

  fitted_dyad_covariance <- as.matrix(
    glmmTMB::VarCorr(fit)$cond$couple_id
  )
  role_terms <- c(female = "rolefemale", male = "rolemale")
  outcome_residual_covariance <- fitted_dyad_covariance[
    role_terms, role_terms, drop = FALSE
  ]
  dimnames(outcome_residual_covariance) <- list(
    names(role_terms), names(role_terms)
  )
  diag(outcome_residual_covariance) <-
    diag(outcome_residual_covariance) + stats::sigma(fit)^2

  residuals <- c(
    sd_female = sqrt(outcome_residual_covariance["female", "female"]),
    sd_male = sqrt(outcome_residual_covariance["male", "male"]),
    correlation = outcome_residual_covariance["female", "male"] /
      sqrt(
        outcome_residual_covariance["female", "female"] *
          outcome_residual_covariance["male", "male"]
      )
  )

  structure(
    list(
      fit = fit,
      data = model_data,
      truth_mean = truth_mean,
      n_dyads = nrow(provided_support_by_role),
      estimates = estimates,
      p_values = p_values,
      residuals = residuals,
      residual_covariance = outcome_residual_covariance,
      actual_similarity_paths = actual_similarity_paths,
      indirect_accuracy = indirect_accuracy,
      total_accuracy = total_accuracy,
      actual_similarity = c(
        estimate = unname(actual_similarity_test$estimate),
        p_value = actual_similarity_test$p.value,
        conf_low = actual_similarity_test$conf.int[[1]],
        conf_high = actual_similarity_test$conf.int[[2]]
      )
    ),
    class = "workshop_truth_bias"
  )
}
