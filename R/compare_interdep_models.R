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
#'
#' @details
#' Both model calls must use named `interdep_data` objects that remain available
#' when the models are compared. The checks assume these objects have not been
#' modified since fitting. Each model must use the same untransformed response
#' column. The function requires exactly identical original, non-`.i_` columns,
#' including their types and attributes. It also checks structural dyad
#' metadata, fitted rows, outcomes, weights and offsets, model family and link,
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
#'   its chi-squared p-value.
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
compare_interdep_models <- function(full, restricted) {
  validate_interdep_model(restricted, "restricted")
  validate_interdep_model(full, "full")

  caller_env <- parent.frame()
  restricted_data <- interdep_model_data(restricted, caller_env, "restricted")
  full_data <- interdep_model_data(full, caller_env, "full")
  validate_interdep_model_data(
    restricted,
    full,
    restricted_data,
    full_data
  )

  labels <- c(
    deparse1(substitute(restricted)),
    deparse1(substitute(full))
  )
  interdep_likelihood_ratio(full, restricted, labels)
}

# Model and data checks -----------------------------------------------------

validate_interdep_model <- function(model, name) {
  comparison_check(
    inherits(model, "glmmTMB"),
    sprintf("`%s` must be a fitted `glmmTMB` model.", name)
  )
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

  invisible(model)
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
  model_formula <- stats::formula(model, component = "cond")
  environments <- list(environment(model_formula), caller_env)

  for (search_env in environments) {
    if (!is.environment(search_env)) {
      next
    }
    if (exists(data_name, envir = search_env, inherits = TRUE)) {
      candidate <- get(data_name, envir = search_env, inherits = TRUE)
      if (inherits(candidate, "interdep_data")) {
        return(candidate)
      }
    }
  }

  stop(
    sprintf(
      paste0(
        "Could not recover the named `interdep_data` object used by `%s`; ",
        "keep it available when comparing models."
      ),
      argument
    ),
    call. = FALSE
  )
}

validate_interdep_model_data <- function(restricted, full,
                                         restricted_data, full_data) {
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

  for (column in restricted_original) {
    comparison_check(
      identical(restricted_data[[column]], full_data[[column]]),
      sprintf(
        "Original column `%s` differs between the two prepared datasets.",
        column
      )
    )
  }

  restricted_formula <- stats::formula(restricted, component = "cond")
  full_formula <- stats::formula(full, component = "cond")
  restricted_response <- restricted_formula[[2L]]
  full_response <- full_formula[[2L]]

  comparison_check(
    is.symbol(restricted_response) && is.symbol(full_response),
    "Only an untransformed outcome stored in the prepared data is supported."
  )

  restricted_response <- as.character(restricted_response)
  full_response <- as.character(full_response)
  comparison_check(
    identical(restricted_response, full_response),
    "The two models use different outcome variables."
  )
  comparison_check(
    restricted_response %in% restricted_original,
    "Only an untransformed outcome stored in the prepared data is supported."
  )

  restricted_rows <- row.names(restricted$frame)
  full_rows <- row.names(full$frame)
  comparison_check(
    identical(restricted_rows, full_rows),
    "The two models were fitted to different observation rows."
  )
  comparison_check(
    identical(
      unname(stats::model.response(restricted$frame)),
      unname(stats::model.response(full$frame))
    ),
    "The fitted outcome values differ between the two models."
  )

  restricted_weights <- stats::model.weights(restricted$frame)
  full_weights <- stats::model.weights(full$frame)
  if (is.null(restricted_weights)) restricted_weights <- rep(1, length(restricted_rows))
  if (is.null(full_weights)) full_weights <- rep(1, length(full_rows))
  comparison_check(
    identical(as.numeric(restricted_weights), as.numeric(full_weights)),
    "The two models use different observation weights."
  )

  restricted_offset <- stats::model.offset(restricted$frame)
  full_offset <- stats::model.offset(full$frame)
  if (is.null(restricted_offset)) restricted_offset <- rep(0, length(restricted_rows))
  if (is.null(full_offset)) full_offset <- rep(0, length(full_rows))
  comparison_check(
    identical(as.numeric(restricted_offset), as.numeric(full_offset)),
    "The two models use different offsets."
  )

  restricted_family <- restricted$modelInfo$family
  full_family <- full$modelInfo$family
  same_family <- identical(restricted_family$family, full_family$family)
  same_link <- identical(restricted_family$link, full_family$link)
  comparison_check(
    same_family && same_link,
    "The two models must use the same family and link."
  )

  invisible(TRUE)
}

comparison_check <- function(condition, message) {
  if (!isTRUE(condition)) {
    stop(message, call. = FALSE)
  }
  invisible(TRUE)
}

# Likelihood-ratio test and output -----------------------------------------

interdep_likelihood_ratio <- function(full, restricted, labels) {
  restricted_log_lik <- stats::logLik(restricted)
  full_log_lik <- stats::logLik(full)
  restricted_df <- attr(restricted_log_lik, "df")
  full_df <- attr(full_log_lik, "df")

  valid_df <- length(restricted_df) == 1L && length(full_df) == 1L &&
    is.finite(restricted_df) && is.finite(full_df)
  comparison_check(
    valid_df,
    "Could not determine the models' numbers of parameters."
  )
  comparison_check(
    full_df > restricted_df,
    "`full` must have more estimated parameters than `restricted`."
  )

  restricted_log_lik <- as.numeric(restricted_log_lik)
  full_log_lik <- as.numeric(full_log_lik)
  statistic <- 2 * (full_log_lik - restricted_log_lik)
  comparison_check(
    is.finite(statistic) && statistic >= -sqrt(.Machine$double.eps),
    paste0(
      "The full model has a lower log-likelihood than the restricted model. ",
      "Check the model order, convergence, and nesting."
    )
  )

  statistic <- max(0, statistic)
  df_difference <- full_df - restricted_df
  p_value <- stats::pchisq(statistic, df_difference, lower.tail = FALSE)
  out <- data.frame(
    Df = c(restricted_df, full_df),
    AIC = c(stats::AIC(restricted), stats::AIC(full)),
    BIC = c(stats::BIC(restricted), stats::BIC(full)),
    logLik = c(restricted_log_lik, full_log_lik),
    deviance = -2 * c(restricted_log_lik, full_log_lik),
    Chisq = c(NA_real_, statistic),
    `Chi Df` = c(NA_real_, df_difference),
    `Pr(>Chisq)` = c(NA_real_, p_value),
    check.names = FALSE,
    row.names = labels
  )

  attr(out, "heading") <- c(
    "Likelihood-ratio test for nested models fitted to equivalent interdep data",
    "Mathematical nesting is assumed and cannot be verified from the data alone.",
    ""
  )
  class(out) <- c("anova", "data.frame")
  out
}
