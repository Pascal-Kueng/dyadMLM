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

  re_terms <- model$modelInfo$reTrms$cond
  re_structure <- model$modelInfo$reStruc$condReStruc
  covariance <- glmmTMB::VarCorr(model)$cond
  n_blocks <- length(re_structure)

  # `cnms` has one named entry per random-effect block, including repeated groups.
  groups <- names(re_terms$cnms)

  # Misaligned blocks could produce plausible but incorrect transformations,
  # so we fail if we can't cleanly align.
  if (
    length(re_terms$cnms) != n_blocks ||
      length(groups) != n_blocks ||
      length(covariance) != n_blocks
  ) {
    stop(
      "Internal error: the stored `glmmTMB` random-effect structures could not be aligned.",
      call. = FALSE
    )
  }

  blocks <- vector("list", n_blocks)
  for (i in seq_len(n_blocks)) {
    coefficients <- unname(re_terms$cnms[[i]])

    # `blockCode`, unlike `fullCor`, reliably distinguishes `|` from `||` in
    # the normalized glmmTMB structure.
    structure <- names(re_structure[[i]]$blockCode)
    correlated <- !structure %in% c("diag", "homdiag")

    # Show the covariance structure explicitly; glmmTMB stores all normalized
    # terms with a single bar, including terms originally specified with `||`.
    term <- paste0(structure, "(", names(re_structure)[[i]], ")")

    # glmmTMB supplies one fitted covariance matrix. Add a leading dimension so
    # downstream code can treat it like the posterior-draw arrays from brms.
    covariance_matrix <- covariance[[i]]
    covariance_array <- array(
      covariance_matrix,
      dim = c(1L, length(coefficients), length(coefficients)),
      dimnames = list(NULL, coefficients, coefficients)
    )

    blocks[[i]] <- list(
      group = groups[[i]],
      coefficients = coefficients,
      correlated = correlated,
      term = term,
      covariance = covariance_array
    )
  }

  block_list <- list(
    backend = "glmmTMB",
    blocks = blocks
  )

  return(block_list)
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
  unsupported <- nzchar(re_terms$dpar) | nzchar(re_terms$nlpar)
  if (any(unsupported)) {
    warning(
      "Random-effect terms for distributional or nonlinear parameters were ignored because they are currently not supported.",
      call. = FALSE
    )
  }
  re_terms <- re_terms[!unsupported, ]

  # A brms ID identifies one covariance block. Different `gn` values reveal
  # explicit `|ID|` syntax linking several formula terms within that block.
  re_blocks <- unname(split(re_terms, re_terms$id))
  if (any(vapply(re_blocks, function(block) {
    length(unique(block$gn)) != 1L
  }, logical(1)))) {
    stop(
      "Random-effect blocks containing more than one formula term are currently not supported.",
      call. = FALSE
    )
  }

  # Keep every posterior draw; transformation and summarization happen later.
  covariance <- brms::VarCorr(model, summary = FALSE)

  blocks <- vector("list", length(re_blocks))
  for (i in seq_along(re_blocks)) {
    block <- re_blocks[[i]]

    # Values within one validated block share their group and correlation flag.
    group <- block$group[[1L]]
    correlated <- isTRUE(block$cor[[1L]])
    coefficients <- unname(block$coef)
    coefficients[coefficients == "Intercept"] <- "(Intercept)"
    formula_rhs <- trimws(sub("^~", "", deparse1(block$form[[1L]])))
    bar <- if (correlated) "|" else "||"

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

    blocks[[i]] <- list(
      group = group,
      coefficients = coefficients,
      correlated = correlated,
      term = paste0("(", formula_rhs, " ", bar, " ", group, ")"),
      covariance = covariance_array
    )
  }

  list(
    backend = "brms",
    blocks = blocks
  )
}
