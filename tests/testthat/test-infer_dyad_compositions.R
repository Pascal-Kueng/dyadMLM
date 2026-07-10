test_that("infer_dyad_compositions counts role compositions", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2, 3, 3, 4, 4),
    person_id = c("A", "B", "C", "D", "E", "F", "G", "H"),
    role = c("female", "male", "female", "male", "female", "female", "male", "male")
  )

  validated <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role
  )

  result <- infer_dyad_compositions(validated, seed = 123)
  expect_s3_class(result, "interdep_data")
  expect_false(".i_raw_composition" %in% names(result))
  expect_false(".i_arbitrary_role" %in% names(result))
  expect_true(".i_composition" %in% names(result))
  expect_true(".i_composition_role" %in% names(result))
  expect_true(is.factor(result$.i_composition))
  expect_true(is.factor(result$.i_composition_role))
  indicator_names <- grep("^\\.i_is_", names(result), value = TRUE)
  expect_equal(
    indicator_names,
    c(
      ".i_is_female_x_female",
      ".i_is_female_x_male_female",
      ".i_is_female_x_male_male",
      ".i_is_male_x_male"
    )
  )
  expect_true(".i_diff_female_x_female" %in% names(result))
  expect_true(".i_diff_male_x_male" %in% names(result))
  expect_true(all(sapply(result[indicator_names], is.numeric)))
  expect_equal(rowSums(result[indicator_names]), rep(1, nrow(result)))

  dyad_compositions <- attr(result, "interdep")$dyad_compositions
  dyad_compositions <- dyad_compositions[order(dyad_compositions$composition), ]

  expect_equal(
    dyad_compositions$composition,
    c("female_x_female", "female_x_male", "male_x_male")
  )
  expect_equal(
    dyad_compositions$dyad_type,
    c("exchangeable", "distinguishable", "exchangeable")
  )
  expect_equal(
    dyad_compositions$dyad_type_source,
    c("inferred", "inferred", "inferred")
  )
  expect_equal(
    dyad_compositions$pooled_from,
    c(NA_character_, NA_character_, NA_character_)
  )
  expect_equal(dyad_compositions$n_dyads, c(1L, 2L, 1L))
  expect_equal(
    as.character(result$.i_composition),
    c("female_x_male", "female_x_male", "female_x_male", "female_x_male",
      "female_x_female", "female_x_female", "male_x_male", "male_x_male")
  )
  expect_equal(
    as.character(result$.i_composition_role),
    c("female_x_male_female", "female_x_male_male",
      "female_x_male_female", "female_x_male_male",
      "female_x_female", "female_x_female",
      "male_x_male", "male_x_male")
  )
  expect_false(interdep_diff_col %in% names(result))
  expect_equal(abs(result$.i_diff_female_x_female[result$dyad_id == 3]), rep(1, 2))
  expect_equal(abs(result$.i_diff_male_x_male[result$dyad_id == 4]), rep(1, 2))
  expect_equal(result$.i_diff_female_x_female[result$dyad_id != 3], rep(0, 6))
  expect_equal(result$.i_diff_male_x_male[result$dyad_id != 4], rep(0, 6))
})

test_that("composition-specific diff signs do not depend on distinguishable dyads", {
  exchangeable_only <- data.frame(
    dyad_id = c(2, 2, 3, 3),
    person_id = c("C", "D", "E", "F"),
    role = c("female", "female", "male", "male")
  )
  mixed <- rbind(
    data.frame(
      dyad_id = c(1, 1),
      person_id = c("A", "B"),
      role = c("female", "male")
    ),
    exchangeable_only
  )

  exchangeable_result <- validate_interdep_data(
    exchangeable_only,
    group = dyad_id,
    member = person_id,
    role = role
  ) |>
    infer_dyad_compositions(seed = 123)

  mixed_result <- validate_interdep_data(
    mixed,
    group = dyad_id,
    member = person_id,
    role = role
  ) |>
    infer_dyad_compositions(seed = 123)

  expect_equal(
    mixed_result$.i_diff_female_x_female[mixed_result$dyad_id == 2],
    exchangeable_result$.i_diff_female_x_female[exchangeable_result$dyad_id == 2]
  )
  expect_equal(
    mixed_result$.i_diff_male_x_male[mixed_result$dyad_id == 3],
    exchangeable_result$.i_diff_male_x_male[exchangeable_result$dyad_id == 3]
  )
})

test_that("infer_dyad_compositions can set distinguishable compositions exchangeable", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male")
  )

  validated <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role
  )

  result <- infer_dyad_compositions(
    validated,
    seed = 123,
    set_exchangeable_compositions = "male-female"
  )

  expect_true(".i_is_female_x_male" %in% names(result))
  expect_false(".i_is_female_x_male_female" %in% names(result))
  expect_false(".i_is_female_x_male_male" %in% names(result))
  expect_true(".i_diff_female_x_male" %in% names(result))
  expect_equal(abs(result$.i_diff_female_x_male), rep(1, 4))
  expect_equal(as.character(result$.i_composition), rep("female_x_male", 4))
  expect_equal(as.character(result$.i_composition_role), rep("female_x_male", 4))
  expect_equal(
    attr(result, "interdep")$dyad_compositions,
    tibble::tibble(
      composition = "female_x_male",
      dyad_type = "exchangeable",
      dyad_type_source = "set_by_user",
      pooled_from = NA_character_,
      n_dyads = 2L
    )
  )
  expect_equal(
    attr(result, "interdep")$dyad_compositions$dyad_type_source,
    "set_by_user"
  )
})

test_that("infer_dyad_compositions accepts separated composition references", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male")
  )

  validated <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role
  )

  result_hyphen <- validated |>
    infer_dyad_compositions(
      seed = 123,
      set_exchangeable_compositions = "female-male"
    )
  result_underscore <- validated |>
    infer_dyad_compositions(
      seed = 123,
      set_exchangeable_compositions = "female_male"
    )
  result_space <- validated |>
    infer_dyad_compositions(
      seed = 123,
      set_exchangeable_compositions = "female male"
    )
  result_canonical <- validated |>
    infer_dyad_compositions(
      seed = 123,
      set_exchangeable_compositions = "female_x_male"
    )

  expect_equal(attr(result_hyphen, "interdep")$dyad_compositions$dyad_type, "exchangeable")
  expect_equal(attr(result_underscore, "interdep")$dyad_compositions$dyad_type, "exchangeable")
  expect_equal(attr(result_space, "interdep")$dyad_compositions$dyad_type, "exchangeable")
  expect_equal(attr(result_canonical, "interdep")$dyad_compositions$dyad_type, "exchangeable")
})

test_that("infer_dyad_compositions accepts a vector of separated composition references", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "younger", "older")
  )

  result <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role
  ) |>
    infer_dyad_compositions(
      seed = 123,
      set_exchangeable_compositions = c("female-male", "older younger")
    )

  dyad_compositions <- attr(result, "interdep")$dyad_compositions
  dyad_compositions <- dyad_compositions[order(dyad_compositions$composition), ]

  expect_equal(dyad_compositions$composition, c("female_x_male", "older_x_younger"))
  expect_equal(dyad_compositions$dyad_type, c("exchangeable", "exchangeable"))
  expect_equal(dyad_compositions$dyad_type_source, c("set_by_user", "set_by_user"))
})

test_that("infer_dyad_compositions pools exchangeable compositions", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "female", "male", "male")
  )

  result <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role
  ) |>
    infer_dyad_compositions(
      seed = 123,
      pool_compositions = list(same_sex = c("female-female", "male male"))
    )

  expect_true(".i_is_same_sex" %in% names(result))
  expect_true(".i_diff_same_sex" %in% names(result))
  expect_false(".i_diff_female_x_female" %in% names(result))
  expect_false(".i_diff_male_x_male" %in% names(result))
  expect_equal(as.character(result$.i_composition), rep("same_sex", 4))
  expect_equal(as.character(result$.i_composition_role), rep("same_sex", 4))

  expect_equal(
    attr(result, "interdep")$dyad_compositions,
    tibble::tibble(
      composition = "same_sex",
      dyad_type = "exchangeable",
      dyad_type_source = "inferred",
      pooled_from = "female_x_female, male_x_male",
      n_dyads = 2L
    )
  )
})

test_that("infer_dyad_compositions preserves unpooled exchangeable compositions", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2, 3, 3),
    person_id = c("A", "B", "C", "D", "E", "F"),
    role = c("female", "female", "male", "male", "friend", "friend")
  )

  result <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role
  ) |>
    infer_dyad_compositions(
      seed = 123,
      pool_compositions = list(same_sex = c("female-female", "male male"))
    )

  dyad_compositions <- attr(result, "interdep")$dyad_compositions
  dyad_compositions <- dyad_compositions[order(dyad_compositions$composition), ]

  expect_equal(dyad_compositions$composition, c("friend_x_friend", "same_sex"))
  expect_equal(
    dyad_compositions$pooled_from,
    c(NA_character_, "female_x_female, male_x_male")
  )
  expect_equal(dyad_compositions$n_dyads, c(1L, 2L))
  expect_equal(
    as.character(result$.i_composition),
    c(rep("same_sex", 4), rep("friend_x_friend", 2))
  )
  expect_equal(
    as.character(result$.i_composition_role),
    c(rep("same_sex", 4), rep("friend_x_friend", 2))
  )
  expect_true(".i_diff_friend_x_friend" %in% names(result))
  expect_false(".i_diff_female_x_female" %in% names(result))
  expect_false(".i_diff_male_x_male" %in% names(result))
})

test_that("infer_dyad_compositions pools after setting compositions exchangeable", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2, 3, 3),
    person_id = c("A", "B", "C", "D", "E", "F"),
    role = c("female", "female", "male", "male", "female", "male")
  )

  result <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role
  ) |>
    infer_dyad_compositions(
      seed = 123,
      set_exchangeable_compositions = "female-male",
      pool_compositions = list(romantic_couples = c("female-female", "male-male", "female-male"))
    )

  dyad_compositions <- attr(result, "interdep")$dyad_compositions

  expect_equal(dyad_compositions$composition, "romantic_couples")
  expect_equal(dyad_compositions$dyad_type, "exchangeable")
  expect_equal(dyad_compositions$dyad_type_source, "mixed")
  expect_equal(
    dyad_compositions$pooled_from,
    "female_x_female, female_x_male, male_x_male"
  )
  expect_equal(dyad_compositions$n_dyads, 3L)
  expect_true(".i_is_romantic_couples" %in% names(result))
  expect_true(".i_diff_romantic_couples" %in% names(result))
})

test_that("infer_dyad_compositions rejects pooling distinguishable compositions", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "female", "female", "male")
  )

  validated <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role
  )

  expect_error(
    infer_dyad_compositions(
      validated,
      seed = 123,
      pool_compositions = list(couples = c("female-female", "female-male"))
    ),
    "can only pool exchangeable compositions",
    fixed = TRUE
  )
})

test_that("infer_dyad_compositions validates composition pooling input", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "female", "male", "male")
  )

  validated <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role
  )

  expect_error(
    infer_dyad_compositions(validated, pool_compositions = c("female-female")),
    "must be a named list",
    fixed = TRUE
  )
  expect_error(
    infer_dyad_compositions(validated, pool_compositions = list(pool = character())),
    "non-empty character vector",
    fixed = TRUE
  )
  expect_error(
    infer_dyad_compositions(
      validated,
      pool_compositions = list(pool_a = "female-female", pool_b = "female female")
    ),
    "same composition to more than one pool",
    fixed = TRUE
  )
  expect_error(
    infer_dyad_compositions(
      validated,
      pool_compositions = list(pool = "female-male")
    ),
    "`pool_compositions` contains unknown dyad composition",
    fixed = TRUE
  )
  expect_error(
    infer_dyad_compositions(
      validated,
      pool_compositions = list(male_x_male = "female-female")
    ),
    "names must not match observed compositions",
    fixed = TRUE
  )
})

test_that("infer_dyad_compositions does not treat role vectors as one composition reference", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male")
  )

  validated <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role
  )

  expect_error(
    infer_dyad_compositions(
      validated,
      seed = 123,
      set_exchangeable_compositions = c("female", "male")
    ),
    "`set_exchangeable_compositions` contains unknown dyad composition",
    fixed = TRUE
  )
})

test_that("infer_dyad_compositions errors for unknown composition references", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "male", "female", "male")
  )

  validated <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role
  )

  expect_error(
    infer_dyad_compositions(
      validated,
      seed = 123,
      set_exchangeable_compositions = "female-female"
    ),
    "`set_exchangeable_compositions` contains unknown dyad composition",
    fixed = TRUE
  )
})

test_that("infer_dyad_compositions errors when setting already exchangeable compositions exchangeable", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female", "female", "female", "male")
  )

  validated <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role
  )

  expect_error(
    infer_dyad_compositions(
      validated,
      seed = 123,
      set_exchangeable_compositions = "female-female"
    ),
    "Already exchangeable composition\\(s\\): female_x_female"
  )
})

test_that("infer_dyad_compositions treats unsplittable aliases as unknown compositions", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("a_b", "c", "a", "b_c")
  )

  validated <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role
  )

  expect_error(
    infer_dyad_compositions(
      validated,
      seed = 123,
      set_exchangeable_compositions = "a_b_c"
    ),
    "`set_exchangeable_compositions` contains unknown dyad composition",
    fixed = TRUE
  )
})

test_that("infer_dyad_compositions is not inflated by longitudinal rows", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "A", "B", "C", "D", "C", "D"),
    role = c("female", "male", "female", "male", "female", "female", "female", "female"),
    time = c(1, 1, 2, 2, 1, 1, 2, 2)
  )

  validated <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role,
    time = time
  )

  result <- infer_dyad_compositions(validated, seed = 123)
  dyad_compositions <- attr(result, "interdep")$dyad_compositions
  dyad_compositions <- dyad_compositions[order(dyad_compositions$composition), ]
  indicator_names <- grep("^\\.i_is_", names(result), value = TRUE)

  expect_equal(dyad_compositions$composition, c("female_x_female", "female_x_male"))
  expect_equal(dyad_compositions$dyad_type, c("exchangeable", "distinguishable"))
  expect_equal(dyad_compositions$dyad_type_source, c("inferred", "inferred"))
  expect_equal(dyad_compositions$pooled_from, c(NA_character_, NA_character_))
  expect_equal(dyad_compositions$n_dyads, c(1L, 1L))
  expect_equal(rowSums(result[indicator_names]), rep(1, nrow(result)))
  expect_equal(
    as.character(result$.i_composition),
    c("female_x_male", "female_x_male", "female_x_male", "female_x_male",
      "female_x_female", "female_x_female", "female_x_female", "female_x_female")
  )
  expect_equal(
    as.character(result$.i_composition_role),
    c("female_x_male_female", "female_x_male_male",
      "female_x_male_female", "female_x_male_male",
      "female_x_female", "female_x_female",
      "female_x_female", "female_x_female")
  )
  expect_true(".i_diff_female_x_female" %in% names(result))
  expect_equal(result$.i_diff_female_x_female[result$dyad_id == 1], rep(0, 4))
  expect_equal(abs(result$.i_diff_female_x_female[result$dyad_id == 2]), rep(1, 4))
})

test_that("infer_dyad_compositions handles ragged longitudinal rows", {
  data <- data.frame(
    dyad_id = c(1, 1, 1, 2, 2, 2, 2),
    person_id = c("A", "B", "B", "C", "D", "C", "D"),
    role = c("female", "male", "male", "female", "female", "female", "female"),
    time = c(1, 1, 2, 1, 1, 2, 2)
  )

  result <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role,
    time = time
  ) |>
    infer_dyad_compositions(seed = 123)

  dyad_compositions <- attr(result, "interdep")$dyad_compositions
  dyad_compositions <- dyad_compositions[order(dyad_compositions$composition), ]

  expect_equal(dyad_compositions$composition, c("female_x_female", "female_x_male"))
  expect_equal(dyad_compositions$n_dyads, c(1L, 1L))
  expect_equal(as.character(result$.i_composition[result$dyad_id == 1]), rep("female_x_male", 3))
  expect_equal(as.character(result$.i_composition[result$dyad_id == 2]), rep("female_x_female", 4))
})

test_that("infer_dyad_compositions creates formula-friendly indicator names", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("female partner", "male-partner", "female partner", "male-partner")
  )

  validated <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role
  )

  result <- infer_dyad_compositions(validated, seed = 123)

  expect_true(".i_is_female_partner_x_male_partner_female_partner" %in% names(result))
  expect_true(".i_is_female_partner_x_male_partner_male_partner" %in% names(result))
})

test_that("infer_dyad_compositions rejects generated indicator name collisions", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D"),
    role = c("a b", "a-b", "a b", "a-b")
  )

  validated <- validate_interdep_data(
    data,
    group = dyad_id,
    member = person_id,
    role = role
  )

  expect_error(
    infer_dyad_compositions(validated, seed = 123),
    "same generated column-name suffix",
    fixed = TRUE
  )
})

test_that("infer_dyad_compositions treats missing role metadata as unclassified", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  validated <- validate_interdep_data(data, group = dyad_id, member = person_id)
  result <- infer_dyad_compositions(validated, seed = 123)

  expect_false(".i_raw_composition" %in% names(result))
  expect_false(".i_arbitrary_role" %in% names(result))
  expect_true(is.factor(result$.i_composition))
  expect_true(is.factor(result$.i_composition_role))
  expect_true(".i_is_assumed_exchangeable" %in% names(result))
  expect_true(".i_diff_assumed_exchangeable" %in% names(result))
  expect_false(interdep_diff_col %in% names(result))
  expect_equal(abs(result$.i_diff_assumed_exchangeable), rep(1, 4))
  expect_equal(
    as.character(result$.i_composition),
    rep("assumed_exchangeable", 4)
  )
  expect_equal(
    as.character(result$.i_composition_role),
    rep("assumed_exchangeable", 4)
  )
  expect_equal(
    attr(result, "interdep")$dyad_compositions,
    tibble::tibble(
      composition = "assumed_exchangeable",
      dyad_type = "exchangeable",
      dyad_type_source = "assumed_no_role",
      pooled_from = NA_character_,
      n_dyads = 2L
    )
  )
})

test_that("infer_dyad_compositions treats empty exchangeability overrides as no request without role", {
  data <- data.frame(
    dyad_id = c(1, 1, 2, 2),
    person_id = c("A", "B", "C", "D")
  )

  validated <- validate_interdep_data(data, group = dyad_id, member = person_id)

  expect_no_error(
    infer_dyad_compositions(
      validated,
      seed = 123,
      set_exchangeable_compositions = character()
    )
  )
})
