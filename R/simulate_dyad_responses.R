#' Simulate response datasets for predictive checks
#'
#' `r lifecycle::badge("experimental")`
#' Generates new response datasets for the same observations and predictors.
#' Reuse them with [check_partner_dependence()] to check whether a fitted
#' model reproduces features of the observed data. For a complete example
#' see [check_partner_dependence()].
#'
#' @param model A fitted `glmmTMB` model.
#' @param nsim Number of complete response datasets to simulate. Default: 1000.
#' @param seed Optional seed for reproducible simulations, interpreted as an
#'   integer (see [set.seed()]). When supplied, the random-number state is restored
#'   after the function returns, or when it stops after an error.
#'
#' @return A `dyadMLM_response_simulations` object for use with
#'   [check_partner_dependence()].
#'
#' The result keeps all components in fitted-row order (after missing-data
#' exclusions):
#'
#' - `simulated_responses`: a matrix with `nsim` rows and one column per fitted
#'   observation. Each row is a complete simulated dataset.
#' - `observed_response` and `response_center`: numeric vectors with one value
#'   per fitted observation.
#' - `model_frame`: the data frame used for fitting, in the same row order.
#'
#' @section Supported models:
#' Currently supports unweighted `glmmTMB` models without zero inflation for
#' the following families:
#' - `gaussian(link = "identity")`
#' - `poisson(link = "log")`
#' - `glmmTMB::nbinom1(link = "log")`
#' - `glmmTMB::nbinom2(link = "log")`
#' - `glmmTMB::tweedie(link = "log")`
#' - `Gamma(link = "log")`
#' - `glmmTMB::beta_family(link = "logit")`
#'
#' [check_partner_dependence()] currently requires cross-sectional dyads.
#'
#' @section Technical details:
#' Each simulation draws new random effects and then new responses from the
#' fitted model. Random effects within each block are drawn together using
#' their fitted variances and correlations. This also applies to random effects
#' in the dispersion model, if present.
#'
#' Fitted parameters and predictors stay fixed. The model is not refitted, and
#' uncertainty in parameter estimates is not included. This is a *plug-in
#' predictive reference*. If dyads are the only grouping factor, the simulations
#' represent hypothetical new dyads under the same study design.
#'
#' `response_center` contains predictions with random effects set to zero.
#' By default, later checks subtract these same predictions from observed and
#' simulated responses. Both random-effect and observation-level variation
#' remain. With nonlinear links, setting random effects to zero generally
#' differs from averaging predictions over them.
#'
#' Predictor values remain unchanged, including any lagged responses used as
#' predictors.
#'
#' @export
simulate_dyad_responses <- function(model, nsim = 1000, seed = NULL) {
  if (!inherits(model, "glmmTMB")) {
    stop("`model` must be a fitted `glmmTMB` model.", call. = FALSE)
  }
  if (!requireNamespace("glmmTMB", quietly = TRUE)) {
    stop("Package `glmmTMB` is required to simulate responses.", call. = FALSE)
  }
  if (!is.numeric(nsim) || !rlang::is_scalar_integerish(nsim, finite = TRUE) ||
      nsim < 1 || nsim > .Machine$integer.max) {
    stop("`nsim` must be one positive whole number.", call. = FALSE)
  }
  nsim <- as.integer(nsim)

  if (!is.null(seed)) {
    seed <- as.integer(seed)
    withr::local_seed(seed)
  }

  family <- stats::family(model)
  supported <- c("gaussian:identity", "poisson:log", "nbinom1:log",
                 "nbinom2:log", "tweedie:log", "Gamma:log", "beta:logit")
  if (!paste(family$family, family$link, sep = ":") %in% supported) {
    stop("Unsupported family/link. ",
         "See the supported models in ?simulate_dyad_responses.", call. = FALSE)
  }
  if (any(stats::weights(model) != 1)) {
    stop("Predictive checks currently only support unweighted models.", call. = FALSE)
  }
  zi <- stats::terms(stats::formula(model, component = "zi"))
  if (attr(zi, "intercept") != 0L || length(attr(zi, "term.labels")) ||
      length(attr(zi, "offset"))) {
    stop("Predictive checks currently require `ziformula = ~ 0`.", call. = FALSE)
  }

  # frame contains retained fitting rows. Observed and center are vectors that match those.
  # newdata = NULL below prevents na.exclude from padding omitted rows back in.
  frame <- stats::model.frame(model)
  observed <- stats::model.response(frame)
  if (!is.numeric(observed) || !is.null(dim(observed)) ||
      any(!is.finite(observed))) {
    stop("Expected one numeric response per fitted row; other formats need an adapter.",
         call. = FALSE)
  }
  center <- as.numeric(stats::predict(model, newdata = NULL,
                                     type = "response", re.form = NA))

  # glmmTMB simCode = 2 redraws whole blocks; always restore the prior settings.
  components <- c("terms", "termszi", "termsdisp")
  # original is a component -> term list of settings, not random-effect draws.
  # The model environment is shared with the caller, hence the on.exit restoration.
  original <- model$obj$env$data[components]
  if (any(vapply(original, is.null, logical(1)))) {
    stop("The fitted model has an unsupported simulation structure.", call. = FALSE)
  }
  on.exit(model$obj$env$data[components] <- original, add = TRUE)
  for (component in components) {
    for (i in seq_along(original[[component]])) {
      model$obj$env$data[[component]][[i]]$simCode <- 2
    }
  }
  # simulate() returns a data frame with one column per draw. Transpose to an
  # nsim x nrow(frame) matrix: later checks process one complete dataset per row.
  simulated <- t(as.matrix(stats::simulate(model, nsim = nsim)))
  if (length(center) != nrow(frame) || any(!is.finite(center)) ||
      !is.numeric(simulated) || any(!is.finite(simulated)) ||
      !identical(dim(simulated), c(nsim, nrow(frame)))) {
    stop("Expected finite predictions and one simulated response per fitted row; ",
         "other response formats need an adapter.", call. = FALSE)
  }

  # Keep the frame with the draws so later checks resolve IDs in the same row order.
  structure(list(
    observed_response = as.numeric(observed), simulated_responses = simulated,
    response_center = center, model_frame = frame,
    backend = "glmmTMB", family = family$family, link = family$link,
    reference = "plug-in predictive", random_effects = "new",
    parameter_uncertainty = "excluded", nsim = nsim, seed = seed,
    call = match.call()
  ), class = c("dyadMLM_response_simulations", "list"))
}


#' Print simulated response datasets
#'
#' Prints the number and type of simulated datasets.
#'
#' @param x An object returned by [simulate_dyad_responses()].
#' @param ... Not used.
#'
#' @return `x`, invisibly.
#'
#' @keywords internal
#'
#' @export
print.dyadMLM_response_simulations <- function(x, ...) {
  cat("<dyadMLM response simulations>\n")
  cat(
    x$nsim,
    "complete", x$family, "response",
    if (x$nsim == 1L) "dataset" else "datasets",
    "from", x$backend,
    "for", length(x$observed_response), "fitted rows\n"
  )
  invisible(x)
}
