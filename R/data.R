#' Example cross-sectional dyadic data
#'
#' A simulated cross-sectional long-format dataset for distinguishable dyads.
#' Each dyad contributes one row per member.
#'
#' @format A data frame with 190 rows and 5 variables:
#' \describe{
#'   \item{personID}{Unique person identifier.}
#'   \item{coupleID}{Dyad identifier.}
#'   \item{gender}{Gender code used in the simulation.}
#'   \item{communication}{Simulated communication score, with some missing values.}
#'   \item{satisfaction}{Simulated satisfaction outcome, with some missing values.}
#' }
#' @source Adapted from \url{https://github.com/Pascal-Kueng/05DyadicDataAnalysis}.
#'   See Küng, P. M. (2026). \emph{Distinguishable and Exchangeable Dyads:
#'   Bayesian Multilevel Modelling} (v2.0.9). Zenodo.
#'   \doi{10.5281/zenodo.20720321}.
"example_dyadic_crosssectional"

#' Example cross-sectional dyadic data with a Tweedie outcome
#'
#' A simulated cross-sectional long-format dataset for distinguishable dyads with
#' a semi-continuous physical activity outcome. Each dyad contributes one row per
#' member.
#'
#' @format A data frame with 240 rows and 5 variables:
#' \describe{
#'   \item{personID}{Unique person identifier.}
#'   \item{coupleID}{Dyad identifier.}
#'   \item{gender}{Gender code used in the simulation.}
#'   \item{motivation}{Simulated motivation predictor, with some missing values.}
#'   \item{physical_activity}{Simulated Tweedie-like physical activity outcome, with some missing values.}
#' }
#' @source Adapted from \url{https://github.com/Pascal-Kueng/05DyadicDataAnalysis}.
#'   See Küng, P. M. (2026). \emph{Distinguishable and Exchangeable Dyads:
#'   Bayesian Multilevel Modelling} (v2.0.9). Zenodo.
#'   \doi{10.5281/zenodo.20720321}.
"example_dyadic_crosssectional_tweedie"

#' Example intensive longitudinal dyadic data
#'
#' A simulated intensive longitudinal long-format dataset for distinguishable
#' dyads. Each dyad contributes one row per member and measurement occasion.
#'
#' @format A data frame with 1,120 rows and 6 variables:
#' \describe{
#'   \item{personID}{Unique person identifier.}
#'   \item{coupleID}{Dyad identifier.}
#'   \item{diaryday}{Measurement day.}
#'   \item{gender}{Gender code used in the simulation.}
#'   \item{closeness}{Simulated closeness outcome, with some missing values.}
#'   \item{provided_support}{Simulated provided support score, with some missing values.}
#' }
#' @source Adapted from \url{https://github.com/Pascal-Kueng/05DyadicDataAnalysis}.
#'   See Küng, P. M. (2026). \emph{Distinguishable and Exchangeable Dyads:
#'   Bayesian Multilevel Modelling} (v2.0.9). Zenodo.
#'   \doi{10.5281/zenodo.20720321}.
"example_dyadic_ILD"
