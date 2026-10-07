# Summarize saved results only; no refitting or changes to the original study.
# Both-eligible datasets are a selected sensitivity subset, not the primary analysis.
run_nb2_paired_inference <- function(
    input_directory = "dev/diagnostic_checks/simulation-studies/results/model-simplification/nb2-fallback/500-datasets-1000-draws",
    output_directory = "dev/diagnostic_checks/simulation-studies/report-data/model-simplification-nb2") {
  input_files <- list.files(input_directory, full.names = TRUE)
  input_hashes <- tools::md5sum(input_files)
  tables <- readRDS(file.path(input_directory, "dataset-tables.rds"))
  specification <- readRDS(file.path(input_directory, "run-specification.rds"))
  keys <- c("condition", "repetition")
  stopifnot(!anyNA(input_hashes),
    !anyDuplicated(tables$fits[c(keys, "model")]),
    !anyDuplicated(tables$inference[c(keys, "model", "parameter")]),
    !anyDuplicated(tables$policies[c(keys, "policy", "parameter")]),
    nrow(tables$fits) == 2L * nrow(specification$conditions) * specification$repetitions)
  both <- tables$fits |>
    dplyr::summarise(both_eligible = dplyr::n() == 2L && all(eligible),
      .by = dplyr::all_of(keys)) |>
    dplyr::filter(both_eligible)
  inference <- tables$inference |>
    dplyr::filter(primary) |>
    dplyr::mutate(method = paste0("fit_", model), available = eligible & defined)
  policies <- tables$policies |>
    dplyr::mutate(method = paste0("policy_", policy))
  columns <- c(keys, "method", "parameter", "true_value", "estimate", "se",
    "available", "covered", "significant")
  rows <- dplyr::bind_rows(dplyr::select(inference, dplyr::all_of(columns)),
    dplyr::select(policies, dplyr::all_of(columns))) |>
    dplyr::inner_join(both[keys], by = keys)
  stopifnot(nrow(rows) == 24L * nrow(both),
    !anyDuplicated(rows[c(keys, "method", "parameter")]))
  full <- rows |>
    dplyr::filter(method == "fit_full") |>
    dplyr::select(dplyr::all_of(keys), parameter, full_available = available,
      full_covered = covered, full_significant = significant)
  rows <- dplyr::left_join(rows, full, by = c(keys, "parameter"))
  stopifnot(!anyNA(rows$full_available))

  rate_summary <- function(values) {
    n <- length(values)
    k <- sum(values)
    p <- k / n
    z <- qnorm(.975)
    center <- (k + z^2 / 2) / (n + z^2)
    half <- z * sqrt(n * p * (1 - p) + z^2 / 4) / (n + z^2)
    c(numerator = k, rate = p, mcse = sqrt(p * (1 - p) / n),
      lower = max(0, center - half), upper = min(1, center + half))
  }
  difference_summary <- function(values) {
    difference <- mean(values)
    mcse <- stats::sd(values) / sqrt(length(values))
    c(difference = difference, mcse = mcse,
      lower = max(-1, difference - qnorm(.975) * mcse),
      upper = min(1, difference + qnorm(.975) * mcse))
  }
  summarize <- function(group) {
    used <- group[group$available, ]
    paired <- group[group$available & group$full_available, ]
    stopifnot(length(unique(group$true_value)) == 1L)
    result <- data.frame(condition = group$condition[1], method = group$method[1],
      parameter = group$parameter[1], true_value = group$true_value[1],
      both_eligible_n = nrow(group), available_n = nrow(used),
      bias = mean(used$estimate - used$true_value),
      bias_mcse = stats::sd(used$estimate - used$true_value) / sqrt(nrow(used)),
      empirical_sd = stats::sd(used$estimate), mean_se = mean(used$se),
      se_ratio = mean(used$se) / stats::sd(used$estimate), paired_n = nrow(paired),
      paired_full_coverage = mean(paired$full_covered),
      paired_full_rejection = mean(paired$full_significant))
    for (metric in c("coverage", "rejection")) {
      field <- if (metric == "coverage") "covered" else "significant"
      rate <- rate_summary(used[[field]])
      names(rate) <- paste0(metric, "_", names(rate))
      names(rate)[names(rate) == paste0(metric, "_rate")] <- metric
      difference <- difference_summary(as.integer(paired[[field]]) -
        as.integer(paired[[paste0("full_", field)]]))
      names(difference) <- paste0("paired_", metric, "_", names(difference))
      result <- cbind(result, as.data.frame(as.list(c(rate, difference))))
    }
    result
  }
  groups <- split(rows, interaction(rows$condition, rows$method, rows$parameter, drop = TRUE))
  result <- dplyr::bind_rows(lapply(groups, summarize)) |>
    dplyr::arrange(condition, method, parameter)
  stopifnot(identical(input_hashes, tools::md5sum(input_files)))
  dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)
  write.csv(result, file.path(output_directory, "paired-inference.csv"), row.names = FALSE)
  result
}

if (sys.nframe() == 0L) {
  arguments <- commandArgs(trailingOnly = TRUE)
  result <- do.call(run_nb2_paired_inference, as.list(arguments))
  message("Saved paired sensitivity: ", nrow(result), " rows.")
}
