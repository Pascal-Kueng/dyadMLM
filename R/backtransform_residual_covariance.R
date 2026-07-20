# Public interface ------------------------------------------------------------

#' Recover member-level residual covariance from exchangeable random-effect blocks
#'
#' Back-transforms covariance matrices from paired shared and member-difference
#' random-effect blocks to the covariance structure of two exchangeable
#' members. The result is on the fitted random effects' linear-predictor scale.
#' In non-Gaussian models, it therefore describes a Gaussian latent covariance,
#' not response-scale residual covariance. For the model specification,
#' derivation, and interpretation, see the
#' [exchangeable APIM vignette](https://pascal-kueng.github.io/dyadMLM/articles/apim.html#exchangeable-residual-structure).
#'
#' @param model A fitted `glmmTMB` or single-response `brmsfit` model.
#' @param pairs `NULL` (default) for automatic block matching. Otherwise, supply
#'   one block-pair specification or a list of block-pair specifications. Each
#'   pair contains:
#'
#'   - `shared`: a single string naming the shared random-effect term
#'     copied from the fitted model formula or an equivalent selector (see
#'     Details), or `NULL` if the entire shared block was omitted when fitting;
#'   - `difference`: a single string naming the member-difference random-effect
#'     term or an equivalent selector, or `NULL` if the entire difference block
#'     was omitted;
#'   - `difference_indicator`: the exact name of the difference-indicator
#'     column used in `difference`. It is required when `difference` selects a
#'     block and optional when `difference = NULL`;
#'   - `shared_indicator`: the exact shared composition-indicator column,
#'     needed only for composition-specific blocks in mixed-dyad models. It
#'     defaults to `"1"`, meaning that every fitted row belongs to the pair and
#'     an ordinary intercept is the shared intercept coordinate.
#'
#' @details
#' Automatic matching recognizes exact `.dy_diff_*_arbitrary` coefficient names
#' and first looks for the corresponding `.dy_is_*` shared block. It requires
#' the two blocks to use the same grouping factor and the same underlying
#' terms. Most models fitted with `dyadMLM`-generated columns therefore need
#' only:
#'
#' ```r
#' result <- dyadMLM::exchangeable_rescov(model)
#' print(result)
#' ```
#'
#' Supply `pairs` when automatic matching is ambiguous or when a model uses
#' custom indicators, multiple covariance levels, or deliberately omitted
#' blocks or terms. To specify one pair with a custom difference indicator:
#'
#' ```r
#' result <- dyadMLM::exchangeable_rescov(
#'   model,
#'   pairs = list(
#'     shared = "(1 + time | coupleID)",
#'     difference = "(0 + my_diff + I(my_diff * time) | coupleID)",
#'     difference_indicator = "my_diff"
#'   )
#' )
#' ```
#'
#' For multiple covariance levels, wrap the pairs in an outer list. For example,
#' in a Gaussian `glmmTMB` model fitted with `dispformula = ~ 0`, this call
#' recovers both a stable dyad-level covariance with an omitted difference
#' time slope and the same-occasion partner residual covariance:
#'
#' ```r
#' result <- dyadMLM::exchangeable_rescov(
#'   model,
#'   pairs = list(
#'     dyad = list(
#'       shared = "(1 + diaryday | coupleID)",
#'       difference = "(0 + .dy_diff_assumed_exchangeable_arbitrary | coupleID)",
#'       difference_indicator =
#'         ".dy_diff_assumed_exchangeable_arbitrary"
#'     ),
#'     same_occasion = list(
#'       shared = "(1 | coupleID:diaryday)",
#'       difference = "(0 + .dy_diff_assumed_exchangeable_arbitrary | coupleID:diaryday)",
#'       difference_indicator =
#'         ".dy_diff_assumed_exchangeable_arbitrary"
#'     )
#'   )
#' )
#' ```
#'
#' At the dyad level, the fitted model includes a shared time slope but no
#' difference time slope. Thus, the two members' time random effects are
#' identical at this level, with correlation `+1` whenever the shared slope
#' variance is non-zero; at zero variance, the correlation is undefined.
#' Covariances involving the diary-day slope are therefore supplied entirely by
#' the shared block.
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
#' zero.
#'
#' @section What omitted blocks and terms mean:
#' `exchangeable_rescov()` only describes constraints that were already imposed
#' when the model was fitted. It does not remove a block, set a variance to zero,
#' or otherwise constrain the supplied model. Describe only the structure that
#' was actually fitted.
#'
#' If a term occurs in only one selected block, the function represents the
#' missing coordinate as a structural zero:
#'
#' - A term present only in `shared` has no difference component, so the two
#'   members have identical random effects for that term.
#' - A term present only in `difference` has no shared component, so the two
#'   members have equal-magnitude, opposite-sign random effects for that term.
#'
#' Setting `difference = NULL` or `shared = NULL` applies the corresponding rule
#' to the entire omitted block. This is valid only when that block is truly
#' absent from the fitted model. Do not use `NULL` merely to ignore an existing
#' block; the resulting back-transformation would be incorrect.
#'
#' See the constrained-block example in the
#' [exchangeable APIM vignette](https://pascal-kueng.github.io/dyadMLM/articles/apim.html#fitted-constraints-and-omitted-blocks).
#'
#' @section Backend note:
#' In `brms`, cross-sectional and same-occasion partner dependence can be
#' represented directly with
#' `unstr(time = member_position, gr = residual_group)`. With Gaussian
#' outcomes, `sigma ~ 1` supplies the common residual scale. Non-Gaussian
#' families have no `sigma` parameter here; `unstr()` instead estimates a
#' common latent residual scale and correlation on the linear-predictor scale.
#' Here,
#' `member_position` identifies the same two arbitrary positions within every
#' group, and `residual_group` identifies dyads in cross-sectional data or
#' dyad-occasions in longitudinal data. This direct specification applies when
#' one covariance structure is sufficient. Separate composition-specific
#' `unstr()` structures for mixed dyad types are not currently supported in a
#' standard single-response `brms` model. For Gaussian mixed-dyad residual
#' covariance, use `glmmTMB`. Shared/difference blocks remain relevant for
#' higher-level random effects and can represent latent link-scale covariance
#' in non-Gaussian models.
#'
#' @return An `exchangeable_rescov` object: a named list with one element per
#'   matched block pair. Each element contains the member-level
#'   variance-covariance matrix in `varcov` and its standard-deviation/correlation
#'   representation in `sdcor`, with standard deviations on the diagonal and
#'   correlations off the diagonal. Names reproduce the matched random-effect
#'   terms. For `glmmTMB`, `varcov` and `sdcor` are matrices. For `brms`, they
#'   are posterior-draw by coefficient by coefficient arrays.
#'
#' @seealso The
#'   [exchangeable APIM vignette](https://pascal-kueng.github.io/dyadMLM/articles/apim.html#exchangeable-residual-structure)
#'   for the model specification, covariance derivation, and constrained-block
#'   example. Run `vignette("apim", package = "dyadMLM")` to open the installed
#'   version.
#'
#' @export
exchangeable_rescov <- function(model, pairs = NULL) {
  # 1. Normalize backend-specific random-effect blocks and covariance estimates.
  extracted <- extract_exchangeable_residual_blocks(model)

  # 2. Recover the fitted rows so indicator coding can be checked.
  model_frame <- tryCatch(
    stats::model.frame(model),
    error = function(e) NULL
  )
  if (!is.data.frame(model_frame)) {
    stop(
      "The fitted model frame could not be recovered from `model`, so the ",
      "exchangeable coding cannot be validated. This is unexpected for a ",
      "supported model. Please report an issue on GitHub with a reproducible ",
      "model and your installed package versions.",
      call. = FALSE
    )
  }

  # 3. Match each shared block to its member-difference block.
  if (is.null(pairs)) {
    matched_pairs <- match_exchangeable_residual_blocks(
      extracted$blocks,
      model_frame
    )
  } else {
    matched_pairs <- match_supplied_exchangeable_residual_blocks(
      extracted$blocks,
      pairs,
      model_frame
    )
  }

  # 4. Flag structures that may act as residual covariance because their
  # grouping units contain no more than two fitted observations.
  warn_about_exchangeable_residual_level(
    extracted,
    matched_pairs
  )

  # 5. Back-transform every matched block pair independently. Internally,
  # both backends use estimate/draw x coefficient x coefficient arrays.
  results <- vector("list", length(matched_pairs))
  result_names <- character(length(matched_pairs))
  has_undefined_correlations <- FALSE # needed for warning

  for (i in seq_along(matched_pairs)) {
    pair <- matched_pairs[[i]]
    aligned <- align_exchangeable_pair_covariances(
      extracted$blocks,
      pair
    )
    varcov <- backtransform_exchangeable_covariances(
      aligned,
      pair$underlying_terms
    )
    sdcor <- covariance_array_to_sdcor(varcov)

    # if ANY loop finds one, this turns TRUE and stays TRUE
    has_undefined_correlations <- has_undefined_correlations || anyNA(sdcor)

    # glmmTMB contributes one point estimate. brms keeps the leading posterior-
    # draw dimension so its uncertainty is not discarded.
    if (identical(extracted$backend, "glmmTMB")) {
      varcov <- varcov[1L, , , drop = TRUE]
      sdcor <- sdcor[1L, , , drop = TRUE]
    }
    results[[i]] <- list(varcov = varcov, sdcor = sdcor)

    shared_term <- if (is.na(pair$shared_block_index)) {
      "<omitted>"
    } else {
      extracted$blocks[[pair$shared_block_index]]$term
    }
    difference_term <- if (is.na(pair$difference_block_index)) {
      "<omitted>"
    } else {
      extracted$blocks[[pair$difference_block_index]]$term
    }
    result_names[[i]] <- paste0(
      "shared: ", shared_term,
      "; difference: ", difference_term
    )
  }

  names(results) <- result_names
  if (has_undefined_correlations) {
    warning(
      "Some correlations in `sdcor` are `NA` because the corresponding ",
      "random-effect standard deviation is zero.",
      call. = FALSE
    )
  }
  class(results) <- c("exchangeable_rescov", "list")
  return(results)
}

#' Print recovered exchangeable residual covariance
#'
#' @param x An object returned by [exchangeable_rescov()].
#' @param what Which representation to print: `"both"` (default), `"varcov"`,
#'   or `"sdcor"`.
#' @param ... Additional arguments passed to [print()] when printing matrices.
#'
#' @return `x`, invisibly.
#'
#' @keywords internal
#'
#' @export
print.exchangeable_rescov <- function(
  x,
  what = c("both", "varcov", "sdcor"),
  ...
) {
  what <- match.arg(what)
  components <- if (identical(what, "both")) {
    c("varcov", "sdcor")
  } else {
    what
  }

  title <- if (length(x) == 1L) {
    "Exchangeable residual covariance"
  } else {
    paste0("Exchangeable residual covariances (", length(x), " block pairs)")
  }
  cat(title, "\n", sep = "")

  for (i in seq_along(x)) {
    if (length(x) > 1L) {
      cat("\nPair ", i, "\n", sep = "")
    } else {
      cat("\n")
    }

    # Result names store both fitted terms on one line. Split only for display;
    # the underlying list name and access paths remain unchanged.
    pair_label <- sub("^shared: ", "Shared:     ", names(x)[[i]])
    pair_label <- sub(
      "; difference: ",
      "\nDifference: ",
      pair_label,
      fixed = TRUE
    )
    cat(pair_label, "\n", sep = "")

    for (component in components) {
      heading <- if (identical(component, "varcov")) {
        "Variance-covariance:"
      } else {
        "Standard deviations and correlations:"
      }
      cat("\n", heading, "\n", sep = "")

      value <- x[[i]][[component]]
      if (is.matrix(value)) {
        print(value, ...)
      } else {
        # brms results retain every posterior draw. Avoid printing thousands of
        # matrices; users can extract this array or summarize it explicitly.
        dimensions <- dim(value)
        cat(
          "<", dimensions[[1L]], " posterior draws x ",
          dimensions[[2L]], " coefficients x ", dimensions[[3L]],
          " coefficients>\n",
          "Extract with `x[[", i, "]]$", component,
          "` to inspect the draw array.\n",
          sep = ""
        )
      }
    }
  }
  invisible(x)
}

# Backend dispatch ------------------------------------------------------------

#' Extract exchangeable random-effect blocks from a fitted model
#'
#' Normalizes the random-effect coefficients and fitted covariance parameters
#' needed by [exchangeable_rescov()] while keeping backend-specific work in two
#' small adapters.
#'
#' @param model A fitted model. Supported classes are `glmmTMB` and `brmsfit`.
#'
#' @return A list containing the model `backend`, one normalized record per
#'   random-effect block, and one grouping-factor ID per fitted row.
#'   Every block record contains `group`, `coefficients`, `correlated`, `term`,
#'   and an estimate/draw-by-coefficients covariance array.
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

# Parsing and validation helpers ---------------------------------------------

# Format the extracted blocks so selection errors show users what is available.
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

# Parse a coefficient without evaluating it. In addition to all variable names,
# recognize the exact form `I(a * b)` because it represents one literal product.
parse_exchangeable_coefficient <- function(coefficient) {
  # 1. Convert the printed coefficient to a language object without evaluating
  # it. Invalid expressions simply cannot be interpreted for matching.
  parsed_expression <- tryCatch(
    str2lang(coefficient),
    error = function(e) NULL
  )
  if (is.null(parsed_expression)) {
    return(list(variables = character(), literal_product = NULL))
  }

  # 2. Recognize only I(symbol * symbol), for example I(idiff * time).
  literal_product <- NULL
  is_I_call <- is.call(parsed_expression) &&
    length(parsed_expression) == 2L &&
    identical(parsed_expression[[1L]], as.name("I"))

  if (is_I_call) {
    product_call <- parsed_expression[[2L]]
    is_two_symbol_product <- is.call(product_call) &&
      length(product_call) == 3L &&
      identical(product_call[[1L]], as.name("*")) &&
      is.symbol(product_call[[2L]]) &&
      is.symbol(product_call[[3L]])

    if (is_two_symbol_product) {
      literal_product <- c(
        as.character(product_call[[2L]]),
        as.character(product_call[[3L]])
      )
    }
  }

  # 3. Retain every referenced variable for general indicator detection, plus
  # the optional literal product for the special I(a * b) matching rule.
  return(list(
    variables = all.vars(parsed_expression),
    literal_product = literal_product
  ))
}

# Check whether an indicator occurs anywhere in a random-effect block.
block_contains_indicator <- function(block, indicator) {
  for (coefficient in block$coefficients) {
    parsed_coefficient <- parse_exchangeable_coefficient(coefficient)
    if (indicator %in% parsed_coefficient$variables) {
      return(TRUE)
    }
  }
  return(FALSE)
}

# Split only formula interactions. Backticked symbols are returned as their
# exact column names, while expressions such as `log(time)` remain intact.
split_exchangeable_interaction <- function(coefficient) {
  parsed_expression <- tryCatch(
    str2lang(coefficient),
    error = function(e) NULL
  )
  if (is.null(parsed_expression)) {
    return(NULL)
  }

  flatten_interaction_parts <- function(x) {
    if (
      is.call(x) &&
        length(x) == 3L &&
        identical(x[[1L]], as.name(":"))
    ) {
      return(c(
        flatten_interaction_parts(x[[2L]]),
        flatten_interaction_parts(x[[3L]])
      ))
    }
    if (is.symbol(x)) {
      return(as.character(x))
    }
    return(deparse1(x))
  }

  return(flatten_interaction_parts(parsed_expression))
}

# Remove the shared/difference indicator so both blocks use common term names.
exchangeable_underlying_terms <- function(coefficients, indicator = "1") {
  # Keep one normalized term per coefficient, preserving the covariance-matrix
  # row and column order. `NULL` means the coefficients could not all be mapped
  # under the requested indicator convention.
  terms <- character(length(coefficients))

  # 1. Interpret each coefficient as an ordinary shared term, a literal
  # I(indicator * term) product, or a formula interaction.
  for (i in seq_along(coefficients)) {
    coefficient <- coefficients[[i]]

    # `indicator = "1"` denotes an ordinary shared block, whose intercept is
    # `(Intercept)`. For example, c("(Intercept)", "time:support") is parsed
    # into character() and c("time", "support") before normalization below.
    if (identical(indicator, "1")) {
      term_parts <- if (identical(coefficient, "(Intercept)")) {
        character()
      } else {
        split_exchangeable_interaction(coefficient)
      }
    } else {
      parsed_coefficient <- parse_exchangeable_coefficient(coefficient)
      literal_product <- parsed_coefficient$literal_product

      if (!is.null(literal_product) &&
          sum(literal_product == indicator) == 1L) {
        # I(idiff * time) becomes c("idiff", "time").
        term_parts <- literal_product
      } else {
        # support:idiff:time becomes c("support", "idiff", "time"). Uses of
        # the indicator inside any other expression are not interpreted.
        term_parts <- split_exchangeable_interaction(coefficient)
        if (
          is.null(term_parts) ||
            !indicator %in% parsed_coefficient$variables ||
            sum(term_parts == indicator) != 1L
        ) {
          return(NULL)
        }
      }
      term_parts <- term_parts[term_parts != indicator]
    }

    if (is.null(term_parts)) {
      return(NULL)
    }

    # 2. Removing the indicator alone leaves the intercept. Sorting makes
    # idiff:time:support and support:idiff:time equivalent.
    terms[[i]] <- if (length(term_parts) == 0L) {
      "(Intercept)"
    } else {
      paste(sort(term_parts), collapse = ":")
    }
  }

  # 3. Reject coefficients that collapse to the same underlying term, such as
  # idiff:time and I(idiff * time) both becoming "time".
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
  generated_indicators <- unique(grep(
    "^\\.dy_diff_.+_arbitrary$",
    variables,
    value = TRUE
  ))

  if (length(generated_indicators) > 1L) {
    stop(
      "A difference block contains more than one generated difference ",
      "indicator: `", paste(generated_indicators, collapse = "`, `"),
      "`. Put each ",
      "exchangeable composition in a separate random-effect block.",
      call. = FALSE
    )
  }
  if (length(generated_indicators) == 0L) {
    return(NA_character_)
  }
  return(generated_indicators[[1L]])
}

# Validate -1/+1 difference coding on rows designated by `shared_indicator`.
validate_exchangeable_coding <- function(
  model_frame,
  idiff,
  shared_indicator,
  pair_label = NULL
) {
  pair_context <- if (is.null(pair_label)) "" else paste0(pair_label, ": ")

  # 1. Matching helpers can be tested without fitted data. There is then no
  # coding to validate.
  if (is.null(model_frame)) {
    return(invisible(NULL))
  }

  # 2. Obtain the difference values. The fitted frame may not retain the source
  # column, so warn when validation is impossible. Wholly omitted difference
  # blocks never call this validator.
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

  difference_values <- model_frame[[idiff]]
  all_rows_supported <- identical(shared_indicator, "1")

  # 3. Obtain the support values. `shared_indicator = "1"` supports every row;
  # a named indicator marks one composition in a mixed-dyad model.
  if (all_rows_supported) {
    support_values <- rep(1, nrow(model_frame))
  } else if (shared_indicator %in% names(model_frame)) {
    support_values <- model_frame[[shared_indicator]]
  } else {
    # Infer support from idiff if the fitted frame omitted the named indicator,
    # but warn because the two columns can no longer be checked independently.
    warning(
      pair_context, "`", shared_indicator,
      "` was not retained in the fitted model frame, so its support could not ",
      "be checked. Verify that it was coded 1 exactly where `abs(", idiff,
      ") == 1` and 0 elsewhere.",
      call. = FALSE
    )
    support_values <- if (is.numeric(difference_values)) {
      abs(difference_values)
    } else {
      difference_values
    }
  }
  if (is.logical(support_values)) {
    support_values <- as.numeric(support_values)
  }

  # 4. Require complete numeric columns before checking their allowed values
  # and whether both components refer to exactly the same fitted rows.
  if (!is.numeric(difference_values) || !is.numeric(support_values) ||
      anyNA(difference_values) || anyNA(support_values)) {
    column_names <- paste0("`", idiff, "`")
    coding_requirement <- paste0(
      "Code `", idiff, "` as -1/+1 before fitting."
    )
    if (!all_rows_supported) {
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
  valid_difference_values <- all(difference_values %in% c(-1, 0, 1))
  valid_support_values <- all(support_values %in% c(0, 1))
  matching_support <- all(abs(difference_values) == support_values)
  valid_coding <- valid_difference_values &&
    valid_support_values &&
    matching_support
  if (!valid_coding) {
    if (all_rows_supported) {
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

  # 5. Both arbitrary member positions must occur on supported rows; otherwise
  # the difference coordinate cannot represent both dyad members.
  supported_rows <- support_values == 1
  if (!any(difference_values[supported_rows] == -1) ||
      !any(difference_values[supported_rows] == 1)) {
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

# Pair construction and automatic matching -----------------------------------

# Describe one shared/difference pair in a common underlying term space.
build_exchangeable_pair <- function(
  blocks,
  shared_block_index,
  difference_block_index,
  idiff,
  shared_indicator
) {
  has_shared_block <- !is.na(shared_block_index)
  has_difference_block <- !is.na(difference_block_index)

  # 1. At least one component must be fitted. If both are present, they must
  # describe random effects at the same grouping level.
  if (!has_shared_block && !has_difference_block) {
    stop("A pair cannot omit both its shared and difference blocks.",
      call. = FALSE
    )
  }
  if (
    has_shared_block &&
      has_difference_block &&
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

  # 2. Map the shared block to underlying term names, removing a named shared
  # indicator when present.
  shared_terms <- character()
  if (has_shared_block) {
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

  # 3. Map the difference block in the same way, removing its indicator.
  difference_terms <- character()
  if (has_difference_block) {
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

  # 4. Form the common coefficient space. `NA` indices mark rows and columns
  # that must later be supplied as structural zeros for one component.
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
  shared_candidate_indices <- integer()
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
      shared_candidate_indices <- c(shared_candidate_indices, i)
    }
  }
  return(shared_candidate_indices)
}

# Match every block containing one generated difference indicator to exactly
# one shared block with the same group and underlying terms.
match_blocks_for_exchangeable_indicator <- function(
  blocks,
  idiff,
  shared_indicator,
  fallback_indicator = NULL,
  model_frame = NULL
) {
  inventory <- format_exchangeable_block_inventory(blocks)
  difference_block_indices <- integer()

  # 1. Find all valid difference blocks using this indicator.
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

  # 2. For each difference block, try the requested shared indicator first.
  # Try the fallback only when that first search finds no candidates.
  matched_pairs <- list()
  for (difference_block_index in difference_block_indices) {
    difference_terms <- exchangeable_underlying_terms(
      blocks[[difference_block_index]]$coefficients,
      idiff
    )
    selected_shared_indicator <- shared_indicator
    shared_candidate_indices <- find_exchangeable_shared_candidates(
      blocks,
      difference_block_index,
      difference_terms,
      selected_shared_indicator,
      excluded_difference_indices = difference_block_indices
    )
    if (length(shared_candidate_indices) == 0L &&
        !is.null(fallback_indicator)) {
      selected_shared_indicator <- fallback_indicator
      shared_candidate_indices <- find_exchangeable_shared_candidates(
        blocks,
        difference_block_index,
        difference_terms,
        selected_shared_indicator,
        excluded_difference_indices = difference_block_indices
      )
    }

    # 3. Automatic matching is deliberately strict: exactly one shared block
    # must fit. Partial or ambiguous structures require explicit `pairs`.
    if (length(shared_candidate_indices) != 1L) {
      problem <- if (length(shared_candidate_indices) == 0L) {
        "No"
      } else {
        "More than one"
      }
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
      shared_candidate_indices[[1L]],
      difference_block_index,
      idiff,
      selected_shared_indicator
    )
    validate_exchangeable_coding(
      model_frame,
      idiff,
      selected_shared_indicator
    )
    matched_pairs[[length(matched_pairs) + 1L]] <- pair
  }
  return(matched_pairs)
}

match_exchangeable_residual_blocks <- function(
  blocks,
  model_frame = NULL
) {
  # 1. Discover generated difference indicators across all extracted blocks.
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
      "No supported `.dy_diff_*_arbitrary` difference block was found.",
      " Supply `pairs` explicitly if the model uses custom ",
      "difference-indicator names or unequal shared and difference term sets.",
      format_exchangeable_block_inventory(blocks),
      call. = FALSE
    )
  }

  # 2. Match every discovered composition independently. An ordinary shared
  # intercept is a safe fallback only when there is one exchangeable type.
  matched_pairs <- list()
  for (idiff in difference_indicators) {
    composition <- sub("^\\.dy_diff_(.+)_arbitrary$", "\\1", idiff)
    indicator_pairs <- match_blocks_for_exchangeable_indicator(
      blocks,
      idiff,
      shared_indicator = paste0(".dy_is_", composition),
      fallback_indicator = if (length(difference_indicators) == 1L) "1" else NULL,
      model_frame = model_frame
    )
    matched_pairs <- c(matched_pairs, indicator_pairs)
  }

  # 3. Ensure no shared block was assigned to more than one difference block,
  # then return pairs in the fitted difference-block order.
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

# User-supplied pair matching -------------------------------------------------

# Convert equivalent backend/formula spellings to one lookup key. For example,
# `(1 + time | group)` and `us(time + 1 | group)` receive the same key.
canonicalize_exchangeable_block_term <- function(term) {
  if (
    !is.character(term) ||
      length(term) != 1L ||
      is.na(term) ||
      !nzchar(trimws(term))
  ) {
    return(NA_character_)
  }

  # 1. Unwrap backend-specific covariance syntax, or start with a plain bar
  # term. The covariance structure is inferred below when no wrapper is present.
  term <- trimws(term)
  covariance_structure <- NULL
  bar_term <- term

  wrapper_match <- regexec(
    "^([[:alnum:]_.]+)[[:space:]]*\\((.*)\\)[[:space:]]*$",
    term,
    perl = TRUE
  )
  wrapper_parts <- regmatches(term, wrapper_match)[[1L]]
  if (length(wrapper_parts) == 3L &&
      grepl("|", wrapper_parts[[3L]], fixed = TRUE)) {
    covariance_structure <- wrapper_parts[[2L]]
    bar_term <- wrapper_parts[[3L]]
  } else if (startsWith(bar_term, "(") && endsWith(bar_term, ")")) {
    bar_term <- substr(bar_term, 2L, nchar(bar_term) - 1L)
  }

  # 2. Normalize `||` to one bar for parsing and infer `diag` versus `us` when
  # the user supplied no explicit covariance-structure wrapper.
  uncorrelated <- grepl("||", bar_term, fixed = TRUE)
  bar_term <- gsub("||", "|", bar_term, fixed = TRUE)
  bar_parts <- strsplit(bar_term, "|", fixed = TRUE)[[1L]]
  if (length(bar_parts) != 2L) {
    return(NA_character_)
  }
  if (is.null(covariance_structure)) {
    covariance_structure <- if (uncorrelated) "diag" else "us"
  }

  # 3. Parse the coefficient and grouping sides as R expressions.
  coefficient_terms <- tryCatch(
    stats::terms(stats::as.formula(paste("~", trimws(bar_parts[[1L]])))),
    error = function(e) NULL
  )
  group_expression <- tryCatch(
    str2lang(trimws(bar_parts[[2L]])),
    error = function(e) NULL
  )
  if (is.null(coefficient_terms) || is.null(group_expression)) {
    return(NA_character_)
  }

  # 4. Canonicalize interaction order and literal products, then rebuild a
  # compact key whose coefficient order no longer matters.
  coefficient_labels <- attr(coefficient_terms, "term.labels")
  for (i in seq_along(coefficient_labels)) {
    coefficient_parts <- strsplit(
      coefficient_labels[[i]],
      ":",
      fixed = TRUE
    )[[1L]]
    for (j in seq_along(coefficient_parts)) {
      parsed_coefficient <- parse_exchangeable_coefficient(
        coefficient_parts[[j]]
      )
      if (!is.null(parsed_coefficient$literal_product)) {
        coefficient_parts[[j]] <- paste0(
          "I(",
          paste(sort(parsed_coefficient$literal_product), collapse = " * "),
          ")"
        )
        next
      }

      part_expression <- tryCatch(
        str2lang(coefficient_parts[[j]]),
        error = function(e) NULL
      )
      coefficient_parts[[j]] <- if (is.null(part_expression)) {
        trimws(coefficient_parts[[j]])
      } else {
        deparse1(part_expression)
      }
    }
    coefficient_labels[[i]] <- paste(
      sort(coefficient_parts),
      collapse = ":"
    )
  }

  canonical_lhs <- c(
    if (attr(coefficient_terms, "intercept") == 1L) "1" else "0",
    sort(coefficient_labels)
  )
  return(paste0(
    covariance_structure, "(", paste(canonical_lhs, collapse = "+"),
    "|", deparse1(group_expression), ")"
  ))
}

# Normalize the convenient single-pair form and the general list-of-pairs form
# to one validated internal representation.
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

  # 1. A top-level list of fields describes one pair; otherwise each top-level
  # element must itself describe one pair.
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

    # 2. Validate the pair's field names and required fields.
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

    # 3. Fill and validate indicator names. The ordinary shared intercept uses
    # the special default `shared_indicator = "1"`.
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

    # 4. Validate the two block selectors and forbid an entirely empty pair.
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

# Resolve an exact printed block label first, then try canonical-equivalent
# formula/backend syntax.
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
  potential_block_indices <- integer()
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
        potential_block_indices <- c(potential_block_indices, i)
      }
      next
    }
    if (
      !is.null(overlap_terms) &&
        !any(terms %in% overlap_terms)
    ) {
      next
    }
    potential_block_indices <- c(potential_block_indices, i)
  }
  return(potential_block_indices)
}

# Add the supplied pair label to lower-level parsing and matching errors.
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
  pair_reference <- substr(pair_label, 1L, nchar(pair_label) - 1L)
  shared_field_label <- paste0(pair_reference, "$shared`")
  difference_field_label <- paste0(pair_reference, "$difference`")

  # 1. Resolve the two user selectors to extracted block positions. `NULL`
  # becomes `NA`, so one fitted component is enough to define a pair.
  shared_block_index <- resolve_exchangeable_block_selector(
    pair$shared,
    shared_field_label,
    block_lookup
  )
  difference_block_index <- resolve_exchangeable_block_selector(
    pair$difference,
    difference_field_label,
    block_lookup
  )

  fitted_block_indices <- c(shared_block_index, difference_block_index)
  fitted_block_indices <- fitted_block_indices[
    !is.na(fitted_block_indices)
  ]

  # 2. Remove indicators and build the common underlying term map.
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

  reference_block_index <- fitted_block_indices[[1L]]
  pair_group <- blocks[[reference_block_index]]$group

  # 3. `NULL` declares that a component was not fitted. Search for clear
  # contradictions before structural zeros are inserted.
  if (
    is.na(difference_block_index) &&
      !is.null(pair$difference_indicator)
  ) {
    potential_block_indices <- with_exchangeable_pair_error_context(
      find_potential_exchangeable_blocks(
        blocks,
        pair_group,
        pair$difference_indicator,
        overlap_terms = matched_pair$underlying_terms
      ),
      pair_label
    )
    potential_block_indices <- setdiff(
      potential_block_indices,
      fitted_block_indices
    )
    if (length(potential_block_indices) > 0L) {
      stop(
        difference_field_label,
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
        pair_group,
        pair$shared_indicator,
        exclude_indicator = pair$difference_indicator,
        overlap_terms = matched_pair$underlying_terms
      ),
      pair_label
    )
    potential_block_indices <- setdiff(
      potential_block_indices,
      fitted_block_indices
    )
    if (length(potential_block_indices) > 0L) {
      stop(
        shared_field_label,
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

  # 4. Check the difference coding whenever that block was actually fitted.
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
  # 1. Normalize pair specifications and prepare exact and canonical block
  # labels for selector lookup.
  pair_specs <- normalize_supplied_exchangeable_pairs(pairs)
  pair_labels <- attr(pair_specs, "pair_labels")
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

  # 2. Resolve and validate each supplied pair independently.
  matched_pairs <- vector("list", length(pair_specs))
  names(matched_pairs) <- names(pair_specs)
  for (i in seq_along(pair_specs)) {
    matched_pairs[[i]] <- match_one_supplied_exchangeable_pair(
      blocks,
      pair_specs[[i]],
      pair_labels[[i]],
      block_lookup,
      model_frame
    )
  }

  # 3. A fitted block can belong to only one requested transformation.
  used_block_indices <- integer()
  for (pair in matched_pairs) {
    used_block_indices <- c(
      used_block_indices,
      pair$shared_block_index,
      pair$difference_block_index
    )
  }
  used_block_indices <- used_block_indices[!is.na(used_block_indices)]
  reused_block_indices <- unique(
    used_block_indices[duplicated(used_block_indices)]
  )
  if (length(reused_block_indices) > 0L) {
    reused_blocks <- paste0(
      "`", term_labels[reused_block_indices], "`",
      collapse = ", "
    )
    reused_pair_assignments <- vapply(
      reused_block_indices,
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
      "Reused block", if (length(reused_block_indices) > 1L) "s" else "",
      ": ", reused_blocks, ". Remove each reused block from all but one pair.",
      " Pair assignments: ", paste(reused_pair_assignments, collapse = "; "),
      ".",
      call. = FALSE
    )
  }

  # 4. Warn when an omitted difference component cannot be checked against the
  # fitted blocks because no indicator name was supplied.
  unverifiable_difference_warnings <- character()
  for (i in seq_along(pair_specs)) {
    if (
      is.null(pair_specs[[i]]$difference) &&
        is.null(pair_specs[[i]]$difference_indicator)
    ) {
      unverifiable_difference_warnings <- c(
        unverifiable_difference_warnings,
        paste0(
          paste0(substr(pair_labels[[i]], 1L, nchar(pair_labels[[i]]) - 1L),
            "$difference`"),
          " is `NULL`, and no `difference_indicator` was supplied, so the ",
          "fitted model could not be checked for a corresponding difference ",
          "block. The block will be treated as omitted. Use `NULL` only if ",
          "that block was omitted from the fitted model; otherwise, the ",
          "back-transformed result is incorrect."
        )
      )
    }
  }
  if (length(unverifiable_difference_warnings) > 0L) {
    warning(
      paste(unverifiable_difference_warnings, collapse = "\n"),
      call. = FALSE
    )
  }
  return(matched_pairs)
}

# Residual-level diagnostics --------------------------------------------------

# A grouping level may represent residual dependence when every fitted group
# contains at most two observations. This deliberately makes no claim that the
# two observations are different members; the warning language stays cautious.
may_be_exchangeable_residual_level <- function(extracted, pair) {
  block_indices <- c(
    pair$shared_block_index,
    pair$difference_block_index
  )
  block_index <- block_indices[!is.na(block_indices)][[1L]]
  group <- extracted$blocks[[block_index]]$group
  group_ids <- extracted$group_ids[[group]]
  if (is.null(group_ids) || length(group_ids) == 0L || anyNA(group_ids)) {
    return(FALSE)
  }
  return(all(table(group_ids) <= 2L))
}

# Warn cautiously when a grouping level could represent residual dependence.
# All applicable issues for one pair are combined into one message.
warn_about_exchangeable_residual_level <- function(extracted, pairs) {
  messages <- character()

  format_terms <- function(terms) {
    paste0("`", terms, "`", collapse = ", ")
  }

  describe_omission <- function(
    component,
    terms,
    member_effects,
    correlation
  ) {
    paste0(
      "Terms absent from the ", component, " block: ",
      format_terms(terms), ". The fitted model fixes their ", component,
      " components at zero, implying ", member_effects, " (correlation ",
      correlation, " when variance > 0; undefined at zero) and singular ",
      "member covariance. If unintended, revise this block and refit."
    )
  }

  for (i in seq_along(pairs)) {
    pair <- pairs[[i]]
    if (!may_be_exchangeable_residual_level(extracted, pair)) {
      next
    }

    block_indices <- c(
      pair$shared_block_index,
      pair$difference_block_index
    )
    block_index <- block_indices[!is.na(block_indices)][[1L]]
    group <- extracted$blocks[[block_index]]$group
    pair_name <- names(pairs)[[i]]
    pair_id <- if (!is.null(pair$difference_indicator)) {
      if (!is.null(pair_name) && nzchar(pair_name)) {
        paste0("Pair `", pair_name, "` for `", pair$difference_indicator, "`")
      } else {
        paste0("Pair for `", pair$difference_indicator, "`")
      }
    } else if (!is.null(pair_name) && nzchar(pair_name)) {
      paste0("Pair `", pair_name, "`")
    } else {
      paste0("Pair ", i)
    }
    pair_label <- paste0(pair_id, " (group `", group, "`)")
    details <- character()

    if (identical(extracted$backend, "brms")) {
      if (identical(pair$shared_indicator, "1")) {
        details <- c(details, paste0(
          "For `brms`, if this pair is intended to model residual dependence, ",
          "the model should usually be refitted with a direct ",
          "`unstr(time = member_position, gr = residual_group)` ",
          "structure. See `?exchangeable_rescov`."
        ))
      } else {
        details <- c(details, paste0(
          "For `brms`, one response cannot contain separate composition-specific ",
          "`unstr()` structures. Use `glmmTMB` for Gaussian mixed-dyad ",
          "residual covariance. For non-Gaussian outcomes, these blocks ",
          "instead describe latent link-scale covariance. ",
          "See `?exchangeable_rescov`."
        ))
      }
    }

    omitted_shared <- pair$underlying_terms[
      is.na(pair$shared_term_indices)
    ]
    omitted_difference <- pair$underlying_terms[
      is.na(pair$difference_term_indices)
    ]
    if (length(omitted_difference) > 0L) {
      details <- c(
        details,
        describe_omission(
          "difference",
          omitted_difference,
          "identical member effects",
          "+1"
        )
      )
    }
    if (length(omitted_shared) > 0L) {
      details <- c(
        details,
        describe_omission(
          "shared",
          omitted_shared,
          "equal and opposite member effects",
          "-1"
        )
      )
    }

    slope_terms <- setdiff(pair$underlying_terms, "(Intercept)")
    if (length(slope_terms) > 0L) {
      details <- c(details, paste0(
        "Non-intercept terms: ", format_terms(slope_terms), ". At residual ",
        "level these make covariance covariate-dependent. For constant ",
        "covariance, consider removing them. For stable random slopes, use a ",
        "grouping level repeated across occasions."
      ))
    }

    if (length(details) > 0L) {
      messages <- c(messages, paste0(
        pair_label, " may be residual-level: at most two fitted rows per ",
        "group. Row-count check only; partner positions were not verified.",
        "\n\n- ", paste(details, collapse = "\n- ")
      ))
    }
  }

  if (length(messages) > 0L) {
    warning(
      "Review possible residual-level structure",
      if (length(messages) == 1L) "" else "s",
      ":\n\n",
      paste(messages, collapse = "\n\n"),
      call. = FALSE
    )
  }
  return(invisible(NULL))
}

# Covariance alignment --------------------------------------------------------

# Align the shared and difference covariance arrays to one common term order.
# Terms absent from either fitted component are represented by structural zeros.
align_exchangeable_pair_covariances <- function(blocks, pair) {
  # 1. Identify the fitted shared and difference blocks. One of the two may
  # be absent because it was deliberately omitted from the fitted model.
  block_indices <- c(
    shared = pair$shared_block_index,
    difference = pair$difference_block_index
  )
  fitted_block_indices <- block_indices[!is.na(block_indices)]

  # All fitted blocks must contain the same number of covariance estimates:
  # one for glmmTMB or one per posterior draw for brms.
  n_estimates <- dim(
    blocks[[fitted_block_indices[[1L]]]]$covariance
  )[[1L]]

  for (block_index in fitted_block_indices) {
    if (dim(blocks[[block_index]]$covariance)[[1L]] != n_estimates) {
      stop(
        "Internal error: paired covariance blocks contain different numbers ",
        "of estimates or posterior draws.",
        call. = FALSE
      )
    }
  }

  # 2. The common term order is the union of terms from both blocks. It may be
  # larger than either fitted block when each one contains unique terms.
  terms <- pair$underlying_terms

  # 3. Start both aligned covariance arrays at zero. Positions that have no
  # fitted shared or difference term remain structural zeros.
  empty_covariance <- array(
    0,
    dim = c(n_estimates, length(terms), length(terms)),
    dimnames = list(NULL, terms, terms)
  )
  aligned <- list(
    shared = empty_covariance,
    difference = empty_covariance
  )

  # 4. Copy each fitted covariance block into its matching rows and columns in
  # the common term order.
  for (component in names(fitted_block_indices)) {
    source_term_indices <- pair[[paste0(component, "_term_indices")]]
    output_positions <- which(!is.na(source_term_indices))
    source_positions <- source_term_indices[output_positions]
    covariance <- blocks[[fitted_block_indices[[component]]]]$covariance

    aligned[[component]][, output_positions, output_positions] <-
      covariance[, source_positions, source_positions, drop = FALSE]
  }
  return(aligned)
}

# Convert aligned shared/difference covariance arrays to member-level arrays.
# For K terms, the input is estimate/draw x K x K and the output is
# estimate/draw x 2K x 2K: all member-1 terms, then all member-2 terms.
backtransform_exchangeable_covariances <- function(aligned, terms) {
  shared <- aligned$shared
  difference <- aligned$difference
  dimensions <- dim(shared)

  # The aligner should always supply two finite, equally sized square arrays.
  valid_dimensions <-
    length(dimensions) == 3L &&
      dimensions[[1L]] > 0L &&
      dimensions[[2L]] > 0L &&
      dimensions[[2L]] == dimensions[[3L]] &&
      identical(dimensions, dim(difference))
  if (
    !is.numeric(shared) ||
      !is.numeric(difference) ||
      !valid_dimensions ||
      any(!is.finite(shared)) ||
      any(!is.finite(difference)) ||
      length(terms) != dimensions[[2L]]
  ) {
    stop(
      "Internal error: aligned shared and difference covariances must be ",
      "finite arrays with identical draw and square term dimensions.",
      call. = FALSE
    )
  }

  # Validate symmetry before using the same between-member block in both
  # off-diagonal positions of the final covariance matrix.
  for (component in c("shared", "difference")) {
    covariance <- aligned[[component]]
    if (!identical(
      unname(covariance),
      unname(aperm(covariance, c(1L, 3L, 2L)))
    )) {
      stop(
        "Internal error: the aligned ", component,
        " covariance array must be symmetric in every estimate or draw.",
        call. = FALSE
      )
    }
  }

  # If u1 = shared + difference and u2 = shared - difference, then:
  #   Var(u1) = Var(u2)    = shared + difference
  #   Cov(u1, u2)          = shared - difference
  within_member <- shared + difference
  between_members <- shared - difference

  n_estimates <- dimensions[[1L]]
  n_terms <- dimensions[[2L]]
  member_1_indices <- seq_len(n_terms)
  member_2_indices <- n_terms + member_1_indices
  member_terms <- c(
    paste0("member_1: ", terms),
    paste0("member_2: ", terms)
  )

  varcov <- array(
    0,
    dim = c(n_estimates, 2L * n_terms, 2L * n_terms),
    dimnames = list(dimnames(shared)[[1L]], member_terms, member_terms)
  )
  varcov[, member_1_indices, member_1_indices] <- within_member
  varcov[, member_2_indices, member_2_indices] <- within_member
  varcov[, member_1_indices, member_2_indices] <- between_members
  varcov[, member_2_indices, member_1_indices] <- between_members
  return(varcov)
}

# Replace the diagonal of each covariance matrix with standard deviations and
# standardize all off-diagonal covariances to correlations.
covariance_array_to_sdcor <- function(varcov) {
  dimensions <- dim(varcov)
  if (
    !is.numeric(varcov) ||
      length(dimensions) != 3L ||
      dimensions[[2L]] != dimensions[[3L]] ||
      any(!is.finite(varcov))
  ) {
    stop(
      "Internal error: `varcov` must be a finite draw by coefficient by ",
      "coefficient array.",
      call. = FALSE
    )
  }

  # Start with NA because correlations involving an exactly zero standard
  # deviation are undefined. The diagonal is always replaced by the SD itself.
  sdcor <- array(NA_real_, dim = dimensions, dimnames = dimnames(varcov))

  for (estimate in seq_len(dimensions[[1L]])) {
    covariance <- varcov[estimate, , , drop = TRUE]
    variances <- diag(covariance)

    # These diagonals are sums of fitted component variances, so cancellation
    # cannot create a legitimate negative value, even at a model boundary.
    if (any(variances < 0)) {
      stop(
        "Internal error: the back-transformed covariance matrix contains a ",
        "negative variance.",
        call. = FALSE
      )
    }
    standard_deviations <- sqrt(variances)
    nonzero_sd_indices <- which(standard_deviations > 0)

    # Correlations are defined only where both standard deviations are non-zero.
    if (length(nonzero_sd_indices) > 0L) {
      denominators <- outer(
        standard_deviations[nonzero_sd_indices],
        standard_deviations[nonzero_sd_indices]
      )
      sdcor[estimate, nonzero_sd_indices, nonzero_sd_indices] <-
        covariance[
          nonzero_sd_indices,
          nonzero_sd_indices,
          drop = FALSE
        ] / denominators
    }
    diag(sdcor[estimate, , ]) <- standard_deviations
  }
  return(sdcor)
}

# Backend adapters ------------------------------------------------------------

# Extract normalized random-effect blocks and point-estimate covariances from
# a fitted glmmTMB model.
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
  fitted_covariances <- glmmTMB::VarCorr(model)$cond

  # `flist` stores one grouping-level ID per fitted row, including
  # interaction groups such as `coupleID:diaryday` that are not retained as a
  # column in the ordinary glmmTMB model frame.
  group_ids <- lapply(
    re_terms$flist,
    function(values) match(values, unique(values))
  )

  # These stored objects use corresponding backend block order.
  groups <- names(re_terms$cnms)
  term_labels <- names(re_structure)
  n_blocks <- length(re_structure)

  if (
    length(re_terms$cnms) != n_blocks ||
      length(groups) != n_blocks ||
      length(term_labels) != n_blocks ||
      length(fitted_covariances) != n_blocks
  ) {
    stop(
      "Internal error: stored `glmmTMB` random-effect blocks could not be ",
      "aligned. This is unexpected for a supported model; please report an ",
      "issue with a reproducible model and the installed versions of ",
      "`dyadMLM` and `glmmTMB`.",
      call. = FALSE
    )
  }

  blocks <- vector("list", n_blocks)
  # Each iteration aligns stored coefficient names with one fitted covariance
  # matrix, restores coefficient order, and adds the leading estimate dimension.
  for (i in seq_len(n_blocks)) {
    coefficients <- unname(re_terms$cnms[[i]])
    covariance_matrix <- fitted_covariances[[i]]
    covariance_structure <- names(re_structure[[i]]$blockCode)

    if (
      length(covariance_structure) != 1L ||
        anyDuplicated(coefficients) ||
        !setequal(rownames(covariance_matrix), coefficients) ||
        !setequal(colnames(covariance_matrix), coefficients)
    ) {
      stop(
        "Internal error: a `glmmTMB` covariance block could not be aligned ",
        "with its coefficients. This is unexpected for a supported model; ",
        "please report an issue with a reproducible model and the installed ",
        "versions of `dyadMLM` and `glmmTMB`.",
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
      correlated = !covariance_structure %in% c("diag", "homdiag"),
      term = paste0(covariance_structure, "(", term_labels[[i]], ")"),
      covariance = covariance_array
    )
  }
  return(list(
    backend = "glmmTMB",
    blocks = blocks,
    group_ids = group_ids
  ))
}

# Recover readable coefficient names while preserving brms' stored covariance
# order.
brms_readable_exchangeable_coefficients <- function(block, model_frame) {
  # `cn` records the coefficient order used by the stored covariance draws.
  block <- block[order(block$cn), , drop = FALSE]
  stored_names <- unname(block$coef)

  # model.matrix() restores names users recognize from their formula. Fall back
  # to the stored names if the formula cannot be reconstructed safely.
  readable_names <- tryCatch(
    colnames(stats::model.matrix(block$form[[1L]], data = model_frame)),
    error = function(e) NULL
  )
  if (is.null(readable_names) ||
      length(readable_names) != length(stored_names)) {
    readable_names <- stored_names
  }
  readable_names[readable_names == "Intercept"] <- "(Intercept)"
  return(list(stored_names = stored_names, readable_names = readable_names))
}

# Extract normalized random-effect blocks and posterior covariance draws from a
# fitted single-response brms model.
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
  unsupported_parameter_rows <- nzchar(re_terms$dpar) | nzchar(re_terms$nlpar)
  if (any(unsupported_parameter_rows)) {
    warning(
      "Random effects for distributional or nonlinear parameters were ",
      "ignored; `exchangeable_rescov()` only processes ordinary response-mean ",
      "random effects.",
      call. = FALSE
    )
  }
  re_terms <- re_terms[!unsupported_parameter_rows, , drop = FALSE]
  if (nrow(re_terms) == 0L) {
    return(list(backend = "brms", blocks = list(), group_ids = list()))
  }
  model_frame <- stats::model.frame(model)
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

  # `id` identifies one fitted covariance block; `group` identifies its
  # grouping factor. Several independent blocks may therefore share a group.
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

  fitted_covariances <- brms::VarCorr(model, summary = FALSE)
  blocks <- vector("list", length(re_blocks))

  # brms retains generated interaction groups in its fitted model frame. Store
  # one grouping-level ID per fitted row for each unique grouping factor.
  group_names <- unique(vapply(
    re_blocks,
    function(block) block$group[[1L]],
    character(1L)
  ))
  group_ids <- stats::setNames(
    vector("list", length(group_names)),
    group_names
  )
  for (group in group_names) {
    values <- model_frame[[group]]
    if (!is.null(values) && !anyNA(values)) {
      group_ids[[group]] <- match(values, unique(values))
    }
  }

  for (i in seq_along(re_blocks)) {
    block <- re_blocks[[i]]
    # Keep stored names for VarCorr lookup and readable formula names for
    # matching against user-supplied terms.
    coefficient_names <- brms_readable_exchangeable_coefficients(
      block,
      model_frame
    )
    stored_coefficients <- coefficient_names$stored_names
    coefficients <- coefficient_names$readable_names
    stored_coefficients[stored_coefficients == "Intercept"] <- "(Intercept)"

    group <- block$group[[1L]]
    group_covariance_draws <- fitted_covariances[[group]]
    if (is.null(group_covariance_draws) ||
        is.null(group_covariance_draws$sd)) {
      stop(
        "Internal error: `brms` covariance draws were not found for a ",
        "random-effect block. This is unexpected for a supported model; please ",
        "report an issue with a reproducible model and the installed versions ",
        "of `dyadMLM` and `brms`.",
        call. = FALSE
      )
    }

    covariance_names <- colnames(group_covariance_draws$sd)
    covariance_names[covariance_names == "Intercept"] <- "(Intercept)"
    if (anyDuplicated(covariance_names)) {
      stop(
        "Internal error: duplicated `brms` covariance names cannot be aligned ",
        "to separate blocks. This is unexpected for a supported model; please ",
        "report an issue with a reproducible model and the installed versions ",
        "of `dyadMLM` and `brms`.",
        call. = FALSE
      )
    }
    coefficient_index <- match(stored_coefficients, covariance_names)
    if (anyNA(coefficient_index)) {
      stop(
        "Internal error: `brms` covariance draws could not be aligned with ",
        "their coefficients. This is unexpected for a supported model; please ",
        "report an issue with a reproducible model and the installed versions ",
        "of `dyadMLM` and `brms`.",
        call. = FALSE
      )
    }

    sd_draws <- group_covariance_draws$sd[, coefficient_index, drop = FALSE]
    if (is.null(group_covariance_draws$cov)) {
      # When VarCorr() supplies only SD draws, reconstruct this block's
      # diagonal covariance draws.
      covariance_array <- array(
        0,
        dim = c(nrow(sd_draws), length(coefficients), length(coefficients))
      )
      for (j in seq_along(coefficients)) {
        covariance_array[, j, j] <- sd_draws[, j]^2
      }
    } else {
      covariance_array <- group_covariance_draws$cov[
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
  return(list(
    backend = "brms",
    blocks = blocks,
    group_ids = group_ids
  ))
}
