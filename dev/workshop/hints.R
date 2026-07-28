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
  ild_prepare_data = list(
    structure = paste(
      "Use prepare_dyad_data() with:",
      "- dyad = couple_id",
      "- member = person_id",
      "- role = gender",
      "- time = diaryday",
      "- predictors = your focal predictor",
      "- model_types = \"apim\"",
      "- temporal_decomposition = \"2l\"",
      "- include_arbitrary_member_contrast = TRUE",
      sep = "\n"
    )
  ),
  ild_model = list(
    structure = paste(
      "Check that the model documents:",
      "- role-specific or pooled intercepts",
      "- within-person actor and partner effects",
      "- between-person actor and partner effects",
      "- stable and same-occasion dyadic covariance",
      "- the chosen time trend and residual temporal structure",
      sep = "\n"
    )
  ),
  ild_report_results = list(
    structure = paste(
      "Useful starting points:",
      "- parameters::model_parameters(model, effects = \"fixed\")",
      "- parameters::model_parameters(model, effects = \"random\")",
      "- plot(parameters::model_parameters(model, effects = \"fixed\"))",
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
