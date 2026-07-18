#' Recover member-level residual covariance from exchangeable random-effect blocks
#'
#' Back-transforms paired shared and difference random-effect covariance
#' matrices to the covariance structure of two exchangeable members.
#'
#' @param model A fitted `glmmTMB` or single-response `brmsfit` model.
#' @param pairs `NULL` for automatic matching, or one exact block pair (or an
#'   outer list of block pairs). Each pair must contain `shared`, `difference`,
#'   and `idiff`, and may contain `shared_indicator`. Copy `shared` and
#'   `difference` from the model formula. Either block may be `NULL` only when
#'   that entire block was omitted from the fitted model. `idiff` is the exact
#'   difference-indicator column name. `shared_indicator` is the exact
#'   composition indicator and defaults to `"1"`, meaning an ordinary random
#'   intercept.
#'
#' @details
#' Automatic matching recognizes exact `.i_diff_*_arbitrary` coefficient names
#' and first looks for the corresponding `.i_is_*` shared block. It remains
#' deliberately conservative: the two blocks must use the same grouping factor
#' and contain the same underlying terms.
#'
#' Use `pairs` when block matching is ambiguous, when custom indicator names
#' were used, or when terms were omitted to impose constraints. Terms found in
#' only one selected block are represented as structural zeros in the other.
#' `shared = NULL` or `difference = NULL` means that the whole corresponding
#' block was absent—not that an existing fitted block should be ignored.
#'
#' ```r
#' pairs = list(
#'   shared = "(1 + time | coupleID)",
#'   difference = "(0 + IDIFF + I(IDIFF * time) || coupleID)",
#'   idiff = "IDIFF"
#' )
#' ```
#'
#' A composition-specific pair also names its shared indicator:
#'
#' ```r
#' pairs = list(
#'   shared = "(0 + SAMESEX + SAMESEX:time | coupleID)",
#'   difference =
#'     "(0 + IDIFF_SAMESEX + IDIFF_SAMESEX:time | coupleID)",
#'   idiff = "IDIFF_SAMESEX",
#'   shared_indicator = "SAMESEX"
#' )
#' ```
#'
#' Model-style equivalents are recognized across backends, such as
#' `(1 + time | group)` and `us(1 + time | group)`, or
#' `(0 + x || group)` and `diag(0 + x | group)`. Difference slopes may be
#' written as `IDIFF:time`, `time:IDIFF`, `I(IDIFF * time)`, or
#' `I(time * IDIFF)`. More complex arithmetic inside `I()` is not interpreted.
#'
#' Here “shared” and “difference” describe the random-effect coordinates: one
#' moves both members together and the other moves them in opposite directions.
#' They are distinct from dyad-mean and within-dyad member-deviation predictor
#' columns, even though both use the same mean/difference logic.
#'
#' When the fitted model frame retains the indicator columns, `idiff` must use
#' unnormalised `-1/+1` coding where `shared_indicator` is one and be zero
#' elsewhere. A column omitted entirely from the fitted formula cannot be
#' recovered from either supported backend, so its coding cannot be checked.
#'
#' In Gaussian `brms` models, cross-sectional and same-occasion partner
#' residual dependence is usually represented directly with
#' `unstr(time = member, gr = pair_id)`. The blocks handled here remain relevant
#' for higher-level shared and difference random effects.
#'
#' @return A named list with one element per matched block pair. Each element
#'   contains the member-level variance-covariance matrix in `varcov` and its
#'   standard-deviation/correlation representation in `sdcor`. Names reproduce
#'   the matched random-effect terms.
#'
#' @export
exchangeable_rescov <- function(model, pairs = NULL) {
  model_structure <- extract_exchangeable_residual_blocks(model)
  model_frame <- tryCatch(
    stats::model.frame(model),
    error = function(e) NULL
  )
  if (!is.data.frame(model_frame)) {
    stop(
      "The fitted model data could not be recovered to validate the exchangeable coding.",
      call. = FALSE
    )
  }

  if (is.null(pairs)) {
    model_structure$pairs <- match_exchangeable_residual_blocks(
      model_structure$blocks,
      model_frame
    )
  } else {
    model_structure$pairs <- match_supplied_exchangeable_residual_blocks(
      model_structure$blocks,
      pairs,
      model_frame
    )
  }
  return(model_structure)
}

#' Extract exchangeable random-effect blocks from a fitted model
#'
#' Normalizes the random-effect coefficients and fitted covariance parameters
#' needed by [exchangeable_rescov()] while keeping backend-specific work in two
#' small adapters.
#'
#' @param model A fitted model. Supported classes are `glmmTMB` and `brmsfit`.
#'
#' @return A list containing the model `backend` and one normalized record per
#'   random-effect block. Every record contains `group`, `coefficients`,
#'   `correlated`, `term`, and an estimate/draw-by-coefficients covariance
#'   array.
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

format_exchangeable_block_inventory <- function(blocks) {
  labels <- character(length(blocks))
  for (i in seq_along(blocks)) {
    labels[[i]] <- paste0("  [", i, "] `", blocks[[i]]$term, "`")
  }
  return(paste0(
    "\nAvailable extracted random-effect blocks:\n",
    paste(labels, collapse = "\n")
  ))
}

# Parse without evaluating. Only `I(a * b)` with two simple symbols is
# recognized as a literal product.
parse_exchangeable_coefficient <- function(coefficient) {
  expression <- tryCatch(
    str2lang(coefficient),
    error = function(e) NULL
  )
  if (is.null(expression)) {
    return(list(variables = character(), literal_product = NULL))
  }

  literal_product <- NULL
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
      literal_product <- c(
        as.character(product[[2L]]),
        as.character(product[[3L]])
      )
    }
  }

  return(list(
    variables = all.vars(expression),
    literal_product = literal_product
  ))
}

block_contains_indicator <- function(block, indicator) {
  for (coefficient in block$coefficients) {
    parsed <- parse_exchangeable_coefficient(coefficient)
    if (indicator %in% parsed$variables) {
      return(TRUE)
    }
  }
  return(FALSE)
}

exchangeable_underlying_terms <- function(coefficients, indicator = "1") {
  terms <- character(length(coefficients))

  for (i in seq_along(coefficients)) {
    coefficient <- coefficients[[i]]
    if (identical(indicator, "1")) {
      parts <- if (identical(coefficient, "(Intercept)")) {
        character()
      } else {
        strsplit(coefficient, ":", fixed = TRUE)[[1L]]
      }
    } else {
      parsed <- parse_exchangeable_coefficient(coefficient)
      product <- parsed$literal_product

      if (!is.null(product) && sum(product == indicator) == 1L) {
        terms[[i]] <- product[product != indicator][[1L]]
        next
      }

      parts <- strsplit(coefficient, ":", fixed = TRUE)[[1L]]
      # Uses of the indicator inside any other expression are not interpreted.
      if (
        !indicator %in% parsed$variables ||
          sum(parts == indicator) != 1L
      ) {
        return(NULL)
      }
      parts <- parts[parts != indicator]
    }

    terms[[i]] <- if (length(parts) == 0L) {
      "(Intercept)"
    } else {
      paste(sort(parts), collapse = ":")
    }
  }

  if (anyDuplicated(terms)) {
    stop(
      "A random-effect block contains coefficients that reduce to the same exchangeable term.",
      call. = FALSE
    )
  }
  return(terms)
}

find_exchangeable_difference_indicator <- function(coefficients) {
  variables <- character()
  for (coefficient in coefficients) {
    variables <- c(
      variables,
      parse_exchangeable_coefficient(coefficient)$variables
    )
  }
  markers <- unique(grep(
    "^\\.i_diff_.+_arbitrary$",
    variables,
    value = TRUE
  ))

  if (length(markers) > 1L) {
    stop(
      "A difference block contains more than one `.i_diff_*_arbitrary` column.",
      call. = FALSE
    )
  }
  if (length(markers) == 0L) {
    return(NA_character_)
  }
  return(markers[[1L]])
}

validate_exchangeable_coding <- function(
  model_frame,
  idiff,
  shared_indicator
) {
  if (is.null(model_frame)) {
    return(invisible(NULL))
  }

  if (!idiff %in% names(model_frame)) {
    warning(
      "`", idiff,
      "` was not retained in the fitted model frame, so its -1/+1 coding could not be checked.",
      call. = FALSE
    )
    return(invisible(NULL))
  }

  difference <- model_frame[[idiff]]
  if (identical(shared_indicator, "1")) {
    shared <- rep(1, nrow(model_frame))
  } else if (shared_indicator %in% names(model_frame)) {
    shared <- model_frame[[shared_indicator]]
  } else {
    warning(
      "`", shared_indicator,
      "` was not retained in the fitted model frame, so its support could not be checked.",
      call. = FALSE
    )
    shared <- abs(difference)
  }
  if (is.logical(shared)) {
    shared <- as.numeric(shared)
  }

  if (!is.numeric(difference) || !is.numeric(shared) ||
      anyNA(difference) || anyNA(shared)) {
    stop(
      "Exchangeable difference and shared-indicator columns must be ",
      "complete numeric columns in the fitted data.",
      call. = FALSE
    )
  }

  valid_coding <- all(difference %in% c(-1, 0, 1)) &&
    all(shared %in% c(0, 1)) &&
    all(abs(difference) == shared)
  if (!valid_coding) {
    stop(
      "`", idiff, "` must use -1/+1 coding where `",
      shared_indicator, "` is one and zero elsewhere in the fitted data.",
      call. = FALSE
    )
  }

  supported <- shared == 1
  if (!any(difference[supported] == -1) ||
      !any(difference[supported] == 1)) {
    stop(
      "`", idiff, "` must contain both -1 and +1 on its supported fitted rows.",
      call. = FALSE
    )
  }
  return(invisible(NULL))
}

build_exchangeable_pair <- function(
  blocks,
  shared_block_index,
  difference_block_index,
  idiff,
  shared_indicator
) {
  if (is.na(shared_block_index) && is.na(difference_block_index)) {
    stop("A pair cannot omit both its shared and difference blocks.",
      call. = FALSE
    )
  }
  if (
    !is.na(shared_block_index) &&
      !is.na(difference_block_index) &&
      !identical(
        blocks[[shared_block_index]]$group,
        blocks[[difference_block_index]]$group
      )
  ) {
    stop(
      "The shared and difference blocks in a pair must use the same grouping factor.",
      call. = FALSE
    )
  }

  shared_terms <- character()
  if (!is.na(shared_block_index)) {
    shared_block <- blocks[[shared_block_index]]
    if (block_contains_indicator(shared_block, idiff)) {
      stop(
        "The selected shared block contains its `idiff` indicator.",
        call. = FALSE
      )
    }
    shared_terms <- exchangeable_underlying_terms(
      shared_block$coefficients,
      shared_indicator
    )
    if (is.null(shared_terms)) {
      stop(
        "`shared_indicator = \"", shared_indicator,
        "\"` must identify every coefficient in the selected shared block.",
        call. = FALSE
      )
    }
  }

  difference_terms <- character()
  if (!is.na(difference_block_index)) {
    difference_block <- blocks[[difference_block_index]]
    if (
      !identical(shared_indicator, "1") &&
        block_contains_indicator(difference_block, shared_indicator)
    ) {
      stop(
        "The selected difference block contains its `shared_indicator`.",
        call. = FALSE
      )
    }
    difference_terms <- exchangeable_underlying_terms(
      difference_block$coefficients,
      idiff
    )
    if (is.null(difference_terms)) {
      stop(
        "`idiff = \"", idiff,
        "\"` must identify every coefficient in the selected difference block. ",
        "Use `idiff:term` or `I(idiff * term)` for slopes.",
        call. = FALSE
      )
    }
  }

  # The union is the common coefficient space for both blocks. `NA` indices
  # mark terms whose covariance rows and columns must later be filled with zero.
  underlying_terms <- unique(c(shared_terms, difference_terms))

  return(list(
    shared_block_index = shared_block_index,
    difference_block_index = difference_block_index,
    idiff = idiff,
    shared_indicator = shared_indicator,
    underlying_terms = underlying_terms,
    shared_term_indices = match(underlying_terms, shared_terms),
    difference_term_indices = match(underlying_terms, difference_terms)
  ))
}

find_exchangeable_shared_candidates <- function(
  blocks,
  difference_block_index,
  difference_terms,
  shared_indicator,
  excluded_difference_indices = integer()
) {
  candidate_indices <- integer()
  difference_group <- blocks[[difference_block_index]]$group

  for (i in seq_along(blocks)) {
    if (
      i == difference_block_index ||
        i %in% excluded_difference_indices ||
        !identical(blocks[[i]]$group, difference_group)
    ) {
      next
    }

    shared_terms <- exchangeable_underlying_terms(
      blocks[[i]]$coefficients,
      shared_indicator
    )
    if (
      !is.null(shared_terms) &&
        setequal(shared_terms, difference_terms)
    ) {
      candidate_indices <- c(candidate_indices, i)
    }
  }
  return(candidate_indices)
}

match_blocks_for_exchangeable_indicator <- function(
  blocks,
  idiff,
  shared_indicator,
  fallback_indicator = NULL,
  model_frame = NULL
) {
  inventory <- format_exchangeable_block_inventory(blocks)
  difference_block_indices <- integer()

  for (i in seq_along(blocks)) {
    if (!block_contains_indicator(blocks[[i]], idiff)) {
      next
    }
    if (is.null(exchangeable_underlying_terms(
      blocks[[i]]$coefficients,
      idiff
    ))) {
      stop(
        "`", idiff, "` must identify every coefficient in its difference ",
        "block. Use `idiff:term` or `I(idiff * term)` for slopes.",
        inventory,
        call. = FALSE
      )
    }
    difference_block_indices <- c(difference_block_indices, i)
  }

  if (length(difference_block_indices) == 0L) {
    stop(
      "No difference block contains `", idiff, "`.",
      inventory,
      call. = FALSE
    )
  }

  matched_pairs <- list()
  for (difference_block_index in difference_block_indices) {
    difference_terms <- exchangeable_underlying_terms(
      blocks[[difference_block_index]]$coefficients,
      idiff
    )
    matched_shared_indicator <- shared_indicator
    candidate_indices <- find_exchangeable_shared_candidates(
      blocks,
      difference_block_index,
      difference_terms,
      matched_shared_indicator,
      excluded_difference_indices = difference_block_indices
    )
    if (length(candidate_indices) == 0L && !is.null(fallback_indicator)) {
      matched_shared_indicator <- fallback_indicator
      candidate_indices <- find_exchangeable_shared_candidates(
        blocks,
        difference_block_index,
        difference_terms,
        matched_shared_indicator,
        excluded_difference_indices = difference_block_indices
      )
    }

    if (length(candidate_indices) != 1L) {
      problem <- if (length(candidate_indices) == 0L) "No" else "More than one"
      stop(
        problem, " shared block matched difference block `",
        blocks[[difference_block_index]]$term,
        "`. Matching requires the same group and underlying terms.",
        inventory,
        call. = FALSE
      )
    }

    pair <- build_exchangeable_pair(
      blocks,
      candidate_indices[[1L]],
      difference_block_index,
      idiff,
      matched_shared_indicator
    )
    validate_exchangeable_coding(
      model_frame,
      idiff,
      matched_shared_indicator
    )
    matched_pairs[[length(matched_pairs) + 1L]] <- pair
  }
  return(matched_pairs)
}

match_exchangeable_residual_blocks <- function(
  blocks,
  model_frame = NULL
) {
  difference_indicators <- rep(NA_character_, length(blocks))
  for (i in seq_along(blocks)) {
    difference_indicators[[i]] <- find_exchangeable_difference_indicator(
      blocks[[i]]$coefficients
    )
  }
  difference_indicators <- unique(
    difference_indicators[!is.na(difference_indicators)]
  )
  if (length(difference_indicators) == 0L) {
    stop(
      "No supported `.i_diff_*_arbitrary` difference block was found.",
      format_exchangeable_block_inventory(blocks),
      call. = FALSE
    )
  }

  matched_pairs <- list()
  for (idiff in difference_indicators) {
    composition <- sub("^\\.i_diff_(.+)_arbitrary$", "\\1", idiff)
    indicator_pairs <- match_blocks_for_exchangeable_indicator(
      blocks,
      idiff,
      shared_indicator = paste0(".i_is_", composition),
      fallback_indicator = if (length(difference_indicators) == 1L) "1" else NULL,
      model_frame = model_frame
    )
    matched_pairs <- c(matched_pairs, indicator_pairs)
  }

  shared_block_indices <- integer()
  difference_block_indices <- integer()
  for (pair in matched_pairs) {
    shared_block_indices <- c(
      shared_block_indices,
      pair$shared_block_index
    )
    difference_block_indices <- c(
      difference_block_indices,
      pair$difference_block_index
    )
  }
  if (anyDuplicated(shared_block_indices)) {
    stop("A shared block matched more than one difference block.", call. = FALSE)
  }
  return(matched_pairs[order(difference_block_indices)])
}

canonicalize_exchangeable_block_term <- function(term) {
  if (
    !is.character(term) ||
      length(term) != 1L ||
      is.na(term) ||
      !nzchar(trimws(term))
  ) {
    return(NA_character_)
  }

  term <- trimws(term)
  structure <- NULL
  core <- term

  # glmmTMB prints structures such as `us(...)` or `diag(...)`; brms prints a
  # bar term.
  wrapper_match <- regexec(
    "^([[:alnum:]_.]+)[[:space:]]*\\((.*)\\)[[:space:]]*$",
    term,
    perl = TRUE
  )
  wrapper <- regmatches(term, wrapper_match)[[1L]]
  if (length(wrapper) == 3L && grepl("|", wrapper[[3L]], fixed = TRUE)) {
    structure <- wrapper[[2L]]
    core <- wrapper[[3L]]
  } else if (startsWith(core, "(") && endsWith(core, ")")) {
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

  lhs_terms <- tryCatch(
    stats::terms(stats::as.formula(paste("~", trimws(bar_parts[[1L]])))),
    error = function(e) NULL
  )
  group <- tryCatch(
    str2lang(trimws(bar_parts[[2L]])),
    error = function(e) NULL
  )
  if (is.null(lhs_terms) || is.null(group)) {
    return(NA_character_)
  }

  coefficients <- attr(lhs_terms, "term.labels")
  for (i in seq_along(coefficients)) {
    parts <- strsplit(coefficients[[i]], ":", fixed = TRUE)[[1L]]
    for (j in seq_along(parts)) {
      parsed <- parse_exchangeable_coefficient(parts[[j]])
      if (!is.null(parsed$literal_product)) {
        parts[[j]] <- paste0(
          "I(",
          paste(sort(parsed$literal_product), collapse = " * "),
          ")"
        )
        next
      }

      expression <- tryCatch(str2lang(parts[[j]]), error = function(e) NULL)
      parts[[j]] <- if (is.null(expression)) {
        trimws(parts[[j]])
      } else {
        deparse1(expression)
      }
    }
    coefficients[[i]] <- paste(sort(parts), collapse = ":")
  }

  lhs <- c(
    if (attr(lhs_terms, "intercept") == 1L) "1" else "0",
    sort(coefficients)
  )
  return(paste0(
    structure, "(", paste(lhs, collapse = "+"),
    "|", deparse1(group), ")"
  ))
}

normalize_supplied_exchangeable_pairs <- function(pairs) {
  required_names <- c("shared", "difference", "idiff")
  allowed_names <- c(required_names, "shared_indicator")
  is_pair <- function(x) {
    is.list(x) &&
      !is.null(names(x)) &&
      !anyDuplicated(names(x)) &&
      all(required_names %in% names(x)) &&
      all(names(x) %in% allowed_names)
  }
  is_nonempty_string <- function(x) {
    is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
  }

  if (is_pair(pairs)) {
    pairs <- list(pairs)
  }
  if (!is.list(pairs) || length(pairs) == 0L) {
    stop(
      "`pairs` must be one named block pair or a list of named block pairs.",
      call. = FALSE
    )
  }

  for (i in seq_along(pairs)) {
    pair <- pairs[[i]]
    if (!is_pair(pair)) {
      stop(
        "Each `pairs` element must contain `shared`, `difference`, and ",
        "`idiff`, with optional `shared_indicator`.",
        call. = FALSE
      )
    }
    if (!"shared_indicator" %in% names(pair)) {
      pair$shared_indicator <- "1"
    }

    for (field in c("idiff", "shared_indicator")) {
      if (!is_nonempty_string(pair[[field]])) {
        stop("`", field, "` must be one non-empty column name.", call. = FALSE)
      }
    }
    if (identical(pair$idiff, "1")) {
      stop("`idiff` must name a difference-indicator column.", call. = FALSE)
    }
    if (identical(pair$idiff, pair$shared_indicator)) {
      stop("`idiff` and `shared_indicator` must be different.", call. = FALSE)
    }

    for (field in c("shared", "difference")) {
      selector <- pair[[field]]
      if (!is.null(selector) && !is_nonempty_string(selector)) {
        stop(
          "`", field,
          "` must be one random-effect term copied from the model formula, or `NULL`.",
          call. = FALSE
        )
      }
    }
    if (is.null(pair$shared) && is.null(pair$difference)) {
      stop("A pair cannot set both `shared` and `difference` to `NULL`.",
        call. = FALSE
      )
    }
    pairs[[i]] <- pair
  }
  return(pairs)
}

resolve_exchangeable_block_selector <- function(
  selector,
  selector_label,
  block_lookup
) {
  if (is.null(selector)) {
    return(NA_integer_)
  }

  matches <- which(block_lookup$term_labels == selector)
  if (length(matches) == 0L) {
    canonical_term <- canonicalize_exchangeable_block_term(selector)
    if (!is.na(canonical_term)) {
      matches <- which(
        block_lookup$canonical_term_labels == canonical_term
      )
    }
  }
  if (length(matches) == 0L) {
    stop(
      selector_label, " does not match an extracted random-effect block.",
      block_lookup$inventory,
      call. = FALSE
    )
  }
  if (length(matches) > 1L) {
    stop(
      selector_label,
      " matches more than one random-effect block and cannot be selected uniquely.",
      block_lookup$inventory,
      call. = FALSE
    )
  }
  return(matches[[1L]])
}

# This guard finds blocks that could contradict an explicitly omitted (`NULL`)
# component. Ordinary block matching uses the exact selectors supplied above.
find_potential_exchangeable_blocks <- function(
  blocks,
  group,
  indicator,
  exclude_indicator = NULL,
  overlap_terms = NULL
) {
  candidate_indices <- integer()
  for (i in seq_along(blocks)) {
    if (!identical(blocks[[i]]$group, group)) {
      next
    }
    if (
      !is.null(exclude_indicator) &&
        block_contains_indicator(blocks[[i]], exclude_indicator)
    ) {
      next
    }

    block <- blocks[[i]]
    terms <- exchangeable_underlying_terms(block$coefficients, indicator)
    if (is.null(terms)) {
      # An unsupported partial block may still contradict `NULL`. If it uses
      # the declared indicator, require the user to select or revise it.
      if (
        !identical(indicator, "1") &&
          block_contains_indicator(block, indicator)
      ) {
        candidate_indices <- c(candidate_indices, i)
      }
      next
    }
    if (
      !is.null(overlap_terms) &&
        !any(terms %in% overlap_terms)
    ) {
      next
    }
    candidate_indices <- c(candidate_indices, i)
  }
  return(candidate_indices)
}

match_one_supplied_exchangeable_pair <- function(
  blocks,
  pair,
  pair_number,
  block_lookup,
  model_frame = NULL
) {
  shared_block_index <- resolve_exchangeable_block_selector(
    pair$shared,
    paste0("`pairs[[", pair_number, "]]$shared`"),
    block_lookup
  )
  difference_block_index <- resolve_exchangeable_block_selector(
    pair$difference,
    paste0("`pairs[[", pair_number, "]]$difference`"),
    block_lookup
  )

  selected_block_indices <- c(shared_block_index, difference_block_index)
  selected_block_indices <- selected_block_indices[
    !is.na(selected_block_indices)
  ]

  matched_pair <- build_exchangeable_pair(
    blocks,
    shared_block_index,
    difference_block_index,
    pair$idiff,
    pair$shared_indicator
  )

  present_block_index <- selected_block_indices[[1L]]
  group <- blocks[[present_block_index]]$group

  # `NULL` declares that the corresponding block was not fitted. Catch clear
  # contradictions rather than silently inserting structural zeros.
  if (is.na(difference_block_index)) {
    potential_block_indices <- find_potential_exchangeable_blocks(
      blocks,
      group,
      pair$idiff,
      overlap_terms = matched_pair$underlying_terms
    )
    potential_block_indices <- setdiff(
      potential_block_indices,
      selected_block_indices
    )
    if (length(potential_block_indices) > 0L) {
      stop(
        "`difference = NULL` was supplied, but a compatible block exists: `",
        paste(
          block_lookup$term_labels[potential_block_indices],
          collapse = "`, `"
        ),
        "`. Supply that block instead of `NULL`.",
        call. = FALSE
      )
    }
  }

  if (is.na(shared_block_index)) {
    potential_block_indices <- find_potential_exchangeable_blocks(
      blocks,
      group,
      pair$shared_indicator,
      exclude_indicator = pair$idiff,
      overlap_terms = matched_pair$underlying_terms
    )
    potential_block_indices <- setdiff(
      potential_block_indices,
      selected_block_indices
    )
    if (length(potential_block_indices) > 0L) {
      stop(
        "`shared = NULL` was supplied, but a compatible block exists: `",
        paste(
          block_lookup$term_labels[potential_block_indices],
          collapse = "`, `"
        ),
        "`. Supply that block instead of `NULL`.",
        call. = FALSE
      )
    }
  }

  validate_exchangeable_coding(
    model_frame,
    pair$idiff,
    pair$shared_indicator
  )
  return(matched_pair)
}

match_supplied_exchangeable_residual_blocks <- function(
  blocks,
  pairs,
  model_frame = NULL
) {
  pairs <- normalize_supplied_exchangeable_pairs(pairs)
  term_labels <- vapply(blocks, `[[`, character(1L), "term")
  block_lookup <- list(
    term_labels = term_labels,
    canonical_term_labels = vapply(
      term_labels,
      canonicalize_exchangeable_block_term,
      character(1L)
    ),
    inventory = format_exchangeable_block_inventory(blocks)
  )

  matched_pairs <- vector("list", length(pairs))
  for (i in seq_along(pairs)) {
    matched_pairs[[i]] <- match_one_supplied_exchangeable_pair(
      blocks,
      pairs[[i]],
      i,
      block_lookup,
      model_frame
    )
  }

  paired_block_indices <- integer()
  for (pair in matched_pairs) {
    paired_block_indices <- c(
      paired_block_indices,
      pair$shared_block_index,
      pair$difference_block_index
    )
  }
  paired_block_indices <- paired_block_indices[
    !is.na(paired_block_indices)
  ]
  if (anyDuplicated(paired_block_indices)) {
    stop(
      "Each random-effect block can occur in only one supplied pair.",
      call. = FALSE
    )
  }
  return(matched_pairs)
}

glmmTMB_extract_exchangeable_residual_blocks <- function(model) {
  if (!requireNamespace("glmmTMB", quietly = TRUE)) {
    stop(
      "Package `glmmTMB` must be installed to extract covariance ",
      "parameters from a `glmmTMB` model.",
      call. = FALSE
    )
  }

  re_terms <- model$modelInfo$reTrms$cond
  re_structure <- model$modelInfo$reStruc$condReStruc
  fitted_covariance <- glmmTMB::VarCorr(model)$cond

  # These stored objects use the same normalized random-effect block order.
  groups <- names(re_terms$cnms)
  term_labels <- names(re_structure)
  n_blocks <- length(re_structure)

  if (
    length(re_terms$cnms) != n_blocks ||
      length(groups) != n_blocks ||
      length(term_labels) != n_blocks ||
      length(fitted_covariance) != n_blocks
  ) {
    stop(
      "Internal error: stored `glmmTMB` random-effect blocks could not be aligned.",
      call. = FALSE
    )
  }

  blocks <- vector("list", n_blocks)
  for (i in seq_len(n_blocks)) {
    coefficients <- unname(re_terms$cnms[[i]])
    covariance_matrix <- fitted_covariance[[i]]
    structure <- names(re_structure[[i]]$blockCode)

    if (
      length(structure) != 1L ||
        anyDuplicated(coefficients) ||
        !setequal(rownames(covariance_matrix), coefficients) ||
        !setequal(colnames(covariance_matrix), coefficients)
    ) {
      stop(
        "Internal error: a `glmmTMB` covariance block could not be aligned with its coefficients.",
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
      correlated = !structure %in% c("diag", "homdiag"),
      term = paste0(structure, "(", term_labels[[i]], ")"),
      covariance = covariance_array
    )
  }
  return(list(backend = "glmmTMB", blocks = blocks))
}

brms_readable_exchangeable_coefficients <- function(block, model_frame) {
  block <- block[order(block$cn), , drop = FALSE]
  stored <- unname(block$coef)
  readable <- tryCatch(
    colnames(stats::model.matrix(block$form[[1L]], data = model_frame)),
    error = function(e) NULL
  )
  if (is.null(readable) || length(readable) != length(stored)) {
    readable <- stored
  }
  readable[readable == "Intercept"] <- "(Intercept)"
  return(list(stored = stored, readable = readable))
}

brms_extract_exchangeable_residual_blocks <- function(model) {
  if (!requireNamespace("brms", quietly = TRUE)) {
    stop(
      "Package `brms` must be installed to extract covariance parameters from a `brmsfit` model.",
      call. = FALSE
    )
  }
  if (inherits(model$formula, "mvbrmsformula")) {
    stop(
      "Multivariate `brms` models are not supported; `model` must contain one response.",
      call. = FALSE
    )
  }

  re_terms <- model$ranef
  # Only ordinary response-mean random effects have the covariance
  # interpretation needed here.
  unsupported <- nzchar(re_terms$dpar) | nzchar(re_terms$nlpar)
  if (any(unsupported)) {
    warning(
      "Random effects for distributional or nonlinear parameters were ignored.",
      call. = FALSE
    )
  }
  re_terms <- re_terms[!unsupported, , drop = FALSE]
  if (nrow(re_terms) == 0L) {
    return(list(backend = "brms", blocks = list()))
  }
  if (
    "by" %in% names(re_terms) &&
      any(!is.na(re_terms$by) & nzchar(re_terms$by))
  ) {
    stop(
      "Random-effect terms using `gr(..., by = ...)` are not supported.",
      call. = FALSE
    )
  }

  re_blocks <- unname(split(re_terms, re_terms$id))
  for (block in re_blocks) {
    if (length(unique(block$gn)) != 1L) {
      stop(
        "Linked `brms` random-effect blocks containing more than one ",
        "formula term are not supported.",
        call. = FALSE
      )
    }
  }

  fitted_covariance <- brms::VarCorr(model, summary = FALSE)
  model_frame <- stats::model.frame(model)
  blocks <- vector("list", length(re_blocks))

  for (i in seq_along(re_blocks)) {
    block <- re_blocks[[i]]
    # Keep stored names for VarCorr lookup and readable formula names for
    # matching against user-supplied terms.
    coefficient_names <- brms_readable_exchangeable_coefficients(
      block,
      model_frame
    )
    stored_coefficients <- coefficient_names$stored
    coefficients <- coefficient_names$readable
    stored_coefficients[stored_coefficients == "Intercept"] <- "(Intercept)"

    group <- block$group[[1L]]
    group_covariance <- fitted_covariance[[group]]
    if (is.null(group_covariance) || is.null(group_covariance$sd)) {
      stop(
        "Internal error: `brms` covariance draws were not found for a random-effect block.",
        call. = FALSE
      )
    }

    covariance_names <- colnames(group_covariance$sd)
    covariance_names[covariance_names == "Intercept"] <- "(Intercept)"
    if (anyDuplicated(covariance_names)) {
      stop(
        "Internal error: duplicated `brms` covariance names cannot be aligned to separate blocks.",
        call. = FALSE
      )
    }
    coefficient_index <- match(stored_coefficients, covariance_names)
    if (anyNA(coefficient_index)) {
      stop(
        "Internal error: `brms` covariance draws could not be aligned with their coefficients.",
        call. = FALSE
      )
    }

    sd_draws <- group_covariance$sd[, coefficient_index, drop = FALSE]
    if (is.null(group_covariance$cov)) {
      # Uncorrelated blocks store SD draws only; reconstruct diagonal
      # covariance draws.
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

    formula_rhs <- trimws(sub("^~", "", deparse1(block$form[[1L]])))
    bar <- if (isTRUE(block$cor[[1L]])) "|" else "||"
    blocks[[i]] <- list(
      group = group,
      coefficients = coefficients,
      correlated = isTRUE(block$cor[[1L]]),
      term = paste0("(", formula_rhs, " ", bar, " ", group, ")"),
      covariance = covariance_array
    )
  }
  return(list(backend = "brms", blocks = blocks))
}
