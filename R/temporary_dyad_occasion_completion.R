#' Temporarily complete observed dyad occasions
#'
#' Adds the missing member row when only one member is present at an observed
#' dyad occasion. Structural identifiers and a resolved stable role are kept;
#' all measured variables are missing on the added row. The added rows are used
#' only while model-ready columns are constructed.
#'
#' @param data A validated `dyadMLM_data` object.
#'
#' @return A list containing the temporarily completed data and the original
#'   observed row keys.
#'
#' @keywords internal
temporarily_complete_dyad_occasions <- function(data) {
  if (!inherits(data, "dyadMLM_data")) {
    stop("`data` must be a validated `dyadMLM_data` object.", call. = FALSE)
  }

  metadata <- attr(data, "dyadMLM")

  if (!metadata$longitudinal) {
    stop("Temporary dyad-occasion completion requires longitudinal data.", call. = FALSE)
  }

  row_key_columns <- c(metadata$dyad, metadata$member, metadata$time)
  input_data <- tibble::as_tibble(data)

  # Save the structural key and order of every supplied row. These keys are
  # used after preparation to remove only the rows added below.
  original_observed_row_keys <- input_data |>
    dplyr::select(dplyr::all_of(row_key_columns)) |>
    dplyr::mutate(.dy_original_row = dplyr::row_number())

  dyad_member_columns <- c(metadata$dyad, metadata$member)
  if (!is.null(metadata$role)) {
    # Keep the stable role so temporary member rows retain their composition.
    # Role is carried along as information. It is not part of the row key.
    dyad_member_columns <- c(dyad_member_columns, metadata$role)
  }

  # Validation guarantees exactly two known members per dyad. Reduce their
  # repeated longitudinal rows to one lookup row per member.
  known_dyad_members <- input_data |>
    dplyr::select(dplyr::all_of(dyad_member_columns)) |>
    dplyr::distinct()

  # Retain only occasions on which at least one member was observed. Entirely
  # unobserved occasions are not added.
  observed_dyad_occasions <- input_data |>
    dplyr::select(dplyr::all_of(c(metadata$dyad, metadata$time))) |>
    dplyr::distinct()

  # Within each dyad, cross its observed occasions with its two known members.
  completed_dyad_occasion_keys <- dplyr::left_join(
    observed_dyad_occasions,
    known_dyad_members,
    by = metadata$dyad,
    relationship = "many-to-many"
  )

  # Keep only genuinely absent member rows. Variables not included in the
  # structural lookup are filled with NA when these rows are appended.
  temporary_missing_member_rows <- dplyr::anti_join(
    completed_dyad_occasion_keys,
    original_observed_row_keys,
    by = row_key_columns
  )

  if (nrow(temporary_missing_member_rows) == 0L) {
    return(list(
      data = data,
      original_observed_row_keys = original_observed_row_keys
    ))
  }

  temporarily_completed_data <- dplyr::bind_rows(
    input_data,
    temporary_missing_member_rows
  )
  attr(temporarily_completed_data, "dyadMLM") <- metadata
  class(temporarily_completed_data) <- class(data)

  list(
    data = temporarily_completed_data,
    original_observed_row_keys = original_observed_row_keys
  )
}


#' Restore rows observed in the supplied data
#'
#' Removes rows added by [temporarily_complete_dyad_occasions()] and restores
#' the original row order. Rows removed by an explicit preparation option, such
#' as composition filtering, remain removed.
#'
#' @param data A temporarily completed `dyadMLM_data` object after model-ready
#'   columns have been constructed.
#' @param original_observed_row_keys Original row keys returned by
#'   [temporarily_complete_dyad_occasions()].
#'
#' @return A `dyadMLM_data` object containing only originally observed rows.
#'
#' @keywords internal
restore_observed_dyad_rows <- function(data, original_observed_row_keys) {
  if (!inherits(data, "dyadMLM_data")) {
    stop("`data` must be a `dyadMLM_data` object.", call. = FALSE)
  }

  metadata <- attr(data, "dyadMLM")
  row_key_columns <- c(metadata$dyad, metadata$member, metadata$time)
  original_data_class <- class(data)

  # The inner join drops temporary rows and attaches the original row order.
  restored_data <- dplyr::inner_join(
    data,
    original_observed_row_keys,
    by = row_key_columns,
    relationship = "one-to-one"
  ) |>
    dplyr::arrange(.data$.dy_original_row) |>
    dplyr::select(-dplyr::all_of(".dy_original_row"))

  attr(restored_data, "dyadMLM") <- metadata
  class(restored_data) <- original_data_class

  restored_data
}
