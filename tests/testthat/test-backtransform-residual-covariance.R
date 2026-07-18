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
})

test_that("unsupported brms random-effect structures fail clearly", {
  skip_if_not_installed("brms")

  data <- data.frame(
    outcome = stats::rnorm(20),
    second_outcome = stats::rnorm(20),
    couple = factor(rep(seq_len(10), each = 2)),
    time = rep(0:1, 10)
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
      VarCorr = function(...) list(),
      .package = "brms"
    ),
    "were ignored",
    fixed = TRUE
  )

  expect_length(nonlinear_blocks$blocks, 0)
})
