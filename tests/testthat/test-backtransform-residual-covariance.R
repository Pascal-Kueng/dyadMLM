rescov_test_block <- function(
  group,
  coefficients,
  term,
  covariance = NULL
) {
  block <- list(group = group, coefficients = coefficients, term = term)
  if (!is.null(covariance)) {
    block$covariance <- covariance
  }
  return(block)
}

rescov_test_covariance <- function(variances) {
  n_terms <- length(variances)
  covariance <- array(
    rep(diag(variances), each = 2L),
    dim = c(2L, n_terms, n_terms)
  )
  covariance[2L, , ] <- covariance[2L, , ] * 2
  if (n_terms > 1L) {
    covariance[, 1L, 2L] <- c(0.1, 0.2)
    covariance[, 2L, 1L] <- c(0.1, 0.2)
  }
  return(covariance)
}

test_that("backend adapters return aligned common block records", {
  skip_if_not_installed("glmmTMB")
  skip_if_not_installed("brms")

  data <- expand.grid(
    member = c(-1, 1),
    day = 0:2,
    coupleID = seq_len(20)
  )
  data <- data[order(data$coupleID, data$day, data$member), ]
  data$coupleID <- factor(data$coupleID)
  data$familyID <- factor((as.integer(data$coupleID) - 1L) %/% 4L + 1L)
  data$idiff <- data$member
  data$shared2 <- 1
  data$diff2 <- data$member
  set.seed(123)
  data$outcome <- stats::rnorm(nrow(data))

  glmm_model <- suppressWarnings(glmmTMB::glmmTMB(
    outcome ~ 1 +
      (1 + day | coupleID) +
      (0 + idiff + idiff:day || coupleID) +
      (0 + shared2 | familyID) +
      homdiag(0 + diff2 | familyID),
    dispformula = ~0,
    data = data
  ))
  brms_model <- brms::brm(
    outcome ~ 1 +
      (1 + day | coupleID) +
      (0 + idiff + idiff:day || coupleID) +
      (0 + shared2 | familyID) +
      (0 + diff2 || familyID),
    data = data,
    empty = TRUE
  )

  couple_names <- c("Intercept", "day", "idiff", "idiff:day")
  couple_sd <- matrix(
    seq(1, 1.7, length.out = 8),
    nrow = 2,
    dimnames = list(NULL, couple_names)
  )
  couple_cov <- array(
    0,
    dim = c(2, 4, 4),
    dimnames = list(NULL, couple_names, couple_names)
  )
  for (i in seq_along(couple_names)) {
    couple_cov[, i, i] <- couple_sd[, i]^2
  }
  couple_cov[, 1, 2] <- 0.2
  couple_cov[, 2, 1] <- 0.2

  family_names <- c("shared2", "diff2")
  family_sd <- matrix(
    seq(0.5, 0.8, length.out = 4),
    nrow = 2,
    dimnames = list(NULL, family_names)
  )

  brms_blocks <- testthat::with_mocked_bindings(
    brms_extract_exchangeable_residual_blocks(brms_model),
    VarCorr = function(...) {
      list(
        coupleID = list(sd = couple_sd, cov = couple_cov),
        familyID = list(sd = family_sd)
      )
    },
    .package = "brms"
  )
  glmm_blocks <- glmmTMB_extract_exchangeable_residual_blocks(glmm_model)

  expect_named(glmm_blocks, c("backend", "blocks", "group_ids"))
  expect_named(brms_blocks, c("backend", "blocks", "group_ids"))
  expect_length(glmm_blocks$blocks, 4)
  expect_length(brms_blocks$blocks, 4)
  expect_equal(glmm_blocks$group_ids, brms_blocks$group_ids)
  expect_equal(
    unname(lengths(glmm_blocks$group_ids)),
    rep(nrow(data), 2L)
  )
  expect_equal(
    as.vector(table(glmm_blocks$group_ids$coupleID)),
    rep(6L, 20L)
  )

  descriptor <- function(block) {
    block[c("group", "coefficients", "correlated")]
  }
  expect_equal(
    lapply(glmm_blocks$blocks, descriptor),
    lapply(brms_blocks$blocks, descriptor)
  )
  expect_equal(
    lapply(glmm_blocks$blocks, names),
    lapply(brms_blocks$blocks, names)
  )

  for (i in seq_along(glmm_blocks$blocks)) {
    expect_equal(dim(glmm_blocks$blocks[[i]]$covariance)[1L], 1L)
    expect_equal(dim(brms_blocks$blocks[[i]]$covariance)[1L], 2L)
    expect_equal(
      dim(glmm_blocks$blocks[[i]]$covariance)[2:3],
      dim(brms_blocks$blocks[[i]]$covariance)[2:3]
    )
  }
  expect_equal(
    unname(brms_blocks$blocks[[1L]]$covariance),
    unname(couple_cov[, 1:2, 1:2, drop = FALSE])
  )
  expect_equal(
    unname(brms_blocks$blocks[[2L]]$covariance),
    unname(couple_cov[, 3:4, 3:4, drop = FALSE])
  )
  expect_equal(
    unname(brms_blocks$blocks[[3L]]$covariance[, 1L, 1L]),
    family_sd[, 1L]^2
  )
  expect_equal(
    unname(brms_blocks$blocks[[4L]]$covariance[, 1L, 1L]),
    family_sd[, 2L]^2
  )

  for (blocks in list(glmm_blocks$blocks, brms_blocks$blocks)) {
    pair <- match_supplied_exchangeable_residual_blocks(
      blocks,
      list(
        shared = "(1 + day | coupleID)",
        difference = "(0 + idiff + idiff:day || coupleID)",
        difference_indicator = "idiff"
      )
    )[[1L]]
    expect_equal(pair$underlying_terms, c("(Intercept)", "day"))

    family_pair <- match_supplied_exchangeable_residual_blocks(
      blocks,
      list(
        shared = blocks[[3L]]$term,
        difference = blocks[[4L]]$term,
        difference_indicator = "diff2",
        shared_indicator = "shared2"
      )
    )[[1L]]
    expect_equal(family_pair$underlying_terms, "(Intercept)")
  }
})

test_that("literal idiff products match in glmmTMB and brms", {
  skip_if_not_installed("glmmTMB")
  skip_if_not_installed("brms")

  data <- expand.grid(
    member = c(-1, 1),
    day = 0:2,
    coupleID = seq_len(20)
  )
  data$coupleID <- factor(data$coupleID)
  data$idiff <- data$member
  set.seed(456)
  data$outcome <- stats::rnorm(nrow(data))

  glmm_model <- suppressWarnings(glmmTMB::glmmTMB(
    outcome ~ 1 + (1 + day | coupleID) +
      (0 + idiff + I(idiff * day) || coupleID),
    dispformula = ~0,
    data = data
  ))
  brms_model <- brms::brm(
    outcome ~ 1 + (1 + day | coupleID) +
      (0 + idiff + I(idiff * day) || coupleID),
    data = data,
    empty = TRUE
  )

  covariance_names <- unname(brms_model$ranef$coef)
  sd_draws <- matrix(
    1,
    nrow = 2,
    ncol = length(covariance_names),
    dimnames = list(NULL, covariance_names)
  )
  covariance_draws <- array(
    0,
    dim = c(2, 4, 4),
    dimnames = list(NULL, covariance_names, covariance_names)
  )
  for (i in seq_along(covariance_names)) {
    covariance_draws[, i, i] <- 1
  }

  glmm_blocks <- glmmTMB_extract_exchangeable_residual_blocks(glmm_model)
  brms_blocks <- testthat::with_mocked_bindings(
    brms_extract_exchangeable_residual_blocks(brms_model),
    VarCorr = function(...) {
      list(coupleID = list(sd = sd_draws, cov = covariance_draws))
    },
    .package = "brms"
  )

  expected <- list(
    c("(Intercept)", "day"),
    c("idiff", "I(idiff * day)")
  )
  expect_equal(
    lapply(glmm_blocks$blocks, `[[`, "coefficients"),
    expected
  )
  expect_equal(
    lapply(brms_blocks$blocks, `[[`, "coefficients"),
    expected
  )

  for (model_blocks in list(glmm_blocks, brms_blocks)) {
    automatic <- match_blocks_for_exchangeable_indicator(
      model_blocks$blocks,
      idiff = "idiff",
      shared_indicator = "1"
    )[[1L]]
    supplied <- match_supplied_exchangeable_residual_blocks(
      model_blocks$blocks,
      list(
        shared = "(1 + day | coupleID)",
        difference = "(0 + idiff + I(idiff * day) || coupleID)",
        difference_indicator = "idiff"
      )
    )[[1L]]

    expect_equal(supplied, automatic)
    expect_equal(automatic$underlying_terms, c("(Intercept)", "day"))
  }
})

test_that("unsupported brms random-effect structures fail clearly", {
  skip_if_not_installed("brms")

  data <- data.frame(
    outcome = stats::rnorm(20),
    second_outcome = stats::rnorm(20),
    couple = factor(rep(seq_len(10), each = 2)),
    time = rep(0:1, 10),
    role = factor(rep(rep(c("a", "b"), each = 5), each = 2))
  )

  multivariate <- brms::brm(
    brms::bf(outcome ~ 1 + (1 | couple)) +
      brms::bf(second_outcome ~ 1 + (1 | couple)) +
      brms::set_rescor(FALSE),
    data = data,
    empty = TRUE
  )
  expect_error(
    brms_extract_exchangeable_residual_blocks(multivariate),
    "one response",
    fixed = TRUE
  )

  linked <- brms::brm(
    outcome ~ 1 + (1 | block | couple) + (0 + time | block | couple),
    data = data,
    empty = TRUE
  )
  expect_error(
    brms_extract_exchangeable_residual_blocks(linked),
    "different `| ID |` labels or no shared ID",
    fixed = TRUE
  )

  by_model <- brms::brm(
    outcome ~ 1 + (1 + time | gr(couple, by = role)),
    data = data,
    empty = TRUE
  )
  expect_error(
    brms_extract_exchangeable_residual_blocks(by_model),
    "Refit the exchangeable blocks without `by`",
    fixed = TRUE
  )
})

test_that("brms ignores non-mean random effects", {
  skip_if_not_installed("brms")

  data <- data.frame(
    outcome = stats::rnorm(20),
    couple = factor(rep(seq_len(10), each = 2)),
    time = rep(0:1, 10)
  )
  model <- brms::brm(
    brms::bf(
      outcome ~ 1 + (1 + time | mean | couple),
      sigma ~ 1 + (1 | scale | couple)
    ),
    data = data,
    empty = TRUE
  )

  names <- c("Intercept", "time", "sigma_Intercept")
  sd <- matrix(1, nrow = 2, ncol = 3, dimnames = list(NULL, names))
  covariance <- array(
    0,
    dim = c(2, 3, 3),
    dimnames = list(NULL, names, names)
  )
  for (i in seq_along(names)) {
    covariance[, i, i] <- 1
  }

  expect_warning(
    blocks <- testthat::with_mocked_bindings(
      brms_extract_exchangeable_residual_blocks(model),
      VarCorr = function(...) {
        list(couple = list(sd = sd, cov = covariance))
      },
      .package = "brms"
    ),
    "only processes ordinary response-mean random effects",
    fixed = TRUE
  )
  expect_length(blocks$blocks, 1L)
  expect_equal(blocks$blocks[[1L]]$coefficients, c("(Intercept)", "time"))
})

test_that("automatic matching aligns groups and coefficient order", {
  marker <- ".i_diff_assumed_exchangeable_arbitrary"
  blocks <- list(
    rescov_test_block("coupleID", c("time", "(Intercept)"), "shared"),
    rescov_test_block(
      "coupleID",
      c(marker, paste0("I(", marker, " * time)")),
      "difference"
    ),
    rescov_test_block("coupleID", "support", "unrelated"),
    rescov_test_block("studyID", c("(Intercept)", "time"), "other group")
  )

  pair <- match_exchangeable_residual_blocks(blocks)[[1L]]
  expect_equal(pair$shared_block_index, 1L)
  expect_equal(pair$difference_block_index, 2L)
  expect_equal(pair$difference_indicator, marker)
  expect_equal(pair$shared_indicator, "1")
  expect_equal(pair$underlying_terms, c("time", "(Intercept)"))
  expect_equal(pair$difference_term_indices, c(2L, 1L))

  expect_equal(
    exchangeable_underlying_terms(
      c("IDIFF", "I(IDIFF * time)"),
      "IDIFF"
    ),
    c("(Intercept)", "time")
  )
  expect_equal(
    exchangeable_underlying_terms("I(time * IDIFF)", "IDIFF"),
    "time"
  )

  nonsyntactic_indicators <- c("my diff", "difference-indicator", "1difference")
  for (indicator in nonsyntactic_indicators) {
    quoted_indicator <- paste0("`", indicator, "`")
    expect_equal(
      exchangeable_underlying_terms(
        c(quoted_indicator, paste0(quoted_indicator, ":`study time`")),
        indicator
      ),
      c("(Intercept)", "study time")
    )
  }
})

test_that("automatic matching handles compositions and grouping levels", {
  same_idiff <- ".i_diff_same_sex_arbitrary"
  friend_idiff <- ".i_diff_friends_arbitrary"
  blocks <- list(
    rescov_test_block("coupleID", "(Intercept)", "generic"),
    rescov_test_block("coupleID", ".i_is_same_sex", "same shared"),
    rescov_test_block("coupleID", same_idiff, "same difference"),
    rescov_test_block("coupleID", ".i_is_friends", "friend shared"),
    rescov_test_block("coupleID", friend_idiff, "friend difference")
  )

  pairs <- match_exchangeable_residual_blocks(blocks)
  expect_equal(
    lapply(
      pairs,
      function(pair) pair[c("shared_block_index", "difference_block_index")]
    ),
    list(
      list(shared_block_index = 2L, difference_block_index = 3L),
      list(shared_block_index = 4L, difference_block_index = 5L)
    )
  )
  expect_equal(
    unlist(lapply(pairs, `[[`, "shared_indicator"), use.names = FALSE),
    c(".i_is_same_sex", ".i_is_friends")
  )

  repeated <- list(
    rescov_test_block("coupleID", "(Intercept)", "stable shared"),
    rescov_test_block("coupleID", same_idiff, "stable difference"),
    rescov_test_block("coupleID:day", "(Intercept)", "occasion shared"),
    rescov_test_block("coupleID:day", same_idiff, "occasion difference")
  )
  repeated_pairs <- match_exchangeable_residual_blocks(repeated)
  expect_equal(
    lapply(repeated_pairs, `[[`, "shared_block_index"),
    list(1L, 3L)
  )
  expect_equal(
    lapply(repeated_pairs, `[[`, "difference_block_index"),
    list(2L, 4L)
  )
})

test_that("automatic matching is conservative about missing and ambiguous blocks", {
  marker <- ".i_diff_assumed_exchangeable_arbitrary"

  expect_error(
    match_exchangeable_residual_blocks(list(
      rescov_test_block("coupleID", "(Intercept)", "shared")
    )),
    "Supply `pairs` explicitly",
    fixed = TRUE
  )

  incomplete <- list(
    rescov_test_block(
      "coupleID",
      c("(Intercept)", "time", "support"),
      "shared"
    ),
    rescov_test_block(
      "coupleID",
      c(marker, paste0(marker, ":time")),
      "difference"
    )
  )
  expect_error(
    match_exchangeable_residual_blocks(incomplete),
    "Supply `pairs` explicitly to select the intended blocks",
    fixed = TRUE
  )

  ambiguous <- list(
    rescov_test_block("coupleID", "(Intercept)", "shared one"),
    rescov_test_block("coupleID", "(Intercept)", "shared two"),
    rescov_test_block("coupleID", marker, "difference")
  )
  expect_error(
    match_exchangeable_residual_blocks(ambiguous),
    "Supply `pairs` explicitly to select the intended blocks",
    fixed = TRUE
  )

  partial <- list(
    rescov_test_block("coupleID", c("(Intercept)", "time"), "shared"),
    rescov_test_block("coupleID", c(marker, "time"), "partial difference")
  )
  expect_error(
    match_exchangeable_residual_blocks(partial),
    "must identify every coefficient in its difference block",
    fixed = TRUE
  )

  expect_error(
    exchangeable_underlying_terms(
      c("IDIFF:time", "I(IDIFF * time)"),
      "IDIFF"
    ),
    "both represent the underlying term `time`. Keep only one representation",
    fixed = TRUE
  )
})

test_that("supplied exact pairs align partial and custom-named blocks", {
  shared_covariance <- rescov_test_covariance(1:3)
  difference_covariance <- rescov_test_covariance(4:6)

  blocks <- list(
    rescov_test_block(
      "coupleID",
      c("time", "(Intercept)", "support"),
      "us(time + 1 + support | coupleID)",
      shared_covariance
    ),
    rescov_test_block(
      "coupleID",
      c("I(IDIFF * support)", "IDIFF", "IDIFF:stress"),
      "diag(0 + I(IDIFF * support) + IDIFF + IDIFF:stress | coupleID)",
      difference_covariance
    )
  )

  pair <- match_supplied_exchangeable_residual_blocks(
    blocks,
    list(
      shared = "(1 + support + time | coupleID)",
      difference =
        "(0 + IDIFF + I(support * IDIFF) + IDIFF:stress || coupleID)",
      difference_indicator = "IDIFF"
    )
  )[[1L]]
  expect_equal(
    pair$underlying_terms,
    c("time", "(Intercept)", "support", "stress")
  )
  expect_equal(pair$shared_term_indices, c(1L, 2L, 3L, NA_integer_))
  expect_equal(
    pair$difference_term_indices,
    c(NA_integer_, 2L, 1L, 3L)
  )

  aligned <- align_exchangeable_pair_covariances(blocks, pair)
  expect_equal(
    unname(aligned$shared[, 1:3, 1:3, drop = FALSE]),
    unname(shared_covariance)
  )
  expect_true(all(aligned$shared[, 4, ] == 0))
  expect_true(all(aligned$shared[, , 4] == 0))
  expect_equal(
    unname(aligned$difference[
      , c(3, 2, 4), c(3, 2, 4), drop = FALSE
    ]),
    unname(difference_covariance)
  )
  expect_true(all(aligned$difference[, 1, ] == 0))
  expect_true(all(aligned$difference[, , 1] == 0))
  expect_equal(
    dimnames(aligned$shared)[2:3],
    list(pair$underlying_terms, pair$underlying_terms)
  )

  # The final transformation uses the aligned order, including every padded
  # zero, rather than either block's original coefficient order.
  transformed <- backtransform_exchangeable_covariances(
    aligned,
    pair$underlying_terms
  )
  member_1_indices <- seq_along(pair$underlying_terms)
  member_2_indices <- length(member_1_indices) + member_1_indices
  expect_equal(
    transformed[, member_1_indices, member_1_indices],
    aligned$shared + aligned$difference,
    ignore_attr = TRUE
  )
  expect_equal(
    transformed[, member_1_indices, member_2_indices],
    aligned$shared - aligned$difference,
    ignore_attr = TRUE
  )

  blocks[[2L]]$covariance <- array(0, dim = c(3, 3, 3))
  expect_error(
    align_exchangeable_pair_covariances(blocks, pair),
    "different numbers of estimates or posterior draws",
    fixed = TRUE
  )

  composition_blocks <- list(
    rescov_test_block(
      "coupleID",
      c("SAMESEX:time", "SAMESEX"),
      "shared"
    ),
    rescov_test_block(
      "coupleID",
      c("IDIFF_SAMESEX", "time:IDIFF_SAMESEX"),
      "difference"
    )
  )
  composition_pair <- match_supplied_exchangeable_residual_blocks(
    composition_blocks,
    list(
      shared = "shared",
      difference = "difference",
      difference_indicator = "IDIFF_SAMESEX",
      shared_indicator = "SAMESEX"
    )
  )[[1L]]
  expect_equal(
    composition_pair$underlying_terms,
    c("time", "(Intercept)")
  )
  expect_equal(composition_pair$difference_term_indices, c(2L, 1L))
})

test_that("supplied exact pairs support wholly omitted blocks", {
  marker <- ".i_diff_assumed_exchangeable_arbitrary"
  shared_covariance <- rescov_test_covariance(1:2)
  difference_covariance <- rescov_test_covariance(3:4)
  blocks <- list(
    rescov_test_block(
      "coupleID",
      c("(Intercept)", "time"),
      "us(1 + time | coupleID)",
      shared_covariance
    ),
    rescov_test_block(
      "coupleID:day",
      c(paste0(marker, ":time"), marker),
      paste0("diag(0 + ", marker, ":time + ", marker, " | coupleID:day)"),
      difference_covariance
    ),
    rescov_test_block("studyID", "(Intercept)", "us(1 | studyID)")
  )

  expect_warning(
    shared_only <- match_supplied_exchangeable_residual_blocks(
      blocks,
      list(
        shared = "(1 + time | coupleID)",
        difference = NULL
      ),
      model_frame = data.frame(other = 1:2)
    ),
    "Use `NULL` only if that block was omitted from the fitted model",
    fixed = TRUE
  )
  expect_no_warning(
    difference_only <- match_supplied_exchangeable_residual_blocks(
      blocks,
      list(
        shared = NULL,
        difference = paste0(
          "(0 + ", marker, " + ", marker, ":time || coupleID:day)"
        ),
        difference_indicator = marker
      )
    )
  )
  matched <- c(shared_only, difference_only)

  expect_equal(matched[[1L]]$shared_block_index, 1L)
  expect_true(is.na(matched[[1L]]$difference_block_index))
  expect_null(matched[[1L]]$difference_indicator)
  expect_equal(matched[[1L]]$underlying_terms, c("(Intercept)", "time"))
  expect_equal(matched[[1L]]$shared_term_indices, c(1L, 2L))
  expect_true(all(is.na(matched[[1L]]$difference_term_indices)))

  expect_true(is.na(matched[[2L]]$shared_block_index))
  expect_equal(matched[[2L]]$difference_block_index, 2L)
  expect_equal(matched[[2L]]$underlying_terms, c("time", "(Intercept)"))
  expect_true(all(is.na(matched[[2L]]$shared_term_indices)))
  expect_equal(matched[[2L]]$difference_term_indices, c(1L, 2L))

  aligned_shared_only <- align_exchangeable_pair_covariances(
    blocks,
    matched[[1L]]
  )
  expect_equal(
    unname(aligned_shared_only$shared),
    unname(shared_covariance)
  )
  expect_true(all(aligned_shared_only$difference == 0))

  aligned_difference_only <- align_exchangeable_pair_covariances(
    blocks,
    matched[[2L]]
  )
  expect_true(all(aligned_difference_only$shared == 0))
  expect_equal(
    unname(aligned_difference_only$difference),
    unname(difference_covariance)
  )
})

test_that("aligned covariance arrays back-transform to member coordinates", {
  terms <- c("(Intercept)", "time")
  shared <- array(0, dim = c(2, 2, 2))
  difference <- array(0, dim = c(2, 2, 2))

  shared[1, , ] <- matrix(c(1.2, 0.2, 0.2, 0.8), 2)
  difference[1, , ] <- matrix(c(0.3, 0.1, 0.1, 0.4), 2)
  shared[2, , ] <- matrix(c(2.0, -0.1, -0.1, 1.0), 2)
  difference[2, , ] <- matrix(c(0.5, 0.2, 0.2, 0.6), 2)

  varcov <- backtransform_exchangeable_covariances(
    list(shared = shared, difference = difference),
    terms
  )
  expect_equal(dim(varcov), c(2L, 4L, 4L))
  expect_equal(
    dimnames(varcov)[2:3],
    rep(list(c(
      "member_1: (Intercept)", "member_1: time",
      "member_2: (Intercept)", "member_2: time"
    )), 2L)
  )

  # Compare both draws with the equivalent matrix expression
  # T %*% diag(shared, difference) %*% t(T).
  identity <- diag(2)
  transformation <- rbind(
    cbind(identity, identity),
    cbind(identity, -identity)
  )
  for (draw in 1:2) {
    component_covariance <- matrix(0, 4, 4)
    component_covariance[1:2, 1:2] <- shared[draw, , ]
    component_covariance[3:4, 3:4] <- difference[draw, , ]
    expected <- transformation %*%
      component_covariance %*%
      t(transformation)
    transformed <- unname(varcov[draw, , ])
    expect_equal(transformed, expected)
    expect_true(isSymmetric(transformed))
    expect_true(all(
      eigen(transformed, symmetric = TRUE, only.values = TRUE)$values >=
        -sqrt(.Machine$double.eps)
    ))
  }
})

test_that("the SD-correlation representation handles boundaries explicitly", {
  shared <- array(1.2, dim = c(1, 1, 1))
  difference <- array(0.3, dim = c(1, 1, 1))
  varcov <- backtransform_exchangeable_covariances(
    list(shared = shared, difference = difference),
    "(Intercept)"
  )
  sdcor <- covariance_array_to_sdcor(varcov)

  expect_equal(
    unname(varcov[1, , ]),
    matrix(c(1.5, 0.9, 0.9, 1.5), 2)
  )
  expect_equal(unname(diag(sdcor[1, , ])), rep(sqrt(1.5), 2))
  expect_equal(sdcor[1, 1, 2], 0.6)
  expect_equal(sdcor[1, 2, 1], 0.6)

  equal_components <- backtransform_exchangeable_covariances(
    list(
      shared = array(1, dim = c(1, 1, 1)),
      difference = array(1, dim = c(1, 1, 1))
    ),
    "(Intercept)"
  )
  expect_equal(covariance_array_to_sdcor(equal_components)[1, 1, 2], 0)

  difference_only <- backtransform_exchangeable_covariances(
    list(
      shared = array(0, dim = c(1, 1, 1)),
      difference = array(1, dim = c(1, 1, 1))
    ),
    "(Intercept)"
  )
  expect_equal(covariance_array_to_sdcor(difference_only)[1, 1, 2], -1)

  zero_variance <- array(
    matrix(c(0, 0, 0, 1), 2),
    dim = c(1, 2, 2)
  )
  zero_sdcor <- covariance_array_to_sdcor(zero_variance)
  expect_equal(diag(zero_sdcor[1, , ]), c(0, 1))
  expect_true(is.na(zero_sdcor[1, 1, 2]))
  expect_true(is.na(zero_sdcor[1, 2, 1]))

  negative_variance <- zero_variance
  negative_variance[1, 1, 1] <- -0.1
  expect_error(
    covariance_array_to_sdcor(negative_variance),
    "contains a negative variance",
    fixed = TRUE
  )
})

test_that("back-transformation validates aligned covariance arrays", {
  symmetric <- array(
    matrix(c(1, 0.2, 0.2, 1), 2),
    dim = c(1, 2, 2)
  )
  asymmetric <- symmetric
  asymmetric[1, 1, 2] <- 0.4

  expect_error(
    backtransform_exchangeable_covariances(
      list(shared = asymmetric, difference = symmetric),
      c("(Intercept)", "time")
    ),
    "shared covariance array must be symmetric",
    fixed = TRUE
  )

  nonfinite <- symmetric
  nonfinite[1, 1, 1] <- NA_real_
  expect_error(
    backtransform_exchangeable_covariances(
      list(shared = nonfinite, difference = symmetric),
      c("(Intercept)", "time")
    ),
    "must be finite arrays with identical draw and square term dimensions",
    fixed = TRUE
  )
})

test_that("omitted blocks are checked without rejecting disjoint pairs", {
  blocks <- list(
    rescov_test_block("coupleID", "time", "shared time"),
    rescov_test_block("coupleID", "IDIFF:support", "difference support")
  )
  expect_no_warning(
    matched <- match_supplied_exchangeable_residual_blocks(
      blocks,
      list(
        list(
          shared = "shared time",
          difference = NULL,
          difference_indicator = "IDIFF"
        ),
        list(
          shared = NULL,
          difference = "difference support",
          difference_indicator = "IDIFF"
        )
      )
    )
  )
  expect_length(matched, 2L)

  malformed_difference <- list(
    rescov_test_block("coupleID", "(Intercept)", "shared"),
    rescov_test_block(
      "coupleID",
      c("IDIFF", "time"),
      "partial difference"
    )
  )
  expect_error(
    match_supplied_exchangeable_residual_blocks(
      malformed_difference,
      list(shared = "shared", difference = NULL, difference_indicator = "IDIFF")
    ),
    "`pairs$difference` is `NULL`, but a compatible fitted block exists",
    fixed = TRUE
  )

  unsupported_product <- list(
    rescov_test_block("coupleID", "time", "shared"),
    rescov_test_block(
      "coupleID",
      "I(IDIFF * time^2)",
      "unsupported difference"
    )
  )
  expect_error(
    match_supplied_exchangeable_residual_blocks(
      unsupported_product,
      list(shared = "shared", difference = NULL, difference_indicator = "IDIFF")
    ),
    "`pairs$difference` is `NULL`, but a compatible fitted block exists",
    fixed = TRUE
  )

  malformed_shared <- list(
    rescov_test_block(
      "coupleID",
      c("SAMESEX", "time"),
      "partial shared"
    ),
    rescov_test_block("coupleID", "IDIFF", "difference")
  )
  expect_error(
    match_supplied_exchangeable_residual_blocks(
      malformed_shared,
      list(
        shared = NULL,
        difference = "difference",
        difference_indicator = "IDIFF",
        shared_indicator = "SAMESEX"
      )
    ),
    "`pairs$shared` is `NULL`, but a compatible fitted block exists",
    fixed = TRUE
  )
})

test_that("model-style selectors preserve covariance structures", {
  marker <- ".i_diff_assumed_exchangeable_arbitrary"
  blocks <- list(
    rescov_test_block(
      "coupleID",
      c("time", "(Intercept)"),
      "us(time + 1 | coupleID)"
    ),
    rescov_test_block(
      "coupleID",
      c(paste0(marker, ":time"), marker),
      paste0("diag(0 + ", marker, ":time + ", marker, " | coupleID)")
    )
  )

  pair <- match_supplied_exchangeable_residual_blocks(
    blocks,
    list(
      shared = "(1 + time | coupleID)",
      difference = paste0(
        "(0 + ", marker, " + time:", marker, " || coupleID)"
      ),
      difference_indicator = marker
    )
  )[[1L]]
  expect_equal(pair$shared_block_index, 1L)
  expect_equal(pair$difference_block_index, 2L)
  expect_equal(pair$difference_term_indices, c(1L, 2L))

  expect_equal(
    canonicalize_exchangeable_block_term("homdiag(0 + x | group)"),
    "homdiag(0+x|group)"
  )
  expect_false(identical(
    canonicalize_exchangeable_block_term("homdiag(0 + x | group)"),
    canonicalize_exchangeable_block_term("(0 + x || group)")
  ))

  ambiguous <- list(
    rescov_test_block(
      "coupleID",
      c("(Intercept)", "time"),
      "us(time + 1 | coupleID)"
    ),
    rescov_test_block(
      "coupleID",
      c("(Intercept)", "time"),
      "us(1 + time | coupleID)"
    ),
    rescov_test_block("coupleID", marker, "difference")
  )
  expect_error(
    match_supplied_exchangeable_residual_blocks(
      ambiguous,
      list(
        shared = "(1+time | coupleID)",
        difference = "difference",
        difference_indicator = marker
      )
    ),
    "Refit without duplicate equivalent random-effect blocks",
    fixed = TRUE
  )
})

test_that("supplied pairs accept arbitrary difference-indicator names", {
  pair <- list(
    shared = "(1 | coupleID)",
    difference = "(0 + hallelujah | coupleID)",
    difference_indicator = "hallelujah"
  )

  single <- normalize_supplied_exchangeable_pairs(pair)
  expect_equal(single[[1L]]$difference_indicator, "hallelujah")
  expect_equal(single[[1L]]$shared_indicator, "1")
  expect_equal(attr(single, "pair_labels"), "`pairs`")

  multiple <- normalize_supplied_exchangeable_pairs(list(
    stable = pair,
    shared = pair
  ))
  expect_equal(names(multiple), c("stable", "shared"))
  expect_equal(
    attr(multiple, "pair_labels"),
    c("`pairs[[\"stable\"]]`", "`pairs[[\"shared\"]]`")
  )
})

test_that("supplied pair specifications fail clearly", {
  blocks <- list(
    rescov_test_block("coupleID", "(Intercept)", "shared"),
    rescov_test_block("coupleID", "IDIFF", "difference"),
    rescov_test_block("study", "(Intercept)", "study")
  )

  expect_error(
    match_supplied_exchangeable_residual_blocks(
      blocks,
      list(shared = "shared", difference = "difference")
    ),
    paste0(
      "`pairs` is missing required field `difference_indicator`. Set it to ",
      "the exact name of the -1/+1 difference-indicator column used in the ",
      "selected difference block, for example ",
      "`difference_indicator = \"hallelujah\"`."
    ),
    fixed = TRUE
  )
  expect_error(
    match_supplied_exchangeable_residual_blocks(
      blocks,
      list(list(shared = "shared", difference = "difference"))
    ),
    "`pairs[[1]]` is missing required field `difference_indicator`",
    fixed = TRUE
  )
  expect_error(
    normalize_supplied_exchangeable_pairs(list(
      shared = "shared",
      difference = "difference",
      difference_indicator = NULL
    )),
    "`pairs` is missing required field `difference_indicator`",
    fixed = TRUE
  )
  omitted_difference <- normalize_supplied_exchangeable_pairs(
    list(shared = "shared", difference = NULL)
  )
  expect_null(omitted_difference[[1L]]$difference_indicator)
  expect_error(
    match_supplied_exchangeable_residual_blocks(
      blocks,
      list(
        shared = "shared",
        difference = "difference",
        idif = "IDIFF"
      )
    ),
    paste0(
      "`pairs` contains unknown field `idif`. Allowed fields are `shared`, ",
      "`difference`, `difference_indicator`, `shared_indicator`."
    ),
    fixed = TRUE
  )
  expect_error(
    match_supplied_exchangeable_residual_blocks(
      blocks,
      list(shared_indicator = "1")
    ),
    "`pairs` is missing required fields `shared`, `difference`.",
    fixed = TRUE
  )
  expect_error(
    match_supplied_exchangeable_residual_blocks(
      blocks,
      list(
        shared = "unknown",
        difference = "difference",
        difference_indicator = "IDIFF"
      )
    ),
    "Copy the intended term from the available blocks below",
    fixed = TRUE
  )
  expect_error(
    match_supplied_exchangeable_residual_blocks(
      blocks,
      list(
        shared = "study",
        difference = "difference",
        difference_indicator = "IDIFF"
      )
    ),
    "shared block groups by `study`, but the selected difference block groups by `coupleID`",
    fixed = TRUE
  )

  transformed <- list(
    rescov_test_block("coupleID", c("(Intercept)", "time"), "shared"),
    rescov_test_block(
      "coupleID",
      c("IDIFF", "I(IDIFF * time^2)"),
      "difference"
    )
  )
  expect_error(
    match_supplied_exchangeable_residual_blocks(
      transformed,
      list(
        shared = "shared",
        difference = "difference",
        difference_indicator = "IDIFF"
      )
    ),
    "must identify every coefficient",
    fixed = TRUE
  )

  expect_error(
    match_supplied_exchangeable_residual_blocks(
      blocks,
      list(shared = NULL, difference = NULL, difference_indicator = "IDIFF")
    ),
    "cannot set both `shared` and `difference` to `NULL`",
    fixed = TRUE
  )

  expect_error(
    match_supplied_exchangeable_residual_blocks(
      blocks,
      list(shared = "shared", difference = NULL, difference_indicator = "IDIFF")
    ),
    "`pairs$difference` is `NULL`, but a compatible fitted block exists",
    fixed = TRUE
  )
  expect_error(
    match_supplied_exchangeable_residual_blocks(
      blocks,
      list(shared = NULL, difference = "difference", difference_indicator = "IDIFF")
    ),
    "`pairs$shared` is `NULL`, but a compatible fitted block exists",
    fixed = TRUE
  )
  expect_error(
    match_supplied_exchangeable_residual_blocks(
      blocks,
      list(shared = "difference", difference = NULL, difference_indicator = "IDIFF")
    ),
    "selected shared block contains the difference indicator `IDIFF`",
    fixed = TRUE
  )

  repeated_pair <- list(
    shared = "shared",
    difference = "difference",
    difference_indicator = "IDIFF"
  )
  expect_error(
    match_supplied_exchangeable_residual_blocks(
      blocks,
      list(repeated_pair, repeated_pair)
    ),
    "Reused blocks: `shared`, `difference`. Remove each reused block",
    fixed = TRUE
  )
})

test_that("named supplied pairs retain their labels in downstream diagnostics", {
  blocks <- list(
    rescov_test_block("coupleID", "(Intercept)", "shared"),
    rescov_test_block("coupleID", "IDIFF", "difference"),
    rescov_test_block("study", "(Intercept)", "study")
  )

  expect_error(
    match_supplied_exchangeable_residual_blocks(
      blocks,
      list(stable = list(
        shared = "study",
        difference = "difference",
        difference_indicator = "IDIFF"
      ))
    ),
    paste0(
      "`pairs[[\"stable\"]]`: The selected shared block groups by `study`, ",
      "but the selected difference block groups by `coupleID`"
    ),
    fixed = TRUE
  )

  malformed_coefficients <- list(
    rescov_test_block("coupleID", "(Intercept)", "shared"),
    rescov_test_block(
      "coupleID",
      c("IDIFF", "I(IDIFF * time^2)"),
      "difference"
    )
  )
  expect_error(
    match_supplied_exchangeable_residual_blocks(
      malformed_coefficients,
      list(stable = list(
        shared = "shared",
        difference = "difference",
        difference_indicator = "IDIFF"
      ))
    ),
    "`pairs[[\"stable\"]]`: Difference indicator `IDIFF` must identify every coefficient",
    fixed = TRUE
  )

  stable_pair <- list(
    shared = "shared",
    difference = "difference",
    difference_indicator = "IDIFF"
  )
  expect_warning(
    match_supplied_exchangeable_residual_blocks(
      blocks,
      list(stable = stable_pair),
      model_frame = data.frame(other = 1:2)
    ),
    "`pairs[[\"stable\"]]`: `IDIFF` was not retained",
    fixed = TRUE
  )
  expect_error(
    match_supplied_exchangeable_residual_blocks(
      blocks,
      list(stable = stable_pair),
      model_frame = data.frame(IDIFF = c(1, 1))
    ),
    "`pairs[[\"stable\"]]`: `IDIFF` must contain both -1 and +1",
    fixed = TRUE
  )

  expect_error(
    match_supplied_exchangeable_residual_blocks(
      blocks,
      list(stable = stable_pair, follow_up = stable_pair)
    ),
    paste0(
      "Pair assignments: `shared` in `pairs[[\"stable\"]]`, ",
      "`pairs[[\"follow_up\"]]`"
    ),
    fixed = TRUE
  )
})

test_that("fitted-row validation protects the exchangeable coding", {
  valid <- data.frame(
    IDIFF = c(-1, 1, 0, 0),
    SAMESEX = c(1, 1, 0, 0)
  )
  expect_no_error(validate_exchangeable_coding(valid, "IDIFF", "SAMESEX"))
  expect_no_error(validate_exchangeable_coding(
    data.frame(IDIFF = c(-1, 1)),
    "IDIFF",
    "1"
  ))
  expect_warning(
    validate_exchangeable_coding(
      data.frame(other = 1:2),
      "IDIFF",
      "1"
    ),
    "Before interpreting the result, verify",
    fixed = TRUE
  )
  expect_warning(
    validate_exchangeable_coding(
      data.frame(IDIFF = c(-1, 1)),
      "IDIFF",
      "SAMESEX"
    ),
    "coded 1 exactly where `abs(IDIFF) == 1` and 0 elsewhere",
    fixed = TRUE
  )

  character_coding <- valid
  character_coding$IDIFF <- as.character(character_coding$IDIFF)
  expect_error(
    validate_exchangeable_coding(character_coding, "IDIFF", "SAMESEX"),
    "`IDIFF` and `SAMESEX` must be complete numeric columns",
    fixed = TRUE
  )
  expect_warning(
    expect_error(
      validate_exchangeable_coding(
        character_coding["IDIFF"],
        "IDIFF",
        "SAMESEX"
      ),
      "must be complete numeric columns",
      fixed = TRUE
    ),
    "support could not be checked",
    fixed = TRUE
  )

  wrong_scale <- valid
  wrong_scale$IDIFF <- wrong_scale$IDIFF / 2
  expect_error(
    validate_exchangeable_coding(wrong_scale, "IDIFF", "SAMESEX"),
    "must use -1/+1 coding",
    fixed = TRUE
  )

  wrong_support <- valid
  wrong_support$IDIFF[[3L]] <- 1
  expect_error(
    validate_exchangeable_coding(wrong_support, "IDIFF", "SAMESEX"),
    "must use -1/+1 coding",
    fixed = TRUE
  )

  one_sign <- data.frame(IDIFF = c(1, 1), SAMESEX = c(1, 1))
  expect_error(
    validate_exchangeable_coding(one_sign, "IDIFF", "SAMESEX"),
    "whether fitted-row filtering removed one member position",
    fixed = TRUE
  )

  marker <- ".i_diff_same_sex_arbitrary"
  generic_blocks <- list(
    rescov_test_block("coupleID", "(Intercept)", "generic shared"),
    rescov_test_block("coupleID", marker, "difference")
  )
  model_frame <- data.frame(value = seq_len(4))
  model_frame[[marker]] <- c(-1, 1, 0, 0)
  expect_error(
    match_exchangeable_residual_blocks(generic_blocks, model_frame),
    "must use -1/+1 coding",
    fixed = TRUE
  )
})

test_that("levels with at most two fitted observations are flagged", {
  blocks <- list(
    rescov_test_block("coupleID", "(Intercept)", "(1 | coupleID)"),
    rescov_test_block("coupleID", "IDIFF", "(0 + IDIFF | coupleID)")
  )
  pair <- build_exchangeable_pair(blocks, 1L, 2L, "IDIFF", "1")
  extracted <- list(
    backend = "glmmTMB",
    blocks = blocks,
    group_ids = list(coupleID = rep(seq_len(3L), each = 2L))
  )

  expect_true(may_be_exchangeable_residual_level(extracted, pair))

  extracted$group_ids$coupleID <- c(1, 1, 1, 1, 2, 2)
  expect_false(may_be_exchangeable_residual_level(extracted, pair))

  # The detector deliberately uses only row counts. It therefore remains
  # cautious even when all fitted grouping units are singletons.
  extracted$group_ids$coupleID <- seq_len(6L)
  expect_true(may_be_exchangeable_residual_level(extracted, pair))

  extracted$group_ids <- list()
  expect_false(may_be_exchangeable_residual_level(extracted, pair))
})

test_that("residual-level warnings explain brms, omissions, and slopes", {
  shared_covariance <- array(
    diag(c(1, 0.25)),
    dim = c(1L, 2L, 2L),
    dimnames = list(NULL, c("(Intercept)", "time"), c("(Intercept)", "time"))
  )
  difference_covariance <- array(
    0.5,
    dim = c(1L, 1L, 1L),
    dimnames = list(NULL, "IDIFF", "IDIFF")
  )
  blocks <- list(
    rescov_test_block(
      "coupleID",
      c("(Intercept)", "time"),
      "(1 + time | coupleID)",
      shared_covariance
    ),
    rescov_test_block(
      "coupleID",
      "IDIFF",
      "(0 + IDIFF | coupleID)",
      difference_covariance
    )
  )
  pair <- build_exchangeable_pair(blocks, 1L, 2L, "IDIFF", "1")
  extracted <- list(
    backend = "brms",
    blocks = blocks,
    group_ids = list(coupleID = rep(seq_len(3L), each = 2L))
  )

  warning_text <- NULL
  withCallingHandlers(
    warn_about_exchangeable_residual_level(
      extracted,
      list(same_occasion = pair)
    ),
    warning = function(warning) {
      warning_text <<- conditionMessage(warning)
      invokeRestart("muffleWarning")
    }
  )

  expect_match(
    warning_text,
    "pair `same_occasion` (`coupleID`) has at most two fitted observations",
    fixed = TRUE
  )
  expect_match(warning_text, "may therefore represent", fixed = TRUE)
  expect_match(warning_text, "The two member positions were not checked", fixed = TRUE)
  expect_match(warning_text, "For a Gaussian `brms` model", fixed = TRUE)
  expect_match(warning_text, "sigma ~ 1", fixed = TRUE)
  expect_match(warning_text, "unstr(time = member_position", fixed = TRUE)
  expect_match(
    warning_text,
    "omit components: difference = `time`",
    fixed = TRUE
  )
  expect_match(warning_text, "correlation +1", fixed = TRUE)
  expect_match(warning_text, "undefined at zero", fixed = TRUE)
  expect_match(
    warning_text,
    "contain non-intercept terms: `time`",
    fixed = TRUE
  )

  # The same coefficient blocks are ordinary higher-level random effects when
  # every dyad contributes repeated member observations.
  extracted$group_ids$coupleID <- rep(seq_len(2L), each = 3L)
  expect_no_warning(warn_about_exchangeable_residual_level(
    extracted,
    list(pair)
  ))

  # A wholly omitted difference block is still flagged even though no idiff
  # term or member-position column exists in the fitted model.
  shared_only <- build_exchangeable_pair(
    blocks,
    1L,
    NA_integer_,
    NULL,
    "1"
  )
  extracted$backend <- "glmmTMB"
  extracted$group_ids$coupleID <- rep(seq_len(3L), each = 2L)
  expect_warning(
    warn_about_exchangeable_residual_level(
      extracted,
      list(shared_only = shared_only)
    ),
    "difference = `(Intercept)`, `time`",
    fixed = TRUE
  )
})

test_that("the public function returns member-level glmmTMB matrices", {
  skip_if_not_installed("glmmTMB")

  marker <- ".i_diff_assumed_exchangeable_arbitrary"
  data <- expand.grid(member = c(-1, 1), coupleID = seq_len(30))
  data$coupleID <- factor(data$coupleID)
  data[[marker]] <- data$member
  set.seed(456)
  data$outcome <- stats::rnorm(nrow(data))

  model <- suppressWarnings(glmmTMB::glmmTMB(
    outcome ~ 1 + (1 | coupleID) +
      (0 + .i_diff_assumed_exchangeable_arbitrary || coupleID),
    dispformula = ~0,
    data = data
  ))
  result <- exchangeable_rescov(model)
  extracted <- glmmTMB_extract_exchangeable_residual_blocks(model)
  shared_variance <- extracted$blocks[[1L]]$covariance[1L, 1L, 1L]
  difference_variance <- extracted$blocks[[2L]]$covariance[1L, 1L, 1L]
  member_variance <- shared_variance + difference_variance
  member_covariance <- shared_variance - difference_variance

  expect_s3_class(result, "exchangeable_rescov")
  expect_length(result, 1L)
  expect_named(result[[1L]], c("varcov", "sdcor"))
  expect_true(is.matrix(result[[1L]]$varcov))
  expect_true(is.matrix(result[[1L]]$sdcor))
  expect_equal(
    unname(result[[1L]]$varcov),
    matrix(
      c(
        member_variance, member_covariance,
        member_covariance, member_variance
      ),
      2L
    )
  )
  expect_equal(
    unname(diag(result[[1L]]$sdcor)),
    rep(sqrt(member_variance), 2L)
  )
  expect_equal(
    result[[1L]]$sdcor[1L, 2L],
    member_covariance / member_variance
  )
  expect_true(grepl(
    extracted$blocks[[1L]]$term,
    names(result),
    fixed = TRUE
  ))
  expect_true(grepl(
    extracted$blocks[[2L]]$term,
    names(result),
    fixed = TRUE
  ))
})

test_that("the public function retains brms draws and labels omitted blocks", {
  data <- data.frame(outcome = 1:4, IDIFF = rep(c(-1, 1), 2L))
  model <- stats::lm(outcome ~ IDIFF, data = data)
  shared_draws <- array(c(1.2, 0), dim = c(2, 1, 1))
  difference_draws <- array(c(0.4, 0.8), dim = c(2, 1, 1))
  extracted <- list(
    backend = "brms",
    blocks = list(
      rescov_test_block(
        "coupleID",
        "(Intercept)",
        "(1 | coupleID)",
        shared_draws
      ),
      rescov_test_block(
        "familyID",
        "IDIFF",
        "(0 + IDIFF | familyID)",
        difference_draws
      )
    )
  )

  expect_warning(
    result <- testthat::with_mocked_bindings(
      exchangeable_rescov(
        model,
        pairs = list(
          shared_only = list(
            shared = "(1 | coupleID)",
            difference = NULL,
            difference_indicator = "IDIFF"
          ),
          difference_only = list(
            shared = NULL,
            difference = "(0 + IDIFF | familyID)",
            difference_indicator = "IDIFF"
          )
        )
      ),
      extract_exchangeable_residual_blocks = function(model) extracted,
      .package = "interdep"
    ),
    "standard deviation is zero",
    fixed = TRUE
  )

  expect_s3_class(result, "exchangeable_rescov")
  expect_length(result, 2L)
  expect_equal(dim(result[[1L]]$varcov), c(2L, 2L, 2L))
  expect_equal(dim(result[[1L]]$sdcor), c(2L, 2L, 2L))
  expect_equal(
    unname(result[[1L]]$varcov[1L, , ]),
    matrix(1.2, 2L, 2L)
  )
  expect_equal(result[[1L]]$sdcor[1L, 1L, 2L], 1)
  expect_true(is.na(result[[1L]]$sdcor[2L, 1L, 2L]))
  expect_equal(
    unname(result[[2L]]$varcov[1L, , ]),
    matrix(c(0.4, -0.4, -0.4, 0.4), 2L)
  )
  expect_equal(result[[2L]]$sdcor[1L, 1L, 2L], -1)
  expect_true(grepl(
    "difference: <omitted>",
    names(result)[[1L]],
    fixed = TRUE
  ))
  expect_true(grepl(
    "shared: <omitted>",
    names(result)[[2L]],
    fixed = TRUE
  ))
})

test_that("exchangeable covariance results print without repeated list paths", {
  pair_name <- paste0(
    "shared: us(1 | coupleID); difference: ",
    "us(0 + IDIFF | coupleID)"
  )
  varcov <- matrix(
    c(1.5, 0.9, 0.9, 1.5),
    2L,
    dimnames = rep(list(c("member_1", "member_2")), 2L)
  )
  sdcor <- matrix(
    c(sqrt(1.5), 0.6, 0.6, sqrt(1.5)),
    2L,
    dimnames = dimnames(varcov)
  )
  result <- structure(
    setNames(list(list(varcov = varcov, sdcor = sdcor)), pair_name),
    class = c("exchangeable_rescov", "list")
  )

  printed <- capture.output(returned <- print(result))
  expect_identical(returned, result)
  expect_true(any(grepl("Shared:     us(1 | coupleID)", printed, fixed = TRUE)))
  expect_true(any(grepl(
    "Difference: us(0 + IDIFF | coupleID)",
    printed,
    fixed = TRUE
  )))
  expect_equal(sum(grepl("us(1 | coupleID)", printed, fixed = TRUE)), 1L)
  expect_true(any(grepl("Variance-covariance:", printed, fixed = TRUE)))
  expect_true(any(grepl(
    "Standard deviations and correlations:",
    printed,
    fixed = TRUE
  )))

  varcov_only <- capture.output(print(result, "varcov"))
  expect_true(any(grepl("Variance-covariance:", varcov_only, fixed = TRUE)))
  expect_false(any(grepl(
    "Standard deviations and correlations:",
    varcov_only,
    fixed = TRUE
  )))

  sdcor_only <- capture.output(print(result, what = "sdcor"))
  expect_false(any(grepl("Variance-covariance:", sdcor_only, fixed = TRUE)))
  expect_true(any(grepl(
    "Standard deviations and correlations:",
    sdcor_only,
    fixed = TRUE
  )))

  multiple <- structure(
    c(unclass(result), unclass(result)),
    class = c("exchangeable_rescov", "list")
  )
  names(multiple) <- c(
    pair_name,
    "shared: us(1 | familyID); difference: us(0 + IDIFF | familyID)"
  )
  multiple_printed <- capture.output(print(multiple, what = "varcov"))
  expect_true(any(grepl(
    "Exchangeable residual covariances (2 block pairs)",
    multiple_printed,
    fixed = TRUE
  )))
  expect_equal(sum(multiple_printed == "Pair 1"), 1L)
  expect_equal(sum(multiple_printed == "Pair 2"), 1L)
})

test_that("printing brms results does not dump posterior draw arrays", {
  draws <- array(
    1,
    dim = c(5, 2, 2),
    dimnames = list(NULL, c("member_1", "member_2"), c("member_1", "member_2"))
  )
  result <- structure(
    list(
      "shared: (1 | coupleID); difference: <omitted>" = list(
        varcov = draws,
        sdcor = draws
      )
    ),
    class = c("exchangeable_rescov", "list")
  )

  printed <- capture.output(print(result, what = "sdcor"))
  expect_true(any(grepl(
    "5 posterior draws x 2 coefficients x 2 coefficients",
    printed,
    fixed = TRUE
  )))
  expect_true(any(grepl(
    "Extract with `x[[1]]$sdcor`",
    printed,
    fixed = TRUE
  )))
})
