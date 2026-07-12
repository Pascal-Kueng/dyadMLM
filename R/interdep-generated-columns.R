#' Collect interdep-generated columns
#'
#' Creates a normalized, one-row-per-column view over temporal predictor, APIM,
#' DIM, and undirected DSM columns stored in an `interdep` attribute. This is a
#' derived lookup table; the model-specific metadata tables remain the source
#' records.
#'
#' @param meta The `interdep` metadata attribute from an `interdep_data` object.
#'
#' @return A tibble with one row per generated temporal predictor, APIM, DIM,
#'   or undirected DSM column.
#'
#' @keywords internal
interdep_generated_columns <- function(meta) {
  dplyr::bind_rows(
    temporal_predictor_generated_columns(meta$temporal_predictor_decompositions),
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
    temporal_decomposition = character(),
    dyadic_decomposition = character(),
    column_centering = character(),
    print_order = integer(),
    column_pattern = character(),
    description = character()
  )
}

temporal_predictor_generated_columns <- function(temporal_predictor_decompositions) {
  if (is.null(temporal_predictor_decompositions) ||
      nrow(temporal_predictor_decompositions) == 0) {
    return(empty_generated_columns())
  }

  temporal_predictor_decompositions <- temporal_predictor_decompositions[
    temporal_predictor_decompositions$component %in% c("cwp", "cbp"),
    ,
    drop = FALSE
  ]

  if (nrow(temporal_predictor_decompositions) == 0) {
    return(empty_generated_columns())
  }

  columns <- tibble::tibble(
    model_family = "temporal",
    variable_role = "predictor",
    variable = temporal_predictor_decompositions$predictor,
    component = temporal_predictor_decompositions$component,
    column_role = "temporal_component",
    column = temporal_predictor_decompositions$column,
    source_column = temporal_predictor_decompositions$predictor
  )

  attach_generated_column_specs(columns)
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
      source_column = apim_predictors$source_column
    ),
    tibble::tibble(
      model_family = "apim",
      variable_role = "predictor",
      variable = apim_predictors$predictor,
      component = apim_predictors$component,
      column_role = "partner",
      column = apim_predictors$partner_column,
      source_column = apim_predictors$source_column
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
      source_column = dim_predictors$source_column
    ),
    tibble::tibble(
      model_family = "dim",
      variable_role = "predictor",
      variable = dim_predictors$predictor,
      component = dim_predictors$component,
      column_role = "within_dyad_deviation",
      column = dim_predictors$deviation_column,
      source_column = dim_predictors$source_column
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
      source_column = undirected_dsm_outcomes$source_column
    ),
    tibble::tibble(
      model_family = "undirected_dsm",
      variable_role = "outcome",
      variable = undirected_dsm_outcomes$outcome,
      component = "raw",
      column_role = "within_dyad_deviation",
      column = undirected_dsm_outcomes$deviation_column,
      source_column = undirected_dsm_outcomes$source_column
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

  spec_cols <- c(
    "temporal_decomposition",
    "dyadic_decomposition",
    "column_centering",
    "print_order",
    "column_pattern",
    "description"
  )
  missing_spec <- !stats::complete.cases(out[spec_cols])
  if (any(missing_spec)) {
    missing_keys <- out[missing_spec, c("model_family", "variable_role", "component", "column_role")]
    stop(
      "Internal error: no generated-column specification exists for metadata key(s) ",
      "`model_family`/`variable_role`/`component`/`column_role`: ",
      paste(
        apply(missing_keys, 1, paste, collapse = "/"),
        collapse = ", "
      ),
      ". Add the missing key(s) to `generated_column_spec_lookup()`.",
      call. = FALSE
    )
  }

  out
}

generated_column_spec_lookup <- function() {
  tibble::tribble(
    ~model_family,    ~variable_role, ~component, ~column_role,              ~temporal_decomposition,      ~dyadic_decomposition,      ~column_centering, ~print_order, ~column_pattern,                         ~description,
    "temporal",       "predictor",    "cwp",      "temporal_component",      "within_person",              "none",                     "none",            8L,           ".i_{pred}_cwp",                             "within-person predictor: momentary deviations from each person's usual level",
    "temporal",       "predictor",    "cbp",      "temporal_component",      "between_person_grand_mean",  "none",                     "none",            9L,           ".i_{pred}_cbp",                             "between-person predictor: stable differences from the average person's usual level",
    "apim",           "predictor",    "raw",      "actor",                  "none",                       "none",                     "none",            10L,          ".i_{pred}_actor",                       "APIM actor predictor: actor's original predictor values",
    "apim",           "predictor",    "raw",      "partner",                "none",                       "none",                     "none",            11L,          ".i_{pred}_partner",                     "APIM partner predictor: partner's original predictor values",
    "apim",           "predictor",    "cwp",      "actor",                  "within_person",              "none",                     "none",            12L,          ".i_{pred}_cwp_actor",                       "APIM within-person actor predictor: actor's momentary deviations from their usual level",
    "apim",           "predictor",    "cwp",      "partner",                "within_person",              "none",                     "none",            13L,          ".i_{pred}_cwp_partner",                     "APIM within-person partner predictor: partner's momentary deviations from their usual level",
    "apim",           "predictor",    "cbp",      "actor",                  "between_person_grand_mean",  "none",                     "none",            14L,          ".i_{pred}_cbp_actor",                       "APIM between-person actor predictor: actor's stable difference from the average person's usual level",
    "apim",           "predictor",    "cbp",      "partner",                "between_person_grand_mean",  "none",                     "none",            15L,          ".i_{pred}_cbp_partner",                     "APIM between-person partner predictor: partner's stable difference from the average person's usual level",
    "dim",            "predictor",    "raw",      "dyad_mean",              "none",                       "dyad_mean",                "grand_mean",      20L,          ".i_{pred}_dyad_mean_gmc",               "DIM dyad-mean predictor: dyad's average predictor level, grand-mean centered",
    "dim",            "predictor",    "raw",      "within_dyad_deviation",  "none",                       "within_dyad_deviation",    "none",            21L,          ".i_{pred}_within_dyad_deviation",       "DIM within-dyad predictor deviation: person's difference from the dyad average",
    "dim",            "predictor",    "cwp",      "dyad_mean",              "within_person",              "dyad_mean",                "none",            22L,          ".i_{pred}_cwp_dyad_mean",                   "DIM within-person dyad-mean predictor: shared momentary deviations in the dyad",
    "dim",            "predictor",    "cwp",      "within_dyad_deviation",  "within_person",              "within_dyad_deviation",    "none",            23L,          ".i_{pred}_cwp_within_dyad_deviation",       "DIM within-person within-dyad predictor deviation: person's momentary deviation from the dyad average",
    "dim",            "predictor",    "cbp",      "dyad_mean",              "between_person_grand_mean",  "dyad_mean",                "none",            24L,          ".i_{pred}_cbp_dyad_mean",                   "DIM between-person dyad-mean predictor: dyad's stable usual level, grand-mean centered",
    "dim",            "predictor",    "cbp",      "within_dyad_deviation",  "between_person_grand_mean",  "within_dyad_deviation",    "none",            25L,          ".i_{pred}_cbp_within_dyad_deviation",       "DIM between-person within-dyad predictor deviation: person's stable difference from the dyad's usual level",
    "undirected_dsm", "outcome",      "raw",      "dyad_mean",              "none",                       "dyad_mean",                "none",            30L,          ".i_{out}_dyad_mean",                   "DSM dyad-mean outcome: dyad's average outcome level",
    "undirected_dsm", "outcome",      "raw",      "within_dyad_deviation",  "none",                       "within_dyad_deviation",    "none",            31L,          ".i_{out}_within_dyad_deviation",       "DSM within-dyad outcome deviation: person's difference from the dyad average"
  )
}
