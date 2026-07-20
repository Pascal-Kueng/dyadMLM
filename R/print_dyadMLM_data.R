#' @export
print.dyadMLM_data <- function(x, ...) {
  meta <- attr(x, "dyadMLM")

  cat(pillar::style_subtle("# dyadMLM data\n"))
  print_wrapped_comment_fields(
    fields = c(
      paste0("Rows: ", nrow(x)),
      paste0("Dyads: ", meta$n_dyads),
      paste0("Intensive longitudinal: ", ifelse(meta$longitudinal, "yes", "no"))
    ),
    sep = " | ",
    exdent = nchar("Rows: "),
    style = "subtle"
  )

  structure_fields <- c(
    paste0("group = ", meta$group),
    paste0("member = ", meta$member)
  )
  if (!is.null(meta$role)) {
    structure_fields <- c(structure_fields, paste0("role = ", meta$role))
  }
  if (!is.null(meta$time)) {
    structure_fields <- c(structure_fields, paste0("time = ", meta$time))
  }

  print_wrapped_comment_fields(
    label = "Structure",
    fields = structure_fields,
    sep = ", ",
    exdent = 2L,
    style = "subtle"
  )

  if (!is.null(meta$dsm_role_order)) {
    print_wrapped_comment_fields(
      label = "DSM direction",
      fields = paste(meta$dsm_role_order, collapse = " - "),
      exdent = 2L,
      style = "subtle"
    )
  }

  cat(pillar::style_subtle("#\n"))

  dropped_dyads <- list(
    "Dropped incomplete dyads" = meta$dropped_incomplete_dyads,
    "Dropped dyads with incomplete role information" = meta$dropped_missing_role_dyads
  )
  for (label in names(dropped_dyads)) {
    dropped <- dropped_dyads[[label]]
    if (length(dropped) > 0) {
      print_wrapped_comment_fields(
        label = label,
        fields = format_group_count(dropped, singular = "dyad", plural = "dyads"),
        exdent = 2L,
        label_style = "negative"
      )
      cat("#\n")
    }
  }

  print_dyad_compositions(meta$dyad_compositions)

  cat("# Added columns:\n")
  print_added_columns(added_columns_for_print(x, meta))
  cat("#\n")

  modified <- x
  class(modified) <- class(modified)[class(modified) != "dyadMLM_data"]
  print(modified, ...)

  # return original unchanged tibble
  invisible(x)
}

print_dyad_compositions <- function(dyad_compositions) {
  if (is.null(dyad_compositions) || nrow(dyad_compositions) == 0) {
    return(invisible(NULL))
  }

  cat("# Dyad compositions:\n")

  pooled_from <- rep(NA_character_, nrow(dyad_compositions))
  if ("pooled_from" %in% names(dyad_compositions)) {
    pooled_from <- dyad_compositions$pooled_from
  }
  has_pooled_members <- !is.na(pooled_from)

  composition_label <- as.character(dyad_compositions$composition)
  composition_label[has_pooled_members] <- paste0(composition_label[has_pooled_members], " (pooled)")
  composition_width <- max(nchar(as.character(dyad_compositions$composition), type = "width"))
  if (any(has_pooled_members)) {
    composition_width <- composition_width + nchar(" (pooled)", type = "width")
  }
  composition_width <- max(composition_width, nchar(composition_label, type = "width"))
  composition <- format(composition_label, width = composition_width, justify = "left")

  dyad_type_label <- ifelse(
    dyad_compositions$dyad_type_source == "set_by_user",
    paste0(dyad_compositions$dyad_type, " (set by user)"),
    dyad_compositions$dyad_type
  )
  dyad_type <- format(dyad_type_label, justify = "left")

  composition_n_dyads <- format(dyad_compositions$n_dyads, justify = "right")
  dyad_count_label <- ifelse(dyad_compositions$n_dyads == 1L, "dyad", "dyads")

  for (i in seq_len(nrow(dyad_compositions))) {
    cat("#",
        composition[[i]],
        dyad_type[[i]],
        composition_n_dyads[[i]],
        paste0(dyad_count_label[[i]], "\n"),
        sep = " ")

    if (has_pooled_members[[i]]) {
      pooled_members <- strsplit(pooled_from[[i]], ",\\s*")[[1]]
      cat(pillar::style_subtle(paste0("#   ", pooled_members, "\n")), sep = "")
    }
  }

  cat("#\n")
  invisible(NULL)
}

added_columns_for_print <- function(x, meta) {
  fixed_added_columns <- tibble::tribble(
    ~column_pattern,        ~description,
    ".dy_composition",       "inferred dyad composition",
    ".dy_composition_role",  "composition-specific member role",
    ".dy_is_{comp-role}",    "composition-role indicator columns",
    ".dy_diff_{comp}",       "composition-specific sum-diff contrasts with arbitrary direction; 0 for distinguishable dyads or other exchangeable compositions"
  )
  show_fixed_added_columns <- c(
    dyad_composition_col %in% names(x),
    dyad_composition_role_col %in% names(x),
    any(startsWith(names(x), paste0(dyad_reserved_prefix, "is_"))),
    any(startsWith(names(x), paste0(dyad_reserved_prefix, "diff_")))
  )
  added_columns <- fixed_added_columns[show_fixed_added_columns, ]

  # Users may remove generated columns while keeping the dyadMLM metadata.
  # Only advertise generated model columns that are still present in the data.
  generated_column_specs <- dyad_generated_columns(meta) |>
    dplyr::filter(.data$column %in% names(x)) |>
    # Avoid repeated descriptions when several generated columns share a family.
    dplyr::distinct(
      .data$print_order,
      .data$column_pattern,
      .data$description
    ) |>
    dplyr::arrange(.data$print_order)

  if (nrow(generated_column_specs) > 0) {
    added_columns <- dplyr::bind_rows(
      added_columns,
      generated_column_specs[, c("column_pattern", "description")]
    )
  }

  added_columns
}

print_added_columns <- function(added_columns) {
  if (nrow(added_columns) == 0) {
    return(invisible(NULL))
  }

  column_width <- max(nchar(added_columns$column_pattern, type = "width")) + 2L

  for (i in seq_len(nrow(added_columns))) {
    prefix <- sprintf("#   %-*s", column_width, added_columns$column_pattern[[i]])
    continuation_prefix <- paste0("\n#   ", strrep(" ", column_width))
    wrap_width <- max(20L, getOption("width", 80L) - nchar(prefix, type = "width"))
    description_lines <- strwrap(added_columns$description[[i]], width = wrap_width)
    if (length(description_lines) == 0) {
      description_lines <- ""
    }

    cat(prefix, paste(description_lines, collapse = continuation_prefix), "\n", sep = "")
  }

  invisible(NULL)
}

print_wrapped_comment_fields <- function(fields, label = NULL, sep = ", ", exdent = 2L,
                                         style = c("plain", "subtle", "negative"),
                                         label_style = c("plain", "subtle", "negative")) {
  style <- rlang::arg_match(style)
  label_style <- rlang::arg_match(label_style)
  wrap_width <- max(20L, getOption("width", 80L) - nchar("# ", type = "width"))
  continuation_prefix <- strrep(" ", exdent)

  lines <- character()
  label_prefix <- NULL
  if (is.null(label)) {
    current <- fields[[1]]
  } else {
    label_prefix <- paste0(label, ":")
    full_line <- paste(label_prefix, paste(fields, collapse = sep))
    if (nchar(full_line, type = "width") <= wrap_width) {
      lines <- full_line
      current <- NULL
    } else {
      lines <- label_prefix
      current <- paste0(continuation_prefix, fields[[1]])
    }
  }

  if (!is.null(current)) {
    for (field in fields[-1]) {
      candidate <- paste0(current, sep, field)
      if (nchar(candidate, type = "width") <= wrap_width) {
        current <- candidate
      } else {
        lines <- c(lines, current)
        current <- paste0(continuation_prefix, field)
      }
    }
    lines <- c(lines, current)
  }

  wrapped_lines <- unlist(lapply(lines, function(line) {
    indent <- regmatches(line, regexpr("^ *", line))
    content <- substring(line, nchar(indent, type = "width") + 1L)
    content_width <- max(10L, wrap_width - nchar(indent, type = "width"))
    wrapped <- strwrap(content, width = content_width)
    if (length(wrapped) == 0) {
      wrapped <- ""
    }

    paste0(indent, wrapped)
  }), use.names = FALSE)
  out <- paste0("# ", wrapped_lines, "\n")
  if (style == "subtle") {
    out <- pillar::style_subtle(out)
  } else if (style == "negative") {
    out <- pillar::style_neg(out)
  } else if (!is.null(label_prefix) && label_style != "plain") {
    styled_label <- label_prefix
    if (label_style == "subtle") {
      styled_label <- pillar::style_subtle(label_prefix)
    } else if (label_style == "negative") {
      styled_label <- pillar::style_neg(label_prefix)
    }

    out <- sub(
      paste0("# ", label_prefix),
      paste0("# ", styled_label),
      out,
      fixed = TRUE
    )
  }

  cat(out, sep = "")
  invisible(NULL)
}
