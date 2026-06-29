#' Example cross-sectional dyadic data
#'
#' A simulated cross-sectional dataset for distinguishable dyads.
#'
#' @format A data frame with 190 rows and 6 variables:
#' \describe{
#'   \item{userID}{Unique person identifier.}
#'   \item{coupleID}{Dyad identifier.}
#'   \item{member}{Member identifier within dyad.}
#'   \item{gender}{Gender code used in the simulation.}
#'   \item{communication}{Simulated communication score.}
#'   \item{satisfaction}{Simulated satisfaction outcome.}
#' }
#' @source Adapted from \url{https://github.com/Pascal-Kueng/05DyadicDataAnalysis}.
#'   See Küng, P. M. (2026). \emph{Distinguishable and Exchangeable Dyads:
#'   Bayesian Multilevel Modelling} (v2.0.9). Zenodo.
#'   \doi{10.5281/zenodo.20720321}.
"example_dyadic_crosssectional"

#' Example intensive longitudinal dyadic data
#'
#' A simulated intensive longitudinal dataset for distinguishable dyads.
#'
#' @format A data frame with 1,120 rows and 7 variables:
#' \describe{
#'   \item{userID}{Unique person identifier.}
#'   \item{coupleID}{Dyad identifier.}
#'   \item{diaryday}{Measurement day.}
#'   \item{gender}{Gender code used in the simulation.}
#'   \item{member}{Member identifier within dyad.}
#'   \item{closeness}{Simulated closeness outcome.}
#'   \item{provided_support}{Simulated provided support score.}
#' }
#' @source Adapted from \url{https://github.com/Pascal-Kueng/05DyadicDataAnalysis}.
#'   See Küng, P. M. (2026). \emph{Distinguishable and Exchangeable Dyads:
#'   Bayesian Multilevel Modelling} (v2.0.9). Zenodo.
#'   \doi{10.5281/zenodo.20720321}.
"example_dyadic_ILD"
