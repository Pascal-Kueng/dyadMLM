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
      "- model_types = \"apim\"",
      "- include_arbitrary_member_contrast = TRUE",
      "- add_apim_gmc_predictors = TRUE",
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
    structure = paste(
      "Useful functions:",
      "- parameters::model_parameters(model, effects = \"fixed\")",
      "- parameters::model_parameters(model, effects = \"random\")",
      "- plot(parameters::model_parameters(model, effects = \"fixed\"))",
      "- dyadMLM::recover_exchangeable_covariance(model)",
      sep = "\n"
    )
  ),
  ild_prepare_data = list(
    concept = paste(
      "ILD preparation must preserve the dyad, member, role, and actual occasion.",
      "Do not silently treat observations separated by a missing occasion as adjacent."
    ),
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
  ild_describe_data = list(
    concept = paste(
      "Start with compliance and matched occasions, then plot paired trajectories.",
      "Use ICCs and level-specific correlations to separate stable differences",
      "between people from occasion-to-occasion covariation."
    )
  ),
  ild_model = list(
    concept = paste(
      "Separate within-person actor and partner effects from between-person effects.",
      "Add plausible trends to the mean before interpreting a residual temporal process."
    ),
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
  ild_time_structure = list(
    concept = paste(
      "Use discrete-time AR(1) only when the factor levels represent the scheduled spacing.",
      "For unequal time gaps, continuous-time decay may be more natural.",
      "Use lagged outcomes only when carryover is part of the research question."
    )
  ),
  ild_diagnostics = list(
    concept = paste(
      "Standard residual calibration is only the first check.",
      "Also inspect residual patterns over time and remaining temporal and",
      "cross-partner dependence."
    )
  ),
  ild_report_results = list(
    concept = paste(
      "Report within-person and between-person actor and partner effects separately.",
      "Also document the time trend, residual temporal process, and",
      "same-occasion cross-partner covariance."
    ),
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
