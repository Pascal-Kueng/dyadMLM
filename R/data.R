#' Example cross-sectional dyadic data
#'
#' A simulated cross-sectional long-format dataset for distinguishable dyads.
#' Each dyad contributes one row per member.
#'
#' Prepare with `group = coupleID`, `member = personID`, and `role = gender`.
#'
#' @format A data frame with 190 rows and 5 variables:
#' \describe{
#'   \item{personID}{Unique person identifier.}
#'   \item{coupleID}{Dyad identifier.}
#'   \item{gender}{Gender role, with levels `female` and `male`.}
#'   \item{communication}{Simulated communication score, with some missing values.}
#'   \item{satisfaction}{Simulated satisfaction outcome, with some missing values.}
#' }
#' @source Adapted from \url{https://github.com/Pascal-Kueng/05DyadicDataAnalysis}.
#'   See Küng, P. M. (2026). \emph{Distinguishable and Exchangeable Dyads:
#'   Bayesian Multilevel Modelling} (v2.0.9). Zenodo.
#'   \doi{10.5281/zenodo.20720321}.
"example_dyadic_crosssectional"

#' Example cross-sectional dyadic data with mixed dyad compositions
#'
#' A simulated cross-sectional long-format dataset containing distinguishable
#' female-male dyads and exchangeable female-female and male-male dyads. Each
#' dyad contributes one row per member.
#'
#' Prepare with `group = coupleID`, `member = personID`, and `role = gender`.
#'
#' @format A data frame with 640 rows and 4 variables:
#' \describe{
#'   \item{personID}{Unique person identifier.}
#'   \item{coupleID}{Dyad identifier.}
#'   \item{gender}{Gender role, with levels `female` and `male`.}
#'   \item{satisfaction}{Simulated Gaussian satisfaction outcome.}
#' }
#' @source Adapted from \url{https://github.com/Pascal-Kueng/05DyadicDataAnalysis}.
#'   See Küng, P. M. (2026). \emph{Distinguishable and Exchangeable Dyads:
#'   Bayesian Multilevel Modelling} (v2.0.9). Zenodo.
#'   \doi{10.5281/zenodo.20720321}.
"example_dyadic_crosssectional_unified"

#' Example cross-sectional dyadic data with a Tweedie outcome
#'
#' A simulated cross-sectional long-format dataset for distinguishable dyads with
#' a semi-continuous physical activity outcome. Each dyad contributes one row per
#' member.
#'
#' Prepare with `group = coupleID`, `member = personID`, and `role = gender`.
#'
#' @format A data frame with 240 rows and 5 variables:
#' \describe{
#'   \item{personID}{Unique person identifier.}
#'   \item{coupleID}{Dyad identifier.}
#'   \item{gender}{Gender role, with levels `female` and `male`.}
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
#' Prepare with `group = coupleID`, `member = personID`, `role = gender`, and
#' `time = diaryday`.
#'
#' @format A data frame with 1,120 rows and 6 variables:
#' \describe{
#'   \item{personID}{Unique person identifier.}
#'   \item{coupleID}{Dyad identifier.}
#'   \item{diaryday}{Measurement day.}
#'   \item{gender}{Gender role, with levels `female` and `male`.}
#'   \item{closeness}{Simulated closeness outcome, with some missing values.}
#'   \item{provided_support}{Simulated provided support score, with some missing values.}
#' }
#' @source Adapted from \url{https://github.com/Pascal-Kueng/05DyadicDataAnalysis}.
#'   See Küng, P. M. (2026). \emph{Distinguishable and Exchangeable Dyads:
#'   Bayesian Multilevel Modelling} (v2.0.9). Zenodo.
#'   \doi{10.5281/zenodo.20720321}.
"example_dyadic_ILD"

#' Example intensive longitudinal dyadic data with mixed dyad compositions
#'
#' A simulated intensive longitudinal long-format dataset containing
#' distinguishable female-male dyads and exchangeable female-female and
#' male-male dyads. Each dyad contributes one row per member and measurement
#' occasion.
#'
#' Prepare with `group = coupleID`, `member = personID`, `role = gender`, and
#' `time = diaryday`.
#'
#' @format A data frame with 2,800 rows and 6 variables:
#' \describe{
#'   \item{personID}{Unique person identifier.}
#'   \item{coupleID}{Dyad identifier.}
#'   \item{diaryday}{Measurement day.}
#'   \item{gender}{Gender role, with levels `female` and `male`.}
#'   \item{closeness}{Simulated Gaussian closeness outcome, with some missing values.}
#'   \item{provided_support}{Simulated provided support score, with some missing values.}
#' }
#' @source Adapted from \url{https://github.com/Pascal-Kueng/05DyadicDataAnalysis}.
#'   See Küng, P. M. (2026). \emph{Distinguishable and Exchangeable Dyads:
#'   Bayesian Multilevel Modelling} (v2.0.9). Zenodo.
#'   \doi{10.5281/zenodo.20720321}.
"example_dyadic_ILD_unified"

#' Example intensive longitudinal dyadic data with a Tweedie outcome
#'
#' A simulated intensive longitudinal long-format dataset for distinguishable
#' dyads with a semi-continuous physical activity outcome. Each dyad contributes
#' one row per member and measurement occasion.
#'
#' Prepare with `group = coupleID`, `member = personID`, `role = gender`, and
#' `time = diaryday`.
#'
#' @format A data frame with 1,120 rows and 6 variables:
#' \describe{
#'   \item{personID}{Unique person identifier.}
#'   \item{coupleID}{Dyad identifier.}
#'   \item{diaryday}{Measurement day.}
#'   \item{gender}{Gender role, with levels `female` and `male`.}
#'   \item{physical_activity}{Simulated Tweedie-like physical activity outcome, with some missing values.}
#'   \item{provided_support}{Simulated provided support score, with some missing values.}
#' }
#' @source Adapted from \url{https://github.com/Pascal-Kueng/05DyadicDataAnalysis}.
#'   See Küng, P. M. (2026). \emph{Distinguishable and Exchangeable Dyads:
#'   Bayesian Multilevel Modelling} (v2.0.9). Zenodo.
#'   \doi{10.5281/zenodo.20720321}.
"example_dyadic_ILD_tweedie"

#' Example intensive longitudinal dyadic data with mixed dyad compositions and a Tweedie outcome
#'
#' A simulated intensive longitudinal long-format dataset containing
#' distinguishable female-male dyads and exchangeable female-female and
#' male-male dyads with a semi-continuous physical activity outcome. Each dyad
#' contributes one row per member and measurement occasion.
#'
#' Prepare with `group = coupleID`, `member = personID`, `role = gender`, and
#' `time = diaryday`.
#'
#' @format A data frame with 2,800 rows and 6 variables:
#' \describe{
#'   \item{personID}{Unique person identifier.}
#'   \item{coupleID}{Dyad identifier.}
#'   \item{diaryday}{Measurement day.}
#'   \item{gender}{Gender role, with levels `female` and `male`.}
#'   \item{physical_activity}{Simulated Tweedie-like physical activity outcome, with some missing values.}
#'   \item{provided_support}{Simulated provided support score, with some missing values.}
#' }
#' @source Adapted from \url{https://github.com/Pascal-Kueng/05DyadicDataAnalysis}.
#'   See Küng, P. M. (2026). \emph{Distinguishable and Exchangeable Dyads:
#'   Bayesian Multilevel Modelling} (v2.0.9). Zenodo.
#'   \doi{10.5281/zenodo.20720321}.
"example_dyadic_ILD_unified_tweedie"
