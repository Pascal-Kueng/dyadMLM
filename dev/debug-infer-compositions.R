# Scratch fixtures for developing infer_dyad_compositions() and
# add_arbitrary_roles().
# Source this file, then call infer_dyad_compositions() on one of the
# validated_* objects, call add_arbitrary_roles() on one of the inferred_*
# objects, or run one of the setup_*_debug() helpers.

devtools::load_all()


complete_roles <- data.frame(
  dyad_id = c(1, 1, 2, 2, 3, 3),
  person_id = c("a", "b", "c", "d", "e", "f"),
  role = c("female", "male", "female", "male", "female", "female")
)

sparse_ild_roles <- data.frame(
  dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
  person_id = c("a", "b", "a", "b", "c", "d", "c", "d"),
  role = c("female", "male", NA, NA, "female", "female", NA, NA),
  time = c(1, 1, 2, 2, 1, 1, 2, 2)
)

missing_roles <- data.frame(
  dyad_id = c(1, 1, 2, 2, 3, 3),
  person_id = c("a", "b", "c", "d", "e", "f"),
  role = c("female", "male", "female", NA, "female", "female")
)

incomplete_roles <- data.frame(
  dyad_id = c(1, 1, 2, 3, 3),
  person_id = c("a", "b", "c", "d", "e"),
  role = c("female", "male", "female", "female", "female")
)


validated_complete_roles <- validate_interdep_data(
  complete_roles,
  group = dyad_id,
  member = person_id,
  role = role
)

validated_sparse_ild_roles <- validate_interdep_data(
  sparse_ild_roles,
  group = dyad_id,
  member = person_id,
  role = role,
  time = time
)

validated_missing_roles_drop <- validate_interdep_data(
  missing_roles,
  group = dyad_id,
  member = person_id,
  role = role,
  missing_role = "drop"
)

validated_incomplete_roles_drop <- validate_interdep_data(
  incomplete_roles,
  group = dyad_id,
  member = person_id,
  role = role,
  incomplete_dyads = "drop"
)


inferred_complete_roles <- infer_dyad_compositions(validated_complete_roles)

inferred_sparse_ild_roles <- infer_dyad_compositions(validated_sparse_ild_roles)

inferred_missing_roles_drop <- infer_dyad_compositions(validated_missing_roles_drop)

inferred_incomplete_roles_drop <- infer_dyad_compositions(validated_incomplete_roles_drop)


setup_infer_debug <- function(data = validated_complete_roles) {
  meta_data <- attr(data, "interdep")

  assign("data", data, envir = .GlobalEnv)
  assign("meta_data", meta_data, envir = .GlobalEnv)
  assign("group_name", meta_data$group, envir = .GlobalEnv)
  assign("member_name", meta_data$member, envir = .GlobalEnv)
  assign("role_name", meta_data$role, envir = .GlobalEnv)
  assign("incomplete_groups", meta_data$incomplete_dyads, envir = .GlobalEnv)

  invisible(data)
}


setup_arbitrary_roles_debug <- function(data = inferred_complete_roles, seed = NULL) {
  meta_data <- attr(data, "interdep")

  assign("data", data, envir = .GlobalEnv)
  assign("seed", seed, envir = .GlobalEnv)
  assign("meta_data", meta_data, envir = .GlobalEnv)
  assign("group_name", meta_data$group, envir = .GlobalEnv)
  assign("member_name", meta_data$member, envir = .GlobalEnv)
  assign("time_name", meta_data$time, envir = .GlobalEnv)
  assign("incomplete_groups", meta_data$incomplete_dyads, envir = .GlobalEnv)
  assign(
    "generated_columns",
    c(
      ".i_arbitrary_role",
      ".i_is_arbitrary_role_1",
      ".i_is_arbitrary_role_2",
      ".i_diff"
    ),
    envir = .GlobalEnv
  )

  invisible(data)
}
