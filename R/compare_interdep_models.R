#' Compare nested glmmTMB models fitted to equivalent data
#'
#' Performs a likelihood-ratio test for two nested `glmmTMB` models. The models
#' may use ordinary data frames or [interdep_data][prepare_interdep_data()]
#' objects, and their calls do not need to refer to the same R object. Models may
#' be supplied in either order. The model with fewer estimated parameters is
#' shown first in the result.
#'
#' @param model1,model2 Two fitted `glmmTMB` models to compare.
#'
#' @details
#' Both model calls must use named data-frame objects that remain available when
#' the models are compared. The checks assume these objects have not been
#' modified since fitting. All ordinary data columns must be identical,
#' including their types and attributes. For `interdep_data`, generated `.i_`
#' columns may differ, but the original columns must be identical. Ordinary and
#' prepared data may be compared with each other. Dyad metadata are checked when
#' both models use `interdep_data`. The function also checks fitted rows,
#' outcomes, weights and offsets, model family and link, maximum-likelihood
#' estimation, and model convergence. Each model must use the same untransformed
#' response column.
#'
#' These checks establish that the models use equivalent observations. They
#' cannot establish that one model is mathematically nested within the other.
#' The caller remains responsible for supplying genuinely nested models. The
#' usual chi-squared reference distribution may also be inappropriate when
#' tested variance parameters are on the boundary.
#'
#' @return An `anova`-style data frame containing model degrees of freedom,
#'   information criteria, log-likelihoods, the likelihood-ratio statistic, and
#'   its chi-squared p-value. When printed, a short conclusion interprets the
#'   test at the 5% significance level.
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
#'   compare_interdep_models(restricted_model, full_model)
#' }
#'
#' @export
compare_interdep_models <- function(model1, model2) {
  validate_comparison_model(model1, "model1")
  validate_comparison_model(model2, "model2")

  # Save the calling environment so we can find the original data objects.
  caller_env <- parent.frame()
  model1_data <- comparison_model_data(model1, caller_env, "model1")
  model2_data <- comparison_model_data(model2, caller_env, "model2")
  validate_comparison_data(
    model1,
    model2,
    model1_data,
    model2_data
  )

  # Use the argument expressions as row labels in the result.
  labels <- c(
    deparse1(substitute(model1)),
    deparse1(substitute(model2))
  )
  return(likelihood_ratio_comparison(model1, model2, labels))
}

# Model and data checks -----------------------------------------------------

validate_comparison_model <- function(model, name) {
  if (!inherits(model, "glmmTMB")) {
    stop(
      sprintf("`%s` must be a fitted `glmmTMB` model.", name),
      call. = FALSE
    )
  }
  if (isTRUE(model$modelInfo$REML)) {
    stop(
      "Both models must be fitted with maximum likelihood, not REML.",
      call. = FALSE
    )
  }
  if (!is.null(model$fit$convergence) &&
      !isTRUE(model$fit$convergence == 0)) {
    stop(sprintf("The `%s` model did not converge.", name), call. = FALSE)
  }
  # pdHess is NULL when the Hessian was not calculated, e.g. with se = FALSE.
  if (!is.null(model$sdr$pdHess) && !isTRUE(model$sdr$pdHess)) {
    stop(
      sprintf(
        "The `%s` model has a non-positive-definite Hessian matrix.",
        name
      ),
      call. = FALSE
    )
  }

  invisible(model)
}

comparison_model_data <- function(model, caller_env, argument) {
  data_call <- model$call$data
  if (!is.symbol(data_call)) {
    stop(
      sprintf(
        "The `%s` model must have been fitted with a named data frame in `data`.",
        argument
      ),
      call. = FALSE
    )
  }

  data_name <- as.character(data_call)
  model_formula <- stats::formula(model, component = "cond")

  # A model fitted inside a helper may keep its data with its formula.
  # Search there first, then where compare_interdep_models() was called.
  environments <- list(environment(model_formula), caller_env)

  for (search_env in environments) {
    if (!is.environment(search_env)) {
      next
    }
    if (exists(data_name, envir = search_env, inherits = TRUE)) {
      candidate <- get(data_name, envir = search_env, inherits = TRUE)
      if (is.data.frame(candidate)) {
        return(candidate)
      }
    }
  }

  stop(
    sprintf(
      paste0(
        "Could not recover the named data frame used by `%s`. ",
        "Keep it available when comparing models."
      ),
      argument
    ),
    call. = FALSE
  )
}

validate_comparison_data <- function(model1, model2,
                                     model1_data, model2_data) {
  if (nrow(model1_data) != nrow(model2_data)) {
    stop(
      "The two data objects have different numbers of rows.",
      call. = FALSE
    )
  }

  both_interdep <- inherits(model1_data, "interdep_data") &&
    inherits(model2_data, "interdep_data")

  if (both_interdep) {
    # Both preparations must agree on the columns that define the dyadic data.
    model1_meta <- attr(model1_data, "interdep")
    model2_meta <- attr(model2_data, "interdep")
    for (field in c("group", "member", "role", "time")) {
      if (!identical(model1_meta[[field]], model2_meta[[field]])) {
        stop(
          sprintf(
            "The two prepared datasets use different `%s` variables.",
            field
          ),
          call. = FALSE
        )
      }
    }
  }

  # Generated interdep columns may differ across model parameterizations.
  model1_columns <- names(model1_data)
  model2_columns <- names(model2_data)
  if (inherits(model1_data, "interdep_data")) {
    model1_columns <- model1_columns[!startsWith(model1_columns, ".i_")]
  }
  if (inherits(model2_data, "interdep_data")) {
    model2_columns <- model2_columns[!startsWith(model2_columns, ".i_")]
  }

  if (!setequal(model1_columns, model2_columns)) {
    stop(
      "The two data objects do not contain the same original columns.",
      call. = FALSE
    )
  }

  for (column in model1_columns) {
    if (!identical(model1_data[[column]], model2_data[[column]])) {
      stop(
        sprintf(
          "Column `%s` differs between the two data objects.",
          column
        ),
        call. = FALSE
      )
    }
  }

  # Inspect the left side directly so transformations such as log(y) fail.
  model1_formula <- stats::formula(model1, component = "cond")
  model2_formula <- stats::formula(model2, component = "cond")
  model1_response <- model1_formula[[2L]]
  model2_response <- model2_formula[[2L]]

  if (!is.symbol(model1_response) || !is.symbol(model2_response)) {
    stop(
      "Only an untransformed outcome stored in the data is supported.",
      call. = FALSE
    )
  }

  model1_response <- as.character(model1_response)
  model2_response <- as.character(model2_response)
  if (!identical(model1_response, model2_response)) {
    stop("The two models use different outcome variables.", call. = FALSE)
  }
  if (!model1_response %in% model1_columns) {
    stop(
      "Only an untransformed outcome stored in the data is supported.",
      call. = FALSE
    )
  }

  # Row names show which observations glmmTMB kept after handling missing data.
  model1_rows <- row.names(model1$frame)
  model2_rows <- row.names(model2$frame)
  if (!identical(model1_rows, model2_rows)) {
    stop(
      "The two models were fitted to different observation rows.",
      call. = FALSE
    )
  }

  # Compare what the models actually fitted, not only the current data objects.
  model1_outcome <- unname(stats::model.response(model1$frame))
  model2_outcome <- unname(stats::model.response(model2$frame))
  if (!identical(model1_outcome, model2_outcome)) {
    stop(
      "The fitted outcome values differ between the two models.",
      call. = FALSE
    )
  }

  # No weights means all observations have weight one.
  model1_weights <- stats::model.weights(model1$frame)
  model2_weights <- stats::model.weights(model2$frame)
  if (is.null(model1_weights)) model1_weights <- rep(1, length(model1_rows))
  if (is.null(model2_weights)) model2_weights <- rep(1, length(model2_rows))
  if (!identical(as.numeric(model1_weights), as.numeric(model2_weights))) {
    stop("The two models use different observation weights.", call. = FALSE)
  }

  # glmmTMB stores separate offsets for its three model components.
  offset_names <- c("offset", "zioffset", "dispoffset")
  model1_offsets <- model1$obj$env$data[offset_names]
  model2_offsets <- model2$obj$env$data[offset_names]
  if (!identical(model1_offsets, model2_offsets)) {
    stop("The two models use different offsets.", call. = FALSE)
  }

  model1_family <- model1$modelInfo$family
  model2_family <- model2$modelInfo$family
  same_family <- identical(model1_family$family, model2_family$family)
  same_link <- identical(model1_family$link, model2_family$link)
  if (!same_family || !same_link) {
    stop("The two models must use the same family and link.", call. = FALSE)
  }

  invisible(TRUE)
}

# Likelihood-ratio test and output -----------------------------------------

likelihood_ratio_comparison <- function(model1, model2, labels) {
  model1_log_lik <- stats::logLik(model1)
  model2_log_lik <- stats::logLik(model2)
  model1_df <- attr(model1_log_lik, "df")
  model2_df <- attr(model2_log_lik, "df")

  valid_df <- length(model1_df) == 1L && length(model2_df) == 1L &&
    is.finite(model1_df) && is.finite(model2_df)
  if (!valid_df) {
    stop(
      "Could not determine the models' numbers of parameters.",
      call. = FALSE
    )
  }
  if (model1_df == model2_df) {
    stop(
      "The two models must have different numbers of estimated parameters.",
      call. = FALSE
    )
  }

  if (model1_df < model2_df) {
    restricted <- model1
    full <- model2
    restricted_log_lik <- model1_log_lik
    full_log_lik <- model2_log_lik
    restricted_df <- model1_df
    full_df <- model2_df
  } else {
    restricted <- model2
    full <- model1
    restricted_log_lik <- model2_log_lik
    full_log_lik <- model1_log_lik
    restricted_df <- model2_df
    full_df <- model1_df
    labels <- rev(labels)
  }

  restricted_log_lik <- as.numeric(restricted_log_lik)
  full_log_lik <- as.numeric(full_log_lik)
  statistic <- 2 * (full_log_lik - restricted_log_lik)

  # Allow only a negligible negative value caused by numerical rounding.
  if (!is.finite(statistic) || statistic < -sqrt(.Machine$double.eps)) {
    stop(
      paste0(
        "The larger model has a lower log-likelihood than the smaller model. ",
        "Check convergence and nesting."
      ),
      call. = FALSE
    )
  }

  statistic <- max(0, statistic)
  df_difference <- full_df - restricted_df
  p_value <- stats::pchisq(statistic, df_difference, lower.tail = FALSE)

  formatted_p <- format.pval(p_value, digits = 3, eps = 0.001)
  if (startsWith(formatted_p, "<")) {
    p_text <- paste("p <", substring(formatted_p, 2L))
  } else {
    p_text <- paste("p =", formatted_p)
  }

  if (p_value < 0.05) {
    conclusion <- sprintf(
      paste0(
        "Conclusion (5%% level): The likelihood-ratio test provides evidence ",
        "that `%s` fits better than `%s` (%s)."
      ),
      labels[2], labels[1], p_text
    )
  } else {
    conclusion <- sprintf(
      paste0(
        "Conclusion (5%% level): The likelihood-ratio test finds no clear ",
        "improvement from `%s` to `%s` (%s). Based on this test, prefer `%s` ",
        "for parsimony. This does not establish equal fit."
      ),
      labels[1], labels[2], p_text, labels[1]
    )
  }

  # Build the table here because anova.glmmTMB() rejects different data names.
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
    "Likelihood-ratio test for nested models fitted to equivalent data",
    "Assumes mathematical nesting and an appropriate chi-squared reference distribution.",
    ""
  )
  attr(out, "conclusion") <- conclusion
  class(out) <- c("interdep_model_comparison", "anova", "data.frame")
  out
}

#' @export
#' @noRd
print.interdep_model_comparison <- function(x, ...) {
  # Print the usual ANOVA table first, then the plain-language conclusion.
  NextMethod()
  cat("\n", attr(x, "conclusion"), "\n", sep = "")
  invisible(x)
}
