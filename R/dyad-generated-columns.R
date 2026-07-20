#' Collect dyadMLM-generated columns
#'
#' Creates a normalized, one-row-per-column view over temporal predictor, APIM,
#' DIM, and DSM columns stored in a `dyadMLM` attribute. This is a
#' derived lookup table; the model-specific metadata tables remain the source
#' records.
#'
#' @param meta The `dyadMLM` metadata attribute from a `dyadMLM_data` object.
#'
#' @return A tibble with one row per generated temporal predictor, APIM, DIM,
#'   or DSM column. The `lag` column is `0` for contemporaneous columns and `1`
#'   for lag-1 columns.
#'
#' @keywords internal
dyad_generated_columns <- function(meta) {
  dplyr::bind_rows(
    temporal_predictor_generated_columns(meta$temporal_predictor_decompositions),
    apim_generated_columns(meta$apim_predictors),
    dim_generated_columns(meta$dim_predictors),
    dsm_generated_columns(
      dsm_predictors = meta$dsm_predictors,
      role_contrast_column = meta$dsm_role_contrast_column,
      role_column = meta$role
    )
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
    lag = integer(),
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
    temporal_predictor_decompositions$component %in% c("cwp", "cbp") |
      temporal_predictor_decompositions$lag > 0L,
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
    lag = temporal_predictor_decompositions$lag,
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
      lag = apim_predictors$lag,
      column_role = "actor",
      column = apim_predictors$actor_column,
      source_column = apim_predictors$source_column
    ),
    tibble::tibble(
      model_family = "apim",
      variable_role = "predictor",
      variable = apim_predictors$predictor,
      component = apim_predictors$component,
      lag = apim_predictors$lag,
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
      lag = dim_predictors$lag,
      column_role = "dyad_mean",
      column = dim_predictors$mean_column,
      source_column = dim_predictors$source_column
    ),
    tibble::tibble(
      model_family = "dim",
      variable_role = "predictor",
      variable = dim_predictors$predictor,
      component = dim_predictors$component,
      lag = dim_predictors$lag,
      column_role = "within_dyad_deviation",
      column = dim_predictors$deviation_column,
      source_column = dim_predictors$source_column
    )
  )

  attach_generated_column_specs(columns)
}

dsm_generated_columns <- function(dsm_predictors, role_contrast_column, role_column) {
  columns <- list()

  if (!is.null(role_contrast_column)) {
    columns$role_contrast <- tibble::tibble(
      model_family = "dsm",
      variable_role = "role",
      variable = role_column,
      component = "raw",
      lag = 0L,
      column_role = "role_contrast",
      column = role_contrast_column,
      source_column = role_column
    )
  }

  if (!is.null(dsm_predictors) && nrow(dsm_predictors) > 0) {
    predictor_columns <- dplyr::bind_rows(
      tibble::tibble(
        model_family = "dsm",
        variable_role = "predictor",
        variable = dsm_predictors$predictor,
        component = dsm_predictors$component,
        lag = dsm_predictors$lag,
        column_role = "dyad_mean",
        column = dsm_predictors$mean_column,
        source_column = dsm_predictors$source_column
      ),
      tibble::tibble(
        model_family = "dsm",
        variable_role = "predictor",
        variable = dsm_predictors$predictor,
        component = dsm_predictors$component,
        lag = dsm_predictors$lag,
        column_role = "dyad_difference",
        column = dsm_predictors$difference_column,
        source_column = dsm_predictors$source_column
      )
    )

    columns$predictors <- predictor_columns
  }

  columns <- dplyr::bind_rows(columns)

  if (nrow(columns) == 0) {
    return(empty_generated_columns())
  }

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
      ". Please report this as a dyadMLM bug with a reproducible example and your package version.",
      call. = FALSE
    )
  }

  is_lagged <- out$lag > 0L
  out$column_pattern[is_lagged] <- paste0(
    out$column_pattern[is_lagged],
    "_lag",
    out$lag[is_lagged]
  )
  out$description[is_lagged] <- paste0(
    "lag-",
    out$lag[is_lagged],
    " ",
    out$description[is_lagged]
  )

  out
}

generated_column_spec_lookup <- function() {
  tibble::tribble(
    ~model_family,    ~variable_role, ~component, ~column_role,              ~temporal_decomposition,      ~dyadic_decomposition,      ~column_centering, ~print_order, ~column_pattern,                         ~description,
    "temporal",       "predictor",    "raw",      "temporal_component",      "none",                       "none",                     "none",            7L,           ".dy_{pred}",                                 "raw predictor values",
    "temporal",       "predictor",    "cwp",      "temporal_component",      "within_person",              "none",                     "none",            8L,           ".dy_{pred}_cwp",                             "within-person predictor: momentary deviations from each person's usual level",
    "temporal",       "predictor",    "cbp",      "temporal_component",      "between_person_grand_mean",  "none",                     "none",            9L,           ".dy_{pred}_cbp",                             "between-person predictor: stable differences from the average person's usual level",
    "apim",           "predictor",    "raw",      "actor",                  "none",                       "none",                     "none",            10L,          ".dy_{pred}_actor",                       "APIM actor predictor: actor's original predictor values",
    "apim",           "predictor",    "raw",      "partner",                "none",                       "none",                     "none",            11L,          ".dy_{pred}_partner",                     "APIM partner predictor: partner's original predictor values",
    "apim",           "predictor",    "cwp",      "actor",                  "within_person",              "none",                     "none",            12L,          ".dy_{pred}_cwp_actor",                       "APIM within-person actor predictor: actor's momentary deviations from their usual level",
    "apim",           "predictor",    "cwp",      "partner",                "within_person",              "none",                     "none",            13L,          ".dy_{pred}_cwp_partner",                     "APIM within-person partner predictor: partner's momentary deviations from their usual level",
    "apim",           "predictor",    "cbp",      "actor",                  "between_person_grand_mean",  "none",                     "none",            14L,          ".dy_{pred}_cbp_actor",                       "APIM between-person actor predictor: actor's stable difference from the average person's usual level",
    "apim",           "predictor",    "cbp",      "partner",                "between_person_grand_mean",  "none",                     "none",            15L,          ".dy_{pred}_cbp_partner",                     "APIM between-person partner predictor: partner's stable difference from the average person's usual level",
    "dsm",            "role",         "raw",      "role_contrast",          "none",                       "role_contrast",            "none",            19L,          ".dy_dsm_role_contrast",                   "DSM role contrast: +0.5 for the first declared role and -0.5 for the second declared role",
    "dim",            "predictor",    "raw",      "dyad_mean",              "none",                       "dyad_mean",                "grand_mean",      20L,          ".dy_{pred}_dyad_mean_gmc",               "dyad-mean predictor: dyad's average predictor level, grand-mean centered",
    "dim",            "predictor",    "raw",      "within_dyad_deviation",  "none",                       "within_dyad_deviation",    "none",            21L,          ".dy_{pred}_within_dyad_dev",             "DIM within-dyad member-deviation predictor: member's difference from the dyad mean",
    "dim",            "predictor",    "cwp",      "dyad_mean",              "within_person",              "dyad_mean",                "none",            22L,          ".dy_{pred}_cwp_dyad_mean",                   "within-person dyad-mean predictor: shared momentary deviations in the dyad",
    "dim",            "predictor",    "cwp",      "within_dyad_deviation",  "within_person",              "within_dyad_deviation",    "none",            23L,          ".dy_{pred}_cwp_within_dyad_dev",         "DIM within-person, within-dyad member-deviation predictor: member's momentary deviation from the dyad mean",
    "dim",            "predictor",    "cbp",      "dyad_mean",              "between_person_grand_mean",  "dyad_mean",                "none",            24L,          ".dy_{pred}_cbp_dyad_mean",                   "between-person dyad-mean predictor: dyad's stable usual level, grand-mean centered",
    "dim",            "predictor",    "cbp",      "within_dyad_deviation",  "between_person_grand_mean",  "within_dyad_deviation",    "none",            25L,          ".dy_{pred}_cbp_within_dyad_dev",         "DIM between-person, within-dyad member-deviation predictor: member's stable difference from the dyad's usual level",
    "dsm",            "predictor",    "raw",      "dyad_mean",              "none",                       "dyad_mean",                "grand_mean",      20L,          ".dy_{pred}_dyad_mean_gmc",                   "dyad-mean predictor: dyad's average predictor level, grand-mean centered",
    "dsm",            "predictor",    "raw",      "dyad_difference",        "none",                       "dyad_difference",          "none",            21L,          ".dy_{pred}_within_dyad_diff",            "DSM signed predictor difference: first declared role minus second declared role",
    "dsm",            "predictor",    "cwp",      "dyad_mean",              "within_person",              "dyad_mean",                "none",            22L,          ".dy_{pred}_cwp_dyad_mean",                   "within-person dyad-mean predictor: shared momentary deviations in the dyad",
    "dsm",            "predictor",    "cwp",      "dyad_difference",        "within_person",              "dyad_difference",          "none",            23L,          ".dy_{pred}_cwp_within_dyad_diff",        "DSM within-person signed predictor difference: first declared role minus second declared role",
    "dsm",            "predictor",    "cbp",      "dyad_mean",              "between_person_grand_mean",  "dyad_mean",                "none",            24L,          ".dy_{pred}_cbp_dyad_mean",                   "between-person dyad-mean predictor: dyad's stable usual level, grand-mean centered",
    "dsm",            "predictor",    "cbp",      "dyad_difference",        "between_person_grand_mean",  "dyad_difference",          "none",            25L,          ".dy_{pred}_cbp_within_dyad_diff",        "DSM between-person signed predictor difference: first declared role minus second declared role"
  )
}
