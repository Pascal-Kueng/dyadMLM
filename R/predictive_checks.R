#' Simulate complete response datasets for dyadic predictive checks
#'
#' Generates complete response datasets from a fitted model while preserving
#' its random-effect and covariance structure. The result can be used for
#' various predictive checks.
#'
#' The initial implementation supports scalar Gaussian identity-link
#' `glmmTMB` models only.
#'
#' @param model A fitted `glmmTMB` model.
#' @param nsim Number of complete response datasets to simulate. The default
#' is 1000.
#' @param seed `NULL` or one nonnegative whole number used to reproduce the
#'   simulations.
#'
#' @return A `dyadMLM_response_simulations` object containing the observed
#'   response, complete simulated responses, fitted response-scale center, and
#'   fitted-row metadata.
#'
#' @keywords internal
simulate_dyad_responses <- function(model, nsim = 1000, seed = NULL) {
  simulation_call <- match.call()

  if (!inherits(model, "glmmTMB")) {
    stop("`model` must be a fitted `glmmTMB` model.", call. = FALSE)
  }
  if (!requireNamespace("glmmTMB", quietly = TRUE)) {
    stop("Package `glmmTMB` is required to simulate responses.", call. = FALSE)
  }
  if (!is_one_whole_number(nsim) || nsim < 1) {
    stop("`nsim` must be one positive whole number.", call. = FALSE)
  }
  nsim <- as.integer(nsim)

  if (!is.null(seed)) {
    if (!is_one_whole_number(seed) || seed < 0) {
      stop("`seed` must be `NULL` or one nonnegative whole number.", call. = FALSE)
    }
    seed <- as.integer(seed)
  }

  model_family <- stats::family(model)
  if (!identical(model_family$family, "gaussian") ||
      !identical(model_family$link, "identity")) {
    stop(
      "Predictive checks currently support only Gaussian identity-link models.",
      call. = FALSE
    )
  }

  model_frame <- stats::model.frame(model)
  observed_response <- stats::model.response(model_frame)
  if (!is.numeric(observed_response) ||
      length(observed_response) != nrow(model_frame)) {
    stop("Predictive checks currently require one numeric response per fitted row.", call. = FALSE)
  }
  if (any(!is.finite(observed_response))) {
    stop("The fitted response contains non-finite values.", call. = FALSE)
  }

  model_weights <- stats::weights(model)
  if (!is.null(model_weights) && any(model_weights != 1)) {
    stop("Predictive checks currently require unit case weights.", call. = FALSE)
  }

  zero_inflation_terms <- stats::terms(
    stats::formula(model, component = "zi")
  )
  has_zero_inflation <- attr(zero_inflation_terms, "intercept") != 0L ||
    length(attr(zero_inflation_terms, "term.labels")) != 0L ||
    length(attr(zero_inflation_terms, "offset")) != 0L
  if (has_zero_inflation) {
    stop("Predictive checks currently require `ziformula = ~ 0`.", call. = FALSE)
  }

  fitted_response <- as.numeric(stats::predict(
    model,
    newdata = NULL,
    type = "response",
    re.form = NA
  ))
  if (length(fitted_response) != nrow(model_frame) ||
      any(!is.finite(fitted_response))) {
    stop(
      "Population-level fitted responses could not be aligned with the fitted rows.",
      call. = FALSE
    )
  }

  # glmmTMB stores simulation settings in the fitted object's mutable TMB
  # environment. A previous diagnostic may have changed them, so force new
  # random effects only for this call and then restore the exact prior settings.
  original_simulation_codes <- get_glmmTMB_simulation_codes(model)
  on.exit(
    set_glmmTMB_simulation_codes(model, original_simulation_codes),
    add = TRUE
  )
  # glmmTMB uses 2 for newly simulated random effects.
  random_simulation_codes <- lapply(
    original_simulation_codes,
    function(codes) rep(2, length(codes))
  )
  set_glmmTMB_simulation_codes(model, random_simulation_codes)

  simulated_responses <- simulate_complete_glmmTMB_responses(
    model,
    nsim = nsim,
    seed = seed
  )
  if (!is.numeric(simulated_responses) ||
      !identical(dim(simulated_responses), c(nsim, nrow(model_frame))) ||
      any(!is.finite(simulated_responses))) {
    stop(
      "Simulated responses were not returned as a finite simulation-by-fitted-row matrix.",
      call. = FALSE
    )
  }

  structure(
    list(
      observed_response = as.numeric(observed_response),
      simulated_responses = simulated_responses,
      fitted_response = fitted_response,
      model_frame = model_frame,
      backend = "glmmTMB",
      family = model_family$family,
      link = model_family$link,
      reference = "plug-in predictive",
      random_effects = "new",
      nsim = nsim,
      seed = seed,
      call = simulation_call
    ),
    class = c("dyadMLM_response_simulations", "list")
  )
}


# Shared validation for the integer-valued simulation arguments.
is_one_whole_number <- function(x) {
  is.numeric(x) &&
    length(x) == 1L &&
    is.finite(x) &&
    x %% 1 == 0 &&
    x <= .Machine$integer.max
}


# Simulate and immediately normalize to simulation x fitted row.
simulate_complete_glmmTMB_responses <- function(model, nsim, seed) {
  t(as.matrix(stats::simulate(model, nsim = nsim, seed = seed)))
}


# Read every component because glmmTMB::set_simcodes() currently changes only
# conditional terms, while dispersion terms can also contain random effects.
get_glmmTMB_simulation_codes <- function(model) {
  simulation_components <- c("terms", "termszi", "termsdisp")
  if (!all(simulation_components %in% names(model$obj$env$data))) {
    stop("The fitted model has an unsupported simulation structure.", call. = FALSE)
  }

  lapply(
    model$obj$env$data[simulation_components],
    function(component_terms) {
      vapply(
        component_terms,
        function(term) as.numeric(term$simCode),
        numeric(1)
      )
    }
  )
}


# Set or restore the exact term-specific codes in every model component.
set_glmmTMB_simulation_codes <- function(model, simulation_codes) {
  for (component in names(simulation_codes)) {
    component_terms <- model$obj$env$data[[component]]
    for (i in seq_along(component_terms)) {
      component_terms[[i]]$simCode <- simulation_codes[[component]][[i]]
    }
    model$obj$env$data[[component]] <- component_terms
  }
  invisible(model)
}
