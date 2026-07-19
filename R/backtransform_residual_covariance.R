#' Recover member-level residual covariance from exchangeable random-effect blocks
#'
#' Back-transforms covariance matrices from paired shared and member-difference
#' random-effect blocks to the covariance structure of two exchangeable
#' members. For the model specification, derivation, and interpretation, see the
#' [exchangeable APIM vignette](https://pascal-kueng.github.io/interdep/articles/apim.html#exchangeable-residual-structure).
#'
#' @param model A fitted `glmmTMB` or single-response `brmsfit` model.
#' @param pairs `NULL` (default) for automatic block matching. Otherwise, supply
#'   one block-pair list or a list of block-pair lists. Each pair contains:
#'
#'   - `shared`: one character string containing the shared random-effect term
#'     copied from the fitted model formula or an equivalent selector (see
#'     Details), or `NULL` if the entire shared block was omitted when fitting;
#'   - `difference`: one character string containing the member-difference
#'     random-effect term or an equivalent selector, or `NULL` if the entire
#'     difference block was omitted;
#'   - `difference_indicator`: the exact name of the difference-indicator
#'     column used in `difference`. It is required when `difference` selects a
#'     block and optional when `difference = NULL`;
#'   - `shared_indicator`: the exact shared composition-indicator column,
#'     needed only for composition-specific blocks in mixed-dyad models. It
#'     defaults to `"1"`, meaning that every fitted row belongs to the pair and
#'     an ordinary intercept is the shared intercept coordinate.
#'
#'   At least one of `shared` and `difference` must select a fitted block.
#'
#' @details
#' Automatic matching recognizes exact `.i_diff_*_arbitrary` coefficient names
#' and first looks for the corresponding `.i_is_*` shared block. It requires
#' the two blocks to use the same grouping factor and the same underlying
#' terms. Most models fitted with `interdep`-generated columns therefore need
#' only:
#'
#' ```r
#' result <- interdep::exchangeable_rescov(model)
#' ```
#'
#' The shared block moves both members together; the member-difference block
#' moves them in opposite directions. The APIM vignette derives the resulting
#' member-level covariance.
#'
#' Supply `pairs` when automatic matching is ambiguous or when a model uses
#' custom indicators, multiple covariance levels, or deliberately omitted
#' blocks or terms. To specify one pair with a custom difference indicator:
#'
#' ```r
#' result <- interdep::exchangeable_rescov(
#'   model,
#'   pairs = list(
#'     shared = "(1 + time | coupleID)",
#'     difference =
#'       "(0 + hallelujah + I(hallelujah * time) || coupleID)",
#'     difference_indicator = "hallelujah"
#'   )
#' )
#' ```
#'
#' For multiple covariance levels, wrap the pairs in an outer list. For example,
#' in a Gaussian `glmmTMB` model fitted with `dispformula = ~ 0`, this call
#' recovers both the stable dyad-level random-intercept covariance and the
#' same-occasion partner residual covariance:
#'
#' ```r
#' result <- interdep::exchangeable_rescov(
#'   model,
#'   pairs = list(
#'     dyad = list(
#'       shared = "us(1 | coupleID)",
#'       difference = "us(0 + .i_diff_assumed_exchangeable_arbitrary | coupleID)",
#'       difference_indicator =
#'         ".i_diff_assumed_exchangeable_arbitrary"
#'     ),
#'     same_occasion = list(
#'       shared = "us(1 | coupleID:diaryday)",
#'       difference = "us(0 + .i_diff_assumed_exchangeable_arbitrary | coupleID:diaryday)",
#'       difference_indicator =
#'         ".i_diff_assumed_exchangeable_arbitrary"
#'     )
#'   )
#' )
#' ```
#'
#' The random-effect terms may be copied exactly from the model formula.
#' Equivalent backend syntax is also recognized, such as
#' `(1 + time | group)` and `us(1 + time | group)`, or
#' `(0 + x || group)` and `diag(0 + x | group)`. A custom difference-indicator
#' name is supplied literally. Difference slopes may be written in either
#' interaction order or as a simple product inside `I()`.
#'
#' When a difference block is supplied and the fitted model frame retains the
#' indicator columns, `difference_indicator` must assign `-1` and `+1` to the
#' two arbitrary member positions consistently within each dyad. For
#' composition-specific blocks, it must be zero where `shared_indicator` is
#' zero. A column omitted entirely from the fitted formula cannot be recovered
#' from either supported backend, so its coding cannot be checked.
#'
#' @section What omitted blocks and terms mean:
#' `exchangeable_rescov()` only describes constraints that were already imposed
#' when the model was fitted. It does not remove a block, set a variance to zero,
#' or otherwise constrain the supplied model.
#'
#' If a term occurs in only one selected block, the function represents the
#' missing coordinate as a structural zero:
#'
#' - A term present only in `shared` has no difference component, so the two
#'   members have identical random effects for that term.
#' - A term present only in `difference` has no shared component, so the two
#'   members have equal-magnitude, opposite-sign random effects for that term.
#'
#' Setting `difference = NULL` or `shared = NULL` makes the corresponding rule
#' apply to every term in the other block. `NULL` therefore means that the whole
#' block was absent from the fitted model; it must never be used merely to ignore
#' an existing block. The function warns whenever `NULL` is supplied. When
#' `difference = NULL` and `difference_indicator` is supplied, it also errors if
#' it can identify a compatible fitted difference block that contradicts the
#' claimed omission. See the constrained-block example in the
#' [exchangeable APIM vignette](https://pascal-kueng.github.io/interdep/articles/apim.html#fitted-constraints-and-omitted-blocks).
#'
#' @section Backend note:
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
#' @seealso The
#'   [exchangeable APIM vignette](https://pascal-kueng.github.io/interdep/articles/apim.html#exchangeable-residual-structure)
#'   for the model specification, covariance derivation, and constrained-block
#'   examples. Run `vignette("apim", package = "interdep")` to open the installed
#'   version.
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
      "The fitted model frame could not be recovered from `model`, so the ",
      "exchangeable coding cannot be validated. This is unexpected for a ",
      "supported model; please report an issue with a reproducible model and ",
      "your installed package versions.",
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

# For error messages printing blocks, we create a list of all
# available blocks
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
    is.call(expression) && # this is a function call (I)
      length(expression) == 2L && # the call has a function (I) and exactly one arg (idiff * x) is one arg
      identical(expression[[1L]], as.name("I")) # the function call is exactly I
  ) {
    product <- expression[[2L]]  # has the form idiff * time
    # check that it really HAS that form
    if (
      is.call(product) &&
        length(product) == 3L && # 3 terms, "idiff", "*", "x"
        identical(product[[1L]], as.name("*")) &&
        is.symbol(product[[2L]]) && # both other expression shoudl be simple var names
        is.symbol(product[[3L]])
    ) {
      # has form c('idiff', 'x')
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

# Check whether an indicator occurs anywhere in a random-effect block.
block_contains_indicator <- function(block, indicator) {
  for (coefficient in block$coefficients) {
    parsed <- parse_exchangeable_coefficient(coefficient)
    if (indicator %in% parsed$variables) {
      return(TRUE)
    }
  }
  return(FALSE)
}

# Split only formula interactions. Backticked symbols are returned as their
# exact column names, while expressions such as `log(time)` remain intact.
split_exchangeable_interaction <- function(coefficient) {
  expression <- tryCatch(
    str2lang(coefficient),
    error = function(e) NULL
  )
  if (is.null(expression)) {
    return(NULL)
  }

  split_parts <- function(x) {
    if (
      is.call(x) &&
        length(x) == 3L &&
        identical(x[[1L]], as.name(":"))
    ) {
      return(c(split_parts(x[[2L]]), split_parts(x[[3L]])))
    }
    if (is.symbol(x)) {
      return(as.character(x))
    }
    return(deparse1(x))
  }

  return(split_parts(expression))
}

# Remove the shared/difference indicator so both blocks use common term names.
exchangeable_underlying_terms <- function(coefficients, indicator = "1") {
  # Keep one normalized term per coefficient, in the same order as the
  # covariance matrix rows and columns.
  terms <- character(length(coefficients))

  # Determine the underlying intercept, slope, or interaction for each
  # coefficient.
  for (i in seq_along(coefficients)) {
    coefficient <- coefficients[[i]]

    # `indicator = "1"` denotes an ordinary shared random intercept. For
    # example, c("(Intercept)", "time:support") is parsed into character()
    # and c("time", "support") before normalization below.
    if (identical(indicator, "1")) {
      parts <- if (identical(coefficient, "(Intercept)")) {
        character()
      } else {
        split_exchangeable_interaction(coefficient)
      }
    } else {
      parsed <- parse_exchangeable_coefficient(coefficient)
      product <- parsed$literal_product

      # For I(idiff * time), `product` is c("idiff", "time"). Removing the
      # indicator therefore leaves the underlying term "time".
      if (!is.null(product) && sum(product == indicator) == 1L) {
        terms[[i]] <- product[product != indicator][[1L]]
        next
      }

      # For regular interaction syntax, "support:idiff:time" becomes
      # c("support", "idiff", "time").
      parts <- split_exchangeable_interaction(coefficient)
      # Uses of the indicator inside any other expression are not interpreted.
      if (
        is.null(parts) ||
        !indicator %in% parsed$variables ||
          sum(parts == indicator) != 1L
      ) {
        return(NULL)
      }
      parts <- parts[parts != indicator]
    }

    if (is.null(parts)) {
      return(NULL)
    }

    # The indicator alone maps to the intercept. Sorting makes
    # idiff:time:support and support:idiff:time equivalent.
    terms[[i]] <- if (length(parts) == 0L) {
      "(Intercept)"
    } else {
      paste(sort(parts), collapse = ":")
    }
  }

  # A covariance block cannot contain two coefficients that map to the same
  # term, such as idiff:time and I(idiff * time) both becoming "time".
  if (anyDuplicated(terms)) {
    duplicated_terms <- unique(terms[duplicated(terms)])
    collisions <- character(length(duplicated_terms))
    for (i in seq_along(duplicated_terms)) {
      term <- duplicated_terms[[i]]
      coefficient_labels <- paste0("`", coefficients[terms == term], "`")
      separator <- if (length(coefficient_labels) == 2L) " and " else ", "
      collisions[[i]] <- paste0(
        paste(coefficient_labels, collapse = separator),
        if (length(coefficient_labels) == 2L) " both" else " all",
        " represent the underlying term `", term, "`."
      )
    }
    stop(
      paste(collisions, collapse = " "),
      " Keep only one representation of each term in this random-effect block.",
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
      "A difference block contains more than one generated difference ",
      "indicator: `", paste(markers, collapse = "`, `"), "`. Put each ",
      "exchangeable composition in a separate random-effect block.",
      call. = FALSE
    )
  }
  if (length(markers) == 0L) {
    return(NA_character_)
  }
  return(markers[[1L]])
}

# Validate correct -1/+1 difference coding on the rows supported by the shared block.
validate_exchangeable_coding <- function(
  model_frame,
  idiff,
  shared_indicator,
  pair_label = NULL
) {
  pair_context <- if (is.null(pair_label)) "" else paste0(pair_label, ": ")

  # Matching can also be tested without fitted data. In that case, there is no
  # coding to validate.
  if (is.null(model_frame)) {
    return(invisible(NULL))
  }

  # If a selected difference block did not retain its source column, warn that
  # its coding cannot be verified. Wholly omitted difference blocks never call
  # this validator.
  if (!idiff %in% names(model_frame)) {
    warning(
      pair_context, "`", idiff,
      "` was not retained in the fitted model frame, so its coding could not ",
      "be verified. Before interpreting the result, verify that the fitted ",
      "model used unnormalised -1/+1 coding on the supported rows and zero ",
      "elsewhere.",
      call. = FALSE
    )
    return(invisible(NULL))
  }

  difference <- model_frame[[idiff]]

  # `shared_indicator = "1"` means every fitted row belongs to one exchangeable
  # composition. A named indicator instead marks the supported rows in a mixed
  # model, where idiff must be zero for all other dyad compositions.
  if (identical(shared_indicator, "1")) {
    shared <- rep(1, nrow(model_frame))
  } else if (shared_indicator %in% names(model_frame)) {
    shared <- model_frame[[shared_indicator]]
  } else {
    # Recover the support implied by idiff when the fitted model did not retain
    # the named shared indicator, but warn because it cannot be checked
    # independently.
    warning(
      pair_context, "`", shared_indicator,
      "` was not retained in the fitted model frame, so its support could not ",
      "be checked. Verify that it was coded 1 exactly where `abs(", idiff,
      ") == 1` and 0 elsewhere.",
      call. = FALSE
    )
    shared <- if (is.numeric(difference)) abs(difference) else difference
  }
  if (is.logical(shared)) {
    shared <- as.numeric(shared)
  }

  if (!is.numeric(difference) || !is.numeric(shared) ||
      anyNA(difference) || anyNA(shared)) {
    column_names <- paste0("`", idiff, "`")
    coding_requirement <- paste0(
      "Code `", idiff, "` as -1/+1 before fitting."
    )
    if (!identical(shared_indicator, "1")) {
      column_names <- paste0(column_names, " and `", shared_indicator, "`")
      coding_requirement <- paste0(
        "Code `", idiff, "` as -1/0/+1 and `", shared_indicator,
        "` as 0/1 before fitting."
      )
    }
    stop(
      pair_context, column_names,
      " must be complete numeric columns in the fitted data. ",
      coding_requirement,
      call. = FALSE
    )
  }

  # Valid mixed-composition coding looks like shared = c(1, 1, 0, 0) and
  # difference = c(-1, 1, 0, 0). The absolute difference must equal the shared
  # indicator so that the selected shared and difference blocks refer to the
  # same rows and therefore the same dyad composition.
  valid_coding <- all(difference %in% c(-1, 0, 1)) &&
    all(shared %in% c(0, 1)) &&
    all(abs(difference) == shared)
  if (!valid_coding) {
    if (identical(shared_indicator, "1")) {
      stop(
        pair_context, "`", idiff,
        "` must use -1/+1 coding on every fitted row because ",
        "`shared_indicator = \"1\"` means that every row is supported. ",
        "Correct the coding and refit the model.",
        call. = FALSE
      )
    }
    stop(
      pair_context, "`", idiff, "` and `", shared_indicator,
      "` have incompatible coding. `", shared_indicator,
      "` must be 0/1; `", idiff, "` must use -1/+1 coding where `",
      shared_indicator, "` is 1 and zero where it is 0. Correct the coding ",
      "and refit the model.",
      call. = FALSE
    )
  }

  # Both arbitrary member positions must occur among the supported fitted rows;
  # otherwise the difference coordinate cannot represent both dyad members.
  supported <- shared == 1
  if (!any(difference[supported] == -1) ||
      !any(difference[supported] == 1)) {
    stop(
      pair_context, "`", idiff,
      "` must contain both -1 and +1 on its supported fitted ",
      "rows. Check the coding and whether fitted-row filtering removed one ",
      "member position, then refit the model.",
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
    shared_group <- blocks[[shared_block_index]]$group
    difference_group <- blocks[[difference_block_index]]$group
    stop(
      "The selected shared block groups by `", shared_group,
      "`, but the selected difference block groups by `", difference_group,
      "`; both blocks must use the same grouping factor. Select a shared and ",
      "difference block from the same grouping level.",
      call. = FALSE
    )
  }

  shared_terms <- character()
  if (!is.na(shared_block_index)) {
    shared_block <- blocks[[shared_block_index]]
    if (!is.null(idiff) && block_contains_indicator(shared_block, idiff)) {
      stop(
        "The selected shared block contains the difference indicator `", idiff,
        "`. Select the block that represents shared random effects instead.",
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
        "\"` must identify every coefficient in the selected shared block. ",
        "Use `", shared_indicator, "` alone for its intercept and `",
        shared_indicator, ":term` for its slopes.",
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
        "The selected difference block contains the shared indicator `",
        shared_indicator, "`. ",
        "Select the block that represents difference random effects instead.",
        call. = FALSE
      )
    }
    difference_terms <- exchangeable_underlying_terms(
      difference_block$coefficients,
      idiff
    )
    if (is.null(difference_terms)) {
      stop(
        "Difference indicator `", idiff,
        "` must identify every coefficient in the selected difference block. ",
        "For slopes, use `", idiff, ":term` or `I(", idiff, " * term)`.",
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
    difference_indicator = idiff,
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
        "block. For slopes, use `", idiff, ":term` or `I(", idiff,
        " * term)`.",
        inventory,
        call. = FALSE
      )
    }
    difference_block_indices <- c(difference_block_indices, i)
  }

  if (length(difference_block_indices) == 0L) {
    stop(
      "No difference block contains `", idiff, "`.",
      " Check the indicator name, or supply `pairs` explicitly if the model ",
      "uses custom block definitions.",
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
        " Supply `pairs` explicitly to select the intended blocks or to match ",
        "partial term sets.",
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
      " Supply `pairs` explicitly if the model uses custom ",
      "difference-indicator names or unequal shared and difference term sets.",
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
    stop(
      "A shared block matched more than one difference block. Supply `pairs` ",
      "explicitly so that each shared block is assigned only once.",
      call. = FALSE
    )
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
  required_names <- c("shared", "difference")
  allowed_names <- c(
    required_names,
    "difference_indicator",
    "shared_indicator"
  )
  is_nonempty_string <- function(x) {
    is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
  }
  pair_field_reference <- function(pair_label, field) {
    paste0(substr(pair_label, 1L, nchar(pair_label) - 1L), "$", field, "`")
  }
  format_fields <- function(fields) {
    paste0("`", fields, "`", collapse = ", ")
  }

  if (!is.list(pairs) || length(pairs) == 0L) {
    stop(
      "`pairs` must be one named block pair or a list of named block pairs.",
      call. = FALSE
    )
  }

  pair_names <- names(pairs)
  has_top_level_names <- !is.null(pair_names) && any(nzchar(pair_names))
  all_values_are_lists <- all(vapply(pairs, is.list, logical(1L)))
  looks_like_single_pair <- has_top_level_names && !all_values_are_lists

  if (looks_like_single_pair) {
    pair_specs <- list(pairs)
    pair_labels <- "`pairs`"
  } else {
    pair_specs <- pairs
    pair_labels <- paste0("`pairs[[", seq_along(pair_specs), "]]`")
    if (!is.null(names(pair_specs))) {
      named <- nzchar(names(pair_specs))
      pair_labels[named] <- paste0(
        "`pairs[[\"", names(pair_specs)[named], "\"]]`"
      )
    }
  }

  for (i in seq_along(pair_specs)) {
    pair <- pair_specs[[i]]
    pair_label <- pair_labels[[i]]
    if (!is.list(pair)) {
      stop(
        pair_label, " must be a named list describing one block pair.",
        call. = FALSE
      )
    }
    if (is.null(names(pair)) || any(!nzchar(names(pair)))) {
      stop(
        pair_label, " must be a named list with fields `shared` ",
        "and `difference`, plus `difference_indicator` when a difference ",
        "block is supplied. `shared_indicator` is optional.",
        call. = FALSE
      )
    }
    if (anyDuplicated(names(pair))) {
      duplicated_fields <- unique(names(pair)[duplicated(names(pair))])
      stop(
        pair_label, " contains duplicated field",
        if (length(duplicated_fields) > 1L) "s " else " ",
        format_fields(duplicated_fields), ".",
        call. = FALSE
      )
    }

    unknown_fields <- setdiff(names(pair), allowed_names)
    if (length(unknown_fields) > 0L) {
      stop(
        pair_label, " contains unknown field",
        if (length(unknown_fields) > 1L) "s " else " ",
        format_fields(unknown_fields), ". Allowed fields are ",
        format_fields(allowed_names), ".",
        call. = FALSE
      )
    }

    missing_fields <- setdiff(required_names, names(pair))
    if (length(missing_fields) > 0L) {
      stop(
        pair_label, " is missing required field",
        if (length(missing_fields) > 1L) "s " else " ",
        format_fields(missing_fields), ".",
        call. = FALSE
      )
    }

    if (
      !is.null(pair$difference) &&
        (
          !"difference_indicator" %in% names(pair) ||
            is.null(pair$difference_indicator)
        )
    ) {
      stop(
        pair_label, " is missing required field `difference_indicator`. ",
        "Set it to the exact name of the -1/+1 difference-indicator ",
        "column used in the selected difference block, for example ",
        "`difference_indicator = \"hallelujah\"`.",
        call. = FALSE
      )
    }

    if (!"shared_indicator" %in% names(pair)) {
      pair$shared_indicator <- "1"
    }

    if (
      !is.null(pair$difference_indicator) &&
        !is_nonempty_string(pair$difference_indicator)
    ) {
      stop(
        pair_field_reference(pair_label, "difference_indicator"),
        " must be one non-empty string giving an exact column name.",
        call. = FALSE
      )
    }
    if (!is_nonempty_string(pair$shared_indicator)) {
      stop(
        pair_field_reference(pair_label, "shared_indicator"),
        " must be one non-empty string giving an exact column name.",
        call. = FALSE
      )
    }
    if (identical(pair$difference_indicator, "1")) {
      stop(
        pair_field_reference(pair_label, "difference_indicator"),
        " must name a difference-indicator column; ",
        "use `shared_indicator = \"1\"` for an ordinary shared intercept.",
        call. = FALSE
      )
    }
    if (
      !is.null(pair$difference_indicator) &&
        identical(pair$difference_indicator, pair$shared_indicator)
    ) {
      stop(
        pair_field_reference(pair_label, "difference_indicator"), " and ",
        pair_field_reference(pair_label, "shared_indicator"),
        " must name different columns.",
        call. = FALSE
      )
    }

    for (field in c("shared", "difference")) {
      selector <- pair[[field]]
      if (!is.null(selector) && !is_nonempty_string(selector)) {
        stop(
          pair_field_reference(pair_label, field),
          " must be one random-effect term selector copied from the model ",
          "formula, written in an equivalent syntax, or `NULL`.",
          call. = FALSE
        )
      }
    }
    if (is.null(pair$shared) && is.null(pair$difference)) {
      stop(pair_label,
        " cannot set both `shared` and `difference` to `NULL`; supply at ",
        "least one fitted random-effect block.",
        call. = FALSE
      )
    }
    pair_specs[[i]] <- pair
  }
  attr(pair_specs, "pair_labels") <- pair_labels
  return(pair_specs)
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
      selector_label, " does not match an extracted random-effect block. Copy ",
      "the intended term from the available blocks below.",
      block_lookup$inventory,
      call. = FALSE
    )
  }
  if (length(matches) > 1L) {
    stop(
      selector_label,
      " matches more than one random-effect block and cannot be selected ",
      "uniquely. Refit without duplicate equivalent random-effect blocks.",
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

with_exchangeable_pair_error_context <- function(code, pair_label) {
  tryCatch(
    force(code),
    error = function(error) {
      stop(
        pair_label, ": ", conditionMessage(error),
        call. = FALSE
      )
    }
  )
}

match_one_supplied_exchangeable_pair <- function(
  blocks,
  pair,
  pair_label,
  block_lookup,
  model_frame = NULL
) {
  shared_block_index <- resolve_exchangeable_block_selector(
    pair$shared,
    paste0(substr(pair_label, 1L, nchar(pair_label) - 1L), "$shared`"),
    block_lookup
  )
  difference_block_index <- resolve_exchangeable_block_selector(
    pair$difference,
    paste0(substr(pair_label, 1L, nchar(pair_label) - 1L), "$difference`"),
    block_lookup
  )

  selected_block_indices <- c(shared_block_index, difference_block_index)
  selected_block_indices <- selected_block_indices[
    !is.na(selected_block_indices)
  ]

  matched_pair <- with_exchangeable_pair_error_context(
    build_exchangeable_pair(
      blocks,
      shared_block_index,
      difference_block_index,
      pair$difference_indicator,
      pair$shared_indicator
    ),
    pair_label
  )

  present_block_index <- selected_block_indices[[1L]]
  group <- blocks[[present_block_index]]$group

  # `NULL` declares that the corresponding block was not fitted. Catch clear
  # contradictions rather than silently inserting structural zeros.
  if (
    is.na(difference_block_index) &&
      !is.null(pair$difference_indicator)
  ) {
    potential_block_indices <- with_exchangeable_pair_error_context(
      find_potential_exchangeable_blocks(
        blocks,
        group,
        pair$difference_indicator,
        overlap_terms = matched_pair$underlying_terms
      ),
      pair_label
    )
    potential_block_indices <- setdiff(
      potential_block_indices,
      selected_block_indices
    )
    if (length(potential_block_indices) > 0L) {
      difference_reference <- paste0(
        substr(pair_label, 1L, nchar(pair_label) - 1L),
        "$difference`"
      )
      stop(
        difference_reference,
        " is `NULL`, but a compatible fitted block exists: `",
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
    potential_block_indices <- with_exchangeable_pair_error_context(
      find_potential_exchangeable_blocks(
        blocks,
        group,
        pair$shared_indicator,
        exclude_indicator = pair$difference_indicator,
        overlap_terms = matched_pair$underlying_terms
      ),
      pair_label
    )
    potential_block_indices <- setdiff(
      potential_block_indices,
      selected_block_indices
    )
    if (length(potential_block_indices) > 0L) {
      shared_reference <- paste0(
        substr(pair_label, 1L, nchar(pair_label) - 1L),
        "$shared`"
      )
      stop(
        shared_reference,
        " is `NULL`, but a compatible fitted block exists: `",
        paste(
          block_lookup$term_labels[potential_block_indices],
          collapse = "`, `"
        ),
        "`. Supply that block instead of `NULL`.",
        call. = FALSE
      )
    }
  }

  if (!is.na(difference_block_index)) {
    validate_exchangeable_coding(
      model_frame,
      pair$difference_indicator,
      pair$shared_indicator,
      pair_label
    )
  }
  return(matched_pair)
}

match_supplied_exchangeable_residual_blocks <- function(
  blocks,
  pairs,
  model_frame = NULL
) {
  pairs <- normalize_supplied_exchangeable_pairs(pairs)
  pair_labels <- attr(pairs, "pair_labels")
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
  names(matched_pairs) <- names(pairs)
  for (i in seq_along(pairs)) {
    matched_pairs[[i]] <- match_one_supplied_exchangeable_pair(
      blocks,
      pairs[[i]],
      pair_labels[[i]],
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
  paired_block_indices <- paired_block_indices[!is.na(paired_block_indices)]
  duplicated_block_indices <- unique(
    paired_block_indices[duplicated(paired_block_indices)]
  )
  if (length(duplicated_block_indices) > 0L) {
    reused_blocks <- paste0(
      "`", term_labels[duplicated_block_indices], "`",
      collapse = ", "
    )
    reused_pair_assignments <- vapply(
      duplicated_block_indices,
      function(block_index) {
        pair_indices <- which(vapply(
          matched_pairs,
          function(pair) {
            block_index %in% c(
              pair$shared_block_index,
              pair$difference_block_index
            )
          },
          logical(1L)
        ))
        paste0(
          "`", term_labels[[block_index]], "` in ",
          paste(pair_labels[pair_indices], collapse = ", ")
        )
      },
      character(1L)
    )
    stop(
      "Each random-effect block can occur in only one supplied pair. ",
      "Reused block", if (length(duplicated_block_indices) > 1L) "s" else "",
      ": ", reused_blocks, ". Remove each reused block from all but one pair.",
      " Pair assignments: ", paste(reused_pair_assignments, collapse = "; "),
      ".",
      call. = FALSE
    )
  }

  omitted_block_warnings <- character()
  for (i in seq_along(pairs)) {
    if (is.null(pairs[[i]]$difference)) {
      omitted_block_warnings <- c(
        omitted_block_warnings,
        paste0(
          "You set ",
          paste0(substr(pair_labels[[i]], 1L, nchar(pair_labels[[i]]) - 1L),
            "$difference`"),
          " to `NULL`. Ensure that the ",
          "fitted model actually excluded the entire difference random-effect ",
          "block; otherwise, the back-transformation is not meaningful. Here, ",
          "`NULL` tells `exchangeable_rescov()` that the fitted model constrained ",
          "this block's variances and covariances to zero; the function does not ",
          "impose this constraint. For a difference block, this means that the ",
          "two members have identical random effects for these terms."
        )
      )
    }
    if (is.null(pairs[[i]]$shared)) {
      omitted_block_warnings <- c(
        omitted_block_warnings,
        paste0(
          "You set ",
          paste0(substr(pair_labels[[i]], 1L, nchar(pair_labels[[i]]) - 1L),
            "$shared`"),
          " to `NULL`. Ensure that the fitted ",
          "model actually excluded the entire shared random-effect block; ",
          "otherwise, the back-transformation is not meaningful. Here, `NULL` ",
          "tells `exchangeable_rescov()` that the fitted model constrained this ",
          "block's variances and covariances to zero; the function does not ",
          "impose this constraint. For a shared block, this means that the two ",
          "members have equal-magnitude, opposite-sign random effects for these ",
          "terms."
        )
      )
    }
  }
  if (length(omitted_block_warnings) > 0L) {
    warning(
      paste(omitted_block_warnings, collapse = "\n"),
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
      "Internal error: stored `glmmTMB` random-effect blocks could not be ",
      "aligned. This is unexpected for a supported model; please report an ",
      "issue with a reproducible model and the installed versions of ",
      "`interdep` and `glmmTMB`.",
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
        "Internal error: a `glmmTMB` covariance block could not be aligned ",
        "with its coefficients. This is unexpected for a supported model; ",
        "please report an issue with a reproducible model and the installed ",
        "versions of `interdep` and `glmmTMB`.",
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
      "Random effects for distributional or nonlinear parameters were ",
      "ignored; `exchangeable_rescov()` only processes ordinary response-mean ",
      "random effects.",
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
      "Random-effect terms using `gr(..., by = ...)` are not supported. Refit ",
      "the exchangeable blocks without `by` before using ",
      "`exchangeable_rescov()`.",
      call. = FALSE
    )
  }

  re_blocks <- unname(split(re_terms, re_terms$id))
  for (block in re_blocks) {
    if (length(unique(block$gn)) != 1L) {
      stop(
        "Linked `brms` random-effect blocks containing more than one ",
        "formula term are not supported. Fit the shared and difference terms ",
        "as separate random-effect blocks, using different `| ID |` labels or ",
        "no shared ID.",
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
        "Internal error: `brms` covariance draws were not found for a ",
        "random-effect block. This is unexpected for a supported model; please ",
        "report an issue with a reproducible model and the installed versions ",
        "of `interdep` and `brms`.",
        call. = FALSE
      )
    }

    covariance_names <- colnames(group_covariance$sd)
    covariance_names[covariance_names == "Intercept"] <- "(Intercept)"
    if (anyDuplicated(covariance_names)) {
      stop(
        "Internal error: duplicated `brms` covariance names cannot be aligned ",
        "to separate blocks. This is unexpected for a supported model; please ",
        "report an issue with a reproducible model and the installed versions ",
        "of `interdep` and `brms`.",
        call. = FALSE
      )
    }
    coefficient_index <- match(stored_coefficients, covariance_names)
    if (anyNA(coefficient_index)) {
      stop(
        "Internal error: `brms` covariance draws could not be aligned with ",
        "their coefficients. This is unexpected for a supported model; please ",
        "report an issue with a reproducible model and the installed versions ",
        "of `interdep` and `brms`.",
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
