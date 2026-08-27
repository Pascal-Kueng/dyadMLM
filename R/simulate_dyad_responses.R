#' Simulate response datasets for predictive checks
#'
#' `r lifecycle::badge("experimental")`
#' Creates response datasets from a fitted model for comparison with the
#' observed data. They show what the model would generate for the same fitted
#' rows and covariates.
#'
#' Each simulation keeps the fitted parameter estimates fixed and draws new
#' random effects and Gaussian observation errors. When dyads are the only
#' grouping factor, this represents hypothetical new dyads observed under the
#' same design. Effects for any other modeled grouping levels are also redrawn.
#'
#' Currently, the function supports unweighted Gaussian identity-link
#' `glmmTMB` models without zero inflation and with one numeric response per
#' fitted row. The ILD prototype has specifically exercised AR(1),
#' dyad-occasion, and shared/difference Gaussian random-effect structures; this
#' is not a blanket validation of every `glmmTMB` covariance structure. The
#' interface is experimental.
#'
#' **Technical details.** This is a plug-in predictive reference: the model is
#' not refitted and uncertainty in the fitted parameters is not included. The
#' simulation is conditional on those estimates and the fitted-row design, but
#' not on the fitted random-effect values.
#'
#' The result stores one expected response for each fitted row. Downstream
#' checks can use the responses unchanged or remove this same fitted mean
#' pattern from the observed and simulated responses. For the supported model,
#' this centre is the response prediction with random effects set to zero.
#'
#' @param model A fitted `glmmTMB` model.
#' @param nsim Number of complete response datasets to simulate. The default
#' is 1000.
#' @param seed `NULL` or one non-negative whole number used to reproduce the
#'   simulations. When supplied, the caller's random-number state is restored
#'   after the function returns, including after an error.
#'
#' @return A `dyadMLM_response_simulations` object for use with
#'   [check_partner_dependence()].
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

    # Use this seed only inside the function. On exit, restore the caller's
    # previous random-number state (including the absence of one).
    withr::local_seed(seed)
  }

  model_family <- stats::family(model)
  if (!identical(model_family$family, "gaussian") ||
      !identical(model_family$link, "identity")) {
    stop(
      "Predictive checks currently support only Gaussian identity-link models.",
      call. = FALSE
    )
  }

  # The model frame contains the rows actually used for fitting. Rows omitted
  # during fitting are already gone, and every object below keeps this order.
  model_frame <- stats::model.frame(model)
  n_fitted_rows <- nrow(model_frame)

  # One observed response value for each fitted row.
  observed_response <- stats::model.response(model_frame)
  if (!is.numeric(observed_response) ||
      length(observed_response) != n_fitted_rows) {
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

  # With `ziformula = ~ 0`, there is no intercept, named term, or offset.
  zero_inflation_terms <- stats::terms(
    stats::formula(model, component = "zi")
  )
  has_zero_inflation <- attr(zero_inflation_terms, "intercept") != 0L ||
    length(attr(zero_inflation_terms, "term.labels")) != 0L ||
    length(attr(zero_inflation_terms, "offset")) != 0L
  if (has_zero_inflation) {
    stop("Predictive checks currently require `ziformula = ~ 0`.", call. = FALSE)
  }

  # Obtain one fixed response centre per fitted row. For a Gaussian identity
  # model, the random-effects-zero prediction is exactly the marginal expected
  # response after averaging over newly drawn zero-mean effects at every level.
  response_center <- as.numeric(stats::predict(
    model,
    newdata = NULL,
    type = "response",
    re.form = NA
  ))
  if (length(response_center) != n_fitted_rows ||
      any(!is.finite(response_center))) {
    stop(
      "Could not obtain one finite response centre for each fitted row.",
      call. = FALSE
    )
  }

  # These settings live inside the caller's fitted model: changing them here
  # also changes that original object. Save them and always restore them,
  # including when simulation fails.
  original_simulation_codes <- get_glmmTMB_simulation_codes(model)
  on.exit(
    set_glmmTMB_simulation_codes(model, original_simulation_codes),
    add = TRUE
  )

  # Code `2` tells glmmTMB to draw a new value for a random-effect term. Keep
  # the same list shape as the saved settings, but replace every code with `2`.
  unconditional_simulation_codes <- lapply(
    original_simulation_codes,
    function(codes) rep(2, length(codes))
  )
  set_glmmTMB_simulation_codes(model, unconditional_simulation_codes)

  # glmmTMB returns a data frame with fitted rows down and simulations across:
  # `n_fitted_rows` rows by `nsim` columns.
  simulations_by_column <- stats::simulate(model, nsim = nsim)

  # Store the result the other way around: one complete dataset per matrix row
  # and one fitted row per column (`nsim` by `n_fitted_rows`).
  simulated_responses <- t(as.matrix(simulations_by_column))

  if (!is.numeric(simulated_responses) ||
      !identical(dim(simulated_responses), c(nsim, n_fitted_rows)) ||
      any(!is.finite(simulated_responses))) {
    stop(
      paste0(
        "Simulated responses were not returned as a finite ",
        "simulation-by-fitted-row matrix."
      ),
      call. = FALSE
    )
  }

  # All row-level pieces now line up. For fitted row `i`:
  # - `model_frame[i, ]` contains the variables used in the fit;
  # - `observed_response[i]` is its observed value;
  # - `response_center[i]` is its expected value with random effects set to
  #   zero; and
  # - `simulated_responses[, i]` holds its value in every generated dataset.
  response_simulations <- list(
    observed_response = as.numeric(observed_response),
    simulated_responses = simulated_responses,
    response_center = response_center,
    model_frame = model_frame,
    backend = "glmmTMB",
    family = model_family$family,
    link = model_family$link,
    reference = "plug-in predictive",
    random_effects = "new",
    parameter_uncertainty = "excluded",
    center = "random-effects-zero expected response",
    center_target = paste0(
      "marginal response mean over new random effects ",
      "(Gaussian identity)"
    ),
    target = paste0(
      "unconditional plug-in replication under the fitted-row design, ",
      "with all random effects newly generated"
    ),
    nsim = nsim,
    seed = seed,
    call = simulation_call
  )
  class(response_simulations) <- c("dyadMLM_response_simulations", "list")

  return(response_simulations)
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


# Read every currently supported glmmTMB random-effect component.
get_glmmTMB_simulation_codes <- function(model) {
  simulation_components <- c("terms", "termszi", "termsdisp")
  if (!all(simulation_components %in% names(model$obj$env$data))) {
    stop(
      "The fitted model has an unsupported simulation structure.",
      call. = FALSE
    )
  }

  # The result is a named list with one numeric vector for the response mean,
  # zero-inflation, and dispersion parts. Each number belongs to one random-
  # effect term; a vector is empty when that model part has no such terms.
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
    # Update one component's term list, then write the whole list back into
    # glmmTMB's mutable model environment.
    component_terms <- model$obj$env$data[[component]]
    for (term_index in seq_along(component_terms)) {
      component_terms[[term_index]]$simCode <-
        simulation_codes[[component]][[term_index]]
    }
    model$obj$env$data[[component]] <- component_terms
  }

  invisible(model)
}
