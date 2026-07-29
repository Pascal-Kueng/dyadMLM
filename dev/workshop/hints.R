.workshop_hints <- list(
  example_hint = list(
    run_chunk_without_comment = paste(
      "You have revealed your first hint.",
      "You can use the other optional hints in the same way."
    )
  ),
  prepare_data = list(
    structure = paste(
      "Use prepare_dyad_data() with:",
      "- dyad = couple_id",
      "- member = person_id",
      "- role = gender",
      "- predictors = YOUR_PREDICTOR",
      "- model_types = \"apim\"",
      "- include_arbitrary_member_contrast = TRUE",
      "- add_apim_gmc_predictors = TRUE",
      sep = "\n"
    )
  ),
  descriptive_summary = list(
    functions = paste(
      "Use tidyr::pivot_wider() to create one row per couple, then",
      "report::report_table() to summarize the role-specific columns."
    ),
    example_code = paste(
      "my_wide_data <- my_data |>",
      "  dplyr::select(couple_id, gender, YOUR_PREDICTOR, YOUR_OUTCOME) |>",
      "  tidyr::pivot_wider(",
      "    names_from = gender,",
      "    values_from = c(YOUR_PREDICTOR, YOUR_OUTCOME)",
      "  )",
      "",
      "my_wide_data |>",
      "  dplyr::select(-couple_id) |>",
      "  report::report_table() |>",
      "  summary()",
      sep = "\n"
    )
  ),
  histograms = list(
    example_code = paste(
      "hist(my_data$YOUR_VARIABLE)",
      "",
      "hist(",
      "  my_data[my_data$gender == \"male\", ]$YOUR_VARIABLE",
      ")",
      sep = "\n"
    )
  ),
  partner_similarity = list(
    correlations = paste(
      "Use correlation::correlation() on my_wide_data. For example:",
      "",
      "correlation::correlation(",
      "  my_wide_data,",
      "  select = c(\"YOUR_PREDICTOR_female\", \"YOUR_OUTCOME_female\"),",
      "  select2 = c(\"YOUR_PREDICTOR_male\", \"YOUR_OUTCOME_male\")",
      ")",
      sep = "\n"
    ),
    plot = paste(
      "For one focal variable:",
      "",
      "plot(",
      "  my_wide_data$YOUR_VARIABLE_female,",
      "  my_wide_data$YOUR_VARIABLE_male,",
      "  xlab = \"Women\", ylab = \"Men\"",
      ")",
      "abline(",
      "  lm(YOUR_VARIABLE_male ~ YOUR_VARIABLE_female, data = my_wide_data),",
      "  col = \"navy\", lwd = 2",
      ")",
      sep = "\n"
    )
  ),
  distinguishable_model = list(
    concept = paste(
      "A distinguishable APIM needs role-specific intercepts, actor effects,",
      "partner effects, and a covariance between the two members' residuals."
    ),
    structure = paste(
      "Check that your glmmTMB model contains:",
      "- 0 + both role indicators",
      "- each role indicator interacted with the actor predictor",
      "- each role indicator interacted with the partner predictor",
      "- an unstructured role-specific random-effects block within couple",
      "- dispformula = ~ 0",
      sep = "\n"
    ),
    example_code = paste(
      "Example using the tutorial variables:",
      "",
      "my_model <- glmmTMB(",
      "  total_mvpa ~",
      "    0 + .is_female + .is_male +",
      "    .is_female:.efficacy_gmc_actor +",
      "    .is_male:.efficacy_gmc_actor +",
      "    .is_female:.efficacy_gmc_partner +",
      "    .is_male:.efficacy_gmc_partner +",
      "    (0 + .is_female + .is_male | couple_id),",
      "  dispformula = ~ 0,",
      "  family = gaussian(),",
      "  data = my_data",
      ")",
      sep = "\n"
    )
  ),
  robustness_mahalanobis = list(
    columns = paste(
      "For example, suppose retained_model uses:",
      "sqrt_total_mvpa ~ .efficacy_gmc_actor + .efficacy_gmc_partner + ...",
      "",
      "Then use these quoted column names:",
      "- actor plots: x = \".efficacy_gmc_actor\", y = \"sqrt_total_mvpa\"",
      "- partner plots: x = \".efficacy_gmc_partner\", y = \"sqrt_total_mvpa\"",
      "",
      "Replace the example names with the columns from your own model. Do not",
      "switch back to raw efficacy or total_mvpa if your model used the",
      "centered predictors and stored transformed outcome.",
      sep = "\n"
    )
  ),
  robustness_refit = list(
    ids = paste(
      "Store the IDs in a vector. For example:",
      "DYAD_IDS_TO_EXCLUDE <- c(2, 35)"
    )
  ),
  exchangeable_model = list(
    fixed_effects = paste(
      "Replace the role-specific fixed effects with one pooled intercept,",
      "one actor effect, and one partner effect."
    ),
    random_effects = paste(
      "Represent the exchangeable residual covariance with a shared block",
      "(1 | couple_id) and a difference block",
      "(0 + .member_contrast_arbitrary | couple_id)."
    ),
    example_code = paste(
      "my_exchangeable_model <- glmmTMB(",
      "  YOUR_OUTCOME ~",
      "    1 +",
      "    YOUR_ACTOR_PREDICTOR +",
      "    YOUR_PARTNER_PREDICTOR +",
      "    (1 | couple_id) +",
      "    (0 + .member_contrast_arbitrary | couple_id),",
      "  dispformula = ~ 0,",
      "  family = gaussian(),",
      "  data = my_data",
      ")",
      sep = "\n"
    )
  ),
  report_results = list(
    fixed_effects = paste(
      "parameters::model_parameters(retained_model, effects = \"fixed\")"
    ),
    random_effects = paste(
      "parameters::model_parameters(retained_model, effects = \"random\")",
      "",
      "For an exchangeable model, also use:",
      "dyadMLM::recover_exchangeable_covariance(retained_model)",
      sep = "\n"
    ),
    plot = paste(
      "parameters::model_parameters(retained_model, effects = \"fixed\") |>",
      "  plot(show_intercept = TRUE)",
      sep = "\n"
    )
  ),
  dim_transformation = list(
    formulas = paste(
      "The between-dyad effect is the sum of the actor and partner effects:",
      "b_mean <- b_actor + b_partner",
      "",
      "The within-dyad effect is their difference:",
      "b_dev <- b_actor - b_partner",
      sep = "\n"
    )
  ),
  outcome_scale = list(
    matched_models = paste(
      "The distinguishable and exchangeable models must use the same stored",
      "outcome column and the same analysis rows.",
      "",
      "If you transform the outcome, first add one new column to my_data.",
      "Then refit and diagnose both candidate models with that column as the",
      "outcome before comparing them.",
      "",
      "Do not compare a raw-outcome model with a transformed-outcome model.",
      "compare_nested_models() will reject models fitted on different outcome",
      "columns or values.",
      "",
      "The helper checks compatibility and estimation quality, but it cannot",
      "prove mathematical nesting. The formulas must differ only by the",
      "constraints you intend to test.",
      sep = "\n"
    )
  ),
  ild_preparation = list(
    solution = paste(
      "my_ild_data <- dyadMLM::prepare_dyad_data(",
      "  data = raw_ild_data,",
      "  dyad = coupleID,",
      "  member = personID,",
      "  role = gender,",
      "  time = diaryday,",
      "  predictors = provided_support,",
      "  model_types = \"apim\",",
      "  temporal_decomposition = \"2l\"",
      ")",
      sep = "\n"
    ),
    time_variables = paste(
      "my_ild_data <- my_ild_data |>",
      "  dplyr::mutate(",
      "    diaryday_c = (diaryday - 6.5) / 13,",
      "    diaryday_f = factor(diaryday, levels = 0:13)",
      "  )",
      sep = "\n"
    )
  ),
  ild_descriptives = list(
    summary = paste(
      "summary(",
      "  my_ild_data[c(\"provided_support\", \"closeness\")]",
      ")",
      "",
      "my_ild_data |>",
      "  dplyr::group_by(gender) |>",
      "  dplyr::summarise(",
      "    n = dplyr::n(),",
      "    support_mean = mean(provided_support, na.rm = TRUE),",
      "    support_sd = stats::sd(provided_support, na.rm = TRUE),",
      "    closeness_mean = mean(closeness, na.rm = TRUE),",
      "    closeness_sd = stats::sd(closeness, na.rm = TRUE),",
      "    .groups = \"drop\"",
      "  )",
      sep = "\n"
    ),
    histograms = paste(
      "old_par <- graphics::par(mfrow = c(2, 2))",
      "",
      "graphics::hist(",
      "  my_ild_data$provided_support[my_ild_data$gender == \"female\"],",
      "  main = \"Provided support: women\",",
      "  xlab = \"Provided support\"",
      ")",
      "graphics::hist(",
      "  my_ild_data$provided_support[my_ild_data$gender == \"male\"],",
      "  main = \"Provided support: men\",",
      "  xlab = \"Provided support\"",
      ")",
      "graphics::hist(",
      "  my_ild_data$closeness[my_ild_data$gender == \"female\"],",
      "  main = \"Closeness: women\",",
      "  xlab = \"Closeness\"",
      ")",
      "graphics::hist(",
      "  my_ild_data$closeness[my_ild_data$gender == \"male\"],",
      "  main = \"Closeness: men\",",
      "  xlab = \"Closeness\"",
      ")",
      "",
      "graphics::par(old_par)",
      sep = "\n"
    )
  ),
  ild_trajectories = list(
    structure = paste(
      "The measure and score columns now identify what is measured and its value.",
      "Each line needs one group per person within couple. Put measures in facet",
      "rows and couples in facet columns.",
      sep = "\n"
    ),
    solution = paste(
      "ggplot2::ggplot(",
      "  trajectory_data,",
      "  ggplot2::aes(",
      "    x = diaryday,",
      "    y = score,",
      "    color = gender,",
      "    group = interaction(coupleID, personID)",
      "  )",
      ") +",
      "  ggplot2::geom_line(na.rm = TRUE) +",
      "  ggplot2::geom_point(na.rm = TRUE) +",
      "  ggplot2::facet_grid(measure ~ coupleID, scales = \"free_y\") +",
      "  ggplot2::labs(x = \"Diary day\", y = NULL, color = \"Gender\") +",
      "  ggplot2::theme_minimal()",
      sep = "\n"
    )
  ),
  ild_level_associations = list(
    structure = paste(
      "In the within-couple matrix:",
      "- female actor: provided_support_female with closeness_female",
      "- female partner: provided_support_male with closeness_female",
      "- male actor: provided_support_male with closeness_male",
      "- male partner: provided_support_female with closeness_male",
      "",
      "The same pairs in the between-couple matrix describe associations among",
      "the corresponding role-specific person means.",
      sep = "\n"
    ),
    solution = paste(
      "ild_wide_data <- my_ild_data |>",
      "  dplyr::select(",
      "    coupleID, diaryday, gender, provided_support, closeness",
      "  ) |>",
      "  tidyr::pivot_wider(",
      "    names_from = gender,",
      "    values_from = c(provided_support, closeness)",
      "  )",
      "",
      "ild_level_correlations <- wbCorr::wbCorr(",
      "  data = dplyr::select(ild_wide_data, -diaryday),",
      "  cluster = \"coupleID\",",
      "  inference = \"none\"",
      ")",
      "",
      "wbCorr::get_matrix(ild_level_correlations)",
      "wbCorr::get_ICC(ild_level_correlations)",
      sep = "\n"
    )
  ),
  ild_models = list(
    distinguishable_ar1 = paste(
      "ild_ar1_start <- make_ild_ar1_start(my_ild_data)",
      "",
      "distinguishable_ar1_model <- glmmTMB::glmmTMB(",
      "  closeness ~",
      "    0 + .is_female + .is_male +",
      "    .is_female:diaryday_c +",
      "    .is_male:diaryday_c +",
      "    .is_female:.provided_support_cwp_actor +",
      "    .is_male:.provided_support_cwp_actor +",
      "    .is_female:.provided_support_cwp_partner +",
      "    .is_male:.provided_support_cwp_partner +",
      "    .is_female:.provided_support_cbp_actor +",
      "    .is_male:.provided_support_cbp_actor +",
      "    .is_female:.provided_support_cbp_partner +",
      "    .is_male:.provided_support_cbp_partner +",
      "    (0 + .is_female + .is_male | coupleID) +",
      "    ar1(0 + .is_female:diaryday_f | coupleID) +",
      "    ar1(0 + .is_male:diaryday_f | coupleID) +",
      "    (0 + .is_female + .is_male | coupleID:diaryday),",
      "  dispformula = ~ 0,",
      "  family = gaussian(),",
      "  data = my_ild_data,",
      "  control = ild_control,",
      "  start = ild_ar1_start",
      ")",
      sep = "\n"
    ),
    pooled_apim_effects = paste(
      "pooled_apim_effects_start <- make_pooled_apim_effects_start(",
      "  distinguishable_model",
      ")",
      "",
      "pooled_apim_effects_model <- update(",
      "  distinguishable_model,",
      "  formula = . ~ . -",
      "    .is_female:.provided_support_cwp_actor -",
      "    .is_male:.provided_support_cwp_actor -",
      "    .is_female:.provided_support_cwp_partner -",
      "    .is_male:.provided_support_cwp_partner -",
      "    .is_female:.provided_support_cbp_actor -",
      "    .is_male:.provided_support_cbp_actor -",
      "    .is_female:.provided_support_cbp_partner -",
      "    .is_male:.provided_support_cbp_partner +",
      "    .provided_support_cwp_actor +",
      "    .provided_support_cwp_partner +",
      "    .provided_support_cbp_actor +",
      "    .provided_support_cbp_partner,",
      "  start = pooled_apim_effects_start",
      ")",
      sep = "\n"
    )
  ),
  ild_reporting = list(
    solution = paste(
      "ild_fixed_effects <- parameters::model_parameters(",
      "  retained_model,",
      "  effects = \"fixed\",",
      "  ci = 0.95",
      ")",
      "",
      "ild_random_effects <- parameters::model_parameters(",
      "  retained_model,",
      "  effects = \"random\",",
      "  ci = 0.95",
      ")",
      "",
      "ild_fixed_effects",
      "ild_random_effects",
      "glmmTMB::VarCorr(retained_model)",
      sep = "\n"
    ),
    plot = paste(
      "plot(",
      "  ild_fixed_effects,",
      "  show_intercept = TRUE",
      ")",
      sep = "\n"
    ),
    paragraph_template = paste(
      "Use this structure and replace every bracketed item with your result:",
      "",
      "\"We analyzed [number] female-male dyads measured on up to [number]",
      "days. Role-specific AR(1) residual processes were fitted and [diagnostic",
      "result]. [Role-specific / pooled] APIM associations were retained because",
      "[four-df comparison and substantive reason]. Within-person actor and",
      "partner associations were [estimates and 95% CIs]; between-person actor",
      "and partner associations were [estimates and 95% CIs]. Stable dyad,",
      "same-occasion partner, and AR(1) covariance estimates were [summary].",
      "Residual and robustness checks [brief conclusion].\"",
      sep = "\n"
    )
  ),
  ild_diagnostics = list(
    solution = paste(
      "Checkpoint: With the supplied dataset and diagnostic seed, the observed",
      "female and male lag-1 statistics are both compatible with simulations",
      "from the fitted role-specific AR(1) model. Retain the AR(1)",
      "specification unless your other residual plots reveal a clear problem.",
      "",
      "Remember that a nonzero raw residual correlation is not itself a failure:",
      "the calibrated check asks whether it is unusual under the fitted model.",
      sep = "\n"
    )
  ),
  ild_ar1 = list(
    role_specific_syntax = paste(
      "Add these two terms:",
      "",
      "ar1(0 + .is_female:diaryday_f | coupleID) +",
      "ar1(0 + .is_male:diaryday_f | coupleID)",
      "",
      "The levels of diaryday_f must follow the scheduled day order. Keep",
      "the separate coupleID:diaryday covariance block in the model.",
      sep = "\n"
    )
  ),
  ild_model_choices = list(
    role_solution = paste(
      "Checkpoint: For the supplied dataset, the four-df likelihood-ratio test",
      "is chi-squared = 89.70, p < .001. Retain the role-specific focal",
      "associations. This is not a test of full exchangeability because the",
      "baseline, covariance, and AR(1) parameters remain role-specific.",
      "",
      "retained_model <- distinguishable_model",
      sep = "\n"
    )
  ),
  ild_optimizer = list(
    bfgs = paste(
      "The exercise uses this tested control for every candidate model:",
      "",
      "ild_control <- glmmTMB::glmmTMBControl(",
      "  profile = TRUE,",
      "  optimizer = stats::optim,",
      "  optArgs = list(method = \"BFGS\"),",
      "  optCtrl = list(maxit = 2000, reltol = 1e-10)",
      ")",
      "",
      "Add control = ild_control to each direct glmmTMB() call. update() then",
      "inherits it. Still check convergence, the Hessian, and boundaries; the",
      "optimizer does not rescue a statistically inadequate specification.",
      sep = "\n"
    )
  )
)

hint_topics <- function() {
  topics <- names(.workshop_hints)

  cat("Available hint topics:\n")
  cat(paste0("  - ", topics), sep = "\n")
  cat("\n")

  invisible(topics)
}

hint <- function(topic, level = "concept") {
  if (!topic %in% names(.workshop_hints)) {
    stop(
      "Unknown hint topic. Run hint_topics() to see the available topics.",
      call. = FALSE
    )
  }

  topic_hints <- .workshop_hints[[topic]]

  if (!level %in% names(topic_hints)) {
    stop(
      "Available levels for '", topic, "': ",
      paste(names(topic_hints), collapse = ", "),
      call. = FALSE
    )
  }

  hint_text <- topic_hints[[level]]

  cat("\n", hint_text, "\n\n", sep = "")

  invisible(hint_text)
}
