#' Recover member-level residual covariance from the dyad-mean/member-deviation
#' parameterization of exchangeable APIMs and DIMs
#'
#' Back-transforms exchangeable dyad-mean/member-deviation random-effect pairs
#' from a fitted model to member-level residual variances, covariance, standard
#' deviations, and correlation.
#'
#' @param model A fitted `glmmTMB` or `brmsfit` model.
#'
#' @details
#' The function identifies dyad-mean and member-deviation blocks, matches them by
#' dyad composition and grouping factor, and back-transforms each matched pair
#' to the covariance structure of two arbitrarily labelled members. It supports
#' multiple exchangeable compositions and grouping levels in the same model.
#' The fitted model is not refitted or modified.
#'
#' In Gaussian `brms` models, cross-sectional and same-occasion partner residual
#' dependence is usually represented directly with
#' `unstr(time = member, gr = pair_id)`. Use `sigma ~ 1` for equal residual
#' standard deviations in exchangeable dyads and `sigma ~ 0 + role` for
#' role-specific standard deviations in distinguishable dyads. Dyad-mean and
#' member-deviation group-level blocks remain relevant for stable dyad effects
#' in intensive longitudinal data and are back-transformed by this function.
#'
#' @return A named list with one element per matched dyad-mean/member-deviation
#'   block pair. Each element contains the member-level variance-covariance
#'   matrix in `varcov` and its standard-deviation/correlation representation in
#'   `sdcor`. Element names reproduce the two matched random-effect terms.
#'
#' @export
exchangeable_rescov <- function(model) {
  model_data <- extract_exchangeable_residual_blocks(model)

  # warn if brms used a residual-level re-term and advise to use as described in the details above.

  model_data$pairs <- match_exchangeable_residual_blocks(model_data$blocks)

  # backtransform each block

  return(model_data)
}

#' Extract exchangeable residual blocks from a fitted model
#'
#' Extracts the fitted random-effect structure and covariance parameters needed
#' to identify exchangeable dyad-mean/member-deviation random-effect pairs.
#' Model-engine-specific information is normalized to a common representation.
#'
#' @param model A fitted model. Supported classes are `glmmTMB` and `brmsfit`.
#'
#' @details
#' Dyad-mean and `.i_diff_*` member-deviation blocks are matched by dyad
#' composition and grouping factor. This permits more than one exchangeable
#' composition and more than one grouping level, such as separate stable dyad
#' and same-occasion residual structures.
#'
#' For `glmmTMB` models, the function uses the normalized random-effect
#' structures stored in `model$modelInfo` together with the fitted covariance
#' estimates. For `brmsfit` models, it uses the stored group-level term
#' structure and raw posterior covariance draws. Distributional and nonlinear
#' `brms` random-effect terms are ignored. Multivariate models, linked
#' multi-term blocks, and terms using `gr(..., by = ...)` are currently not
#' supported.
#'
#' @return A normalized internal representation containing the model engine,
#'   extracted random-effect blocks and their fitted covariance parameters.
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

match_exchangeable_residual_blocks <- function(blocks) {
  matched_pairs <- list()
  used_dyad_mean_indices <- integer()

  # Identify all exchangeable compositions before matching. An unmarked
  # dyad-mean block is safe only when the model has one exchangeable composition.
  member_deviation_markers <- rep(NA_character_, length(blocks))
  for (i in seq_along(blocks)) {
    member_deviation_markers[[i]] <-
      find_exchangeable_member_deviation_marker(
        blocks[[i]]$coefficients
      )
  }
  member_deviation_indices <- which(!is.na(member_deviation_markers))
  if (length(member_deviation_indices) == 0L) {
    stop(
      "No supported `.i_diff_*_arbitrary` member-deviation block was found.",
      call. = FALSE
    )
  }

  # the non-idiff blocks could be potential matches.
  dyad_mean_candidate_indices <- which(is.na(member_deviation_markers))

  # We count distinct dyad compositions for mixed dyad types
  # The same composition marker may occur at multiple grouping levels, thus we use unique.
  has_multiple_compositions <- length(unique(
    member_deviation_markers[member_deviation_indices]
  )) > 1L

  for (member_deviation_index in member_deviation_indices) {
    member_deviation_block <- blocks[[member_deviation_index]]
    member_deviation_marker <-
      member_deviation_markers[[member_deviation_index]]

    # A marker without an interaction represents the member-deviation intercept.
    member_deviation_terms <- exchangeable_base_terms(
      member_deviation_block$coefficients,
      member_deviation_marker
    )
    # Match terms independently of their order in the two model formulas.
    member_deviation_signature <- sort(member_deviation_terms)
    composition <- gsub(
      "^\\.i_diff_|_arbitrary$",
      "",
      member_deviation_marker
    )
    composition_marker <- paste0(".i_is_", composition)

    # Composition-specific candidates use `.i_is_*`; unmarked candidates use
    # terms such as `(1 + time | coupleID)`.
    marked_dyad_mean_candidates <- integer()
    unmarked_dyad_mean_candidates <- integer()

    for (dyad_mean_index in dyad_mean_candidate_indices) {
      dyad_mean_block <- blocks[[dyad_mean_index]]

      # Check if same grouping structure is present, otherwise skip
      if (!identical(dyad_mean_block$group, member_deviation_block$group)) {
        next
      }

      # First test whether this is a composition-specific dyad-mean block.
      # Generic, unrelated, or only partially marked blocks return NULL
      dyad_mean_terms <- exchangeable_base_terms(
        dyad_mean_block$coefficients,
        composition_marker,
        require_marker = TRUE
      )
      # Record the candidate when its composition marker and underlying terms match.
      if (
        !is.null(dyad_mean_terms) &&
          identical(sort(dyad_mean_terms), member_deviation_signature)
      ) {
        marked_dyad_mean_candidates <- c(
          marked_dyad_mean_candidates,
          dyad_mean_index
        )
        next
      }

      # An unmarked block can be assigned safely only when the model contains
      # one exchangeable dyad composition. With multiple compositions, its
      # target is ambiguous and composition-specific `.i_is_*` blocks are
      # required.
      if (!has_multiple_compositions) {
        dyad_mean_terms <- exchangeable_base_terms(
          dyad_mean_block$coefficients
        )
        if (identical(sort(dyad_mean_terms), member_deviation_signature)) {
          # We found a match! But need to keep going to see if no other candidate would match
          unmarked_dyad_mean_candidates <- c(
            unmarked_dyad_mean_candidates,
            dyad_mean_index
          )
        }
      }
    }

    # If at least one explicitly composition-marked match exists, we use only these marked matches.
    # otherwise, we fall back to the generic matches.
    dyad_mean_candidates <- if (length(marked_dyad_mean_candidates) > 0L) {
      marked_dyad_mean_candidates
    } else {
      unmarked_dyad_mean_candidates
    }
    if (length(dyad_mean_candidates) == 0L) {
      stop(
        "No dyad-mean block matched the member-deviation block `",
        member_deviation_block$term, "`. Automatic matching requires the same ",
        "grouping factor and identical terms. Explicit matching ",
        "of intentionally constrained structures will be added through a `pairs` argument.",
        call. = FALSE
      )
    }
    if (length(dyad_mean_candidates) > 1L) {
      candidate_terms <- vapply(
        dyad_mean_candidates,
        function(i) blocks[[i]]$term,
        character(1L)
      )
      stop(
        "More than one dyad-mean block matched the member-deviation block `",
        member_deviation_block$term, "`: `",
        paste(candidate_terms, collapse = "`, `"),
        "`. Automatic matching requires exactly one unambiguous match.",
        call. = FALSE
      )
    }

    dyad_mean_index <- dyad_mean_candidates[[1L]]
    if (dyad_mean_index %in% used_dyad_mean_indices) {
      stop(
        "A dyad-mean block matched more than one member-deviation block.",
        call. = FALSE
      )
    }

    # Return specific block if one is a match, else NULL
    dyad_mean_terms <- exchangeable_base_terms(
      blocks[[dyad_mean_index]]$coefficients,
      composition_marker,
      require_marker = TRUE
    )
    # Otherwise, return the generic block if it is a match
    if (is.null(dyad_mean_terms)) {
      dyad_mean_terms <- exchangeable_base_terms(
        blocks[[dyad_mean_index]]$coefficients
      )
    }


    # The same terms may appear in a different order in the two blocks. Store how
    # to reorder the member-deviation block to match the dyad-mean block.
    matched_pairs[[length(matched_pairs) + 1L]] <- list(
      dyad_mean_index = dyad_mean_index,
      member_deviation_index = member_deviation_index,
      terms = dyad_mean_terms,
      member_deviation_order = match(
        dyad_mean_terms,
        member_deviation_terms
      )
    )
    used_dyad_mean_indices <- c(used_dyad_mean_indices, dyad_mean_index)
  }

  return(matched_pairs)
}

find_exchangeable_member_deviation_marker <- function(coefficients) {
  parts <- unlist(
    strsplit(coefficients, ":", fixed = TRUE),
    use.names = FALSE
  )
  markers <- unique(grep(
    "^\\.i_diff_.+_arbitrary$",
    parts,
    value = TRUE
  ))

  if (length(markers) > 1L) {
    stop(
      "A member-deviation block contains more than one `.i_diff_*` column.",
      call. = FALSE
    )
  }
  if (length(markers) == 0L) {
    return(NA_character_)
  }

  return(markers[[1L]])
}

exchangeable_base_terms <- function(
  coefficients,
  marker = NULL,
  require_marker = FALSE
) {
  terms <- character(length(coefficients))
  contains_marker <- logical(length(coefficients))

  for (i in seq_along(coefficients)) {
    parts <- strsplit(coefficients[[i]], ":", fixed = TRUE)[[1L]]
    contains_marker[[i]] <- !is.null(marker) && marker %in% parts
    parts <- parts[!parts %in% marker]
    terms[[i]] <- if (length(parts) == 0L) {
      "(Intercept)"
    } else {
      paste(sort(parts), collapse = ":")
    }
  }

  # A composition marker must apply either to the whole block or to none of it.
  if (
    (any(contains_marker) && !all(contains_marker)) ||
      (require_marker && !all(contains_marker))
  ) {
    return(NULL)
  }

  return(terms)
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
  term_labels <- names(re_structure)

  # Misaligned blocks could produce plausible but incorrect transformations,
  # so we fail if we can't cleanly align.
  if (
    length(re_terms$cnms) != n_blocks ||
      length(groups) != n_blocks ||
      length(term_labels) != n_blocks ||
      length(covariance) != n_blocks
  ) {
    stop(
      "Internal error: the stored `glmmTMB` random-effect structures could not be aligned.",
      call. = FALSE
    )
  }
  if (
    any(is.na(groups) | !nzchar(groups)) ||
      any(is.na(term_labels) | !nzchar(term_labels))
  ) {
    stop(
      "Internal error: stored `glmmTMB` random-effect labels are missing.",
      call. = FALSE
    )
  }

  blocks <- vector("list", n_blocks)
  for (i in seq_len(n_blocks)) {
    coefficients <- unname(re_terms$cnms[[i]])

    # `blockCode` records the normalized covariance structure (`us`, `diag`,
    # `homdiag`, and so on); it does not preserve the user's exact syntax.
    structure <- names(re_structure[[i]]$blockCode)
    if (
      length(structure) != 1L ||
        is.na(structure) ||
        !nzchar(structure)
    ) {
      stop(
        "Internal error: a stored `glmmTMB` covariance structure is missing.",
        call. = FALSE
      )
    }
    correlated <- !structure %in% c("diag", "homdiag")

    # Show the covariance structure explicitly; glmmTMB stores all normalized
    # terms with a single bar, including terms originally specified with `||`.
    term <- paste0(structure, "(", term_labels[[i]], ")")

    # glmmTMB supplies one fitted covariance matrix. Add a leading dimension so
    # downstream code can treat it like the posterior-draw arrays from brms.
    covariance_matrix <- covariance[[i]]
    expected_dimension <- rep(length(coefficients), 2L)
    if (!identical(dim(covariance_matrix), expected_dimension)) {
      stop(
        "Internal error: a stored `glmmTMB` covariance matrix has unexpected dimensions.",
        call. = FALSE
      )
    }

    covariance_rows <- rownames(covariance_matrix)
    covariance_columns <- colnames(covariance_matrix)
    if (
      is.null(covariance_rows) ||
        is.null(covariance_columns) ||
        anyDuplicated(coefficients) ||
        !setequal(covariance_rows, coefficients) ||
        !setequal(covariance_columns, coefficients)
    ) {
      stop(
        "Internal error: `glmmTMB` covariance parameters could not be aligned with their random-effect coefficients.",
        call. = FALSE
      )
    }
    covariance_matrix <- covariance_matrix[
      coefficients,
      coefficients,
      drop = FALSE
    ]
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

  if (nrow(re_terms) == 0L) {
    block_list <- list(
      backend = "brms",
      blocks = list()
    )
    return(block_list)
  }

  if (
    "by" %in% names(re_terms) &&
      any(!is.na(re_terms$by) & nzchar(re_terms$by))
  ) {
    stop(
      "Random-effect terms using `gr(..., by = ...)` are currently not supported.",
      call. = FALSE
    )
  }

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

  block_list <- list(
    backend = "brms",
    blocks = blocks
  )

  return(block_list)
}
