# Repeatable smoke validation for brms-partner-prototype.R
#
# Run from the package root. This fits a deliberately small model to validate
# mechanics, not posterior estimation quality.

if (!requireNamespace("brms", quietly = TRUE) ||
    !requireNamespace("cmdstanr", quietly = TRUE)) {
  stop("This smoke validation requires brms and cmdstanr.", call. = FALSE)
}

devtools::load_all(".", quiet = TRUE)
source("dev/diagnostic_checks/brms-partner-prototype.R")

set.seed(17001L)
n_dyads <- 18L
analysis_data <- data.frame(
  dyad = factor(rep(seq_len(n_dyads), each = 2L)),
  role = factor(
    rep(c("first", "second"), times = n_dyads),
    levels = c("first", "second")
  ),
  x = stats::rnorm(2L * n_dyads)
)
dyad_effect <- stats::rnorm(n_dyads, sd = 0.8)
analysis_data$outcome <-
  1 +
  0.35 * (analysis_data$role == "second") +
  0.45 * analysis_data$x +
  dyad_effect[as.integer(analysis_data$dyad)] +
  stats::rnorm(nrow(analysis_data), sd = 0.55)

model <- brms::brm(
  outcome ~ role + x + (1 | dyad),
  data = analysis_data,
  family = stats::gaussian(),
  prior = c(
    brms::prior(normal(0, 2), class = "Intercept"),
    brms::prior(normal(0, 2), class = "b"),
    brms::prior(exponential(1), class = "sd"),
    brms::prior(exponential(1), class = "sigma")
  ),
  backend = "cmdstanr",
  chains = 1,
  cores = 1,
  iter = 400,
  warmup = 200,
  seed = 17002L,
  refresh = 0
)
posterior_draw_count <- unname(as.integer(brms::ndraws(model)))

set.seed(17003L)
caller_rng_state <- .Random.seed
simulations <- simulate_brms_partner_prototype(
  model,
  nsim = 60,
  seed = 17003L
)
stopifnot(identical(.Random.seed, caller_rng_state))

simulations_again <- simulate_brms_partner_prototype(
  model,
  nsim = 60,
  seed = 17003L
)
stopifnot(
  identical(
    simulations$simulated_responses,
    simulations_again$simulated_responses
  ),
  identical(
    simulations$response_center,
    simulations_again$response_center
  ),
  identical(dim(simulations$simulated_responses), c(60L, 36L)),
  identical(length(simulations$response_center), 36L),
  inherits(simulations, "dyadMLM_response_simulations")
)

# Every member of one dyad receives the same new grouping level, and different
# dyads receive different levels.
stopifnot(
  all(vapply(
    split(simulations$simulated_grouping_values, analysis_data$dyad),
    function(values) length(unique(values)) == 1L,
    logical(1L)
  )),
  length(unique(simulations$simulated_grouping_values)) == n_dyads
)

# Under the Gaussian identity model, the fixed center must equal the posterior
# mean of X beta across all draws. The varying covariate ensures this is a
# row-specific centre rather than an intercept-only shift.
fixed_draws <- brms::fixef(model, summary = FALSE)
fixed_design <- stats::model.matrix(~ role + x, data = analysis_data)
colnames(fixed_design)[colnames(fixed_design) == "(Intercept)"] <- "Intercept"
fixed_design <- fixed_design[, colnames(fixed_draws), drop = FALSE]
expected_center_draws <- fixed_draws %*% t(fixed_design)
expected_response_center <- colMeans(expected_center_draws)
stopifnot(
  isTRUE(all.equal(
    unname(simulations$response_center),
    unname(expected_response_center),
    tolerance = 1e-10
  )),
  stats::sd(simulations$response_center) > 0,
  identical(
    simulations$center_target,
    "new-dyad marginal mean (Gaussian identity)"
  ),
  identical(simulations$center_draws, posterior_draw_count),
  identical(simulations$random_effects, "new")
)

# Independently verify brms's new-level behavior: the sampled random intercept
# is identical for both members of a dyad and differs across dyads.
new_dyad_data <- simulations$model_frame
new_dyad_data[[simulations$grouping_factor]] <- factor(
  simulations$simulated_grouping_values
)
set.seed(17005L)
new_dyad_expected <- brms::posterior_epred(
  model,
  newdata = new_dyad_data,
  re_formula = NULL,
  allow_new_levels = TRUE,
  sample_new_levels = "gaussian",
  sort = FALSE
)
selected_center_predictions <- brms::posterior_epred(
  model,
  newdata = simulations$model_frame,
  re_formula = NA,
  sort = FALSE
)
new_dyad_effects <- new_dyad_expected - selected_center_predictions
stopifnot(
  isTRUE(all.equal(
    new_dyad_effects[, seq(1L, ncol(new_dyad_effects), by = 2L)],
    new_dyad_effects[, seq(2L, ncol(new_dyad_effects), by = 2L)],
    tolerance = 1e-10
  )),
  any(abs(new_dyad_effects[, 1L] - new_dyad_effects[, 3L]) > 1e-10)
)

# The default uses every posterior draw once. Requesting more than are
# available fails rather than recycling draws.
all_draw_simulations <- simulate_brms_partner_prototype(
  model,
  seed = 17004L
)
explicit_all_draw_simulations <- simulate_brms_partner_prototype(
  model,
  nsim = posterior_draw_count,
  seed = 17004L
)
stopifnot(
  identical(all_draw_simulations$nsim, posterior_draw_count),
  identical(
    dim(all_draw_simulations$simulated_responses),
    c(posterior_draw_count, nrow(analysis_data))
  ),
  identical(explicit_all_draw_simulations$nsim, posterior_draw_count),
  identical(
    dim(explicit_all_draw_simulations$simulated_responses),
    c(posterior_draw_count, nrow(analysis_data))
  )
)

too_many_draws_error <- tryCatch(
  simulate_brms_partner_prototype(
    model,
    nsim = posterior_draw_count + 1L,
    seed = 17004L
  ),
  error = conditionMessage
)
stopifnot(
  is.character(too_many_draws_error),
  grepl("cannot exceed", too_many_draws_error, fixed = TRUE)
)

role_check <- check_brms_partner_prototype(
  simulations,
  dyad = dyad,
  role = role,
  plot = FALSE
)
explicit_model_centred_role_check <- check_brms_partner_prototype(
  simulations,
  dyad = dyad,
  role = role,
  response = "model-centred",
  plot = FALSE
)
direct_shared_role_check <- check_partner_dependence(
  simulations,
  dyad = dyad,
  role = role,
  plot = FALSE
)
raw_role_check <- check_brms_partner_prototype(
  simulations,
  dyad = dyad,
  role = role,
  response = "raw",
  plot = FALSE
)
exchangeable_check <- check_brms_partner_prototype(
  simulations,
  dyad = "dyad",
  plot = FALSE
)
small_simulations <- simulate_brms_partner_prototype(
  model,
  nsim = 5,
  seed = 17006L
)
small_check <- check_brms_partner_prototype(
  small_simulations,
  dyad = dyad,
  role = role,
  plot = FALSE
)
stopifnot(
  inherits(role_check, "dyadMLM_partner_check"),
  identical(role_check$response, "model-centred"),
  identical(raw_role_check$response, "raw"),
  identical(role_check$backend, "brms"),
  identical(role_check$reference, "posterior predictive"),
  identical(role_check$parameter_uncertainty, "included"),
  identical(role_check$random_effects, "new"),
  identical(
    role_check$statistics_table,
    explicit_model_centred_role_check$statistics_table
  ),
  identical(
    role_check$replicated_statistics,
    explicit_model_centred_role_check$replicated_statistics
  ),
  identical(
    role_check$statistics_table,
    direct_shared_role_check$statistics_table
  ),
  identical(
    role_check$replicated_statistics,
    direct_shared_role_check$replicated_statistics
  ),
  identical(dim(role_check$replicated_statistics), c(60L, 6L)),
  identical(dim(raw_role_check$replicated_statistics), c(60L, 6L)),
  identical(dim(exchangeable_check$replicated_statistics), c(60L, 4L)),
  identical(dim(small_check$replicated_statistics), c(5L, 6L)),
  all(is.finite(unlist(role_check$statistics_table[, c(
    "observed_value", "replicated_median", "replicated_lower",
    "replicated_upper", "observed_quantile"
  )]))),
  all(is.finite(unlist(exchangeable_check$statistics_table[, c(
    "observed_value", "replicated_median", "replicated_lower",
    "replicated_upper", "observed_quantile"
  )])))
)

calculate_statistics <- getFromNamespace(
  "calculate_partner_response_statistics",
  "dyadMLM"
)
expected_observed_statistics <- calculate_statistics(
  simulations$observed_response - simulations$response_center,
  matrix(seq_len(nrow(analysis_data)), ncol = 2L, byrow = TRUE),
  use_role_specific_statistics = TRUE
)
expected_raw_observed_statistics <- calculate_statistics(
  simulations$observed_response,
  matrix(seq_len(nrow(analysis_data)), ncol = 2L, byrow = TRUE),
  use_role_specific_statistics = TRUE
)
expected_raw_replicated_statistics <- t(apply(
  simulations$simulated_responses,
  MARGIN = 1L,
  FUN = calculate_statistics,
  paired_row_indices = matrix(
    seq_len(nrow(analysis_data)),
    ncol = 2L,
    byrow = TRUE
  ),
  use_role_specific_statistics = TRUE
))
expected_replicated_intervals <- apply(
  role_check$replicated_statistics,
  2L,
  stats::quantile,
  probs = c(0.025, 0.975),
  names = FALSE
)
stopifnot(
  isTRUE(all.equal(
    role_check$statistics_table$observed_value,
    unname(expected_observed_statistics),
    tolerance = 1e-10
  )),
  isTRUE(all.equal(
    raw_role_check$statistics_table$observed_value,
    unname(expected_raw_observed_statistics),
    tolerance = 1e-10
  )),
  isTRUE(all.equal(
    unname(raw_role_check$replicated_statistics),
    unname(expected_raw_replicated_statistics),
    tolerance = 1e-10
  )),
  !isTRUE(all.equal(
    role_check$statistics_table$observed_value,
    raw_role_check$statistics_table$observed_value
  )),
  isTRUE(all.equal(
    role_check$statistics_table$replicated_lower,
    unname(expected_replicated_intervals[1L, ]),
    tolerance = 1e-10
  )),
  isTRUE(all.equal(
    role_check$statistics_table$replicated_upper,
    unname(expected_replicated_intervals[2L, ]),
    tolerance = 1e-10
  ))
)

# Exercise the single user-facing plot on a real graphics device. The method
# must remain invisible and return the original object.
plot_file <- tempfile(fileext = ".pdf")
grDevices::pdf(plot_file, width = 8, height = 6)
original_plot_margins <- graphics::par("mar")
stopifnot(
  identical(
    plot(role_check, parameterization = "member", ask = FALSE),
    role_check
  ),
  identical(
    plot(small_check, parameterization = "member", ask = FALSE),
    small_check
  ),
  identical(
    plot(raw_role_check, parameterization = "member", ask = FALSE),
    raw_role_check
  ),
  identical(
    plot(
      exchangeable_check,
      parameterization = "member",
      ask = FALSE
    ),
    exchangeable_check
  ),
  identical(graphics::par("mar"), original_plot_margins)
)
grDevices::dev.off()
unlink(plot_file)

# Response-addition terms must fail before observed and replicated values can
# be compared on different scales.
censored_model_copy <- model
censored_model_copy$formula$formula <-
  outcome | cens(censoring) ~ role + x + (1 | dyad)
censored_error <- tryCatch(
  simulate_brms_partner_prototype(censored_model_copy, nsim = 2, seed = 1),
  error = conditionMessage
)
stopifnot(
  is.character(censored_error),
  grepl("plain response", censored_error, fixed = TRUE)
)

non_gaussian_random_effect_copy <- model
non_gaussian_random_effect_copy$formula$formula <-
  outcome ~ role + x + (1 | gr(dyad, dist = "student"))
non_gaussian_random_effect_error <- tryCatch(
  simulate_brms_partner_prototype(
    non_gaussian_random_effect_copy,
    nsim = 2,
    seed = 1
  ),
  error = conditionMessage
)
stopifnot(
  is.character(non_gaussian_random_effect_error),
  grepl("Gaussian random intercept", non_gaussian_random_effect_error,
        fixed = TRUE)
)

autocorrelation_model_copy <- model
autocorrelation_model_copy$formula$formula <-
  outcome ~ role + x + ar(time = x, gr = dyad) + (1 | dyad)
autocorrelation_error <- tryCatch(
  simulate_brms_partner_prototype(
    autocorrelation_model_copy,
    nsim = 2,
    seed = 1
  ),
  error = conditionMessage
)
stopifnot(
  is.character(autocorrelation_error),
  grepl("Autocorrelation structures", autocorrelation_error, fixed = TRUE)
)

message("BRMS_PARTNER_PROTOTYPE_SMOKE_OK")
