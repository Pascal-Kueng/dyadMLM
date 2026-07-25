# Package-level documentation. The title, authors, and links are taken from
# DESCRIPTION through roxygen2's "_PACKAGE" sentinel.

#' @description
#' `dyadMLM` validates and prepares cross-sectional and intensive longitudinal
#' dyadic data for multilevel modeling. It creates model-ready variables for
#' APIMs, DIMs, and DSMs and provides supporting post-estimation tools.
#'
#' @section Main functions:
#' - [prepare_dyad_data()] validates long-format dyadic data and creates
#'   model-ready variables.
#' - [compare_nested_glmmTMB_models()] compares compatible nested `glmmTMB`
#'   models fitted to equivalent data.
#' - [recover_exchangeable_covariance()] converts exchangeable
#'   shared/difference covariance structures to member-level quantities.
#'
#' @section Example data:
#' See [dyads_cross] and [dyads_ild] for Gaussian examples, and
#' [dyads_nbinom_cross] and [dyads_nbinom_ild] for negative-binomial examples.
#'
#' @section Getting started:
#' See `vignette("getting-started", package = "dyadMLM")` for an overview.
#' The APIM, DIM, and DSM vignettes provide model-specific examples.
#'
#' @keywords internal
"_PACKAGE"
