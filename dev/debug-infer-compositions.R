# Scratch fixtures for developing interdep internals.
# Source this file, then call package functions on one of the raw_*,
# validated_*, or inferred_* objects, or run a setup_*_debug() helper.

devtools::load_all()


raw_complete_roles <- data.frame(
  dyad_id = c(1, 1, 2, 2, 3, 3),
  person_id = c("a", "b", "c", "d", "e", "f"),
  role = c("female", "male", "female", "male", "female", "female")
)

raw_sparse_ild_roles <- data.frame(
  dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
  person_id = c("a", "b", "a", "b", "c", "d", "c", "d"),
  role = c("female", "male", NA, NA, "female", "female", NA, NA),
  time = c(1, 1, 2, 2, 1, 1, 2, 2)
)

raw_missing_roles <- data.frame(
  dyad_id = c(1, 1, 2, 2, 3, 3),
  person_id = c("a", "b", "c", "d", "e", "f"),
  role = c("female", "male", "female", NA, "female", "female")
)

raw_incomplete_roles <- data.frame(
  dyad_id = c(1, 1, 2, 3, 3),
  person_id = c("a", "b", "c", "d", "e"),
  role = c("female", "male", "female", "female", "female")
)


validated_complete_roles <- validate_interdep_data(
  raw_complete_roles,
  group = dyad_id,
  member = person_id,
  role = role
)

validated_sparse_ild_roles <- validate_interdep_data(
  raw_sparse_ild_roles,
  group = dyad_id,
  member = person_id,
  role = role,
  time = time
)

validated_missing_roles_drop <- validate_interdep_data(
  raw_missing_roles,
  group = dyad_id,
  member = person_id,
  role = role,
  missing_role = "drop"
)

validated_incomplete_roles_drop <- validate_interdep_data(
  raw_incomplete_roles,
  group = dyad_id,
  member = person_id,
  role = role,
  incomplete_dyads = "drop"
)


inferred_complete_roles <- infer_dyad_compositions(validated_complete_roles)

inferred_sparse_ild_roles <- infer_dyad_compositions(validated_sparse_ild_roles)

inferred_missing_roles_drop <- infer_dyad_compositions(validated_missing_roles_drop)

inferred_incomplete_roles_drop <- infer_dyad_compositions(validated_incomplete_roles_drop)


setup_interdep_debug <- function(
    data = validated_complete_roles,
    seed = NULL,
    generated_columns = character()
  ) {
  meta_data <- attr(data, "interdep")

  assign("data", data, envir = .GlobalEnv)
  assign("seed", seed, envir = .GlobalEnv)
  assign("generated_columns", generated_columns, envir = .GlobalEnv)
  assign("meta_data", meta_data, envir = .GlobalEnv)

  if (!is.null(meta_data)) {
    assign("group_name", meta_data$group, envir = .GlobalEnv)
    assign("member_name", meta_data$member, envir = .GlobalEnv)
    assign("role_name", meta_data$role, envir = .GlobalEnv)
    assign("time_name", meta_data$time, envir = .GlobalEnv)
    assign("incomplete_groups", meta_data$incomplete_dyads, envir = .GlobalEnv)
  }

  invisible(data)
}


setup_validate_debug <- function(data = raw_complete_roles) {
  setup_interdep_debug(data = data)
}



setup_infer_debug <- function(data = validated_complete_roles, seed = NULL) {
  setup_interdep_debug(
    data = data,
    seed = seed,
    generated_columns = c(
      ".i_composition",
      ".i_composition_role",
      ".i_diff"
    )
  )
}


setup_assign_arbitrary_member_roles_debug <- function(
    data = validated_complete_roles,
    seed = NULL
  ) {
  setup_interdep_debug(
    data = data,
    seed = seed,
    generated_columns = ".i_arbitrary_role"
  )
}
