#' Prepare dyadic data for interdep
#'
#' Validates dyadic data, records the structural variables, and adds metadata
#' used by downstream interdep functions.
#'
#' Data must be in long format. Cross-sectional dyadic data must contain exactly
#' one row per member within dyad. Intensive longitudinal dyadic data must
#' contain at most one row per member and observed measurement occasion within
#' dyad. Measured variables may contain missing values, but structural variables
#' used for `group`, `member`, `role`, and `time` may not.
#'
#' @param data A data frame or tibble. Data must be in long format. For
#' cross-sectional dyadic data, each member of each dyad has one row. For
#' intensive longitudinal dyadic data, each member of each dyad has one row per
#' observed time point.
#' @param group Column identifying the dyad.
#' @param member Column identifying a person or the member within dyad.
#' @param role Optional column identifying a stable member role, such as gender.
#'   Values must be complete, stable within each `group` x `member`, and must
#'   not contain `__`. If no role is supplied, all dyads are treated as the same
#'   type of exchangeable dyads.
#' @param time Optional column identifying time or measurement order of repeated
#' measures.
#'
#' @return The original data as a tibble with class `interdep_data`, reserved
#'   `.interdep_*` composition columns, and an `interdep` attribute containing
#'   structural metadata and `dyad_compositions`.
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
#' @export
prepare_interdep_data <- function(data, group, member, role = NULL, time = NULL) {

  # Validating and returning tibble with attributes
  out <- validate_interdep_data(
    data = data,
    group = {{ group }},
    member = {{ member }},
    role = {{ role }},
    time = {{ time }}
  )

  # Inferring dyad compositions
  out <- infer_dyad_compositions(out)

  out
}
