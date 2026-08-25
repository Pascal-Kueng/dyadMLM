# Development prototype: Gaussian brms partner-dependence checks
#
# This file explores the Bayesian object and plotting contract before that
# contract is added to the package API. Run `devtools::load_all()` from the
# package root before sourcing it so the prototype can reuse dyadMLM's current
# fitted-row resolver and partner-statistic helper.
#
# Scope: one numeric Gaussian response, identity link, cross-sectional pairs,
# and exactly one ordinary Gaussian dyad-level random intercept. Replicated
# datasets represent new dyads. ILD, existing-dyad predictions, additional
# grouping factors, random slopes, autocorrelation, multivariate models, and
# generalized families are intentionally excluded.


#' Prototype posterior-predictive response simulations for brms
#'
#' Simulates complete datasets for hypothetical new dyads. Each dataset uses
#' one posterior draw plus newly sampled dyad effects and observation error. By
#' default, every retained posterior draw is used once.
#'
#' The object stores one fixed response centre. Model-centred checks subtract it
#' from the observed response and every simulated response; raw checks leave
#' those same responses unchanged.
#'
#' **Statistical details.** For posterior draw \eqn{s}, \eqn{y_s^{rep}} is
#' generated with new dyad effects and new observation errors. The fixed center
#' is
#'
#' \deqn{\bar\mu = E(\mu \mid y),}
#'
#' where \eqn{\mu} omits group-level effects. For the supported Gaussian
#' identity model, this is also the expected response for a new dyad. Posterior
#' parameters vary across datasets, and each dataset receives new dyad effects
#' and observation errors; only the centre stays fixed.
#'
#' @param model A fitted univariate Gaussian identity-link `brmsfit` model with
#'   exactly one ordinary Gaussian random intercept.
#' @param nsim `NULL` to use every retained posterior draw, the default, or the
#'   number of posterior-predictive datasets to generate without replacement.
#'   A supplied number cannot exceed the available posterior draws.
#' @param seed `NULL` or one non-negative whole number used to reproduce draw
#'   selection, new dyad effects, and predictive responses.
#'
#' @return A `dyadMLM_brms_response_simulations_prototype` object containing
#'   posterior-predictive responses and the fixed population-level center.
#'
#' @references
#' Gelman, A., Meng, X.-L., & Stern, H. S. (1996). Posterior predictive
#' assessment of model fitness via realized discrepancies. *Statistica Sinica,
#' 6*, 733-807.
#'
#' Gelman, A. (2007). Comment: Bayesian checking of the second levels of
#' hierarchical models. *Statistical Science, 22*(3), 349-352.
#' [doi:10.1214/07-STS235A](https://doi.org/10.1214/07-STS235A).
#'
#' Buerkner, P.-C. (2017). `brms`: An R package for Bayesian multilevel models
#' using Stan. *Journal of Statistical Software, 80*(1), 1-28.
#' [doi:10.18637/jss.v080.i01](https://doi.org/10.18637/jss.v080.i01).
simulate_brms_partner_prototype <- function(
  model,
  nsim = NULL,
  seed = NULL
) {
  simulation_call <- match.call()

  if (!inherits(model, "brmsfit")) {
    stop("`model` must be a fitted `brmsfit` model.", call. = FALSE)
  }
  if (!requireNamespace("brms", quietly = TRUE)) {
    stop("Package `brms` is required for this prototype.", call. = FALSE)
  }
  if (inherits(model$formula, "mvbrmsformula")) {
    stop("The prototype requires a model with one response.", call. = FALSE)
  }

  if (!is.null(nsim)) {
    nsim <- validate_brms_prototype_whole_number(
      nsim,
      argument_name = "nsim",
      allow_zero = FALSE
    )
  }
  if (!is.null(seed)) {
    seed <- validate_brms_prototype_whole_number(
      seed,
      argument_name = "seed",
      allow_zero = TRUE
    )
  }

  model_family <- stats::family(model)
  if (!identical(model_family$family, "gaussian") ||
      !identical(model_family$link, "identity")) {
    stop(
      "The prototype supports only Gaussian identity-link models.",
      call. = FALSE
    )
  }

  response_formula <- model$formula$formula
  has_plain_response <-
    inherits(response_formula, "formula") &&
    length(response_formula) == 3L &&
    is.symbol(response_formula[[2L]])
  if (!has_plain_response) {
    stop(
      paste0(
        "The prototype requires a plain response without response-addition ",
        "terms such as `cens()` or `trunc()`, or response transformations."
      ),
      call. = FALSE
    )
  }

  model_frame <- stats::model.frame(model)
  observed_response <- stats::model.response(model_frame)
  if (!is.numeric(observed_response) ||
      length(observed_response) != nrow(model_frame) ||
      any(!is.finite(observed_response))) {
    stop(
      "The prototype requires one finite numeric response per fitted row.",
      call. = FALSE
    )
  }

  # Use brms's exported formula parser rather than deprecated fitted-object
  # slots so formula-based autocorrelation and grouping structures are visible.
  model_terms <- brms::brmsterms(model$formula)
  mean_terms <- model_terms$dpars$mu
  random_effect_terms <- mean_terms$re
  if (!is.data.frame(random_effect_terms) || nrow(random_effect_terms) != 1L) {
    stop(
      paste0(
        "The prototype requires exactly one ordinary dyad-level random-",
        "effect term."
      ),
      call. = FALSE
    )
  }

  random_effect_formula <- random_effect_terms$form[[1L]]
  random_effect_formula_terms <- stats::terms(random_effect_formula)
  random_effect_call <- random_effect_terms$gcall[[1L]]
  random_effect_is_intercept_only <-
    attr(random_effect_formula_terms, "intercept") == 1L &&
    length(attr(random_effect_formula_terms, "term.labels")) == 0L
  unsupported_random_effect <-
    !random_effect_is_intercept_only ||
    !is.list(random_effect_call) ||
    !identical(as.character(random_effect_call$dist), "gaussian") ||
    brms_prototype_has_text(random_effect_terms$gtype[[1L]]) ||
    brms_prototype_has_text(random_effect_terms$type[[1L]]) ||
    brms_prototype_has_text(random_effect_call$by) ||
    brms_prototype_has_text(random_effect_call$pw) ||
    brms_prototype_has_text(random_effect_call$cov) ||
    brms_prototype_has_text(random_effect_call$type)
  if (unsupported_random_effect) {
    stop(
      paste0(
        "The prototype requires one ordinary Gaussian random intercept; ",
        "non-Gaussian random effects, random slopes, and special grouping ",
        "structures are not supported."
      ),
      call. = FALSE
    )
  }

  if (!is.null(mean_terms$ac)) {
    stop("Autocorrelation structures are outside this prototype.", call. = FALSE)
  }

  grouping_factor <- as.character(random_effect_terms$group[[1L]])
  if (!grouping_factor %in% names(model_frame)) {
    stop(
      "The random-intercept grouping factor was not found in the model frame.",
      call. = FALSE
    )
  }
  grouping_values <- model_frame[[grouping_factor]]
  if (anyNA(grouping_values)) {
    stop("The grouping factor contains missing fitted values.", call. = FALSE)
  }

  posterior_draw_count <- brms::ndraws(model)
  if (length(posterior_draw_count) != 1L ||
      !is.finite(posterior_draw_count) || posterior_draw_count < 1L) {
    stop("The fitted model does not contain posterior draws.", call. = FALSE)
  }
  posterior_draw_count <- unname(as.integer(posterior_draw_count))
  if (!is.null(nsim) && nsim > posterior_draw_count) {
    stop(
      paste0(
        "`nsim` cannot exceed the number of posterior draws in `model` (",
        posterior_draw_count,
        ")."
      ),
      call. = FALSE
    )
  }

  # Relabel once per fitted grouping level. Both members of a dyad must receive
  # the same new label or the replicated partner dependence would be destroyed.
  prediction_data <- model_frame
  grouping_index <- match(
    as.character(grouping_values),
    unique(as.character(grouping_values))
  )
  new_prefix <- ".dyadMLM_new_dyad_"
  new_grouping_values <- paste0(new_prefix, grouping_index)
  while (any(new_grouping_values %in% as.character(grouping_values))) {
    new_prefix <- paste0(new_prefix, "_")
    new_grouping_values <- paste0(new_prefix, grouping_index)
  }
  prediction_data[[grouping_factor]] <- factor(new_grouping_values)

  if (!is.null(seed)) {
    has_old_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    if (has_old_seed) {
      old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    }
    on.exit({
      if (has_old_seed) {
        assign(".Random.seed", old_seed, envir = .GlobalEnv)
      } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
        rm(".Random.seed", envir = .GlobalEnv)
      }
    }, add = TRUE)
    set.seed(seed)
  }
  # brms uses every draw by default and subsamples without replacement when
  # `ndraws` is supplied. This call also generates new group effects and error.
  simulated_responses <- brms::posterior_predict(
    model,
    newdata = prediction_data,
    re_formula = NULL,
    ndraws = nsim,
    allow_new_levels = TRUE,
    sample_new_levels = "gaussian",
    sort = FALSE
  )
  nsim <- nrow(simulated_responses)

  # Compute one stable population-level centre from all posterior draws. Under
  # this Gaussian identity model it is also the marginal new-dyad response mean.
  # Using the original model frame preserves any population-level use of the
  # grouping variable; relabelled values are needed only to generate new effects.
  posterior_center_predictions <- brms::posterior_epred(
    model,
    newdata = model_frame,
    re_formula = NA,
    sort = FALSE
  )

  expected_response_dimensions <- c(nsim, nrow(model_frame))
  expected_center_dimensions <- c(posterior_draw_count, nrow(model_frame))
  responses_are_aligned <-
    is.numeric(simulated_responses) &&
    is.numeric(posterior_center_predictions) &&
    identical(dim(simulated_responses), expected_response_dimensions) &&
    identical(dim(posterior_center_predictions), expected_center_dimensions) &&
    all(is.finite(simulated_responses)) &&
    all(is.finite(posterior_center_predictions))
  if (!responses_are_aligned) {
    stop(
      paste0(
        "Posterior predictions were not returned as finite matrices aligned ",
        "with the fitted rows. Expected simulated dimensions ",
        paste(expected_response_dimensions, collapse = " x "),
        " and center dimensions ",
        paste(expected_center_dimensions, collapse = " x "),
        "; received ",
        paste(dim(simulated_responses), collapse = " x "),
        " and ",
        paste(dim(posterior_center_predictions), collapse = " x "),
        "."
      ),
      call. = FALSE
    )
  }
  response_center <- colMeans(posterior_center_predictions)

  simulations <- list(
    observed_response = as.numeric(observed_response),
    simulated_responses = simulated_responses,
    response_center = as.numeric(response_center),
    model_frame = model_frame,
    simulated_grouping_values = as.character(new_grouping_values),
    backend = "brms",
    family = model_family$family,
    link = model_family$link,
    reference = "posterior predictive",
    random_effects = "new",
    grouping_factor = grouping_factor,
    parameter_uncertainty = "included",
    center = "posterior mean population-level expected response",
    center_target = "new-dyad marginal mean (Gaussian identity)",
    center_draws = posterior_draw_count,
    target = "new-dyad posterior replication under the fitted covariate design",
    nsim = nsim,
    seed = seed,
    call = simulation_call
  )
  class(simulations) <- c(
    "dyadMLM_brms_response_simulations_prototype",
    "dyadMLM_response_simulations",
    "list"
  )

  simulations
}


#' Prototype posterior-predictive check of partner dependence
#'
#' Checks whether a fitted `brms` model reproduces how much partner responses
#' vary and how strongly they are associated in hypothetical new dyads.
#'
#' `"model-centred"` subtracts the same fixed posterior-mean expected response
#' from the observed response and every simulated dataset. Random dyad effects
#' remain. `"raw"` leaves those responses unchanged. Both options reuse the same
#' posterior-predictive datasets.
#'
#' The plot matches the `glmmTMB` version: a histogram shows the summary from
#' each simulated dataset, a red line shows the observed summary, and dashed
#' lines show the middle 95% of the simulated summaries. The practical question
#' is whether the model generates partner spread and association like those in
#' the observed data.
#'
#' **Statistical details.** Let \eqn{\bar\mu=E(\mu\mid y)} be the posterior
#' mean expected response with group-level effects omitted. The centred check
#' computes
#'
#' \deqn{T_{obs}=T(y-\bar\mu), \qquad
#' T_{rep,s}=T(y_s^{rep}-\bar\mu).}
#'
#' The raw check instead computes
#' \eqn{T_{obs}=T(y)} and \eqn{T_{rep,s}=T(y_s^{rep})}.
#'
#' Each \eqn{y_s^{rep}} is a complete dataset from one posterior draw, with new
#' dyad effects and observation errors. Thus, simulated summaries include both
#' posterior and new-dataset uncertainty. The observed position is descriptive,
#' not a calibrated p-value or decision rule.
#'
#' @param simulations An object from [simulate_brms_partner_prototype()].
#' @param dyad An unquoted or quoted fitted-model-frame column, or a vector
#'   aligned with the fitted rows.
#' @param role An optional unquoted or quoted fitted-model-frame column, or a
#'   fitted-row-aligned vector. Use `NULL` only for substantively
#'   interchangeable dyads.
#' @param plot Logical. Draw the predictive-statistic histogram when `TRUE`.
#' @param response Which values to summarize. `"model-centred"` (the default)
#'   subtracts the fixed new-dyad response centre; `"raw"` leaves responses
#'   unchanged. The same choice is applied to observed and simulated responses.
#'
#' @return Invisibly, the shared `dyadMLM_partner_check` object also returned for
#'   `glmmTMB` simulations.
#'
#' @references
#' Gelman, A., Meng, X.-L., & Stern, H. S. (1996). Posterior predictive
#' assessment of model fitness via realized discrepancies. *Statistica Sinica,
#' 6*, 733-807.
#'
#' Gelman, A. (2007). Comment: Bayesian checking of the second levels of
#' hierarchical models. *Statistical Science, 22*(3), 349-352.
#' [doi:10.1214/07-STS235A](https://doi.org/10.1214/07-STS235A).
#'
#' Hoff, P. D. (2015). Dyadic data analysis with `amen`. *arXiv:1506.08237*.
#' [doi:10.48550/arXiv.1506.08237](https://doi.org/10.48550/arXiv.1506.08237).
#'
#' Hartig, F. (2026). *DHARMa: Residual Diagnostics for Hierarchical
#' (Multi-Level / Mixed) Regression Models*, version 0.5.0.
#' [CRAN manual](https://cran.r-project.org/package=DHARMa).
#'
#' Gabry, J., Simpson, D., Vehtari, A., Betancourt, M., & Gelman, A. (2019).
#' Visualization in Bayesian workflow. *Journal of the Royal Statistical
#' Society: Series A, 182*(2), 389-402.
#' [doi:10.1111/rssa.12378](https://doi.org/10.1111/rssa.12378).
#'
check_brms_partner_prototype <- function(
  simulations,
  dyad,
  role = NULL,
  plot = TRUE,
  response = c("model-centred", "raw")
) {
  check_call <- match.call()
  response <- match.arg(response)

  if (!inherits(
    simulations,
    "dyadMLM_brms_response_simulations_prototype"
  )) {
    stop(
      "`simulations` must be created by `simulate_brms_partner_prototype()`.",
      call. = FALSE
    )
  }
  if (missing(dyad)) {
    stop("`dyad` must identify the dyad for each fitted row.", call. = FALSE)
  }

  resolve_fitted_argument <- getFromNamespace(
    "resolve_fitted_row_argument",
    "dyadMLM"
  )
  dyad_values <- resolve_fitted_argument(
    argument_quo = rlang::enquo(dyad),
    argument_name = "dyad",
    model_frame = simulations$model_frame
  )
  # The grouping factor whose new levels were simulated must describe the same
  # dyad partition used by the statistic. Names and labels may differ, but the
  # non-missing fitted rows must map one-to-one.
  grouping_values <-
    simulations$model_frame[[simulations$grouping_factor]]
  non_missing_dyad <- !is.na(dyad_values)
  dyad_group_mapping <- unique(data.frame(
    dyad = as.character(dyad_values[non_missing_dyad]),
    group = as.character(grouping_values[non_missing_dyad])
  ))
  dyad_matches_simulated_group <-
    nrow(dyad_group_mapping) ==
      length(unique(dyad_group_mapping$dyad)) &&
    nrow(dyad_group_mapping) ==
      length(unique(dyad_group_mapping$group))
  if (!dyad_matches_simulated_group) {
    stop(
      paste0(
        "`dyad` must identify the same grouping units as the model's `",
        simulations$grouping_factor,
        "` random intercept in this prototype."
      ),
      call. = FALSE
    )
  }
  role_values <- resolve_fitted_argument(
    argument_quo = rlang::enquo(role),
    argument_name = "role",
    model_frame = simulations$model_frame,
    allow_null = TRUE
  )

  # The prototype owns only posterior-predictive generation and validation of
  # its new-dyad target. Pairing, response selection, summaries, printing, and
  # plotting are exactly the package machinery also used for glmmTMB.
  partner_check_result <- check_partner_dependence(
    simulations,
    dyad = dyad_values,
    role = role_values,
    plot = FALSE,
    response = response
  )
  partner_check_result$call <- check_call

  if (plot) {
    graphics::plot(partner_check_result)
  }

  invisible(partner_check_result)
}


print.dyadMLM_brms_response_simulations_prototype <- function(x, ...) {
  cat("<dyadMLM brms response-simulation prototype>\n")
  cat(
    x$nsim,
    "posterior-predictive datasets for",
    length(x$observed_response),
    "fitted rows\n"
  )
  cat(
    "Target: new dyads (grouping factor: ",
    x$grouping_factor,
    ")\n",
    sep = ""
  )
  invisible(x)
}


validate_brms_prototype_whole_number <- function(
  value,
  argument_name,
  allow_zero
) {
  lower_bound <- if (allow_zero) 0 else 1
  if (!is.numeric(value) || length(value) != 1L ||
      !is.finite(value) || value < lower_bound || value %% 1 != 0 ||
      value > .Machine$integer.max) {
    qualifier <- if (allow_zero) "non-negative" else "positive"
    stop(
      paste0("`", argument_name, "` must be one ", qualifier, " whole number."),
      call. = FALSE
    )
  }
  as.integer(value)
}


brms_prototype_has_text <- function(value) {
  length(value) == 1L && !is.na(value) && nzchar(value)
}


# Minimal workflow after fitting a supported model:
#
# devtools::load_all(".")
# source("dev/diagnostic_checks/brms-partner-prototype.R")
# simulations <- simulate_brms_partner_prototype(model, seed = 123)
# check <- check_brms_partner_prototype(
#   simulations,
#   dyad = dyad_id,
#   role = role,
#   plot = FALSE
# )
# print(check)
# plot(check)
