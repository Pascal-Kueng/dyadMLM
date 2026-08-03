# Generate the focused ILD dataset used in 04_exercises_ild.Rmd.
#
# The predictor is generated first. The outcome is then simulated from the
# exact distinguishable glmmTMB formula taught in the exercise, including
# role-specific AR(1) processes and same-occasion partner covariance.
#
# glmmTMB::simulate_new() is experimental. This script was generated and
# stress-tested with glmmTMB 1.1.14; the named parameter order and checks below
# are intended to make any future API drift visible before the RDS is replaced.

make_ild_exercise_predictor_data <- function(
    seed,
    n_dyads = 120L,
    diary_days = 0:13) {
  stopifnot(
    length(seed) == 1L,
    length(n_dyads) == 1L,
    n_dyads >= 2L,
    identical(diary_days, 0:13)
  )

  set.seed(seed)

  panel <- expand.grid(
    member_position = 1:2,
    diaryday = diary_days,
    coupleID = seq_len(n_dyads),
    KEEP.OUT.ATTRS = FALSE
  )
  panel <- panel[order(
    panel$coupleID,
    panel$diaryday,
    panel$member_position
  ), ]

  panel$personID <- 2L * panel$coupleID - 2L + panel$member_position
  panel$gender <- factor(
    ifelse(panel$member_position == 1L, "female", "male"),
    levels = c("female", "male")
  )
  panel$dyad_composition <- factor(
    "female_x_male",
    levels = "female_x_male"
  )

  support_shared_mean <- stats::rnorm(n_dyads, 0, 0.65)
  support_difference_mean <- stats::rnorm(n_dyads, 0, 0.50)

  dyad_days <- expand.grid(
    diaryday = diary_days,
    coupleID = seq_len(n_dyads),
    KEEP.OUT.ATTRS = FALSE
  )
  dyad_days <- dyad_days[order(
    dyad_days$coupleID,
    dyad_days$diaryday
  ), ]
  support_shared_day <- stats::rnorm(nrow(dyad_days), 0, 0.50)
  support_difference_day <- stats::rnorm(nrow(dyad_days), 0, 0.45)

  dyad_day_index <- match(
    paste(panel$coupleID, panel$diaryday),
    paste(dyad_days$coupleID, dyad_days$diaryday)
  )
  member_sign <- ifelse(panel$gender == "female", 1, -1)
  role_mean <- ifelse(panel$gender == "female", 5.15, 4.75)

  panel$provided_support <-
    role_mean +
    support_shared_mean[panel$coupleID] +
    member_sign * support_difference_mean[panel$coupleID] +
    support_shared_day[dyad_day_index] +
    member_sign * support_difference_day[dyad_day_index]

  # simulate_new() requires the raw outcome column to exist in newdata. Its
  # placeholder values are replaced below.
  panel$closeness <- 0

  panel <- panel[, c(
    "personID",
    "coupleID",
    "diaryday",
    "gender",
    "dyad_composition",
    "closeness",
    "provided_support"
  )]

  tibble::as_tibble(panel)
}

prepare_ild_exercise_simulation_data <- function(data) {
  prepared_data <- dyadMLM::prepare_dyad_data(
    data = data,
    dyad = coupleID,
    member = personID,
    role = gender,
    time = diaryday,
    predictors = provided_support,
    model_types = "apim",
    temporal_decomposition = "2l"
  )

  prepared_data$diaryday_c <- (prepared_data$diaryday - 6.5) / 13
  prepared_data$diaryday_f <- factor(
    prepared_data$diaryday,
    levels = 0:13
  )

  prepared_data
}

ild_exercise_fixed_formula <- ~
  0 + .is_female + .is_male +
  .is_female:diaryday_c +
  .is_male:diaryday_c +
  .is_female:.provided_support_cwp_actor +
  .is_male:.provided_support_cwp_actor +
  .is_female:.provided_support_cwp_partner +
  .is_male:.provided_support_cwp_partner +
  .is_female:.provided_support_cbp_actor +
  .is_male:.provided_support_cbp_actor +
  .is_female:.provided_support_cbp_partner +
  .is_male:.provided_support_cbp_partner

ild_exercise_simulation_formula <- update(
  ild_exercise_fixed_formula,
  ~ . +
    (0 + .is_female + .is_male | coupleID) +
    ar1(0 + .is_female:diaryday_f | coupleID) +
    ar1(0 + .is_male:diaryday_f | coupleID) +
    (0 + .is_female + .is_male | coupleID:diaryday)
)

ild_exercise_fixed_effects <- c(
  ".is_female" = 5.30,
  ".is_male" = 4.80,
  ".is_female:diaryday_c" = -0.18,
  ".is_male:diaryday_c" = 0.10,
  ".is_female:.provided_support_cwp_actor" = 0.45,
  ".is_male:.provided_support_cwp_actor" = 0.25,
  ".is_female:.provided_support_cwp_partner" = 0.20,
  ".is_male:.provided_support_cwp_partner" = 0.08,
  ".is_female:.provided_support_cbp_actor" = 0.80,
  ".is_male:.provided_support_cbp_actor" = 0.55,
  ".is_female:.provided_support_cbp_partner" = 0.30,
  ".is_male:.provided_support_cbp_partner" = 0.15
)

# glmmTMB theta parameters follow the random-term order in the formula:
# stable role covariance (3), female AR(1) (2), male AR(1) (2), and
# same-occasion role covariance (3).
ild_exercise_theta <- c(
  "stable_log_sd_female" = log(0.65),
  "stable_log_sd_male" = log(0.50),
  "stable_correlation" = glmmTMB::put_cor(0.35, input_val = "vec"),
  "female_ar1_log_sd" = log(0.80),
  "female_ar1_correlation" = glmmTMB::put_cor(
    0.70,
    input_val = "vec"
  ),
  "male_ar1_log_sd" = log(0.60),
  "male_ar1_correlation" = glmmTMB::put_cor(
    0.45,
    input_val = "vec"
  ),
  "same_day_log_sd_female" = log(0.40),
  "same_day_log_sd_male" = log(0.45),
  "same_day_correlation" = glmmTMB::put_cor(0.25, input_val = "vec")
)

check_ild_exercise_model_structure <- function(prepared_data) {
  fitting_formula <- update(
    ild_exercise_simulation_formula,
    closeness ~ .
  )
  model_structure <- glmmTMB::glmmTMB(
    formula = fitting_formula,
    dispformula = ~ 0,
    family = gaussian(),
    data = prepared_data,
    doFit = FALSE
  )

  random_structure <- model_structure$condReStruc
  expected_terms <- c(
    "0 + .is_female + .is_male | coupleID",
    "0 + .is_female:diaryday_f | coupleID",
    "0 + .is_male:diaryday_f | coupleID",
    "0 + .is_female + .is_male | coupleID:diaryday"
  )
  expected_covariance_types <- c("us", "ar1", "ar1", "us")
  expected_theta_counts <- c(3, 2, 2, 3)

  stopifnot(
    identical(names(random_structure), expected_terms),
    identical(
      unname(vapply(
        random_structure,
        function(term) names(term$blockCode),
        character(1)
      )),
      expected_covariance_types
    ),
    identical(
      as.double(vapply(
        random_structure,
        function(term) term$blockNumTheta,
        numeric(1)
      )),
      expected_theta_counts
    ),
    length(model_structure$parameters$theta) ==
      length(ild_exercise_theta)
  )

  invisible(model_structure)
}

# Seed 20260719 was selected after checking 20260719:20260721 with the exact
# workshop full and pooled models; both candidates converged for all three.
# The selected seed had interior covariance estimates, recovered the intended
# role-specific AR(1) pattern clearly, and reached the same optimum from three
# starting values.
simulate_ild_exercise_data <- function(
    seed = 20260719L,
    n_dyads = 120L) {
  installed_glmmTMB <- as.character(utils::packageVersion("glmmTMB"))
  if (!identical(installed_glmmTMB, "1.1.14")) {
    warning(
      "This generator was stress-tested with glmmTMB 1.1.14, not ",
      installed_glmmTMB,
      ". Recheck the fixed-effect and theta parameter order before replacing ",
      "the workshop RDS.",
      call. = FALSE
    )
  }

  raw_data <- make_ild_exercise_predictor_data(
    seed = seed,
    n_dyads = n_dyads
  )
  prepared_data <- prepare_ild_exercise_simulation_data(
    data = raw_data
  )

  raw_row_keys <- paste(
    raw_data$coupleID,
    raw_data$personID,
    raw_data$diaryday
  )
  prepared_row_keys <- paste(
    prepared_data$coupleID,
    prepared_data$personID,
    prepared_data$diaryday
  )
  stopifnot(identical(raw_row_keys, prepared_row_keys))

  fixed_columns <- colnames(stats::model.matrix(
    ild_exercise_fixed_formula,
    data = prepared_data
  ))
  stopifnot(identical(fixed_columns, names(ild_exercise_fixed_effects)))
  check_ild_exercise_model_structure(prepared_data)

  simulated_outcome <- glmmTMB::simulate_new(
    object = ild_exercise_simulation_formula,
    nsim = 1,
    seed = seed + 100000L,
    family = gaussian(),
    newdata = prepared_data,
    newparams = list(
      beta = unname(ild_exercise_fixed_effects),
      theta = unname(ild_exercise_theta)
    ),
    dispformula = ~ 0
  )

  raw_data$closeness <- as.double(simulated_outcome[[1L]])
  raw_data
}

check_ild_exercise_data <- function(data, n_dyads = 120L) {
  stopifnot(
    identical(
      names(data),
      c(
        "personID",
        "coupleID",
        "diaryday",
        "gender",
        "dyad_composition",
        "closeness",
        "provided_support"
      )
    ),
    nrow(data) == n_dyads * 2L * 14L,
    dplyr::n_distinct(data$coupleID) == n_dyads,
    dplyr::n_distinct(data$personID) == 2L * n_dyads,
    identical(levels(data$gender), c("female", "male")),
    identical(levels(data$dyad_composition), "female_x_male"),
    identical(sort(unique(data$diaryday)), 0:13),
    !anyDuplicated(data[c("coupleID", "personID", "diaryday")]),
    all(table(data$coupleID, data$diaryday) == 2L),
    all(is.finite(data$closeness)),
    all(is.finite(data$provided_support))
  )

  invisible(data)
}

if (sys.nframe() == 0L) {
  workshop_dir <- if (dir.exists(file.path("dev", "workshop"))) {
    file.path("dev", "workshop")
  } else {
    "."
  }

  output_file <- file.path(workshop_dir, "dyadic-ild-exercise.rds")
  ild_exercise_data <- simulate_ild_exercise_data()
  check_ild_exercise_data(ild_exercise_data)
  saveRDS(ild_exercise_data, output_file)

  message(
    "Saved ",
    nrow(ild_exercise_data),
    " rows to ",
    normalizePath(output_file)
  )
}
