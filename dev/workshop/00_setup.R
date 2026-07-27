# Run this file once, in a fresh R session, before the workshop.

cran_repository <- "https://cloud.r-project.org"

cran_packages <- c(
  "glmmTMB",
  "DHARMa",
  "easystats",
  "dplyr",
  "ggplot2",
  "tibble",
  "tidyr"
)

universe_packages <- c("dyadMLM", "wbCorr")
universe_package_references <- paste0(universe_packages, "?reinstall")
workshop_packages <- c(cran_packages, universe_packages)

options(repos = c(CRAN = cran_repository))

if (!requireNamespace("pak", quietly = TRUE)) {
  install.packages("pak")
}

pak::pkg_install(
  cran_packages,
  upgrade = FALSE,
  ask = FALSE
)

options(
  repos = c(
    PascalKueng = "https://pascal-kueng.r-universe.dev",
    CRAN = cran_repository
  )
)

pak::pkg_install(
  universe_package_references,
  upgrade = FALSE,
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
