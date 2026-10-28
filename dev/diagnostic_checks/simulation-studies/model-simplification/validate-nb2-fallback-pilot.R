# Run after the complete 2-dataset pilot. Serial replays use one fitting worker.
source("dev/diagnostic_checks/simulation-studies/model-simplification/nb2-fallback.R")
directory <- file.path(study_directory, "results/model-simplification/nb2-fallback/2-datasets-1000-draws")
specification <- readRDS(file.path(directory, "run-specification.rds"))
stopifnot(identical(specification, nb2_fallback_specification(2L, 1000L)))
files <- list.files(directory, "^condition-.*[.]rds$", full.names = TRUE)
stopifnot(length(files) == 6L)
hashes <- tools::md5sum(files)
completed <- unlist(lapply(files, readRDS), recursive = FALSE)
conditions <- specification$conditions |> dplyr::mutate(repetitions = 2L, reference_draws = 1000L)
result <- summarise_nb2_fallback(completed, conditions)
tables <- result$tables
stopifnot(nrow(tables$status) == 12L, nrow(tables$fits) == 24L,
  nrow(tables$inference) == 384L, nrow(tables$policies) == 192L,
  all(tables$status$check_error == ""), all(tables$fits$inference_error == ""),
  all(tables$inference$defined[tables$inference$eligible]))
sort_keys <- list(conditions = "condition", fits = c("condition", "model"),
  inference = c("condition", "method", "parameter"), selection = c("condition", "policy", "selected_model", "available"),
  flags = c("condition", "full_fit", "scope", "check", "composition", "role", "statistic"))
for (name in names(result$exports)) {
  expected <- as.data.frame(result$exports[[name]]) |>
    dplyr::arrange(dplyr::across(dplyr::all_of(sort_keys[[name]])))
  saved <- read.csv(file.path(directory, paste0(name, ".csv"))) |>
    dplyr::arrange(dplyr::across(dplyr::all_of(sort_keys[[name]])))
  stopifnot(isTRUE(all.equal(expected, saved, tolerance = 1e-12, check.attributes = FALSE)))
}
for (record in completed) {
  usable <- stats::setNames(record$fits$eligible, record$fits$model)
  expected_reversal <- all(record$fits$usable) && is.finite(record$status$likelihood_delta) &&
    record$status$likelihood_delta < -specification$likelihood_tolerance
  stopifnot(identical(record$status$likelihood_reversal, expected_reversal),
    identical(record$fits$eligible,
      record$fits$usable & !(record$fits$model == "full" & expected_reversal)))
  stopifnot(nrow(record$checks) == if (usable[["pooled"]]) 42L else 0L)
  if (usable[["pooled"]]) {
    stopifnot(isTRUE(record$status$simulation_finite), all(!is.na(record$checks$flagged)))
    scalar <- record$checks[!is.na(record$checks$reference_defined), ]
    curves <- record$checks[!is.na(record$checks$finite_curve), ]
    stopifnot(all(scalar$reference_defined == 1000L), all(curves$finite_curve),
      all(scalar$reference_below >= 0L & scalar$reference_above >= 0L),
      all(scalar$reference_below + scalar$reference_above <= 1000L))
    # At 1000 references, rank bounds are order statistics 25 and 976.
    stopifnot(identical(unname(scalar$flagged),
      scalar$reference_below >= 976L | scalar$reference_above >= 976L))
  }
  if (all(usable) && record$status$comparison_error == "") {
    statistic <- max(0, 2 * diff(record$fits$log_likelihood))
    df <- diff(record$fits$likelihood_df)
    stopifnot(isTRUE(all.equal(unname(statistic), record$status$lrt_statistic)),
      isTRUE(all.equal(unname(df), record$status$lrt_df)),
      isTRUE(all.equal(pchisq(statistic, df, lower.tail = FALSE), record$status$lrt_p)))
  }
  for (policy in unique(record$policies$policy)) {
    chosen <- switch(policy, pooled = if (usable[["pooled"]]) "pooled" else NA_character_,
      full = if (usable[["full"]]) "full" else NA_character_,
      full_then_pooled = if (usable[["full"]]) "full" else if (usable[["pooled"]]) "pooled" else NA_character_,
      lrt_05 = if (all(usable)) {
        if (is.finite(record$status$lrt_p)) {
          if (record$status$lrt_p < .05) "full" else "pooled"
        } else NA_character_
      } else if (usable[["full"]]) "full" else if (usable[["pooled"]]) "pooled" else NA_character_)
    rows <- record$policies[record$policies$policy == policy, ]
    stopifnot(identical(rows$selected_model, rep(chosen, 4L)))
    if (!is.na(chosen)) {
      inference <- record$inference[record$inference$model == chosen & record$inference$primary, ]
      stopifnot(identical(rows$estimate, inference$estimate), identical(rows$se, inference$se))
    } else stopifnot(all(!rows$available))
  }
}

# Resume must read existing blocks without touching their bytes.
run_nb2_fallback(2L, 1000L, 1L, "run")
stopifnot(identical(hashes, tools::md5sum(files)))
without_timing <- function(record) {
  record$fits$elapsed_seconds <- NULL
  record$status$check_seconds <- NULL
  record
}
replays <- lapply(c(2L, 6L), function(condition_number) {
  condition <- conditions[conditions$condition == condition_number, ]
  original <- completed[vapply(completed, function(record)
    record$status$condition == condition_number && record$status$repetition == 1L, logical(1))][[1]]
  replay <- run_nb2_fallback_dataset(condition, 1L, 1000L)
  equality <- all.equal(without_timing(original), without_timing(replay), tolerance = 1e-8)
  stopifnot(isTRUE(equality))
  list(condition = condition_number, replay = replay, equal = equality)
})
stopifnot(identical(hashes, tools::md5sum(files)),
  identical(specification, nb2_fallback_specification(2L, 1000L)))
saveRDS(replays, file.path(directory, "serial-replays.rds"))
writeLines(c("NB2 fallback pilot passed.",
  "6 conditions, 12 datasets, 24 fits, 384 inference rows, 192 policy rows.",
  "All native panels available for every usable pooled fit; finite scalar references and curve bounds.",
  "Saved tail counts reproduce native rank flags. LRTs independently reconstructed from log-likelihood and df.",
  "Nominal usability and likelihood eligibility verified separately. All policy choices and exported tables reconstructed.",
  "Checkpoint resume leaves all blocks unchanged.",
  "Small and large conditions replayed serially with identical results apart from elapsed times.",
  "Pilot estimates and flag rates are workflow checks, not calibration evidence.", "",
  capture.output(print(result$exports$fits, n = Inf)), "",
  capture.output(print(tables$status, n = Inf))), file.path(directory, "pilot-validation.txt"))
cat("NB2 fallback pilot validation passed.\n")
