# Example cross-sectional distinguishable dyadic data with a Tweedie outcome.
#
# Adapted from:
# https://github.com/Pascal-Kueng/05DyadicDataAnalysis
#
# Source:
# Küng, P. M. (2026). Distinguishable and Exchangeable Dyads: Bayesian
# Multilevel Modelling (v2.0.9). Zenodo.
# https://doi.org/10.5281/zenodo.20720321

set.seed(124)

###############################################################################
### DESIGN: SAMPLE SIZE
###############################################################################

# Sample size is intentionally modest so the package example data are quick to
# inspect and lightweight to ship.
n_couples <- 120

###############################################################################
### PARAMETERS TO RECOVER LATER: FIXED EFFECTS
###############################################################################

# Role-specific log-mean effects. The outcome is meant to resemble
# semi-continuous physical activity: many low or zero observations and a
# positively skewed continuous distribution among active participants.
beta_0_female <- 2.2
beta_0_male <- 2.4

beta_a_female <- 0.35
beta_a_male <- 0.40

beta_p_female <- 0.10
beta_p_male <- 0.08

###############################################################################
### PARAMETERS TO RECOVER LATER: PREDICTOR DISTRIBUTION
###############################################################################

# Correlated role-specific predictors.
mu_motivation_female <- 0
mu_motivation_male <- 0
sd_motivation_female <- 1
sd_motivation_male <- 1
cor_motivation <- 0.35

###############################################################################
### PARAMETERS TO RECOVER LATER: CORRELATED DYAD-LEVEL RANDOM INTERCEPTS
###############################################################################

sd_re_female <- 0.35
sd_re_male <- 0.45
cor_re <- 0.30

###############################################################################
### PARAMETERS TO RECOVER LATER: TWEEDIE OUTCOME DISTRIBUTION
###############################################################################

# Tweedie power values between 1 and 2 imply a compound Poisson-gamma outcome:
# exact zeros plus positive continuous values. Role-specific dispersion and
# power parameters are included because non-Gaussian dyadic models may later
# allow these distributional parameters to differ by role.
tweedie_power_female <- 1.45
tweedie_power_male <- 1.55
tweedie_phi_female <- 3.00
tweedie_phi_male <- 3.50

###############################################################################
### SIMULATE CORRELATED PREDICTORS
###############################################################################

Sigma_motivation <- matrix(
  c(
    sd_motivation_female^2,
    cor_motivation * sd_motivation_female * sd_motivation_male,
    cor_motivation * sd_motivation_female * sd_motivation_male,
    sd_motivation_male^2
  ),
  nrow = 2
)

motivation_pair <- MASS::mvrnorm(
  n = n_couples,
  mu = c(mu_motivation_female, mu_motivation_male),
  Sigma = Sigma_motivation
)

###############################################################################
### SIMULATE CORRELATED DYAD-LEVEL RANDOM INTERCEPTS
###############################################################################

Sigma_re <- matrix(
  c(
    sd_re_female^2,
    cor_re * sd_re_female * sd_re_male,
    cor_re * sd_re_female * sd_re_male,
    sd_re_male^2
  ),
  nrow = 2
)

re_pair <- MASS::mvrnorm(
  n = n_couples,
  mu = c(0, 0),
  Sigma = Sigma_re
)

###############################################################################
### SIMULATE TWEEDIE OUTCOMES
###############################################################################

rtweedie_cp <- function(mu, phi, power) {
  if (any(power <= 1 | power >= 2)) {
    stop("`power` must be between 1 and 2.", call. = FALSE)
  }

  lambda <- mu^(2 - power) / (phi * (2 - power))
  gamma_shape <- (2 - power) / (power - 1)
  gamma_scale <- phi * (power - 1) * mu^(power - 1)

  n_events <- stats::rpois(length(mu), lambda)
  out <- numeric(length(mu))
  positive <- n_events > 0
  out[positive] <- stats::rgamma(
    sum(positive),
    shape = n_events[positive] * gamma_shape,
    scale = gamma_scale[positive]
  )
  out
}

dyad_data <- tibble::tibble(
  coupleID = seq_len(n_couples),
  personID_female = as.integer(2 * seq_len(n_couples) - 1),
  personID_male = as.integer(2 * seq_len(n_couples)),
  motivation_female = motivation_pair[, 1],
  motivation_male = motivation_pair[, 2],
  re_female = re_pair[, 1],
  re_male = re_pair[, 2]
)

dyad_data <- dplyr::mutate(
  dyad_data,
  eta_female = beta_0_female +
    beta_a_female * motivation_female +
    beta_p_female * motivation_male +
    re_female,
  eta_male = beta_0_male +
    beta_a_male * motivation_male +
    beta_p_male * motivation_female +
    re_male,
  mu_female = exp(eta_female),
  mu_male = exp(eta_male),
  activity_female = rtweedie_cp(mu_female, tweedie_phi_female, tweedie_power_female),
  activity_male = rtweedie_cp(mu_male, tweedie_phi_male, tweedie_power_male)
)

###############################################################################
### ASSEMBLE PERSON-LEVEL DATA
###############################################################################

person_female <- dplyr::transmute(
  dyad_data,
  personID = personID_female,
  coupleID = coupleID,
  gender = 1L,
  motivation = motivation_female,
  physical_activity = activity_female
)

person_male <- dplyr::transmute(
  dyad_data,
  personID = personID_male,
  coupleID = coupleID,
  gender = 2L,
  motivation = motivation_male,
  physical_activity = activity_male
)

example_dyadic_crosssectional_tweedie <- dplyr::bind_rows(person_female, person_male)
example_dyadic_crosssectional_tweedie <- dplyr::arrange(
  example_dyadic_crosssectional_tweedie,
  coupleID,
  gender
)

###############################################################################
### MISSING DATA: NON-STRUCTURAL VARIABLES ONLY
###############################################################################

# Rare isolated predictor missingness.
n_missing_motivation <- 5
missing_motivation_rows <- sample(
  seq_len(nrow(example_dyadic_crosssectional_tweedie)),
  n_missing_motivation
)
example_dyadic_crosssectional_tweedie$motivation[missing_motivation_rows] <- NA_real_

# Rare person-level nonresponse. The row stays in the data with dyad/person/role
# information intact, but all measured variables for that row are missing.
n_nonresponse_rows <- 4
available_rows <- setdiff(
  seq_len(nrow(example_dyadic_crosssectional_tweedie)),
  missing_motivation_rows
)
nonresponse_rows <- sample(available_rows, n_nonresponse_rows)
example_dyadic_crosssectional_tweedie$motivation[nonresponse_rows] <- NA_real_
example_dyadic_crosssectional_tweedie$physical_activity[nonresponse_rows] <- NA_real_

###############################################################################
### SAVE PACKAGE DATA
###############################################################################

usethis::use_data(example_dyadic_crosssectional_tweedie, overwrite = TRUE)
