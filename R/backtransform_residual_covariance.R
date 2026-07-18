#' Recover member-level residual covariance from the dyad-mean/member-deviation
#' parameterization of exchangeable APIMs and DIMs
#'
#' Back-transforms exchangeable dyad-mean/member-deviation random-effect pairs
#' from a fitted model to member-level residual variances, covariance, standard
#' deviations, and correlation.
#'
#' @param model A fitted `glmmTMB` or `brmsfit` model.
#' @param pairs `NULL` for automatic matching, or explicit random-effect block
#'   pairs for constrained, renamed, or ambiguous models. Each pair must contain
#'   `dyad_mean`, `member_deviation`, and `idiff`; it may also contain
#'   `mean_indicator`. Multiple pairs are supplied in an outer list. Identify
#'   each block by a model-style random-effect term copied from the model
#'   formula. Common equivalent forms such as
#'   `(1 | group)` and `us(1 | group)`,
#'   or `(0 + x || group)` and `diag(0 + x | group)`, are recognized. Use a named
#'   list and set one component to `NULL`
#'   only when that entire block is absent from the fitted model formula. Do not
#'   use `NULL` for a block that is present but estimated at zero or that you do
#'   not want to report. `idiff` is the exact member-deviation indicator name,
#'   such as `.i_diff_assumed_exchangeable_arbitrary`, `IDIFF`, or
#'   `difference_indicator`. `mean_indicator` is the exact composition-specific
#'   dyad-mean indicator name. It defaults to `"1"`, meaning that the ordinary
#'   random intercept represents the dyad mean.
#'
#' @details
#' The function automatically identifies dyad-mean and member-deviation blocks,
#' matches them by dyad composition and grouping factor, and back-transforms each
#' matched pair to the covariance structure of two arbitrarily labelled members.
#' It supports multiple exchangeable compositions and grouping levels in the
#' same model. The fitted model is not refitted or modified.
#'
#' Automatic matching requires complete, unambiguous pairs. Use `pairs` to
#' assign blocks explicitly when terms were omitted to impose constraints or
#' when more than one match is possible. Terms present in one supplied block but
#' absent from the other are treated as constrained to zero.
#'
#' **Important:** `dyad_mean = NULL` or `member_deviation = NULL` has a narrower
#' meaning: the corresponding *entire random-effect block was not included in
#' the fitted model formula*. If the block exists in the fitted model, supply
#' it—even if its estimated variance is zero, some of its terms were omitted, or
#' you do not plan to report the resulting matrix. Missing terms are determined
#' from the supplied blocks; users do not declare them with `NULL`.
#'
#' When `pairs` is supplied, only those pairs are returned; all other blocks are
#' left alone. Unlisted blocks are inspected only to verify that a component
#' declared as `NULL` does not have an existing compatible block.
#'
#' The explicit interface can be used for one pair:
#'
#' ```r
#' pairs = list(
#'   dyad_mean = "(1 | coupleID)",
#'   member_deviation =
#'     "(0 + IDIFF | coupleID)",
#'   idiff = "IDIFF"
#' )
#' ```
#'
#' For a composition-specific dyad-mean block, supply both indicators:
#'
#' ```r
#' pairs = list(
#'   dyad_mean = "(0 + SAMESEX + SAMESEX:time | coupleID)",
#'   member_deviation =
#'     "(0 + IDIFF_SAMESEX + IDIFF_SAMESEX:time | coupleID)",
#'   idiff = "IDIFF_SAMESEX",
#'   mean_indicator = "SAMESEX"
#' )
#' ```
#'
#' For multiple pairs, use an outer list:
#'
#' ```r
#' pairs = list(
#'   list(
#'     dyad_mean = "(1 | coupleID)",
#'     member_deviation =
#'       "(0 + IDIFF | coupleID)",
#'     idiff = "IDIFF"
#'   ),
#'   # No member-deviation block was included for this grouping level:
#'   list(
#'     dyad_mean = "(1 | coupleID:day)",
#'     member_deviation = NULL,
#'     idiff = "IDIFF"
#'   )
#' )
#' ```
#'
#' Within every supplied member-deviation block, `idiff` must appear in every
#' coefficient, either alone for the member-deviation intercept or in an
#' interaction such as `IDIFF:time` for a slope. Literal products of two columns,
#' such as `I(IDIFF * time)` or `I(time * IDIFF)`, are also recognized as the
#' member-deviation counterpart of `time`. More complex arithmetic inside
#' `I()` is not supported. Similarly, a non-default `mean_indicator` must appear
#' in every dyad-mean coefficient.
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
exchangeable_rescov <- function(model, pairs = NULL) {
  model_data <- extract_exchangeable_residual_blocks(model)

  # TODO: Warn about brms residual-level random-effect terms.

  if (is.null(pairs)) {
    model_data$pairs <- match_exchangeable_residual_blocks(model_data$blocks)
  } else {
    model_data$pairs <- match_supplied_exchangeable_residual_blocks(
      model_data$blocks,
      pairs
    )
  }
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

normalize_exchangeable_block_label <- function(term) {
  term <- trimws(term)
  structure <- NULL
  core <- term

  # glmmTMB shows the covariance structure as an outer wrapper; brms does not.
  wrapper_match <- regexec(
    "^([[:alnum:]_.]+)[[:space:]]*\\((.*)\\)[[:space:]]*$",
    term,
    perl = TRUE
  )
  wrapper_parts <- regmatches(term, wrapper_match)[[1L]]
  has_wrapper <- length(wrapper_parts) == 3L &&
    grepl("|", wrapper_parts[[3L]], fixed = TRUE)
  if (has_wrapper) {
    structure <- wrapper_parts[[2L]]
    core <- wrapper_parts[[3L]]
  } else if (
    startsWith(core, "(") &&
      endsWith(core, ")")
  ) {
    core <- substr(core, 2L, nchar(core) - 1L)
  }

  uncorrelated <- grepl("||", core, fixed = TRUE)
  core <- gsub("||", "|", core, fixed = TRUE)
  bar_parts <- strsplit(core, "|", fixed = TRUE)[[1L]]
  if (length(bar_parts) != 2L) {
    return(NA_character_)
  }

  if (is.null(structure)) {
    structure <- if (uncorrelated) "diag" else "us"
  }

  lhs <- trimws(bar_parts[[1L]])
  group <- trimws(bar_parts[[2L]])
  lhs_terms <- tryCatch(
    stats::terms(stats::as.formula(paste("~", lhs))),
    error = function(e) NULL
  )
  group_expression <- tryCatch(str2lang(group), error = function(e) NULL)
  if (is.null(lhs_terms) || is.null(group_expression)) {
    return(NA_character_)
  }

  coefficients <- attr(lhs_terms, "term.labels")
  for (i in seq_along(coefficients)) {
    interaction_parts <- strsplit(coefficients[[i]], ":", fixed = TRUE)[[1L]]
    coefficients[[i]] <- paste(sort(interaction_parts), collapse = ":")
  }
  lhs <- c(
    if (attr(lhs_terms, "intercept") == 1L) "1" else "0",
    sort(coefficients)
  )

  normalized_term <- paste0(
    structure,
    "(", paste(lhs, collapse = "+"),
    "|", deparse1(group_expression), ")"
  )
  return(normalized_term)
}

format_exchangeable_block_inventory <- function(blocks) {
  terms <- vapply(blocks, `[[`, character(1L), "term")
  inventory <- paste0(
    "\nAvailable extracted random-effect blocks:\n",
    paste0("  [", seq_along(terms), "] `", terms, "`", collapse = "\n")
  )
  return(inventory)
}

parse_exchangeable_coefficient <- function(coefficient) {
  expression <- tryCatch(
    str2lang(coefficient),
    error = function(e) NULL
  )
  if (is.null(expression)) {
    return(list(variables = character(), i_product = NULL))
  }

  i_product <- NULL
  if (
    is.call(expression) &&
      length(expression) == 2L &&
      identical(expression[[1L]], as.name("I"))
  ) {
    product <- expression[[2L]]
    if (
      is.call(product) &&
        length(product) == 3L &&
        identical(product[[1L]], as.name("*")) &&
        is.symbol(product[[2L]]) &&
        is.symbol(product[[3L]])
    ) {
      i_product <- c(
        as.character(product[[2L]]),
        as.character(product[[3L]])
      )
    }
  }

  return(list(
    variables = all.vars(expression),
    i_product = i_product
  ))
}

brms_stored_coefficient_name <- function(coefficient) {
  patterns <- c(" ", "(", ")", "[", "]", ",", "\"", "'", "?", "+", "-", "*", "/", "^", "=", "$")
  replacements <- c(rep("", 9L), "P", "M", "MU", "D", "E", "EQ", "USD")

  for (i in seq_along(patterns)) {
    coefficient <- gsub(
      patterns[[i]],
      replacements[[i]],
      coefficient,
      fixed = TRUE
    )
  }
  return(coefficient)
}

restore_brms_i_product_coefficients <- function(coefficients, formula) {
  formula_terms <- attr(stats::terms(formula), "term.labels")
  i_products <- formula_terms[vapply(
    formula_terms,
    function(term) {
      !is.null(parse_exchangeable_coefficient(term)$i_product)
    },
    logical(1L)
  )]

  for (term in i_products) {
    stored_term <- brms_stored_coefficient_name(term)
    coefficient_index <- which(coefficients == stored_term)
    if (length(coefficient_index) == 1L) {
      coefficients[[coefficient_index]] <- term
    }
  }
  return(coefficients)
}

match_exchangeable_residual_blocks <- function(blocks) {
  matched_pairs <- list()
  used_dyad_mean_indices <- integer()
  block_inventory <- format_exchangeable_block_inventory(blocks)

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
      block_inventory,
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
        "grouping factor and identical terms. Use `pairs` to match an ",
        "intentionally constrained structure explicitly.",
        block_inventory,
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
        "`. Automatic matching requires exactly one unambiguous match; use ",
        "`pairs` to identify the intended match explicitly.",
        block_inventory,
        call. = FALSE
      )
    }

    dyad_mean_index <- dyad_mean_candidates[[1L]]
    if (dyad_mean_index %in% used_dyad_mean_indices) {
      stop(
        "A dyad-mean block matched more than one member-deviation block.",
        block_inventory,
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
      mean_indicator <- "1"
      dyad_mean_terms <- exchangeable_base_terms(
        blocks[[dyad_mean_index]]$coefficients
      )
    } else {
      mean_indicator <- composition_marker
    }


    # The same terms may appear in a different order in the two blocks. Store how
    # to reorder the member-deviation block to match the dyad-mean block.
    matched_pairs[[length(matched_pairs) + 1L]] <- list(
      dyad_mean_index = dyad_mean_index,
      member_deviation_index = member_deviation_index,
      idiff = member_deviation_marker,
      mean_indicator = mean_indicator,
      terms = dyad_mean_terms,
      dyad_mean_order = seq_along(dyad_mean_terms),
      member_deviation_order = match(
        dyad_mean_terms,
        member_deviation_terms
      )
    )
    used_dyad_mean_indices <- c(used_dyad_mean_indices, dyad_mean_index)
  }

  return(matched_pairs)
}

normalize_supplied_exchangeable_pairs <- function(pairs) {
  required_names <- c("dyad_mean", "member_deviation", "idiff")
  allowed_names <- c(required_names, "mean_indicator")
  is_pair <- function(x) {
    !is.null(names(x)) &&
      !anyDuplicated(names(x)) &&
      all(required_names %in% names(x)) &&
      all(names(x) %in% allowed_names)
  }

  # A single named pair does not need an additional outer list.
  if (is_pair(pairs)) {
    pairs <- list(pairs)
  }
  if (!is.list(pairs) || length(pairs) == 0L) {
    stop(
      "`pairs` must be a named pair or a list of named pairs containing `dyad_mean`, `member_deviation`, and `idiff`.",
      call. = FALSE
    )
  }
  for (i in seq_along(pairs)) {
    if (!is_pair(pairs[[i]])) {
      stop(
        "Each element of `pairs` must contain `dyad_mean`, `member_deviation`, and `idiff`, with optional `mean_indicator`.",
        call. = FALSE
      )
    }

    pairs[[i]] <- as.list(pairs[[i]])
    if (!"mean_indicator" %in% names(pairs[[i]])) {
      pairs[[i]]$mean_indicator <- "1"
    }
  }

  return(pairs)
}

resolve_exchangeable_block <- function(selector, location, block_info) {
  if (
    !is.character(selector) ||
      length(selector) != 1L ||
      is.na(selector) ||
      !nzchar(selector)
  ) {
    stop(
      location,
      " must be one random-effect term copied from the model formula.",
      block_info$inventory,
      call. = FALSE
    )
  }

  matches <- which(block_info$terms == selector)
  if (length(matches) == 0L) {
    normalized_selector <- normalize_exchangeable_block_label(selector)
    if (!is.na(normalized_selector)) {
      matches <- which(block_info$normalized_terms == normalized_selector)
    }
  }
  if (length(matches) == 0L) {
    stop(
      location,
      " does not match an extracted random-effect block.",
      block_info$inventory,
      call. = FALSE
    )
  }
  if (length(matches) > 1L) {
    stop(
      location,
      " matches more than one random-effect block and cannot be selected uniquely.",
      block_info$inventory,
      call. = FALSE
    )
  }
  return(matches[[1L]])
}

validate_exchangeable_indicator <- function(
  indicator,
  location,
  allow_intercept = FALSE
) {
  if (
    !is.character(indicator) ||
      length(indicator) != 1L ||
      is.na(indicator) ||
      !nzchar(indicator) ||
      (!allow_intercept && identical(indicator, "1"))
  ) {
    description <- if (allow_intercept) {
      "one column name or `\"1\"` for the ordinary random intercept"
    } else {
      "one member-deviation indicator column name"
    }
    stop(location, " must be ", description, ".", call. = FALSE)
  }
}

contains_exchangeable_indicator <- function(coefficients, indicator) {
  return(any(vapply(
    coefficients,
    function(coefficient) {
      indicator %in% parse_exchangeable_coefficient(coefficient)$variables
    },
    logical(1L)
  )))
}

exchangeable_component_terms <- function(coefficients, indicator, component) {
  component <- match.arg(component, c("dyad_mean", "member_deviation"))
  if (identical(component, "dyad_mean") && identical(indicator, "1")) {
    return(exchangeable_base_terms(coefficients))
  }
  return(exchangeable_base_terms(
    coefficients,
    indicator,
    require_marker = TRUE
  ))
}

find_compatible_exchangeable_blocks <- function(
  blocks,
  groups,
  group,
  indicator,
  component,
  required_terms = NULL
) {
  indices <- which(groups == group)
  compatible <- logical(length(indices))

  for (i in seq_along(indices)) {
    terms <- exchangeable_component_terms(
      blocks[[indices[[i]]]]$coefficients,
      indicator,
      component
    )
    compatible[[i]] <- !is.null(terms) &&
      (is.null(required_terms) || any(terms %in% required_terms))
  }
  return(indices[compatible])
}

match_one_supplied_exchangeable_pair <- function(
  blocks,
  pair,
  pair_number,
  paired_indices,
  block_info
) {
  idiff <- pair[["idiff"]]
  mean_indicator <- pair[["mean_indicator"]]
  validate_exchangeable_indicator(
    idiff,
    paste0("`pairs[[", pair_number, "]]$idiff`")
  )
  validate_exchangeable_indicator(
    mean_indicator,
    paste0("`pairs[[", pair_number, "]]$mean_indicator`"),
    allow_intercept = TRUE
  )
  if (identical(idiff, mean_indicator)) {
    stop(
      "`idiff` and `mean_indicator` must identify different model columns.",
      call. = FALSE
    )
  }

  dyad_mean_index <- if (is.null(pair[["dyad_mean"]])) {
    NA_integer_
  } else {
    resolve_exchangeable_block(
      pair[["dyad_mean"]],
      paste0("`pairs[[", pair_number, "]]$dyad_mean`"),
      block_info
    )
  }
  member_deviation_index <- if (is.null(pair[["member_deviation"]])) {
    NA_integer_
  } else {
    resolve_exchangeable_block(
      pair[["member_deviation"]],
      paste0("`pairs[[", pair_number, "]]$member_deviation`"),
      block_info
    )
  }

  if (is.na(dyad_mean_index) && is.na(member_deviation_index)) {
    stop(
      "A supplied pair cannot have both `dyad_mean = NULL` and `member_deviation = NULL`.",
      call. = FALSE
    )
  }

  current_indices <- c(dyad_mean_index, member_deviation_index)
  current_indices <- current_indices[!is.na(current_indices)]
  if (
    anyDuplicated(current_indices) ||
      any(current_indices %in% paired_indices)
  ) {
    stop(
      "Each random-effect block can occur in only one supplied pair.",
      call. = FALSE
    )
  }

  if (
    !is.na(dyad_mean_index) &&
      !is.na(member_deviation_index) &&
      !identical(
        blocks[[dyad_mean_index]]$group,
        blocks[[member_deviation_index]]$group
      )
  ) {
    stop(
      "The dyad-mean and member-deviation blocks in a pair must use the same grouping factor.",
      call. = FALSE
    )
  }

  member_deviation_terms <- character()
  if (!is.na(member_deviation_index)) {
    member_deviation_block <- blocks[[member_deviation_index]]
    if (
      !identical(mean_indicator, "1") &&
        contains_exchangeable_indicator(
          member_deviation_block$coefficients,
          mean_indicator
        )
    ) {
      stop(
        "The supplied member-deviation block contains its `mean_indicator`.",
        call. = FALSE
      )
    }
    member_deviation_terms <- exchangeable_component_terms(
      member_deviation_block$coefficients,
      idiff,
      "member_deviation"
    )
    if (is.null(member_deviation_terms)) {
      stop(
        "`idiff = \"", idiff,
        "\"` must appear in every coefficient of the supplied member-deviation block.",
        call. = FALSE
      )
    }
  }

  dyad_mean_terms <- character()
  if (!is.na(dyad_mean_index)) {
    dyad_mean_block <- blocks[[dyad_mean_index]]
    if (contains_exchangeable_indicator(dyad_mean_block$coefficients, idiff)) {
      stop(
        "The supplied dyad-mean block contains its `idiff` indicator.",
        call. = FALSE
      )
    }
    dyad_mean_terms <- exchangeable_component_terms(
      dyad_mean_block$coefficients,
      mean_indicator,
      "dyad_mean"
    )
    if (is.null(dyad_mean_terms)) {
      stop(
        "`mean_indicator = \"", mean_indicator,
        "\"` must appear in every coefficient of the supplied dyad-mean block.",
        call. = FALSE
      )
    }
  }

  # `NULL` means that no compatible block exists in the fitted model.
  if (is.na(member_deviation_index)) {
    candidate_indices <- find_compatible_exchangeable_blocks(
      blocks,
      block_info$groups,
      dyad_mean_block$group,
      idiff,
      "member_deviation"
    )
    if (length(candidate_indices) > 0L) {
      stop(
        "`member_deviation = NULL` was supplied, but a compatible block exists: `",
        paste(block_info$terms[candidate_indices], collapse = "`, `"),
        "`. Supply that block instead of `NULL`.",
        call. = FALSE
      )
    }
  }

  if (is.na(dyad_mean_index)) {
    candidate_indices <- find_compatible_exchangeable_blocks(
      blocks,
      block_info$groups,
      member_deviation_block$group,
      mean_indicator,
      "dyad_mean",
      required_terms = member_deviation_terms
    )
    if (length(candidate_indices) > 0L) {
      stop(
        "`dyad_mean = NULL` was supplied, but a compatible block exists: `",
        paste(block_info$terms[candidate_indices], collapse = "`, `"),
        "`. Supply that block instead of `NULL`.",
        call. = FALSE
      )
    }
  }

  if (anyDuplicated(dyad_mean_terms) || anyDuplicated(member_deviation_terms)) {
    stop(
      "A supplied block contains coefficients that map to the same exchangeable term.",
      call. = FALSE
    )
  }

  # Keep the dyad-mean order and append terms found only in the
  # member-deviation block. Missing indices represent structural zeros.
  terms <- unique(c(dyad_mean_terms, member_deviation_terms))
  return(list(
    dyad_mean_index = dyad_mean_index,
    member_deviation_index = member_deviation_index,
    idiff = idiff,
    mean_indicator = mean_indicator,
    terms = terms,
    dyad_mean_order = match(terms, dyad_mean_terms),
    member_deviation_order = match(terms, member_deviation_terms)
  ))
}

match_supplied_exchangeable_residual_blocks <- function(blocks, pairs) {
  pairs <- normalize_supplied_exchangeable_pairs(pairs)

  block_terms <- vapply(blocks, `[[`, character(1L), "term")
  block_info <- list(
    terms = block_terms,
    groups = vapply(blocks, `[[`, character(1L), "group"),
    normalized_terms = vapply(
      block_terms,
      normalize_exchangeable_block_label,
      character(1L)
    ),
    inventory = format_exchangeable_block_inventory(blocks)
  )
  matched_pairs <- vector("list", length(pairs))
  paired_indices <- integer()

  for (i in seq_along(pairs)) {
    matched_pairs[[i]] <- match_one_supplied_exchangeable_pair(
      blocks,
      pairs[[i]],
      pair_number = i,
      paired_indices,
      block_info
    )
    paired_indices <- c(
      paired_indices,
      matched_pairs[[i]]$dyad_mean_index,
      matched_pairs[[i]]$member_deviation_index
    )
    paired_indices <- paired_indices[!is.na(paired_indices)]
  }

  return(matched_pairs)
}

find_exchangeable_member_deviation_marker <- function(coefficients) {
  variables <- unlist(
    lapply(coefficients, function(coefficient) {
      parse_exchangeable_coefficient(coefficient)$variables
    }),
    use.names = FALSE
  )
  markers <- unique(grep(
    "^\\.i_diff_.+_arbitrary$",
    variables,
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
    parsed_coefficient <- parse_exchangeable_coefficient(coefficients[[i]])
    contains_marker[[i]] <-
      !is.null(marker) && marker %in% parsed_coefficient$variables

    i_product <- parsed_coefficient$i_product
    if (!is.null(i_product) && sum(i_product == marker) == 1L) {
      terms[[i]] <- i_product[i_product != marker][[1L]]
      next
    }

    parts <- strsplit(coefficients[[i]], ":", fixed = TRUE)[[1L]]
    # Marker use inside any other expression is not a supported interaction.
    if (contains_marker[[i]] && !marker %in% parts) {
      return(NULL)
    }
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
    stored_coefficients <- unname(block$coef)
    coefficients <- restore_brms_i_product_coefficients(
      stored_coefficients,
      block$form[[1L]]
    )
    stored_coefficients[stored_coefficients == "Intercept"] <- "(Intercept)"
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
    coefficient_index <- match(stored_coefficients, covariance_names)
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
