# Reproducible engineering validation for the simple generalized check.

source_dir <- normalizePath(Sys.getenv("DYADMLM_SOURCE", unset = "."))
output_dir <- file.path(
  source_dir,
  "dev/diagnostic_checks/simple-generalized-cross-sectional"
)
devtools::load_all(source_dir, quiet = TRUE)

outer_repetitions <- as.integer(Sys.getenv("DYADMLM_OUTER_REPS", unset = "6"))
nsim <- as.integer(Sys.getenv("DYADMLM_NSIM", unset = "199"))
n_dyads <- as.integer(Sys.getenv("DYADMLM_N_DYADS", unset = "120"))
stopifnot(outer_repetitions >= 1L, nsim >= 20L, n_dyads >= 40L)

family_object <- function(family_name) {
  switch(
    family_name,
    poisson = stats::poisson(link = "log"),
    nbinom1 = glmmTMB::nbinom1(link = "log"),
    nbinom2 = glmmTMB::nbinom2(link = "log"),
    tweedie = glmmTMB::tweedie(link = "log"),
    Gamma = stats::Gamma(link = "log"),
    beta = glmmTMB::beta_family(link = "logit"),
    stop("Unknown family: ", family_name, call. = FALSE)
  )
}

simulate_tweedie <- function(mu, dispersion, power = 1.5) {
  poisson_rate <- mu^(2 - power) / (dispersion * (2 - power))
  event_count <- stats::rpois(length(mu), poisson_rate)
  response <- numeric(length(mu))
  positive <- event_count > 0L
  response[positive] <- stats::rgamma(
    sum(positive),
    shape = event_count[positive] * (2 - power) / (power - 1),
    scale = dispersion[positive] * (power - 1) *
      mu[positive]^(power - 1)
  )
  response
}

generate_dyad_data <- function(
  family_name,
  seed,
  n_dyads,
  shared_effect_sd = 0.65,
  random_dispersion = FALSE
) {
  set.seed(seed)
  n_rows <- 2L * n_dyads
  n_batches <- max(12L, as.integer(n_dyads / 6L))
  data <- data.frame(
    dyad = factor(rep(seq_len(n_dyads), each = 2L)),
    role = factor(rep(c("female", "male"), times = n_dyads)),
    predictor = stats::rnorm(n_rows),
    batch = factor(rep(seq_len(n_batches), length.out = n_rows))
  )
  shared_effect <- stats::rnorm(n_dyads, sd = shared_effect_sd)
  linear_predictor <-
    0.75 + 0.3 * data$predictor + 0.2 * (data$role == "male") +
    shared_effect[as.integer(data$dyad)]
  if (family_name == "beta") {
    linear_predictor <- linear_predictor - 1
  }
  response_mean <- if (family_name == "beta") {
    stats::plogis(linear_predictor)
  } else {
    exp(linear_predictor)
  }

  role_multiplier <- ifelse(data$role == "male", 1.45, 0.75)
  batch_effect <- rep(0, n_rows)
  if (random_dispersion) {
    batch_effect <- stats::rnorm(n_batches, sd = 0.35)[
      as.integer(data$batch)
    ]
  }
  dispersion_multiplier <- role_multiplier * exp(batch_effect)
  data$outcome <- switch(
    family_name,
    poisson = stats::rpois(n_rows, response_mean),
    nbinom1 = stats::rnbinom(
      n_rows,
      mu = response_mean,
      size = response_mean / (0.65 * dispersion_multiplier)
    ),
    nbinom2 = stats::rnbinom(
      n_rows,
      mu = response_mean,
      size = 3 / dispersion_multiplier
    ),
    tweedie = simulate_tweedie(
      response_mean,
      dispersion = 0.45 * dispersion_multiplier
    ),
    Gamma = stats::rgamma(
      n_rows,
      shape = 5 / dispersion_multiplier,
      scale = response_mean * dispersion_multiplier / 5
    ),
    beta = stats::rbeta(
      n_rows,
      shape1 = response_mean * 20 / dispersion_multiplier,
      shape2 = (1 - response_mean) * 20 / dispersion_multiplier
    )
  )
  data
}

capture_warnings <- function(expression) {
  warnings <- character()
  value <- withCallingHandlers(
    expression,
    warning = function(condition) {
      warnings <<- c(warnings, conditionMessage(condition))
      invokeRestart("muffleWarning")
    }
  )
  list(value = value, warnings = paste(unique(warnings), collapse = " | "))
}

fit_model <- function(data, family_name, include_dyad, random_dispersion) {
  conditional_formula <- if (include_dyad) {
    outcome ~ predictor + role + (1 | dyad)
  } else {
    outcome ~ predictor + role
  }
  dispersion_formula <- if (family_name == "poisson") {
    ~1
  } else if (random_dispersion) {
    ~0 + role + (1 | batch)
  } else {
    ~0 + role
  }
  glmmTMB::glmmTMB(
    conditional_formula,
    dispformula = dispersion_formula,
    family = family_object(family_name),
    data = data
  )
}

extract_partner_row <- function(check, context) {
  row <- check$statistics_table[
    check$statistics_table$statistic_name == "partner_correlation",
    ,
    drop = FALSE
  ]
  data.frame(
    context,
    observed = row$observed_value,
    replicated_median = row$replicated_median,
    replicated_lower = row$replicated_lower,
    replicated_upper = row$replicated_upper,
    observed_position = row$observed_quantile,
    outside_middle_95 =
      row$observed_value < row$replicated_lower |
      row$observed_value > row$replicated_upper,
    stringsAsFactors = FALSE
  )
}

empty_fit_result <- function(context) {
  data.frame(
    context,
    observed = NA_real_,
    replicated_median = NA_real_,
    replicated_lower = NA_real_,
    replicated_upper = NA_real_,
    observed_position = NA_real_,
    outside_middle_95 = NA
  )
}

run_one_fit <- function(
  data,
  family_name,
  model_name,
  include_dyad,
  outer_index,
  random_dispersion = FALSE
) {
  context <- data.frame(
    outer = outer_index,
    family = family_name,
    model = model_name,
    response = NA_character_,
    fit_convergence = NA_integer_,
    positive_definite_hessian = NA,
    warning = "",
    error = "",
    stringsAsFactors = FALSE
  )
  fit_capture <- tryCatch(
    capture_warnings(fit_model(
      data,
      family_name,
      include_dyad = include_dyad,
      random_dispersion = random_dispersion
    )),
    error = identity
  )
  if (inherits(fit_capture, "error")) {
    context$error <- conditionMessage(fit_capture)
    return(empty_fit_result(context))
  }

  fit <- fit_capture$value
  context$fit_convergence <- fit$fit$convergence
  context$positive_definite_hessian <- isTRUE(fit$sdr$pdHess)
  context$warning <- fit_capture$warnings
  check_capture <- tryCatch(
    capture_warnings({
      simulations <- simulate_dyad_responses(
        fit,
        nsim = nsim,
        seed = 500000L + outer_index * 100L + match(
          family_name,
          c("poisson", "nbinom1", "nbinom2", "tweedie", "Gamma", "beta")
        )
      )
      lapply(c("raw", "model-centred"), function(response_type) {
        check_partner_dependence(
          simulations,
          dyad = data$dyad,
          role = data$role,
          response = response_type,
          plot = FALSE
        )
      })
    }),
    error = identity
  )
  if (inherits(check_capture, "error")) {
    context$error <- conditionMessage(check_capture)
    return(empty_fit_result(context))
  }

  context$warning <- paste(
    c(context$warning, check_capture$warnings)[
      nzchar(c(context$warning, check_capture$warnings))
    ],
    collapse = " | "
  )
  checks <- check_capture$value
  do.call(rbind, lapply(seq_along(checks), function(index) {
    row_context <- context
    row_context$response <- c("raw", "model-centred")[[index]]
    extract_partner_row(checks[[index]], row_context)
  }))
}

run_dispersion_checks <- function() {
  dispersion_families <- c("nbinom2", "tweedie")
  do.call(rbind, lapply(dispersion_families, function(family_name) {
    message("Random-dispersion check: ", family_name)
    data <- generate_dyad_data(
      family_name,
      seed = 43000L + match(family_name, dispersion_families),
      n_dyads = 80L,
      random_dispersion = TRUE
    )
    tryCatch({
      fit_capture <- capture_warnings(fit_model(
        data,
        family_name,
        include_dyad = TRUE,
        random_dispersion = TRUE
      ))
      fit <- fit_capture$value
      simulations <- simulate_dyad_responses(fit, nsim = 39L, seed = 43100L)
      raw <- check_partner_dependence(
        simulations,
        dyad = "dyad",
        role = "role",
        response = "raw",
        plot = FALSE
      )
      centred <- check_partner_dependence(
        simulations,
        dyad = "dyad",
        role = "role",
        response = "model-centred",
        plot = FALSE
      )
      data.frame(
        family = family_name,
        convergence = fit$fit$convergence,
        positive_definite_hessian = isTRUE(fit$sdr$pdHess),
        dispersion_random_terms = length(
          get_glmmTMB_simulation_codes(fit)$termsdisp
        ),
        center_matches_predict = isTRUE(all.equal(
          simulations$response_center,
          as.numeric(stats::predict(
            fit,
            newdata = NULL,
            type = "response",
            re.form = NA
          )),
          tolerance = 0
        )),
        raw_check = inherits(raw, "dyadMLM_partner_check"),
        centred_check = inherits(centred, "dyadMLM_partner_check"),
        warning = fit_capture$warnings,
        error = "",
        stringsAsFactors = FALSE
      )
    }, error = function(condition) data.frame(
      family = family_name,
      convergence = NA_integer_,
      positive_definite_hessian = NA,
      dispersion_random_terms = NA_integer_,
      center_matches_predict = NA,
      raw_check = FALSE,
      centred_check = FALSE,
      warning = "",
      error = conditionMessage(condition),
      stringsAsFactors = FALSE
    ))
  }))
}

run_sparse_check <- function() {
  set.seed(44001L)
  data <- data.frame(
    dyad = factor(rep(seq_len(40L), each = 2L)),
    role = factor(rep(c("female", "male"), times = 40L))
  )
  data$outcome <- stats::rpois(nrow(data), lambda = 0.12)
  fit <- glmmTMB::glmmTMB(
    outcome ~ role,
    family = stats::poisson(link = "log"),
    data = data
  )
  simulations <- simulate_dyad_responses(fit, nsim = 199L, seed = 44002L)
  pair_rows <- matrix(seq_len(nrow(data)), ncol = 2L, byrow = TRUE)
  correlations <- apply(
    simulations$simulated_responses,
    1L,
    function(values) {
      first <- values[pair_rows[, 1L]]
      second <- values[pair_rows[, 2L]]
      if (stats::sd(first) == 0 || stats::sd(second) == 0) {
        return(NA_real_)
      }
      stats::cor(first, second)
    }
  )
  check_capture <- tryCatch(
    capture_warnings(check_partner_dependence(
      simulations,
      dyad = data$dyad,
      role = data$role,
      response = "raw",
      plot = FALSE
    )),
    error = identity
  )
  data.frame(
    family = "poisson",
    mean = mean(data$outcome),
    defined_correlations = sum(is.finite(correlations)),
    simulations = length(correlations),
    check_completed = !inherits(check_capture, "error"),
    warning = if (inherits(check_capture, "error")) "" else check_capture$warnings,
    error = if (inherits(check_capture, "error")) {
      conditionMessage(check_capture)
    } else {
      ""
    },
    stringsAsFactors = FALSE
  )
}

family_names <- c("poisson", "nbinom1", "nbinom2", "tweedie", "Gamma", "beta")
study_results <- list()
result_index <- 0L
for (outer_index in seq_len(outer_repetitions)) {
  for (family_name in family_names) {
    message(
      "Outer study: repetition ", outer_index, "/", outer_repetitions,
      ", family ", family_name
    )
    data <- generate_dyad_data(
      family_name,
      seed = 100000L + outer_index * 100L + match(family_name, family_names),
      n_dyads = n_dyads
    )
    for (model_name in c("correct", "dyad_effect_omitted")) {
      result_index <- result_index + 1L
      study_results[[result_index]] <- run_one_fit(
        data,
        family_name,
        model_name,
        include_dyad = model_name == "correct",
        outer_index = outer_index
      )
    }
  }
}

study_results <- do.call(rbind, study_results)
expected_result_rows <-
  outer_repetitions * length(family_names) * 2L * 2L
if (nrow(study_results) != expected_result_rows ||
    any(is.na(study_results$response)) ||
    any(nzchar(study_results$error))) {
  stop("The outer study did not complete every requested diagnostic.", call. = FALSE)
}

message("Random-dispersion checks")
dispersion_results <- run_dispersion_checks()
dispersion_checks_passed <- with(
  dispersion_results,
  family %in% c("nbinom2", "tweedie") &
    convergence == 0L &
    positive_definite_hessian &
    dispersion_random_terms == 1L &
    center_matches_predict &
    raw_check &
    centred_check &
    !nzchar(warning) &
    !nzchar(error)
)
if (!isTRUE(all(dispersion_checks_passed))) {
  stop("Random-dispersion validation failed.", call. = FALSE)
}
message(
  "Random-dispersion checks passed for ",
  paste(dispersion_results$family, collapse = ", ")
)

message("Sparse-reference check")
sparse_results <- run_sparse_check()
sparse_check_passed <- with(
  sparse_results,
    check_completed &
    !nzchar(error) &
    grepl(
      "undefined partner-dependence summary",
      warning,
      fixed = TRUE
    ) &
    defined_correlations > 0L &
    defined_correlations < simulations
)
if (!isTRUE(sparse_check_passed)) {
  stop("Sparse-reference validation failed.", call. = FALSE)
}
message(
  "Sparse-reference check passed with ",
  sparse_results$defined_correlations, "/",
  sparse_results$simulations,
  " defined partner correlations"
)

recorded_configuration <-
  outer_repetitions == 6L && nsim == 199L && n_dyads == 120L
if (recorded_configuration) {
  output_file <- file.path(output_dir, "outer-study-results.csv")
  utils::write.csv(study_results, output_file, row.names = FALSE)
  message(
    "Validation complete; outer-study results written to ",
    output_file
  )
} else {
  message(
    "Validation complete; recorded outer-study results were not overwritten ",
    "because this was a non-default run"
  )
}
