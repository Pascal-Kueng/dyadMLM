#' Example Gaussian cross-sectional dyadic data
#'
#' A simulated long-format dataset containing distinguishable female-male
#' dyads and exchangeable female-female and male-male dyads. Each dyad has two
#' members and each member has one row. `closeness` and `provided_support` are
#' the member's averages across the 14 observations in [dyads_ild].
#'
#' Prepare with `dyad = coupleID`, `member = personID`, and `role = gender`.
#' These data contain three compositions. Use `keep_compositions` in
#' [prepare_dyad_data()] when an analysis should retain only selected
#' compositions; omit it when all supplied compositions should remain.
#'
#' @format A data frame with 720 rows and 6 variables:
#' \describe{
#'   \item{personID}{Unique person identifier.}
#'   \item{coupleID}{Dyad identifier.}
#'   \item{gender}{Gender role, with levels `female` and `male`.}
#'   \item{dyad_composition}{Observed dyad composition, with levels
#'     `female_x_male`, `female_x_female`, and `male_x_male`.}
#'   \item{closeness}{Mean simulated Gaussian closeness score across 14 days.}
#'   \item{provided_support}{Mean simulated provided-support score across 14
#'     days.}
#' }
#' @source Simulated for `dyadMLM`; design adapted from
#'   \url{https://github.com/Pascal-Kueng/05DyadicDataAnalysis}. See Küng,
#'   P. M. (2026). \emph{Distinguishable and Exchangeable Dyads: Bayesian
#'   Multilevel Modelling} (v2.0.9). Zenodo.
#'   \doi{10.5281/zenodo.20720321}.
"dyads_cross"

#' Example Gaussian intensive longitudinal dyadic data
#'
#' A simulated long-format dataset containing distinguishable female-male
#' dyads and exchangeable female-female and male-male dyads. Each dyad has two
#' members observed on 14 diary days.
#'
#' Prepare with `dyad = coupleID`, `member = personID`, `role = gender`, and
#' `time = diaryday`. These data contain three compositions. Use
#' `keep_compositions` in [prepare_dyad_data()] when an analysis should retain
#' only selected compositions; omit it when all supplied compositions should
#' remain.
#'
#' @format A data frame with 10,080 rows and 7 variables:
#' \describe{
#'   \item{personID}{Unique person identifier.}
#'   \item{coupleID}{Dyad identifier.}
#'   \item{diaryday}{Measurement day, from 0 through 13.}
#'   \item{gender}{Gender role, with levels `female` and `male`.}
#'   \item{dyad_composition}{Observed dyad composition, with levels
#'     `female_x_male`, `female_x_female`, and `male_x_male`.}
#'   \item{closeness}{Simulated Gaussian closeness outcome.}
#'   \item{provided_support}{Simulated provided-support score.}
#' }
#' @source Simulated for `dyadMLM`; design adapted from
#'   \url{https://github.com/Pascal-Kueng/05DyadicDataAnalysis}. See Küng,
#'   P. M. (2026). \emph{Distinguishable and Exchangeable Dyads: Bayesian
#'   Multilevel Modelling} (v2.0.9). Zenodo.
#'   \doi{10.5281/zenodo.20720321}.
"dyads_ild"

#' Example negative-binomial cross-sectional dyadic data
#'
#' A simulated long-format dataset containing the same dyads, members, and
#' dyad compositions as [dyads_cross]. Each member has one row. `stress` is the
#' member's average across the 14 observations in [dyads_nbinom_ild]. The count
#' outcome is a separate negative-binomial draw using the NB2 variance function;
#' it is not an average or sum of the daily counts.
#'
#' Prepare with `dyad = coupleID`, `member = personID`, and `role = gender`.
#' These data contain three compositions. Use `keep_compositions` in
#' [prepare_dyad_data()] when an analysis should retain only selected
#' compositions; omit it when all supplied compositions should remain.
#'
#' @format A data frame with 720 rows and 6 variables:
#' \describe{
#'   \item{personID}{Unique person identifier.}
#'   \item{coupleID}{Dyad identifier.}
#'   \item{gender}{Gender role, with levels `female` and `male`.}
#'   \item{dyad_composition}{Observed dyad composition, with levels
#'     `female_x_male`, `female_x_female`, and `male_x_male`.}
#'   \item{conflict_count}{Simulated number of conflictual interactions reported
#'     by a member.}
#'   \item{stress}{Mean simulated stress score across 14 days.}
#' }
#' @source Simulated for `dyadMLM`; design adapted from
#'   \url{https://github.com/Pascal-Kueng/05DyadicDataAnalysis}. See Küng,
#'   P. M. (2026). \emph{Distinguishable and Exchangeable Dyads: Bayesian
#'   Multilevel Modelling} (v2.0.9). Zenodo.
#'   \doi{10.5281/zenodo.20720321}.
"dyads_nbinom_cross"

#' Example negative-binomial intensive longitudinal dyadic data
#'
#' A simulated long-format dataset containing the same dyads, members, diary
#' days, and dyad compositions as [dyads_ild]. The outcome is a count generated
#' from a negative-binomial distribution using the NB2 variance function.
#'
#' Prepare with `dyad = coupleID`, `member = personID`, `role = gender`, and
#' `time = diaryday`. These data contain three compositions. Use
#' `keep_compositions` in [prepare_dyad_data()] when an analysis should retain
#' only selected compositions; omit it when all supplied compositions should
#' remain.
#'
#' @format A data frame with 10,080 rows and 7 variables:
#' \describe{
#'   \item{personID}{Unique person identifier.}
#'   \item{coupleID}{Dyad identifier.}
#'   \item{diaryday}{Measurement day, from 0 through 13.}
#'   \item{gender}{Gender role, with levels `female` and `male`.}
#'   \item{dyad_composition}{Observed dyad composition, with levels
#'     `female_x_male`, `female_x_female`, and `male_x_male`.}
#'   \item{conflict_count}{Simulated number of conflictual interactions reported
#'     by a member on that day.}
#'   \item{stress}{Simulated stress score.}
#' }
#' @source Simulated for `dyadMLM`; design adapted from
#'   \url{https://github.com/Pascal-Kueng/05DyadicDataAnalysis}. See Küng,
#'   P. M. (2026). \emph{Distinguishable and Exchangeable Dyads: Bayesian
#'   Multilevel Modelling} (v2.0.9). Zenodo.
#'   \doi{10.5281/zenodo.20720321}.
"dyads_nbinom_ild"
