# Gaussian parameter recovery for the specifications in dev/vignettes/mixed-apim.Rmd.
pkgload::load_all(quiet = TRUE)
study_directory <- "dev/diagnostic_checks/simulation-studies"

study_conditions <- dplyr::bind_rows(
  tidyr::crossing(design = c("cross_intercept", "cross_apim"), pooling = "separate",
                  dyads_per_composition = c(40L, 120L)),
  tidyr::crossing(design = c("ild_intercept", "ild_slopes"), pooling = c("separate", "pooled"),
                  dyads_per_composition = c(40L, 120L))
) |>
  dplyr::mutate(condition = dplyr::row_number(), .before = 1,
    n_occasions = ifelse(startsWith(design, "ild"), 14L, 1L),
    n_dyads = 3L * dyads_per_composition)

composition_names <- function(condition) {
  if (condition$pooling == "pooled") c("female_x_male", "same_sex") else
    c("female_x_male", "female_x_female", "male_x_male")
}

fixed_targets <- function(condition) {
  coefficients <- tibble::tribble(
    ~role, ~intercept, ~time, ~actor_between, ~partner_between, ~actor_within, ~partner_within,
    "female_x_male_female", .50, .025, .60, .25, .50, .20,
    "female_x_male_male",  -.20, -.010, .40, .15, .30, .10,
    "female_x_female",     .20, .020, .50, .20, .35, .15,
    "male_x_male",        -.40, .015, .35, .30, .40, .25
  )
  if (condition$pooling == "pooled") {
    coefficients <- coefficients[coefficients$role != "male_x_male", ]
    coefficients$role[coefficients$role == "female_x_female"] <- "same_sex"
  }
  if (condition$design == "cross_intercept") {
    coefficients <- dplyr::select(coefficients, role, intercept)
  } else if (condition$design == "cross_apim") {
    coefficients <- dplyr::transmute(coefficients, role, intercept,
      actor = actor_within, partner = partner_within)
  }
  predictors <- c(intercept = "", time = "day", actor = ".support_actor",
    partner = ".support_partner", actor_between = ".support_cbp_actor",
    partner_between = ".support_cbp_partner", actor_within = ".support_cwp_actor",
    partner_within = ".support_cwp_partner")
  tidyr::pivot_longer(coefficients, -role, names_to = "parameter", values_to = "true_value") |>
    dplyr::mutate(composition = ifelse(startsWith(role, "female_x_male_"), "female_x_male", role),
      predictor = unname(predictors[parameter]),
      term = paste0(".is_", role, ifelse(predictor == "", "", paste0(":", predictor))))
}

covariance_from_sds <- function(sds, correlation) diag(sds) %*% correlation %*% diag(sds)

member_covariance <- function(shared, difference) {
  rbind(cbind(shared + difference, shared - difference),
        cbind(shared - difference, shared + difference))
}

covariance_targets <- function(condition) {
  shared_cor <- matrix(c(1, .25, -.15, .25, 1, .20, -.15, .20, 1), 3)
  difference_cor <- matrix(c(1, -.20, .15, -.20, 1, -.25, .15, -.25, 1), 3)
  shared <- covariance_from_sds(c(.70, .22, .18), shared_cor)
  difference <- covariance_from_sds(c(.90, .16, .24), difference_cor)
  fm <- covariance_from_sds(c(1.05, .28, .20, .80, .20, .32),
    kronecker(matrix(c(1, -.25, -.25, 1), 2), shared_cor))
  ff <- member_covariance(shared, difference)
  # A different same-sex covariance tests that composition blocks remain separate.
  mm <- member_covariance(1.4 * difference, .6 * shared)
  stable <- list(female_x_male = fm, female_x_female = ff, male_x_male = mm, same_sex = ff)
  occasion <- list(female_x_male = matrix(c(1.2^2, .24, .24, .8^2), 2),
    female_x_female = matrix(c(1, -.30, -.30, 1), 2),
    male_x_male = matrix(c(.8, .40, .40, .8), 2),
    same_sex = matrix(c(1, -.30, -.30, 1), 2))
  terms <- if (condition$design == "ild_slopes") c("intercept", "actor", "partner") else "intercept"
  member_names <- unlist(lapply(1:2, function(member) paste0("member", member, "_", terms)))
  lapply(stats::setNames(composition_names(condition), composition_names(condition)), function(composition) {
    if (condition$n_occasions == 1L) {
      result <- list(residual = occasion[[composition]])
    } else {
      stable_matrix <- stable[[composition]]
      if (length(terms) == 1L) stable_matrix <- stable_matrix[c(1, 4), c(1, 4)]
      result <- list(stable = stable_matrix, occasion = occasion[[composition]])
    }
    for (component in names(result)) {
      labels <- if (component == "stable") member_names else paste0("member", 1:2, "_intercept")
      dimnames(result[[component]]) <- list(labels, labels)
    }
    result
  })
}

draw_normal <- function(n, covariance) {
  matrix(rnorm(n * nrow(covariance)), nrow = n) %*% chol(covariance)
}

# Generate from named members and hand-computed predictors, before package preparation.
generate_recovery_data <- function(condition, dataset_seed) {
  set.seed(dataset_seed)
  n <- condition$dyads_per_composition
  days <- condition$n_occasions
  raw_compositions <- c("female_x_male", "female_x_female", "male_x_male")
  generated <- dplyr::bind_rows(lapply(seq_along(raw_compositions), function(index) {
    raw_composition <- raw_compositions[index]
    rows <- expand.grid(sim_member = 1:2, day = seq_len(days) - 1L, dyad = seq_len(n))
    usual <- draw_normal(n, .49 * matrix(c(1, .3, .3, 1), 2))
    daily <- draw_normal(n * days, .49 * matrix(c(1, .2, .2, 1), 2))
    rows$coupleID <- (index - 1L) * n + rows$dyad
    rows$personID <- 2L * rows$coupleID - 2L + rows$sim_member
    rows$gender <- if (raw_composition == "female_x_male") {
      c("female", "male")[rows$sim_member]
    } else if (raw_composition == "female_x_female") "female" else "male"
    rows$sim_composition <- if (condition$pooling == "pooled" && index > 1L) "same_sex" else raw_composition
    rows$support <- as.vector(t(usual[rep(seq_len(n), each = days), ] + daily))
    rows
  })) |>
    dplyr::mutate(gender = factor(gender, levels = c("female", "male"))) |>
    dplyr::group_by(personID) |>
    dplyr::mutate(manual_mean = mean(support), actor_within = support - manual_mean) |>
    dplyr::ungroup() |>
    dplyr::mutate(actor_between = manual_mean - mean(manual_mean), actor = support) |>
    dplyr::group_by(coupleID, day) |>
    dplyr::mutate(partner = rev(actor), partner_between = rev(actor_between),
      partner_within = rev(actor_within)) |>
    dplyr::ungroup()
  generated$sim_role <- ifelse(generated$sim_composition == "female_x_male",
    paste0("female_x_male_", generated$gender), generated$sim_composition)
  targets <- fixed_targets(condition)
  generated$true_fixed_mean <- 0
  for (index in seq_len(nrow(targets))) {
    target <- targets[index, ]
    x <- if (target$parameter == "intercept") 1 else if (target$parameter == "time") {
      generated$day
    } else generated[[target$parameter]]
    generated$true_fixed_mean <- generated$true_fixed_mean +
      (generated$sim_role == target$role) * target$true_value * x
  }
  generated$outcome <- generated$true_fixed_mean
  covariances <- covariance_targets(condition)
  for (composition in names(covariances)) {
    positions <- which(generated$sim_composition == composition)
    rows <- generated[positions, ]
    dyads <- match(rows$coupleID, unique(rows$coupleID))
    count <- length(unique(dyads))
    if (days > 1L) {
      random <- draw_normal(count, covariances[[composition]]$stable)
      k <- ncol(random) / 2L
      coefficients <- (rows$sim_member - 1L) * k
      contribution <- random[cbind(dyads, coefficients + 1L)]
      if (k == 3L) contribution <- contribution +
        random[cbind(dyads, coefficients + 2L)] * rows$actor_within +
        random[cbind(dyads, coefficients + 3L)] * rows$partner_within
      generated$outcome[positions] <- generated$outcome[positions] + contribution
    }
    error_covariance <- covariances[[composition]][[if (days > 1L) "occasion" else "residual"]]
    errors <- draw_normal(count * days, error_covariance)
    generated$outcome[positions] <- generated$outcome[positions] + as.vector(t(errors))
  }
  prepared <- if (days > 1L) {
    prepare_dyad_data(generated, dyad = coupleID, member = personID, role = gender, time = day,
      predictors = support, model_types = "apim", short_colnames = FALSE, seed = dataset_seed,
      pool_compositions = if (condition$pooling == "pooled") list("same-sex" = c("female-female", "male-male")) else NULL)
  } else {
    prepare_dyad_data(generated, dyad = coupleID, member = personID, role = gender,
      predictors = support, model_types = "apim", short_colnames = FALSE, seed = dataset_seed)
  }
  prepared
}

# These are the vignette's distinct-role and shared/difference blocks.
random_blocks <- function(condition) {
  blocks <- list()
  for (component in if (condition$n_occasions == 1L) "residual" else c("stable", "occasion")) {
    predictors <- if (component == "stable" && condition$design == "ild_slopes") {
      c("", ".support_cwp_actor", ".support_cwp_partner")
    } else ""
    grouping <- if (component == "occasion") "coupleID:day" else "coupleID"
    for (composition in composition_names(condition)) {
      bases <- if (composition == "female_x_male") {
        list(member = paste0(".is_", composition, c("_female", "_male")))
      } else list(shared = paste0(".is_", composition),
        difference = paste0(".member_contrast_", composition, "_arbitrary"))
      for (coding in names(bases)) {
        coefficients <- unlist(lapply(bases[[coding]], function(base) {
          paste0(base, ifelse(predictors == "", "", paste0(":", predictors)))
        }))
        blocks[[length(blocks) + 1L]] <- list(composition = composition, component = component,
          coding = coding, coefficients = coefficients, grouping = grouping,
          term = paste0("us(0 + ", paste(coefficients, collapse = " + "), " | ", grouping, ")"))
      }
    }
  }
  blocks
}

recovery_formula <- function(condition, compositions = composition_names(condition)) {
  fixed <- fixed_targets(condition)
  blocks <- random_blocks(condition)
  fixed_terms <- fixed$term[fixed$composition %in% compositions]
  random_terms <- vapply(Filter(function(x) x$composition %in% compositions, blocks), `[[`, "", "term")
  as.formula(paste("outcome ~ 0 +", paste(c(fixed_terms, random_terms), collapse = " + ")))
}

fit_recovery_model <- function(data, condition, compositions = composition_names(condition)) {
  start <- NULL
  initialization_failures <- 0L
  if (condition$design == "ild_slopes" && length(compositions) > 1L) {
    # The likelihood factorizes by composition. Use its separate fits as starts
    # for the literal joint specification, keeping the joint sample's centering.
    composition_key <- gsub("-", "_", data$.composition, fixed = TRUE)
    separate <- lapply(compositions, function(composition)
      fit_recovery_model(data[composition_key == composition, ], condition, composition))
    initialization_failures <- sum(vapply(separate, function(model)
      model$fit$convergence != 0L || !isTRUE(model$sdr$pdHess), logical(1)))
    template <- glmmTMB::glmmTMB(recovery_formula(condition), data = data,
      family = gaussian(), dispformula = ~0, REML = FALSE, doFit = FALSE)
    beta <- do.call(c, lapply(separate, function(model) glmmTMB::fixef(model)$cond))
    theta <- unlist(lapply(separate, function(model) {
      blocks <- model$modelInfo$reStruc$condReStruc
      sizes <- vapply(blocks, `[[`, numeric(1), "blockNumTheta")
      split(unname(model$fit$par[names(model$fit$par) == "theta"]), rep(names(blocks), sizes))
    }), recursive = FALSE)
    positions <- match(term_key(colnames(template$data.tmb$X)), term_key(names(beta)))
    stopifnot(!anyNA(positions), all(names(template$condReStruc) %in% names(theta)))
    start <- list(beta = unname(beta[positions]),
      theta = unlist(theta[names(template$condReStruc)], use.names = FALSE))
    stopifnot(all(is.finite(unlist(start))))
  }
  model <- glmmTMB::glmmTMB(recovery_formula(condition, compositions), data = data,
    family = gaussian(), dispformula = ~0, REML = FALSE,
    start = start,
    control = glmmTMB::glmmTMBControl(optimizer = optim, optArgs = list(method = "BFGS"),
      optCtrl = list(maxit = 1000, reltol = 1e-10), profile = is.null(start), parallel = 1L))
  attr(model, "initialization_failures") <- initialization_failures
  model
}

term_key <- function(terms) {
  vapply(strsplit(terms, ":", fixed = TRUE), function(x) paste(sort(x), collapse = ":"), "")
}

fitted_covariances <- function(model, condition) {
  fitted <- glmmTMB::VarCorr(model)$cond
  blocks <- random_blocks(condition)
  matrices <- lapply(blocks, function(block) {
    block_index <- which(vapply(fitted, function(value) setequal(term_key(colnames(value)), term_key(block$coefficients)), logical(1)) &
      sub("[.][0-9]+$", "", names(fitted)) == make.names(block$grouping))
    stopifnot(length(block_index) == 1L)
    positions <- match(term_key(block$coefficients), term_key(colnames(fitted[[block_index]])))
    as.matrix(fitted[[block_index]])[positions, positions, drop = FALSE]
  })
  targets <- covariance_targets(condition)
  for (composition in names(targets)) {
    for (component in names(targets[[composition]])) {
      positions <- which(vapply(blocks, function(block) block$composition == composition &&
        block$component == component, logical(1)))
      recovered <- if (composition == "female_x_male") matrices[[positions]] else
        member_covariance(matrices[[positions[1]]], matrices[[positions[2]]])
      dimnames(recovered) <- dimnames(targets[[composition]][[component]])
      targets[[composition]][[component]] <- recovered
    }
  }
  targets
}

extract_recovery <- function(model, condition) {
  fixed <- fixed_targets(condition)
  table <- summary(model)$coefficients$cond
  positions <- match(term_key(fixed$term), term_key(rownames(table)))
  stopifnot(!anyNA(positions))
  fixed$estimate <- table[positions, "Estimate"]
  fixed$se <- table[positions, "Std. Error"]
  fixed$parameter <- paste(fixed$role, fixed$parameter, sep = ":")
  fixed <- dplyr::transmute(fixed, component = "fixed", composition, parameter,
    kind = "fixed", true_value, estimate, se)
  truth <- covariance_targets(condition)
  estimated <- fitted_covariances(model, condition)
  covariance <- list()
  for (composition in names(truth)) {
    for (component in names(truth[[composition]])) {
      target <- truth[[composition]][[component]]
      estimate <- estimated[[composition]][[component]]
      positions <- which(lower.tri(target, diag = TRUE), arr.ind = TRUE)
      covariance[[length(covariance) + 1L]] <- tibble::tibble(component, composition,
        parameter = paste(rownames(target)[positions[, 1]], colnames(target)[positions[, 2]], sep = "__"),
        kind = ifelse(positions[, 1] == positions[, 2], "variance", "covariance"),
        true_value = target[positions], estimate = estimate[positions], se = NA_real_)
      positions <- which(lower.tri(target), arr.ind = TRUE)
      covariance[[length(covariance) + 1L]] <- tibble::tibble(component, composition,
        parameter = paste0("cor:", rownames(target)[positions[, 1]], "__", colnames(target)[positions[, 2]]),
        kind = "correlation", true_value = cov2cor(target)[positions],
        estimate = cov2cor(estimate)[positions], se = NA_real_)
    }
  }
  dplyr::bind_rows(fixed, covariance)
}

run_recovery_dataset <- function(condition, repetition, seed_offset = 0L) {
  dataset_seed <- 710000000L + seed_offset + 100000L * condition$condition + repetition
  started <- proc.time()[["elapsed"]]
  warnings <- character()
  error <- ""
  model <- tryCatch(withCallingHandlers({
    data <- generate_recovery_data(condition, dataset_seed)
    fit_recovery_model(data, condition)
  }, warning = function(w) {
    warnings <<- c(warnings, conditionMessage(w))
    invokeRestart("muffleWarning")
  }), error = function(e) { error <<- conditionMessage(e); NULL })
  usable <- !is.null(model) && model$fit$convergence == 0L &&
    isTRUE(model$sdr$pdHess) && is.finite(as.numeric(logLik(model)))
  boundary <- if (is.null(model)) NA else any(vapply(glmmTMB::VarCorr(model)$cond, function(x) {
    eigen(x, symmetric = TRUE, only.values = TRUE)$values[ nrow(x)] /
      max(diag(x)) < 1e-6
  }, logical(1)))
  estimates <- NULL
  if (usable) {
    estimates <- tryCatch(extract_recovery(model, condition), error = function(e) {
      error <<- paste("Extraction:", conditionMessage(e)); NULL
    })
    if (is.null(estimates) || any(!is.finite(estimates$estimate)) ||
        any(!is.finite(estimates$se[estimates$kind == "fixed"]))) usable <- FALSE
  }
  list(fits = tibble::tibble(condition = condition$condition, repetition, dataset_seed, usable,
    convergence = if (is.null(model)) NA_integer_ else model$fit$convergence,
    positive_hessian = if (is.null(model)) NA else isTRUE(model$sdr$pdHess), boundary,
    initialization_failures = if (is.null(model)) NA_integer_ else attr(model, "initialization_failures"),
    warnings = paste(unique(warnings), collapse = " | "), error,
    elapsed_seconds = proc.time()[["elapsed"]] - started),
    estimates = if (usable) dplyr::mutate(estimates, condition = condition$condition, repetition, .before = 1) else
      tibble::tibble(condition = integer(), repetition = integer(), component = character(),
        composition = character(), parameter = character(), kind = character(),
        true_value = double(), estimate = double(), se = double()))
}
