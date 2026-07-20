# Scratch helpers for developing dyadMLM internals.
#
# Source this file, then call one of:
#   setup_validate_debug()
#   setup_infer_debug()
#   setup_infer_debug(
#     set_exchangeable_compositions = "female-male",
#     pool_compositions = list(
#       romantic_couples = c("female-female", "male-male", "female-male")
#     )
#   )
#   setup_center_debug()
#   setup_add_actor_partner_debug()
#   setup_add_dyad_individual_debug()
#   setup_add_dyadic_score_debug()
#   debugonce(add_dyadic_score_columns)
#   add_dyadic_score_columns(data)
#
# Each helper assigns `data` and the main local variables used inside the
# corresponding internal function to the global environment. This makes it easy
# to copy lines from the function body into the console and run them manually.


load_dyad_debug_internals <- function() {
  source("R/utils-args.R")
  source("R/utils-compositions.R")
  source("R/assign_arbitrary_member_roles.R")
  source("R/validate_dyad_data.R")
  source("R/infer_dyad_compositions.R")
  source("R/center_predictors.R")
  source("R/add_temporal_lag_columns.R")
  source("R/validate-model-compatibility.R")
  source("R/add_actor_partner_columns.R")
  source("R/add_dyad_individual_columns.R")
  source("R/add_dyadic_score_columns.R")

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
                              set_exchangeable_compositions = NULL,
                              pool_compositions = NULL) {
  load_dyad_debug_internals()

  data <- validate_dyad_data(
    load_debug_ild_data(dataset),
    group = coupleID,
    member = personID,
    role = gender,
    time = diaryday,
    predictors = provided_support
  )

  meta_data <- attr(data, "dyadMLM")
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
      .dy_raw_composition = {
        canonical_composition(.data[[role_name]])
      },
      .dy_dyad_type = {
        has_one_role <- dplyr::n_distinct(.data[[role_name]]) == 1

        if (has_one_role) {
          "exchangeable"
        } else {
          "distinguishable"
        }
      },
      .dy_dyad_type_source = "inferred",
      .groups = "drop"
    ) |>
    dplyr::mutate(
      .dy_composition = .data$.dy_raw_composition,
      .dy_pool_member = NA_character_
    )

  resolved_set_exchangeable_compositions <- resolve_composition_references(
    references = set_exchangeable_compositions,
    observed_compositions = dyad_roles[[dyad_composition_col]],
    arg_name = "set_exchangeable_compositions"
  )

  dyad_roles_after_exchangeability <- apply_exchangeable_composition_overrides(
    dyad_roles = dyad_roles,
    set_exchangeable_compositions = set_exchangeable_compositions
  )

  dyad_roles_after_pooling <- apply_pool_compositions(
    dyad_roles = dyad_roles_after_exchangeability,
    pool_compositions = pool_compositions
  )

  dyad_compositions <- dyad_roles_after_pooling |>
    dplyr::group_by(
      composition = .data[[dyad_composition_col]]
    ) |>
    dplyr::summarise(
      dyad_type = dplyr::first(.data[[dyad_type_col]]),
      dyad_type_source = ifelse(
        dplyr::n_distinct(.data[[dyad_type_source_col]]) == 1L,
        dplyr::first(.data[[dyad_type_source_col]]),
        "mixed"
      ),
      pooled_from = paste(sort(unique(stats::na.omit(.data[[dyad_pool_member_col]]))), collapse = ", "),
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
    set_exchangeable_compositions = set_exchangeable_compositions,
    pool_compositions = pool_compositions,
    resolved_set_exchangeable_compositions = resolved_set_exchangeable_compositions,
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
                               set_exchangeable_compositions = NULL,
                               pool_compositions = NULL) {
  load_dyad_debug_internals()

  data <- validate_dyad_data(
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
    set_exchangeable_compositions = set_exchangeable_compositions,
    pool_compositions = pool_compositions
  )

  meta_data <- attr(data, "dyadMLM")
  out <- data
  group <- meta_data$group
  member <- meta_data$member
  predictors <- meta_data$predictors
  temporal_predictor_decomposition <- meta_data$temporal_predictor_decomposition

  assign_debug_vars(
    data = data,
    set_exchangeable_compositions = set_exchangeable_compositions,
    pool_compositions = pool_compositions,
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
                                          set_exchangeable_compositions = NULL,
                                          pool_compositions = NULL) {
  load_dyad_debug_internals()

  data <- validate_dyad_data(
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
    set_exchangeable_compositions = set_exchangeable_compositions,
    pool_compositions = pool_compositions
  )
  data <- center_predictors(data)

  meta_data <- attr(data, "dyadMLM")
  out <- data
  group <- meta_data$group
  member <- meta_data$member
  has_time <- meta_data$longitudinal
  time <- meta_data$time
  predictors <- meta_data$predictors
  temporal_predictor_decompositions <- meta_data$temporal_predictor_decompositions

  assign_debug_vars(
    data = data,
    set_exchangeable_compositions = set_exchangeable_compositions,
    pool_compositions = pool_compositions,
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
                                            set_exchangeable_compositions = NULL,
                                            pool_compositions = NULL) {
  load_dyad_debug_internals()

  data <- validate_dyad_data(
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
    set_exchangeable_compositions = set_exchangeable_compositions,
    pool_compositions = pool_compositions
  )
  data <- center_predictors(data)

  meta_data <- attr(data, "dyadMLM")
  out <- data
  group <- meta_data$group
  member <- meta_data$member
  has_time <- meta_data$longitudinal
  time <- meta_data$time
  temporal_predictor_decompositions <- meta_data$temporal_predictor_decompositions

  dim_predictors <- tibble::tibble(
    predictor = character(),
    component = character(),
    lag = integer(),
    source_column = character(),
    mean_column = character(),
    deviation_column = character(),
    dyad_decomposition_level = character()
  )

  i <- 1L
  predictor <- temporal_predictor_decompositions$predictor[[i]]
  component <- temporal_predictor_decompositions$component[[i]]
  lag <- temporal_predictor_decompositions$lag[[i]]
  source_col <- temporal_predictor_decompositions$column[[i]]

  column_stem <- make_dyad_predictor_column_stem(
    predictor = predictor,
    component = component,
    source_col = source_col,
    lag = lag
  )
  lag_suffix <- make_predictor_lag_suffix(lag)
  mean_col <- paste0(column_stem, "_dyad_mean", lag_suffix)
  if (component == "raw") {
    mean_col <- paste0(column_stem, "_dyad_mean_gmc", lag_suffix)
  }
  deviation_col <- paste0(column_stem, "_within_dyad_dev", lag_suffix)
  dyad_decomposition_level <- "dyad"
  if (has_time && component %in% c("raw", "cwp")) {
    dyad_decomposition_level <- "dyad_time"
  }

  assign_debug_vars(
    data = data,
    set_exchangeable_compositions = set_exchangeable_compositions,
    pool_compositions = pool_compositions,
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
    lag = lag,
    source_col = source_col,
    column_stem = column_stem,
    lag_suffix = lag_suffix,
    mean_col = mean_col,
    deviation_col = deviation_col,
    dyad_decomposition_level = dyad_decomposition_level
  )

  invisible(data)
}


setup_add_dyadic_score_debug <- function(dataset = c("gaussian", "tweedie"), seed = 123,
                                         dsm_role_order = c("female", "male")) {
  load_dyad_debug_internals()

  data <- validate_dyad_data(
    load_debug_ild_data(dataset),
    group = coupleID,
    member = personID,
    role = gender,
    time = diaryday,
    predictors = provided_support,
    model_type = "dsm",
    dsm_role_order = dsm_role_order
  )
  data <- infer_dyad_compositions(
    data,
    seed = seed,
    include_compositions = "female-male"
  )
  validate_dsm_compatibility(data)
  data <- center_predictors(data)

  meta_data <- attr(data, "dyadMLM")
  dsm_role_order <- meta_data$dsm_role_order
  role <- meta_data$role

  assign_debug_vars(
    data = data,
    meta_data = meta_data,
    dsm_role_order = dsm_role_order,
    role = role
  )

  invisible(data)
}
