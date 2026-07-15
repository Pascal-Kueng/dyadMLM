#' Compare nested models fitted to equivalent interdep data
#'
#' Performs a likelihood-ratio test for two nested `glmmTMB` models fitted to
#' separate [interdep_data][prepare_interdep_data()] objects. Unlike
#' `anova.glmmTMB()`, the model calls do not need to refer to the same R object.
#' The function instead checks that the prepared data contain the same original
#' observations before comparing the models.
#'
#' @param full The full (larger) fitted `glmmTMB` model.
#' @param restricted The restricted (smaller) fitted `glmmTMB` model.
#' @param alpha Significance level used for the printed interpretation.
#'
#' @details
#' Both model calls must use named `interdep_data` objects. The function checks
#' the original, non-`.i_` columns, structural dyad metadata, outcome values and
#' missingness, fitted row identities, model family and link,
#' maximum-likelihood estimation, and model convergence.
#'
#' These checks establish that the models use equivalent observations. They
#' cannot establish that one model is mathematically nested within the other.
#' The caller remains responsible for supplying a genuinely restricted model
#' and its corresponding full model. The usual chi-squared reference
#' distribution may also be inappropriate when tested variance parameters are
#' on the boundary.
#'
#' @return An `anova`-style data frame containing model degrees of freedom,
#'   information criteria, log-likelihoods, the likelihood-ratio statistic, and
#'   its chi-squared p-value. Printing the result adds a cautious interpretation
#'   based on `alpha`.
#'
#' @examples
#' if (requireNamespace("glmmTMB", quietly = TRUE)) {
#'   restricted_data <- prepare_interdep_data(
#'     example_dyadic_crosssectional,
#'     group = coupleID,
#'     member = personID,
#'     role = gender
#'   )
#'   full_data <- restricted_data
#'
#'   restricted_model <- glmmTMB::glmmTMB(
#'     satisfaction ~ 1 + us(1 | coupleID),
#'     data = restricted_data
#'   )
#'   full_model <- glmmTMB::glmmTMB(
#'     satisfaction ~ gender + us(1 | coupleID),
#'     data = full_data
#'   )
#'
#'   compare_interdep_models(
#'     full = full_model,
#'     restricted = restricted_model
#'   )
#' }
#'
#' @export
compare_interdep_models <- function(full, restricted, alpha = 0.05) {
  comparison_check(
    is.numeric(alpha) && length(alpha) == 1L && !is.na(alpha) &&
      alpha > 0 && alpha < 1,
    "`alpha` must be a single number between 0 and 1."
  )

  models <- list(restricted = restricted, full = full)
  labels <- c(
    restricted = deparse1(substitute(restricted)),
    full = deparse1(substitute(full))
  )
  validate_interdep_models(models)

  model_data <- list(
    restricted = interdep_model_data(restricted, parent.frame(), "restricted"),
    full = interdep_model_data(full, parent.frame(), "full")
  )
  validate_interdep_model_data(models, model_data)

  test <- interdep_likelihood_ratio(models)
  new_interdep_model_comparison(models, labels, test, alpha)
}

#' @export
print.interdep_model_comparison <- function(x, ...) {
  interpretation <- attr(x, "interpretation", exact = TRUE)

  modified <- x
  class(modified) <- setdiff(class(modified), "interdep_model_comparison")
  print(modified, ...)

  if (!is.null(interpretation)) {
    cat("\n", interpretation, "\n", sep = "")
  }
  invisible(x)
}

# Model and data checks -----------------------------------------------------

validate_interdep_models <- function(models) {
  comparison_check(
    all(vapply(models, inherits, logical(1), what = "glmmTMB")),
    "`restricted` and `full` must both be fitted `glmmTMB` models."
  )

  for (name in names(models)) {
    model <- models[[name]]
    comparison_check(
      !isTRUE(model$modelInfo$REML),
      "Both models must be fitted with maximum likelihood, not REML."
    )
    comparison_check(
      is.null(model$fit$convergence) || model$fit$convergence == 0,
      sprintf("The `%s` model did not converge.", name)
    )
    comparison_check(
      is.null(model$sdr$pdHess) || isTRUE(model$sdr$pdHess),
      sprintf("The `%s` model has a non-positive-definite Hessian matrix.", name)
    )
  }

  invisible(TRUE)
}

interdep_model_data <- function(model, caller_env, argument) {
  data_call <- model$call$data
  comparison_check(
    is.symbol(data_call),
    sprintf(
      "The `%s` model must have been fitted with a named `interdep_data` object in `data`.",
      argument
    )
  )

  data_name <- as.character(data_call)
  environments <- list(caller_env, environment(stats::formula(model)))
  for (env in environments) {
    if (is.environment(env) && exists(data_name, envir = env, inherits = TRUE)) {
      data <- get(data_name, envir = env, inherits = TRUE)
      comparison_check(
        inherits(data, "interdep_data"),
        sprintf("The data used by `%s` must inherit from `interdep_data`.", argument)
      )
      return(data)
    }
  }

  stop(
    sprintf(
      "Could not recover the data object used by `%s`; keep it available when comparing models.",
      argument
    ),
    call. = FALSE
  )
}

validate_interdep_model_data <- function(models, model_data) {
  restricted <- models$restricted
  full <- models$full
  restricted_data <- model_data$restricted
  full_data <- model_data$full

  comparison_check(
    nrow(restricted_data) == nrow(full_data),
    "The two prepared datasets have different numbers of rows."
  )

  restricted_meta <- attr(restricted_data, "interdep")
  full_meta <- attr(full_data, "interdep")
  for (field in c("group", "member", "role", "time")) {
    comparison_check(
      identical(restricted_meta[[field]], full_meta[[field]]),
      sprintf("The two prepared datasets use different `%s` variables.", field)
    )
  }

  restricted_original <- names(restricted_data)[
    !startsWith(names(restricted_data), ".i_")
  ]
  full_original <- names(full_data)[!startsWith(names(full_data), ".i_")]
  comparison_check(
    setequal(restricted_original, full_original),
    "The two prepared datasets do not contain the same original columns."
  )

  restricted_response_name <- all.vars(stats::formula(restricted))[1]
  full_response_name <- all.vars(stats::formula(full))[1]
  comparison_check(
    identical(restricted_response_name, full_response_name),
    "The two models use different outcome variables."
  )
  comparison_check(
    restricted_response_name %in% restricted_original,
    "Only an untransformed outcome stored in the prepared data is supported."
  )

  restricted_missing <- is.na(restricted_data[[restricted_response_name]])
  full_missing <- is.na(full_data[[full_response_name]])
  comparison_check(
    sum(restricted_missing) == sum(full_missing),
    "The two datasets have different numbers of missing outcome values."
  )
  comparison_check(
    identical(restricted_missing, full_missing),
    "The outcome has a different missing-value pattern."
  )

  for (column in restricted_original) {
    comparison_check(
      same_values(restricted_data[[column]], full_data[[column]]),
      sprintf("Original column `%s` differs between the two prepared datasets.", column)
    )
  }

  restricted_frame <- restricted$frame
  full_frame <- full$frame
  comparison_check(
    identical(row.names(restricted_frame), row.names(full_frame)),
    "The two models were fitted to different observation rows."
  )

  restricted_family <- restricted$modelInfo$family
  full_family <- full$modelInfo$family
  comparison_check(
    identical(restricted_family$family, full_family$family) &&
      identical(restricted_family$link, full_family$link),
    "The two models must use the same family and link."
  )

  invisible(TRUE)
}

same_values <- function(x, y) {
  isTRUE(all.equal(x, y, check.attributes = FALSE))
}

comparison_check <- function(condition, message) {
  if (!isTRUE(condition)) {
    stop(message, call. = FALSE)
  }
  invisible(TRUE)
}

# Likelihood-ratio test and output -----------------------------------------

interdep_likelihood_ratio <- function(models) {
  log_lik <- lapply(models, stats::logLik)
  df <- vapply(log_lik, attr, numeric(1), which = "df")

  comparison_check(
    df["full"] > df["restricted"],
    "`full` must have more estimated parameters than `restricted`."
  )

  log_lik <- vapply(log_lik, as.numeric, numeric(1))
  statistic <- 2 * (log_lik["full"] - log_lik["restricted"])
  comparison_check(
    is.finite(statistic) && statistic >= -sqrt(.Machine$double.eps),
    paste0(
      "The full model has a lower log-likelihood than the restricted model. ",
      "Check the model order, convergence, and nesting."
    )
  )

  statistic <- max(0, unname(statistic))
  df_difference <- unname(df["full"] - df["restricted"])
  list(
    log_lik = log_lik,
    df = df,
    statistic = statistic,
    df_difference = df_difference,
    p_value = stats::pchisq(statistic, df_difference, lower.tail = FALSE)
  )
}

new_interdep_model_comparison <- function(models, labels, test, alpha) {
  out <- data.frame(
    Df = test$df,
    AIC = vapply(models, stats::AIC, numeric(1)),
    BIC = vapply(models, stats::BIC, numeric(1)),
    logLik = test$log_lik,
    deviance = -2 * test$log_lik,
    Chisq = c(NA_real_, test$statistic),
    `Chi Df` = c(NA_real_, test$df_difference),
    `Pr(>Chisq)` = c(NA_real_, test$p_value),
    check.names = FALSE,
    row.names = labels
  )

  attr(out, "heading") <- c(
    "Likelihood-ratio test for nested models fitted to equivalent interdep data",
    "Mathematical nesting is assumed and cannot be verified from the data alone.",
    ""
  )
  attr(out, "interpretation") <- interdep_comparison_interpretation(labels, test, alpha)
  class(out) <- c("interdep_model_comparison", "anova", "data.frame")
  out
}

interdep_comparison_interpretation <- function(labels, test, alpha) {
  p <- if (test$p_value < 0.001) {
    "p < .001"
  } else {
    sprintf("p = %.3f", test$p_value)
  }
  test_text <- sprintf(
    "likelihood-ratio test: \u03c7\u00b2(%d) = %.2f, %s",
    test$df_difference,
    test$statistic,
    p
  )

  significant <- test$p_value < alpha
  conclusion <- sprintf(
    "the test %s that `%s` fits the data worse than `%s`",
    if (significant) "provides evidence" else "does not provide evidence",
    labels["restricted"],
    labels["full"]
  )
  caveat <- if (significant) "." else "; this does not establish equivalent fit."

  paste0(
    "Under the assumed nesting and chi-squared reference distribution, ",
    conclusion,
    " (", test_text, ")",
    caveat
  )
}
