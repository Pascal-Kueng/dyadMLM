#' Prepare dyadic data for interdep
#'
#' Validates dyadic data, records the structural variables, and adds metadata
#' used by downstream interdep functions.
#'
#'
#' @param data A data frame or tibble. Data must be in long format. For
#' cross-sectional dyadic data, each member of each dyad has one row. For
#' intensive longitudinal dyadic data, each member of each dyad has one row per
#' observed time point.
#' @param group Column identifying the dyad.
#' @param member Column identifying a person or the member within dyad.
#' @param role Optional column identifying a stable member role, such as gender.
#'   If no role is supplied, all dyads are treated as the same type of
#'   exchangeable dyads.
#' @param time Optional column identifying time or measurement order of repeated
#' measures.
#'
#' @return A tibble with class `interdep_data` and metadata about the dyads.
#' @export
prepare_interdep_data <- function(data, group, member, role = NULL, time = NULL) {
  out <- validate_interdep_data(
    data = data,
    group = {{ group }},
    member = {{ member }},
    role = {{ role }},
    time = {{ time }}
  )

  # Infering stuff here...

  attr(out, "interdep")$dyad_composition <- infer_dyad_composition(out)

  out
}
