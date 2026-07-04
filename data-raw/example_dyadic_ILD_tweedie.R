# Example intensive longitudinal dyadic data with a Tweedie outcome.
#
# Adapted from:
# https://github.com/Pascal-Kueng/05DyadicDataAnalysis
#
# Source:
# Küng, P. M. (2026). Distinguishable and Exchangeable Dyads: Bayesian
# Multilevel Modelling (v2.0.9). Zenodo.
# https://doi.org/10.5281/zenodo.20720321
#
# This uses the same longitudinal dyadic structure as example_dyadic_ILD:
# role-specific between-person and within-person actor/partner effects are
# included in the data-generating model. The outcome is semi-continuous and
# generated from a Tweedie distribution.

set.seed(125)

###############################################################################
### DESIGN: SAMPLE SIZE AND MEASUREMENT OCCASIONS
###############################################################################

n_couples <- 40
days <- 0:13
T_per <- length(days)

###############################################################################
### ASSEMBLE PERSON-LEVEL IDENTIFIERS
###############################################################################

persons <- tibble::tibble(
  coupleID = rep(1:n_couples, each = 2),
  member = rep(1:2, times = n_couples),
  gender = ifelse(member == 1L, 1L, 2L),
  is_female = as.integer(gender == 1L),
  is_male = as.integer(gender == 2L),
  personID = as.integer(2 * coupleID - 2 + member)
)

###############################################################################
### PARAMETERS TO RECOVER LATER: FIXED EFFECTS
###############################################################################

# Role-specific log-mean effects.
b0_female <- 2.15
b0_male <- 2.35
b_time_female <- 0.005
b_time_male <- -0.003

b_bp_actor_f <- 0.35
b_bp_partner_f <- 0.10
b_bp_actor_m <- 0.30
b_bp_partner_m <- 0.08

b_wp_actor_f <- 0.18
b_wp_partner_f <- 0.06
b_wp_actor_m <- 0.15
b_wp_partner_m <- 0.05

###############################################################################
### PARAMETERS TO RECOVER LATER: COUPLE-LEVEL RANDOM EFFECTS
###############################################################################

re_names <- c(
  "re_b0_m",
  "re_b0_f",
  "re_time_m",
  "re_time_f",
  "re_bpA_m",
  "re_bpP_m",
  "re_bpA_f",
  "re_bpP_f",
  "re_wpA_m",
  "re_wpP_m",
  "re_wpA_f",
  "re_wpP_f"
)
sd_re <- c(0.30, 0.35, 0.006, 0.006, 0.08, 0.06, 0.08, 0.06, 0.05, 0.04, 0.05, 0.04)
R <- matrix(0.12, length(re_names), length(re_names))
diag(R) <- 1
Sigma_re <- diag(sd_re) %*% R %*% diag(sd_re)

###############################################################################
### SIMULATE COUPLE-LEVEL RANDOM EFFECTS
###############################################################################

RE <- MASS::mvrnorm(n_couples, mu = rep(0, length(re_names)), Sigma = Sigma_re)
RE <- tibble::as_tibble(
  RE,
  .name_repair = ~ re_names
)
RE <- dplyr::mutate(RE, coupleID = 1:n_couples)

###############################################################################
### PARAMETERS TO RECOVER LATER: BETWEEN-PERSON PREDICTOR DISTRIBUTION
###############################################################################

mu_sup_f <- 5.0
sd_mu_f <- 0.8
mu_sup_m <- 4.8
sd_mu_m <- 0.8
rho_couple_mean <- 0.50
Sigma_mu <- matrix(
  c(
    sd_mu_f^2,
    rho_couple_mean * sd_mu_f * sd_mu_m,
    rho_couple_mean * sd_mu_f * sd_mu_m,
    sd_mu_m^2
  ),
  nrow = 2
)

mu_pairs <- MASS::mvrnorm(n_couples, mu = c(mu_sup_f, mu_sup_m), Sigma = Sigma_mu)

###############################################################################
### SIMULATE PERSON-LEVEL PREDICTOR MEANS
###############################################################################

mu_df <- tibble::tibble(
  coupleID = rep(1:n_couples, each = 2),
  member = rep(1:2, times = n_couples),
  mu_sup = c(rbind(mu_pairs[, 1], mu_pairs[, 2]))
)

###############################################################################
### PARAMETERS TO RECOVER LATER: WITHIN-PERSON PREDICTOR PROCESS
###############################################################################

phi_sup <- 0.4
sd_sup_wp <- 0.8
sd_eta_sup <- sqrt(sd_sup_wp^2 * (1 - phi_sup^2))
rho_sup_day <- 0.3
Sigma_eta_day <- matrix(
  c(
    sd_eta_sup^2,
    rho_sup_day * sd_eta_sup^2,
    rho_sup_day * sd_eta_sup^2,
    sd_eta_sup^2
  ),
  nrow = 2
)

###############################################################################
### SIMULATE WITHIN-PERSON PREDICTORS
###############################################################################

sim_support_one_couple <- function(couple_id) {
  eta <- MASS::mvrnorm(T_per, mu = c(0, 0), Sigma = Sigma_eta_day)
  sup <- matrix(NA_real_, nrow = T_per, ncol = 2)
  sup[1, ] <- eta[1, ] / sqrt(1 - phi_sup^2)
  for (day in 2:T_per) {
    sup[day, ] <- phi_sup * sup[day - 1, ] + eta[day, ]
  }
  data.frame(coupleID = couple_id, diaryday = days, sup_f = sup[, 1], sup_m = sup[, 2])
}

support_time <- dplyr::bind_rows(lapply(1:n_couples, sim_support_one_couple))
support_f <- dplyr::select(support_time, coupleID, diaryday, sup_cwp = sup_f)
support_f <- dplyr::mutate(support_f, member = 1L)
support_m <- dplyr::select(support_time, coupleID, diaryday, sup_cwp = sup_m)
support_m <- dplyr::mutate(support_m, member = 2L)
support_long <- dplyr::bind_rows(support_f, support_m)
support_long <- dplyr::left_join(support_long, mu_df, by = c("coupleID", "member"))
support_long <- dplyr::mutate(support_long, provided_support = mu_sup + sup_cwp)
support_long <- dplyr::select(support_long, coupleID, diaryday, member, provided_support, sup_cwp)

###############################################################################
### ASSEMBLE PERSON-DAY PANEL
###############################################################################

panel <- expand.grid(coupleID = 1:n_couples, diaryday = days, member = 1:2)
panel <- panel[order(panel$coupleID, panel$diaryday, panel$member), ]
panel <- tibble::as_tibble(panel)
panel <- dplyr::left_join(panel, persons, by = c("coupleID", "member"))
panel <- dplyr::left_join(panel, support_long, by = c("coupleID", "diaryday", "member"))

panel <- dplyr::group_by(panel, coupleID, diaryday)
panel <- dplyr::mutate(
  panel,
  provided_support_partner = provided_support[3 - member],
  sup_cwp_partner = sup_cwp[3 - member]
)
panel <- dplyr::ungroup(panel)

mu_actor_tbl <- dplyr::rename(mu_df, mu_actor = mu_sup)
mu_partner_tbl <- dplyr::mutate(mu_df, member = 3 - member)
mu_partner_tbl <- dplyr::rename(mu_partner_tbl, mu_partner = mu_sup)

panel <- dplyr::left_join(panel, mu_actor_tbl, by = c("coupleID", "member"))
panel <- dplyr::left_join(panel, mu_partner_tbl, by = c("coupleID", "member"))

grand_mu <- mean(mu_df$mu_sup)

###############################################################################
### GENERATE CONDITIONAL MEAN OF THE OUTCOME
###############################################################################

panel <- dplyr::left_join(panel, RE, by = "coupleID")
panel <- dplyr::mutate(
  panel,
  fix_b0 = ifelse(is_male == 1L, b0_male, b0_female),
  fix_time = ifelse(is_male == 1L, b_time_male, b_time_female),
  fix_bp_actor = ifelse(is_male == 1L, b_bp_actor_m, b_bp_actor_f),
  fix_bp_partner = ifelse(is_male == 1L, b_bp_partner_m, b_bp_partner_f),
  fix_wp_actor = ifelse(is_male == 1L, b_wp_actor_m, b_wp_actor_f),
  fix_wp_partner = ifelse(is_male == 1L, b_wp_partner_m, b_wp_partner_f),
  re_b0 = ifelse(is_male == 1L, re_b0_m, re_b0_f),
  re_time = ifelse(is_male == 1L, re_time_m, re_time_f),
  re_bp_actor = ifelse(is_male == 1L, re_bpA_m, re_bpA_f),
  re_bp_part = ifelse(is_male == 1L, re_bpP_m, re_bpP_f),
  re_wp_actor = ifelse(is_male == 1L, re_wpA_m, re_wpA_f),
  re_wp_part = ifelse(is_male == 1L, re_wpP_m, re_wpP_f),
  actor_cwp = sup_cwp,
  partner_cwp = sup_cwp_partner,
  actor_cbp = mu_actor - grand_mu,
  partner_cbp = mu_partner - grand_mu,
  eta_mean =
    fix_b0 + re_b0 +
      (fix_time + re_time) * diaryday +
      (fix_bp_actor + re_bp_actor) * actor_cbp +
      (fix_bp_partner + re_bp_part) * partner_cbp +
      (fix_wp_actor + re_wp_actor) * actor_cwp +
      (fix_wp_partner + re_wp_part) * partner_cwp
)

###############################################################################
### PARAMETERS TO RECOVER LATER: LATENT AR(1) OUTCOME PROCESS
###############################################################################

# These latent log-mean deviations mirror the Gaussian ILD residual process.
# They induce serial dependence and same-day partner dependence before the
# Tweedie observation process is drawn.
phi_eps_f <- 0.15
phi_eps_m <- 0.05
sd_eps_f <- 0.25
sd_eps_m <- 0.30
cor_eta_eps <- -0.20

sd_eta_f <- sqrt(sd_eps_f^2 * (1 - phi_eps_f^2))
sd_eta_m <- sqrt(sd_eps_m^2 * (1 - phi_eps_m^2))
cov_eta <- cor_eta_eps * sd_eta_f * sd_eta_m

###############################################################################
### SIMULATE CORRELATED ROLE-SPECIFIC LATENT AR(1) DEVIATIONS
###############################################################################

Sigma_eta_eps <- matrix(
  c(sd_eta_f^2, cov_eta, cov_eta, sd_eta_m^2),
  nrow = 2
)
Sigma0_eps <- matrix(
  c(
    sd_eps_f^2,
    cov_eta / (1 - phi_eps_f * phi_eps_m),
    cov_eta / (1 - phi_eps_f * phi_eps_m),
    sd_eps_m^2
  ),
  nrow = 2
)

simulate_couple_ar1_latent <- function(couple_id) {
  eps <- matrix(NA_real_, nrow = T_per, ncol = 2)
  eps[1, ] <- MASS::mvrnorm(n = 1, mu = c(0, 0), Sigma = Sigma0_eps)
  innovations <- MASS::mvrnorm(n = T_per - 1, mu = c(0, 0), Sigma = Sigma_eta_eps)

  if (T_per >= 2) {
    for (time_index in 2:T_per) {
      eps[time_index, 1] <- phi_eps_f * eps[time_index - 1, 1] + innovations[time_index - 1, 1]
      eps[time_index, 2] <- phi_eps_m * eps[time_index - 1, 2] + innovations[time_index - 1, 2]
    }
  }

  data.frame(
    coupleID = couple_id,
    diaryday = days,
    eps_female = eps[, 1],
    eps_male = eps[, 2]
  )
}

eps_time <- dplyr::bind_rows(lapply(1:n_couples, simulate_couple_ar1_latent))
eps_female <- dplyr::select(eps_time, coupleID, diaryday, e_it = eps_female)
eps_female <- dplyr::mutate(eps_female, member = 1L)
eps_male <- dplyr::select(eps_time, coupleID, diaryday, e_it = eps_male)
eps_male <- dplyr::mutate(eps_male, member = 2L)
eps_long <- dplyr::bind_rows(eps_female, eps_male)

panel <- dplyr::left_join(panel, eps_long, by = c("coupleID", "diaryday", "member"))
panel <- dplyr::mutate(panel, eta_it = eta_mean + e_it, mu_it = exp(eta_it))
panel <- dplyr::arrange(panel, coupleID, diaryday, member)

###############################################################################
### SIMULATE TWEEDIE OUTCOMES
###############################################################################

rtweedie_cp <- function(mu, phi, power) {
  phi <- rep(phi, length.out = length(mu))
  power <- rep(power, length.out = length(mu))

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
    shape = n_events[positive] * gamma_shape[positive],
    scale = gamma_scale[positive]
  )
  out
}

panel <- dplyr::mutate(
  panel,
  tweedie_phi = ifelse(is_male == 1L, 3.40, 3.00),
  tweedie_power = ifelse(is_male == 1L, 1.55, 1.45),
  physical_activity = rtweedie_cp(mu_it, tweedie_phi, tweedie_power)
)

###############################################################################
### ASSEMBLE FINAL PACKAGE DATA
###############################################################################

example_dyadic_ILD_tweedie <- dplyr::select(
  dplyr::mutate(
    panel,
    gender = factor(gender, levels = c(1L, 2L), labels = c("female", "male"))
  ),
  personID,
  coupleID,
  diaryday,
  gender,
  physical_activity,
  provided_support
)
example_dyadic_ILD_tweedie <- dplyr::arrange(example_dyadic_ILD_tweedie, coupleID, personID, diaryday)

###############################################################################
### MISSING DATA: NON-STRUCTURAL VARIABLES ONLY
###############################################################################

# Rare isolated predictor missingness.
n_missing_support <- 20
missing_support_rows <- sample(seq_len(nrow(example_dyadic_ILD_tweedie)), n_missing_support)
example_dyadic_ILD_tweedie$provided_support[missing_support_rows] <- NA_real_

# Rare diary nonresponse. The person-day row stays in the data with dyad, person,
# role, and time information intact, but all measured variables for that row are
# missing.
n_nonresponse_rows <- 24
available_rows <- setdiff(seq_len(nrow(example_dyadic_ILD_tweedie)), missing_support_rows)
nonresponse_rows <- sample(available_rows, n_nonresponse_rows)
example_dyadic_ILD_tweedie$provided_support[nonresponse_rows] <- NA_real_
example_dyadic_ILD_tweedie$physical_activity[nonresponse_rows] <- NA_real_

###############################################################################
### SAVE PACKAGE DATA
###############################################################################

usethis::use_data(example_dyadic_ILD_tweedie, overwrite = TRUE)
