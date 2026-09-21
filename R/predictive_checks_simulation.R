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
#' - `observed_response` and `predicted_response`: numeric vectors with one value
#'   per fitted observation.
#' - `model_frame`: the data frame used for fitting, in the same row order.
#'
#' The `dyadMLM` attribute records the model and simulation settings, including
#' the seed.
#'
#' @section Supported models:
#' Supports unweighted `glmmTMB` models with the following families:
#' - `gaussian()`
#' - `poisson()`, `glmmTMB::compois()`, `glmmTMB::genpois()`, `glmmTMB::bell()`
#' - `glmmTMB::nbinom1()`, `glmmTMB::nbinom2()`, `glmmTMB::nbinom12()`
#' - `glmmTMB::truncated_poisson()`, `glmmTMB::truncated_nbinom1()`,
#'   `glmmTMB::truncated_nbinom2()`, `glmmTMB::truncated_compois()`,
#'   `glmmTMB::truncated_genpois()`
#' - `glmmTMB::tweedie()`
#' - `Gamma()`, `glmmTMB::ziGamma()`
#' - `glmmTMB::beta_family()`
#' - `glmmTMB::lognormal()`, `glmmTMB::skewnormal()`
#' - `glmmTMB::t_family()` with more than two degrees of freedom
#'
#' Zero-inflated and hurdle versions are supported where available. Checks
#' describe the combined response, including zeros, rather than each model
#' component separately. Random effects in `ziformula` are not yet supported.
#'
#' The model's fitted link is used for prediction and simulation. Predictions
#' and simulated responses must be finite.
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
#' `predicted_response` contains predicted mean responses with random effects
#' in the conditional model set to zero.
#' By default, later checks subtract these same predictions from observed and
#' simulated responses. Both random effects and observation-level noise still
#' contribute to response variance. With nonlinear links, setting random effects
#' to zero generally differs from averaging predictions over them.
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
  supported <- c(
    "gaussian", "poisson", "nbinom1", "nbinom2", "nbinom12", "compois", "genpois",
    "truncated_poisson", "truncated_nbinom1", "truncated_nbinom2",
    "truncated_compois", "truncated_genpois", "tweedie", "Gamma", "beta",
    "lognormal", "skewnormal", "bell", "t"
  )
  if (!family$family %in% supported) {
    stop("Unsupported family. ",
         "See the supported models in ?simulate_dyad_responses.", call. = FALSE)
  }
  if (any(stats::weights(model) != 1)) {
    stop("Predictive checks currently only support unweighted models.", call. = FALSE)
  }
  # glmmTMB currently keeps zero-inflation random effects in response predictions.
  if (length(model$obj$env$data$termszi) > 0L) {
    stop("Predictive checks do not yet support random effects in `ziformula`.",
         call. = FALSE)
  }
  if (family$family == "t" && glmmTMB::family_params(model) <= 2) {
    stop("Student-t predictive checks require more than two degrees of freedom ",
         "so that response variances and correlations are defined.", call. = FALSE)
  }

  frame <- stats::model.frame(model)
  observed <- stats::model.response(frame) # response variable from frame (vector)
  if (!is.numeric(observed) || !is.null(dim(observed)) ||
      any(!is.finite(observed))) {
    stop("Expected one numeric response per fitted row.",
         call. = FALSE)
  }

  # Predicted mean responses (one per fitted row), with random effects in the
  # conditional model set to zero.
  # newdata = NULL below prevents na.exclude from padding omitted rows back in.
  predicted <- as.numeric(stats::predict(model, newdata = NULL,
                                        type = "response", re.form = NA))

  # Select components whose random effects should be redrawn.
  components <- c("terms", "termszi", "termsdisp")
  # Store current simulation settings.
  original <- model$obj$env$data[components]
  if (any(vapply(original, is.null, logical(1)))) {
    stop("The fitted model has an unsupported simulation structure.", call. = FALSE)
  }
  # Restore original settings on exit, including after an error.
  on.exit(model$obj$env$data[components] <- original, add = TRUE)

  # Tell simulate() to draw new random effects for every block.
  for (component in components) {
    for (i in seq_along(original[[component]])) {
      model$obj$env$data[[component]][[i]]$simCode <- 2 # Redraws whole re-blocks.
    }
  }


  # simulate() returns a data frame with one column per draw. Transpose to an
  # nsim x nrow(frame) matrix.
  simulated <- t(as.matrix(stats::simulate(model, nsim = nsim)))

  if (length(predicted) != nrow(frame) || any(!is.finite(predicted)) ||
      !is.numeric(simulated) || any(!is.finite(simulated)) ||
      !identical(dim(simulated), c(nsim, nrow(frame)))) {
    stop("Expected finite predictions and one simulated response per fitted row.", call. = FALSE)
  }

  # Keep the frame with the draws so later checks resolve IDs in the same row order.
  out <- list(
    observed_response = as.numeric(observed),
    simulated_responses = simulated,
    predicted_response = predicted,
    model_frame = frame
  )

  attr(out, "dyadMLM") <- list(
    backend = "glmmTMB",
    family = family$family,
    link = family$link,
    reference = "plug-in predictive",
    random_effects = "new",
    parameter_uncertainty = "excluded",
    seed = seed
  )

  class(out) <- c("dyadMLM_response_simulations", "list")

  return(out)
}


#' Print simulated response datasets
#'
#' Prints the number and type of simulated datasets.
#'
#' @param x An object returned by [simulate_dyad_responses()].
#' @param ... Not used.
#'
#' @return `x`, invisible.
#'
#' @keywords internal
#'
#' @export
print.dyadMLM_response_simulations <- function(x, ...) {
  meta <- attr(x, "dyadMLM")
  nsim <- nrow(x$simulated_responses)
  cat("<dyadMLM response simulations>\n")
  cat(
    nsim,
    "complete", meta$family, "response",
    if (nsim == 1L) "dataset" else "datasets",
    "from", meta$backend,
    "for", length(x$observed_response), "fitted rows\n"
  )
  invisible(x)
}
