# Scratch helpers for developing interdep internals.
#
# Source this file, then call one of:
#   setup_validate_debug()
#   setup_infer_debug()
#   setup_center_debug()
#   setup_add_actor_partner_debug()
#
# Each helper assigns `data` and the main local variables used inside the
# corresponding internal function to the global environment. This makes it easy
# to copy lines from the function body into the console and run them manually.


load_interdep_debug_internals <- function() {
  source("R/utils-compositions.R")
  source("R/assign_arbitrary_member_roles.R")
  source("R/validate_interdep_data.R")
  source("R/infer_dyad_compositions.R")
  source("R/center_predictors.R")

  invisible(TRUE)
}

load_debug_ild_data <- function(dataset = c("gaussian", "tweedie")) {
  dataset <- rlang::arg_match(dataset)
  data_env <- new.env(parent = emptyenv())

  if (dataset == "gaussian") {
    load("data/example_dyadic_ILD_unified.rda", envir = data_env)
    return(data_env$example_dyadic_ILD_unified)
  }

  load("data/example_dyadic_ILD_unified_tweedie.rda", envir = data_env)
  data_env$example_dyadic_ILD_unified_tweedie
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
  centering <- "auto"
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
    centering = centering,
    incomplete_dyads = incomplete_dyads,
    missing_role = missing_role
  )

  invisible(data)
}


setup_infer_debug <- function(dataset = c("gaussian", "tweedie"), seed = 123) {
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

  assign_debug_vars(
    data = data,
    seed = seed,
    meta_data = meta_data,
    group_name = group_name,
    member_name = member_name,
    role_name = role_name
  )

  invisible(data)
}


setup_center_debug <- function(dataset = c("gaussian", "tweedie"), seed = 123) {
  load_interdep_debug_internals()

  data <- validate_interdep_data(
    load_debug_ild_data(dataset),
    group = coupleID,
    member = personID,
    role = gender,
    time = diaryday,
    predictors = provided_support
  )
  data <- infer_dyad_compositions(data, seed = seed)

  meta_data <- attr(data, "interdep")
  out <- data
  group <- meta_data$group
  member <- meta_data$member
  predictors <- meta_data$predictors
  centering <- meta_data$centering

  assign_debug_vars(
    data = data,
    meta_data = meta_data,
    out = out,
    group = group,
    member = member,
    predictors = predictors,
    centering = centering
  )

  invisible(data)
}


setup_add_actor_partner_debug <- function(dataset = c("gaussian", "tweedie"), seed = 123) {
  load_interdep_debug_internals()

  data <- validate_interdep_data(
    load_debug_ild_data(dataset),
    group = coupleID,
    member = personID,
    role = gender,
    time = diaryday,
    predictors = provided_support
  )
  data <- infer_dyad_compositions(data, seed = seed)
  data <- center_predictors(data)

  meta_data <- attr(data, "interdep")
  out <- data
  group <- meta_data$group
  member <- meta_data$member
  has_time <- meta_data$longitudinal
  time <- meta_data$time
  predictors <- meta_data$predictors
  predictor_decompositions <- meta_data$predictor_decompositions

  assign_debug_vars(
    data = data,
    meta_data = meta_data,
    out = out,
    group = group,
    member = member,
    has_time = has_time,
    time = time,
    predictors = predictors,
    predictor_decompositions = predictor_decompositions
  )

  invisible(data)
}
