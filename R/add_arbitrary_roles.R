#' Add arbitrary dyad role columns (needed for exchangeable dyad analyses)
#'
#' @param data An `interdep_data` object returned by [prepare_interdep_data()].
#' @param seed Optional seed for random arbitrary partner-role assignment. If
#'   `NULL`, the current R session's RNG state is used.
#'
#' @return The input data with columns .i_arbitrary_role, .i_is_arbitrary_role1,
#' .i_is_arbitrary_role2, .i_diff which can be used in models.
#' @keywords internal
add_arbitrary_roles <- function(data, seed = NULL) {
  if (!inherits(data, "interdep_data")) {
    stop("`data` must be an `interdep_data` object.", call. = FALSE)
  }

  meta_data <- attr(data, "interdep")

  group_name <- meta_data$group
  member_name <- meta_data$member
  time_name <- meta_data$time

  if (!is.null(seed)) {
    # store old seed if one was set
    if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      old_seed <- .Random.seed
    }

    set.seed(seed)

    on.exit({
      if (exists(old_seed)) {
        assign(".Random.seed", old_seed, envir = .GlobalEnv)
      } else {
        rm(".Random.seed", envir = .GlobalEnv)
      }
    }, add = TRUE)
  }



  data
}
