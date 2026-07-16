.interdep_effect_colors <- c(
  actor = "#1769AA",
  partner = "#7B3FA1",
  dyad_mean = "#C43C35",
  member_deviation = "#8A6500"
)

#' Semantic colors for dyadic model effects
#'
#' Returns the shared color palette used for model effects in `interdep`
#' diagrams, vignettes, and teaching materials. The colors have fixed meanings:
#' blue for actor effects, purple for partner effects, red for dyad-mean
#' effects, and gold for member-deviation effects. Reserve these colors for
#' those meanings when several model components appear together.
#'
#' @param effect Character vector selecting one or more effects. Available
#'   values are `"actor"`, `"partner"`, `"dyad_mean"`, and
#'   `"member_deviation"`. By default, all colors are returned.
#'
#' @return A named character vector of hexadecimal colors.
#' @export
#'
#' @examples
#' interdep_colors()
#' interdep_colors(c("actor", "partner"))
interdep_colors <- function(effect = names(.interdep_effect_colors)) {
  if (!is.character(effect) || anyNA(effect) || any(!nzchar(effect))) {
    stop("`effect` must be a character vector without missing values.",
         call. = FALSE)
  }

  unknown <- setdiff(effect, names(.interdep_effect_colors))
  if (length(unknown) > 0L) {
    stop(
      "Unknown effect", if (length(unknown) == 1L) "" else "s", ": ",
      paste(unknown, collapse = ", "), ". Available effects are: ",
      paste(names(.interdep_effect_colors), collapse = ", "), ".",
      call. = FALSE
    )
  }

  .interdep_effect_colors[effect]
}
