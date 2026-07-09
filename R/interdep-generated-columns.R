#' Collect generated model columns
#'
#' Creates a normalized, one-row-per-column view over the model-specific
#' metadata tables stored in an `interdep` attribute. This is a derived lookup
#' table; the model-specific metadata tables remain the source records.
#'
#' @param meta The `interdep` metadata attribute from an `interdep_data` object.
#'
#' @return A tibble with one row per generated APIM, DIM, or undirected DSM
#'   model column.
#'
#' @keywords internal
interdep_generated_columns <- function(meta) {
  dplyr::bind_rows(
    apim_generated_columns(meta$apim_predictors),
    dim_generated_columns(meta$dim_predictors),
    undirected_dsm_generated_columns(meta$undirected_dsm_outcomes)
  )
}

# Used as an empty tibble that is identical for each model type and is returned,
# if that model type is not applicable/requested.
empty_generated_columns <- function() {
  tibble::tibble(
    model_family = character(),
    variable_role = character(),
    variable = character(),
    component = character(),
    column_role = character(),
    column = character(),
    source_column = character(),
    decomposition_level = character(),
    centering = character(),
    print_order = integer(),
    column_pattern = character(),
    description = character()
  )
}

apim_generated_columns <- function(apim_predictors) {
  if (is.null(apim_predictors) || nrow(apim_predictors) == 0) {
    return(empty_generated_columns())
  }

  columns <- dplyr::bind_rows(
    tibble::tibble(
      model_family = "apim",
      variable_role = "predictor",
      variable = apim_predictors$predictor,
      component = apim_predictors$component,
      column_role = "actor",
      column = apim_predictors$actor_column,
      source_column = apim_predictors$source_column,
      decomposition_level = "none"
    ),
    tibble::tibble(
      model_family = "apim",
      variable_role = "predictor",
      variable = apim_predictors$predictor,
      component = apim_predictors$component,
      column_role = "partner",
      column = apim_predictors$partner_column,
      source_column = apim_predictors$source_column,
      decomposition_level = "none"
    )
  )

  attach_generated_column_specs(columns)
}

dim_generated_columns <- function(dim_predictors) {
  if (is.null(dim_predictors) || nrow(dim_predictors) == 0) {
    return(empty_generated_columns())
  }

  columns <- dplyr::bind_rows(
    tibble::tibble(
      model_family = "dim",
      variable_role = "predictor",
      variable = dim_predictors$predictor,
      component = dim_predictors$component,
      column_role = "dyad_mean",
      column = dim_predictors$mean_column,
      source_column = dim_predictors$source_column,
      decomposition_level = dim_predictors$decomposition_level
    ),
    tibble::tibble(
      model_family = "dim",
      variable_role = "predictor",
      variable = dim_predictors$predictor,
      component = dim_predictors$component,
      column_role = "within_dyad_deviation",
      column = dim_predictors$deviation_column,
      source_column = dim_predictors$source_column,
      decomposition_level = dim_predictors$decomposition_level
    )
  )

  attach_generated_column_specs(columns)
}

undirected_dsm_generated_columns <- function(undirected_dsm_outcomes) {
  if (is.null(undirected_dsm_outcomes) || nrow(undirected_dsm_outcomes) == 0) {
    return(empty_generated_columns())
  }

  columns <- dplyr::bind_rows(
    tibble::tibble(
      model_family = "undirected_dsm",
      variable_role = "outcome",
      variable = undirected_dsm_outcomes$outcome,
      component = "raw",
      column_role = "dyad_mean",
      column = undirected_dsm_outcomes$mean_column,
      source_column = undirected_dsm_outcomes$source_column,
      decomposition_level = undirected_dsm_outcomes$decomposition_level
    ),
    tibble::tibble(
      model_family = "undirected_dsm",
      variable_role = "outcome",
      variable = undirected_dsm_outcomes$outcome,
      component = "raw",
      column_role = "within_dyad_deviation",
      column = undirected_dsm_outcomes$deviation_column,
      source_column = undirected_dsm_outcomes$source_column,
      decomposition_level = undirected_dsm_outcomes$decomposition_level
    )
  )

  attach_generated_column_specs(columns)
}

attach_generated_column_specs <- function(columns) {
  out <- columns |>
    dplyr::left_join(
      generated_column_spec_lookup(),
      by = c("model_family", "variable_role", "component", "column_role")
    )

  missing_spec <- is.na(out$print_order) | is.na(out$column_pattern) | is.na(out$description)
  if (any(missing_spec)) {
    missing_keys <- out[missing_spec, c("model_family", "variable_role", "component", "column_role")]
    stop(
      "Internal error: missing generated-column specification for: ",
      paste(
        apply(missing_keys, 1, paste, collapse = "/"),
        collapse = ", "
      ),
      call. = FALSE
    )
  }

  out
}

generated_column_spec_lookup <- function() {
  tibble::tribble(
    ~model_family,    ~variable_role,  ~component, ~column_role,             ~centering,                   ~print_order, ~column_pattern,                        ~description,
    "apim",            "predictor",    "raw",      "actor",                  "none",                       10L,          ".i_*_raw_actor",                       "APIM raw actor predictors",
    "apim",            "predictor",    "raw",      "partner",                "none",                       11L,          ".i_*_raw_partner",                     "APIM raw partner predictors",
    "apim",            "predictor",    "cwp",      "actor",                  "within_person",              12L,          ".i_*_cwp_actor",                       "APIM within-person actor predictors",
    "apim",            "predictor",    "cwp",      "partner",                "within_person",              13L,          ".i_*_cwp_partner",                     "APIM within-person partner predictors",
    "apim",            "predictor",    "cbp",      "actor",                  "between_person_grand_mean",  14L,          ".i_*_cbp_actor",                       "APIM between-person actor predictors",
    "apim",            "predictor",    "cbp",      "partner",                "between_person_grand_mean",  15L,          ".i_*_cbp_partner",                     "APIM between-person partner predictors",
    "dim",             "predictor",    "raw",      "dyad_mean",              "grand_mean_dyad_mean",       20L,          ".i_*_raw_dyad_mean_gmc",               "DIM raw predictor dyad means, grand-mean centred",
    "dim",             "predictor",    "raw",      "within_dyad_deviation",  "none",                       21L,          ".i_*_raw_within_dyad_deviation",       "DIM raw predictor within-dyad deviations",
    "dim",             "predictor",    "cwp",      "dyad_mean",              "within_person",              22L,          ".i_*_cwp_dyad_mean",                   "DIM shared momentary predictor deviations",
    "dim",             "predictor",    "cwp",      "within_dyad_deviation",  "within_person",              23L,          ".i_*_cwp_within_dyad_deviation",       "DIM person deviations from shared momentary predictor levels",
    "dim",             "predictor",    "cbp",      "dyad_mean",              "between_person_grand_mean",  24L,          ".i_*_cbp_dyad_mean",                   "DIM shared usual predictor levels",
    "dim",             "predictor",    "cbp",      "within_dyad_deviation",  "between_person_grand_mean",  25L,          ".i_*_cbp_within_dyad_deviation",       "DIM person differences from dyad usual predictor levels",
    "undirected_dsm",  "outcome",      "raw",      "dyad_mean",              "none",                       30L,          ".i_*_raw_dyad_mean",                   "DSM raw outcome dyad means",
    "undirected_dsm",  "outcome",      "raw",      "within_dyad_deviation",  "none",                       31L,          ".i_*_raw_within_dyad_deviation",       "DSM raw outcome within-dyad deviations"
  )
}

