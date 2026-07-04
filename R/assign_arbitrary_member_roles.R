#' Assign arbitrary member roles within dyads
#'
#' Creates a member-level lookup with one arbitrary role per observed member.
#' The assignment is stable across longitudinal rows because it is made once per
#' `group` x `member`.
#'
#' @param data A data frame.
#' @param group_name Name of the dyad/group column.
#' @param member_name Name of the member/person column.
#' @param seed Optional seed for random arbitrary partner-role assignment. If
#'   `NULL`, the current R session's RNG state is used.
#'
#' @return A data frame with `group_name`, `member_name`, and
#'   `.i_arbitrary_role`.
#' @keywords internal
assign_arbitrary_member_roles <- function(data, group_name, member_name, seed = NULL) {
  if (!is.null(seed)) {
    has_old_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    if (has_old_seed) {
      old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    }

    set.seed(seed)

    on.exit({
      if (has_old_seed) {
        assign(".Random.seed", old_seed, envir = .GlobalEnv)
      } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
        rm(".Random.seed", envir = .GlobalEnv)
      }
    }, add = TRUE)
  }

  data |>
    dplyr::distinct(
      .data[[group_name]],
      .data[[member_name]]
    ) |>
    dplyr::arrange(
      .data[[group_name]],
      .data[[member_name]]
    ) |>
    dplyr::group_by(.data[[group_name]]) |>
    dplyr::mutate(
      "{interdep_arbitrary_role_col}" := sample(
        c("arbitrary_1", "arbitrary_2"),
        size = dplyr::n()
      )
    ) |>
    dplyr::ungroup()
}


add_arbitrary_member_roles <- function(data, group_name, member_name, seed = NULL) {
  arbitrary_roles <- assign_arbitrary_member_roles(
    data = data,
    group_name = group_name,
    member_name = member_name,
    seed = seed
  )

  dplyr::left_join(
    data,
    arbitrary_roles,
    by = c(group_name, member_name)
  )
}
