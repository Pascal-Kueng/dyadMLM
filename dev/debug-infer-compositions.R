# Scratch fixtures for developing infer_dyad_compositions().
# Source this file, then call infer_dyad_compositions() on one of the
# validated_* objects or run the setup_infer_debug() helper.

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
  time = time,
  missing_role = "keep"
)

validated_missing_roles_keep <- validate_interdep_data(
  missing_roles,
  group = dyad_id,
  member = person_id,
  role = role,
  missing_role = "keep"
)

validated_missing_roles_drop <- validate_interdep_data(
  missing_roles,
  group = dyad_id,
  member = person_id,
  role = role,
  missing_role = "drop"
)

validated_incomplete_roles_keep <- validate_interdep_data(
  incomplete_roles,
  group = dyad_id,
  member = person_id,
  role = role,
  incomplete_dyads = "keep"
)

validated_incomplete_roles_drop <- validate_interdep_data(
  incomplete_roles,
  group = dyad_id,
  member = person_id,
  role = role,
  incomplete_dyads = "drop"
)


setup_infer_debug <- function(data = validated_incomplete_roles_keep) {
  meta_data <<- attr(data, "interdep")
  group_name <<- meta_data$group
  member_name <<- meta_data$member
  role_name <<- meta_data$role
  incomplete_groups <<- meta_data$incomplete_dyads
  data <<- data

  invisible(data)
}
