#' Simulate complete response datasets for dyadic predictive checks
#'
#' Generates complete response datasets from a fitted model while preserving
#' its random-effect and covariance structure. The result can be used for
#' various predictive checks.
#'
#' The initial implementation supports scalar Gaussian identity-link
#' `glmmTMB` models only.
#' The interface is experimental and may change as predictive checks expand.
#'
#' @param model A fitted `glmmTMB` model.
#' @param nsim Number of complete response datasets to simulate. The default
#' is 1000.
#' @param seed `NULL` or one non-negative whole number used to reproduce the
#'   simulations.
#'
#' @return A `dyadMLM_response_simulations` object containing the observed and
#'   simulated response datasets used by predictive checks.
#'
#' @export
simulate_dyad_responses <- function(model, nsim = 1000, seed = NULL) {
  simulation_call <- match.call()

  # Validate the fitted model and simulation arguments.
  if (!inherits(model, "glmmTMB")) {
    stop("`model` must be a fitted `glmmTMB` model.", call. = FALSE)
  }
  if (!requireNamespace("glmmTMB", quietly = TRUE)) {
    stop("Package `glmmTMB` is required to simulate responses.", call. = FALSE)
  }
  if (!is.numeric(nsim) || length(nsim) != 1L ||
      !is.finite(nsim) || nsim < 1 || nsim %% 1 != 0 ||
      nsim > .Machine$integer.max) {
    stop("`nsim` must be one positive whole number.", call. = FALSE)
  }
  nsim <- as.integer(nsim)

  if (!is.null(seed)) {
    if (!is.numeric(seed) || length(seed) != 1L ||
        !is.finite(seed) || seed < 0 || seed %% 1 != 0 ||
        seed > .Machine$integer.max) {
      stop("`seed` must be `NULL` or one non-negative whole number.", call. = FALSE)
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

  # Extract the fitted rows and observed response from the model itself.
  model_frame <- stats::model.frame(model)
  observed_response <- stats::model.response(model_frame)
  if (!is.numeric(observed_response) ||
      length(observed_response) != nrow(model_frame)) {
    stop(
      "Predictive checks currently require one numeric response per fitted row.",
      call. = FALSE
    )
  }
  if (any(!is.finite(observed_response))) {
    stop("The fitted response contains non-finite values.", call. = FALSE)
  }

  model_weights <- stats::weights(model)
  if (!is.null(model_weights) && any(model_weights != 1)) {
    stop("Predictive checks currently require unit case weights.", call. = FALSE)
  }

  zero_inflation_terms <- model |>
    stats::formula(component = "zi") |>
    stats::terms()
  has_zero_inflation <- attr(zero_inflation_terms, "intercept") != 0L ||
    length(attr(zero_inflation_terms, "term.labels")) != 0L ||
    length(attr(zero_inflation_terms, "offset")) != 0L
  if (has_zero_inflation) {
    stop("Predictive checks currently require `ziformula = ~ 0`.", call. = FALSE)
  }

  # Obtain one random-effects-excluded response-scale prediction per fitted
  # row. This is a deterministic center, not another simulated response.
  fixed_effect_prediction <- model |>
    stats::predict(
      newdata = NULL,
      type = "response",
      re.form = NA
    ) |>
    as.numeric()
  if (length(fixed_effect_prediction) != nrow(model_frame) ||
      any(!is.finite(fixed_effect_prediction))) {
    stop(
      "Could not obtain one finite fixed-effect prediction for each fitted row.",
      call. = FALSE
    )
  }

  # glmmTMB stores simulation settings in mutable environments. Temporarily
  # change them, then restore the caller's exact settings on success or error.
  original_simulation_codes <- get_glmmTMB_simulation_codes(model)
  on.exit(
    set_glmmTMB_simulation_codes(model, original_simulation_codes),
    add = TRUE
  )

  # glmmTMB uses `2` to draw new random effects during simulation.
  unconditional_simulation_codes <- lapply(
    original_simulation_codes,
    function(codes) rep(2, length(codes))
  )
  set_glmmTMB_simulation_codes(model, unconditional_simulation_codes)

  # Simulate complete response datasets with newly drawn random effects.
  simulated_responses <- model |>
    stats::simulate(nsim = nsim, seed = seed) |>
    # glmmTMB returns fitted rows x simulations
    # but we need simulations x fitted rows.
    t()

  if (!is.numeric(simulated_responses) ||
      !identical(dim(simulated_responses), c(nsim, nrow(model_frame))) ||
      any(!is.finite(simulated_responses))) {
    stop(
      paste0(
        "Simulated responses were not returned as a finite ",
        "simulation-by-fitted-row matrix."
      ),
      call. = FALSE
    )
  }

  response_simulations <- list(
    observed_response = as.numeric(observed_response),
    simulated_responses = simulated_responses,
    fixed_effect_prediction = fixed_effect_prediction,
    model_frame = model_frame,
    backend = "glmmTMB",
    family = model_family$family,
    link = model_family$link,
    reference = "plug-in predictive",
    random_effects = "new",
    nsim = nsim,
    seed = seed,
    call = simulation_call
  )
  class(response_simulations) <- c("dyadMLM_response_simulations", "list")

  return(response_simulations)
}


# Read every currently supported glmmTMB random-effect component.
get_glmmTMB_simulation_codes <- function(model) {
  simulation_components <- c("terms", "termszi", "termsdisp")
  if (!all(simulation_components %in% names(model$obj$env$data))) {
    stop(
      "The fitted model has an unsupported simulation structure.",
      call. = FALSE
    )
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
    for (term_index in seq_along(component_terms)) {
      component_terms[[term_index]]$simCode <-
        simulation_codes[[component]][[term_index]]
    }
    model$obj$env$data[[component]] <- component_terms
  }

  invisible(model)
}
