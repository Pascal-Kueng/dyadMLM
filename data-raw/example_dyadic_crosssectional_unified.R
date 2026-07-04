# Example cross-sectional dyadic data with multiple dyad compositions.
#
# Adapted from:
# https://github.com/Pascal-Kueng/05DyadicDataAnalysis
#
# Source:
# Küng, P. M. (2026). Distinguishable and Exchangeable Dyads: Bayesian
# Multilevel Modelling (v2.0.9). Zenodo.
# https://doi.org/10.5281/zenodo.20720321

set.seed(126)

###############################################################################
### DESIGN: SAMPLE SIZE
###############################################################################

n_female_male <- 120
n_female_female <- 100
n_male_male <- 100
n_couples <- n_female_male + n_female_female + n_male_male

###############################################################################
### PARAMETERS TO RECOVER LATER: FIXED EFFECTS
###############################################################################

mu_female_male_female <- 5.50
mu_female_male_male <- 4.50
mu_female_female <- 5.80
mu_male_male <- 4.20

###############################################################################
### PARAMETERS TO RECOVER LATER: RESIDUAL COVARIANCE
###############################################################################

# Distinguishable female-male dyads.
sd_female_male_female <- 1.10
sd_female_male_male <- 1.40
cor_female_male <- -0.30

# Exchangeable female-female dyads.
sd_female_female <- 1.00
cor_female_female <- 0.35

# Exchangeable male-male dyads.
sd_male_male <- 1.30
cor_male_male <- -0.25

###############################################################################
### HELPERS
###############################################################################

simulate_distinguishable_residuals <- function(n, sd_1, sd_2, cor) {
  Sigma <- matrix(
    c(
      sd_1^2,
      cor * sd_1 * sd_2,
      cor * sd_1 * sd_2,
      sd_2^2
    ),
    nrow = 2
  )

  MASS::mvrnorm(n = n, mu = c(0, 0), Sigma = Sigma, empirical = TRUE)
}

simulate_exchangeable_residuals <- function(n, sd, cor) {
  # The sum-diff representation gives:
  # Var(y1) = Var(sum) + Var(diff)
  # Var(y2) = Var(sum) + Var(diff)
  # Cov(y1, y2) = Var(sum) - Var(diff)
  var_sum <- sd^2 * (1 + cor) / 2
  var_diff <- sd^2 * (1 - cor) / 2

  sum_diff <- MASS::mvrnorm(
    n = n,
    mu = c(0, 0),
    Sigma = diag(c(var_sum, var_diff)),
    empirical = TRUE
  )
  sum_effect <- sum_diff[, 1]
  diff_effect <- sum_diff[, 2]

  cbind(
    sum_effect - diff_effect,
    sum_effect + diff_effect
  )
}

make_dyad_rows <- function(couple_id, gender_1, gender_2, mean_1, mean_2, residuals) {
  tibble::tibble(
    coupleID = rep(couple_id, each = 2),
    member = rep(1:2, times = length(couple_id)),
    gender = rep(c(gender_1, gender_2), times = length(couple_id)),
    satisfaction = c(rbind(mean_1 + residuals[, 1], mean_2 + residuals[, 2]))
  )
}

###############################################################################
### SIMULATE RESIDUALS
###############################################################################

female_male_resid <- simulate_distinguishable_residuals(
  n = n_female_male,
  sd_1 = sd_female_male_female,
  sd_2 = sd_female_male_male,
  cor = cor_female_male
)

female_female_resid <- simulate_exchangeable_residuals(
  n = n_female_female,
  sd = sd_female_female,
  cor = cor_female_female
)

male_male_resid <- simulate_exchangeable_residuals(
  n = n_male_male,
  sd = sd_male_male,
  cor = cor_male_male
)

###############################################################################
### ASSEMBLE PERSON-LEVEL DATA
###############################################################################

female_male_ids <- seq_len(n_female_male)
female_female_ids <- max(female_male_ids) + seq_len(n_female_female)
male_male_ids <- max(female_female_ids) + seq_len(n_male_male)

female_male_data <- make_dyad_rows(
  couple_id = female_male_ids,
  gender_1 = 1L,
  gender_2 = 2L,
  mean_1 = mu_female_male_female,
  mean_2 = mu_female_male_male,
  residuals = female_male_resid
)

female_female_data <- make_dyad_rows(
  couple_id = female_female_ids,
  gender_1 = 1L,
  gender_2 = 1L,
  mean_1 = mu_female_female,
  mean_2 = mu_female_female,
  residuals = female_female_resid
)

male_male_data <- make_dyad_rows(
  couple_id = male_male_ids,
  gender_1 = 2L,
  gender_2 = 2L,
  mean_1 = mu_male_male,
  mean_2 = mu_male_male,
  residuals = male_male_resid
)

example_dyadic_crosssectional_unified <- dplyr::bind_rows(
  female_male_data,
  female_female_data,
  male_male_data
)

example_dyadic_crosssectional_unified <- dplyr::mutate(
  example_dyadic_crosssectional_unified,
  personID = as.integer(2 * coupleID - 2 + member),
  gender = factor(gender, levels = c(1L, 2L), labels = c("female", "male"))
)

example_dyadic_crosssectional_unified <- dplyr::select(
  example_dyadic_crosssectional_unified,
  personID,
  coupleID,
  gender,
  satisfaction
)

example_dyadic_crosssectional_unified <- dplyr::arrange(
  example_dyadic_crosssectional_unified,
  coupleID,
  personID
)

###############################################################################
### SAVE PACKAGE DATA
###############################################################################

usethis::use_data(example_dyadic_crosssectional_unified, overwrite = TRUE)
