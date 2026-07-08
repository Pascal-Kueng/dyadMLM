# Example intensive longitudinal dyadic data with multiple dyad compositions.
#
# Adapted from:
# https://github.com/Pascal-Kueng/05DyadicDataAnalysis
#
# Source:
# Küng, P. M. (2026). Distinguishable and Exchangeable Dyads: Bayesian
# Multilevel Modelling (v2.0.9). Zenodo.
# https://doi.org/10.5281/zenodo.20720321
#
# This extends example_dyadic_ILD to a unified dyadic setting with
# distinguishable female-male dyads and exchangeable female-female and
# male-male dyads.

set.seed(127)

###############################################################################
### DESIGN: SAMPLE SIZE AND MEASUREMENT OCCASIONS
###############################################################################

n_female_male <- 80
n_female_female <- 60
n_male_male <- 60
n_couples <- n_female_male + n_female_female + n_male_male
days <- 0:13
T_per <- length(days)

###############################################################################
### ASSEMBLE PERSON-LEVEL IDENTIFIERS
###############################################################################

female_male_ids <- seq_len(n_female_male)
female_female_ids <- max(female_male_ids) + seq_len(n_female_female)
male_male_ids <- max(female_female_ids) + seq_len(n_male_male)

make_person_rows <- function(couple_id, gender_1, gender_2, composition) {
  tibble::tibble(
    coupleID = rep(couple_id, each = 2),
    member = rep(1:2, times = length(couple_id)),
    gender = rep(c(gender_1, gender_2), times = length(couple_id)),
    composition = composition
  )
}

persons <- dplyr::bind_rows(
  make_person_rows(female_male_ids, 1L, 2L, "female_male"),
  make_person_rows(female_female_ids, 1L, 1L, "female_female"),
  make_person_rows(male_male_ids, 2L, 2L, "male_male")
)

persons <- dplyr::mutate(
  persons,
  personID = as.integer(2 * coupleID - 2 + member),
  role_key = dplyr::case_when(
    composition == "female_male" & gender == 1L ~ "female_male_female",
    composition == "female_male" & gender == 2L ~ "female_male_male",
    composition == "female_female" ~ "female_female",
    composition == "male_male" ~ "male_male"
  )
)

###############################################################################
### PARAMETERS TO RECOVER LATER: FIXED EFFECTS
###############################################################################

fixed_effects <- tibble::tribble(
  ~role_key,              ~fix_b0, ~fix_time, ~fix_bp_actor, ~fix_bp_partner, ~fix_wp_actor, ~fix_wp_partner,
  "female_male_female",      5.50,     0.010,          1.40,            0.45,          0.38,            0.18,
  "female_male_male",        4.70,    -0.005,          1.05,            0.28,          0.22,            0.10,
  "female_female",           5.80,     0.006,          1.25,            0.40,          0.32,            0.16,
  "male_male",               4.35,    -0.002,          0.95,            0.24,          0.20,            0.08
)

###############################################################################
### PARAMETERS TO RECOVER LATER: DYAD-LEVEL RANDOM EFFECTS
###############################################################################

re_names <- c(
  "re_b0",
  "re_time",
  "re_bp_actor",
  "re_bp_partner",
  "re_wp_actor",
  "re_wp_partner"
)
sd_re <- c(0.75, 0.012, 0.16, 0.12, 0.08, 0.06)
R <- matrix(0.12, length(re_names), length(re_names))
diag(R) <- 1
Sigma_re <- diag(sd_re) %*% R %*% diag(sd_re)

RE <- MASS::mvrnorm(n_couples, mu = rep(0, length(re_names)), Sigma = Sigma_re)
RE <- tibble::as_tibble(
  RE,
  .name_repair = ~ re_names
)
RE <- dplyr::mutate(RE, coupleID = seq_len(n_couples))

###############################################################################
### PARAMETERS TO RECOVER LATER: STABLE MEMBER-LEVEL INTERCEPT DEVIATIONS
###############################################################################

# These stable deviations make the maximal unified ILD covariance model
# identifiable away from the boundary. The shared dyad-level random effects
# above induce stable non-independence; these member-level deviations allow
# nonzero stable difference variance in exchangeable dyads.
stable_intercept_params <- tibble::tribble(
  ~composition,      ~sd_1, ~sd_2, ~rho,
  "female_male",      0.70,  0.65, 0.45,
  "female_female",    0.65,  0.65, 0.30,
  "male_male",        0.55,  0.55, 0.25
)

simulate_stable_intercepts <- function(couple_ids, composition_label) {
  params <- stable_intercept_params[stable_intercept_params$composition == composition_label, ]
  Sigma_stable <- matrix(
    c(
      params$sd_1^2,
      params$rho * params$sd_1 * params$sd_2,
      params$rho * params$sd_1 * params$sd_2,
      params$sd_2^2
    ),
    nrow = 2
  )
  stable_pairs <- MASS::mvrnorm(
    n = length(couple_ids),
    mu = c(0, 0),
    Sigma = Sigma_stable
  )

  tibble::tibble(
    coupleID = rep(couple_ids, each = 2),
    member = rep(1:2, times = length(couple_ids)),
    stable_intercept = c(rbind(stable_pairs[, 1], stable_pairs[, 2]))
  )
}

stable_intercepts <- dplyr::bind_rows(
  simulate_stable_intercepts(female_male_ids, "female_male"),
  simulate_stable_intercepts(female_female_ids, "female_female"),
  simulate_stable_intercepts(male_male_ids, "male_male")
)

###############################################################################
### PARAMETERS TO RECOVER LATER: BETWEEN-PERSON PREDICTOR DISTRIBUTION
###############################################################################

support_mean_params <- tibble::tribble(
  ~composition,      ~mu_1, ~mu_2, ~sd_1, ~sd_2, ~rho,
  "female_male",     5.00,  4.80,  0.80,  0.80, 0.50,
  "female_female",   5.20,  5.20,  0.75,  0.75, 0.45,
  "male_male",       4.60,  4.60,  0.75,  0.75, 0.45
)

simulate_support_means <- function(couple_ids, composition_label) {
  params <- support_mean_params[support_mean_params$composition == composition_label, ]
  Sigma_mu <- matrix(
    c(
      params$sd_1^2,
      params$rho * params$sd_1 * params$sd_2,
      params$rho * params$sd_1 * params$sd_2,
      params$sd_2^2
    ),
    nrow = 2
  )
  mu_pairs <- MASS::mvrnorm(
    n = length(couple_ids),
    mu = c(params$mu_1, params$mu_2),
    Sigma = Sigma_mu
  )

  tibble::tibble(
    coupleID = rep(couple_ids, each = 2),
    member = rep(1:2, times = length(couple_ids)),
    mu_sup = c(rbind(mu_pairs[, 1], mu_pairs[, 2]))
  )
}

mu_df <- dplyr::bind_rows(
  simulate_support_means(female_male_ids, "female_male"),
  simulate_support_means(female_female_ids, "female_female"),
  simulate_support_means(male_male_ids, "male_male")
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
  data.frame(coupleID = couple_id, diaryday = days, sup_1 = sup[, 1], sup_2 = sup[, 2])
}

support_time <- dplyr::bind_rows(lapply(seq_len(n_couples), sim_support_one_couple))
support_1 <- dplyr::select(support_time, coupleID, diaryday, sup_cwp = sup_1)
support_1 <- dplyr::mutate(support_1, member = 1L)
support_2 <- dplyr::select(support_time, coupleID, diaryday, sup_cwp = sup_2)
support_2 <- dplyr::mutate(support_2, member = 2L)
support_long <- dplyr::bind_rows(support_1, support_2)
support_long <- dplyr::left_join(support_long, mu_df, by = c("coupleID", "member"))
support_long <- dplyr::mutate(support_long, provided_support = mu_sup + sup_cwp)
support_long <- dplyr::select(support_long, coupleID, diaryday, member, provided_support, sup_cwp)

###############################################################################
### ASSEMBLE PERSON-DAY PANEL
###############################################################################

panel <- expand.grid(coupleID = seq_len(n_couples), diaryday = days, member = 1:2)
panel <- panel[order(panel$coupleID, panel$diaryday, panel$member), ]
panel <- tibble::as_tibble(panel)
panel <- dplyr::left_join(panel, persons, by = c("coupleID", "member"))
panel <- dplyr::left_join(panel, support_long, by = c("coupleID", "diaryday", "member"))
panel <- dplyr::left_join(panel, stable_intercepts, by = c("coupleID", "member"))

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

panel <- dplyr::left_join(panel, fixed_effects, by = "role_key")
panel <- dplyr::left_join(panel, RE, by = "coupleID")
panel <- dplyr::mutate(
  panel,
  actor_cwp = sup_cwp,
  partner_cwp = sup_cwp_partner,
  actor_cbp = mu_actor - grand_mu,
  partner_cbp = mu_partner - grand_mu,
  mu_it =
    fix_b0 + re_b0 + stable_intercept +
      (fix_time + re_time) * diaryday +
      (fix_bp_actor + re_bp_actor) * actor_cbp +
      (fix_bp_partner + re_bp_partner) * partner_cbp +
      (fix_wp_actor + re_wp_actor) * actor_cwp +
      (fix_wp_partner + re_wp_partner) * partner_cwp
)

###############################################################################
### PARAMETERS TO RECOVER LATER: RESIDUAL AR(1) PROCESS
###############################################################################

residual_params <- tibble::tribble(
  ~composition,      ~phi_1, ~phi_2, ~sd_1, ~sd_2, ~rho,
  "female_male",      0.15,   0.05,  0.70,  1.10, -0.25,
  "female_female",    0.12,   0.12,  0.75,  0.75,  0.30,
  "male_male",        0.08,   0.08,  1.00,  1.00, -0.15
)

simulate_pair_ar1 <- function(couple_id, composition_label) {
  params <- residual_params[residual_params$composition == composition_label, ]
  sd_eta_1 <- sqrt(params$sd_1^2 * (1 - params$phi_1^2))
  sd_eta_2 <- sqrt(params$sd_2^2 * (1 - params$phi_2^2))
  cov_eta <- params$rho * sd_eta_1 * sd_eta_2

  Sigma_eta <- matrix(
    c(sd_eta_1^2, cov_eta, cov_eta, sd_eta_2^2),
    nrow = 2
  )
  Sigma0 <- matrix(
    c(
      params$sd_1^2,
      cov_eta / (1 - params$phi_1 * params$phi_2),
      cov_eta / (1 - params$phi_1 * params$phi_2),
      params$sd_2^2
    ),
    nrow = 2
  )

  eps <- matrix(NA_real_, nrow = T_per, ncol = 2)
  eps[1, ] <- MASS::mvrnorm(n = 1, mu = c(0, 0), Sigma = Sigma0)
  innovations <- MASS::mvrnorm(n = T_per - 1, mu = c(0, 0), Sigma = Sigma_eta)

  if (T_per >= 2) {
    for (time_index in 2:T_per) {
      eps[time_index, 1] <- params$phi_1 * eps[time_index - 1, 1] + innovations[time_index - 1, 1]
      eps[time_index, 2] <- params$phi_2 * eps[time_index - 1, 2] + innovations[time_index - 1, 2]
    }
  }

  data.frame(
    coupleID = couple_id,
    diaryday = days,
    eps_1 = eps[, 1],
    eps_2 = eps[, 2]
  )
}

couple_compositions <- dplyr::distinct(persons, coupleID, composition)
eps_time <- dplyr::bind_rows(
  lapply(
    seq_len(nrow(couple_compositions)),
    function(row_index) {
      simulate_pair_ar1(
        couple_id = couple_compositions$coupleID[row_index],
        composition_label = couple_compositions$composition[row_index]
      )
    }
  )
)

eps_1 <- dplyr::select(eps_time, coupleID, diaryday, e_it = eps_1)
eps_1 <- dplyr::mutate(eps_1, member = 1L)
eps_2 <- dplyr::select(eps_time, coupleID, diaryday, e_it = eps_2)
eps_2 <- dplyr::mutate(eps_2, member = 2L)
eps_long <- dplyr::bind_rows(eps_1, eps_2)

panel <- dplyr::left_join(panel, eps_long, by = c("coupleID", "diaryday", "member"))
panel <- dplyr::arrange(panel, coupleID, diaryday, member)

###############################################################################
### ASSEMBLE FINAL PACKAGE DATA
###############################################################################

example_dyadic_ILD_unified <- dplyr::mutate(panel, closeness = mu_it + e_it)
example_dyadic_ILD_unified <- dplyr::select(
  dplyr::mutate(
    example_dyadic_ILD_unified,
    gender = factor(gender, levels = c(1L, 2L), labels = c("female", "male"))
  ),
  personID,
  coupleID,
  diaryday,
  gender,
  closeness,
  provided_support
)
example_dyadic_ILD_unified <- dplyr::arrange(example_dyadic_ILD_unified, coupleID, personID, diaryday)

###############################################################################
### MISSING DATA: NON-STRUCTURAL VARIABLES ONLY
###############################################################################

# Rare isolated predictor missingness.
n_missing_support <- 100
missing_support_rows <- sample(seq_len(nrow(example_dyadic_ILD_unified)), n_missing_support)
example_dyadic_ILD_unified$provided_support[missing_support_rows] <- NA_real_

# Rare diary nonresponse. The person-day row stays in the data with dyad, person,
# role, and time information intact, but all measured variables for that row are
# missing.
n_nonresponse_rows <- 120
available_rows <- setdiff(seq_len(nrow(example_dyadic_ILD_unified)), missing_support_rows)
nonresponse_rows <- sample(available_rows, n_nonresponse_rows)
example_dyadic_ILD_unified$provided_support[nonresponse_rows] <- NA_real_
example_dyadic_ILD_unified$closeness[nonresponse_rows] <- NA_real_

###############################################################################
### SAVE PACKAGE DATA
###############################################################################

usethis::use_data(example_dyadic_ILD_unified, overwrite = TRUE)
