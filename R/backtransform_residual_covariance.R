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
#' @return A named list with one element per matched shared/difference block
#'   pair. Each element contains the member-level variance-covariance matrix in
#'   `varcov` and its standard-deviation/correlation representation in `sdcor`.
#'   Element names reproduce the two matched random-effect terms.
#'
#' @export
exchangeable_rescov <- function(model) {
  model_data <- extract_exchangeable_residual_blocks(model)

  # warn if brms used a residual-level re-term and advise to use as described in the details above.

  # match shared/difference blocks

  # backtransform each block

  # return

  return(model_data)
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
#' structure and raw posterior covariance draws. Distributional and nonlinear
#' `brms` random-effect terms are ignored.
#'
#' @return A normalized internal representation containing the model engine,
#'   extracted random-effect blocks, matched shared/difference block pairs, and
#'   their fitted covariance parameters.
#'
#' @keywords internal
extract_exchangeable_residual_blocks <- function(model) {
  if (inherits(model, "glmmTMB")) {
    return(glmmTMB_extract_exchangeable_residual_blocks(model))
  }

  if (inherits(model, "brmsfit")) {
    return(brms_extract_exchangeable_residual_blocks(model))
  }

  stop(
    "`model` must be a fitted `glmmTMB` or `brmsfit` model.",
    call. = FALSE
  )
}

glmmTMB_extract_exchangeable_residual_blocks <- function(model) {
  if (!requireNamespace("glmmTMB", quietly = TRUE)) {
    stop(
      "Package `glmmTMB` must be installed to extract covariance parameters from a `glmmTMB` model.",
      call. = FALSE
    )
  }

  # These objects describe the same ordered set of conditional random-effect
  # blocks: coefficient names, covariance structures, and fitted covariances.
  re_terms <- model$modelInfo$reTrms$cond
  re_structure <- model$modelInfo$reStruc$condReStruc
  covariance <- glmmTMB::VarCorr(model)$cond
  n_blocks <- length(re_structure)

  # `flist` contains unique grouping factors; `assign` maps each block back to
  # its grouping factor when several blocks use the same factor.
  group_assign <- attr(re_terms$flist, "assign")

  # Misaligned blocks could produce plausible but incorrect transformations,
  # so fail rather than relying on positional recycling.
  if (
    length(re_terms$cnms) != n_blocks ||
      length(group_assign) != n_blocks ||
      length(covariance) != n_blocks
  ) {
    stop(
      "Internal error: the stored `glmmTMB` random-effect structures could not be aligned.",
      call. = FALSE
    )
  }

  groups <- names(re_terms$flist)[group_assign]
  blocks <- lapply(seq_len(n_blocks), function(i) {
    coefficients <- unname(re_terms$cnms[[i]])

    # `blockCode`, unlike `fullCor`, reliably distinguishes `|` from `||` in
    # the normalized glmmTMB structure.
    structure <- names(re_structure[[i]]$blockCode)
    correlated <- !structure %in% c("diag", "homdiag")

    # Reconstruct a recognizable term label from glmmTMB's normalized names.
    formula_terms <- coefficients
    formula_terms[formula_terms == "(Intercept)"] <- "1"
    if (!"(Intercept)" %in% coefficients) {
      formula_terms <- c("0", formula_terms)
    }
    bar <- if (correlated) "|" else "||"

    # glmmTMB supplies one fitted covariance matrix. Add a leading dimension so
    # downstream code can treat it like the posterior-draw arrays from brms.
    covariance_matrix <- covariance[[i]]
    covariance_array <- array(
      covariance_matrix,
      dim = c(1L, length(coefficients), length(coefficients)),
      dimnames = list(NULL, coefficients, coefficients)
    )

    list(
      group = groups[[i]],
      coefficients = coefficients,
      correlated = correlated,
      term = paste0(
        "(", paste(formula_terms, collapse = " + "),
        " ", bar, " ", groups[[i]], ")"
      ),
      covariance = covariance_array
    )
  })

  list(
    backend = "glmmTMB",
    blocks = blocks
  )
}

brms_extract_exchangeable_residual_blocks <- function(model) {
  if (!requireNamespace("brms", quietly = TRUE)) {
    stop(
      "Package `brms` must be installed to extract covariance parameters from a `brmsfit` model.",
      call. = FALSE
    )
  }

  # Response identity is not yet part of the common block representation.
  if (inherits(model$formula, "mvbrmsformula")) {
    stop(
      "Multivariate `brms` models are currently not supported; `model` must contain a single response.",
      call. = FALSE
    )
  }

  # This function back-transforms ordinary response-mean blocks. Random effects
  # for distributional or nonlinear parameters have different interpretations
  # and are therefore left out rather than making the whole model unsupported.
  re_terms <- model$ranef
  re_terms <- re_terms[!nzchar(re_terms$dpar) & !nzchar(re_terms$nlpar), ]

  # A brms ID identifies one covariance block. Explicit `|ID|` syntax can link
  # several formula terms into one block, which the first implementation does
  # not yet normalize safely.
  block_ids <- unique(re_terms$id)
  block_rows <- lapply(block_ids, function(id) which(re_terms$id == id))
  block_formulas <- lapply(block_rows, function(rows) {
    unique(vapply(re_terms$form[rows], deparse1, character(1)))
  })
  if (any(lengths(block_formulas) != 1L)) {
    stop(
      "Random-effect blocks containing more than one formula term are currently not supported.",
      call. = FALSE
    )
  }

  # Keep every posterior draw; transformation and summarization happen later.
  covariance <- brms::VarCorr(model, summary = FALSE)

  blocks <- Map(function(rows, formulas) {
    # Values within one validated block share their group and correlation flag.
    group <- re_terms$group[rows[[1L]]]
    correlated <- re_terms$cor[rows[[1L]]]
    coefficients <- unname(re_terms$coef[rows])
    coefficients[coefficients == "Intercept"] <- "(Intercept)"
    formula_rhs <- trimws(sub("^~", "", formulas))
    bar <- if (isTRUE(correlated)) "|" else "||"

    # VarCorr combines all coefficients using the same grouping factor. Match
    # by coefficient name so separate blocks are not confused by their order.
    group_covariance <- covariance[[group]]
    if (is.null(group_covariance) || is.null(group_covariance$sd)) {
      stop(
        "Internal error: covariance draws could not be found for a stored `brms` random-effect block.",
        call. = FALSE
      )
    }

    covariance_names <- colnames(group_covariance$sd)
    covariance_names[covariance_names == "Intercept"] <- "(Intercept)"
    coefficient_index <- match(coefficients, covariance_names)
    if (anyNA(coefficient_index)) {
      stop(
        "Internal error: `brms` covariance draws could not be aligned with their random-effect coefficients.",
        call. = FALSE
      )
    }
    sd_draws <- group_covariance$sd[, coefficient_index, drop = FALSE]

    # For `||` blocks brms may return only SD draws. Recreate the implied
    # diagonal covariance matrices so both backends expose the same structure.
    if (is.null(group_covariance$cov)) {
      covariance_array <- array(
        0,
        dim = c(nrow(sd_draws), length(coefficients), length(coefficients))
      )
      for (j in seq_along(coefficients)) {
        covariance_array[, j, j] <- sd_draws[, j]^2
      }
    } else {
      covariance_array <- group_covariance$cov[
        , coefficient_index, coefficient_index,
        drop = FALSE
      ]
    }
    dimnames(covariance_array) <- list(NULL, coefficients, coefficients)

    list(
      group = group,
      coefficients = coefficients,
      correlated = isTRUE(correlated),
      term = paste0("(", formula_rhs, " ", bar, " ", group, ")"),
      covariance = covariance_array
    )
  }, block_rows, block_formulas)

  list(
    backend = "brms",
    blocks = blocks
  )
}
