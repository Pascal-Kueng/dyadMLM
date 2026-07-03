#' Add arbitrary dyad role columns (needed for exchangeable dyad analyses)
#'
#' @param data An `interdep_data` object returned by [prepare_interdep_data()].
#' @param seed Optional seed for random arbitrary partner-role assignment. If
#'   `NULL`, the current R session's RNG state is used.
#'
#' @return The input data with columns .i_arbitrary_role, .i_is_arbitrary_role_1,
#' .i_is_arbitrary_role_2, and .i_diff. The indicator and diff columns are active
#' for exchangeable dyads and zero for distinguishable dyads.
#' @keywords internal
add_arbitrary_roles <- function(data, seed = NULL) {
  if (!inherits(data, "interdep_data")) {
    stop("`data` must be an `interdep_data` object.", call. = FALSE)
  }

  meta_data <- attr(data, "interdep")

  group_name <- meta_data$group
  member_name <- meta_data$member
  dyad_compositions <- meta_data$dyad_compositions

  # check which dyads are distinguishable vs. exchangeable.
  arbitrary_compositions <- dyad_compositions$composition[
    dyad_compositions$dyad_type == "exchangeable"
  ]

  # Handle the seed: apply it and make sure it restores when the function exits!
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

  # create the arbitrary (random) roles columns we need.
  random_member_roles <- data |>
    # Collapse repeated ILD rows to one role per member.
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
      .i_arbitrary_role = sample(
        c("arbitrary_role_1", "arbitrary_role_2"),
        # if we have a dyad where only 1 member is ever observed, we only sample
        # 1 value, otherwise both!
        size = dplyr::n()
      )
    ) |>
    dplyr::ungroup()

  data <- dplyr::left_join(
    data,
    random_member_roles,
    by = c(group_name, member_name)
  )

  # Only exchangeable dyads get active arbitrary-role model columns.
  # Distinguishable dyads get zero.
  uses_arbitrary_roles <- as.character(data[[interdep_composition_col]]) %in%
    arbitrary_compositions

  data$.i_is_arbitrary_role_1 <- ifelse(
    uses_arbitrary_roles & data$.i_arbitrary_role == "arbitrary_role_1",
    1,
    0
  )

  data$.i_is_arbitrary_role_2 <- ifelse(
    uses_arbitrary_roles & data$.i_arbitrary_role == "arbitrary_role_2",
    1,
    0
  )

  data$.i_diff <- ifelse(
    uses_arbitrary_roles,
    ifelse(data$.i_arbitrary_role == "arbitrary_role_1", -1, 1),
    0
  )

  data
}
