# Scratch helpers for developing interdep internals.
#
# Source this file, then call one of:
#   setup_validate_debug()
#   setup_infer_debug()
#   setup_infer_debug(
#     set_compositions_exchangeable = "female-male",
#     composition_pooling = list(
#       romantic_couples = c("female-female", "male-male", "female-male")
#     )
#   )
#   setup_center_debug()
#   setup_add_actor_partner_debug()
#   setup_add_dyad_individual_debug()
#   setup_add_undirected_dyadic_score_debug()
#
# Each helper assigns `data` and the main local variables used inside the
# corresponding internal function to the global environment. This makes it easy
# to copy lines from the function body into the console and run them manually.


load_interdep_debug_internals <- function() {
  source("R/utils-args.R")
  source("R/utils-compositions.R")
  source("R/assign_arbitrary_member_roles.R")
  source("R/validate_interdep_data.R")
  source("R/infer_dyad_compositions.R")
  source("R/center_predictors.R")
  source("R/validate-model-compatibility.R")
  source("R/add_actor_partner_columns.R")
  source("R/add_dyad_individual_columns.R")
  source("R/add_undirected_dyadic_score_columns.R")

  invisible(TRUE)
}

load_debug_ild_data <- function(dataset = c("gaussian", "tweedie")) {
  dataset <- rlang::arg_match(dataset)
  data_env <- new.env(parent = emptyenv())

  if (dataset == "gaussian") {
    load("data/example_dyadic_ILD_mixed.rda", envir = data_env)
    return(data_env$example_dyadic_ILD_mixed)
  }

  load("data/example_dyadic_ILD_mixed_tweedie.rda", envir = data_env)
  data_env$example_dyadic_ILD_mixed_tweedie
}


assign_debug_vars <- function(..., envir = .GlobalEnv) {
  vars <- list(...)

  for (name in names(vars)) {
    assign(name, vars[[name]], envir = envir)
  }

  invisible(vars)
}


setup_validate_debug <- function(dataset = c("gaussian", "tweedie")) {
  data <- load_debug_ild_data(dataset)
  out <- tibble::as_tibble(data)

  group_name <- "coupleID"
  member_name <- "personID"
  role_name <- "gender"
  time_name <- "diaryday"
  predictor_names <- "provided_support"

  has_role <- TRUE
  has_time <- TRUE
  model_type <- "apim"
  temporal_predictor_decomposition <- "auto"
  incomplete_dyads <- "error"
  missing_role <- "error"

  assign_debug_vars(
    data = data,
    out = out,
    group_name = group_name,
    member_name = member_name,
    role_name = role_name,
    time_name = time_name,
    predictor_names = predictor_names,
    has_role = has_role,
    has_time = has_time,
    model_type = model_type,
    temporal_predictor_decomposition = temporal_predictor_decomposition,
    incomplete_dyads = incomplete_dyads,
    missing_role = missing_role
  )

  invisible(data)
}


setup_infer_debug <- function(dataset = c("gaussian", "tweedie"), seed = 123,
                              set_compositions_exchangeable = NULL,
                              composition_pooling = NULL) {
  load_interdep_debug_internals()

  data <- validate_interdep_data(
    load_debug_ild_data(dataset),
    group = coupleID,
    member = personID,
    role = gender,
    time = diaryday,
    predictors = provided_support
  )

  meta_data <- attr(data, "interdep")
  group_name <- meta_data$group
  member_name <- meta_data$member
  role_name <- meta_data$role
  has_role <- !is.null(role_name)

  dyad_roles <- data |>
    dplyr::distinct(
      .data[[group_name]],
      .data[[member_name]],
      .data[[role_name]]
    ) |>
    dplyr::group_by(.data[[group_name]]) |>
    dplyr::summarise(
      .i_raw_composition = {
        canonical_composition(.data[[role_name]])
      },
      .i_dyad_type = {
        has_one_role <- dplyr::n_distinct(.data[[role_name]]) == 1

        if (has_one_role) {
          "exchangeable"
        } else {
          "distinguishable"
        }
      },
      .i_dyad_type_source = "inferred",
      .groups = "drop"
    ) |>
    dplyr::mutate(
      .i_composition = .data$.i_raw_composition,
      .i_pool_member = NA_character_
    )

  resolved_set_compositions_exchangeable <- resolve_composition_references(
    references = set_compositions_exchangeable,
    observed_compositions = dyad_roles[[interdep_composition_col]],
    arg_name = "set_compositions_exchangeable"
  )

  dyad_roles_after_exchangeability <- apply_exchangeable_composition_overrides(
    dyad_roles = dyad_roles,
    set_compositions_exchangeable = set_compositions_exchangeable
  )

  dyad_roles_after_pooling <- apply_composition_pooling(
    dyad_roles = dyad_roles_after_exchangeability,
    composition_pooling = composition_pooling
  )

  dyad_compositions <- dyad_roles_after_pooling |>
    dplyr::group_by(
      composition = .data[[interdep_composition_col]]
    ) |>
    dplyr::summarise(
      dyad_type = dplyr::first(.data[[interdep_dyad_type_col]]),
      dyad_type_source = ifelse(
        dplyr::n_distinct(.data[[interdep_dyad_type_source_col]]) == 1L,
        dplyr::first(.data[[interdep_dyad_type_source_col]]),
        "mixed"
      ),
      pooled_from = paste(sort(unique(stats::na.omit(.data[[interdep_pool_member_col]]))), collapse = ", "),
      n_dyads = dplyr::n(),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      pooled_from = dplyr::na_if(.data$pooled_from, "")
    ) |>
    dplyr::select(
      "composition",
      "dyad_type",
      "dyad_type_source",
      "pooled_from",
      "n_dyads"
    )

  assign_debug_vars(
    data = data,
    seed = seed,
    set_compositions_exchangeable = set_compositions_exchangeable,
    composition_pooling = composition_pooling,
    resolved_set_compositions_exchangeable = resolved_set_compositions_exchangeable,
    meta_data = meta_data,
    group_name = group_name,
    member_name = member_name,
    role_name = role_name,
    has_role = has_role,
    dyad_roles = dyad_roles,
    dyad_roles_after_exchangeability = dyad_roles_after_exchangeability,
    dyad_roles_after_pooling = dyad_roles_after_pooling,
    dyad_compositions = dyad_compositions
  )

  invisible(data)
}


setup_center_debug <- function(dataset = c("gaussian", "tweedie"), seed = 123,
                               set_compositions_exchangeable = NULL,
                               composition_pooling = NULL) {
  load_interdep_debug_internals()

  data <- validate_interdep_data(
    load_debug_ild_data(dataset),
    group = coupleID,
    member = personID,
    role = gender,
    time = diaryday,
    predictors = provided_support
  )
  data <- infer_dyad_compositions(
    data,
    seed = seed,
    set_compositions_exchangeable = set_compositions_exchangeable,
    composition_pooling = composition_pooling
  )

  meta_data <- attr(data, "interdep")
  out <- data
  group <- meta_data$group
  member <- meta_data$member
  predictors <- meta_data$predictors
  temporal_predictor_decomposition <- meta_data$temporal_predictor_decomposition

  assign_debug_vars(
    data = data,
    set_compositions_exchangeable = set_compositions_exchangeable,
    composition_pooling = composition_pooling,
    meta_data = meta_data,
    out = out,
    group = group,
    member = member,
    predictors = predictors,
    temporal_predictor_decomposition = temporal_predictor_decomposition
  )

  invisible(data)
}


setup_add_actor_partner_debug <- function(dataset = c("gaussian", "tweedie"), seed = 123,
                                          set_compositions_exchangeable = NULL,
                                          composition_pooling = NULL) {
  load_interdep_debug_internals()

  data <- validate_interdep_data(
    load_debug_ild_data(dataset),
    group = coupleID,
    member = personID,
    role = gender,
    time = diaryday,
    predictors = provided_support
  )
  data <- infer_dyad_compositions(
    data,
    seed = seed,
    set_compositions_exchangeable = set_compositions_exchangeable,
    composition_pooling = composition_pooling
  )
  data <- center_predictors(data)

  meta_data <- attr(data, "interdep")
  out <- data
  group <- meta_data$group
  member <- meta_data$member
  has_time <- meta_data$longitudinal
  time <- meta_data$time
  predictors <- meta_data$predictors
  temporal_predictor_decompositions <- meta_data$temporal_predictor_decompositions

  assign_debug_vars(
    data = data,
    set_compositions_exchangeable = set_compositions_exchangeable,
    composition_pooling = composition_pooling,
    meta_data = meta_data,
    out = out,
    group = group,
    member = member,
    has_time = has_time,
    time = time,
    predictors = predictors,
    temporal_predictor_decompositions = temporal_predictor_decompositions
  )

  invisible(data)
}


setup_add_dyad_individual_debug <- function(dataset = c("gaussian", "tweedie"), seed = 123,
                                            set_compositions_exchangeable = NULL,
                                            composition_pooling = NULL) {
  load_interdep_debug_internals()

  data <- validate_interdep_data(
    load_debug_ild_data(dataset),
    group = coupleID,
    member = personID,
    role = gender,
    time = diaryday,
    predictors = provided_support,
    model_type = "dim"
  )
  data <- infer_dyad_compositions(
    data,
    seed = seed,
    set_compositions_exchangeable = set_compositions_exchangeable,
    composition_pooling = composition_pooling
  )
  data <- center_predictors(data)

  meta_data <- attr(data, "interdep")
  out <- data
  group <- meta_data$group
  member <- meta_data$member
  has_time <- meta_data$longitudinal
  time <- meta_data$time
  temporal_predictor_decompositions <- meta_data$temporal_predictor_decompositions

  dim_predictors <- tibble::tibble(
    predictor = character(),
    component = character(),
    source_column = character(),
    mean_column = character(),
    deviation_column = character(),
    dyad_decomposition_level = character()
  )

  i <- 1L
  predictor <- temporal_predictor_decompositions$predictor[[i]]
  component <- temporal_predictor_decompositions$component[[i]]
  source_col <- temporal_predictor_decompositions$column[[i]]

  predictor_suffix <- make_interdep_suffixes(predictor)[[predictor]]
  column_stem <- source_col
  mean_col <- paste0(column_stem, "_dyad_mean")
  deviation_col <- paste0(column_stem, "_within_dyad_deviation")
  dyad_decomposition_level <- if (component == "cwp") "dyad_time" else "dyad"

  assign_debug_vars(
    data = data,
    set_compositions_exchangeable = set_compositions_exchangeable,
    composition_pooling = composition_pooling,
    meta_data = meta_data,
    out = out,
    group = group,
    member = member,
    has_time = has_time,
    time = time,
    temporal_predictor_decompositions = temporal_predictor_decompositions,
    dim_predictors = dim_predictors,
    i = i,
    predictor = predictor,
    component = component,
    source_col = source_col,
    predictor_suffix = predictor_suffix,
    column_stem = column_stem,
    mean_col = mean_col,
    deviation_col = deviation_col,
    dyad_decomposition_level = dyad_decomposition_level
  )

  invisible(data)
}


setup_add_undirected_dyadic_score_debug <- function(dataset = c("gaussian", "tweedie"), seed = 123,
                                                    set_compositions_exchangeable = NULL,
                                                    composition_pooling = NULL) {
  dataset <- rlang::arg_match(dataset)
  load_interdep_debug_internals()

  raw_data <- load_debug_ild_data(dataset)
  outcome_name <- if (dataset == "gaussian") "closeness" else "physical_activity"

  data <- validate_interdep_data(
    raw_data,
    group = coupleID,
    member = personID,
    time = diaryday,
    predictors = provided_support,
    model_type = "dim"
  )
  data <- infer_dyad_compositions(
    data,
    seed = seed,
    set_compositions_exchangeable = set_compositions_exchangeable,
    composition_pooling = composition_pooling
  )
  data <- center_predictors(data)
  attr(data, "interdep")$outcomes <- outcome_name

  meta_data <- attr(data, "interdep")
  out <- data
  group <- meta_data$group
  member <- meta_data$member
  has_time <- meta_data$longitudinal
  time <- meta_data$time
  outcomes <- meta_data$outcomes
  temporal_predictor_decompositions <- meta_data$temporal_predictor_decompositions

  dsm_outcomes <- tibble::tibble(
    outcome = character(),
    source_column = character(),
    mean_column = character(),
    deviation_column = character()
  )

  outcome <- outcomes[[1]]
  outcome_suffix <- make_interdep_suffixes(outcome)[[outcome]]
  column_stem <- paste0(interdep_reserved_prefix, outcome_suffix, "_raw")
  mean_col <- paste0(column_stem, "_dyad_mean")
  deviation_col <- paste0(column_stem, "_within_dyad_deviation")
  dyad_decomposition_level <- if (has_time) "dyad_time" else "dyad"

  assign_debug_vars(
    raw_data = raw_data,
    data = data,
    set_compositions_exchangeable = set_compositions_exchangeable,
    composition_pooling = composition_pooling,
    meta_data = meta_data,
    out = out,
    group = group,
    member = member,
    has_time = has_time,
    time = time,
    outcomes = outcomes,
    temporal_predictor_decompositions = temporal_predictor_decompositions,
    dsm_outcomes = dsm_outcomes,
    outcome = outcome,
    outcome_suffix = outcome_suffix,
    column_stem = column_stem,
    mean_col = mean_col,
    deviation_col = deviation_col,
    dyad_decomposition_level = dyad_decomposition_level
  )

  invisible(data)
}
