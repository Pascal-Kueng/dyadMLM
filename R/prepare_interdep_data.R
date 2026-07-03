#' Prepare dyadic data for interdep
#'
#' Validates dyadic data, records the structural variables, and adds metadata
#' used by downstream interdep functions.
#'
#' Data must be in long format. Cross-sectional dyadic data may contain at most
#' one row per member within dyad. Intensive longitudinal dyadic data may
#' contain at most one row per member and observed measurement occasion within
#' dyad. Measured variables may contain missing values. Missing or incomplete
#' structural information is controlled by `incomplete_dyads` and
#' `missing_role`.
#'
#' @param data A data frame or tibble. Data must be in long format. For
#' cross-sectional dyadic data, each observed member of each dyad has one row.
#' For intensive longitudinal dyadic data, each observed member of each dyad has
#' one row per observed time point.
#' @param group Column identifying the dyad.
#' @param member Column identifying a person or the member within dyad.
#' @param role Optional column identifying a stable member role, such as gender.
#'   Values must be stable within each `group` x `member` and must not contain
#'   `__`. Missing role information is controlled by `missing_role`. If no role
#'   is supplied, all dyads are treated as the same type of exchangeable dyads.
#' @param time Optional column identifying time or measurement order of repeated
#' measures.
#' @param incomplete_dyads How to handle dyads that do not contain exactly two
#'   unique members anywhere in the data. `"error"` stops with an error,
#'   `"drop"` removes the entire dyad, and `"keep"` retains the observed rows.
#'   Keeping incomplete dyads can produce unknown role compositions, such as
#'   `"female__unknown"`, when a `role` column is supplied.
#' @param missing_role How to handle missing values in the `role` column.
#'   `"error"` stops with an error, `"drop"` removes dyads with incomplete role
#'   information, and `"keep"` retains them. Keeping missing roles can produce
#'   unknown role compositions, such as `"female__unknown"`. Ignored when no
#'   `role` column is supplied.
#'
#' @return The original data as a tibble with class `interdep_data`,
#'   `.i_composition` and `.i_composition_role` factor columns,
#'   `.i_is_*` numeric indicator columns, and an `interdep` attribute
#'   containing structural metadata and `dyad_compositions`.
#'
#' @examples
#' data <- data.frame(
#'   dyad_id = c(1, 1, 2, 2),
#'   person_id = c(1, 2, 3, 4),
#'   role = c("female", "male", "female", "male")
#' )
#'
#' prepared <- prepare_interdep_data(
#'   data,
#'   group = dyad_id,
#'   member = person_id,
#'   role = role
#' )
#'
#' attr(prepared, "interdep")$dyad_compositions
#'
#' print(prepared)
#' @export
prepare_interdep_data <- function(
    data,
    group,
    member,
    role = NULL,
    time = NULL,
    incomplete_dyads = c("error", "drop", "keep"),
    missing_role = c("error", "drop", "keep")
  ) {

  incomplete_dyads <- rlang::arg_match(incomplete_dyads)
  missing_role <- rlang::arg_match(missing_role)

  # Validating and returning tibble with attributes
  out <- validate_interdep_data(
    data = data,
    group = {{ group }},
    member = {{ member }},
    role = {{ role }},
    time = {{ time }},
    incomplete_dyads = incomplete_dyads,
    missing_role = missing_role
  )

  # Inferring dyad compositions
  out <- infer_dyad_compositions(out)

  out
}
