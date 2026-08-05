#' Temporarily complete observed dyad occasions
#'
#' Adds the missing member row when only one member is present at an observed
#' dyad occasion. Structural identifiers and a resolved stable role are kept;
#' all measured variables are missing on the added row. The added rows are used
#' only while model-ready columns are constructed.
#'
#' @param data A validated `dyadMLM_data` object.
#'
#' @return A `dyadMLM_data` object containing temporary missing-member rows and
#'   an internal column recording the original row order.
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
  # Work with a plain tibble and mark every supplied row. Temporary rows added
  # below receive NA for this column, so the marker also restores row order.
  input_data <- tibble::as_tibble(data) |>
    dplyr::mutate(.dy_original_row = dplyr::row_number())

  dyad_member_columns <- c(metadata$dyad, metadata$member)
  if (!is.null(metadata$role)) {
    # Keep the stable role so temporary member rows retain their composition.
    # Role is carried along as information. It is not part of the row key.
    dyad_member_columns <- c(dyad_member_columns, metadata$role)
  }

  # Reduce repeated longitudinal rows to one lookup row per member.
  # Since validation ensures that both members show up at least once, this is
  # complete.
  known_dyad_members <- input_data |>
    dplyr::select(dplyr::all_of(dyad_member_columns)) |>
    dplyr::distinct()

  # Retain only occasions on which at least one member was observed.
  observed_dyad_occasions <- input_data |>
    dplyr::select(dplyr::all_of(c(metadata$dyad, metadata$time))) |>
    dplyr::distinct()

  # Join for "complete" data frame (only structural yet)  -----------------

  # Within each dyad, cross its observed occasions with its two known members.
  completed_dyad_occasion_keys <- dplyr::left_join(
    observed_dyad_occasions,
    known_dyad_members,
    by = metadata$dyad,
    relationship = "many-to-many"
  )

  # Find only the missing rows ----------------------------------

  # Keep only genuinely absent member rows. Variables not included in the
  # structural lookup are filled with NA when these rows are appended.
  temporary_missing_member_rows <- dplyr::anti_join(
    completed_dyad_occasion_keys,
    input_data,
    by = row_key_columns
  )

  # Bind rows inserts NA to any variables that are not present in the bound
  # dataset (e.g., all non-structural columns)
  temporarily_completed_data <- dplyr::bind_rows(
    input_data,
    temporary_missing_member_rows
  )

  # re-add metadata that was removed at the start
  attr(temporarily_completed_data, "dyadMLM") <- metadata
  class(temporarily_completed_data) <- class(data)

  temporarily_completed_data
}


#' Restore rows observed in the supplied data
#'
#' Removes rows added by [temporarily_complete_dyad_occasions()] and restores
#' the original row order. Rows removed by an explicit preparation option, such
#' as composition filtering, remain removed.
#'
#' @param data A temporarily completed `dyadMLM_data` object after model-ready
#'   columns have been constructed.
#' @return A `dyadMLM_data` object containing only originally observed rows.
#'
#' @keywords internal
restore_observed_dyad_rows <- function(data) {
  if (!inherits(data, "dyadMLM_data")) {
    stop("`data` must be a `dyadMLM_data` object.", call. = FALSE)
  }

  metadata <- attr(data, "dyadMLM")
  original_data_class <- class(data)

  # Temporary rows have no original row number. Keep the supplied rows, restore
  # their order, and remove the internal marker.
  restored_data <- data |>
    dplyr::filter(!is.na(.data$.dy_original_row)) |>
    dplyr::arrange(.data$.dy_original_row) |>
    dplyr::select(-dplyr::all_of(".dy_original_row"))

  attr(restored_data, "dyadMLM") <- metadata
  class(restored_data) <- original_data_class

  restored_data
}
