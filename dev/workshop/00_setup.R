# Run this file once, in a fresh R session, before the workshop.

workshop_repositories <- c(
  PascalKueng = "https://pascal-kueng.r-universe.dev",
  CRAN = "https://cloud.r-project.org"
)

workshop_packages <- c(
  "dyadMLM",
  "wbCorr",
  "glmmTMB",
  "DHARMa",
  "easystats",
  "dplyr",
  "ggplot2",
  "tibble",
  "tidyr"
)

options(repos = workshop_repositories)

if (!requireNamespace("pak", quietly = TRUE)) {
  install.packages("pak")
}

pak::pkg_install(
  workshop_packages,
  upgrade = TRUE,
  ask = FALSE
)

missing_packages <- workshop_packages[
  !vapply(workshop_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  stop(
    "Workshop setup failed for: ",
    paste(missing_packages, collapse = ", "),
    call. = FALSE
  )
}

message("Workshop setup complete. Restart R before beginning the exercises.")
