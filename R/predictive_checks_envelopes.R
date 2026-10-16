# Compare complete curves using extreme rank length (ERL), with the observed
# curve treated symmetrically. Keep boundary ties together: column order must
# not decide which curves fall outside the 95% global envelope.
residual_curve_summary <- function(values) {
  result <- list(observed = values[, 1],
                 lower = rep(NA_real_, nrow(values)),
                 upper = rep(NA_real_, nrow(values)))
  available <- rowSums(!is.na(values)) > 0L
  if (!any(available)) return(result)
  curves <- values[available, , drop = FALSE]
  if (any(!is.finite(curves)))
    stop("Residual curves must be finite or have whole missing rows.", call. = FALSE)

  number_of_curves <- ncol(curves)
  pointwise_ranks <- t(vapply(seq_len(nrow(curves)), function(row)
    rank(curves[row, ], ties.method = "average"), numeric(number_of_curves)))
  extreme_ranks <- pmin(pointwise_ranks, number_of_curves + 1 - pointwise_ranks)
  sorted_ranks <- vapply(seq_len(number_of_curves), function(column)
    sort(extreme_ranks[, column]), numeric(nrow(curves)))
  sorted_ranks <- matrix(sorted_ranks, nrow = nrow(curves))
  curve_order <- do.call(order, as.data.frame(t(sorted_ranks)))
  number_to_remove <- floor(.05 * number_of_curves)
  retained <- curve_order[seq.int(number_to_remove + 1L, number_of_curves)]
  boundary_ties <- colSums(sorted_ranks != sorted_ranks[, retained[1]]) == 0L
  retained <- unique(c(retained, which(boundary_ties)))
  result$lower[available] <- apply(curves[, retained, drop = FALSE], 1, min)
  result$upper[available] <- apply(curves[, retained, drop = FALSE], 1, max)
  result
}

# Strict comparisons with these order statistics allocate at most half the
# allowed departures to each tail. Too few draws cannot bound both tails.
simulated_rank_limits <- function(values, level = .95) {
  values <- sort(unname(values[is.finite(values)]))
  number_of_simulations <- length(values)
  if (!number_of_simulations) return(c(NA_real_, NA_real_))
  tail_count <- floor((1 - level) * (number_of_simulations + 1) / 2)
  c(-Inf, values, Inf)[c(tail_count + 1L, number_of_simulations + 2L - tail_count)]
}
