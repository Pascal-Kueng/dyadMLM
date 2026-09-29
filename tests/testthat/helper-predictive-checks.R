# Count pages without external tools: the device writes one file per page.
count_pdf_pages <- function(code, ...) {
  directory <- withr::local_tempdir()
  grDevices::pdf(file.path(directory, "page%03d.pdf"), onefile = FALSE, ...)
  tryCatch(force(code), finally = grDevices::dev.off())
  length(list.files(directory))
}

distribution_check_fixture <- function() {
  predicted <- seq(0, 2, length.out = 12)
  structure(list(
    observed_response = predicted + seq(-2, 2, length.out = 12),
    predicted_response = predicted,
    simulated_responses = sweep(matrix(sin(seq_len(200 * 12)), 200),
                                2, predicted, "+"),
    model_frame = data.frame(
      dyad = rep(seq_len(6), each = 2), member = rep(1:2, 6),
      role = rep(c("A", "B"), 6)
    )
  ), class = "dyadMLM_response_simulations", dyadMLM = list(family = "gaussian"))
}

subset_fixture <- function(simulations, rows) {
  simulations$observed_response <- simulations$observed_response[rows]
  simulations$predicted_response <- simulations$predicted_response[rows]
  simulations$simulated_responses <- simulations$simulated_responses[, rows, drop = FALSE]
  simulations$model_frame <- simulations$model_frame[rows, , drop = FALSE]
  simulations
}
