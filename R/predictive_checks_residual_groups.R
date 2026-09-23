# Map fitted observations to compositions without requiring complete observed pairs.
build_residual_check_groups <- function(model_frame, dyad_quo, role_quo,
                                       member_quo, data = NULL) {
  fitted_rows <- seq_len(nrow(model_frame))
  if (rlang::quo_is_null(role_quo)) {
    dyad_ids <- resolve_fitted_row_argument(
      dyad_quo, "dyad", model_frame, data, allow_null = TRUE
    )
    return(list(list(
      label = "All observations", rows = list(Pooled = fitted_rows),
      n_dyads = if (is.null(dyad_ids)) NULL else
        length(unique(dyad_ids[!is.na(dyad_ids) & !is.na(as.character(dyad_ids))]))
    )))
  }
  if (rlang::quo_is_null(dyad_quo)) {
    stop("`dyad` is required when `role` is supplied.", call. = FALSE)
  }

  # The original roster can identify a partner excluded during model fitting.
  roster <- if (is.null(data)) model_frame else data
  fitted_roster_rows <- match_fitted_rows(model_frame, roster)
  dyad_ids <- resolve_fitted_row_argument(dyad_quo, "dyad", roster)
  role_values <- resolve_fitted_row_argument(role_quo, "role", roster)
  member_ids <- resolve_fitted_row_argument(
    member_quo, "member", roster, allow_null = TRUE
  )
  known_dyad <- !is.na(dyad_ids) & !is.na(as.character(dyad_ids)) &
    dyad_ids %in% dyad_ids[fitted_roster_rows]
  if (is.null(member_ids)) {
    if (any(table(dyad_ids[known_dyad]) > 2L)) {
      stop("Supply `member` to identify each person when dyads have repeated rows.",
           call. = FALSE)
    }
    member_ids <- seq_len(nrow(roster))
  }

  # Integer codes preserve role order and avoid combining equal-looking labels.
  known_role <- !is.na(role_values) & !is.na(as.character(role_values))
  ordered_roles <- sort(unique(role_values[known_role]))
  roster <- tibble::tibble(
    dyad_number = match(dyad_ids, unique(dyad_ids)),
    member_number = match(member_ids, unique(member_ids)),
    role_index = match(role_values, ordered_roles),
    known_member = known_dyad & !is.na(member_ids) & !is.na(as.character(member_ids))
  )
  members <- roster |>
    dplyr::filter(.data$known_member) |>
    dplyr::summarise(
      n_roles = dplyr::n_distinct(.data$role_index, na.rm = TRUE),
      role_index = dplyr::first(.data$role_index[!is.na(.data$role_index)],
                                default = NA_integer_),
      .by = c("dyad_number", "member_number")
    )
  if (any(members$n_roles > 1L)) {
    stop("Each member must have the same role throughout the data.", call. = FALSE)
  }
  compositions <- members |>
    dplyr::summarise(
      n_members = dplyr::n(), first_role = min(.data$role_index),
      second_role = max(.data$role_index), .by = "dyad_number"
    )
  if (any(compositions$n_members > 2L)) {
    stop("Each dyad must contain at most two members.", call. = FALSE)
  }
  compositions <- compositions |>
    dplyr::filter(.data$n_members == 2L, !is.na(.data$first_role),
                  !is.na(.data$second_role))
  fitted_members <- roster[fitted_roster_rows, c("dyad_number", "member_number")] |>
    dplyr::mutate(fitted_row = fitted_rows) |>
    dplyr::left_join(members, by = c("dyad_number", "member_number")) |>
    dplyr::left_join(compositions, by = "dyad_number")
  unknown <- is.na(fitted_members$first_role) | is.na(fitted_members$role_index)
  if (all(unknown)) {
    stop("No fitted observations have a known two-member composition. ",
         "Supply the original fitting data with `data` if partners were excluded.",
         call. = FALSE)
  }
  if (any(unknown)) {
    warning(sum(unknown), " fitted observations omitted because their composition ",
            "or member role is unknown. Supply the original fitting data with `data` ",
            "if partners were excluded.", call. = FALSE)
  }
  fitted_members <- fitted_members[!unknown, ] |>
    dplyr::group_by(.data$first_role, .data$second_role) |>
    dplyr::group_split()
  lapply(fitted_members, function(current) {
    roles <- c(current$first_role[1], current$second_role[1])
    role_labels <- as.character(ordered_roles[roles])
    rows <- if (roles[1] == roles[2]) list(Pooled = current$fitted_row) else
      stats::setNames(lapply(roles, function(role) {
        current$fitted_row[current$role_index == role]
      }), role_labels)
    list(label = paste(role_labels, collapse = " - "), rows = rows,
         n_dyads = dplyr::n_distinct(current$dyad_number))
  })
}
