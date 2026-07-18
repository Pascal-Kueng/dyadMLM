#' Extract exchangeable residual blocks from a fitted model
#'
#' Extracts the fitted random-effect structure and covariance parameters needed
#' to identify exchangeable shared/difference residual-block pairs. Model-engine
#' specific information is normalized to a common representation.
#'
#' @param model A fitted model. Supported classes are `glmmTMB` and `brmsfit`.
#'
#' @details
#' Shared and `.i_diff_*` blocks are matched by dyad composition and grouping
#' factor. This permits more than one exchangeable composition and more than one
#' grouping level, such as separate stable dyad and same-occasion residual
#' structures.
#'
#' For `glmmTMB` models, the function uses the normalized random-effect
#' structures stored in `model$modelInfo` together with the fitted covariance
#' estimates. For `brmsfit` models, it uses the stored group-level term
#' structure and raw posterior covariance draws.
#'
#' @return A normalized internal representation containing the model engine,
#'   extracted random-effect blocks, matched shared/difference block pairs, and
#'   their fitted covariance parameters.
#'
#' @keywords internal
extract_exchangeable_residual_blocks <- function(model) {

  # Note that in brms, we only need to worry about random effects for ILD. For
  # cross sectional fits, no back-transformation is needed, as residual variance-
  # covariance is not handled through re blocks. If users try to force residuals
  # into random effects block (detectable by seing that they are on the obser-
  # vation level), then we should warn that in brms, usually, they should use
  # unstr(time = member, group = dyad) with sigma = ~ 1 for exchangeable dyads
  # and sigma ~ 0 + role for exchangeable dyads.



  return(model)
}
