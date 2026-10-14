# Shared help page on reading the residual and outcome check plots.
#' Read residual and outcome check plots
#'
#' How to read the pages drawn by [check_dyad_residuals()] and
#' [check_dyad_outcomes()], and how to follow up flags. `plot()` redraws a check
#' saved with `plot = FALSE`.
#'
#' @param x A result from [check_dyad_residuals()] or [check_dyad_outcomes()].
#' @inheritParams check_dyad_residuals
#' @param ... Unused.
#' @return `x`, invisibly.
#'
#' @section Views and compositions:
#' Start with everyone pooled (`role = NULL`), then also inspect meaningful
#' roles, such as gender, even when the model treats partners as exchangeable:
#' role-specific problems show only there. Use `predictors` to examine other
#' measured characteristics. For separate QQ plots and summaries by a
#' person-level categorical characteristic, use that variable as `role`.
#'
#' Each composition gets one pooled column for same-role partners, or separate
#' columns for distinct roles. Supplying roles does not change the model's
#' assumptions. Observations whose composition or role is unknown, for example
#' because the partner's row is missing and `data` was not supplied, are omitted
#' with a warning.
#'
#' @section Residual check pages:
#' For each composition, the first page shows uniform QQ and mean PIT distance.
#' The second shows PIT quartiles against predicted outcomes. Each supplied
#' predictor gets another page like the second.
#'
#' PIT (probability integral transform) residuals rank each outcome from 0 (low)
#' to 1 (high) relative to its own simulated values. A suitable model should
#' produce ranks roughly evenly spread between 0 and 1, allowing for the
#' variation shown in blue. PIT distance is `2 * abs(PIT - 0.5)`. Blue envelopes
#' are global: they are built so that the whole red curve of a correct model
#' stays inside in a nominal 95% of datasets. This holds within each panel, not
#' across roles, predictors, or pages. Because the model was fitted to these
#' same data, departures often look smaller than they are, as in the settings
#' studied by Robins et al. (2000) and in our simulations.
#'
#' Predicted outcomes and numeric predictors with more than eight distinct values
#' are grouped into up to eight bins per role, with at least about 20
#' observations per bin; with four or more bins, quartiles are smoothed across
#' neighboring bins. These are full-model residuals, not partial effects; bins
#' and separate predictors can hide local patterns and interactions.
#'
#'
#' @section Outcome check pages:
#' The first row compares outcome distributions. Ordinal responses use bars for
#' all defined categories, with separate 95% ranges per category, so one red
#' point outside can occur by chance. Other outcomes show the proportion at or
#' below each value (ECDF) for the observations and up to 30 simulated datasets.
#'
#' The remaining rows compare the response SD (standard deviation of outcome
#' minus prediction), the largest absolute deviation from prediction, and, when
#' the composition has simulated zeros (or observed zeros, for count and Tweedie
#' families), the number of zeros. The SD includes random effects; it does not
#' isolate the model's residual variance or dispersion parameter. For complete
#' cross-sectional dyads with distinct roles, these SDs match the role SDs of
#' [check_partner_dependence()] with its default `response = "model-centred"`.
#' Ordinal summaries depend on the category scores `1, 2, ..., K`. Use a tall
#' plotting window to keep all rows readable.
#'
#' @section Reading flags:
#' A flag is a red curve or point outside its blue envelope or range, or a red
#' line outside its dashed limits. Each panel alone rarely flags a correct
#' model, but flags add up across panels, roles, and predictor pages, so look
#' for a consistent pattern, not any single flag. The
#' [simulation study](https://pascal-kueng.github.io/dyadMLM/articles/distribution-checks.html)
#' reports how often correct and mismatched models were flagged.
#'
#' With about 40 dyads, most mismatches studied were hard to detect; the absence
#' of flags does not show a good fit. Panels suggest possible problems, not their
#' cause. Neither a flag nor its absence shows whether estimates or standard
#' errors are wrong: fit the model the pattern suggests and compare the
#' estimates and standard errors you report. Mismatches showed mainly in these
#' panels of both checks:
#' - Poisson fitted to overdispersed counts: mean PIT distance, number of zeros, QQ.
#' - Extra zeros: QQ and PIT quartiles; the number of zeros less often.
#' - Omitted role means: QQ and PIT quartiles across predicted outcomes, by role.
#' - Different role SDs: response SD and mean PIT distance, by role.
#' - Spread rising with a predictor: largest absolute deviation, mean PIT distance, QQ.
#' - Omitted partner effect: PIT quartiles across the partner's predictor
#'   (supply it in `predictors` of [check_dyad_residuals()]).
#'
#' @references
#' Robins, J. M., van der Vaart, A., & Ventura, V. (2000). Asymptotic
#' distribution of P values in composite null models. *Journal of the American
#' Statistical Association, 95*(452), 1143--1156.
#' \doi{10.1080/01621459.2000.10474310}
#'
#' @seealso [check_dyad_residuals()], [check_dyad_outcomes()]
#' @name dyad_check_plots
#' @keywords internal
NULL
