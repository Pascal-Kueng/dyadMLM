# Example cross-sectional distinguishable dyadic data.
#
# Adapted from:
# https://github.com/Pascal-Kueng/05DyadicDataAnalysis
#
# Source:
# Küng, P. M. (2026). Distinguishable and Exchangeable Dyads: Bayesian
# Multilevel Modelling (v2.0.9). Zenodo.
# https://doi.org/10.5281/zenodo.20720321

set.seed(123)

###############################################################################
### DESIGN: SAMPLE SIZE
###############################################################################

# Sample size is intentionally modest so the package example data are quick to
# inspect and lightweight to ship.
n_couples <- 95

###############################################################################
### PARAMETERS TO RECOVER LATER: FIXED EFFECTS
###############################################################################

# Role-specific fixed effects.
gamma_0_female <- 5.5
gamma_0_male <- 4.5

gamma_a_female <- 1.6
gamma_a_male <- 1.8

gamma_p_female <- 0.3
gamma_p_male <- 0.2

###############################################################################
### PARAMETERS TO RECOVER LATER: PREDICTOR DISTRIBUTION
###############################################################################

# Correlated role-specific predictors.
mu_x_female <- 5
mu_x_male <- 5
sd_x_female <- 1.5
sd_x_male <- 1.5
cor_x <- 0.4

###############################################################################
### SIMULATE CORRELATED PREDICTORS
###############################################################################

Sigma_x <- matrix(
  c(
    sd_x_female^2,
    cor_x * sd_x_female * sd_x_male,
    cor_x * sd_x_female * sd_x_male,
    sd_x_male^2
  ),
  nrow = 2
)

communication_pair <- MASS::mvrnorm(
  n = n_couples,
  mu = c(mu_x_female, mu_x_male),
  Sigma = Sigma_x
)

###############################################################################
### PARAMETERS TO RECOVER LATER: RESIDUAL COVARIANCE
###############################################################################

# Negatively correlated residuals across partners. The fixed effects and
# correlated predictors may still produce a positive observed outcome
# correlation; the intended negative dependence is in the residual part.
sd_e_female <- 1.1
sd_e_male <- 1.4
cor_e <- -0.30

###############################################################################
### SIMULATE CORRELATED RESIDUALS
###############################################################################

Sigma_e <- matrix(
  c(
    sd_e_female^2,
    cor_e * sd_e_female * sd_e_male,
    cor_e * sd_e_female * sd_e_male,
    sd_e_male^2
  ),
  nrow = 2
)

resid_pair <- MASS::mvrnorm(
  n = n_couples,
  mu = c(0, 0),
  Sigma = Sigma_e
)

###############################################################################
### ASSEMBLE DYAD-LEVEL DATA
###############################################################################

dyad_data <- tibble::tibble(
  coupleID = seq_len(n_couples),
  communication_female = communication_pair[, 1],
  communication_male = communication_pair[, 2],
  e_female = resid_pair[, 1],
  e_male = resid_pair[, 2]
)

person_female <- dplyr::transmute(
  dyad_data,
  userID = paste0(coupleID, "_1"),
  coupleID = coupleID,
  member = 1L,
  gender = 1L,
  communication = communication_female,
  communication_partner = communication_male,
  residual = e_female
)

person_male <- dplyr::transmute(
  dyad_data,
  userID = paste0(coupleID, "_2"),
  coupleID = coupleID,
  member = 2L,
  gender = 2L,
  communication = communication_male,
  communication_partner = communication_female,
  residual = e_male
)

###############################################################################
### ASSEMBLE PERSON-LEVEL DATA AND OUTCOME
###############################################################################

example_dyadic_crosssectional <- dplyr::bind_rows(person_female, person_male)
example_dyadic_crosssectional <- dplyr::arrange(
  example_dyadic_crosssectional,
  coupleID,
  member
)
example_dyadic_crosssectional <- dplyr::mutate(
  example_dyadic_crosssectional,
  c_communication_actor = communication - mean(communication),
  c_communication_partner = communication_partner - mean(communication_partner),
  satisfaction = dplyr::case_when(
    gender == 1L ~ gamma_0_female +
      gamma_a_female * c_communication_actor +
      gamma_p_female * c_communication_partner +
      residual,
    gender == 2L ~ gamma_0_male +
      gamma_a_male * c_communication_actor +
      gamma_p_male * c_communication_partner +
      residual
  )
)
example_dyadic_crosssectional <- dplyr::select(
  example_dyadic_crosssectional,
  userID,
  coupleID,
  member,
  gender,
  communication,
  satisfaction
)

###############################################################################
### SAVE PACKAGE DATA
###############################################################################

usethis::use_data(example_dyadic_crosssectional, overwrite = TRUE)
