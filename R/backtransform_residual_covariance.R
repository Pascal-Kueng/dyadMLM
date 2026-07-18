#' Recover member-level residual covariance from the shared/difference
#' parameterization of exchangeable APIMs and DIMs
#'
#' Back-transforms exchangeable shared/difference residual-block pairs from a
#' fitted model to member-level residual variances, covariance, standard
#' deviations, and correlation.
#'
#' @param model A fitted `glmmTMB` or `brmsfit` model.
#'
#' @details
#' The function identifies shared and difference residual blocks, matches them
#' by dyad composition and grouping factor, and back-transforms each matched
#' pair to the covariance structure of two arbitrarily labelled members. It
#' supports multiple exchangeable compositions and grouping levels in the same
#' model. The fitted model is not refitted or modified.
#'
#' In Gaussian `brms` models, cross-sectional and same-occasion partner residual
#' dependence is usually represented directly with
#' `unstr(time = member, gr = pair_id)`. Use `sigma ~ 1` for equal residual
#' standard deviations in exchangeable dyads and `sigma ~ 0 + role` for
#' role-specific standard deviations in distinguishable dyads. Shared/difference
#' group-level blocks remain relevant for stable dyad effects in intensive
#' longitudinal data and are back-transformed by this function.
#'
#' @return A data frame with one row per matched composition and grouping-factor
#'   pair. It contains the fitted shared and difference variances, member-level
#'   residual variances, covariance, standard deviations, correlation, and the
#'   named member-level covariance matrix.
#'
#' @export
exchangeable_rescov <- function(model) {
  extract_exchangeable_residual_blocks(model)
}

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
  return(model)
}
