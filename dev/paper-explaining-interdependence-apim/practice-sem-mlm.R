# Run section by section, with the manuscript checkout as working directory.
# Supplied FLASHE example: self-efficacy predicting fruit/vegetable intake.
# This is cross-sectional: the MLM does not separate temporal levels.

library(lavaan)
library(glmmTMB)

source_dir <- "dev/references/explaining-interdependence-apim/jp-materials-2026-09-13/J-P&Niall-FLASHE-example"
d <- read.csv(file.path(source_dir, "flashe-lavaan.csv"))
n <- nrow(d)

# 1. Fit the APIM in wide format, estimating predictor moments jointly.
model <- '
  pftveg ~ ap*cpeffv + pp*cteffv
  tftveg ~ at*cteffv + pt*cpeffv
  pftveg ~~ ep*pftveg
  tftveg ~~ et*tftveg
  pftveg ~~ ept*tftveg
  cpeffv ~~ vp*cpeffv
  cteffv ~~ vt*cteffv
  cpeffv ~~ cpt*cteffv
'
sem_fit <- sem(model, data = d, fixed.x = FALSE,
               meanstructure = TRUE, estimator = "ML")

# 2. Fit the same paired outcome model in long format.
long <- rbind(
  data.frame(id = seq_len(n), role = "parent",
             y = d$pftveg, actor = d$cpeffv, partner = d$cteffv),
  data.frame(id = seq_len(n), role = "teen",
             y = d$tftveg, actor = d$cteffv, partner = d$cpeffv)
)
long$role <- factor(long$role, levels = c("parent", "teen"))
long <- long[order(long$id, long$role), ]
mlm_fit <- glmmTMB(
  y ~ 0 + role + role:actor + role:partner + us(0 + role | id),
  data = long, family = gaussian, dispformula = ~ 0, REML = FALSE
)

# 3. Extract coefficients, predictor moments, and paired residual covariance.
# Every matrix has parent, teen order for outcomes and predictors.
s <- coef(sem_fit)
B_sem <- matrix(s[c("ap", "pp", "pt", "at")], 2, byrow = TRUE)
X_sem <- matrix(s[c("vp", "cpt", "cpt", "vt")], 2)
E_sem <- matrix(s[c("ep", "ept", "ept", "et")], 2)
m <- fixef(mlm_fit)$cond
B_mlm <- matrix(m[c("roleparent:actor", "roleparent:partner",
                    "roleteen:partner", "roleteen:actor")], 2, byrow = TRUE)
# R's cov() uses n-1; normal-theory ML uses n.
X_mlm <- cov(d[c("cpeffv", "cteffv")]) * (n - 1) / n
# ~0 fixes scalar dispersion near zero, not exactly zero. Include that tiny
# fixed variance for an exact reconstruction of the fitted covariance.
E_mlm <- matrix(VarCorr(mlm_fit)$cond$id, 2, 2) + diag(sigma(mlm_fit)^2, 2)

# 4. Trace the four predictor routes and add residual covariance.
partition <- function(B, X, E) {
  V <- B %*% X %*% t(B) + E
  parts <- c(
    actor_driven = B[1, 1] * B[2, 2] * X[1, 2],
    partner_driven = B[1, 2] * B[2, 1] * X[1, 2],
    parent_driven = B[1, 1] * B[2, 1] * X[1, 1],
    teen_driven = B[1, 2] * B[2, 2] * X[2, 2],
    residual = E[1, 2]
  )
  data.frame(covariance = parts,
             correlation_units = parts / sqrt(V[1, 1] * V[2, 2]),
             percent_of_total = 100 * parts / V[1, 2])
}

cat("N dyads:", n, "\n")
cat("SEM partition\n"); print(partition(B_sem, X_sem, E_sem), digits = 9)
cat("MLM partition\n"); print(partition(B_mlm, X_mlm, E_mlm), digits = 9)
cat("Predictor moments\n"); print(X_mlm, digits = 10)
cat("SEM residual covariance\n"); print(E_sem, digits = 10)
cat("MLM convergence:", mlm_fit$fit$convergence,
    "; positive-definite Hessian:", mlm_fit$sdr$pdHess, "\n")
cat("Maximum absolute SEM/MLM discrepancies\n")
print(c(slopes = max(abs(B_sem - B_mlm)),
        predictor_moments = max(abs(X_sem - X_mlm)),
        residual_covariance = max(abs(E_sem - E_mlm))))
V <- B_mlm %*% X_mlm %*% t(B_mlm) + E_mlm
cat("MLM implied outcome covariance\n"); print(V, digits = 10)
cat("MLM implied outcome correlation:", cov2cor(V)[1, 2], "\n")
stopifnot(mlm_fit$fit$convergence == 0, mlm_fit$sdr$pdHess,
          max(abs(B_sem - B_mlm)) < 1e-5,
          max(abs(E_sem - E_mlm)) < 1e-5,
          max(abs(V - cov(d[c("pftveg", "tftveg")]) * (n - 1) / n)) < 1e-5)
