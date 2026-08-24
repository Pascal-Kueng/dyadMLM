# Cross-backend development validation for partner-dependence checks
#
# This script compares diagnostic conclusions, not equality of predictive
# distributions. glmmTMB uses a plug-in predictive reference; brms propagates
# posterior uncertainty. Run from the package root. Expect several minutes.

required_packages <- c("brms", "cmdstanr", "devtools", "glmmTMB", "posterior")
missing_packages <- required_packages[!vapply(
  required_packages,
  requireNamespace,
  logical(1L),
  quietly = TRUE
)]
if (length(missing_packages) > 0L) {
  stop(
    "This validation requires: ",
    paste(missing_packages, collapse = ", "),
    ".",
    call. = FALSE
  )
}

devtools::load_all(".", quiet = TRUE)
source("dev/diagnostic_checks/brms-partner-prototype.R")

n_predictive_datasets <- 4000L


make_validation_data <- function(
  n_dyads,
  shared_sd,
  difference_sd,
  residual_sd_first,
  residual_sd_second,
  seed
) {
  set.seed(seed)
  data <- data.frame(
    dyad = factor(rep(seq_len(n_dyads), each = 2L)),
    role = factor(
      rep(c("first", "second"), times = n_dyads),
      levels = c("first", "second")
    ),
    x = stats::rnorm(2L * n_dyads)
  )

  shared_effect <- stats::rnorm(n_dyads, sd = shared_sd)
  difference_effect <- stats::rnorm(n_dyads, sd = difference_sd)
  difference_sign <- rep(c(1, -1), times = n_dyads)
  residual_sd <- ifelse(
    data$role == "first",
    residual_sd_first,
    residual_sd_second
  )

  data$outcome <-
    1 +
    0.35 * (data$role == "second") +
    0.45 * data$x +
    shared_effect[as.integer(data$dyad)] +
    difference_sign * difference_effect[as.integer(data$dyad)] +
    stats::rnorm(nrow(data), sd = residual_sd)

  data
}


existing_validation_data <- prepare_dyad_data(
  dyads_cross,
  dyad = coupleID,
  member = personID,
  role = gender,
  model_types = "none",
  keep_compositions = "female-male",
  seed = 18401L
)
existing_validation_data <- data.frame(
  outcome = existing_validation_data$closeness,
  dyad = existing_validation_data$coupleID,
  role = existing_validation_data$gender
)

validation_scenarios <- list(
  correct = list(
    data = make_validation_data(
      n_dyads = 300L,
      shared_sd = 0.7,
      difference_sd = 0,
      residual_sd_first = 0.7,
      residual_sd_second = 0.7,
      seed = 18101L
    ),
    formula = outcome ~ role + x + (1 | dyad)
  ),
  missed_negative_dependence = list(
    data = make_validation_data(
      n_dyads = 200L,
      shared_sd = 0.1,
      difference_sd = 0.8,
      residual_sd_first = 0.55,
      residual_sd_second = 0.55,
      seed = 18102L
    ),
    formula = outcome ~ role + x + (1 | dyad)
  ),
  missed_role_variance = list(
    data = make_validation_data(
      n_dyads = 200L,
      shared_sd = 0.5,
      difference_sd = 0,
      residual_sd_first = 0.35,
      residual_sd_second = 1.05,
      seed = 18103L
    ),
    formula = outcome ~ role + x + (1 | dyad)
  ),
  existing_female_male = list(
    data = existing_validation_data,
    formula = outcome ~ role + (1 | dyad)
  )
)


fit_and_check_both <- function(scenario, fit_seed, predictive_seed) {
  data <- scenario$data

  glmm_model <- glmmTMB::glmmTMB(
    scenario$formula,
    data = data,
    family = stats::gaussian()
  )
  if (glmm_model$fit$convergence != 0L || !isTRUE(glmm_model$sdr$pdHess)) {
    stop("The glmmTMB validation fit did not converge cleanly.", call. = FALSE)
  }

  brms_model <- brms::brm(
    scenario$formula,
    data = data,
    family = stats::gaussian(),
    prior = c(
      brms::prior(normal(0, 3), class = "Intercept"),
      brms::prior(normal(0, 3), class = "b"),
      brms::prior(exponential(1), class = "sd"),
      brms::prior(exponential(1), class = "sigma")
    ),
    backend = "cmdstanr",
    chains = 4,
    cores = 4,
    iter = 2000,
    warmup = 1000,
    seed = fit_seed,
    refresh = 0,
    control = list(adapt_delta = 0.95)
  )

  draw_summary <- posterior::summarise_draws(
    brms::as_draws_array(brms_model),
    "rhat",
    "ess_bulk"
  )
  population_draw_summary <- draw_summary[
    grepl("^(b_|sd_|sigma$)", draw_summary$variable),
  ]
  max_rhat <- max(population_draw_summary$rhat, na.rm = TRUE)
  min_ess_bulk <- min(population_draw_summary$ess_bulk, na.rm = TRUE)

  sampler_diagnostics <- brms::nuts_params(brms_model)
  n_divergent <- sum(
    sampler_diagnostics$Parameter == "divergent__" &
      sampler_diagnostics$Value == 1
  )
  if (max_rhat > 1.01 || n_divergent > 0L) {
    stop("The brms validation fit did not sample cleanly.", call. = FALSE)
  }

  glmm_simulations <- simulate_dyad_responses(
    glmm_model,
    nsim = n_predictive_datasets,
    seed = predictive_seed
  )
  brms_simulations <- simulate_brms_partner_prototype(
    brms_model,
    nsim = n_predictive_datasets,
    seed = predictive_seed
  )

  stopifnot(
    identical(
      glmm_simulations$observed_response,
      brms_simulations$observed_response
    ),
    identical(
      as.character(glmm_simulations$model_frame$dyad),
      as.character(brms_simulations$model_frame$dyad)
    ),
    identical(
      as.character(glmm_simulations$model_frame$role),
      as.character(brms_simulations$model_frame$role)
    )
  )

  list(
    glmmTMB = check_partner_dependence(
      glmm_simulations,
      dyad = data$dyad,
      role = data$role,
      plot = FALSE
    ),
    brms = check_brms_partner_prototype(
      brms_simulations,
      dyad = data$dyad,
      role = data$role,
      plot = FALSE
    ),
    diagnostics = data.frame(
      max_rhat = max_rhat,
      min_ess_bulk = min_ess_bulk,
      n_divergent = n_divergent,
      glmmTMB_pdHess = glmm_model$sdr$pdHess
    )
  )
}


validation_checks <- list()
scenario_index <- 0L
for (scenario_name in names(validation_scenarios)) {
  scenario_index <- scenario_index + 1L
  message("VALIDATING_", scenario_name)
  validation_checks[[scenario_name]] <- fit_and_check_both(
    validation_scenarios[[scenario_name]],
    fit_seed = 18500L + scenario_index,
    predictive_seed = 18600L + scenario_index
  )
}


comparison_rows <- list()
row_index <- 0L
for (scenario_name in names(validation_checks)) {
  for (backend_name in c("glmmTMB", "brms")) {
    check <- validation_checks[[scenario_name]][[backend_name]]
    statistics <- check$statistics_table

    for (statistic_index in seq_len(nrow(statistics))) {
      statistic <- statistics[statistic_index, ]
      row_index <- row_index + 1L
      comparison_rows[[row_index]] <- data.frame(
        scenario = scenario_name,
        backend = backend_name,
        reference = check$reference,
        statistic_name = statistic$statistic_name,
        parameterization = statistic$parameterization,
        observed = statistic$observed_value,
        reference_median = statistic$replicated_median,
        reference_lower = statistic$replicated_lower,
        reference_upper = statistic$replicated_upper,
        observed_quantile = statistic$observed_quantile,
        tail = if (statistic$observed_quantile < 0.025) {
          "lower"
        } else if (statistic$observed_quantile > 0.975) {
          "upper"
        } else {
          "compatible"
        },
        row.names = NULL
      )
    }
  }
}
comparison_table <- do.call(rbind, comparison_rows)

agreement_rows <- list()
row_index <- 0L
for (scenario_name in unique(comparison_table$scenario)) {
  scenario_table <- comparison_table[
    comparison_table$scenario == scenario_name,
  ]
  for (statistic_name in unique(scenario_table$statistic_name)) {
    statistic_table <- scenario_table[
      scenario_table$statistic_name == statistic_name,
    ]
    row_index <- row_index + 1L
    agreement_rows[[row_index]] <- data.frame(
      scenario = scenario_name,
      statistic_name = statistic_name,
      glmmTMB_tail = statistic_table$tail[
        statistic_table$backend == "glmmTMB"
      ],
      brms_tail = statistic_table$tail[
        statistic_table$backend == "brms"
      ],
      same_tail = length(unique(statistic_table$tail)) == 1L,
      row.names = NULL
    )
  }
}
agreement_table <- do.call(rbind, agreement_rows)


tail_matches <- function(scenario_name, statistic_name, expected_tail) {
  matching_rows <-
    comparison_table$scenario == scenario_name &
    comparison_table$statistic_name == statistic_name

  sum(matching_rows) == 2L &&
    setequal(
      comparison_table$backend[matching_rows],
      c("glmmTMB", "brms")
    ) &&
    all(comparison_table$tail[matching_rows] == expected_tail)
}

diagnostics_table <- do.call(
  rbind,
  lapply(names(validation_checks), function(scenario_name) {
    cbind(
      scenario = scenario_name,
      validation_checks[[scenario_name]]$diagnostics
    )
  })
)

print(diagnostics_table, row.names = FALSE)
print(comparison_table, row.names = FALSE, digits = 4)
print(agreement_table, row.names = FALSE)

correct_scenario_rows <- comparison_table$scenario == "correct"
stopifnot(
  nrow(agreement_table) == 24L,
  all(agreement_table$same_tail),
  sum(correct_scenario_rows) == 12L,
  all(comparison_table$tail[correct_scenario_rows] == "compatible"),
  tail_matches(
    "missed_negative_dependence",
    "partner_correlation",
    "lower"
  ),
  tail_matches(
    "missed_role_variance",
    "dyad_mean_half_difference_correlation",
    "lower"
  ),
  tail_matches(
    "existing_female_male",
    "dyad_mean_half_difference_correlation",
    "upper"
  )
)

message("CROSS_BACKEND_VALIDATION_OK")
