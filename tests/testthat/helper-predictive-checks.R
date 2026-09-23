distribution_check_fixture <- function() {
  predicted <- seq(0, 2, length.out = 12)
  structure(list(
    observed_response = predicted + seq(-2, 2, length.out = 12),
    predicted_response = predicted,
    simulated_responses = sweep(matrix(sin(seq_len(40 * 12)), 40),
                                2, predicted, "+"),
    model_frame = data.frame(
      dyad = rep(seq_len(6), each = 2), member = rep(1:2, 6),
      role = rep(c("A", "B"), 6)
    )
  ), class = "dyadMLM_response_simulations", dyadMLM = list(family = "gaussian"))
}
