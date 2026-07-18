test_that("random-effect blocks have a common backend-independent structure", {
  skip_if_not_installed("glmmTMB")
  skip_if_not_installed("brms")

  data <- expand.grid(
    member = c(-1, 1),
    day = 0:3,
    coupleID = seq_len(30)
  )
  data <- data[order(data$coupleID, data$day, data$member), ]
  data$coupleID <- factor(data$coupleID)
  data$familyID <- factor((as.integer(data$coupleID) - 1L) %/% 3L + 1L)
  data$idiff <- data$member
  data$shared2 <- 1
  data$diff2 <- data$member
  data$occasion_shared <- 1
  data$occasion_diff <- data$member
  set.seed(123)
  data$outcome <- stats::rnorm(nrow(data))

  glmm_model <- suppressWarnings(glmmTMB::glmmTMB(
    outcome ~ 1 +
      (1 + day | coupleID) +
      (0 + idiff + idiff:day || coupleID) +
      (0 + shared2 | familyID) +
      homdiag(0 + diff2 | familyID) +
      (0 + occasion_shared | coupleID:day) +
      (0 + occasion_diff || coupleID:day),
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

  couple_sd <- matrix(
    seq(1, 2.1, length.out = 12),
    nrow = 3,
    dimnames = list(NULL, c("Intercept", "day", "idiff", "idiff:day"))
  )
  couple_cov <- array(
    0,
    dim = c(3, 4, 4),
    dimnames = list(
      NULL,
      c("Intercept", "day", "idiff", "idiff:day"),
      c("Intercept", "day", "idiff", "idiff:day")
    )
  )
  for (j in seq_len(4)) {
    couple_cov[, j, j] <- couple_sd[, j]^2
  }
  couple_cov[, 1, 2] <- 0.2
  couple_cov[, 2, 1] <- 0.2

  family_sd <- matrix(
    seq(0.5, 1, length.out = 6),
    nrow = 3,
    dimnames = list(NULL, c("shared2", "diff2"))
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

  expect_named(glmm_blocks, c("backend", "blocks"))
  expect_named(brms_blocks, c("backend", "blocks"))
  expect_length(glmm_blocks$blocks, 6)
  expect_length(brms_blocks$blocks, 4)

  is_residual_block <- vapply(
    glmm_blocks$blocks,
    function(block) identical(block$group, "coupleID:day"),
    logical(1)
  )
  expect_equal(sum(is_residual_block), 2)
  glmm_common_blocks <- glmm_blocks$blocks[!is_residual_block]

  descriptor <- function(block) {
    block[c("group", "coefficients", "correlated")]
  }
  expect_equal(
    lapply(glmm_common_blocks, descriptor),
    lapply(brms_blocks$blocks, descriptor)
  )
  expect_equal(
    lapply(glmm_common_blocks, names),
    lapply(brms_blocks$blocks, names)
  )

  for (i in seq_along(glmm_common_blocks)) {
    expect_equal(dim(glmm_common_blocks[[i]]$covariance)[1], 1)
    expect_equal(dim(brms_blocks$blocks[[i]]$covariance)[1], 3)
    expect_equal(
      dim(glmm_common_blocks[[i]]$covariance)[2:3],
      dim(brms_blocks$blocks[[i]]$covariance)[2:3]
    )
  }

  expect_equal(
    unname(brms_blocks$blocks[[1]]$covariance),
    unname(couple_cov[, 1:2, 1:2, drop = FALSE])
  )
  expect_equal(
    unname(brms_blocks$blocks[[2]]$covariance),
    unname(couple_cov[, 3:4, 3:4, drop = FALSE])
  )
  expect_equal(
    unname(brms_blocks$blocks[[3]]$covariance[, 1, 1]),
    family_sd[, 1]^2
  )
  expect_equal(
    unname(brms_blocks$blocks[[4]]$covariance[, 1, 1]),
    family_sd[, 2]^2
  )

  fitted_glmm_covariance <- glmmTMB::VarCorr(glmm_model)$cond
  expect_equal(
    as.numeric(glmm_blocks$blocks[[1]]$covariance[1, , ]),
    as.numeric(fitted_glmm_covariance[[1]])
  )

  expect_equal(
    vapply(glmm_common_blocks, `[[`, logical(1), "correlated"),
    c(TRUE, FALSE, TRUE, FALSE)
  )
  expect_equal(
    vapply(glmm_common_blocks, `[[`, character(1), "term"),
    c(
      "us(1 + day | coupleID)",
      "diag(0 + idiff + idiff:day | coupleID)",
      "us(0 + shared2 | familyID)",
      "homdiag(0 + diff2 | familyID)"
    )
  )
  expect_equal(
    vapply(brms_blocks$blocks, `[[`, character(1), "term"),
    c(
      "(1 + day | coupleID)",
      "(0 + idiff + idiff:day || coupleID)",
      "(0 + shared2 | familyID)",
      "(0 + diff2 || familyID)"
    )
  )

  uncorrelated_model <- brms::brm(
    outcome ~ 1 + (0 + idiff + idiff:day || coupleID),
    data = data,
    empty = TRUE
  )
  uncorrelated_sd <- couple_sd[, 3:4, drop = FALSE]
  uncorrelated_blocks <- testthat::with_mocked_bindings(
    brms_extract_exchangeable_residual_blocks(uncorrelated_model),
    VarCorr = function(...) {
      list(coupleID = list(sd = uncorrelated_sd))
    },
    .package = "brms"
  )
  expected_uncorrelated_covariance <- array(0, dim = c(3, 2, 2))
  expected_uncorrelated_covariance[, 1, 1] <- uncorrelated_sd[, 1]^2
  expected_uncorrelated_covariance[, 2, 2] <- uncorrelated_sd[, 2]^2
  expect_equal(
    unname(uncorrelated_blocks$blocks[[1]]$covariance),
    expected_uncorrelated_covariance
  )
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

  multivariate_model <- brms::brm(
    brms::bf(outcome ~ 1 + (1 | couple)) +
      brms::bf(second_outcome ~ 1 + (1 | couple)) +
      brms::set_rescor(FALSE),
    data = data,
    empty = TRUE
  )
  expect_error(
    brms_extract_exchangeable_residual_blocks(multivariate_model),
    "must contain a single response",
    fixed = TRUE
  )

  linked_terms_model <- brms::brm(
    outcome ~ 1 + (1 | block | couple) + (0 + time | block | couple),
    data = data,
    empty = TRUE
  )
  expect_error(
    brms_extract_exchangeable_residual_blocks(linked_terms_model),
    "more than one formula term",
    fixed = TRUE
  )

  by_model <- brms::brm(
    outcome ~ 1 + (1 + time | gr(couple, by = role)),
    data = data,
    empty = TRUE
  )
  expect_error(
    brms_extract_exchangeable_residual_blocks(by_model),
    "using `gr(..., by = ...)`",
    fixed = TRUE
  )
})

test_that("brms distributional and nonlinear random effects are ignored", {
  skip_if_not_installed("brms")

  data <- data.frame(
    outcome = stats::rnorm(20),
    couple = factor(rep(seq_len(10), each = 2)),
    time = rep(0:1, 10)
  )

  distributional_model <- brms::brm(
    brms::bf(
      outcome ~ 1 + (1 + time | mean | couple),
      sigma ~ 1 + (1 | scale | couple)
    ),
    data = data,
    empty = TRUE
  )
  sd_draws <- matrix(
    c(1, 2, 3, 1.1, 2.1, 3.1),
    nrow = 2,
    byrow = TRUE,
    dimnames = list(NULL, c("Intercept", "time", "sigma_Intercept"))
  )
  covariance <- array(
    0,
    dim = c(2, 3, 3),
    dimnames = list(
      NULL,
      c("Intercept", "time", "sigma_Intercept"),
      c("Intercept", "time", "sigma_Intercept")
    )
  )
  for (j in seq_len(3)) {
    covariance[, j, j] <- sd_draws[, j]^2
  }

  expect_warning(
    blocks <- testthat::with_mocked_bindings(
      brms_extract_exchangeable_residual_blocks(distributional_model),
      VarCorr = function(...) {
        list(couple = list(sd = sd_draws, cov = covariance))
      },
      .package = "brms"
    ),
    "were ignored",
    fixed = TRUE
  )

  expect_length(blocks$blocks, 1)
  expect_equal(blocks$blocks[[1]]$coefficients, c("(Intercept)", "time"))

  nonlinear_model <- brms::brm(
    brms::bf(
      outcome ~ alpha + beta * time,
      alpha ~ 1 + (1 | couple),
      beta ~ 1,
      nl = TRUE
    ),
    data = data,
    empty = TRUE
  )
  expect_warning(
    nonlinear_blocks <- testthat::with_mocked_bindings(
      brms_extract_exchangeable_residual_blocks(nonlinear_model),
      VarCorr = function(...) stop("VarCorr should not be called"),
      .package = "brms"
    ),
    "were ignored",
    fixed = TRUE
  )

  expect_length(nonlinear_blocks$blocks, 0)
})

test_that("complete exchangeable blocks are matched by group and terms", {
  block <- function(group, coefficients, term) {
    list(group = group, coefficients = coefficients, term = term)
  }
  model_data <- list(blocks = list(
    block("coupleID", c("time", "(Intercept)"), "dyad mean"),
    block(
      "coupleID",
      c(
        ".i_diff_assumed_exchangeable_arbitrary",
        "time:.i_diff_assumed_exchangeable_arbitrary"
      ),
      "member deviation"
    ),
    block("coupleID", "support", "unrelated"),
    block("study", c("(Intercept)", "time"), "other group")
  ))

  pairs <- match_exchangeable_residual_blocks(model_data$blocks)

  expect_length(pairs, 1)
  expect_equal(pairs[[1]]$dyad_mean_index, 1)
  expect_equal(pairs[[1]]$member_deviation_index, 2)
  expect_equal(pairs[[1]]$terms, c("time", "(Intercept)"))
  expect_equal(pairs[[1]]$member_deviation_order, c(2L, 1L))

  expect_equal(
    exchangeable_base_terms(
      "time:time:.i_diff_same_sex_arbitrary",
      ".i_diff_same_sex_arbitrary"
    ),
    "time:time"
  )
})

test_that("composition-specific blocks are matched in mixed models", {
  block <- function(group, coefficients, term) {
    list(group = group, coefficients = coefficients, term = term)
  }
  blocks <- list(
    block("coupleID", "(Intercept)", "generic"),
    block("coupleID", ".i_is_same_sex", "same-sex dyad mean"),
    block(
      "coupleID",
      ".i_diff_same_sex_arbitrary",
      "same-sex member deviation"
    ),
    block("coupleID", ".i_is_friends", "friends dyad mean"),
    block(
      "coupleID",
      ".i_diff_friends_arbitrary",
      "friends member deviation"
    )
  )

  pairs <- match_exchangeable_residual_blocks(blocks)

  expect_equal(
    pairs,
    list(
      list(
        dyad_mean_index = 2L,
        member_deviation_index = 3L,
        terms = "(Intercept)",
        member_deviation_order = 1L
      ),
      list(
        dyad_mean_index = 4L,
        member_deviation_index = 5L,
        terms = "(Intercept)",
        member_deviation_order = 1L
      )
    )
  )
})

test_that("composition-specific blocks are preferred in single-composition models", {
  blocks <- list(
    list(group = "coupleID", coefficients = "(Intercept)", term = "generic"),
    list(
      group = "coupleID",
      coefficients = ".i_is_same_sex",
      term = "dyad mean"
    ),
    list(
      group = "coupleID",
      coefficients = ".i_diff_same_sex_arbitrary",
      term = "member deviation"
    )
  )

  pairs <- match_exchangeable_residual_blocks(blocks)

  expect_equal(
    pairs,
    list(list(
      dyad_mean_index = 2L,
      member_deviation_index = 3L,
      terms = "(Intercept)",
      member_deviation_order = 1L
    ))
  )
})

test_that("one composition can be matched at multiple grouping levels", {
  block <- function(group, coefficients, term) {
    list(group = group, coefficients = coefficients, term = term)
  }
  blocks <- list(
    block("coupleID", "(Intercept)", "stable dyad mean"),
    block(
      "coupleID",
      ".i_diff_assumed_exchangeable_arbitrary",
      "stable member deviation"
    ),
    block("coupleID:day", "(Intercept)", "occasion dyad mean"),
    block(
      "coupleID:day",
      ".i_diff_assumed_exchangeable_arbitrary",
      "occasion member deviation"
    )
  )

  pairs <- match_exchangeable_residual_blocks(blocks)

  expect_equal(
    pairs,
    list(
      list(
        dyad_mean_index = 1L,
        member_deviation_index = 2L,
        terms = "(Intercept)",
        member_deviation_order = 1L
      ),
      list(
        dyad_mean_index = 3L,
        member_deviation_index = 4L,
        terms = "(Intercept)",
        member_deviation_order = 1L
      )
    )
  )
})

test_that("incomplete exchangeable blocks are not matched automatically", {
  model_data <- list(blocks = list(
    list(
      group = "coupleID",
      coefficients = c("(Intercept)", "time", "support"),
      term = "dyad mean"
    ),
    list(
      group = "coupleID",
      coefficients = c(
        ".i_diff_assumed_exchangeable_arbitrary",
        ".i_diff_assumed_exchangeable_arbitrary:time"
      ),
      term = "member deviation"
    )
  ))

  expect_error(
    match_exchangeable_residual_blocks(model_data$blocks),
    "No dyad-mean block matched the member-deviation block `member deviation`",
    fixed = TRUE
  )

  partial_member_deviation <- list(
    list(
      group = "coupleID",
      coefficients = c("(Intercept)", "time"),
      term = "dyad mean"
    ),
    list(
      group = "coupleID",
      coefficients = c(
        ".i_diff_assumed_exchangeable_arbitrary",
        "time"
      ),
      term = "partial member deviation"
    )
  )
  expect_error(
    match_exchangeable_residual_blocks(partial_member_deviation),
    "No dyad-mean block matched the member-deviation block `partial member deviation`",
    fixed = TRUE
  )
})

test_that("missing and ambiguous exchangeable structures fail clearly", {
  no_member_deviation <- list(list(
    group = "coupleID",
    coefficients = "(Intercept)",
    term = "dyad mean"
  ))
  expect_error(
    match_exchangeable_residual_blocks(no_member_deviation),
    "No supported `.i_diff_*_arbitrary` member-deviation block was found.",
    fixed = TRUE
  )

  ambiguous <- list(
    list(group = "coupleID", coefficients = "(Intercept)", term = "dyad mean 1"),
    list(group = "coupleID", coefficients = "(Intercept)", term = "dyad mean 2"),
    list(
      group = "coupleID",
      coefficients = ".i_diff_assumed_exchangeable_arbitrary",
      term = "member deviation"
    )
  )
  expect_error(
    match_exchangeable_residual_blocks(ambiguous),
    "More than one dyad-mean block matched the member-deviation block `member deviation`: `dyad mean 1`, `dyad mean 2`.",
    fixed = TRUE
  )

  reused_dyad_mean <- list(
    list(group = "coupleID", coefficients = "(Intercept)", term = "generic"),
    list(
      group = "coupleID",
      coefficients = ".i_is_same_sex",
      term = "dyad mean"
    ),
    list(
      group = "coupleID",
      coefficients = ".i_diff_same_sex_arbitrary",
      term = "member deviation 1"
    ),
    list(
      group = "coupleID",
      coefficients = ".i_diff_same_sex_arbitrary",
      term = "member deviation 2"
    )
  )
  expect_error(
    match_exchangeable_residual_blocks(reused_dyad_mean),
    "A dyad-mean block matched more than one member-deviation block.",
    fixed = TRUE
  )
})
