# Run this file once, in a fresh R session, before the workshop.

cran_repository <- c(
  CRAN = "https://packagemanager.posit.co/cran/latest"
)

cran_packages <- c(
  "glmmTMB?reinstall",
  "DHARMa",
  "easystats",
  "dplyr",
  "ggplot2",
  "tibble",
  "tidyr"
)

universe_packages <- c("dyadMLM", "wbCorr")
workshop_packages <- c(
  sub("\\?.*$", "", cran_packages),
  universe_packages
)

options(repos = cran_repository)

if (!requireNamespace("pak", quietly = TRUE)) {
  install.packages("pak")
}

pak::pkg_install(
  cran_packages,
  upgrade = TRUE,
  ask = FALSE
)

options(
  repos = c(
    PascalKueng = "https://pascal-kueng.r-universe.dev",
    cran_repository
  )
)

pak::pkg_install(
  universe_packages,
  upgrade = TRUE,
  ask = FALSE
)

glmmTMB_warnings <- character()

withCallingHandlers(
  requireNamespace("glmmTMB", quietly = TRUE),
  warning = function(warning) {
    glmmTMB_warnings <<- c(
      glmmTMB_warnings,
      conditionMessage(warning)
    )
    invokeRestart("muffleWarning")
  }
)

if (any(grepl("version mismatch", glmmTMB_warnings, fixed = TRUE))) {
  stop(
    "glmmTMB still has incompatible binary dependencies. ",
    "Restart R, run install.packages(\"glmmTMB\", type = \"source\"), ",
    "then rerun 00_setup.R.",
    call. = FALSE
  )
}

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
